extends Node

class_name TileGenerator

@export var noise_seed: int = 12345
@export var noise_scale := 0.08

var altitude_noise := FastNoiseLite.new()

@export var humidity_seed_offset := 999
@export var humidity_scale := 0.1

var humidity_noise := FastNoiseLite.new()

@export var temperature_seed_offset := 499
@export var temperature_scale := 0.1

var temperature_noise := FastNoiseLite.new()

func _init(noise_seed: int) -> void:
	noise_seed = noise_seed
	altitude_noise.seed = noise_seed
	altitude_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	altitude_noise.frequency = noise_scale
	humidity_noise.seed = noise_seed + humidity_seed_offset
	humidity_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	humidity_noise.frequency = humidity_scale
	temperature_noise.seed = noise_seed + temperature_seed_offset
	temperature_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	temperature_noise.frequency = temperature_scale

func generate_tile(q: float, r:float) -> HexTile:
	var tile := HexTile.new()
	if abs(q + r) > WorldConfig.MAX_MAP_RADIUS:
		tile.terrain_id = "void"
		return tile

	tile.q = q
	tile.r = r
	var altitude = get_altitude(q, r)
	tile.altitude = altitude
	var humidity = get_humidity(q, r)
	tile.humidity = humidity
	tile.terrain_id = get_terrain_from_altitude(altitude, humidity)
	tile.position = WorldUtil.axial_to_pixel(q, r)
	return tile

func get_altitude(q: int, r: int) -> float:
	var x = float(q)
	var y = float(r)
	var value = altitude_noise.get_noise_2d(x, y)
	return (value + 1.0) * 0.5  # [-1,1] → [0,1]
	
func get_humidity(q: int, r: int) -> float:
	var value = humidity_noise.get_noise_2d(float(q), float(r))
	return (value + 1.0) * 0.5

func get_temperature(q: int, r: int) -> float:
	var value = temperature_noise.get_noise_2d(float(q), float(r))
	return (value + 1.0) * 0.5

func get_terrain_from_altitude(altitude: float, humidity: float) -> String:
	if altitude < 0.30:
		return "ocean"
	elif altitude < 0.40:
		return "coast"
	elif altitude < 0.55:
		if humidity < 0.20:
			return "desert"
		elif humidity < 0.40:
			return "steppe"
		elif humidity < 0.65:
			return "plains"
		elif humidity < 0.85:
			return "forest"
		else:
			return "swamp"
	elif altitude < 0.70:
		return "hills"
	else:
		if humidity < 0.4:
			return "dry_mountain"
		else:
			return "alpine"
