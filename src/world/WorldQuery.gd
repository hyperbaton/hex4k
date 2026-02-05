extends Node
class_name WorldQuery

# Bridge between World (terrain) and CityManager (gameplay)
# Provides unified TileView access

var world_node: Node2D  # Reference to World scene
var city_manager: CityManager  # Reference to CityManager

func _ready():
	pass

func initialize(p_world: Node2D, p_city_manager: CityManager):
	"""Initialize with references to world and city manager"""
	world_node = p_world
	city_manager = p_city_manager
	print("WorldQuery initialized")

# === TileView Generation ===

func get_tile_view(coord: Vector2i) -> TileView:
	"""Get a unified view of a tile"""
	# Get terrain data from world
	var terrain_data = get_terrain_data(coord)
	if not terrain_data:
		push_warning("No terrain data at %v" % coord)
		return null
	
	# Get city data (if tile is claimed)
	var city = city_manager.get_city_at_tile(coord) if city_manager else null
	var city_tile = city.get_tile(coord) if city else null
	
	return TileView.new(coord, terrain_data, city_tile, city)

func get_tile_views_in_area(center: Vector2i, radius: int) -> Array[TileView]:
	"""Get TileViews for all tiles in a radius"""
	var views: Array[TileView] = []
	
	for q in range(center.x - radius, center.x + radius + 1):
		for r in range(center.y - radius, center.y + radius + 1):
			var coord = Vector2i(q, r)
			var distance = calculate_hex_distance(center, coord)
			
			if distance <= radius:
				var view = get_tile_view(coord)
				if view:
					views.append(view)
	
	return views

func get_tile_views_for_city(city_id: String) -> Array[TileView]:
	"""Get TileViews for all tiles in a city"""
	var views: Array[TileView] = []
	
	if not city_manager:
		return views
	
	var city = city_manager.get_city(city_id)
	if not city:
		return views
	
	for coord in city.tiles.keys():
		var view = get_tile_view(coord)
		if view:
			views.append(view)
	
	return views

# === Terrain Data Access (delegated to World) ===

func get_terrain_data(coord: Vector2i) -> HexTileData:
	"""Get terrain data for a tile from the world"""
	if not world_node or not world_node.has_method("get_tile_data"):
		push_error("World not properly connected to WorldQuery")
		return null
	
	return world_node.get_tile_data(coord)

func get_terrain_id(coord: Vector2i) -> String:
	var data = get_terrain_data(coord)
	return data.terrain_id if data else ""

# === Building Placement Queries ===

func can_build_here(coord: Vector2i, building_id: String) -> Dictionary:
	"""
	Comprehensive check if a building can be placed.
	Combines city, terrain, and tech checks.
	Returns {can_build: bool, reason: String}
	"""
	# Check if tile is in a city
	var city = city_manager.get_city_at_tile(coord) if city_manager else null
	if not city:
		return {can_build = false, reason = "Tile not in a city"}
	
	# Check terrain
	var terrain_id = get_terrain_id(coord)
	if not Registry.buildings.can_place_on_terrain(building_id, terrain_id):
		return {can_build = false, reason = "Invalid terrain for this building"}
	
	# Check terrain adjacency requirements
	var adj_check = check_terrain_adjacency_requirements(coord, building_id)
	if not adj_check.met:
		return {can_build = false, reason = adj_check.reason}
	
	# Delegate to city for full check (admin, existing building, tech, etc.)
	var city_check = city.can_place_building(coord, building_id)
	# Normalize the response key from can_place to can_build
	return {can_build = city_check.get("can_place", false), reason = city_check.get("reason", "")}

func check_terrain_adjacency_requirements(coord: Vector2i, building_id: String) -> Dictionary:
	"""
	Check if terrain/modifier adjacency requirements are met for a building.
	Supports terrain_types, modifiers, and or_self options.
	Returns {met: bool, reason: String}
	"""
	var building = Registry.buildings.get_building(building_id)
	if not building.has("requirements"):
		return {met = true, reason = ""}
	
	var reqs = building.requirements
	if not reqs.has("required_adjacent"):
		return {met = true, reason = ""}
	
	var adj_reqs = reqs.required_adjacent
	var min_count = adj_reqs.get("min_count", 1)
	var max_distance = adj_reqs.get("max_distance", 1)
	var or_self = adj_reqs.get("or_self", false)  # If true, being on the terrain/modifier counts
	
	var required_terrains = adj_reqs.get("terrain_types", [])
	var required_modifiers = adj_reqs.get("modifiers", [])
	
	# Nothing to check
	if required_terrains.is_empty() and required_modifiers.is_empty():
		return {met = true, reason = ""}
	
	# Count matching terrain and modifiers
	var matching_count = 0
	
	# Check "or_self" - if the building is ON matching terrain/modifier, that counts
	if or_self:
		var self_terrain = get_terrain_id(coord)
		var self_data = get_terrain_data(coord)
		
		# Check if self terrain matches
		if self_terrain in required_terrains:
			matching_count += 1
		
		# Check if self has any required modifier
		if self_data:
			for mod_id in required_modifiers:
				if self_data.has_modifier(mod_id):
					matching_count += 1
					break  # Only count self once even if multiple modifiers match
	
	# Check adjacent tiles
	var neighbors = get_tiles_in_range(coord, 1, max_distance)
	
	for neighbor_coord in neighbors:
		var neighbor_terrain = get_terrain_id(neighbor_coord)
		var neighbor_data = get_terrain_data(neighbor_coord)
		
		# Check terrain match
		if neighbor_terrain in required_terrains:
			matching_count += 1
			continue  # Don't double-count if terrain matches
		
		# Check modifier match
		if neighbor_data:
			for mod_id in required_modifiers:
				if neighbor_data.has_modifier(mod_id):
					matching_count += 1
					break  # Only count this tile once even if multiple modifiers match
	
	if matching_count < min_count:
		# Build a user-friendly reason message
		var requirements_list: Array[String] = []
		if not required_terrains.is_empty():
			requirements_list.append(", ".join(required_terrains))
		if not required_modifiers.is_empty():
			# Get readable modifier names
			var mod_names: Array[String] = []
			for mod_id in required_modifiers:
				var mod_name = Registry.modifiers.get_modifier_name(mod_id)
				mod_names.append(mod_name)
			requirements_list.append(", ".join(mod_names))
		
		var requirements_str = " or ".join(requirements_list)
		return {met = false, reason = "Requires adjacent %s (found %d, need %d)" % [requirements_str, matching_count, min_count]}
	
	return {met = true, reason = ""}

func get_buildable_buildings(coord: Vector2i) -> Array[String]:
	"""Get list of building IDs that can be built at this location"""
	var buildable: Array[String] = []
	
	var all_buildings = Registry.buildings.get_all_building_ids()
	for building_id in all_buildings:
		var check = can_build_here(coord, building_id)
		if check.can_build:
			buildable.append(building_id)
	
	return buildable

# === City Expansion Queries ===

func can_city_expand_here(coord: Vector2i) -> Dictionary:
	"""
	Check if any city can expand to this tile.
	Returns {can_expand: bool, reason: String, city_id: String}
	"""
	# Check if already owned
	if city_manager and city_manager.is_tile_owned(coord):
		return {can_expand = false, reason = "Already owned"}
	
	# Find adjacent cities
	var adjacent_cities = get_adjacent_cities(coord)
	if adjacent_cities.is_empty():
		return {can_expand = false, reason = "No adjacent city"}
	
	# Check first adjacent city (could extend to support multiple)
	var city = adjacent_cities[0]
	var check = city_manager.can_city_expand_to_tile(city.city_id, coord)
	
	check.city_id = city.city_id
	return check

func get_adjacent_cities(coord: Vector2i) -> Array[City]:
	"""Get cities adjacent to this tile"""
	var cities: Array[City] = []
	var seen_city_ids = {}
	
	var neighbors = get_hex_neighbors(coord)
	for neighbor in neighbors:
		var city = city_manager.get_city_at_tile(neighbor) if city_manager else null
		if city and not seen_city_ids.has(city.city_id):
			cities.append(city)
			seen_city_ids[city.city_id] = true
	
	return cities

# === City Founding Queries ===

func can_found_city_here(coord: Vector2i) -> Dictionary:
	"""
	Check if a city can be founded at this location.
	Returns {can_found: bool, reason: String}
	"""
	if not city_manager:
		return {can_found = false, reason = "CityManager not initialized"}
	
	# Use CityManager's check
	return city_manager.can_found_city_here(coord)

func get_suitable_city_locations(center: Vector2i, radius: int) -> Array[Vector2i]:
	"""Find all tiles suitable for city founding in an area"""
	var suitable: Array[Vector2i] = []
	
	for q in range(center.x - radius, center.x + radius + 1):
		for r in range(center.y - radius, center.y + radius + 1):
			var coord = Vector2i(q, r)
			var check = can_found_city_here(coord)
			if check.can_found:
				suitable.append(coord)
	
	return suitable

# === Hex Utilities ===

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

func calculate_hex_distance(a: Vector2i, b: Vector2i) -> int:
	"""Calculate hex distance between two coordinates"""
	var q_diff = abs(a.x - b.x)
	var r_diff = abs(a.y - b.y)
	var s_diff = abs((-a.x - a.y) - (-b.x - b.y))
	return int((q_diff + r_diff + s_diff) / 2)

func get_tiles_in_range(center: Vector2i, min_range: int, max_range: int) -> Array[Vector2i]:
	"""Get all tiles within a range ring"""
	var tiles: Array[Vector2i] = []
	
	for q in range(center.x - max_range, center.x + max_range + 1):
		for r in range(center.y - max_range, center.y + max_range + 1):
			var coord = Vector2i(q, r)
			var distance = calculate_hex_distance(center, coord)
			
			if distance >= min_range and distance <= max_range:
				tiles.append(coord)
	
	return tiles

# === Pathfinding Helpers (for future use) ===

func get_path_between(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	"""Get a path between two tiles (basic implementation)"""
	# TODO: Implement proper A* pathfinding
	# For now, return empty array
	return []

func get_movement_cost(from: Vector2i, to: Vector2i) -> float:
	"""Get movement cost between two adjacent tiles"""
	var terrain_id = get_terrain_id(to)
	if terrain_id == "":
		return INF
	
	var terrain = Registry.terrains.get_terrain(terrain_id)
	return terrain.get("movement_cost", 1.0)

func get_terrain_type(coord: Vector2i) -> String:
	"""Get the terrain type at a coordinate (for unit movement)"""
	return get_terrain_id(coord)

# === Multiplayer Support ===

func get_visible_tiles_for_player(player_id: String) -> Array[TileView]:
	"""Get all tiles visible to a specific player"""
	var visible: Array[TileView] = []
	
	if not city_manager:
		return visible
	
	# Get player's cities
	var cities = city_manager.get_cities_for_player(player_id)
	
	# Add tiles from each city
	for city in cities:
		var city_views = get_tile_views_for_city(city.city_id)
		visible.append_array(city_views)
	
	# TODO: Add vision from units, explored tiles, etc.
	
	return visible

# === Debug Helpers ===

func print_tile_info(coord: Vector2i):
	"""Print detailed information about a tile"""
	var view = get_tile_view(coord)
	if not view:
		print("No tile at %v" % coord)
		return
	
	print("\n=== Tile Info: %v ===" % coord)
	print(view.get_tooltip_text())
	#print("=" * 30)
