extends RefCounted
class_name FogOfWarManager

# Manages per-player fog of war state.
# Three visibility states: UNDISCOVERED (never seen), EXPLORED (seen before), VISIBLE (in current view).
# Vision sources: owned city tiles, units with vision_range, buildings with vision stat.
# Terrain/modifiers can block line-of-sight. Elevated terrain grants bonus vision range.

enum TileVisibility { UNDISCOVERED, EXPLORED, VISIBLE }

signal visibility_changed

var explored_tiles: Dictionary = {}  # Vector2i -> true
var visible_tiles: Dictionary = {}   # Vector2i -> true
var player_id: String

# References
var city_manager: CityManager
var unit_manager: UnitManager
var world_query: Node  # WorldQuery

func initialize(p_player_id: String, p_city_manager: CityManager, p_unit_manager: UnitManager, p_world_query: Node):
	"""Initialize with player and manager references"""
	player_id = p_player_id
	city_manager = p_city_manager
	unit_manager = p_unit_manager
	world_query = p_world_query

func recalculate_visibility():
	"""Recalculate all visible tiles for the player from scratch"""
	visible_tiles.clear()

	# 1. All owned city tiles are always visible
	var cities = city_manager.get_cities_for_player(player_id)
	for city in cities:
		for coord in city.tiles.keys():
			visible_tiles[coord] = true

	# 2. Vision from units
	var units = unit_manager.get_player_units(player_id)
	for unit in units:
		var terrain_bonus = _get_terrain_vision_bonus(unit.coord)
		var effective_range = unit.vision_range + terrain_bonus
		var seen = _get_visible_from_source(unit.coord, effective_range)
		for coord in seen:
			visible_tiles[coord] = true

	# 3. Vision from buildings with vision stat
	for city in cities:
		for coord in city.building_instances.keys():
			var instance = city.building_instances[coord]
			var building_vision = Registry.buildings.get_building_vision(instance.building_id)
			if building_vision > 0:
				var terrain_bonus = _get_terrain_vision_bonus(coord)
				var effective_range = building_vision + terrain_bonus
				var seen = _get_visible_from_source(coord, effective_range)
				for tile_coord in seen:
					visible_tiles[tile_coord] = true

	# 4. Mark all visible tiles as explored
	for coord in visible_tiles.keys():
		explored_tiles[coord] = true

	emit_signal("visibility_changed")

func _get_visible_from_source(source: Vector2i, vision_range: int) -> Array[Vector2i]:
	"""Calculate all tiles visible from a source with line-of-sight checking"""
	var result: Array[Vector2i] = [source]

	if vision_range <= 0:
		return result

	# Check all tiles within vision range
	for q in range(source.x - vision_range, source.x + vision_range + 1):
		for r in range(source.y - vision_range, source.y + vision_range + 1):
			var target = Vector2i(q, r)
			if target == source:
				continue

			var distance = _hex_distance(source, target)
			if distance > vision_range:
				continue

			# Tiles at distance 1 are always visible (cannot be blocked)
			if distance <= 1:
				result.append(target)
				continue

			# Check line-of-sight
			if _has_line_of_sight(source, target):
				result.append(target)

	return result

func _has_line_of_sight(source: Vector2i, target: Vector2i) -> bool:
	"""Check if there is a clear line of sight between source and target"""
	var line = _hex_line(source, target)

	# Check intermediate tiles (skip source and target)
	for i in range(1, line.size() - 1):
		if _tile_blocks_vision(line[i]):
			return false

	return true

func _tile_blocks_vision(coord: Vector2i) -> bool:
	"""Check if a tile blocks line-of-sight via terrain or modifiers"""
	if not world_query:
		return false

	var terrain_data = world_query.get_terrain_data(coord)
	if not terrain_data:
		return false

	# Check terrain
	if Registry.terrains.blocks_vision(terrain_data.terrain_id):
		return true

	# Check modifiers
	for mod_id in terrain_data.modifiers:
		if Registry.modifiers.blocks_vision(mod_id):
			return true

	return false

func _get_terrain_vision_bonus(coord: Vector2i) -> int:
	"""Get vision bonus from standing on elevated terrain"""
	if not world_query:
		return 0

	var terrain_data = world_query.get_terrain_data(coord)
	if not terrain_data:
		return 0

	return Registry.terrains.get_vision_bonus(terrain_data.terrain_id)

# === Hex Line Drawing (cube coordinate lerp) ===

func _hex_line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	"""Draw a line between two hex coordinates using cube coordinate interpolation"""
	var n = _hex_distance(a, b)
	if n == 0:
		return [a]

	var results: Array[Vector2i] = []

	# Convert to cube coordinates (x, y, z) where z = -x - y
	var a_cube = Vector3(a.x, a.y, -a.x - a.y)
	var b_cube = Vector3(b.x, b.y, -b.x - b.y)

	# Add small offset to avoid ties when rounding (nudge technique)
	var epsilon = Vector3(1e-6, 2e-6, -3e-6)
	a_cube += epsilon

	for i in range(n + 1):
		var t = float(i) / float(n)
		var cube = a_cube.lerp(b_cube, t)
		var rounded = _cube_round(cube)
		results.append(Vector2i(int(rounded.x), int(rounded.y)))

	return results

func _cube_round(cube: Vector3) -> Vector3:
	"""Round fractional cube coordinates to the nearest hex"""
	var rx = round(cube.x)
	var ry = round(cube.y)
	var rz = round(cube.z)

	var x_diff = abs(rx - cube.x)
	var y_diff = abs(ry - cube.y)
	var z_diff = abs(rz - cube.z)

	if x_diff > y_diff and x_diff > z_diff:
		rx = -ry - rz
	elif y_diff > z_diff:
		ry = -rx - rz
	else:
		rz = -rx - ry

	return Vector3(rx, ry, rz)

func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	"""Calculate hex distance between two axial coordinates"""
	var q_diff = abs(a.x - b.x)
	var r_diff = abs(a.y - b.y)
	var s_diff = abs((-a.x - a.y) - (-b.x - b.y))
	return int((q_diff + r_diff + s_diff) / 2)

# === Public Query ===

func get_tile_visibility(coord: Vector2i) -> TileVisibility:
	"""Get the visibility state of a tile for this player"""
	if visible_tiles.has(coord):
		return TileVisibility.VISIBLE
	if explored_tiles.has(coord):
		return TileVisibility.EXPLORED
	return TileVisibility.UNDISCOVERED

func is_tile_visible(coord: Vector2i) -> bool:
	return visible_tiles.has(coord)

func is_tile_explored(coord: Vector2i) -> bool:
	return explored_tiles.has(coord)

# === Save/Load ===

func get_save_data() -> Dictionary:
	"""Serialize explored tiles for saving (visible tiles are recomputed)"""
	var coords: Array = []
	for coord in explored_tiles.keys():
		coords.append([coord.x, coord.y])
	return {
		"player_id": player_id,
		"explored_tiles": coords
	}

func load_save_data(data: Dictionary):
	"""Restore explored tiles from save data"""
	explored_tiles.clear()
	var coords = data.get("explored_tiles", [])
	for pair in coords:
		if pair.size() >= 2:
			explored_tiles[Vector2i(pair[0], pair[1])] = true
	# Visible tiles will be recomputed via recalculate_visibility()
