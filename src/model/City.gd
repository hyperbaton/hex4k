extends RefCounted
class_name City

# Represents a city with all its tiles, buildings, and resources

var city_id: String  # Unique identifier
var city_name: String
var owner: Player  # Reference to owning player

# Tiles
var tiles: Dictionary = {}  # Vector2i -> CityTile
var city_center_coord: Vector2i
var frontier_tiles: Array[Vector2i] = []  # Tiles at the edge of the city

# Resources
var resources: ResourceLedger

# Population
var population_stored: float = 0.0  # Current workforce available
var population_capacity: float = 0.0  # Max population (from housing)
var total_population: int = 0  # Actual population count

# Administrative capacity
var admin_capacity_available: float = 0.0  # Per-turn flow
var admin_capacity_used: float = 0.0

# Buildings under construction
var construction_queue: Array[Dictionary] = []  # [{tile_coord, building_id, turns_remaining, progress}]

func _init(id: String, name: String, center_coord: Vector2i):
	city_id = id
	city_name = name
	city_center_coord = center_coord
	resources = ResourceLedger.new()

func add_tile(coord: Vector2i, is_center: bool = false) -> CityTile:
	"""Add a tile to the city"""
	if tiles.has(coord):
		return tiles[coord]
	
	var tile = CityTile.new(coord)
	tile.is_city_center = is_center
	
	if is_center:
		tile.distance_from_center = 0
	else:
		tile.distance_from_center = calculate_distance_from_center(coord)
	
	tiles[coord] = tile
	update_frontier()
	return tile

func remove_tile(coord: Vector2i):
	"""Remove a tile from the city"""
	if coord == city_center_coord:
		push_error("Cannot remove city center!")
		return
	
	tiles.erase(coord)
	update_frontier()

func has_tile(coord: Vector2i) -> bool:
	return tiles.has(coord)

func get_tile(coord: Vector2i) -> CityTile:
	return tiles.get(coord)

func get_city_center() -> CityTile:
	return tiles.get(city_center_coord)

func get_all_tiles() -> Array[CityTile]:
	var result: Array[CityTile] = []
	for tile in tiles.values():
		result.append(tile)
	return result

func get_tile_count() -> int:
	return tiles.size()

func calculate_distance_from_center(coord: Vector2i) -> int:
	"""Calculate hex distance from city center"""
	var q_diff = abs(coord.x - city_center_coord.x)
	var r_diff = abs(coord.y - city_center_coord.y)
	var s_diff = abs((-coord.x - coord.y) - (-city_center_coord.x - city_center_coord.y))
	return int((q_diff + r_diff + s_diff) / 2)

func update_frontier():
	"""Update which tiles are at the frontier of the city"""
	frontier_tiles.clear()
	
	for coord in tiles.keys():
		if is_frontier_tile(coord):
			frontier_tiles.append(coord)

func is_frontier_tile(coord: Vector2i) -> bool:
	"""Check if a tile is at the frontier (has non-city neighbors)"""
	var neighbors = get_hex_neighbors(coord)
	for neighbor in neighbors:
		if not tiles.has(neighbor):
			return true
	return false

func get_hex_neighbors(coord: Vector2i) -> Array[Vector2i]:
	"""Get the 6 adjacent hex coordinates"""
	var neighbors: Array[Vector2i] = []
	var directions = [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
	]
	for dir in directions:
		neighbors.append(coord + dir)
	return neighbors

func is_contiguous(new_coord: Vector2i) -> bool:
	"""Check if adding this tile would keep the city contiguous"""
	if tiles.is_empty():
		return true
	
	var neighbors = get_hex_neighbors(new_coord)
	for neighbor in neighbors:
		if tiles.has(neighbor):
			return true
	return false

# === Building Management ===

func count_buildings(building_id: String) -> int:
	"""Count how many of a specific building exist in this city (built + under construction)"""
	var count = 0
	
	# Count completed buildings
	for tile in tiles.values():
		if tile.building_id == building_id:
			count += 1
	
	# Count buildings under construction
	for project in construction_queue:
		if project.building_id == building_id:
			count += 1
	
	return count

func is_tile_under_construction(coord: Vector2i) -> bool:
	"""Check if a tile has a building under construction"""
	for project in construction_queue:
		if project.tile_coord == coord:
			return true
	return false

func get_construction_at_tile(coord: Vector2i) -> Dictionary:
	"""Get the construction project at a tile, or empty dict if none"""
	for project in construction_queue:
		if project.tile_coord == coord:
			return project
	return {}

func can_place_building(coord: Vector2i, building_id: String) -> Dictionary:
	"""
	Check if a building can be placed at the given coordinate.
	Returns {can_place: bool, reason: String}
	Note: Terrain checks should be done by WorldQuery before calling this.
	"""
	# Check if tile exists in city
	if not has_tile(coord):
		return {can_place = false, reason = "Tile not in city"}
	
	var tile = get_tile(coord)
	
	# Check if tile already has a building
	if tile.has_building():
		return {can_place = false, reason = "Tile already has a building"}
	
	# Check if tile has construction in progress
	if is_tile_under_construction(coord):
		return {can_place = false, reason = "Construction already in progress"}
	
	# Check max per city limit
	var max_per_city = Registry.buildings.get_max_per_city(building_id)
	if max_per_city > 0:
		var current_count = count_buildings(building_id)
		if current_count >= max_per_city:
			var building_name = Registry.get_name_label("building", building_id)
			return {can_place = false, reason = "Maximum %s reached (%d)" % [building_name, max_per_city]}
	
	# Note: Terrain compatibility is checked by WorldQuery.can_build_here()
	# which has access to terrain data. We skip it here.
	
	# Check tech requirements
	var required_milestones = Registry.buildings.get_required_milestones(building_id)
	if not Registry.has_all_milestones(required_milestones):
		return {can_place = false, reason = "Missing technology"}
	
	# Check admin capacity
	var admin_cost = Registry.buildings.get_admin_cost(building_id, tile.distance_from_center)
	if admin_cost > get_available_admin_capacity():
		return {can_place = false, reason = "Insufficient administrative capacity"}
	
	# Check initial construction cost
	var initial_cost = Registry.buildings.get_initial_construction_cost(building_id)
	for resource_id in initial_cost.keys():
		var cost = initial_cost[resource_id]
		if not resources.has_resource(resource_id, cost):
			var resource_name = Registry.get_name_label("resource", resource_id)
			return {can_place = false, reason = "Insufficient %s (need %d)" % [resource_name, cost]}
	
	return {can_place = true, reason = ""}

func start_construction(coord: Vector2i, building_id: String) -> bool:
	"""Start building construction at the given tile"""
	var check = can_place_building(coord, building_id)
	if not check.can_place:
		push_warning("Cannot build %s at %v: %s" % [building_id, coord, check.reason])
		return false
	
	# Deduct initial construction cost
	var initial_cost = Registry.buildings.get_initial_construction_cost(building_id)
	for resource_id in initial_cost.keys():
		var cost = initial_cost[resource_id]
		resources.add_stored(resource_id, -cost)
		print("  Deducted initial cost: ", resource_id, " x", cost)
	
	# Add to construction queue
	construction_queue.append({
		tile_coord = coord,
		building_id = building_id,
		turns_remaining = Registry.buildings.get_construction_turns(building_id),
		cost_per_turn = Registry.buildings.get_construction_cost(building_id)
	})
	
	return true

func complete_building(coord: Vector2i, building_id: String):
	"""Complete a building and add it to the tile"""
	var tile = get_tile(coord)
	if tile:
		tile.set_building(building_id)
		recalculate_city_stats()

func demolish_building(coord: Vector2i):
	"""Demolish a building at the given tile"""
	var tile = get_tile(coord)
	if tile and tile.has_building():
		tile.remove_building()
		recalculate_city_stats()

# === Resource Management ===

func get_terrain_at_tile(coord: Vector2i) -> String:
	"""Get terrain type at tile coordinates - must be implemented via World"""
	# This will need to query the world's tile data
	# For now, return empty string
	return ""

func recalculate_city_stats():
	"""Recalculate all city statistics (call after any building changes)"""
	resources.clear_flows()
	population_capacity = 0.0
	admin_capacity_available = 0.0
	admin_capacity_used = 0.0
	
	# Reset storage capacity
	for resource_id in Registry.resources.get_all_resource_ids():
		resources.set_storage_capacity(resource_id, 0.0)
	
	# Calculate from each tile
	for tile in get_all_tiles():
		# Admin cost for claiming the tile (non-center tiles)
		if not tile.is_city_center:
			var tile_admin_cost = calculate_tile_claim_cost(tile.distance_from_center)
			admin_capacity_used += tile_admin_cost
		
		if not tile.has_building():
			continue
		
		var building_id = tile.building_id
		print("  Processing building: ", building_id, " at ", tile.tile_coord)
		
		# Production
		var produces = Registry.buildings.get_production_per_turn(building_id)
		for resource_id in produces.keys():
			resources.add_production(resource_id, produces[resource_id])
		
		# Consumption
		var consumes = Registry.buildings.get_consumption_per_turn(building_id)
		for resource_id in consumes.keys():
			resources.add_consumption(resource_id, consumes[resource_id])
		
		# Storage capacity
		var storage = Registry.buildings.get_storage_provided(building_id)
		for resource_id in storage.keys():
			var current_capacity = resources.get_storage_capacity(resource_id)
			resources.set_storage_capacity(resource_id, current_capacity + storage[resource_id])
		
		# Population capacity
		population_capacity += Registry.buildings.get_population_capacity(building_id)
		
		# Admin capacity
		var admin_cap = Registry.buildings.get_admin_capacity(building_id)
		print("    Admin capacity from building: ", admin_cap)
		admin_capacity_available += admin_cap
		
		# Admin cost for the building
		var admin_cost = Registry.buildings.get_admin_cost(building_id, tile.distance_from_center)
		admin_capacity_used += admin_cost
	
	print("  Final admin capacity: ", admin_capacity_available, " / used: ", admin_capacity_used)
	
	# Calculate decay for perishable resources
	calculate_decay()

func calculate_tile_claim_cost(distance: int) -> float:
	"""Calculate the admin cost to claim/maintain a tile based on distance"""
	var base_cost = 1.0
	var distance_multiplier = 0.5
	return base_cost + (distance * distance_multiplier)

func calculate_decay():
	"""Calculate decay for perishable resources"""
	for resource_id in resources.total_stored.keys():
		if not Registry.resources.is_storable(resource_id):
			continue
		
		var resource_data = Registry.resources.get_resource(resource_id)
		if not resource_data.has("storage"):
			continue
		
		var decay_data = resource_data.storage.get("decay", {})
		if not decay_data.get("enabled", false):
			continue
		
		var base_decay_rate = decay_data.get("base_rate_per_turn", 0.0)
		
		# TODO: Apply decay reduction from storage buildings
		var actual_decay_rate = base_decay_rate
		
		var stored = resources.get_stored(resource_id)
		var decay_amount = stored * actual_decay_rate
		
		resources.add_decay(resource_id, decay_amount)

func get_available_admin_capacity() -> float:
	return max(0.0, admin_capacity_available - admin_capacity_used)

func process_turn():
	"""Process end-of-turn for this city"""
	# 1. Process construction
	process_construction()
	
	# 2. Calculate production/consumption
	recalculate_city_stats()
	
	# 3. Check if buildings can consume (disable if not)
	check_building_consumption()
	
	# 4. Apply resource changes
	apply_resource_changes()
	
	# 5. Update population
	update_population()

func process_construction():
	"""Advance construction projects"""
	var completed = []
	
	for i in range(construction_queue.size()):
		var project = construction_queue[i]
		
		# Try to pay this turn's cost
		var can_afford = true
		for resource_id in project.cost_per_turn.keys():
			var cost = project.cost_per_turn[resource_id]
			if not resources.has_resource(resource_id, cost):
				can_afford = false
				break
		
		if can_afford:
			# Deduct costs
			for resource_id in project.cost_per_turn.keys():
				var cost = project.cost_per_turn[resource_id]
				resources.add_stored(resource_id, -cost)
			
			# Advance construction
			project.turns_remaining -= 1
			
			if project.turns_remaining <= 0:
				complete_building(project.tile_coord, project.building_id)
				completed.append(i)
	
	# Remove completed projects (reverse order to maintain indices)
	completed.reverse()
	for idx in completed:
		construction_queue.remove_at(idx)

func check_building_consumption():
	"""Check if buildings can consume resources, disable if not"""
	# This will be implemented when we add building states
	pass

func apply_resource_changes():
	"""Apply all resource changes from production, consumption, trade, decay"""
	for resource_id in resources.get_all_resources():
		var change = resources.get_net_change(resource_id)
		resources.add_stored(resource_id, change)

func update_population():
	"""Update population based on production/consumption"""
	var pop_change = resources.get_internal_change("population")
	population_stored = clamp(population_stored + pop_change, 0.0, population_capacity)
	
	# Update total population count (integer representation)
	total_population = int(population_stored)
