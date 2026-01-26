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

# Buildings (using BuildingInstance for status tracking)
var building_instances: Dictionary = {}  # Vector2i -> BuildingInstance

# Population
var total_population: int = 0  # Current population count
var population_capacity: int = 0  # Max population (from housing)

# Administrative capacity
var admin_capacity_available: float = 0.0
var admin_capacity_used: float = 0.0

# Legacy resource ledger (for compatibility, will be phased out)
var resources: ResourceLedger

func _init(id: String, name: String, center_coord: Vector2i):
	city_id = id
	city_name = name
	city_center_coord = center_coord
	resources = ResourceLedger.new()

# === Tile Management ===

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

func calculate_tile_claim_cost(distance: int) -> float:
	"""Calculate the admin cost to claim/maintain a tile based on distance"""
	var base_cost = 1.0
	var distance_multiplier = 0.5
	return base_cost + (distance * distance_multiplier)

# === Building Management ===

func get_building_instance(coord: Vector2i) -> BuildingInstance:
	"""Get the building instance at a coordinate"""
	return building_instances.get(coord)

func has_building(coord: Vector2i) -> bool:
	"""Check if there's a building at the coordinate"""
	return building_instances.has(coord)

func count_buildings(building_id: String) -> int:
	"""Count how many of a specific building exist (any status)"""
	var count = 0
	for instance in building_instances.values():
		if instance.building_id == building_id:
			count += 1
	return count

func is_tile_under_construction(coord: Vector2i) -> bool:
	"""Check if a tile has a building under construction"""
	var instance = building_instances.get(coord)
	if instance:
		return instance.is_under_construction()
	return false

func can_place_building(coord: Vector2i, building_id: String) -> Dictionary:
	"""
	Check if a building can be placed at the given coordinate.
	Returns {can_place: bool, reason: String}
	"""
	# Check if tile exists in city
	if not has_tile(coord):
		return {can_place = false, reason = "Tile not in city"}
	
	# Check if tile already has a building
	if has_building(coord):
		return {can_place = false, reason = "Tile already has a building"}
	
	# Check max per city limit
	var max_per_city = Registry.buildings.get_max_per_city(building_id)
	if max_per_city > 0:
		var current_count = count_buildings(building_id)
		if current_count >= max_per_city:
			var building_name = Registry.get_name_label("building", building_id)
			return {can_place = false, reason = "Maximum %s reached (%d)" % [building_name, max_per_city]}
	
	# Check tech requirements
	var required_milestones = Registry.buildings.get_required_milestones(building_id)
	if not Registry.has_all_milestones(required_milestones):
		return {can_place = false, reason = "Missing technology"}
	
	# Check admin capacity
	var tile = get_tile(coord)
	var admin_cost = Registry.buildings.get_admin_cost(building_id, tile.distance_from_center)
	if admin_cost > get_available_admin_capacity():
		return {can_place = false, reason = "Insufficient administrative capacity"}
	
	# Check initial construction cost
	var initial_cost = Registry.buildings.get_initial_construction_cost(building_id)
	for resource_id in initial_cost.keys():
		var cost = initial_cost[resource_id]
		if get_total_resource(resource_id) < cost:
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
		consume_resource(resource_id, cost)
		print("  Deducted initial cost: ", resource_id, " x", cost)
	
	# Create building instance
	var instance = BuildingInstance.new(building_id, coord)
	instance.start_construction(
		Registry.buildings.get_construction_turns(building_id),
		Registry.buildings.get_construction_cost(building_id)
	)
	
	building_instances[coord] = instance
	
	# Update tile reference (for visual compatibility)
	var tile = get_tile(coord)
	if tile:
		tile.building_id = building_id
	
	return true

func demolish_building(coord: Vector2i):
	"""Demolish a building at the given tile"""
	if not has_building(coord):
		return
	
	building_instances.erase(coord)
	
	var tile = get_tile(coord)
	if tile:
		tile.building_id = ""

# === Resource Management (Per-Building Storage) ===

func get_total_resource(resource_id: String) -> float:
	"""Get total amount of a resource across all storage buildings"""
	var total: float = 0.0
	for instance in building_instances.values():
		total += instance.get_stored_amount(resource_id)
	return total

func get_total_storage_capacity(resource_id: String) -> float:
	"""Get total storage capacity for a resource across all buildings"""
	var total: float = 0.0
	for instance in building_instances.values():
		total += instance.get_storage_capacity(resource_id)
	return total

func get_available_storage(resource_id: String) -> float:
	"""Get available storage space for a resource"""
	var total: float = 0.0
	for instance in building_instances.values():
		total += instance.get_available_space(resource_id)
	return total

func store_resource(resource_id: String, amount: float) -> float:
	"""
	Store resources in available storage buildings.
	Returns the amount actually stored. Excess is not stored (spillage).
	"""
	var remaining = amount
	
	for instance in building_instances.values():
		if remaining <= 0:
			break
		
		if instance.can_store(resource_id):
			var stored = instance.add_resource(resource_id, remaining)
			remaining -= stored
	
	return amount - remaining  # Return amount stored

func consume_resource(resource_id: String, amount: float) -> float:
	"""
	Consume resources from storage buildings.
	Returns the amount actually consumed.
	"""
	var remaining = amount
	
	for instance in building_instances.values():
		if remaining <= 0:
			break
		
		var removed = instance.remove_resource(resource_id, remaining)
		remaining -= removed
	
	return amount - remaining  # Return amount consumed

func has_resources(requirements: Dictionary) -> bool:
	"""Check if the city has all required resources"""
	for resource_id in requirements.keys():
		if get_total_resource(resource_id) < requirements[resource_id]:
			return false
	return true

func get_missing_resources(requirements: Dictionary) -> Dictionary:
	"""Get dictionary of missing resources {resource_id: amount_missing}"""
	var missing: Dictionary = {}
	for resource_id in requirements.keys():
		var needed = requirements[resource_id]
		var available = get_total_resource(resource_id)
		if available < needed:
			missing[resource_id] = needed - available
	return missing

# === Admin Capacity ===

func get_available_admin_capacity() -> float:
	return max(0.0, admin_capacity_available - admin_capacity_used)

# === Statistics Recalculation ===

func recalculate_city_stats():
	"""Recalculate all city statistics (call after building changes during player turn)"""
	population_capacity = 0
	admin_capacity_available = 0.0
	admin_capacity_used = 0.0
	
	# Calculate admin cost for all tiles
	for coord in tiles.keys():
		var tile: CityTile = tiles[coord]
		if not tile.is_city_center:
			admin_capacity_used += calculate_tile_claim_cost(tile.distance_from_center)
	
	# Calculate from each building
	for coord in building_instances.keys():
		var instance: BuildingInstance = building_instances[coord]
		var tile: CityTile = tiles.get(coord)
		var distance = tile.distance_from_center if tile else 0
		
		# Admin capacity provided
		if instance.is_operational() or instance.is_under_construction():
			admin_capacity_available += Registry.buildings.get_admin_capacity(instance.building_id)
		
		# Admin cost
		admin_capacity_used += instance.get_admin_cost(distance)
		
		# Population capacity (only from operational buildings)
		if instance.is_operational():
			population_capacity += Registry.buildings.get_population_capacity(instance.building_id)
	
	print("City stats: admin %.1f/%.1f, pop capacity %d" % [admin_capacity_used, admin_capacity_available, population_capacity])

# === Legacy Compatibility ===

# These methods maintain compatibility with existing code that uses ResourceLedger

func get_construction_at_tile(coord: Vector2i) -> Dictionary:
	"""Get construction info at a tile (legacy compatibility)"""
	var instance = building_instances.get(coord)
	if instance and instance.is_under_construction():
		return {
			tile_coord = coord,
			building_id = instance.building_id,
			turns_remaining = instance.turns_remaining,
			cost_per_turn = instance.cost_per_turn
		}
	return {}
