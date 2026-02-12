extends Node2D
class_name FogOfWarOverlay

# Draws fog of war overlays on tiles based on visibility state.
# Follows the CityTileDimmer pattern: sits in world space, tracks camera,
# and uses _draw() to render hex overlays.

var fog_manager: FogOfWarManager
var is_active := false

var undiscovered_color := Color(0.12, 0.12, 0.12, 1.0)
var explored_color := Color(0.0, 0.0, 0.0, 0.45)

# Cache visible area
var cached_screen_coords: Array[Vector2i] = []
var last_camera_pos := Vector2.ZERO
var last_zoom := Vector2.ONE

func setup(p_fog_manager: FogOfWarManager):
	"""Initialize with fog manager reference"""
	fog_manager = p_fog_manager
	is_active = true
	fog_manager.visibility_changed.connect(_on_visibility_changed)
	last_camera_pos = Vector2.INF  # Force recalculation

func _process(_delta):
	if not is_active or not fog_manager:
		return

	var camera = get_viewport().get_camera_2d()
	if not camera:
		return

	var camera_pos = camera.global_position
	var zoom = camera.zoom

	# Only recalculate if camera moved significantly or zoom changed
	if camera_pos.distance_to(last_camera_pos) > WorldConfig.HEX_SIZE * 0.5 or zoom != last_zoom:
		last_camera_pos = camera_pos
		last_zoom = zoom
		_update_screen_coords()
		queue_redraw()

func _on_visibility_changed():
	"""Fog state changed — redraw"""
	queue_redraw()

func _update_screen_coords():
	"""Calculate which hex coordinates are visible on screen"""
	cached_screen_coords.clear()

	var camera = get_viewport().get_camera_2d()
	if not camera:
		return

	var viewport_size = get_viewport_rect().size
	var camera_pos = camera.global_position
	var zoom = camera.zoom

	# Calculate visible world area
	var half_width = viewport_size.x / (2.0 * zoom.x)
	var half_height = viewport_size.y / (2.0 * zoom.y)

	# Add padding for hex tiles at edges
	var padding = WorldConfig.HEX_SIZE * 2

	var left = camera_pos.x - half_width - padding
	var right = camera_pos.x + half_width + padding
	var top_edge = camera_pos.y - half_height - padding
	var bottom_edge = camera_pos.y + half_height + padding

	# Sample points in a grid across the visible area
	var step_x = WorldConfig.HEX_SIZE * 1.5
	var step_y = WorldConfig.HEX_SIZE * 0.866

	var coords_set := {}

	var y = top_edge
	while y <= bottom_edge:
		var x = left
		while x <= right:
			var coord = WorldUtil.pixel_to_axial(Vector2(x, y))
			coords_set[coord] = true
			x += step_x
		y += step_y

	# Add neighbors for complete coverage
	var all_coords := {}
	for coord in coords_set.keys():
		all_coords[coord] = true
		var neighbors = [
			coord + Vector2i(1, 0), coord + Vector2i(1, -1), coord + Vector2i(0, -1),
			coord + Vector2i(-1, 0), coord + Vector2i(-1, 1), coord + Vector2i(0, 1)
		]
		for neighbor in neighbors:
			all_coords[neighbor] = true

	for coord in all_coords.keys():
		cached_screen_coords.append(coord)

func _draw():
	if not is_active or not fog_manager:
		return

	for coord in cached_screen_coords:
		var visibility = fog_manager.get_tile_visibility(coord)

		if visibility == FogOfWarManager.TileVisibility.UNDISCOVERED:
			_draw_fog_hex(coord, undiscovered_color)
		elif visibility == FogOfWarManager.TileVisibility.EXPLORED:
			_draw_fog_hex(coord, explored_color)
		# VISIBLE tiles get no overlay

func _draw_fog_hex(coord: Vector2i, color: Color):
	"""Draw a fog overlay hexagon at the given coordinate"""
	var world_pos = WorldUtil.axial_to_pixel(coord.x, coord.y)
	var points = _get_hex_points(world_pos)
	draw_colored_polygon(points, color)

func _get_hex_points(center: Vector2) -> PackedVector2Array:
	"""Get hexagon corner points centered at the given position"""
	var points := PackedVector2Array()
	for i in range(6):
		var angle = PI / 3 * i + PI / 6
		points.append(center + Vector2(
			WorldConfig.HEX_SIZE * sin(angle),
			WorldConfig.HEX_SIZE * cos(angle)
		))
	return points
