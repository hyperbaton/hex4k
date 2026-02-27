extends Node2D
class_name ChunkManager

@export var noise_seed := 12345

var chunk_data := {}     # Dictionary<Vector2i, ChunkData>
var loaded_chunks := {}  # Dictionary<Vector2i, Chunk>

var generator: TileGenerator

var current_save: String

var selected_tile: HexTile = null
var fog_manager: FogOfWarManager  # Set by World.gd
signal tile_selected(tile: HexTile)
signal chunk_loaded(chunk_coord: Vector2i)

func _ready():
	
	match GameState.mode:
		GameState.Mode.NEW_GAME:
			generator = TileGenerator.new(noise_seed)

		GameState.Mode.LOAD_GAME:
			load_meta()
			noise_seed = GameState.world_seed
			generator = TileGenerator.new(noise_seed)
			load_world(GameState.save_id)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if click is not on UI
		var ui_root = get_node("../UI/Root")
		if ui_root:
			var local_pos = ui_root.get_local_mouse_position()
			var rect = ui_root.get_rect()
			if rect.has_point(local_pos):
				# Check if any UI element was actually clicked
				for child in ui_root.get_children():
					if child is Control and child.visible:
						var child_rect = child.get_global_rect()
						if child_rect.has_point(event.position):
							return  # Click was on UI, don't handle
		handle_click(event.position)
		get_viewport().set_input_as_handled()
	
func handle_click(_screen_pos: Vector2):
	var camera := get_viewport().get_camera_2d()
	var world_pos := camera.get_global_mouse_position()
	var coords := WorldUtil.pixel_to_axial(world_pos)
	select_tile(coords.x, coords.y)
	print("Mouse:", world_pos, "→ Hex:", coords)

func select_tile(q: int, r: int):
	# Block selection of undiscovered tiles
	if fog_manager:
		var coord = Vector2i(q, r)
		if fog_manager.get_tile_visibility(coord) == FogOfWarManager.TileVisibility.UNDISCOVERED:
			return

	for chunk in get_children():
		for tile in chunk.get_children():
			if tile.data.q == q and tile.data.r == r:
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

func get_or_create_chunk_data(coord: Vector2i) -> ChunkData:
	if chunk_data.has(coord):
		return chunk_data[coord]

	var path = get_chunk_path(coord)
	var chunk: ChunkData

	if FileAccess.file_exists(path):
		chunk = ChunkData.load_chunk(path)
	else:
		chunk = generator.generate_chunk_data(coord.x, coord.y)

	chunk_data[coord] = chunk
	return chunk

func load_chunk(coord: Vector2i):
	if loaded_chunks.has(coord):
		return

	var data = get_or_create_chunk_data(coord)

	var chunk := Chunk.new()
	chunk.build_from_data(data)
	add_child(chunk)

	loaded_chunks[coord] = chunk
	emit_signal("chunk_loaded", coord)

func unload_chunk(coord: Vector2i):
	if not loaded_chunks.has(coord):
		return

	loaded_chunks[coord].queue_free()
	loaded_chunks.erase(coord)


func update_chunks(camera_pos: Vector2):
	var center_chunk = get_chunk_coords(camera_pos)

	var needed := {}
	for dq in range(-WorldConfig.CHUNK_RADIUS, WorldConfig.CHUNK_RADIUS + 1):
		for dr in range(-WorldConfig.CHUNK_RADIUS, WorldConfig.CHUNK_RADIUS + 1):
			var coord = center_chunk + Vector2i(dq, dr)
			needed[coord] = true
			if not loaded_chunks.has(coord):
				load_chunk(coord)

	for coord in loaded_chunks.keys():
		if not needed.has(coord):
			unload_chunk(coord)

func save_world():
	for coord in chunk_data.keys():
		ChunkData.save_chunk(
			chunk_data[coord],
			get_chunk_path(coord)
		)
		
func get_chunk_path(coord: Vector2i) -> String:
	var save_dir = "user://saves/%s" % GameState.save_id
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("user://saves/"):
		dir.make_dir("user://saves/")
	if not dir.dir_exists(save_dir):
		dir.make_dir(save_dir)
	if not dir.dir_exists(save_dir + "/chunks/"):
		dir.make_dir(save_dir + "/chunks/")
	return "%s/chunks/chunk_%d_%d.bin" % [save_dir, coord.x, coord.y]
	
func load_world(save_id: String):
	current_save = save_id
	load_visible_chunks()

func save_meta(current_turn: int = 1):
	"""Save world metadata (seed, version, display name, turn) to meta.json"""
	var save_dir = "user://saves/%s" % GameState.save_id
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("user://saves/"):
		dir.make_dir("user://saves/")
	if not dir.dir_exists(save_dir):
		dir.make_dir(save_dir)

	var path = "%s/meta.json" % save_dir
	var meta = {
		"seed": GameState.world_seed,
		"save_version": 1,
		"display_name": GameState.save_display_name,
		"current_turn": current_turn,
		"timestamp": Time.get_datetime_string_from_system()
	}
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(meta, "\t"))
	file.close()

func load_meta():
	"""Load world metadata from meta.json"""
	var path = "user://saves/%s/meta.json" % GameState.save_id
	if not FileAccess.file_exists(path):
		push_warning("No meta.json found for save: %s" % GameState.save_id)
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var meta = JSON.parse_string(file.get_as_text())
	file.close()
	if meta:
		GameState.world_seed = meta.get("seed", GameState.world_seed)
	
func get_camera_chunk() -> Vector2i:
	var cam_pos = get_node("../Camera2D").global_position
	var axial = WorldUtil.pixel_to_axial(cam_pos)
	return Vector2i(
		floori(axial.x / WorldConfig.CHUNK_SIZE),
		floori(axial.y / WorldConfig.CHUNK_SIZE)
	)

func get_visible_chunk_coords(center: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	for dq in range(-WorldConfig.CHUNK_RADIUS, WorldConfig.CHUNK_RADIUS + 1):
		for dr in range(-WorldConfig.CHUNK_RADIUS, WorldConfig.CHUNK_RADIUS + 1):
			result.append(center + Vector2i(dq, dr))

	return result
	
func spawn_chunk_node(coord: Vector2i, data: ChunkData):
	if loaded_chunks.has(coord):
		return

	var node = Chunk.new()
	node.build_from_data(data)

	add_child(node)
	loaded_chunks[coord] = node
	emit_signal("chunk_loaded", coord)

func unload_far_chunks(visible: Array[Vector2i]):
	for coord in loaded_chunks.keys():
		if not visible.has(coord):
			loaded_chunks[coord].queue_free()
			loaded_chunks.erase(coord)

func load_visible_chunks():
	var center = get_camera_chunk()
	var visible_chunks = get_visible_chunk_coords(center)

	for coord in visible_chunks:
		var data = get_or_create_chunk_data(coord)
		spawn_chunk_node(coord, data)

	unload_far_chunks(visible_chunks)

# === Public API for World/WorldQuery ===

func get_tile_data(coord: Vector2i) -> HexTileData:
	"""Get terrain data for a tile at the given coordinates"""
	var chunk_coord = Vector2i(
		floor(float(coord.x) / WorldConfig.CHUNK_SIZE),
		floor(float(coord.y) / WorldConfig.CHUNK_SIZE)
	)
	
	var chunk = get_or_create_chunk_data(chunk_coord)
	if not chunk:
		return null
	
	var local_coord = Vector2i(
		coord.x - chunk_coord.x * WorldConfig.CHUNK_SIZE,
		coord.y - chunk_coord.y * WorldConfig.CHUNK_SIZE
	)
	
	return chunk.tiles.get(local_coord)

func get_tile_at_position(world_pos: Vector2) -> HexTile:
	"""Get the visual HexTile node at a world position"""
	var coords = WorldUtil.pixel_to_axial(world_pos)
	return get_tile_at_coords(coords.x, coords.y)

func get_tile_at_coords(q: int, r: int) -> HexTile:
	"""Get the visual HexTile node at hex coordinates"""
	for chunk in get_children():
		for tile in chunk.get_children():
			if tile is HexTile and tile.data.q == q and tile.data.r == r:
				return tile
	return null

func get_tile_at_coord(coord: Vector2i) -> HexTile:
	"""Get the visual HexTile node at hex coordinates (Vector2i version)"""
	return get_tile_at_coords(coord.x, coord.y)
