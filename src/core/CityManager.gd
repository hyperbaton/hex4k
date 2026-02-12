extends Node
class_name CityManager

# Global manager for all cities in the game session.
# Uses settlement types for founding, tile costs, and expansion limits.

var cities: Dictionary = {}  # city_id -> City
var tile_ownership: Dictionary = {}  # Vector2i -> city_id
var players: Dictionary = {}  # player_id -> Player
var fog_manager: FogOfWarManager  # Set by World.gd for expansion checks

signal city_founded(city: City)
signal city_destroyed(city: City)
signal city_abandoned(city: City, previous_owner: Player)
signal player_defeated(player: Player)
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

func found_city(city_name: String, center_coord: Vector2i, owner_id: String, settlement_type: String = "encampment") -> City:
	"""Found a new city at the given location using settlement type configuration."""
	
	# Check if tile is already owned
	if tile_ownership.has(center_coord):
		push_error("Cannot found city - tile already owned by city: %s" % tile_ownership[center_coord])
		return null
	
	# Get owner
	var owner = get_player(owner_id)
	if not owner:
		push_error("Cannot found city - player not found: %s" % owner_id)
		return null
	
	# Validate settlement type exists
	if not Registry.settlements.type_exists(settlement_type):
		push_error("Cannot found city - unknown settlement type: %s" % settlement_type)
		return null
	
	# Get founding config from settlement type
	var founding = Registry.settlements.get_founding_info(settlement_type)
	var initial_buildings = founding.get("initial_buildings", ["longhouse"])
	var initial_resources = founding.get("initial_resources", {})
	var city_center_building = initial_buildings[0] if not initial_buildings.is_empty() else "longhouse"
	
	# Create city
	var city_id = generate_city_id()
	var city = City.new(city_id, city_name, center_coord)
	city.owner = owner
	city.settlement_type = settlement_type
	
	# Add city center tile
	var center_tile = city.add_tile(center_coord, true)
	center_tile.building_id = city_center_building
	
	# Create BuildingInstance for city center (already built, active)
	var center_instance = BuildingInstance.new(city_center_building, center_coord)
	center_instance.set_active()
	city.building_instances[center_coord] = center_instance
	
	# Give starting resources from settlement type
	for resource_id in initial_resources.keys():
		var amount = initial_resources[resource_id]
		city.store_resource(resource_id, amount)
	
	# Give starting population (stored in population-tagged pools)
	city.store_resource("population", 5)
	
	# Register city
	cities[city_id] = city
	tile_ownership[center_coord] = city_id
	owner.add_city(city)
	
	# Initialize city stats
	city.recalculate_city_stats()
	
	emit_signal("city_founded", city)
	print("Founded city: %s at %v (type: %s)" % [city_name, center_coord, settlement_type])
	
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

func abandon_city(city_id: String) -> Player:
	"""
	Abandon a city due to population reaching zero.
	Returns the previous owner (for defeat checking).
	"""
	var city = cities.get(city_id)
	if not city:
		push_warning("Cannot abandon city - not found: %s" % city_id)
		return null
	
	if city.is_abandoned:
		return null
	
	var previous_owner = city.owner
	city.abandon()
	
	emit_signal("city_abandoned", city, previous_owner)
	print("City %s has been abandoned" % city.city_name)
	
	if previous_owner and previous_owner.get_city_count() == 0:
		_handle_player_defeat(previous_owner)
	
	return previous_owner

func _handle_player_defeat(player: Player):
	"""Handle a player losing the game due to having no cities"""
	print("=== PLAYER DEFEATED ===")
	print("  %s has lost all their cities!" % player.player_name)
	print("========================")
	emit_signal("player_defeated", player)

func get_abandoned_cities() -> Array[City]:
	"""Get all abandoned cities that can be claimed"""
	var result: Array[City] = []
	for city in cities.values():
		if city.is_abandoned:
			result.append(city)
	return result

func reclaim_city(city_id: String, new_owner: Player) -> bool:
	"""Allow a player to reclaim an abandoned city"""
	var city = cities.get(city_id)
	if not city:
		push_warning("Cannot reclaim city - not found: %s" % city_id)
		return false
	
	if not city.is_abandoned:
		push_warning("Cannot reclaim city - not abandoned: %s" % city_id)
		return false
	
	city.reclaim(new_owner)
	print("City %s reclaimed by %s" % [city.city_name, new_owner.player_name])
	return true

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
	"""Get all cities owned by a player (excludes abandoned cities)"""
	var player = get_player(player_id)
	if player:
		return player.get_all_cities()
	return []

func get_active_cities() -> Array[City]:
	"""Get all non-abandoned cities"""
	var result: Array[City] = []
	for city in cities.values():
		if not city.is_abandoned:
			result.append(city)
	return result

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
	
	if city.is_abandoned:
		return {can_expand = false, reason = "City is abandoned"}
	
	# Check tile limit from settlement type
	if not city.can_expand_tiles():
		var max_tiles = city.get_max_tiles()
		if max_tiles > 0:
			return {can_expand = false, reason = "Tile limit reached (%d/%d)" % [city.get_tile_count(), max_tiles]}
		return {can_expand = false, reason = "Expansion not allowed for this settlement type"}
	
	# Check if tile has been explored (fog of war)
	if fog_manager and not fog_manager.is_tile_explored(coord):
		return {can_expand = false, reason = "Unexplored territory"}

	# Check if tile is already owned
	if is_tile_owned(coord):
		return {can_expand = false, reason = "Tile already owned"}
	
	# Check if tile would keep city contiguous
	if not city.is_contiguous(coord):
		return {can_expand = false, reason = "Would break contiguity"}
	
	# Check cap resources for the new tile cost
	var distance = city.calculate_distance_from_center(coord)
	var tile_costs = city.calculate_tile_claim_cost(distance)
	
	for res_id in tile_costs.keys():
		var cost = tile_costs[res_id]
		var remaining = city.get_cap_remaining(res_id)
		if cost > remaining:
			var res_name = Registry.get_name_label("resource", res_id)
			return {can_expand = false, reason = "Insufficient %s" % res_name}
	
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
	
	# Recalculate stats since tile costs changed
	city.recalculate_city_stats()
	
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
	
	return {can_found = true, reason = ""}

func calculate_hex_distance(a: Vector2i, b: Vector2i) -> int:
	"""Calculate hex distance between two coordinates"""
	var q_diff = abs(a.x - b.x)
	var r_diff = abs(a.y - b.y)
	var s_diff = abs((-a.x - a.y) - (-b.x - b.y))
	return int((q_diff + r_diff + s_diff) / 2)
