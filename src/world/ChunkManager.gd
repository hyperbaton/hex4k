extends Node2D
class_name ChunkManager

@export var noise_seed := 12345

var chunks := {}  # Dictionary<Vector2i, Chunk>

var generator: TileGenerator

var selected_tile: HexTile = null
signal tile_selected(tile: HexTile)

func _ready():
	generator = TileGenerator.new(noise_seed)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_click(event.position)
	
func handle_click(_screen_pos: Vector2):
	var camera := get_viewport().get_camera_2d()
	var world_pos := camera.get_global_mouse_position()
	var coords := WorldUtil.pixel_to_axial(world_pos)
	select_tile(coords.x, coords.y)
	print("Mouse:", world_pos, "→ Hex:", coords)

func select_tile(q: int, r: int):
	for chunk in get_children():
		for tile in chunk.get_children():
			if tile.q == q and tile.r == r:
				if selected_tile:
					selected_tile.set_selected(false)
				selected_tile = tile
				tile.set_selected(true)
				emit_signal("tile_selected", tile)
				print("Selected:", q, r, tile.terrain_id)
				return

func get_chunk_coords(world_pos: Vector2) -> Vector2i:
	var axial = WorldUtil.pixel_to_axial(world_pos)
	return Vector2i(
		floor(axial.x / WorldConfig.CHUNK_SIZE),
		floor(axial.y / WorldConfig.CHUNK_SIZE)
	)

func update_chunks(camera_pos: Vector2):
	var center_chunk = get_chunk_coords(camera_pos)

	var needed := {}
	for dq in range(-WorldConfig.CHUNK_RADIUS, WorldConfig.CHUNK_RADIUS + 1):
		for dr in range(-WorldConfig.CHUNK_RADIUS, WorldConfig.CHUNK_RADIUS + 1):
			var coord = center_chunk + Vector2i(dq, dr)
			needed[coord] = true
			if not chunks.has(coord):
				load_chunk(coord)

	for coord in chunks.keys():
		if not needed.has(coord):
			unload_chunk(coord)

func load_chunk(coord: Vector2i):
	var chunk := Chunk.new()
	chunk.chunk_q = coord.x
	chunk.chunk_r = coord.y
	chunk.generate(generator)
	add_child(chunk)
	chunks[coord] = chunk

func unload_chunk(coord: Vector2i):
	chunks[coord].queue_free()
	chunks.erase(coord)
