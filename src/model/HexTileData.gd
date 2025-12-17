extends RefCounted
class_name HexTileData

var q: int
var r: int

var altitude: float
var humidity: float
var temperature: float

var terrain_id: String

func write_tile(file: FileAccess, tile: HexTileData):
	file.store_16(tile.q)
	file.store_16(tile.r)

	file.store_float(tile.altitude)
	file.store_float(tile.humidity)
	file.store_float(tile.temperature)

	file.store_pascal_string(tile.terrain_id)

static func read_tile(file: FileAccess) -> HexTileData:
	var tile := HexTileData.new()

	tile.q = file.get_16()
	tile.r = file.get_16()

	tile.altitude = file.get_float()
	tile.humidity = file.get_float()
	tile.temperature = file.get_float()

	tile.terrain_id = file.get_pascal_string()

	return tile
