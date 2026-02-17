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
var fog_manager: FogOfWarManager
var fog_overlay: FogOfWarOverlay
var unit_ability_bar: UnitAbilityBar
var unit_info_panel: UnitInfoPanel
var cargo_dialog: CargoDialog
var end_turn_button: Button
var turn_label: Label
var turn_report_panel: PanelContainer
var perks_panel: PerksPanel
var perks_button: Button

var current_player_id := "player1"

func _ready():
	# Initialize managers
	world_query.initialize(self, city_manager)
	tile_highlighter.initialize(world_query)
	
	# Create unit manager
	unit_manager = UnitManager.new()
	
	# Create turn manager with unit manager and world_query references
	turn_manager = TurnManager.new(city_manager, unit_manager, world_query)
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

	# Create fog of war manager (logic)
	fog_manager = FogOfWarManager.new()

	# Create fog of war overlay (visuals, above unit layer)
	fog_overlay = FogOfWarOverlay.new()
	fog_overlay.name = "FogOfWarOverlay"
	add_child(fog_overlay)
	move_child(fog_overlay, unit_layer.get_index() + 1)

	# Create turn UI
	_create_turn_ui()
	
	# Create unit ability bar (in UI layer)
	_create_unit_ability_bar()
	
	# Create unit info panel (right side)
	_create_unit_info_panel()
	
	# Create cargo dialog (modal, centered)
	_create_cargo_dialog()
	
	# Create perks panel and button
	_create_perks_ui()

	# Connect signals
	chunk_manager.tile_selected.connect(_on_tile_selected)
	city_overlay.closed.connect(_on_city_overlay_closed)
	tile_highlighter.tile_clicked.connect(_on_highlighted_tile_clicked)
	tech_tree_button.pressed.connect(_on_tech_tree_button_pressed)
	tech_tree_screen.closed.connect(_on_tech_tree_closed)
	perks_button.pressed.connect(_on_perks_button_pressed)
	perks_panel.closed.connect(_on_perks_panel_closed)

	# Connect fog of war recalculation triggers
	unit_manager.unit_moved.connect(_on_fog_trigger_unit_moved)
	unit_manager.unit_spawned.connect(_on_fog_trigger_unit_changed)
	unit_manager.unit_destroyed.connect(_on_fog_trigger_unit_changed)
	city_manager.city_founded.connect(_on_fog_trigger_city_changed)
	
	# Start or load world
	match GameState.mode:
		GameState.Mode.NEW_GAME:
			start_new_world()

		GameState.Mode.LOAD_GAME:
			load_existing_world()
	
	# Initialize player and starting units
	setup_player_start()
	setup_test_tech_progress()

	# Initialize fog of war after city/unit setup
	fog_manager.initialize(current_player_id, city_manager, unit_manager, world_query)
	fog_overlay.setup(fog_manager)
	chunk_manager.fog_manager = fog_manager
	unit_layer.fog_manager = fog_manager
	city_manager.fog_manager = fog_manager
	fog_manager.visibility_changed.connect(unit_layer.update_fog_visibility)
	fog_manager.recalculate_visibility()

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

func _create_unit_ability_bar():
	"""Create the unit ability bar UI"""
	var ui_root = $UI/Root
	
	unit_ability_bar = UnitAbilityBar.new()
	unit_ability_bar.name = "UnitAbilityBar"
	unit_ability_bar.set_context({
		world_query = world_query,
		city_manager = city_manager,
		unit_manager = unit_manager
	})
	unit_ability_bar.ability_requested.connect(_on_ability_requested)
	ui_root.add_child(unit_ability_bar)

func _create_unit_info_panel():
	"""Create the unit info panel (right side of screen)"""
	var ui_root = $UI/Root
	
	unit_info_panel = UnitInfoPanel.new()
	unit_info_panel.name = "UnitInfoPanel_Unit"
	# Position on the right side
	unit_info_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	unit_info_panel.anchor_left = 1.0
	unit_info_panel.anchor_right = 1.0
	unit_info_panel.anchor_top = 0.5
	unit_info_panel.anchor_bottom = 0.5
	unit_info_panel.offset_left = -240
	unit_info_panel.offset_right = -10
	unit_info_panel.offset_top = -200
	unit_info_panel.offset_bottom = 200
	unit_info_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	unit_info_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	ui_root.add_child(unit_info_panel)

func _create_cargo_dialog():
	"""Create the cargo transfer dialog (centered modal)"""
	var ui_root = $UI/Root
	
	cargo_dialog = CargoDialog.new()
	cargo_dialog.name = "CargoDialog"
	cargo_dialog.transfer_completed.connect(_on_cargo_transfer_completed)
	cargo_dialog.dialog_closed.connect(_on_cargo_dialog_closed)
	ui_root.add_child(cargo_dialog)

func _on_cargo_transfer_completed():
	"""Cargo was transferred - refresh unit displays"""
	var unit = unit_layer.selected_unit
	if unit:
		if unit_info_panel:
			unit_info_panel.refresh()
		if unit_ability_bar:
			unit_ability_bar.refresh()
		# Refresh movement range (cargo weight doesn't affect it, but abilities might change)
		_show_unit_movement_range(unit)

func _on_cargo_dialog_closed():
	"""Cargo dialog was cancelled"""
	pass

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
	
	# Show toast notifications for perk unlocks
	for perk_id in report.perks_unlocked:
		var perk_name = Registry.perks.get_perk_name(perk_id)
		ToastNotification.show_success("Perk Unlocked: %s" % perk_name, 5.0)

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

	# Recalculate fog of war (city expansions, buildings completed)
	if fog_manager:
		fog_manager.recalculate_visibility()

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
	# Don't handle tile selection if city overlay, tech tree, or perks panel is open
	if city_overlay.is_open or tech_tree_screen.is_open or perks_panel.is_open:
		return
	
	# Don't handle if turn report is showing
	if turn_report_panel and turn_report_panel.visible:
		return
	
	# Don't handle if cargo dialog is open
	if cargo_dialog and cargo_dialog.visible:
		return
	
	# Get tile coordinate
	var coord = Vector2i(tile.data.q, tile.data.r)
	print("World._on_tile_selected: coord=", coord)

	# Fog of war checks
	if fog_manager:
		var visibility = fog_manager.get_tile_visibility(coord)
		if visibility == FogOfWarManager.TileVisibility.UNDISCOVERED:
			return  # Cannot interact with undiscovered tiles
		if visibility == FogOfWarManager.TileVisibility.EXPLORED:
			# Show limited info for explored tiles
			tile_info_panel.show_explored_tile(tile)
			# Deselect any selected unit
			if unit_layer.selected_unit:
				unit_layer.deselect_unit()
				tile_highlighter.clear_all()
				if unit_ability_bar:
					unit_ability_bar.hide_bar()
				if unit_info_panel:
					unit_info_panel.hide_panel()
			return

	# Check for unit at this tile first
	var unit_at_tile = unit_manager.get_unit_at(coord) if unit_manager else null
	print("  unit_at_tile: ", unit_at_tile, " (unit_manager exists: ", unit_manager != null, ")")
	
	# Hide enemy units in non-visible tiles
	if unit_at_tile and unit_at_tile.owner_id != current_player_id:
		if fog_manager and not fog_manager.is_tile_visible(coord):
			unit_at_tile = null

	if unit_at_tile:
		print("  Unit found: ", unit_at_tile.unit_id, " owner: ", unit_at_tile.owner_id)
		# There's a unit here - check if it belongs to the current player
		if unit_at_tile.owner_id == current_player_id:
			# Is this unit already selected?
			if unit_layer.selected_unit == unit_at_tile:
				print("  Unit already selected - checking for city")
				# Unit already selected - clicking again opens city if applicable
				var city = city_manager.get_city_at_tile(coord)
				if city and city.owner and city.owner.player_id == current_player_id:
					# Deselect unit and open city
					unit_layer.deselect_unit()
					tile_highlighter.clear_all()
					if unit_ability_bar:
						unit_ability_bar.hide_bar()
					if unit_info_panel:
						unit_info_panel.hide_panel()
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
				# Show unit info panel
				if unit_info_panel:
					unit_info_panel.show_unit(unit_at_tile)
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
			if unit_ability_bar:
				unit_ability_bar.hide_bar()
			if unit_info_panel:
				unit_info_panel.hide_panel()
	
	# Check for city
	var tile_view = world_query.get_tile_view(coord)
	
	if tile_view:
		# Check if clicking on any tile that belongs to a city owned by the player
		var city = city_manager.get_city_at_tile(coord)
		if city and city.owner and city.owner.player_id == current_player_id:
			# Deselect any selected unit when entering city
			unit_layer.deselect_unit()
			tile_highlighter.clear_all()
			if unit_ability_bar:
				unit_ability_bar.hide_bar()
			if unit_info_panel:
				unit_info_panel.hide_panel()
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
	
	# Show ability bar for the unit
	if unit_ability_bar:
		unit_ability_bar.show_unit_abilities(unit)

func _move_selected_unit_to(coord: Vector2i):
	"""Move the selected unit to the target coordinate"""
	var unit = unit_layer.selected_unit
	if not unit:
		return

	# Safety check: don't move onto a tile with a friendly unit
	var existing_unit = unit_manager.get_unit_at(coord)
	if existing_unit and existing_unit.owner_id == unit.owner_id:
		print("Cannot move to ", coord, " - tile occupied by friendly unit")
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
	
	# Refresh unit info panel
	if unit_info_panel:
		unit_info_panel.refresh()
	
	# Update movement highlights
	if unit.current_movement > 0:
		# Still has movement - show new range
		_show_unit_movement_range(unit)
	else:
		# No more movement - clear highlights but keep selected
		tile_highlighter.clear_all()
		print("Unit has no more movement this turn")
		# Refresh ability bar (conditions may have changed)
		if unit_ability_bar:
			unit_ability_bar.show_unit_abilities(unit)

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

func _on_ability_requested(ability_id: String, params: Dictionary):
	"""Handle ability button press"""
	var unit = unit_layer.selected_unit
	if not unit:
		print("✗ No unit selected for ability")
		return
	
	print("Executing ability: ", ability_id, " with params: ", params)
	
	# Build context
	var context = {
		world_query = world_query,
		city_manager = city_manager,
		unit_manager = unit_manager
	}
	
	# Execute ability
	var result = Registry.abilities.execute_ability(ability_id, unit, params, context)
	
	if result.success:
		print("✓ Ability executed: ", result.message)
		
		# Check if we need to open a dialog
		if result.results.get("open_dialog", "") == "cargo":
			# Open cargo dialog for unit at its current city
			var city = city_manager.get_city_at_tile(unit.coord)
			if city and cargo_dialog:
				print("  Opening cargo dialog for %s at %s" % [unit.unit_id, city.city_name])
				cargo_dialog.open(unit, city)
			else:
				print("✗ Cannot open cargo dialog - no city at unit location")
			return
		
		# Check if unit was consumed
		if result.results.get("unit_consumed", false):
			print("  Unit consumed by ability")
			# Remove the unit
			unit_manager.remove_unit(unit.unit_id)
			unit_layer.deselect_unit()
			tile_highlighter.clear_all()
			if unit_ability_bar:
				unit_ability_bar.hide_bar()
			if unit_info_panel:
				unit_info_panel.hide_panel()
			
			# If a city was founded, show it
			if result.results.has("city"):
				var city = result.results.city
				print("  City founded: ", city.city_name)
				# Update tile visual
				var center_tile = chunk_manager.get_tile_at_coord(city.city_center_coord)
				if center_tile:
					var building_id = city.get_building_instance(city.city_center_coord).building_id
					center_tile.set_building(building_id)
			return
		
		# Check if infrastructure was built - refresh tile visual
		if result.results.has("built_modifier"):
			var built_coord = result.results.get("coord", unit.coord)
			var tile = chunk_manager.get_tile_at_coord(built_coord)
			if tile:
				# Refresh tile data to pick up the new modifier
				var terrain_data = world_query.get_terrain_data(built_coord)
				if terrain_data:
					tile.modifier_ids = terrain_data.modifiers.duplicate()
					tile.queue_redraw()
					tile.update_modifier_visuals()
				print("  Path built at %v - tile refreshed" % built_coord)
		
		# Unit still exists - refresh displays
		_show_unit_movement_range(unit)
		if unit_info_panel:
			unit_info_panel.refresh()
	else:
		print("✗ Ability failed: ", result.message)

# === Fog of War Signal Handlers ===

func _on_fog_trigger_unit_moved(_unit: Unit, _from_coord: Vector2i, _to_coord: Vector2i):
	if fog_manager:
		fog_manager.recalculate_visibility()

func _on_fog_trigger_unit_changed(_unit: Unit):
	if fog_manager:
		fog_manager.recalculate_visibility()

func _on_fog_trigger_city_changed(_city: City):
	if fog_manager:
		fog_manager.recalculate_visibility()

func _on_tech_tree_button_pressed():
	if not tech_tree_screen.is_open:
		tech_tree_screen.show_screen()

func _on_tech_tree_closed():
	pass  # Could re-enable other UI if needed

func _create_perks_ui():
	"""Create the Perks button and PerksPanel."""
	# Perks panel (CanvasLayer, created in code)
	perks_panel = PerksPanel.new()
	perks_panel.name = "PerksPanel"
	add_child(perks_panel)

	# Perks button (positioned next to the tech tree button)
	var ui_root = $UI/Root
	perks_button = Button.new()
	perks_button.name = "PerksButton"
	perks_button.text = "Perks"
	perks_button.custom_minimum_size = Vector2(80, 36)
	# Position below tech tree button (top-left area)
	perks_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	perks_button.offset_left = 10
	perks_button.offset_top = 50
	perks_button.offset_right = 90
	perks_button.offset_bottom = 86
	ui_root.add_child(perks_button)

func _on_perks_button_pressed():
	if not perks_panel.is_open:
		var player = city_manager.get_player(current_player_id)
		var perk_game_state := {}
		if player:
			perk_game_state = Registry.perks.build_game_state_for_player(
				player, city_manager, unit_manager, world_query,
				turn_manager.get_current_turn(), turn_manager.get_last_report()
			)
		perks_panel.show_panel(player, perk_game_state)

func _on_perks_panel_closed():
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

# === Player Start ===

func setup_player_start():
	"""Initialize the player with starting units (nomadic band + explorer)"""
	await get_tree().create_timer(0.5).timeout  # Wait for chunks to load

	# Create player
	city_manager.create_player(current_player_id, "Test Player")

	# Starting position (will be randomized later)
	var start_coord = Vector2i(-12, 15)
	var adjacent_coord = Vector2i(start_coord.x + 1, start_coord.y)

	# Spawn nomadic band (can found first encampment)
	var band = unit_manager.spawn_unit("nomadic_band", current_player_id, start_coord)
	if band:
		print("✓ Nomadic band spawned at ", start_coord)

	# Spawn explorer next to the nomadic band
	var explorer = unit_manager.spawn_unit("explorer", current_player_id, adjacent_coord)
	if explorer:
		print("✓ Explorer spawned at ", adjacent_coord)

	# Center camera on starting position
	camera.focus_on_coord(start_coord)

# === Test Setup (temporary) ===

func setup_test_city():
	"""Create a test city for development (not called by default)"""
	await get_tree().create_timer(0.5).timeout  # Wait for chunks to load

	# Create player if not already created
	if not city_manager.get_player(current_player_id):
		city_manager.create_player(current_player_id, "Test Player")

	# Find a suitable location (on land)
	var test_coord = Vector2i(-12, 15)

	# Found city (encampment settlement type auto-places longhouse as city center)
	var city = city_manager.found_city("Test City", test_coord, current_player_id)

	if city:
		print("✓ Test city founded at ", test_coord)
		print("  Starting resources: food=%d, wood=%d, stone=%d" % [
			city.get_total_resource("food"),
			city.get_total_resource("wood"),
			city.get_total_resource("stone")
		])
		print("  Population: %d" % city.get_total_population())

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
