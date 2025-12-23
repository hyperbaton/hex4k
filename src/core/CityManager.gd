extends Node
class_name CityManager

# Global manager for all cities in the game session

var cities: Dictionary = {}  # city_id -> City
var tile_ownership: Dictionary = {}  # Vector2i -> city_id
var players: Dictionary = {}  # player_id -> Player

signal city_founded(city: City)
signal city_destroyed(city: City)
signal building_constructed(city: City, coord: Vector2i, building_id: String)
signal building_demolished(city: City, coord: Vector2i)

func _ready():
	pass

# === Player Management ===

func create_player(player_id: String, player_name: String, is_human: bool = true) -> Player:
	"""Create a new player"""
	if players.has(player_id):
		push_warning("Player %s already exists!" % player_id)
		return players[player_id]
	
	var player = Player.new(player_id, player_name, is_human)
	players[player_id] = player
	print("Created player: %s (%s)" % [player_name, player_id])
	return player

func get_player(player_id: String) -> Player:
	return players.get(player_id)

func get_all_players() -> Array[Player]:
	var result: Array[Player] = []
	for player in players.values():
		result.append(player)
	return result

# === City Management ===

func found_city(city_name: String, center_coord: Vector2i, owner_id: String, city_center_building: String = "city_center") -> City:
	"""Found a new city at the given location"""
	
	# Check if tile is already owned
	if tile_ownership.has(center_coord):
		push_error("Cannot found city - tile already owned by city: %s" % tile_ownership[center_coord])
		return null
	
	# Get owner
	var owner = get_player(owner_id)
	if not owner:
		push_error("Cannot found city - player not found: %s" % owner_id)
		return null
	
	# Create city
	var city_id = generate_city_id()
	var city = City.new(city_id, city_name, center_coord)
	city.owner = owner
	
	# Add city center tile
	var center_tile = city.add_tile(center_coord, true)
	center_tile.set_building(city_center_building)
	
	# Register city
	cities[city_id] = city
	tile_ownership[center_coord] = city_id
	owner.add_city(city)
	
	# Initialize city stats
	city.recalculate_city_stats()
	
	emit_signal("city_founded", city)
	print("Founded city: %s at %v" % [city_name, center_coord])
	
	return city

func destroy_city(city_id: String):
	"""Destroy a city and remove all its tiles from ownership"""
	var city = cities.get(city_id)
	if not city:
		push_warning("Cannot destroy city - not found: %s" % city_id)
		return
	
	# Remove tile ownership
	for coord in city.tiles.keys():
		tile_ownership.erase(coord)
	
	# Remove from owner
	if city.owner:
		city.owner.remove_city(city)
	
	emit_signal("city_destroyed", city)
	cities.erase(city_id)
	print("Destroyed city: %s" % city.city_name)

func get_city(city_id: String) -> City:
	return cities.get(city_id)

func get_city_at_tile(coord: Vector2i) -> City:
	"""Get the city that owns this tile"""
	var city_id = tile_ownership.get(coord)
	if city_id:
		return cities.get(city_id)
	return null

func get_all_cities() -> Array[City]:
	var result: Array[City] = []
	for city in cities.values():
		result.append(city)
	return result

func get_cities_for_player(player_id: String) -> Array[City]:
	"""Get all cities owned by a player"""
	var player = get_player(player_id)
	if player:
		return player.get_all_cities()
	return []

func is_tile_owned(coord: Vector2i) -> bool:
	return tile_ownership.has(coord)

func can_city_expand_to_tile(city_id: String, coord: Vector2i) -> Dictionary:
	"""
	Check if a city can expand to claim a tile.
	Returns {can_expand: bool, reason: String}
	"""
	var city = get_city(city_id)
	if not city:
		return {can_expand = false, reason = "City not found"}
	
	# Check if tile is already owned
	if is_tile_owned(coord):
		return {can_expand = false, reason = "Tile already owned"}
	
	# Check if tile would keep city contiguous
	if not city.is_contiguous(coord):
		return {can_expand = false, reason = "Would break contiguity"}
	
	# Check admin capacity for the tile
	var distance = city.calculate_distance_from_center(coord)
	var base_admin_cost = 1.0  # Base cost for claiming a tile
	var admin_cost = base_admin_cost + (distance * distance * 0.1)
	
	if admin_cost > city.get_available_admin_capacity():
		return {can_expand = false, reason = "Insufficient administrative capacity"}
	
	return {can_expand = true, reason = ""}

func expand_city_to_tile(city_id: String, coord: Vector2i) -> bool:
	"""Expand a city to claim a new tile"""
	var check = can_city_expand_to_tile(city_id, coord)
	if not check.can_expand:
		push_warning("Cannot expand city %s to %v: %s" % [city_id, coord, check.reason])
		return false
	
	var city = get_city(city_id)
	city.add_tile(coord)
	tile_ownership[coord] = city_id
	
	print("City %s expanded to tile %v" % [city.city_name, coord])
	return true

# === Building Management (delegated to cities) ===

func place_building(city_id: String, coord: Vector2i, building_id: String) -> bool:
	"""Start building construction at a tile"""
	var city = get_city(city_id)
	if not city:
		push_warning("Cannot place building - city not found: %s" % city_id)
		return false
	
	return city.start_construction(coord, building_id)

func demolish_building(city_id: String, coord: Vector2i):
	"""Demolish a building at a tile"""
	var city = get_city(city_id)
	if city:
		city.demolish_building(coord)
		emit_signal("building_demolished", city, coord)

# === Turn Processing ===

func process_all_cities_turn():
	"""Process end-of-turn for all cities"""
	for city in cities.values():
		city.process_turn()

# === Utility ===

func generate_city_id() -> String:
	"""Generate a unique city ID"""
	return "city_%d" % Time.get_ticks_msec()

func get_minimum_city_distance() -> int:
	"""Minimum distance between city centers"""
	return 7  # Configurable

func can_found_city_here(coord: Vector2i) -> Dictionary:
	"""
	Check if a city can be founded at this location.
	Returns {can_found: bool, reason: String}
	"""
	# Check if tile is already owned
	if is_tile_owned(coord):
		return {can_found = false, reason = "Tile already owned"}
	
	# Check minimum distance from other cities
	var min_distance = get_minimum_city_distance()
	for city in cities.values():
		var distance = calculate_hex_distance(coord, city.city_center_coord)
		if distance < min_distance:
			return {can_found = false, reason = "Too close to another city"}
	
	# TODO: Check terrain requirements (plains, fresh water, etc.)
	
	return {can_found = true, reason = ""}

func calculate_hex_distance(a: Vector2i, b: Vector2i) -> int:
	"""Calculate hex distance between two coordinates"""
	var q_diff = abs(a.x - b.x)
	var r_diff = abs(a.y - b.y)
	var s_diff = abs((-a.x - a.y) - (-b.x - b.y))
	return int((q_diff + r_diff + s_diff) / 2)
