extends RefCounted
class_name TurnManager

# Orchestrates the turn cycle for all cities

signal turn_started(turn_number: int)
signal turn_completed(report: TurnReport)
signal city_processed(city_id: String, city_report: TurnReport.CityTurnReport)

var current_turn: int = 0
var last_report: TurnReport = null

# Reference to city manager for accessing all cities
var city_manager: CityManager

func _init(p_city_manager: CityManager):
	city_manager = p_city_manager

func process_turn() -> TurnReport:
	"""Process a complete turn for all cities"""
	current_turn += 1
	
	var report = TurnReport.new()
	report.turn_number = current_turn
	
	emit_signal("turn_started", current_turn)
	print("\n========== TURN %d ==========" % current_turn)
	
	# Process each city
	for city in city_manager.get_all_cities():
		var city_report = _process_city_turn(city)
		report.add_city_report(city.city_id, city_report)
		
		# Generate critical alerts for this city
		_generate_city_alerts(city, city_report, report)
		
		emit_signal("city_processed", city.city_id, city_report)
	
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
	
	# Phase 3: Consumption (two-pass system, penalties if consumption fails)
	_phase_consumption(city, report)
	
	# Phase 4: Construction processing
	_phase_construction(city, report)
	
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
		
		# Calculate adjacency bonuses (future: implement properly)
		# var adjacency = _calculate_adjacency_bonuses(city, coord, instance.building_id)
		
		for resource_id in production.keys():
			var raw_amount = production[resource_id]
			var adjusted_amount = raw_amount * efficiency
			
			# Try to store the produced resources (partial storage supported)
			var stored = city.store_resource(resource_id, adjusted_amount)
			var spilled = adjusted_amount - stored
			
			report.add_production(resource_id, raw_amount, adjusted_amount)
			
			if spilled > 0:
				report.add_spillage(resource_id, spilled)
				print("    Spillage: %.1f %s (storage full)" % [spilled, resource_id])
	
	print("  Production complete (efficiency: %.0f%%)" % (efficiency * 100))

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
	"""Process construction for all buildings being built"""
	for coord in city.building_instances.keys():
		var instance: BuildingInstance = city.building_instances[coord]
		
		if not instance.is_under_construction():
			continue
		
		var cost = instance.cost_per_turn
		
		# If no per-turn cost, just advance construction
		if cost.is_empty():
			instance.set_constructing()
			var completed = instance.advance_construction()
			
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
			
			if completed:
				_on_construction_completed(city, instance, report)
			else:
				report.add_construction_progressed(coord, instance.building_id, instance.turns_remaining)
		else:
			# Pause construction
			instance.set_construction_paused()
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
