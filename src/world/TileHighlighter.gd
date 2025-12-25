extends Node2D
class_name TileHighlighter

# Visual feedback for tile highlighting in city view

signal tile_clicked(coord: Vector2i)

var highlighted_tiles: Dictionary = {}  # Vector2i -> HighlightInfo
var world_query: WorldQuery

class HighlightInfo:
	var coord: Vector2i
	var color: Color
	var adjacency_bonuses: Array[Dictionary] = []  # [{resource_id, amount}]

func _ready():
	pass

func initialize(p_world_query: WorldQuery):
	world_query = p_world_query

func clear_all():
	"""Remove all highlights"""
	highlighted_tiles.clear()
	queue_redraw()

func highlight_tile(coord: Vector2i, color: Color):
	"""Highlight a single tile"""
	var info = HighlightInfo.new()
	info.coord = coord
	info.color = color
	highlighted_tiles[coord] = info
	queue_redraw()

func highlight_tiles(coords: Array[Vector2i], color: Color):
	"""Highlight multiple tiles"""
	for coord in coords:
		highlight_tile(coord, color)

func add_adjacency_bonus_display(coord: Vector2i, resource_id: String, amount: float):
	"""Add an adjacency bonus display to a tile"""
	if not highlighted_tiles.has(coord):
		return
	
	var info = highlighted_tiles[coord]
	info.adjacency_bonuses.append({
		resource_id = resource_id,
		amount = amount
	})
	queue_redraw()

func _draw():
	"""Draw all highlights"""
	for coord in highlighted_tiles.keys():
		var info = highlighted_tiles[coord]
		draw_tile_highlight(info)

func draw_tile_highlight(info: HighlightInfo):
	"""Draw a single tile highlight"""
	var world_pos = WorldUtil.axial_to_pixel(info.coord.x, info.coord.y)
	
	# Draw hexagon outline
	var points = get_hex_points()
	var transformed_points = PackedVector2Array()
	for point in points:
		transformed_points.append(world_pos + point)
	
	# Draw filled polygon with transparency
	var fill_color = info.color
	fill_color.a = 0.3
	draw_colored_polygon(transformed_points, fill_color)
	
	# Draw outline
	draw_polyline(transformed_points, info.color, 3.0)
	
	# Draw adjacency bonuses
	if not info.adjacency_bonuses.is_empty():
		draw_adjacency_bonuses(world_pos, info.adjacency_bonuses)

func draw_adjacency_bonuses(world_pos: Vector2, bonuses: Array[Dictionary]):
	"""Draw adjacency bonus icons"""
	var offset_y = -WorldConfig.HEX_SIZE * 0.5
	
	for i in range(bonuses.size()):
		var bonus = bonuses[i]
		var resource_id = bonus.resource_id
		var amount = bonus.amount
		
		var pos = world_pos + Vector2(0, offset_y + (i * 20))
		
		# Draw small circle background
		draw_circle(pos, 12, Color(0, 0, 0, 0.7))
		
		# Draw resource icon (simplified - just colored circle)
		var resource_color = get_resource_color(resource_id)
		draw_circle(pos, 10, resource_color)
		
		# Draw amount text
		var text = "%+.1f" % amount
		var font = ThemeDB.fallback_font
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
		draw_string(font, pos + Vector2(15, 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

func get_hex_points() -> PackedVector2Array:
	"""Get hexagon corner points"""
	var points := PackedVector2Array()
	for i in range(6):
		var angle = PI / 3 * i + PI / 6
		points.append(Vector2(
			WorldConfig.HEX_SIZE * sin(angle),
			WorldConfig.HEX_SIZE * cos(angle)
		))
	return points

func get_resource_color(resource_id: String) -> Color:
	"""Get color for a resource"""
	var resource = Registry.resources.get_resource(resource_id)
	if resource.has("visual") and resource.visual.has("color"):
		return Color(resource.visual.color)
	return Color.WHITE

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if clicked on a highlighted tile
		var camera = get_viewport().get_camera_2d()
		if not camera:
			return
		
		var world_pos = camera.get_global_mouse_position()
		var coord = WorldUtil.pixel_to_axial(world_pos)
		
		if highlighted_tiles.has(coord):
			emit_signal("tile_clicked", coord)
			get_viewport().set_input_as_handled()
