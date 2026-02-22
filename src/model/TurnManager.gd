extends RefCounted
class_name TurnManager

# Orchestrates the turn cycle for all cities.
# Uses tag-driven resource processing:
# - Cap resources computed generically (not hardcoded to admin_capacity)
# - Production/consumption use array format with tag-based matching
# - Knowledge resources route to tech tree branches
# - Population derived from population-tagged storage

signal turn_started(turn_number: int)
signal turn_completed(report: TurnReport)
signal city_processed(city_id: String, city_report: TurnReport.CityTurnReport)
signal city_abandoned(city: City, previous_owner: Player)
signal player_defeated(player: Player)

var current_turn: int = 0
var last_report: TurnReport = null

# Reference to city manager for accessing all cities
var city_manager: CityManager

# Reference to unit manager for spawning units
var unit_manager: UnitManager

# Reference to world query for terrain/modifier data
var world_query: Node  # WorldQuery type

# Reference to trade route manager for per-turn resource transfers
var trade_route_manager: TradeRouteManager

func _init(p_city_manager: CityManager, p_unit_manager: UnitManager = null, p_world_query: Node = null, p_trade_route_manager: TradeRouteManager = null):
	city_manager = p_city_manager
	unit_manager = p_unit_manager
	world_query = p_world_query
	trade_route_manager = p_trade_route_manager

func process_turn() -> TurnReport:
	"""Process a complete turn for all cities"""
	current_turn += 1
	
	var report = TurnReport.new()
	report.turn_number = current_turn
	
	# Snapshot milestones before turn processing to detect new unlocks
	var milestones_before := Registry.tech.get_unlocked_milestones().duplicate()
	
	emit_signal("turn_started", current_turn)
	print("\n========== TURN %d ==========" % current_turn)
	
	# Process unit turn start (refresh movement, etc.)
	if unit_manager:
		for unit in unit_manager.get_all_units():
			unit.start_turn()
		print("  Units refreshed: %d" % unit_manager.get_all_units().size())

	# Validate trade routes and clean up dead convoys
	if trade_route_manager:
		_validate_trade_routes(report)

	# Clear trade ledger flows before city processing
	for city in city_manager.get_all_cities():
		if not city.is_abandoned:
			city.resources.clear_flows()

	# Process each city (skip abandoned cities)
	var cities_to_abandon: Array[City] = []
	
	for city in city_manager.get_all_cities():
		if city.is_abandoned:
			print("  Skipping abandoned city: %s" % city.city_name)
			continue
		
		var city_report = _process_city_turn(city)
		report.add_city_report(city.city_id, city_report)
		
		# Check if city should be abandoned (population reached 0)
		if city.should_check_abandonment():
			cities_to_abandon.append(city)
		
		# Generate critical alerts for this city
		_generate_city_alerts(city, city_report, report)
		
		emit_signal("city_processed", city.city_id, city_report)
	
	# Handle city abandonments (done after loop to avoid modifying collection during iteration)
	for city in cities_to_abandon:
		_handle_city_abandonment(city, report)
	
	# Process global research and milestone unlocks
	_process_global_research(report)
	
	# Detect newly unlocked milestones this turn
	var milestones_after := Registry.tech.get_unlocked_milestones()
	for milestone_id in milestones_after:
		if milestone_id not in milestones_before:
			report.add_milestone_unlocked(milestone_id)
			print("  ★ Milestone unlocked: %s" % Registry.tech.get_milestone_name(milestone_id))

	# Detect perk unlocks for all players
	_check_perk_unlocks(report)

	last_report = report
	emit_signal("turn_completed", report)
	
	print("\n" + report.get_summary())
	print("========== END TURN %d ==========\n" % current_turn)
	
	return report

func _process_city_turn(city: City) -> TurnReport.CityTurnReport:
	"""Process a single city's turn"""
	var report = TurnReport.CityTurnReport.new(city.city_id, city.city_name)
	
	print("\n--- Processing City: %s ---" % city.city_name)
	
	# Phase 1: Calculate cap resources and efficiency
	_phase_caps(city, report)
	
	# Phase 2: Production (all operational buildings produce FIRST)
	_phase_production(city, report)
	
	# Phase 2b: Modifier consumption (active buildings may consume nearby modifiers)
	_phase_modifier_consumption(city, report)

	# Phase 2c: Trade transfers (send/receive resources via trade routes)
	_phase_trade(city, report)

	# Phase 3: Consumption (two-pass system, penalties if consumption fails)
	_phase_consumption(city, report)

	# Phase 3b: Modifier production (active buildings place/remove modifiers on their tile)
	_phase_modifier_production(city, report)

	# Phase 4: Construction processing
	_phase_construction(city, report)
	
	# Phase 4b: Upgrade processing
	_phase_upgrades(city, report)
	
	# Phase 4c: Training processing
	_phase_training(city, report)
	
	# Phase 5: Population update (derived from population-tagged resources)
	_phase_population(city, report)
	
	# Phase 6: Resource decay
	_phase_decay(city, report)
	
	# Record final resource totals
	_record_resource_totals(city, report)
	
	return report

# === Phase 1: Generic Cap Processing ===

func _phase_caps(city: City, report: TurnReport.CityTurnReport):
	"""Calculate all cap resources generically. Updates city.cap_state and report."""
	city.cap_state.clear()
	
	# Gather all cap-tagged resources involved in this city
	var cap_resource_ids := _gather_cap_resources(city)
	
	# Best efficiency across all caps (used as global production modifier)
	var worst_efficiency := 1.0
	
	for res_id in cap_resource_ids:
		var available := 0.0
		var used := 0.0
		
		# Sum available (production) from operational/constructing buildings
		for instance in city.building_instances.values():
			if instance.is_operational() or instance.is_under_construction():
				for entry in Registry.buildings.get_produces(instance.building_id):
					if entry.get("resource", "") == res_id:
						available += entry.get("quantity", 0.0)
		
		# Sum used from building consumption
		for coord in city.building_instances.keys():
			var instance: BuildingInstance = city.building_instances[coord]
			if instance.is_disabled():
				# Disabled buildings may still have a reduced cost
				used += _get_disabled_cap_cost(instance, res_id)
				continue
			
			used += _calculate_building_cap_consumption(instance, res_id, city, coord)
		
		# Sum tile costs from settlement type
		for coord in city.tiles.keys():
			var tile: CityTile = city.tiles[coord]
			used += Registry.settlements.calculate_tile_cost(
				city.settlement_type, res_id, tile.distance_from_center, tile.is_city_center
			)
		
		# Compute ratio and efficiency
		var ratio = used / max(available, 0.001)
		var efficiency = city._calculate_cap_efficiency(res_id, ratio)
		
		# Update city cap state
		city.cap_state[res_id] = {
			"available": available,
			"used": used,
			"ratio": ratio,
			"efficiency": efficiency
		}
		
		# Report
		report.set_cap_report(res_id, available, used, ratio, efficiency)
		
		# Track worst efficiency for production modifier
		if efficiency < worst_efficiency:
			worst_efficiency = efficiency
		
		var res_name = Registry.get_name_label("resource", res_id)
		print("  Cap [%s]: %.1f / %.1f (ratio: %.2f, eff: %.0f%%)" % [
			res_name, used, available, ratio, efficiency * 100
		])
	
	report.production_efficiency = worst_efficiency

func _gather_cap_resources(city: City) -> Array[String]:
	"""Find all cap-tagged resources referenced by this city's buildings and settlement."""
	var found := {}
	
	# From settlement tile costs
	for res_id in Registry.settlements.get_all_tile_cost_resources(city.settlement_type):
		found[res_id] = true
	
	# From buildings
	for instance in city.building_instances.values():
		for entry in Registry.buildings.get_produces(instance.building_id):
			var res_id = entry.get("resource", "")
			if res_id != "" and Registry.resources.has_tag(res_id, "cap"):
				found[res_id] = true
		for entry in Registry.buildings.get_consumes(instance.building_id):
			var res_id = entry.get("resource", "")
			if res_id != "" and Registry.resources.has_tag(res_id, "cap"):
				found[res_id] = true
	
	var result: Array[String] = []
	for res_id in found.keys():
		result.append(res_id)
	return result

func _calculate_building_cap_consumption(instance: BuildingInstance, cap_resource_id: String, city: City, coord: Vector2i) -> float:
	"""Calculate how much of a cap resource a building consumes, including distance costs."""
	var total := 0.0
	
	for entry in Registry.buildings.get_consumes(instance.building_id):
		if entry.get("resource", "") != cap_resource_id:
			continue
		
		var base_qty = entry.get("quantity", 0.0)
		var dist_cost = entry.get("distance_cost", {})
		
		if dist_cost.is_empty():
			total += base_qty
		else:
			var multiplier = dist_cost.get("multiplier", 0.0)
			var distance_to = dist_cost.get("distance_to", "city_center")
			var distance: int
			
			if distance_to == "nearest_source":
				distance = _find_nearest_producer_distance(city, coord, cap_resource_id)
			else:  # "city_center" or default
				var tile: CityTile = city.tiles.get(coord)
				distance = tile.distance_from_center if tile else 0
			
			# Apply perk admin distance modifier
			var perk_dist_mod = Registry.perks.get_admin_distance_modifier(city.owner) if city.owner else 0.0
			var effective_multiplier = max(0.0, multiplier + perk_dist_mod)
			total += base_qty + (pow(distance, 2) * effective_multiplier)

	return total

func _find_nearest_producer_distance(city: City, from_coord: Vector2i, resource_id: String) -> int:
	"""Find hex distance to the nearest building that produces a resource."""
	var min_distance := 999
	
	for coord in city.building_instances.keys():
		if coord == from_coord:
			continue
		var instance = city.building_instances[coord]
		if not instance.is_operational() and not instance.is_under_construction():
			continue
		
		for entry in Registry.buildings.get_produces(instance.building_id):
			if entry.get("resource", "") == resource_id:
				var distance = city.calculate_distance_from_center(coord)
				# Compute hex distance between the two coords
				var q_diff = abs(from_coord.x - coord.x)
				var r_diff = abs(from_coord.y - coord.y)
				var s_diff = abs((-from_coord.x - from_coord.y) - (-coord.x - coord.y))
				var hex_dist = int((q_diff + r_diff + s_diff) / 2)
				if hex_dist < min_distance:
					min_distance = hex_dist
				break
	
	# If no producer found, use distance from center as fallback
	if min_distance == 999:
		var tile: CityTile = city.tiles.get(from_coord)
		min_distance = tile.distance_from_center if tile else 0
	
	return min_distance

func _get_disabled_cap_cost(instance: BuildingInstance, cap_resource_id: String) -> float:
	"""Get cap cost for a disabled building (usually reduced or zero)."""
	# Only admin_capacity has disabled cost for now, but check building data
	if cap_resource_id == "admin_capacity":
		return instance.get_disabled_admin_cost()
	return 0.0

# === Phase 2: Production ===

func _phase_production(city: City, report: TurnReport.CityTurnReport):
	"""Process production using array format. Handles storable, flow, and knowledge resources."""
	var efficiency = report.production_efficiency
	
	for coord in city.building_instances.keys():
		var instance: BuildingInstance = city.building_instances[coord]
		
		# Only ACTIVE buildings produce
		if not instance.can_produce():
			continue
		
		var produces = Registry.buildings.get_produces(instance.building_id)
		if produces.is_empty():
			continue
		
		# Calculate production bonuses for this building
		var bonuses = _calculate_production_bonuses(city, coord, instance.building_id)

		# Perk production multiplier for this building type
		var perk_mult = Registry.perks.get_production_multiplier(city.owner, instance.building_id)

		for entry in produces:
			var res_id = entry.get("resource", "")
			if res_id == "":
				continue

			# Skip cap resources (already handled in Phase 1)
			if Registry.resources.has_tag(res_id, "cap"):
				continue

			var base_amount = entry.get("quantity", 0.0)
			var bonus_amount = bonuses.get(res_id, 0.0)
			var raw_amount = base_amount + bonus_amount
			var adjusted_amount = raw_amount * efficiency * perk_mult
			
			# Knowledge resources (flow + knowledge tag) — route to tech tree
			if Registry.resources.has_tag(res_id, "knowledge"):
				var branch = entry.get("branch", "")
				if branch != "":
					# Branch-specific knowledge
					report.add_knowledge(res_id, branch, adjusted_amount)
				else:
					# Generic knowledge (routed to player's chosen branch later)
					report.add_generic_knowledge(res_id, adjusted_amount)
				
				report.add_production(res_id, raw_amount, adjusted_amount)
				if bonus_amount > 0:
					print("    %s: base %.1f + bonus %.1f = %.1f" % [res_id, base_amount, bonus_amount, raw_amount])
				continue
			
			# Flow resources (non-knowledge) — just track, no storage
			if Registry.resources.has_tag(res_id, "flow"):
				report.add_production(res_id, raw_amount, adjusted_amount)
				continue
			
			# Storable resources — store in pools
			var stored = city.store_resource(res_id, adjusted_amount)
			var spilled = adjusted_amount - stored
			
			report.add_production(res_id, raw_amount, adjusted_amount)
			
			if bonus_amount > 0:
				print("    %s: base %.1f + bonus %.1f = %.1f" % [res_id, base_amount, bonus_amount, raw_amount])
			
			if spilled > 0:
				report.add_spillage(res_id, spilled)
				print("    Spillage: %.1f %s (storage full)" % [spilled, res_id])
	
	# Apply global yield bonuses from perks (once per city)
	var global_bonuses = Registry.perks.get_global_yield_bonuses(city.owner)
	for res_id in global_bonuses.keys():
		var bonus = global_bonuses[res_id]
		if bonus == 0.0:
			continue
		if Registry.resources.has_tag(res_id, "cap") or Registry.resources.has_tag(res_id, "flow"):
			continue
		var stored = city.store_resource(res_id, bonus)
		var spilled = bonus - stored
		report.add_production(res_id, bonus, bonus)
		if spilled > 0:
			report.add_spillage(res_id, spilled)
		if bonus > 0:
			print("    Perk global bonus: +%.1f %s" % [bonus, res_id])

	print("  Production complete (efficiency: %.0f%%)" % (efficiency * 100))

func _calculate_production_bonuses(city: City, coord: Vector2i, building_id: String) -> Dictionary:
	"""
	Calculate all production bonuses for a building at a specific location.
	Includes: terrain bonuses, modifier bonuses, and adjacency bonuses.
	Returns: Dictionary of resource_id -> bonus_amount
	"""
	var bonuses: Dictionary = {}
	
	if not world_query:
		return bonuses
	
	var terrain_data = world_query.get_terrain_data(coord)
	if not terrain_data:
		return bonuses
	
	# 1. Terrain bonuses - bonus from being ON specific terrain
	var terrain_bonuses = Registry.buildings.get_terrain_bonuses(building_id)
	if terrain_bonuses.has(terrain_data.terrain_id):
		var terrain_yields = terrain_bonuses[terrain_data.terrain_id]
		for resource_id in terrain_yields.keys():
			bonuses[resource_id] = bonuses.get(resource_id, 0.0) + terrain_yields[resource_id]
	
	# 2. Modifier bonuses - bonus from modifiers ON this tile
	var modifier_bonuses = Registry.buildings.get_modifier_bonuses(building_id)
	for mod_id in terrain_data.modifiers:
		if modifier_bonuses.has(mod_id):
			var mod_yields = modifier_bonuses[mod_id]
			for resource_id in mod_yields.keys():
				bonuses[resource_id] = bonuses.get(resource_id, 0.0) + mod_yields[resource_id]
	
	# 3. Adjacency bonuses - bonus from adjacent terrain/buildings/modifiers
	var adjacency_bonuses = Registry.buildings.get_adjacency_bonuses(building_id)
	for adj_bonus in adjacency_bonuses:
		var source_type = adj_bonus.get("source_type", "")
		var source_id = adj_bonus.get("source_id", "")
		var radius = adj_bonus.get("radius", 1)
		var yields = adj_bonus.get("yields", {})
		
		var matching_count = _count_adjacent_sources(coord, source_type, source_id, radius, city)
		
		if matching_count > 0:
			for resource_id in yields.keys():
				var bonus_per_source = yields[resource_id]
				bonuses[resource_id] = bonuses.get(resource_id, 0.0) + (bonus_per_source * matching_count)

	# 4. Per-terrain perk yield bonuses
	if city.owner:
		var perk_terrain_bonuses = Registry.perks.get_terrain_yield_bonuses(city.owner, terrain_data.terrain_id)
		for resource_id in perk_terrain_bonuses.keys():
			bonuses[resource_id] = bonuses.get(resource_id, 0.0) + perk_terrain_bonuses[resource_id]

	return bonuses

func _count_adjacent_sources(coord: Vector2i, source_type: String, source_id: String, radius: int, city: City) -> int:
	"""Count how many matching sources are adjacent to a tile"""
	var count = 0
	
	if not world_query:
		return count
	
	var neighbors = world_query.get_tiles_in_range(coord, 1, radius)
	
	for neighbor_coord in neighbors:
		var matched = false
		
		match source_type:
			"terrain":
				var terrain_id = world_query.get_terrain_id(neighbor_coord)
				matched = (terrain_id == source_id)
			
			"modifier":
				var neighbor_data = world_query.get_terrain_data(neighbor_coord)
				if neighbor_data:
					matched = neighbor_data.has_modifier(source_id)
			
			"building":
				if city.has_building(neighbor_coord):
					var neighbor_instance = city.get_building_instance(neighbor_coord)
					matched = (neighbor_instance.building_id == source_id)
			
			"building_category":
				if city.has_building(neighbor_coord):
					var neighbor_instance = city.get_building_instance(neighbor_coord)
					var neighbor_building = Registry.buildings.get_building(neighbor_instance.building_id)
					matched = (neighbor_building.get("category", "") == source_id)
			
			"river":
				var neighbor_data = world_query.get_terrain_data(neighbor_coord)
				if neighbor_data:
					matched = neighbor_data.is_river
		
		if matched:
			count += 1
	
	return count

# === Phase 2b: Modifier Consumption ===

func _phase_modifier_consumption(city: City, report: TurnReport.CityTurnReport):
	"""Active buildings may consume nearby modifiers each turn based on chance."""
	if not world_query:
		return
	
	for coord in city.building_instances.keys():
		var instance: BuildingInstance = city.building_instances[coord]
		
		if not instance.is_active():
			continue
		
		var consumption_rules = Registry.buildings.get_modifier_consumption(instance.building_id)
		if consumption_rules.is_empty():
			continue
		
		for rule in consumption_rules:
			var modifier_id: String = rule.get("modifier_id", "")
			var chance_percent: float = rule.get("chance_percent", 0.0)
			var radius: int = rule.get("radius", 1)
			var transforms_to: String = rule.get("transforms_to", "")
			
			if modifier_id == "" or chance_percent <= 0.0:
				continue
			
			var tiles_to_check: Array[Vector2i] = [coord]
			if radius > 0:
				tiles_to_check.append_array(world_query.get_tiles_in_range(coord, 1, radius))
			
			for target_coord in tiles_to_check:
				var terrain_data = world_query.get_terrain_data(target_coord)
				if not terrain_data:
					continue
				
				if not terrain_data.has_modifier(modifier_id):
					continue
				
				var roll = randf() * 100.0
				if roll < chance_percent:
					terrain_data.remove_modifier(modifier_id)
					
					if transforms_to != "":
						terrain_data.add_modifier(transforms_to)
						report.add_modifier_consumed(coord, instance.building_id, target_coord, modifier_id, transforms_to)
						print("    Modifier consumed: %s -> %s at %v (by %s)" % [modifier_id, transforms_to, target_coord, instance.building_id])
					else:
						report.add_modifier_consumed(coord, instance.building_id, target_coord, modifier_id, "")
						print("    Modifier consumed: %s removed at %v (by %s)" % [modifier_id, target_coord, instance.building_id])

# === Phase 2c: Trade ===

func _phase_trade(city: City, report: TurnReport.CityTurnReport):
	"""Process trade route transfers for this city.
	Only processes routes where this city is the source (outgoing transfers).
	Incoming transfers are handled when the other city is processed."""
	if not trade_route_manager:
		return

	trade_route_manager.process_trade(city, report)

# === Phase 3: Consumption ===

func _phase_consumption(city: City, report: TurnReport.CityTurnReport):
	"""Two-pass consumption using array format. Supports tag-based consumption."""
	
	# Separate buildings into lists BEFORE processing
	var active_buildings: Array[Vector2i] = []
	var expecting_buildings: Array[Vector2i] = []
	
	for coord in city.building_instances.keys():
		var instance: BuildingInstance = city.building_instances[coord]
		if instance.is_active():
			active_buildings.append(coord)
		elif instance.is_expecting_resources():
			expecting_buildings.append(coord)
	
	print("  Consumption: %d active, %d expecting" % [active_buildings.size(), expecting_buildings.size()])
	
	# Pass 1: Process ACTIVE buildings
	for coord in active_buildings:
		var instance: BuildingInstance = city.building_instances[coord]
		_process_building_consumption(city, instance, report)
	
	# Pass 2: Process EXPECTING_RESOURCES buildings
	for coord in expecting_buildings:
		var instance: BuildingInstance = city.building_instances[coord]
		_process_building_consumption(city, instance, report)

func _process_building_consumption(city: City, instance: BuildingInstance, report: TurnReport.CityTurnReport):
	"""Process consumption for a single building using array format."""
	# Runtime adjacency recheck: buildings with required_adjacent must still meet the requirement
	if world_query:
		var adj_check = world_query.check_terrain_adjacency_requirements(instance.tile_coord, instance.building_id)
		if not adj_check.met:
			instance.set_expecting_resources()
			report.add_building_waiting(instance.tile_coord, instance.building_id, {"adjacency": adj_check.reason})
			print("    Adjacency not met: %s at %v (%s)" % [instance.building_id, instance.tile_coord, adj_check.reason])
			return

	var consumes = Registry.buildings.get_consumes(instance.building_id)
	
	# Filter out cap resources (already handled in Phase 1)
	var non_cap_consumes := []
	for entry in consumes:
		var res_id = entry.get("resource", "")
		var tag = entry.get("tag", "")
		if res_id != "" and Registry.resources.has_tag(res_id, "cap"):
			continue
		non_cap_consumes.append(entry)
	
	if non_cap_consumes.is_empty():
		# No consumption needed - ensure building is active
		if not instance.is_active():
			instance.set_active()
			report.add_building_activated(instance.tile_coord, instance.building_id)
		return
	
	# Check if city has all required resources
	var can_consume = true
	var missing: Dictionary = {}
	
	for entry in non_cap_consumes:
		var needed = entry.get("quantity", 0.0)
		var res_id = entry.get("resource", "")
		var tag = entry.get("tag", "")
		
		if res_id != "":
			# Resource-based consumption
			var available = city.get_total_resource(res_id)
			if available < needed:
				can_consume = false
				missing[res_id] = needed - available
		elif tag != "":
			# Tag-based consumption — check total of all resources with this tag
			var tagged = city.get_resources_by_tag(tag)
			var total_available := 0.0
			for amount in tagged.values():
				total_available += amount
			if total_available < needed:
				can_consume = false
				missing[tag + " (tag)"] = needed - total_available
	
	if can_consume:
		# Consume resources
		for entry in non_cap_consumes:
			var amount = entry.get("quantity", 0.0)
			var res_id = entry.get("resource", "")
			var tag = entry.get("tag", "")
			
			if res_id != "":
				city.consume_resource(res_id, amount)
				report.add_consumption(res_id, amount)
			elif tag != "":
				var consumed = city.consume_resource_by_tag(tag, amount)
				for consumed_id in consumed.keys():
					report.add_consumption(consumed_id, consumed[consumed_id])
		
		# Activate the building
		if not instance.is_active():
			instance.set_active()
			report.add_building_activated(instance.tile_coord, instance.building_id)
	else:
		# Cannot consume - apply penalty and set to expecting
		instance.set_expecting_resources()
		report.add_building_waiting(instance.tile_coord, instance.building_id, missing)
		
		# Apply penalty if defined
		var penalty_entries = Registry.buildings.get_penalty(instance.building_id)
		if not penalty_entries.is_empty():
			var penalty_dict := {}
			for penalty_entry in penalty_entries:
				var res_id = penalty_entry.get("resource", "")
				var penalty_amount = penalty_entry.get("quantity", 0.0)
				if res_id != "" and penalty_amount > 0:
					city.consume_resource(res_id, penalty_amount)
					report.add_penalty(res_id, penalty_amount)
					penalty_dict[res_id] = penalty_amount
			
			if not penalty_dict.is_empty():
				report.add_building_penalized(instance.tile_coord, instance.building_id, penalty_dict)
				print("    Penalty applied: %s at %v" % [instance.building_id, instance.tile_coord])

# === Phase 3b: Modifier Production ===

func _phase_modifier_production(city: City, report: TurnReport.CityTurnReport):
	"""Active buildings with provides.modifiers place modifiers on their tile; inactive ones remove them."""
	if not world_query:
		return

	for coord in city.building_instances.keys():
		var instance: BuildingInstance = city.building_instances[coord]
		var provided_mods = Registry.buildings.get_provided_modifiers(instance.building_id)
		if provided_mods.is_empty():
			continue

		var terrain_data = world_query.get_terrain_data(coord)
		if not terrain_data:
			continue

		if instance.is_active():
			for mod_id in provided_mods:
				if not terrain_data.has_modifier(mod_id):
					terrain_data.add_modifier(mod_id)
					print("    Modifier produced: %s at %v (by %s)" % [mod_id, coord, instance.building_id])
		else:
			for mod_id in provided_mods:
				if terrain_data.has_modifier(mod_id):
					terrain_data.remove_modifier(mod_id)
					print("    Modifier removed: %s at %v (%s inactive)" % [mod_id, coord, instance.building_id])

# === Phase 4: Construction ===

func _phase_construction(city: City, report: TurnReport.CityTurnReport):
	"""Process construction for buildings being built, limited by building capacity."""
	var building_capacity = city.get_total_building_capacity()
	var construction_coords = city.get_constructions_in_progress()
	var constructions_processed: int = 0
	
	print("  Building capacity: %d, constructions queued: %d" % [building_capacity, construction_coords.size()])
	
	for coord in construction_coords:
		var instance: BuildingInstance = city.building_instances[coord]
		
		if constructions_processed >= building_capacity:
			report.add_construction_queued(coord, instance.building_id, instance.turns_remaining)
			print("    Construction queued (no capacity): %s at %v" % [instance.building_id, coord])
			continue
		
		var base_cost = instance.cost_per_turn

		if base_cost.is_empty():
			instance.set_constructing()
			var completed = instance.advance_construction()
			constructions_processed += 1

			if completed:
				_on_construction_completed(city, instance, report)
			else:
				report.add_construction_progressed(coord, instance.building_id, instance.turns_remaining)
			continue

		# Apply perk construction cost multiplier
		var perk_cost_mult = Registry.perks.get_construction_cost_multiplier(city.owner, instance.building_id)
		var cost := {}
		for resource_id in base_cost.keys():
			cost[resource_id] = ceili(base_cost[resource_id] * perk_cost_mult)

		var can_afford = true
		var missing: Dictionary = {}

		for resource_id in cost.keys():
			var needed = cost[resource_id]
			var available = city.get_total_resource(resource_id)
			if available < needed:
				can_afford = false
				missing[resource_id] = needed - available
		
		if can_afford:
			for resource_id in cost.keys():
				city.consume_resource(resource_id, cost[resource_id])
			
			instance.set_constructing()
			var completed = instance.advance_construction()
			constructions_processed += 1
			
			if completed:
				_on_construction_completed(city, instance, report)
			else:
				report.add_construction_progressed(coord, instance.building_id, instance.turns_remaining)
		else:
			instance.set_construction_paused()
			constructions_processed += 1
			report.add_construction_paused(coord, instance.building_id, missing)
			print("    Construction paused: %s at %v (missing resources)" % [instance.building_id, coord])

func _on_construction_completed(city: City, instance: BuildingInstance, report: TurnReport.CityTurnReport):
	"""Handle building construction completion and apply rewards"""
	var coord = instance.tile_coord
	var building_id = instance.building_id
	
	report.add_construction_completed(coord, building_id)
	print("    Construction completed: %s at %v" % [building_id, coord])
	
	var rewards = Registry.buildings.get_on_construction_complete(building_id)
	if rewards.is_empty():
		return
	
	if rewards.has("resources"):
		for resource_id in rewards.resources.keys():
			var amount = rewards.resources[resource_id]
			var stored = city.store_resource(resource_id, amount)
			report.add_completion_reward(resource_id, stored)
			if stored > 0:
				print("      Reward: +%.1f %s" % [stored, resource_id])
	
	if rewards.has("research"):
		for branch_id in rewards.research.keys():
			var points = rewards.research[branch_id]
			Registry.tech.add_research(branch_id, points)
			report.add_completion_research_reward(branch_id, points)
			print("      Research reward: +%.2f %s" % [points, branch_id])

# === Phase 4b: Upgrades ===

func _phase_upgrades(city: City, report: TurnReport.CityTurnReport):
	"""Process building upgrades - buildings continue operating while upgrading"""
	for coord in city.building_instances.keys():
		var instance: BuildingInstance = city.building_instances[coord]
		
		if not instance.is_upgrading():
			continue
		
		var cost = instance.upgrade_cost_per_turn
		
		if cost.is_empty():
			var completed = instance.advance_upgrade()
			
			if completed:
				_on_upgrade_completed(city, instance, report)
			else:
				report.add_upgrade_progressed(coord, instance.building_id, instance.upgrading_to, instance.upgrade_turns_remaining)
			continue
		
		var can_afford = true
		var missing: Dictionary = {}
		
		for resource_id in cost.keys():
			var needed = cost[resource_id]
			var available = city.get_total_resource(resource_id)
			if available < needed:
				can_afford = false
				missing[resource_id] = needed - available
		
		if can_afford:
			for resource_id in cost.keys():
				city.consume_resource(resource_id, cost[resource_id])
			
			var completed = instance.advance_upgrade()
			
			if completed:
				_on_upgrade_completed(city, instance, report)
			else:
				report.add_upgrade_progressed(coord, instance.building_id, instance.upgrading_to, instance.upgrade_turns_remaining)
		else:
			report.add_upgrade_paused(coord, instance.building_id, instance.upgrading_to, missing)
			print("    Upgrade paused: %s at %v (missing resources)" % [instance.building_id, coord])

func _on_upgrade_completed(city: City, instance: BuildingInstance, report: TurnReport.CityTurnReport):
	"""Handle building upgrade completion"""
	var coord = instance.tile_coord
	var old_building_id = instance.building_id
	var new_building_id = instance.upgrading_to
	
	instance.complete_upgrade()
	
	var tile = city.get_tile(coord)
	if tile:
		tile.building_id = new_building_id
	
	# Check if this upgrade triggers a settlement transition
	_check_settlement_transition(city, old_building_id, new_building_id)
	
	report.add_upgrade_completed(coord, old_building_id, new_building_id)
	print("    Upgrade completed: %s -> %s at %v" % [old_building_id, new_building_id, coord])
	
	var rewards = Registry.buildings.get_on_construction_complete(new_building_id)
	if rewards.is_empty():
		return
	
	if rewards.has("resources"):
		for resource_id in rewards.resources.keys():
			var amount = rewards.resources[resource_id]
			var stored = city.store_resource(resource_id, amount)
			report.add_completion_reward(resource_id, stored)
			if stored > 0:
				print("      Reward: +%.1f %s" % [stored, resource_id])
	
	if rewards.has("research"):
		for branch_id in rewards.research.keys():
			var points = rewards.research[branch_id]
			Registry.tech.add_research(branch_id, points)
			report.add_completion_research_reward(branch_id, points)
			print("      Research reward: +%.2f %s" % [points, branch_id])

func _check_settlement_transition(city: City, old_building_id: String, new_building_id: String):
	"""Check if a building upgrade triggers a settlement type transition."""
	var transitions = Registry.settlements.get_transitions(city.settlement_type)
	
	for transition in transitions:
		if transition.get("trigger", "") != "building_upgrade":
			continue
		if transition.get("trigger_building", "") != old_building_id:
			continue
		if transition.get("target_building", "") != new_building_id:
			continue
		
		var target_type = transition.get("target", "")
		if target_type == "":
			continue
		
		# Check requirements
		var check = city.can_transition_to(target_type)
		if check.get("can", false):
			city.transition_settlement(target_type)
			print("    ★ Settlement transition: %s → %s" % [city.settlement_type, target_type])

# === Phase 4c: Training ===

func _phase_training(city: City, report: TurnReport.CityTurnReport):
	"""Process unit training for all buildings in the city"""
	for coord in city.building_instances.keys():
		var instance: BuildingInstance = city.building_instances[coord]
		
		if not instance.is_training():
			continue
		
		var unit_id = instance.training_unit_id
		var turns_remaining = instance.training_turns_remaining
		
		var completed_unit_type = instance.advance_training()
		
		if completed_unit_type != "":
			_on_training_completed(city, completed_unit_type, coord, report)
		else:
			print("    Training %s at %v: %d turns remaining" % [unit_id, coord, turns_remaining - 1])

func _on_training_completed(city: City, unit_type: String, building_coord: Vector2i, report: TurnReport.CityTurnReport):
	"""Handle unit training completion - spawn the unit"""
	print("    Training completed: %s at %v" % [Registry.units.get_unit_name(unit_type), building_coord])
	
	var spawn_coord = _find_unit_spawn_location(city, building_coord)
	
	if spawn_coord == Vector2i(-99999, -99999):
		print("      Warning: No valid spawn location found!")
		return
	
	if unit_manager:
		var owner_id = city.owner.player_id if city.owner else "unknown"
		var unit = unit_manager.spawn_unit(unit_type, owner_id, spawn_coord, city.city_id)
		if unit:
			print("      Spawned %s at %v" % [unit_type, spawn_coord])
	else:
		print("      Warning: No unit manager - unit not spawned")

func _find_unit_spawn_location(city: City, building_coord: Vector2i) -> Vector2i:
	"""Find a valid tile to spawn a unit, preferring the building location"""
	if not unit_manager or not unit_manager.has_unit_at(building_coord):
		return building_coord
	
	var directions = [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
	]
	
	for dir in directions:
		var coord = building_coord + dir
		if city.has_tile(coord):
			if not unit_manager.has_unit_at(coord):
				return coord
	
	if not unit_manager.has_unit_at(city.city_center_coord):
		return city.city_center_coord
	
	for coord in city.tiles.keys():
		if not unit_manager.has_unit_at(coord):
			return coord
	
	return Vector2i(-99999, -99999)

# === Phase 5: Population ===

func _phase_population(city: City, report: TurnReport.CityTurnReport):
	"""Update population derived from population-tagged resources in storage pools."""
	var pop_total = city.get_total_population()
	var pop_capacity = city.get_population_capacity()
	
	# Population change is already tracked through production/consumption/penalties
	# The population is simply whatever is stored in population-tagged pools
	# We just need to report on it
	
	# Calculate net change from production and penalties this turn
	var pop_change := 0.0
	var pop_resources = Registry.resources.get_resources_by_tag("population")
	for res_id in pop_resources:
		var produced = report.production_after_efficiency.get(res_id, 0.0)
		var penalty = report.penalties_applied.get(res_id, 0.0)
		pop_change += produced - penalty
	
	report.population_change = pop_change
	report.population_total = pop_total
	report.population_capacity = pop_capacity
	
	if pop_change != 0:
		print("  Population: %d (change: %+.0f, capacity: %d)" % [pop_total, pop_change, pop_capacity])

# === Phase 6: Decay ===

func _phase_decay(city: City, report: TurnReport.CityTurnReport):
	"""Apply decay to resources in storage buildings, including adjacency-based decay bonuses"""
	for coord in city.building_instances.keys():
		var instance: BuildingInstance = city.building_instances[coord]
		
		var adjacency_bonus = _calculate_adjacency_decay_bonus(city, coord, instance.building_id)
		
		var decayed = instance.apply_decay(adjacency_bonus)
		for resource_id in decayed.keys():
			report.add_decay(resource_id, decayed[resource_id])
	
	if not report.decay_summary.is_empty():
		print("  Decay: %s" % str(report.decay_summary))

func _calculate_adjacency_decay_bonus(city: City, coord: Vector2i, building_id: String) -> Dictionary:
	"""Calculate decay reduction bonuses from nearby active buildings."""
	var bonuses: Dictionary = {}
	
	var decay_bonus_rules = Registry.buildings.get_adjacency_decay_bonuses(building_id)
	if decay_bonus_rules.is_empty():
		return bonuses
	
	if not world_query:
		return bonuses
	
	for rule in decay_bonus_rules:
		var source_type: String = rule.get("source_type", "")
		var source_id: String = rule.get("source_id", "")
		var radius: int = rule.get("radius", 1)
		var requires_active: bool = rule.get("requires_active", true)
		var decay_reduction: Dictionary = rule.get("decay_reduction", {})
		
		if source_id == "" or decay_reduction.is_empty():
			continue
		
		var neighbors = world_query.get_tiles_in_range(coord, 1, radius)
		
		for neighbor_coord in neighbors:
			if not city.has_building(neighbor_coord):
				continue
			
			var neighbor_instance = city.get_building_instance(neighbor_coord)
			var matched = false
			
			match source_type:
				"building":
					matched = (neighbor_instance.building_id == source_id)
				"building_category":
					var neighbor_building = Registry.buildings.get_building(neighbor_instance.building_id)
					matched = (neighbor_building.get("category", "") == source_id)
			
			if matched:
				if requires_active and not neighbor_instance.is_active():
					continue
				
				for resource_id in decay_reduction.keys():
					bonuses[resource_id] = bonuses.get(resource_id, 0.0) + decay_reduction[resource_id]
	
	return bonuses

# === Global Research Processing ===

func _process_global_research(report: TurnReport):
	"""Aggregate knowledge from all cities and apply to tech tree."""
	var total_branch_research: Dictionary = {}  # branch_id -> points
	var total_generic_by_resource: Dictionary = {}  # resource_id -> points
	
	# Sum knowledge from all cities
	for city_id in report.city_reports.keys():
		var city_report = report.city_reports[city_id]
		
		# Branch-specific knowledge
		for res_id in city_report.knowledge_produced.keys():
			var branches = city_report.knowledge_produced[res_id]
			for branch_id in branches.keys():
				total_branch_research[branch_id] = total_branch_research.get(branch_id, 0.0) + branches[branch_id]
		
		# Generic knowledge
		for res_id in city_report.generic_knowledge_produced.keys():
			total_generic_by_resource[res_id] = total_generic_by_resource.get(res_id, 0.0) + city_report.generic_knowledge_produced[res_id]
	
	# Route generic knowledge to player's chosen branch
	# For each knowledge resource, check accepted_by_branches
	for res_id in total_generic_by_resource.keys():
		var amount = total_generic_by_resource[res_id]
		if amount <= 0.0:
			continue
		
		var target_branch = Registry.tech.get_generic_research_target()
		if target_branch == "":
			print("  Generic %s: %.2f lost (no visible branches)" % [res_id, amount])
			continue
		
		# Validate that this knowledge resource is accepted by the target branch
		var accepted = Registry.resources.get_accepted_branches(res_id)
		if "all" not in accepted and target_branch not in accepted:
			print("  Generic %s: %.2f lost (%s not accepted by branch %s)" % [res_id, amount, res_id, target_branch])
			continue
		
		total_branch_research[target_branch] = total_branch_research.get(target_branch, 0.0) + amount
		print("  Generic %s: %.2f -> %s" % [res_id, amount, target_branch])
		
		# Record in city reports for display
		for city_id in report.city_reports.keys():
			var city_report = report.city_reports[city_id]
			var city_generic = city_report.generic_knowledge_produced.get(res_id, 0.0)
			if city_generic > 0.0:
				city_report.set_generic_knowledge_target(res_id, target_branch)
				city_report.add_knowledge(res_id, target_branch, city_generic)
	
	# Apply to tech tree
	for branch_id in total_branch_research.keys():
		var points = total_branch_research[branch_id]
		Registry.tech.add_research(branch_id, points)
	
	# Check for milestone unlocks
	Registry.tech.check_milestone_unlocks()

# === City Abandonment ===

func _handle_city_abandonment(city: City, report: TurnReport):
	"""Handle a city being abandoned due to population reaching zero"""
	print("\n!!! CITY ABANDONED: %s !!!" % city.city_name)
	
	var previous_owner = city_manager.abandon_city(city.city_id)
	
	report.add_critical_alert(
		"city_abandoned",
		city.city_id,
		"%s has been abandoned! Population reached zero." % city.city_name,
		{"previous_owner": previous_owner.player_id if previous_owner else "none"}
	)
	
	emit_signal("city_abandoned", city, previous_owner)
	
	if previous_owner and previous_owner.get_city_count() == 0:
		report.add_critical_alert(
			"player_defeated",
			"",
			"%s has lost all their cities and is defeated!" % previous_owner.player_name,
			{"player_id": previous_owner.player_id}
		)
		emit_signal("player_defeated", previous_owner)

# === Alerts Generation ===

func _generate_city_alerts(city: City, city_report: TurnReport.CityTurnReport, report: TurnReport):
	"""Generate critical alerts based on city report"""
	
	# Cap overloads (generic for all cap resources)
	for cap_id in city_report.cap_reports.keys():
		var cap = city_report.cap_reports[cap_id]
		var ratio = cap.get("ratio", 0.0)
		if ratio > 1.5:
			var cap_name = Registry.get_name_label("resource", cap_id)
			var eff = cap.get("efficiency", 1.0)
			report.add_critical_alert(
				"cap_overload",
				city.city_id,
				"%s: %s severely overloaded (%.0f%% efficiency)" % [city.city_name, cap_name, eff * 100],
				{"resource": cap_id, "ratio": ratio}
			)
	
	# Buildings waiting for resources
	if not city_report.buildings_waiting.is_empty():
		var count = city_report.buildings_waiting.size()
		report.add_critical_alert(
			"resource_shortage",
			city.city_id,
			"%s: %d building(s) waiting for resources" % [city.city_name, count],
			{"buildings": city_report.buildings_waiting}
		)
	
	# Construction paused
	if not city_report.constructions_paused.is_empty():
		var count = city_report.constructions_paused.size()
		report.add_critical_alert(
			"construction_paused",
			city.city_id,
			"%s: %d construction(s) paused due to missing resources" % [city.city_name, count],
			{"constructions": city_report.constructions_paused}
		)
	
	# Construction queued
	if not city_report.constructions_queued.is_empty():
		var count = city_report.constructions_queued.size()
		report.add_critical_alert(
			"construction_queued",
			city.city_id,
			"%s: %d construction(s) waiting for building capacity" % [city.city_name, count],
			{"constructions": city_report.constructions_queued}
		)
	
	# Significant spillage
	var total_spillage = 0.0
	for amount in city_report.spillage.values():
		total_spillage += amount
	if total_spillage > 10.0:
		report.add_critical_alert(
			"spillage",
			city.city_id,
			"%s: %.0f resources lost to spillage (storage full)" % [city.city_name, total_spillage],
			{"spillage": city_report.spillage}
		)
	
	# Population decline
	if city_report.population_change < 0:
		report.add_critical_alert(
			"population_decline",
			city.city_id,
			"%s: Population declining! (%d)" % [city.city_name, city_report.population_change],
			{"change": city_report.population_change}
		)

# === Helper ===

func _record_resource_totals(city: City, report: TurnReport.CityTurnReport):
	"""Record the final resource totals after all processing"""
	for resource_id in Registry.resources.get_all_resource_ids():
		var total = city.get_total_resource(resource_id)
		if total > 0:
			report.resource_totals[resource_id] = total

func get_current_turn() -> int:
	return current_turn

func get_last_report() -> TurnReport:
	return last_report

# === Perk Unlock Detection ===

func _check_perk_unlocks(report: TurnReport):
	"""Check all players for newly unlockable perks."""
	for player in city_manager.get_all_players():
		var game_state = Registry.perks.build_game_state_for_player(
			player, city_manager, unit_manager, world_query, current_turn, last_report
		)

		for perk_id in Registry.perks.get_all_perk_ids():
			# Skip already-owned perks
			if player.has_perk(perk_id):
				continue

			if Registry.perks.check_unlock_conditions(perk_id, game_state):
				player.add_perk(perk_id)
				report.add_perk_unlocked(perk_id)
				print("  ★ Perk unlocked: %s (player: %s)" % [
					Registry.perks.get_perk_name(perk_id), player.player_name
				])

				# Apply one-time effects
				var perk = Registry.perks.get_perk(perk_id)
				var effects = perk.get("effects", {})
				var unlock_branch = effects.get("unlocks_tech_branch", null)
				if unlock_branch and unlock_branch is String and unlock_branch != "":
					# Tech branch unlocking via perks (reserved for future use)
					print("    Perk requests tech branch unlock: %s" % unlock_branch)

# === Trade Route Validation ===

func _validate_trade_routes(report: TurnReport):
	"""Validate all trade routes at the start of a turn.
	Remove routes with broken paths or dead convoys."""
	var routes_to_remove: Array[String] = []

	for route_id in trade_route_manager.routes.keys():
		var route: TradeRoute = trade_route_manager.routes[route_id]

		# Check for dead convoys (units that no longer exist)
		if unit_manager:
			var dead_convoys: Array[String] = []
			for convoy in route.convoys:
				var unit = unit_manager.get_unit(convoy.unit_id)
				if not unit or unit.current_health <= 0:
					dead_convoys.append(convoy.unit_id)

			for unit_id in dead_convoys:
				route.remove_convoy(unit_id)
				print("  Trade: Removed dead convoy %s from route %s" % [unit_id, route_id])

		# Check if path is still valid (all markers present)
		if not trade_route_manager.validate_route(route):
			routes_to_remove.append(route_id)
			var city_a = city_manager.get_city(route.city_a_id)
			var city_b = city_manager.get_city(route.city_b_id)
			var city_a_name = city_a.city_name if city_a else route.city_a_id
			var city_b_name = city_b.city_name if city_b else route.city_b_id
			report.add_critical_alert(
				"trade_route_broken",
				route.city_a_id,
				"Trade route %s <-> %s broken! Route markers missing." % [city_a_name, city_b_name],
				{"route_id": route_id, "city_a_id": route.city_a_id, "city_b_id": route.city_b_id}
			)
			print("  Trade: Route %s broken (markers missing)" % route_id)

		# Check if either city was abandoned
		var city_a = city_manager.get_city(route.city_a_id)
		var city_b = city_manager.get_city(route.city_b_id)
		if (city_a and city_a.is_abandoned) or (city_b and city_b.is_abandoned):
			if route_id not in routes_to_remove:
				routes_to_remove.append(route_id)
				print("  Trade: Route %s removed (city abandoned)" % route_id)

	# Remove broken routes
	for route_id in routes_to_remove:
		trade_route_manager.remove_route(route_id)
