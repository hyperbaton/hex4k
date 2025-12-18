extends RefCounted

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

func _init(p_seed: int) -> void:
	self.noise_seed = p_seed
	altitude_noise.seed = noise_seed
	altitude_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	altitude_noise.frequency = noise_scale
	humidity_noise.seed = noise_seed + humidity_seed_offset
	humidity_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	humidity_noise.frequency = humidity_scale
	temperature_noise.seed = noise_seed + temperature_seed_offset
	temperature_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	temperature_noise.frequency = temperature_scale

func generate_chunk_data(chunk_q: int, chunk_r: int) -> ChunkData:
	var chunk := ChunkData.new()
	chunk.coord = Vector2i(chunk_q, chunk_r)

	for q in range(WorldConfig.CHUNK_SIZE):
		for r in range(WorldConfig.CHUNK_SIZE):
			var world_q = chunk_q * WorldConfig.CHUNK_SIZE + q
			var world_r = chunk_r * WorldConfig.CHUNK_SIZE + r

			var tile_data = generate_tile_data(world_q, world_r)
			chunk.tiles[Vector2i(q, r)] = tile_data

	return chunk

func generate_tile_data(q: float, r:float) -> HexTileData:
	var tile := HexTileData.new()
	if max(abs(q), abs(r), abs(-q - r)) > WorldConfig.MAX_MAP_RADIUS:
		tile.terrain_id = "void"
		return tile

	tile.q = q
	tile.r = r
	var altitude = get_altitude(q, r)
	tile.altitude = altitude
	var humidity = get_humidity(q, r)
	tile.humidity = humidity
	tile.terrain_id = get_terrain_from_altitude(altitude, humidity)
	#tile.position = WorldUtil.axial_to_pixel(q, r)
	return tile

func get_altitude(q: int, r: int) -> float:
	var x = float(q)
	var y = float(r)
	var amplitude = 1.0
	var frequency = 0.5
	var lacunarity = 1.2
	var persistence = 0.1
	var x_offset = noise_seed
	var y_offset = noise_seed
	var mountainness = 0.7
	var sea_level = 0.3
	var value = 0.0
	for i in range(8):
		value += amplitude * altitude_noise.get_noise_2d(frequency * x + x_offset, frequency * y + y_offset)
		amplitude *= persistence
		frequency *= lacunarity
		x_offset += x_offset
		y_offset += y_offset

	# Add mountain ranges when the point is above the sea level
	if (value > sea_level):
		# Random but deterministic [-π,π] value for tilting (rotating the domain)
		var mountain_tilting = altitude_noise.get_noise_2d(noise_seed, noise_seed) * PI
		var xp = x*cos(mountain_tilting) - y*sin(mountain_tilting)
		var yp = x*sin(mountain_tilting) + y*cos(mountain_tilting)
		var mountranges = (altitude_noise.get_noise_2d(xp*0.5, yp*0.5) + 1.0) * 0.5
		mountranges = max(mountranges - mountainness, 0) * 1 / (1-mountainness)
		value += mountranges
	# Apply mascara to have something like continents
	var mask = cell_mascara(q,r,x,y)
	
	return clamp(mask + (value + 1.0) * 0.5, 0, 1)
	#return (value + 1.0) * 0.5  # [-1,1] → [0,1]
	
func cell_mascara(q:int, r: int, x: float,y: float) -> float:
	var wavelength = 120
	var cx = floor(x/wavelength)
	var cy = floor(y/wavelength)
	var lx = x - wavelength * (cx + 0.5)
	var ly = y - wavelength * (cy + 0.5)
	
	var n = altitude_noise.get_noise_1d(q) * altitude_noise.get_noise_1d(r) + 0.5*altitude_noise.get_noise_1d(2*q) * 0.5*altitude_noise.get_noise_1d(2*r)
	lx += 0.2 * wavelength * n
	ly += 0.2 * wavelength * n

	var dist = sqrt(lx*lx + ly*ly)
	var base_mask = 0.5 + 0.25 * cos(1.75*PI * dist / wavelength)
	return max(base_mask, 0) - 0.5
	
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
