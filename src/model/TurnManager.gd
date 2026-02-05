extends RefCounted
class_name TurnManager

# Orchestrates the turn cycle for all cities

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

func _init(p_city_manager: CityManager, p_unit_manager: UnitManager = null, p_world_query: Node = null):
	city_manager = p_city_manager
	unit_manager = p_unit_manager
	world_query = p_world_query

func process_turn() -> TurnReport:
	"""Process a complete turn for all cities"""
	current_turn += 1
	
	var report = TurnReport.new()
	report.turn_number = current_turn
	
	emit_signal("turn_started", current_turn)
	print("\n========== TURN %d ==========" % current_turn)
	
	# Process unit turn start (refresh movement, etc.)
	if unit_manager:
		# For now, process all units (could be per-player in multiplayer)
		for unit in unit_manager.get_all_units():
			unit.start_turn()
		print("  Units refreshed: %d" % unit_manager.get_all_units().size())
	
	# Process each city (skip abandoned cities)
	var cities_to_abandon: Array[City] = []
	
	for city in city_manager.get_all_cities():
		# Skip abandoned cities - they don't participate in the turn cycle
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
	
	last_report = report
	emit_signal("turn_completed", report)
	
	print("\n" + report.get_summary())
	print("========== END TURN %d ==========\n" % current_turn)
	
	return report

func _process_city_turn(city: City) -> TurnReport.CityTurnReport:
	"""Process a single city's turn"""
	var report = TurnReport.CityTurnReport.new(city.city_id, city.city_name)
	
	print("\n--- Processing City: %s ---" % city.city_name)
	
	# Phase 1: Calculate admin capacity and efficiency
	_phase_admin_capacity(city, report)
	
	# Phase 2: Production (all operational buildings produce FIRST)
	_phase_production(city, report)
	
	# Phase 2b: Modifier consumption (active buildings may consume nearby modifiers)
	_phase_modifier_consumption(city, report)
	
	# Phase 3: Consumption (two-pass system, penalties if consumption fails)
	_phase_consumption(city, report)
	
	# Phase 4: Construction processing
	_phase_construction(city, report)
	
	# Phase 4b: Upgrade processing
	_phase_upgrades(city, report)
	
	# Phase 4c: Training processing
	_phase_training(city, report)
	
	# Phase 5: Population update
	_phase_population(city, report)
	
	# Phase 6: Research generation (only from ACTIVE buildings)
	_phase_research(city, report)
	
	# Phase 7: Resource decay
	_phase_decay(city, report)
	
	# Record final resource totals
	_record_resource_totals(city, report)
	
	return report

# === Phase 1: Admin Capacity ===

func _phase_admin_capacity(city: City, report: TurnReport.CityTurnReport):
	"""Calculate admin capacity usage and production efficiency"""
	var used: float = 0.0
	var available: float = 0.0
	
	# Calculate available admin capacity from buildings
	for coord in city.building_instances.keys():
		var instance: BuildingInstance = city.building_instances[coord]
		if instance.is_operational() or instance.is_under_construction():
			available += Registry.buildings.get_admin_capacity(instance.building_id)
	
	# Calculate used admin capacity
	# First: tile costs (all tiles cost admin)
	for coord in city.tiles.keys():
		var tile: CityTile = city.tiles[coord]
		if not tile.is_city_center:
			used += city.calculate_tile_claim_cost(tile.distance_from_center)
	
	# Second: building costs
	for coord in city.building_instances.keys():
		var instance: BuildingInstance = city.building_instances[coord]
		var tile: CityTile = city.tiles.get(coord)
		var distance = tile.distance_from_center if tile else 0
		used += instance.get_admin_cost(distance)
	
	# Calculate ratio and efficiency
	var ratio = used / max(available, 0.001)  # Avoid division by zero
	var efficiency = _calculate_production_efficiency(ratio)
	
	report.admin_capacity_used = used
	report.admin_capacity_available = available
	report.admin_ratio = ratio
	report.production_efficiency = efficiency
	
	city.admin_capacity_used = used
	city.admin_capacity_available = available
	
	print("  Admin: %.1f / %.1f (ratio: %.2f, efficiency: %.0f%%)" % [used, available, ratio, efficiency * 100])

func _calculate_production_efficiency(admin_ratio: float) -> float:
	"""
	Calculate production efficiency based on admin ratio.
	f(1.0) = 100%, f(1.5) ≈ 50%, f(2.0) ≈ 0%
	"""
	if admin_ratio <= 1.0:
		return 1.0
	
	var overage = admin_ratio - 1.0
	var penalty = pow(overage, 1.5)  # Non-linear curve
	return clamp(1.0 - penalty, 0.0, 1.0)

# === Phase 2: Production ===

func _phase_production(city: City, report: TurnReport.CityTurnReport):
	"""Only ACTIVE buildings produce. EXPECTING_RESOURCES buildings skip production."""
	var efficiency = report.production_efficiency
	
	for coord in city.building_instances.keys():
		var instance: BuildingInstance = city.building_instances[coord]
		
		# Only ACTIVE buildings produce (not EXPECTING_RESOURCES)
		if not instance.can_produce():
			continue
		
		var production = instance.get_production()
		if production.is_empty():
			continue
		
		# Calculate all production bonuses for this building
		var bonuses = _calculate_production_bonuses(city, coord, instance.building_id)
		
		for resource_id in production.keys():
			var base_amount = production[resource_id]
			var bonus_amount = bonuses.get(resource_id, 0.0)
			var raw_amount = base_amount + bonus_amount
			var adjusted_amount = raw_amount * efficiency
			
			# Try to store the produced resources (partial storage supported)
			var stored = city.store_resource(resource_id, adjusted_amount)
			var spilled = adjusted_amount - stored
			
			report.add_production(resource_id, raw_amount, adjusted_amount)
			
			if bonus_amount > 0:
				print("    %s: base %.1f + bonus %.1f = %.1f" % [resource_id, base_amount, bonus_amount, raw_amount])
			
			if spilled > 0:
				report.add_spillage(resource_id, spilled)
				print("    Spillage: %.1f %s (storage full)" % [spilled, resource_id])
	
	print("  Production complete (efficiency: %.0f%%)" % (efficiency * 100))

func _calculate_production_bonuses(city: City, coord: Vector2i, building_id: String) -> Dictionary:
	"""
	Calculate all production bonuses for a building at a specific location.
	Includes: terrain bonuses, modifier bonuses, and adjacency bonuses.
	Returns: Dictionary of resource_id -> bonus_amount
	"""
	var bonuses: Dictionary = {}
	
	# Get terrain data if world_query is available
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
		
		# Count matching adjacent sources
		var matching_count = _count_adjacent_sources(coord, source_type, source_id, radius, city)
		
		if matching_count > 0:
			for resource_id in yields.keys():
				var bonus_per_source = yields[resource_id]
				bonuses[resource_id] = bonuses.get(resource_id, 0.0) + (bonus_per_source * matching_count)
	
	return bonuses

func _count_adjacent_sources(coord: Vector2i, source_type: String, source_id: String, radius: int, city: City) -> int:
	"""Count how many matching sources are adjacent to a tile"""
	var count = 0
	
	if not world_query:
		return count
	
	# Get all tiles within radius
	var neighbors = world_query.get_tiles_in_range(coord, 1, radius)
	
	for neighbor_coord in neighbors:
		var matched = false
		
		match source_type:
			"terrain":
				# Check terrain type
				var terrain_id = world_query.get_terrain_id(neighbor_coord)
				matched = (terrain_id == source_id)
			
			"modifier":
				# Check for modifier on tile
				var neighbor_data = world_query.get_terrain_data(neighbor_coord)
				if neighbor_data:
					matched = neighbor_data.has_modifier(source_id)
			
			"building":
				# Check for building
				if city.has_building(neighbor_coord):
					var neighbor_instance = city.get_building_instance(neighbor_coord)
					matched = (neighbor_instance.building_id == source_id)
			
			"building_category":
				# Check for building category
				if city.has_building(neighbor_coord):
					var neighbor_instance = city.get_building_instance(neighbor_coord)
					var neighbor_building = Registry.buildings.get_building(neighbor_instance.building_id)
					matched = (neighbor_building.get("category", "") == source_id)
			
			"river":
				# Check for river
				var neighbor_data = world_query.get_terrain_data(neighbor_coord)
				if neighbor_data:
					matched = neighbor_data.is_river
		
		if matched:
			count += 1
	
	return count

# === Phase 2b: Modifier Consumption ===

func _phase_modifier_consumption(city: City, report: TurnReport.CityTurnReport):
	"""Active buildings may consume nearby modifiers each turn based on chance.
	This represents resource exploitation (deforestation, mining depletion, etc.)."""
	if not world_query:
		return
	
	for coord in city.building_instances.keys():
		var instance: BuildingInstance = city.building_instances[coord]
		
		# Only active buildings consume modifiers
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
			
			# Check own tile first, then tiles within radius
			var tiles_to_check: Array[Vector2i] = [coord]
			if radius > 0:
				tiles_to_check.append_array(world_query.get_tiles_in_range(coord, 1, radius))
			
			for target_coord in tiles_to_check:
				var terrain_data = world_query.get_terrain_data(target_coord)
				if not terrain_data:
					continue
				
				if not terrain_data.has_modifier(modifier_id):
					continue
				
				# Roll the dice
				var roll = randf() * 100.0
				if roll < chance_percent:
					# Consume the modifier
					terrain_data.remove_modifier(modifier_id)
					
					if transforms_to != "":
						terrain_data.add_modifier(transforms_to)
						report.add_modifier_consumed(coord, instance.building_id, target_coord, modifier_id, transforms_to)
						print("    Modifier consumed: %s -> %s at %v (by %s)" % [modifier_id, transforms_to, target_coord, instance.building_id])
					else:
						report.add_modifier_consumed(coord, instance.building_id, target_coord, modifier_id, "")
						print("    Modifier consumed: %s removed at %v (by %s)" % [modifier_id, target_coord, instance.building_id])

# === Phase 3: Consumption ===

func _phase_consumption(city: City, report: TurnReport.CityTurnReport):
	"""Two-pass consumption system"""
	
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
	
	# Pass 2: Process EXPECTING_RESOURCES buildings (from original list)
	for coord in expecting_buildings:
		var instance: BuildingInstance = city.building_instances[coord]
		_process_building_consumption(city, instance, report)

func _process_building_consumption(city: City, instance: BuildingInstance, report: TurnReport.CityTurnReport):
	"""Process consumption for a single building"""
	var consumption = instance.get_consumption()
	
	if consumption.is_empty():
		# No consumption needed - ensure building is active
		if not instance.is_active():
			instance.set_active()
			report.add_building_activated(instance.tile_coord, instance.building_id)
		return
	
	# Check if city has all required resources
	var can_consume = true
	var missing: Dictionary = {}
	
	for resource_id in consumption.keys():
		var needed = consumption[resource_id]
		var available = city.get_total_resource(resource_id)
		if available < needed:
			can_consume = false
			missing[resource_id] = needed - available
	
	if can_consume:
		# Consume resources
		for resource_id in consumption.keys():
			var amount = consumption[resource_id]
			city.consume_resource(resource_id, amount)
			report.add_consumption(resource_id, amount)
		
		# Activate the building
		if not instance.is_active():
			instance.set_active()
			report.add_building_activated(instance.tile_coord, instance.building_id)
	else:
		# Cannot consume - apply penalty and set to expecting
		instance.set_expecting_resources()
		report.add_building_waiting(instance.tile_coord, instance.building_id, missing)
		
		# Apply penalty if defined
		var penalty = instance.get_penalty()
		if not penalty.is_empty():
			for resource_id in penalty.keys():
				var penalty_amount = penalty[resource_id]
				# Penalties remove from storage
				city.consume_resource(resource_id, penalty_amount)
				report.add_penalty(resource_id, penalty_amount)
			
			report.add_building_penalized(instance.tile_coord, instance.building_id, penalty)
			print("    Penalty applied: %s at %v" % [instance.building_id, instance.tile_coord])

# === Phase 4: Construction ===

func _phase_construction(city: City, report: TurnReport.CityTurnReport):
	"""Process construction for buildings being built, limited by building capacity.
	Only the first X constructions in the queue progress each turn,
	where X = total building capacity from operational buildings."""
	var building_capacity = city.get_total_building_capacity()
	var construction_coords = city.get_constructions_in_progress()
	var constructions_processed: int = 0
	
	print("  Building capacity: %d, constructions queued: %d" % [building_capacity, construction_coords.size()])
	
	for coord in construction_coords:
		var instance: BuildingInstance = city.building_instances[coord]
		
		# Check if we've hit the building capacity limit
		if constructions_processed >= building_capacity:
			# This construction is queued but cannot progress this turn
			report.add_construction_queued(coord, instance.building_id, instance.turns_remaining)
			print("    Construction queued (no capacity): %s at %v" % [instance.building_id, coord])
			continue
		
		var cost = instance.cost_per_turn
		
		# If no per-turn cost, just advance construction
		if cost.is_empty():
			instance.set_constructing()
			var completed = instance.advance_construction()
			constructions_processed += 1
			
			if completed:
				_on_construction_completed(city, instance, report)
			else:
				report.add_construction_progressed(coord, instance.building_id, instance.turns_remaining)
			continue
		
		# Check if city can afford this turn's cost
		var can_afford = true
		var missing: Dictionary = {}
		
		for resource_id in cost.keys():
			var needed = cost[resource_id]
			var available = city.get_total_resource(resource_id)
			if available < needed:
				can_afford = false
				missing[resource_id] = needed - available
		
		if can_afford:
			# Consume resources
			for resource_id in cost.keys():
				city.consume_resource(resource_id, cost[resource_id])
			
			# Advance construction
			instance.set_constructing()
			var completed = instance.advance_construction()
			constructions_processed += 1
			
			if completed:
				_on_construction_completed(city, instance, report)
			else:
				report.add_construction_progressed(coord, instance.building_id, instance.turns_remaining)
		else:
			# Pause construction (still uses a capacity slot)
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
	
	# Apply on_construction_complete rewards
	var rewards = Registry.buildings.get_on_construction_complete(building_id)
	if rewards.is_empty():
		return
	
	# Apply resource rewards - store in city
	if rewards.has("resources"):
		for resource_id in rewards.resources.keys():
			var amount = rewards.resources[resource_id]
			var stored = city.store_resource(resource_id, amount)
			report.add_completion_reward(resource_id, stored)
			if stored > 0:
				print("      Reward: +%.1f %s" % [stored, resource_id])
	
	# Apply research rewards - add directly to tech tree
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
		
		# If no per-turn cost, just advance the upgrade
		if cost.is_empty():
			var completed = instance.advance_upgrade()
			
			if completed:
				_on_upgrade_completed(city, instance, report)
			else:
				report.add_upgrade_progressed(coord, instance.building_id, instance.upgrading_to, instance.upgrade_turns_remaining)
			continue
		
		# Check if city can afford this turn's cost
		var can_afford = true
		var missing: Dictionary = {}
		
		for resource_id in cost.keys():
			var needed = cost[resource_id]
			var available = city.get_total_resource(resource_id)
			if available < needed:
				can_afford = false
				missing[resource_id] = needed - available
		
		if can_afford:
			# Consume resources
			for resource_id in cost.keys():
				city.consume_resource(resource_id, cost[resource_id])
			
			# Advance upgrade
			var completed = instance.advance_upgrade()
			
			if completed:
				_on_upgrade_completed(city, instance, report)
			else:
				report.add_upgrade_progressed(coord, instance.building_id, instance.upgrading_to, instance.upgrade_turns_remaining)
		else:
			# Can't afford - upgrade is paused this turn (but building still operates)
			report.add_upgrade_paused(coord, instance.building_id, instance.upgrading_to, missing)
			print("    Upgrade paused: %s at %v (missing resources)" % [instance.building_id, coord])

func _on_upgrade_completed(city: City, instance: BuildingInstance, report: TurnReport.CityTurnReport):
	"""Handle building upgrade completion"""
	var coord = instance.tile_coord
	var old_building_id = instance.building_id
	var new_building_id = instance.upgrading_to
	
	# Complete the upgrade (transforms the building)
	instance.complete_upgrade()
	
	# Update tile reference
	var tile = city.get_tile(coord)
	if tile:
		tile.building_id = new_building_id
	
	report.add_upgrade_completed(coord, old_building_id, new_building_id)
	print("    Upgrade completed: %s -> %s at %v" % [old_building_id, new_building_id, coord])
	
	# Apply on_construction_complete rewards for the new building
	var rewards = Registry.buildings.get_on_construction_complete(new_building_id)
	if rewards.is_empty():
		return
	
	# Apply resource rewards
	if rewards.has("resources"):
		for resource_id in rewards.resources.keys():
			var amount = rewards.resources[resource_id]
			var stored = city.store_resource(resource_id, amount)
			report.add_completion_reward(resource_id, stored)
			if stored > 0:
				print("      Reward: +%.1f %s" % [stored, resource_id])
	
	# Apply research rewards
	if rewards.has("research"):
		for branch_id in rewards.research.keys():
			var points = rewards.research[branch_id]
			Registry.tech.add_research(branch_id, points)
			report.add_completion_research_reward(branch_id, points)
			print("      Research reward: +%.2f %s" % [points, branch_id])

# === Phase 4c: Training ===

func _phase_training(city: City, report: TurnReport.CityTurnReport):
	"""Process unit training for all buildings in the city"""
	for coord in city.building_instances.keys():
		var instance: BuildingInstance = city.building_instances[coord]
		
		if not instance.is_training():
			continue
		
		var unit_id = instance.training_unit_id
		var turns_remaining = instance.training_turns_remaining
		
		# Process one turn of training
		var completed_unit_type = instance.advance_training()
		
		if completed_unit_type != "":
			# Training completed - spawn unit!
			_on_training_completed(city, completed_unit_type, coord, report)
		else:
			# Still training
			print("    Training %s at %v: %d turns remaining" % [unit_id, coord, turns_remaining - 1])

func _on_training_completed(city: City, unit_type: String, building_coord: Vector2i, report: TurnReport.CityTurnReport):
	"""Handle unit training completion - spawn the unit"""
	print("    Training completed: %s at %v" % [Registry.units.get_unit_name(unit_type), building_coord])
	
	# Find spawn location (building tile first, then adjacent, then city center)
	var spawn_coord = _find_unit_spawn_location(city, building_coord)
	
	if spawn_coord == Vector2i(-99999, -99999):  # Invalid coord sentinel
		print("      Warning: No valid spawn location found!")
		return
	
	# Spawn the unit if we have a unit manager
	if unit_manager:
		var owner_id = city.owner.player_id if city.owner else "unknown"
		var unit = unit_manager.spawn_unit(unit_type, owner_id, spawn_coord, city.city_id)
		if unit:
			print("      Spawned %s at %v" % [unit_type, spawn_coord])
			# Add to report (we could add training-related tracking to TurnReport)
	else:
		print("      Warning: No unit manager - unit not spawned")

func _find_unit_spawn_location(city: City, building_coord: Vector2i) -> Vector2i:
	"""Find a valid tile to spawn a unit, preferring the building location"""
	# First try the building's tile
	if not unit_manager or not unit_manager.has_unit_at(building_coord):
		return building_coord
	
	# Try adjacent tiles to the building
	var directions = [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
	]
	
	for dir in directions:
		var coord = building_coord + dir
		if city.has_tile(coord):
			if not unit_manager.has_unit_at(coord):
				return coord
	
	# Try city center
	if not unit_manager.has_unit_at(city.city_center_coord):
		return city.city_center_coord
	
	# Try any city tile
	for coord in city.tiles.keys():
		if not unit_manager.has_unit_at(coord):
			return coord
	
	# No valid location found
	return Vector2i(-99999, -99999)

# === Phase 5: Population ===

func _phase_population(city: City, report: TurnReport.CityTurnReport):
	"""Update city population count based on population-flagged resources"""
	var pop_change: float = 0.0
	var pop_capacity: int = 0
	
	# Calculate total population capacity from housing
	for coord in city.building_instances.keys():
		var instance: BuildingInstance = city.building_instances[coord]
		if instance.is_operational():
			pop_capacity += Registry.buildings.get_population_capacity(instance.building_id)
	
	# Sum production and penalties for population-flagged resources
	for resource_id in Registry.resources.get_all_population_resources():
		# Get net change from production and penalties
		var produced = report.production_after_efficiency.get(resource_id, 0.0)
		var penalty = report.penalties_applied.get(resource_id, 0.0)
		pop_change += produced - penalty
	
	# Apply population change
	var old_pop = city.total_population
	city.total_population = clampi(city.total_population + int(pop_change), 0, pop_capacity)
	city.population_capacity = pop_capacity
	
	report.population_change = city.total_population - old_pop
	report.population_total = city.total_population
	report.population_capacity = pop_capacity
	
	if report.population_change != 0:
		print("  Population: %d → %d (capacity: %d)" % [old_pop, city.total_population, pop_capacity])

# === Phase 6: Research ===

func _phase_research(city: City, report: TurnReport.CityTurnReport):
	"""Collect research from ACTIVE buildings only"""
	var efficiency = report.production_efficiency
	
	for coord in city.building_instances.keys():
		var instance: BuildingInstance = city.building_instances[coord]
		
		# Only ACTIVE buildings generate research (not EXPECTING_RESOURCES)
		if not instance.is_active():
			continue
		
		var research = instance.get_research_output()
		for branch_id in research.keys():
			var raw_points = research[branch_id]
			var adjusted_points = raw_points * efficiency
			report.add_research(branch_id, adjusted_points)
	
	if not report.research_generated.is_empty():
		print("  Research generated: %s" % str(report.research_generated))

# === Phase 7: Decay ===

func _phase_decay(city: City, report: TurnReport.CityTurnReport):
	"""Apply decay to resources in storage buildings"""
	for coord in city.building_instances.keys():
		var instance: BuildingInstance = city.building_instances[coord]
		
		var decayed = instance.apply_decay()
		for resource_id in decayed.keys():
			report.add_decay(resource_id, decayed[resource_id])
	
	if not report.decay_summary.is_empty():
		print("  Decay: %s" % str(report.decay_summary))

# === Global Research Processing ===

func _process_global_research(report: TurnReport):
	"""Aggregate research from all cities and apply to tech tree"""
	var total_research: Dictionary = {}
	
	# Sum research from all cities
	for city_id in report.city_reports.keys():
		var city_report = report.city_reports[city_id]
		for branch_id in city_report.research_generated.keys():
			var points = city_report.research_generated[branch_id]
			total_research[branch_id] = total_research.get(branch_id, 0.0) + points
	
	# Apply to tech tree
	for branch_id in total_research.keys():
		var points = total_research[branch_id]
		Registry.tech.add_research(branch_id, points)
	
	# Check for newly unlocked milestones
	Registry.tech.check_milestone_unlocks()

# === City Abandonment ===

func _handle_city_abandonment(city: City, report: TurnReport):
	"""Handle a city being abandoned due to population reaching zero"""
	print("\n!!! CITY ABANDONED: %s !!!" % city.city_name)
	
	# Use CityManager to handle the abandonment
	var previous_owner = city_manager.abandon_city(city.city_id)
	
	# Add critical alert
	report.add_critical_alert(
		"city_abandoned",
		city.city_id,
		"%s has been abandoned! Population reached zero." % city.city_name,
		{"previous_owner": previous_owner.player_id if previous_owner else "none"}
	)
	
	# Emit signals
	emit_signal("city_abandoned", city, previous_owner)
	
	# Check if player was defeated
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
	
	# Admin overload
	if city_report.admin_ratio > 1.5:
		report.add_critical_alert(
			"admin_overload",
			city.city_id,
			"%s: Admin capacity severely overloaded (%.0f%% efficiency)" % [city.city_name, city_report.production_efficiency * 100],
			{"ratio": city_report.admin_ratio}
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
	
	# Construction queued (no building capacity)
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
