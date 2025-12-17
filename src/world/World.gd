extends Node2D

@onready var tile_info_panel := $UI/Root/TileInfoPanel
@onready var chunk_manager := $ChunkManager
@onready var camera := $Camera2D

func _ready():
	chunk_manager.tile_selected.connect(_on_tile_selected)
	match GameState.mode:
		GameState.Mode.NEW_GAME:
			start_new_world()

		GameState.Mode.LOAD_GAME:
			load_existing_world()

func _on_tile_selected(tile: HexTile):
	tile_info_panel.show_tile(tile)

#func initialize_world():
	#grid.generate_grid()

func _process(_delta):
	chunk_manager.update_chunks(camera.global_position)

func start_new_world():
	chunk_manager.noise_seed = GameState.world_seed
	#chunk_manager.initialize_new_world()

func load_existing_world():
	chunk_manager.load_world(GameState.save_id)
