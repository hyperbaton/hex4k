extends RefCounted
class_name TileView

# Unified view of a tile combining terrain and gameplay data
# This is a READ-ONLY view - modifications go through proper systems

var coord: Vector2i
var terrain_data: HexTileData  # Physical/terrain data (always present)
var city_tile: CityTile  # Gameplay data (null if unclaimed)
var city: City  # Owning city (null if unclaimed)

func _init(p_coord: Vector2i, p_terrain_data: HexTileData, p_city_tile: CityTile = null, p_city: City = null):
	coord = p_coord
	terrain_data = p_terrain_data
	city_tile = p_city_tile
	city = p_city

# === Terrain Information ===

func get_terrain_id() -> String:
	return terrain_data.terrain_id if terrain_data else ""

func get_altitude() -> float:
	return terrain_data.altitude if terrain_data else 0.0

func get_humidity() -> float:
	return terrain_data.humidity if terrain_data else 0.0

func get_temperature() -> float:
	return terrain_data.temperature if terrain_data else 0.0

func is_river() -> bool:
	return terrain_data.is_river if terrain_data else false

func get_terrain_name() -> String:
	return Registry.get_name_label("terrain", get_terrain_id())

func get_terrain_color() -> Color:
	if not terrain_data:
		return Color.MAGENTA
	
	var terrain = Registry.terrains.get_terrain(terrain_data.terrain_id)
	if terrain.has("visual") and terrain.visual.has("color"):
		return Color(terrain.visual.color)
	
	return Color.WHITE

# === Ownership Information ===

func is_claimed() -> bool:
	return city_tile != null

func get_owner_name() -> String:
	if city and city.owner:
		return city.owner.player_name
	return ""

func get_city_name() -> String:
	return city.city_name if city else ""

func get_city_id() -> String:
	return city.city_id if city else ""

func is_city_center() -> bool:
	return city_tile.is_city_center if city_tile else false

func get_distance_from_center() -> int:
	return city_tile.distance_from_center if city_tile else -1

func is_frontier() -> bool:
	if not city:
		return false
	return coord in city.frontier_tiles

# === Building Information ===

func has_building() -> bool:
	return city_tile != null and city_tile.has_building()

func get_building_id() -> String:
	return city_tile.building_id if city_tile else ""

func get_building_name() -> String:
	var building_id = get_building_id()
	if building_id == "":
		return ""
	return Registry.get_name_label("building", building_id)

func get_building_category() -> String:
	var building_id = get_building_id()
	if building_id == "":
		return ""
	
	var building = Registry.buildings.get_building(building_id)
	return building.get("category", "")

func can_units_stand() -> bool:
	var building_id = get_building_id()
	if building_id == "":
		return true  # Empty tiles allow units
	
	return Registry.buildings.allows_units_on_tile(building_id)

# === Resource Information (for storage buildings) ===

func get_stored_resources() -> Dictionary:
	if city_tile:
		return city_tile.stored_resources.duplicate()
	return {}

func get_stored_amount(resource_id: String) -> float:
	return city_tile.get_stored_amount(resource_id) if city_tile else 0.0

func get_storage_capacity(resource_id: String) -> float:
	return city_tile.get_storage_capacity(resource_id) if city_tile else 0.0

# === Production Information (if building produces/consumes) ===

func get_production() -> Dictionary:
	"""Returns what this tile's building produces per turn"""
	var building_id = get_building_id()
	if building_id == "":
		return {}
	
	return Registry.buildings.get_production_per_turn(building_id)

func get_consumption() -> Dictionary:
	"""Returns what this tile's building consumes per turn"""
	var building_id = get_building_id()
	if building_id == "":
		return {}
	
	return Registry.buildings.get_consumption_per_turn(building_id)

func get_net_production(resource_id: String) -> float:
	"""Net production/consumption for a specific resource"""
	var prod = get_production().get(resource_id, 0.0)
	var cons = get_consumption().get(resource_id, 0.0)
	return prod - cons

# === Display Helpers ===

func get_display_summary() -> Dictionary:
	"""Get a summary suitable for UI display"""
	return {
		coord = coord,
		terrain = get_terrain_name(),
		terrain_id = get_terrain_id(),
		is_claimed = is_claimed(),
		city_name = get_city_name(),
		owner = get_owner_name(),
		building = get_building_name(),
		building_id = get_building_id(),
		is_city_center = is_city_center(),
		can_build = is_claimed() and not has_building()
	}

func get_tooltip_text() -> String:
	"""Generate tooltip text for this tile"""
	var text = ""
	
	# Coordinate
	text += "Tile (%d, %d)\n" % [coord.x, coord.y]
	
	# Terrain
	text += "Terrain: %s\n" % get_terrain_name()
	
	# Ownership
	if is_claimed():
		text += "City: %s\n" % get_city_name()
		text += "Owner: %s\n" % get_owner_name()
		
		if is_city_center():
			text += "[City Center]\n"
		else:
			text += "Distance: %d from center\n" % get_distance_from_center()
	else:
		text += "Unclaimed\n"
	
	# Building
	if has_building():
		text += "\nBuilding: %s\n" % get_building_name()
		
		# Production
		var production = get_production()
		if not production.is_empty():
			text += "Produces:\n"
			for resource_id in production.keys():
				var amount = production[resource_id]
				var name = Registry.get_name_label("resource", resource_id)
				text += "  +%.1f %s\n" % [amount, name]
		
		# Consumption
		var consumption = get_consumption()
		if not consumption.is_empty():
			text += "Consumes:\n"
			for resource_id in consumption.keys():
				var amount = consumption[resource_id]
				var name = Registry.get_name_label("resource", resource_id)
				text += "  -%.1f %s\n" % [amount, name]
	
	return text

# === Visibility Filtering (for multiplayer) ===

func get_visible_to_player(player_id: String) -> Dictionary:
	"""
	Get only the information visible to a specific player.
	Used for multiplayer to hide enemy building details.
	"""
	var visible = {
		coord = coord,
		terrain = get_terrain_name(),
		terrain_id = get_terrain_id(),
		is_claimed = is_claimed()
	}
	
	# If this is the player's tile, show everything
	if city and city.owner and city.owner.player_id == player_id:
		visible.city_name = get_city_name()
		visible.building = get_building_name()
		visible.building_id = get_building_id()
		visible.production = get_production()
		visible.consumption = get_consumption()
		visible.is_city_center = is_city_center()
	# If it's an enemy tile, only show basic info
	elif is_claimed():
		visible.city_name = get_city_name()
		visible.owner = get_owner_name()
		# Building visible but no details
		visible.has_building = has_building()
		visible.building_category = get_building_category()
		# Don't reveal exact building or production
	
	return visible

# === Validation ===

func is_valid() -> bool:
	"""Check if this view has valid data"""
	return terrain_data != null
