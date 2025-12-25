extends Node2D

@onready var tile_info_panel := $UI/Root/TileInfoPanel
@onready var chunk_manager := $ChunkManager
@onready var camera := $Camera2D
@onready var city_manager := $CityManager
@onready var world_query := $WorldQuery
@onready var city_overlay := $CityOverlayLayer/CityOverlay
@onready var tile_highlighter := $TileHighlighter

var current_player_id := "player1"

func _ready():
	# Initialize managers
	world_query.initialize(self, city_manager)
	tile_highlighter.initialize(world_query)
	
	# Connect signals
	chunk_manager.tile_selected.connect(_on_tile_selected)
	city_overlay.closed.connect(_on_city_overlay_closed)
	tile_highlighter.tile_clicked.connect(_on_highlighted_tile_clicked)
	
	# Start or load world
	match GameState.mode:
		GameState.Mode.NEW_GAME:
			start_new_world()

		GameState.Mode.LOAD_GAME:
			load_existing_world()
	
	# Create test setup for development
	setup_test_city()

func _on_tile_selected(tile: HexTile):
	# Don't handle tile selection if city overlay is open
	if city_overlay.is_open:
		return
	
	# Create TileView for selected tile
	var coord = Vector2i(tile.data.q, tile.data.r)
	var tile_view = world_query.get_tile_view(coord)
	
	if tile_view:
		# Check if clicking on city center
		if tile_view.is_city_center():
			var city = city_manager.get_city_at_tile(coord)
			if city and city.owner.player_id == current_player_id:
				# Hide tile info panel
				tile_info_panel.hide_panel()
				# Open city overlay
				city_overlay.open_city(city, world_query, city_manager, tile_highlighter)
				return
		
		# Otherwise show tile info
		tile_info_panel.show_tile_view(tile_view)
	else:
		# Fallback to old method
		tile_info_panel.show_tile(tile)

func _on_city_overlay_closed():
	# City overlay closed
	tile_highlighter.clear_all()

func _on_highlighted_tile_clicked(coord: Vector2i):
	# Forward to city overlay
	city_overlay.on_highlighted_tile_clicked(coord)

func _process(_delta):
	chunk_manager.update_chunks(camera.global_position)

func start_new_world():
	chunk_manager.noise_seed = GameState.world_seed

func load_existing_world():
	chunk_manager.load_world(GameState.save_id)

# === Public API for WorldQuery ===

func get_tile_data(coord: Vector2i) -> HexTileData:
	"""Get terrain data for a tile"""
	return chunk_manager.get_tile_data(coord)

func get_tile_at_position(world_pos: Vector2) -> HexTile:
	"""Get the visual HexTile node at a world position"""
	return chunk_manager.get_tile_at_position(world_pos)

# === City Integration ===

func found_city_at_position(city_name: String, world_pos: Vector2, player_id: String) -> City:
	"""Found a city at a world position"""
	var coords = WorldUtil.pixel_to_axial(world_pos)
	return city_manager.found_city(city_name, coords, player_id)

func found_city_at_coords(city_name: String, coord: Vector2i, player_id: String) -> City:
	"""Found a city at hex coordinates"""
	return city_manager.found_city(city_name, coord, player_id)

# === Test Setup (temporary) ===

func setup_test_city():
	"""Create a test city for development"""
	await get_tree().create_timer(0.5).timeout  # Wait for chunks to load
	
	# Create player
	city_manager.create_player(current_player_id, "Test Player")
	
	# Find a suitable location (near origin)
	var test_coord = Vector2i(5, 5)
	
	# Found city
	var city = city_manager.found_city("Test City", test_coord, current_player_id)
	
	if city:
		print("✓ Test city founded at ", test_coord)
		print("  Click the city center to open the city overlay!")
	else:
		push_warning("Failed to found test city")
