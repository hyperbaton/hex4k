extends RefCounted

class_name TileGenerator

@export var noise_seed: int = 12345
@export var noise_scale := 0.08

var altitude_noise := FastNoiseLite.new()

@export var humidity_seed_offset := 999
@export var humidity_scale := 0.1

var humidity_noise := FastNoiseLite.new()

@export var temperature_seed_offset := 499
@export var temperature_scale := 0.05  # Lower frequency for larger temperature zones

var temperature_noise := FastNoiseLite.new()

@export var river_seed_offset := 299
@export var river_scale := 0.1

var river_noise := FastNoiseLite.new()

# Modifier generation noise layers
var modifier_noise := FastNoiseLite.new()
var cluster_noise := FastNoiseLite.new()

# Cache for terrain matching
var terrain_cache: Array[Dictionary] = []

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
	river_noise.seed = noise_seed + river_seed_offset
	river_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	river_noise.frequency = river_scale
	
	# Initialize modifier noise
	modifier_noise.seed = noise_seed + 1234
	modifier_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	modifier_noise.frequency = 0.15
	
	# Cluster noise for grouping modifiers
	cluster_noise.seed = noise_seed + 5678
	cluster_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	cluster_noise.frequency = 0.08
	
	# Build terrain cache sorted by priority (highest first)
	_build_terrain_cache()

func _build_terrain_cache():
	"""Build a sorted cache of terrains for efficient matching"""
	terrain_cache.clear()
	
	for terrain_id in Registry.terrains.get_all_terrain_ids():
		var terrain = Registry.terrains.get_terrain(terrain_id)
		var gen = terrain.get("generation", {})
		
		# Skip special terrains (river, lake) - they're handled separately
		if gen.get("special", "") != "":
			continue
		
		terrain_cache.append({
			"id": terrain_id,
			"altitude_min": gen.get("altitude_min", 0.0),
			"altitude_max": gen.get("altitude_max", 1.0),
			"humidity_min": gen.get("humidity_min", 0.0),
			"humidity_max": gen.get("humidity_max", 1.0),
			"temperature_min": gen.get("temperature_min", 0.0),
			"temperature_max": gen.get("temperature_max", 1.0),
			"priority": gen.get("priority", 5)
		})
	
	# Sort by priority descending (higher priority = checked first)
	terrain_cache.sort_custom(func(a, b): return a.priority > b.priority)
	
	print("TileGenerator: Built terrain cache with ", terrain_cache.size(), " terrains")

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
	
	var temperature = get_temperature(q, r)
	tile.temperature = temperature
	
	tile.is_river = generate_river(q, r, altitude)
	
	tile.terrain_id = get_terrain_from_parameters(altitude, humidity, temperature, tile.is_river)
	
	# Generate modifiers for this tile
	generate_modifiers_for_tile(tile)
	
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
	
	# Apply mask to have something like continents
	var mask = cell_mascara(q, r, x, y)
	
	return clamp(mask + (value + 1.0) * 0.5, 0, 1)
	
func cell_mascara(q: int, r: int, x: float, y: float) -> float:
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
	
func generate_river(q: int, r: int, altitude: float) -> bool:
	var v = river_noise.get_noise_2d(0.1*q, 0.1*r)
	if abs(v) < 0.03 and altitude < 0.75 and altitude > 0.35:
		return true
	return false

func get_terrain_from_parameters(altitude: float, humidity: float, temperature: float, is_river: bool) -> String:
	"""Select terrain based on altitude, humidity, temperature using registry data"""
	
	# Special cases first
	if is_river:
		return "river"
	
	# Find best matching terrain from cache
	var best_match := ""
	var best_score := -1.0
	
	for terrain in terrain_cache:
		# Check if parameters are within range
		if altitude < terrain.altitude_min or altitude > terrain.altitude_max:
			continue
		if humidity < terrain.humidity_min or humidity > terrain.humidity_max:
			continue
		if temperature < terrain.temperature_min or temperature > terrain.temperature_max:
			continue
		
		# Calculate how well this terrain fits (center of ranges = better fit)
		var alt_center = (terrain.altitude_min + terrain.altitude_max) / 2.0
		var hum_center = (terrain.humidity_min + terrain.humidity_max) / 2.0
		var temp_center = (terrain.temperature_min + terrain.temperature_max) / 2.0
		
		var alt_range = terrain.altitude_max - terrain.altitude_min
		var hum_range = terrain.humidity_max - terrain.humidity_min
		var temp_range = terrain.temperature_max - terrain.temperature_min
		
		# Score based on how close we are to center of each range (normalized)
		var alt_score = 1.0 - abs(altitude - alt_center) / max(alt_range / 2.0, 0.01)
		var hum_score = 1.0 - abs(humidity - hum_center) / max(hum_range / 2.0, 0.01)
		var temp_score = 1.0 - abs(temperature - temp_center) / max(temp_range / 2.0, 0.01)
		
		# Weight by priority and range specificity (smaller ranges = more specific = better match)
		var specificity = 3.0 - (alt_range + hum_range + temp_range)
		var score = (alt_score + hum_score + temp_score) * terrain.priority * (1.0 + specificity * 0.1)
		
		if score > best_score:
			best_score = score
			best_match = terrain.id
	
	# Fallback for unmatched areas
	if best_match == "":
		if altitude < 0.30:
			return "ocean"
		elif altitude > 0.90:
			return "high_mountain"
		else:
			return "plains"
	
	return best_match

# === Modifier Generation ===

func generate_modifiers_for_tile(tile: HexTileData):
	"""Generate modifiers for a tile based on terrain and climate"""
	var gen_cache = Registry.modifiers.get_generation_cache()
	
	for mod_data in gen_cache:
		var modifier_id = mod_data.id

		# Skip if this modifier was already added by a previous rule
		if tile.has_modifier(modifier_id):
			continue

		# Check if this modifier can spawn here
		if not _can_modifier_spawn(mod_data, tile):
			continue
		
		# Calculate spawn probability with clustering
		var spawn_chance = _calculate_spawn_chance(mod_data, tile)
		
		# Use deterministic random based on position and modifier
		var random_value = _get_deterministic_random(tile.q, tile.r, modifier_id)
		
		if random_value < spawn_chance:
			tile.add_modifier(modifier_id)

func _can_modifier_spawn(mod_data: Dictionary, tile: HexTileData) -> bool:
	"""Check if a modifier can spawn on this tile"""
	
	# Check terrain type
	var allowed_terrains = mod_data.terrain_types
	if not allowed_terrains.is_empty() and not tile.terrain_id in allowed_terrains:
		return false
	
	# Check altitude
	if tile.altitude < mod_data.altitude_min or tile.altitude > mod_data.altitude_max:
		return false
	
	# Check humidity
	if tile.humidity < mod_data.humidity_min or tile.humidity > mod_data.humidity_max:
		return false
	
	# Check temperature
	if tile.temperature < mod_data.temperature_min or tile.temperature > mod_data.temperature_max:
		return false
	
	# Check conflicts with existing modifiers
	var conflicts = mod_data.conflicts_with
	for existing in tile.modifiers:
		if existing in conflicts:
			return false
	
	return true

func _calculate_spawn_chance(mod_data: Dictionary, tile: HexTileData) -> float:
	"""Calculate spawn chance with clustering support"""
	var base_chance = mod_data.spawn_chance
	var cluster_size = mod_data.cluster_size
	var cluster_falloff = mod_data.cluster_falloff
	
	if cluster_size <= 1:
		# No clustering - just use base chance
		return base_chance
	
	# Use cellular noise to create cluster centers
	# Different modifiers use different noise offsets for variety
	var mod_hash = mod_data.id.hash() % 1000
	var cluster_value = cluster_noise.get_noise_2d(
		float(tile.q) + mod_hash * 0.1,
		float(tile.r) + mod_hash * 0.1
	)
	
	# Cellular noise returns values around 0, with "cells" being similar values
	# Transform to a multiplier: cells with low absolute values get higher spawn chance
	var cluster_multiplier = 1.0 - abs(cluster_value) * cluster_falloff
	cluster_multiplier = clamp(cluster_multiplier, 0.1, 2.0)
	
	# Additional variation using regular noise
	var variation = modifier_noise.get_noise_2d(
		float(tile.q) * 0.5 + mod_hash,
		float(tile.r) * 0.5 + mod_hash
	)
	# Map from [-1,1] to [0.5, 1.5]
	var variation_multiplier = 1.0 + variation * 0.5
	
	return base_chance * cluster_multiplier * variation_multiplier * cluster_size

func _get_deterministic_random(q: int, r: int, modifier_id: String) -> float:
	"""Get a deterministic 'random' value for a tile and modifier combination"""
	# Use noise with a unique offset per modifier
	var mod_hash = modifier_id.hash()
	var noise_val = modifier_noise.get_noise_2d(
		float(q) * 3.7 + mod_hash * 0.001,
		float(r) * 3.7 + mod_hash * 0.001
	)
	# Map from [-1,1] to [0,1]
	return (noise_val + 1.0) * 0.5
