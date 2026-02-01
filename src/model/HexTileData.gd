extends RefCounted
class_name HexTileData

var q: int
var r: int

var altitude: float
var humidity: float
var temperature: float
var is_river: bool

var terrain_id: String
var modifiers: Array[String] = []  # List of modifier IDs on this tile

func add_modifier(modifier_id: String):
	"""Add a modifier to this tile"""
	if not modifier_id in modifiers:
		modifiers.append(modifier_id)

func remove_modifier(modifier_id: String):
	"""Remove a modifier from this tile"""
	modifiers.erase(modifier_id)

func has_modifier(modifier_id: String) -> bool:
	"""Check if this tile has a specific modifier"""
	return modifier_id in modifiers

func get_tile_type_id() -> String:
	"""Get the tile type ID based on terrain and modifiers"""
	return Registry.tile_types.resolve_tile_type(terrain_id, modifiers)

func write_tile(file: FileAccess, tile: HexTileData):
	file.store_16(tile.q)
	file.store_16(tile.r)

	file.store_float(tile.altitude)
	file.store_float(tile.humidity)
	file.store_float(tile.temperature)
	file.store_var(tile.is_river)

	file.store_pascal_string(tile.terrain_id)
	
	# Store modifiers
	file.store_16(tile.modifiers.size())
	for modifier_id in tile.modifiers:
		file.store_pascal_string(modifier_id)

static func read_tile(file: FileAccess) -> HexTileData:
	var tile := HexTileData.new()

	tile.q = file.get_16()
	tile.r = file.get_16()

	tile.altitude = file.get_float()
	tile.humidity = file.get_float()
	tile.temperature = file.get_float()
	#tile.is_river = file.get_var()

	tile.terrain_id = file.get_pascal_string()
	
	# Read modifiers (handle old saves without modifiers)
	if not file.eof_reached():
		var modifier_count = file.get_16()
		for i in range(modifier_count):
			var modifier_id = file.get_pascal_string()
			tile.modifiers.append(modifier_id)

	return tile
