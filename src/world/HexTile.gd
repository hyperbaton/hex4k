extends Node2D
class_name HexTile

var terrain_id: String
var modifier_ids: Array = []
var building_id: String = "empty"
var unit_id: String = "empty"

var q: int
var r: int

var altitude: float
var humidity: float
var temperature: float

const HEX_SIZE := 32.0

var selected := false

func set_selected(value: bool):
	selected = value
	queue_redraw()

func _draw():
	var color := get_terrain_color()
	draw_colored_polygon(get_hex_points(), color)
	draw_polyline(get_hex_points(), Color.BLACK, 1.0)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-10, 5),
		"%d,%d" % [q, r],
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		8,
		Color.BLACK
	)
	if selected:
		draw_polyline(
			get_hex_points(),
			Color.YELLOW,
			3.0
		)


func get_hex_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(6):
		var angle = PI / 3 * i + PI / 6
		points.append(Vector2(
			HEX_SIZE * sin(angle),
			HEX_SIZE * cos(angle)
		))
	return points

func get_terrain_color() -> Color:
	match terrain_id:
		"water": return Color(0.2, 0.4, 0.8)
		"forest": return Color(0.1, 0.5, 0.2)
		"hills": return Color(0.6, 0.6, 0.4)
		"mountain": return Color(0.5, 0.5, 0.5)
		"ocean": return Color(0.15, 0.3, 0.7)
		"coast": return Color(0.85, 0.8, 0.6)
		"desert": return Color(0.9, 0.85, 0.5)
		"steppe": return Color(0.7, 0.8, 0.4)
		"plains": return Color(0.4, 0.75, 0.4)
		"forest": return Color(0.1, 0.5, 0.2)
		"swamp": return Color(0.2, 0.4, 0.25)
		"dry_mountain": return Color(0.55, 0.5, 0.45)
		"alpine": return Color(0.8, 0.8, 0.8)
		_: return Color.MAGENTA
		
