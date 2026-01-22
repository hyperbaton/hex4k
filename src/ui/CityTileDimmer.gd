extends Node2D
class_name CityTileDimmer

# Draws dimming overlay on tiles that don't belong to the current city

var current_city: City
var dim_color := Color(0, 0, 0, 0.5)
var is_active := false

# Cache visible area
var cached_visible_coords: Array[Vector2i] = []
var last_camera_pos := Vector2.ZERO
var last_zoom := Vector2.ONE

func _ready():
	# We need to redraw when camera moves
	set_process(true)

func _process(_delta):
	if not is_active:
		return
	
	# Check if we need to update visible tiles
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	
	var camera_pos = camera.global_position
	var zoom = camera.zoom
	
	# Only recalculate if camera moved significantly or zoom changed
	if camera_pos.distance_to(last_camera_pos) > WorldConfig.HEX_SIZE * 0.5 or zoom != last_zoom:
		last_camera_pos = camera_pos
		last_zoom = zoom
		update_visible_coords()
		queue_redraw()

func activate(city: City):
	"""Start dimming for the given city"""
	current_city = city
	is_active = true
	last_camera_pos = Vector2.INF  # Force recalculation
	update_visible_coords()
	queue_redraw()

func deactivate():
	"""Stop dimming"""
	current_city = null
	is_active = false
	cached_visible_coords.clear()
	queue_redraw()

func update_visible_coords():
	"""Calculate which tiles are visible on screen"""
	cached_visible_coords.clear()
	
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
	var top = camera_pos.y - half_height - padding
	var bottom = camera_pos.y + half_height + padding
	
	# Use a set to avoid duplicates
	var coords_set := {}
	
	# Sample points in a grid across the visible area
	# Use hex dimensions for step size
	var step_x = WorldConfig.HEX_SIZE * 1.5  # Horizontal spacing between hex centers
	var step_y = WorldConfig.HEX_SIZE * 0.866  # Vertical spacing (sqrt(3)/2)
	
	var y = top
	while y <= bottom:
		var x = left
		while x <= right:
			var coord = WorldUtil.pixel_to_axial(Vector2(x, y))
			coords_set[coord] = true
			x += step_x
		y += step_y
	
	# Also add neighbors of all found coords to ensure complete coverage
	var all_coords := {}
	for coord in coords_set.keys():
		all_coords[coord] = true
		# Add the 6 neighbors
		var neighbors = [
			coord + Vector2i(1, 0), coord + Vector2i(1, -1), coord + Vector2i(0, -1),
			coord + Vector2i(-1, 0), coord + Vector2i(-1, 1), coord + Vector2i(0, 1)
		]
		for neighbor in neighbors:
			all_coords[neighbor] = true
	
	# Convert to array
	for coord in all_coords.keys():
		cached_visible_coords.append(coord)

func _draw():
	if not is_active or not current_city:
		return
	
	# Draw dim overlay on each visible tile that doesn't belong to the city
	for coord in cached_visible_coords:
		if not current_city.has_tile(coord):
			draw_dim_hex(coord)

func draw_dim_hex(coord: Vector2i):
	"""Draw a dimmed hexagon at the given coordinate"""
	var world_pos = WorldUtil.axial_to_pixel(coord.x, coord.y)
	var points = get_hex_points(world_pos)
	draw_colored_polygon(points, dim_color)

func get_hex_points(center: Vector2) -> PackedVector2Array:
	"""Get hexagon corner points centered at the given position"""
	var points := PackedVector2Array()
	for i in range(6):
		var angle = PI / 3 * i + PI / 6
		points.append(center + Vector2(
			WorldConfig.HEX_SIZE * sin(angle),
			WorldConfig.HEX_SIZE * cos(angle)
		))
	return points
