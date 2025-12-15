extends Node2D
class_name HexGrid

const HEX_SIZE := 32.0
const MAP_RADIUS := 20

var selected_tile: HexTile = null
@export var noise_seed: int = 12345
@export var noise_scale := 0.08

var altitude_noise := FastNoiseLite.new()

@export var humidity_seed_offset := 999
@export var humidity_scale := 0.1

var humidity_noise := FastNoiseLite.new()

@export var temperature_seed_offset := 499
@export var temperature_scale := 0.1

var temperature_noise := FastNoiseLite.new()

signal tile_selected(tile: HexTile)

func _ready():
	altitude_noise.seed = noise_seed
	altitude_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	altitude_noise.frequency = noise_scale
	humidity_noise.seed = noise_seed + humidity_seed_offset
	humidity_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	humidity_noise.frequency = humidity_scale
	temperature_noise.seed = noise_seed + temperature_seed_offset
	temperature_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	temperature_noise.frequency = temperature_scale

	generate_grid()

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
			var altitude = get_altitude(q, r)
			tile.altitude = altitude
			var humidity = get_humidity(q, r)
			tile.humidity = humidity
			tile.terrain_id = get_terrain_from_altitude(altitude, humidity)
			tile.position = axial_to_pixel(q, r)

			add_child(tile)

func clear():
	for child in get_children():
		child.queue_free()
		
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

func axial_to_pixel(q: int, r: int) -> Vector2:
	var x = HEX_SIZE * 3.0/2.0 * q
	var y = HEX_SIZE * sqrt(3) * (r + q / 2.0)
	return Vector2(x, y)

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
