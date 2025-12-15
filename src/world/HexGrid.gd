extends Node2D
class_name HexGrid

const HEX_SIZE := 32.0
const MAP_RADIUS := 10

var selected_tile: HexTile = null

signal tile_selected(tile: HexTile)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_click(event.position)
	
func handle_click(screen_pos: Vector2):
	var camera := get_viewport().get_camera_2d()
	var world_pos := camera.get_global_mouse_position()
	var coords := pixel_to_axial(world_pos)
	select_tile(coords.x, coords.y)
	print("Mouse:", world_pos, "→ Hex:", coords)

func select_tile(q: int, r: int):
	for tile in get_children():
		if tile.q == q and tile.r == r:
			if selected_tile:
				selected_tile.set_selected(false)
			selected_tile = tile
			tile.set_selected(true)
			emit_signal("tile_selected", tile)
			print("Selected:", q, r, tile.terrain_id)
			return

func generate_grid():
	clear()
	for q in range(-MAP_RADIUS, MAP_RADIUS + 1):
		for r in range(-MAP_RADIUS, MAP_RADIUS + 1):
			if abs(q + r) > MAP_RADIUS:
				continue

			var tile := HexTile.new()
			tile.q = q
			tile.r = r
			tile.terrain_id = get_basic_terrain(q, r)
			tile.position = axial_to_pixel(q, r)

			add_child(tile)

func clear():
	for child in get_children():
		child.queue_free()

func axial_to_pixel(q: int, r: int) -> Vector2:
	var x = HEX_SIZE * 3.0/2.0 * q
	var y = HEX_SIZE * sqrt(3) * (r + q / 2.0)
	return Vector2(x, y)

func get_basic_terrain(q: int, r: int) -> String:
	var d = abs(q) + abs(r) + abs(q + r)
	if d > 16:
		return "water"
	elif d > 12:
		return "plains"
	elif d > 8:
		return "forest"
	elif d > 4:
		return "hills"
	else:
		return "mountain"

func pixel_to_axial(pos: Vector2) -> Vector2i:
	var q = (2.0 / 3.0 * pos.x) / HEX_SIZE
	var r = (-1.0 / 3.0 * pos.x + sqrt(3) / 3.0 * pos.y) / HEX_SIZE
	return axial_round(q, r)

func axial_round(qf: float, rf: float) -> Vector2i:
	var sf = -qf - rf

	var q = round(qf)
	var r = round(rf)
	var s = round(sf)

	var q_diff = abs(q - qf)
	var r_diff = abs(r - rf)
	var s_diff = abs(s - sf)

	if q_diff > r_diff and q_diff > s_diff:
		q = -r - s
	elif r_diff > s_diff:
		r = -q - s

	return Vector2i(q, r)
