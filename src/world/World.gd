extends Node2D

@onready var tile_info_panel := $UI/Root/TileInfoPanel
@onready var chunk_manager := $ChunkManager
@onready var camera := $Camera2D
@onready var city_manager := $CityManager
@onready var world_query := $WorldQuery
@onready var city_overlay := $CityOverlayLayer/CityOverlay
@onready var tile_highlighter := $TileHighlighter
@onready var tech_tree_screen := $TechTreeLayer/TechTreeScreen
@onready var tech_tree_button := $UI/Root/TechTreeButton

var city_tile_dimmer: CityTileDimmer

var current_player_id := "player1"

func _ready():
	# Initialize managers
	world_query.initialize(self, city_manager)
	tile_highlighter.initialize(world_query)
	
	# Create the city tile dimmer (in world space, above chunks but below UI)
	city_tile_dimmer = CityTileDimmer.new()
	city_tile_dimmer.name = "CityTileDimmer"
	add_child(city_tile_dimmer)
	# Move it after ChunkManager so it draws on top of tiles
	move_child(city_tile_dimmer, chunk_manager.get_index() + 1)
	
	# Connect signals
	chunk_manager.tile_selected.connect(_on_tile_selected)
	city_overlay.closed.connect(_on_city_overlay_closed)
	tile_highlighter.tile_clicked.connect(_on_highlighted_tile_clicked)
	tech_tree_button.pressed.connect(_on_tech_tree_button_pressed)
	tech_tree_screen.closed.connect(_on_tech_tree_closed)
	
	# Start or load world
	match GameState.mode:
		GameState.Mode.NEW_GAME:
			start_new_world()

		GameState.Mode.LOAD_GAME:
			load_existing_world()
	
	# Create test setup for development
	setup_test_city()
	setup_test_tech_progress()

func _on_tile_selected(tile: HexTile):
	# Don't handle tile selection if city overlay or tech tree is open
	if city_overlay.is_open or tech_tree_screen.is_open:
		return
	
	# Create TileView for selected tile
	var coord = Vector2i(tile.data.q, tile.data.r)
	var tile_view = world_query.get_tile_view(coord)
	
	if tile_view:
		# Check if clicking on any tile that belongs to a city owned by the player
		var city = city_manager.get_city_at_tile(coord)
		if city and city.owner.player_id == current_player_id:
			# Hide tile info panel
			tile_info_panel.hide_panel()
			# Activate tile dimmer for this city
			if city_tile_dimmer:
				city_tile_dimmer.activate(city)
			# Open city overlay with chunk_manager reference
			city_overlay.open_city(city, world_query, city_manager, tile_highlighter, chunk_manager)
			return
		
		# Otherwise show tile info
		tile_info_panel.show_tile_view(tile_view)
	else:
		# Fallback to old method
		tile_info_panel.show_tile(tile)

func _on_city_overlay_closed():
	# City overlay closed - deactivate dimmer
	if city_tile_dimmer:
		city_tile_dimmer.deactivate()
	tile_highlighter.clear_all()

func _on_highlighted_tile_clicked(coord: Vector2i):
	# Forward to city overlay
	city_overlay.on_highlighted_tile_clicked(coord)

func _on_tech_tree_button_pressed():
	if not tech_tree_screen.is_open:
		tech_tree_screen.show_screen()

func _on_tech_tree_closed():
	pass  # Could re-enable other UI if needed

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
	
	# Find a suitable location (on land)
	var test_coord = Vector2i(-12, 15)
	
	# Found city
	var city = city_manager.found_city("Test City", test_coord, current_player_id)
	
	if city:
		print("✓ Test city founded at ", test_coord)
		
		# Add some starting resources for testing
		city.resources.set_storage_capacity("food", 100.0)
		city.resources.set_storage_capacity("wood", 200.0)
		city.resources.set_storage_capacity("stone", 150.0)
		city.resources.set_storage_capacity("admin_capacity", 150.0)
		
		city.resources.add_stored("food", 45.0)
		city.resources.add_stored("wood", 120.0)
		city.resources.add_stored("stone", 30.0)
		city.resources.add_stored("admin_capacity", 30.0)
		
		print("  Added test resources: food=45, wood=120, stone=30")
		
		# Add admin capacity for testing (simulating what city_center would provide)
		city.admin_capacity_available = 20.0
		city.admin_capacity_used = 2.0
		print("  Added test admin capacity: 20.0")
		
		# Update the visual for the city center building
		var center_tile = chunk_manager.get_tile_at_coord(test_coord)
		if center_tile:
			center_tile.set_building("city_center")
			print("  Set city_center building visual on tile")
		
		print("  Click the city center to open the city overlay!")
	else:
		push_warning("Failed to found test city")

func setup_test_tech_progress():
	"""Set up some test tech progress for development"""
	# Add progress to some branches to see the visualization
	Registry.tech.set_branch_progress("agriculture", 5.0)
	Registry.tech.set_branch_progress("construction", 3.0)
	Registry.tech.set_branch_progress("pottery", 4.0)
	Registry.tech.set_branch_progress("mining", 1.0)
	
	print("✓ Set test tech progress: agriculture=5, construction=3, pottery=4, mining=1")
