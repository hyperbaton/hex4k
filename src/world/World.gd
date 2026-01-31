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
var turn_manager: TurnManager
var unit_manager: UnitManager
var unit_layer: UnitLayer
var end_turn_button: Button
var turn_label: Label
var turn_report_panel: PanelContainer

var current_player_id := "player1"

func _ready():
	# Initialize managers
	world_query.initialize(self, city_manager)
	tile_highlighter.initialize(world_query)
	
	# Create unit manager
	unit_manager = UnitManager.new()
	
	# Create turn manager with unit manager reference
	turn_manager = TurnManager.new(city_manager, unit_manager)
	turn_manager.turn_completed.connect(_on_turn_completed)
	
	# Create unit layer for visuals (in world space, above tiles)
	unit_layer = UnitLayer.new()
	unit_layer.name = "UnitLayer"
	unit_layer.setup(unit_manager)
	add_child(unit_layer)
	
	# Create the city tile dimmer (in world space, above chunks but below UI)
	city_tile_dimmer = CityTileDimmer.new()
	city_tile_dimmer.name = "CityTileDimmer"
	add_child(city_tile_dimmer)
	# Move it after ChunkManager so it draws on top of tiles
	move_child(city_tile_dimmer, chunk_manager.get_index() + 1)
	
	# Move unit layer above dimmer
	move_child(unit_layer, city_tile_dimmer.get_index() + 1)
	
	# Create turn UI
	_create_turn_ui()
	
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

func _create_turn_ui():
	"""Create the End Turn button and turn counter"""
	var ui_root = $UI/Root
	
	# Container for turn controls (bottom right)
	var turn_container = VBoxContainer.new()
	turn_container.name = "TurnContainer"
	turn_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	turn_container.anchor_left = 1.0
	turn_container.anchor_top = 1.0
	turn_container.offset_left = -160
	turn_container.offset_top = -100
	turn_container.offset_right = -20
	turn_container.offset_bottom = -20
	turn_container.add_theme_constant_override("separation", 8)
	ui_root.add_child(turn_container)
	
	# Turn counter label
	turn_label = Label.new()
	turn_label.name = "TurnLabel"
	turn_label.text = "Turn 0"
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.add_theme_font_size_override("font_size", 18)
	turn_container.add_child(turn_label)
	
	# End turn button
	end_turn_button = Button.new()
	end_turn_button.name = "EndTurnButton"
	end_turn_button.text = "End Turn"
	end_turn_button.custom_minimum_size = Vector2(120, 40)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	turn_container.add_child(end_turn_button)
	
	# Turn report panel (hidden by default)
	_create_turn_report_panel(ui_root)

func _create_turn_report_panel(parent: Control):
	"""Create the turn report panel"""
	turn_report_panel = PanelContainer.new()
	turn_report_panel.name = "TurnReportPanel"
	turn_report_panel.visible = false
	turn_report_panel.custom_minimum_size = Vector2(400, 300)
	turn_report_panel.set_anchors_preset(Control.PRESET_CENTER)
	turn_report_panel.anchor_left = 0.5
	turn_report_panel.anchor_right = 0.5
	turn_report_panel.anchor_top = 0.5
	turn_report_panel.anchor_bottom = 0.5
	turn_report_panel.offset_left = -200
	turn_report_panel.offset_right = 200
	turn_report_panel.offset_top = -150
	turn_report_panel.offset_bottom = 150
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style.border_color = Color(0.4, 0.4, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	turn_report_panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 10)
	turn_report_panel.add_child(vbox)
	
	# Header
	var header = HBoxContainer.new()
	vbox.add_child(header)
	
	var title = Label.new()
	title.name = "Title"
	title.text = "Turn Report"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.pressed.connect(_on_report_close_pressed)
	header.add_child(close_btn)
	
	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	# Scroll container for report content
	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 200)
	vbox.add_child(scroll)
	
	var report_label = Label.new()
	report_label.name = "ReportContent"
	report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report_label.add_theme_font_size_override("font_size", 14)
	report_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report_label.custom_minimum_size = Vector2(360, 0)  # Ensure minimum width
	scroll.add_child(report_label)
	
	# Close button at bottom
	var btn_container = HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_container)
	
	var ok_btn = Button.new()
	ok_btn.text = "OK"
	ok_btn.custom_minimum_size = Vector2(80, 32)
	ok_btn.pressed.connect(_on_report_close_pressed)
	btn_container.add_child(ok_btn)
	
	parent.add_child(turn_report_panel)

func _on_end_turn_pressed():
	"""Handle End Turn button press"""
	# Disable button during processing
	end_turn_button.disabled = true
	end_turn_button.text = "Processing..."
	
	# Process the turn
	var report = turn_manager.process_turn()
	
	# Update turn label
	turn_label.text = "Turn %d" % turn_manager.current_turn
	
	# Re-enable button
	end_turn_button.disabled = false
	end_turn_button.text = "End Turn"
	
	# Show report if there are critical alerts
	if report.has_critical_alerts():
		_show_turn_report(report)
	
	# Update any open city overlay
	if city_overlay.is_open and city_overlay.current_city:
		city_overlay.current_city.recalculate_city_stats()
		city_overlay.city_header.update_display()
		# Update queue panel
		if city_overlay.queue_panel:
			city_overlay.queue_panel.update_display()
	
	# Update building visuals for completed constructions
	_update_building_visuals(report)
	
	# Refresh unit visuals
	if unit_layer:
		unit_layer.refresh_all()

func _update_building_visuals(report: TurnReport):
	"""Update visual state of buildings after turn processing"""
	for city_id in report.city_reports.keys():
		var city_report = report.city_reports[city_id]
		
		# Update completed constructions
		for completion in city_report.constructions_completed:
			var coord = completion.coord
			var building_id = completion.building_id
			var tile = chunk_manager.get_tile_at_coord(coord)
			if tile:
				tile.set_building(building_id, false)  # false = not under construction
				print("Updated visual for completed building: %s at %v" % [building_id, coord])

func _on_turn_completed(report: TurnReport):
	"""Called when turn processing is complete"""
	print("Turn %d completed" % report.turn_number)

func _show_turn_report(report: TurnReport):
	"""Show the turn report panel"""
	var vbox = turn_report_panel.get_node("VBox")
	var header = vbox.get_child(0)  # First child is the HBoxContainer header
	var title = header.get_node("Title") as Label
	title.text = "Turn %d Report" % report.turn_number
	
	var scroll = vbox.get_node("Scroll")
	var content = scroll.get_node("ReportContent") as Label
	content.text = report.get_summary()
	
	turn_report_panel.visible = true

func _on_report_close_pressed():
	"""Close the turn report panel"""
	turn_report_panel.visible = false

func _on_tile_selected(tile: HexTile):
	# Don't handle tile selection if city overlay or tech tree is open
	if city_overlay.is_open or tech_tree_screen.is_open:
		return
	
	# Don't handle if turn report is showing
	if turn_report_panel and turn_report_panel.visible:
		return
	
	# Get tile coordinate
	var coord = Vector2i(tile.data.q, tile.data.r)
	print("World._on_tile_selected: coord=", coord)
	
	# Check for unit at this tile first
	var unit_at_tile = unit_manager.get_unit_at(coord) if unit_manager else null
	print("  unit_at_tile: ", unit_at_tile, " (unit_manager exists: ", unit_manager != null, ")")
	
	if unit_at_tile:
		print("  Unit found: ", unit_at_tile.unit_id, " owner: ", unit_at_tile.owner_id)
		# There's a unit here - check if it belongs to the current player
		if unit_at_tile.owner_id == current_player_id:
			# Is this unit already selected?
			if unit_layer.selected_unit == unit_at_tile:
				print("  Unit already selected - checking for city")
				# Unit already selected - clicking again opens city if applicable
				var city = city_manager.get_city_at_tile(coord)
				if city and city.owner.player_id == current_player_id:
					# Deselect unit and open city
					unit_layer.deselect_unit()
					tile_highlighter.clear_all()
					tile_info_panel.hide_panel()
					if city_tile_dimmer:
						city_tile_dimmer.activate(city)
					city_overlay.open_city(city, world_query, city_manager, tile_highlighter, chunk_manager)
					return
				# No city - just keep unit selected, maybe show unit info
				print("Unit already selected, no city here")
				return
			else:
				# Select this unit
				print("Selecting unit: ", unit_at_tile.unit_id, " (", unit_at_tile.unit_type, ")")
				unit_layer.select_unit(unit_at_tile)
				tile_info_panel.hide_panel()
				# Show movement range
				_show_unit_movement_range(unit_at_tile)
				return
		else:
			# Enemy unit - show info but don't select
			print("Enemy unit at tile")
	else:
		print("  No unit at tile")
	
	# No unit clicked - check if we have a selected unit and clicked a valid move tile
	if unit_layer.selected_unit:
		# Check if clicking a reachable tile
		if tile_highlighter.highlighted_tiles.has(coord):
			# Move the selected unit here
			_move_selected_unit_to(coord)
			return
		else:
			# Clicked somewhere else - deselect unit
			print("Deselecting unit - clicked non-reachable tile")
			unit_layer.deselect_unit()
			tile_highlighter.clear_all()
	
	# Check for city
	var tile_view = world_query.get_tile_view(coord)
	
	if tile_view:
		# Check if clicking on any tile that belongs to a city owned by the player
		var city = city_manager.get_city_at_tile(coord)
		if city and city.owner.player_id == current_player_id:
			# Deselect any selected unit when entering city
			unit_layer.deselect_unit()
			tile_highlighter.clear_all()
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

func _show_unit_movement_range(unit: Unit):
	"""Highlight tiles the unit can move to"""
	tile_highlighter.clear_all()
	
	# Get reachable tiles
	var reachable = unit_manager.get_reachable_tiles(unit, world_query)
	
	print("Unit movement range: ", reachable.size(), " tiles")
	
	# Highlight each reachable tile
	for coord in reachable.keys():
		if coord == unit.coord:
			continue  # Don't highlight current position
		
		var move_cost = reachable[coord]
		# Color based on movement cost (green = cheap, yellow = expensive)
		var color: Color
		if move_cost <= unit.current_movement / 2:
			color = Color(0.2, 0.8, 0.2, 0.6)  # Green - easy to reach
		else:
			color = Color(0.8, 0.8, 0.2, 0.6)  # Yellow - uses most movement
		
		tile_highlighter.highlight_tile(coord, color)

func _move_selected_unit_to(coord: Vector2i):
	"""Move the selected unit to the target coordinate"""
	var unit = unit_layer.selected_unit
	if not unit:
		return
	
	# Get movement cost
	var reachable = unit_manager.get_reachable_tiles(unit, world_query)
	if not reachable.has(coord):
		print("Cannot move to ", coord, " - not reachable")
		return
	
	var move_cost = reachable[coord]
	
	# Move the unit
	var from_coord = unit.coord
	unit.move_to(coord, move_cost)
	
	print("Moved unit from ", from_coord, " to ", coord, " (cost: ", move_cost, ", remaining: ", unit.current_movement, ")")
	
	# Update movement highlights
	if unit.current_movement > 0:
		# Still has movement - show new range
		_show_unit_movement_range(unit)
	else:
		# No more movement - clear highlights but keep selected
		tile_highlighter.clear_all()
		print("Unit has no more movement this turn")

func _on_city_overlay_closed():
	# City overlay closed - deactivate dimmer
	if city_tile_dimmer:
		city_tile_dimmer.deactivate()
	tile_highlighter.clear_all()

func _on_highlighted_tile_clicked(coord: Vector2i):
	# Forward to city overlay if open
	if city_overlay.is_open:
		city_overlay._on_highlighted_tile_clicked(coord)
		return
	
	# Check if we have a selected unit - handle movement
	if unit_layer.selected_unit:
		print("Highlighted tile clicked for unit movement: ", coord)
		_move_selected_unit_to(coord)

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
	
	# Found city with longhouse as city center
	var city = city_manager.found_city("Test City", test_coord, current_player_id, "longhouse")
	
	if city:
		print("✓ Test city founded at ", test_coord)
		print("  Starting resources: food=%d, wood=%d, stone=%d" % [
			city.get_total_resource("food"),
			city.get_total_resource("wood"),
			city.get_total_resource("stone")
		])
		print("  Population: %d" % city.total_population)
		
		# Update the visual for the longhouse building
		var center_tile = chunk_manager.get_tile_at_coord(test_coord)
		if center_tile:
			center_tile.set_building("longhouse")
			print("  Set longhouse building visual on tile")
		
		print("  Click the city center to open the city overlay!")
	else:
		push_warning("Failed to found test city")

func setup_test_tech_progress():
	"""Set up some test tech progress for development"""
	# Add progress to some branches to see the visualization
	Registry.tech.set_branch_progress("agriculture", 0.0)
	Registry.tech.set_branch_progress("construction", 0.0)
	Registry.tech.set_branch_progress("gathering_and_crafting", 0.0)
	Registry.tech.set_branch_progress("mysticism", 0.0)
	
	print("✓ Set test tech progress")
