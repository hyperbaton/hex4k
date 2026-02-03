extends CanvasLayer
class_name CityOverlay

# Main city management overlay

signal closed

@onready var dimmer := $Dimmer
@onready var city_header := $CityHeader
@onready var action_menu := $ActionMenu
@onready var resource_detail_panel := $ResourceDetailPanel

var current_city: City
var world_query: WorldQuery
var city_manager: CityManager
var tile_highlighter: TileHighlighter
var chunk_manager: Node  # ChunkManager reference for updating tile visuals
var selected_building_id: String = ""
var is_expand_mode: bool = false  # True when in tile expansion mode
var is_train_mode: bool = false  # True when selecting building for training
var selected_unit_for_training: String = ""  # Unit type to train

var is_open := false

var close_button: Button
var click_catcher: Control  # Invisible control to catch map clicks
var tile_info_panel: CityTileInfoPanel  # Panel for showing tile/building info
var queue_panel: CityQueuePanel  # Panel for showing construction and training queues

func _ready():
	hide_overlay()
	
	# Connect signals
	action_menu.build_requested.connect(_on_build_requested)
	action_menu.expand_requested.connect(_on_expand_requested)
	action_menu.train_requested.connect(_on_train_requested)
	action_menu.closed.connect(_on_action_menu_closed)
	resource_detail_panel.closed.connect(_on_resource_detail_closed)
	city_header.clicked.connect(_on_header_clicked)
	
	# Create invisible click catcher (replaces dimmer for click handling)
	_create_click_catcher()
	
	# Create close button
	_create_close_button()
	
	# Create tile info panel
	_create_tile_info_panel()
	
	# Create queue panel
	_create_queue_panel()

func _create_click_catcher():
	"""Create an invisible full-screen control to catch map clicks"""
	click_catcher = Control.new()
	click_catcher.name = "ClickCatcher"
	# Set explicit size to fill viewport (anchors don't work in CanvasLayer)
	click_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	click_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	click_catcher.gui_input.connect(_on_click_catcher_input)
	# Add as first child so other UI elements are on top
	add_child(click_catcher)
	move_child(click_catcher, 0)
	
	# Update size when viewport changes
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_update_click_catcher_size()

func _on_viewport_size_changed():
	"""Update click catcher size when viewport changes"""
	_update_click_catcher_size()

func _update_click_catcher_size():
	"""Set click catcher to fill viewport"""
	if click_catcher:
		var viewport_size = get_viewport().get_visible_rect().size
		click_catcher.position = Vector2.ZERO
		click_catcher.size = viewport_size
		print("CityOverlay: click_catcher size set to ", viewport_size)

func _create_close_button():
	"""Create an X button in the top-right corner"""
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "✕"
	close_button.add_theme_font_size_override("font_size", 24)
	
	# Position in top-right corner
	close_button.anchors_preset = Control.PRESET_TOP_RIGHT
	close_button.anchor_left = 1.0
	close_button.anchor_right = 1.0
	close_button.anchor_top = 0.0
	close_button.anchor_bottom = 0.0
	close_button.offset_left = -50
	close_button.offset_right = -10
	close_button.offset_top = 10
	close_button.offset_bottom = 50
	
	close_button.pressed.connect(_on_close_button_pressed)
	add_child(close_button)

func _on_close_button_pressed():
	"""Handle close button click"""
	close_overlay()

func _create_tile_info_panel():
	"""Create the tile info panel for displaying tile/building info"""
	tile_info_panel = CityTileInfoPanel.new()
	tile_info_panel.name = "TileInfoPanel"
	tile_info_panel.closed.connect(_on_tile_info_panel_closed)
	tile_info_panel.building_action_requested.connect(_on_building_action_requested)
	add_child(tile_info_panel)
	print("CityOverlay: tile_info_panel created and added to scene")

func _create_queue_panel():
	"""Create the queue panel for displaying construction and training queues"""
	queue_panel = CityQueuePanel.new()
	queue_panel.name = "QueuePanel"
	add_child(queue_panel)
	print("CityOverlay: queue_panel created and added to scene")

func _input(event: InputEvent):
	"""Handle ESC key to close overlay and close button clicks"""
	if not is_open:
		return
	
	# Handle ESC key
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# If tile info panel is visible, close it first
		if tile_info_panel and tile_info_panel.visible:
			tile_info_panel.hide_panel()
			get_viewport().set_input_as_handled()
			return
		# If building is selected, cancel selection first
		elif selected_building_id != "":
			selected_building_id = ""
			clear_tile_highlights()
			action_menu.close_all_menus()
		elif is_train_mode:
			# Cancel train mode
			is_train_mode = false
			selected_unit_for_training = ""
			clear_tile_highlights()
		elif is_expand_mode:
			# Cancel expand mode
			is_expand_mode = false
			clear_tile_highlights()
		else:
			# Close the overlay
			close_overlay()
		get_viewport().set_input_as_handled()
		return
	
	# Handle close button click
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos = event.global_position
		
		if close_button:
			var btn_rect = close_button.get_global_rect()
			if btn_rect.has_point(click_pos):
				if event.pressed:
					# Visual feedback - button pressed
					pass
				else:
					# Button released - close overlay
					close_overlay()
				get_viewport().set_input_as_handled()
				return

func open_city(city: City, p_world_query: WorldQuery, p_city_manager: CityManager, p_tile_highlighter: TileHighlighter, p_chunk_manager: Node = null):
	"""Open the overlay for a specific city"""
	current_city = city
	world_query = p_world_query
	city_manager = p_city_manager
	tile_highlighter = p_tile_highlighter
	chunk_manager = p_chunk_manager
	
	# Pass city reference to action menu
	action_menu.set_city(city)
	
	# Recalculate city stats
	current_city.recalculate_city_stats()
	
	# Update UI
	city_header.set_city(city)
	
	# Show queue panel and update it
	if queue_panel:
		queue_panel.show_panel(city)
	
	# Show overlay
	show_overlay()

func close_overlay():
	"""Close the overlay"""
	if not is_open:
		return
	
	hide_overlay()
	clear_tile_highlights()
	selected_building_id = ""
	is_expand_mode = false
	is_train_mode = false
	selected_unit_for_training = ""
	if tile_info_panel:
		tile_info_panel.hide_panel()
	if queue_panel:
		queue_panel.hide_panel()
	emit_signal("closed")

func show_overlay():
	visible = true
	is_open = true
	# Hide the full-screen dimmer - we use CityTileDimmer for selective dimming instead
	dimmer.visible = false
	# Show click catcher to handle map clicks
	if click_catcher:
		click_catcher.visible = true

func hide_overlay():
	visible = false
	is_open = false
	dimmer.visible = false
	if click_catcher:
		click_catcher.visible = false
	action_menu.close_all_menus()

func _on_click_catcher_input(event: InputEvent):
	"""Handle clicks on the map area"""
	if not is_open:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("CityOverlay: click_catcher received click")
		var click_pos = event.global_position
		
		# Check if click is on close button
		if close_button and close_button.get_global_rect().has_point(click_pos):
			close_overlay()
			get_viewport().set_input_as_handled()
			return
		
		# Check if click is on action menu buttons - if so, don't process
		if action_menu.is_mouse_over():
			print("CityOverlay: click on action menu, ignoring")
			return
		
		# Check if click is on header
		if city_header.get_global_rect().has_point(click_pos):
			print("CityOverlay: click on header, ignoring")
			return
		
		# Check if click is on tile info panel
		if tile_info_panel and tile_info_panel.visible and tile_info_panel.get_global_rect().has_point(click_pos):
			print("CityOverlay: click on tile info panel, ignoring")
			return
		
		# Check if click is on queue panel
		if queue_panel and queue_panel.visible and queue_panel.get_global_rect().has_point(click_pos):
			print("CityOverlay: click on queue panel, ignoring")
			return
		
		# Click was on the map area
		if selected_building_id != "":
			print("CityOverlay: in building mode")
			# In building mode - try to place or cancel
			try_place_building_at_mouse()
		elif is_train_mode:
			print("CityOverlay: in train mode")
			# In training mode - try to select building for training
			try_select_training_building_at_mouse()
		elif is_expand_mode:
			print("CityOverlay: in expand mode")
			# In expand mode - try to claim tile or cancel
			try_expand_at_mouse()
		else:
			print("CityOverlay: showing tile info")
			# Not in any mode - show tile info if clicking on city tile, otherwise close
			_handle_tile_info_click()
		
		# Mark as handled
		get_viewport().set_input_as_handled()

func _handle_tile_info_click():
	"""Handle clicking on a tile to show info"""
	# Get world position
	var camera = get_viewport().get_camera_2d()
	var world_pos = camera.get_global_mouse_position()
	var coord = WorldUtil.pixel_to_axial(world_pos)
	
	print("CityOverlay: clicked at ", coord, " (city has tile: ", current_city.has_tile(coord), ")")
	
	# Check if this tile belongs to the city
	if current_city.has_tile(coord):
		# Show tile info panel
		if tile_info_panel:
			print("CityOverlay: showing tile info panel")
			tile_info_panel.show_tile(coord, current_city, world_query)
		else:
			print("CityOverlay: tile_info_panel is null!")
	else:
		# Clicked outside city - close overlay
		close_overlay()

func _on_tile_info_panel_closed():
	"""Handle tile info panel close"""
	pass

func _on_building_action_requested(action: String, coord: Vector2i):
	"""Handle building action requests from the tile info panel"""
	print("CityOverlay: Building action requested: %s at %v" % [action, coord])
	
	match action:
		"enable":
			_handle_enable_building(coord)
		"disable":
			_handle_disable_building(coord)
		"demolish":
			_handle_demolish_building(coord)
		_:
			push_warning("Unknown building action: " + action)

func _handle_enable_building(coord: Vector2i):
	"""Enable a disabled building"""
	var success = current_city.enable_building(coord)
	
	if success:
		var instance = current_city.get_building_instance(coord)
		var building_name = Registry.get_name_label("building", instance.building_id)
		_show_toast_success("Enabled: " + building_name)
		
		# Update displays
		current_city.recalculate_city_stats()
		city_header.update_display()
		if queue_panel:
			queue_panel.update_display()
		
		# Refresh the tile info panel
		if tile_info_panel:
			tile_info_panel.refresh()
	else:
		var check = current_city.can_enable_building(coord)
		_show_toast_error("Cannot enable: " + check.reason)

func _handle_disable_building(coord: Vector2i):
	"""Disable an active building"""
	var success = current_city.disable_building(coord)
	
	if success:
		var instance = current_city.get_building_instance(coord)
		var building_name = Registry.get_name_label("building", instance.building_id)
		_show_toast_success("Disabled: " + building_name)
		
		# Update displays
		current_city.recalculate_city_stats()
		city_header.update_display()
		if queue_panel:
			queue_panel.update_display()
		
		# Refresh the tile info panel
		if tile_info_panel:
			tile_info_panel.refresh()
	else:
		var check = current_city.can_disable_building(coord)
		_show_toast_error("Cannot disable: " + check.reason)

func _handle_demolish_building(coord: Vector2i):
	"""Demolish a building"""
	var instance = current_city.get_building_instance(coord)
	if not instance:
		return
	
	var building_name = Registry.get_name_label("building", instance.building_id)
	var success = current_city.try_demolish_building(coord)
	
	if success:
		_show_toast_success("Demolished: " + building_name)
		
		# Update tile visual
		update_tile_building_visual(coord, "", false)
		
		# Update displays
		current_city.recalculate_city_stats()
		city_header.update_display()
		if queue_panel:
			queue_panel.update_display()
		
		# Hide the tile info panel since building is gone
		if tile_info_panel:
			tile_info_panel.hide_panel()
	else:
		var check = current_city.can_demolish_building(coord)
		_show_toast_error("Cannot demolish: " + check.reason)

func is_click_outside_ui(pos: Vector2) -> bool:
	"""Check if click is outside all UI elements"""
	# Check header
	if city_header.get_global_rect().has_point(pos):
		return false
	
	# Check action menu
	if action_menu.is_mouse_over():
		return false
	
	# Check resource detail panel
	if resource_detail_panel.visible and resource_detail_panel.get_global_rect().has_point(pos):
		return false
	
	# Check tile info panel
	if tile_info_panel and tile_info_panel.visible and tile_info_panel.get_global_rect().has_point(pos):
		return false
	
	# Check queue panel
	if queue_panel and queue_panel.visible and queue_panel.get_global_rect().has_point(pos):
		return false
	
	return true

func try_place_building_at_mouse():
	"""Try to place the selected building at mouse position"""
	if selected_building_id == "":
		return
	
	# Get world position
	var camera = get_viewport().get_camera_2d()
	var world_pos = camera.get_global_mouse_position()
	var coord = WorldUtil.pixel_to_axial(world_pos)
	
	# Check if this is a valid (highlighted) tile
	if tile_highlighter and tile_highlighter.highlighted_tiles.has(coord):
		# Valid tile - place building
		place_building_at_coord(coord)
	else:
		# Invalid tile - exit building mode
		print("Clicked invalid tile, exiting building mode")
		selected_building_id = ""
		clear_tile_highlights()
		action_menu.close_all_menus()

func place_building_at_coord(coord: Vector2i):
	"""Place building at specific coordinate"""
	# Check if can build here
	var check = world_query.can_build_here(coord, selected_building_id)
	
	if check.can_build:
		# Place building in data model
		var success = city_manager.place_building(current_city.city_id, coord, selected_building_id)
		if success:
			var building_name = Registry.get_name_label("building", selected_building_id)
			print("✓ Started construction: ", selected_building_id, " at ", coord)
			
			# Update the visual tile
			update_tile_building_visual(coord, selected_building_id, true)  # true = under construction
			
			# Refresh city display
			current_city.recalculate_city_stats()
			city_header.update_display()
			
			# Update queue panel
			if queue_panel:
				queue_panel.update_display()
			
			# Show success toast
			_show_toast_success("Started construction: " + building_name)
			
			# Clear selection and highlights
			selected_building_id = ""
			clear_tile_highlights()
			action_menu.close_all_menus()
	else:
		print("✗ Cannot build here: ", check.reason)
		_show_toast_error("Cannot build here: " + check.reason)

func update_tile_building_visual(coord: Vector2i, building_id: String, under_construction: bool = false):
	"""Update the visual representation of a building on a tile"""
	if chunk_manager:
		var tile = chunk_manager.get_tile_at_coord(coord)
		if tile:
			tile.set_building(building_id, under_construction)
			print("  Updated tile visual at ", coord)
		else:
			push_warning("Could not find tile at ", coord)
	else:
		push_warning("No chunk_manager reference available")

func clear_tile_highlights():
	"""Remove all tile highlights"""
	if tile_highlighter:
		tile_highlighter.clear_all()

# === Signal Handlers ===

func _on_header_clicked():
	"""Show detailed resource panel"""
	resource_detail_panel.show_panel(current_city)

func _on_resource_detail_closed():
	"""Hide detailed resource panel"""
	pass

func _on_build_requested(building_id: String):
	"""Player selected a building to place"""
	selected_building_id = building_id
	print("Selected building for placement: ", building_id)
	
	# Hide tile info panel when entering build mode
	if tile_info_panel:
		tile_info_panel.hide_panel()
	
	# Show valid placement tiles
	highlight_valid_tiles(building_id)

func highlight_valid_tiles(building_id: String):
	"""Highlight tiles where building can be placed"""
	# Clear existing highlights
	if tile_highlighter:
		tile_highlighter.clear_all()
	
	# Get all city tiles
	var city_tiles = current_city.tiles.keys()
	
	for coord in city_tiles:
		var check = world_query.can_build_here(coord, building_id)
		
		if check.can_build:
			# Highlight in green
			tile_highlighter.highlight_tile(coord, Color.GREEN)
			
			# Calculate and show adjacency bonuses
			calculate_and_show_adjacency(coord, building_id)

func calculate_and_show_adjacency(coord: Vector2i, building_id: String):
	"""Calculate and display adjacency bonuses"""
	var bonuses = Registry.buildings.get_adjacency_bonuses(building_id)
	
	if bonuses.is_empty():
		return
	
	# Check each bonus
	for bonus in bonuses:
		var source_type = bonus.get("source_type", "")
		var source_id = bonus.get("source_id", "")
		var yields = bonus.get("yields", {})
		var radius = bonus.get("radius", 1)
		
		# Check neighbors
		var neighbors = world_query.get_tiles_in_range(coord, 0, radius)
		
		for neighbor_coord in neighbors:
			if neighbor_coord == coord:
				continue
			
			var matches = false
			
			match source_type:
				"terrain":
					var terrain_id = world_query.get_terrain_id(neighbor_coord)
					matches = (terrain_id == source_id)
				
				"building":
					var view = world_query.get_tile_view(neighbor_coord)
					if view and view.has_building():
						matches = (view.get_building_id() == source_id)
				
				"modifier":
					# TODO: Check modifiers when implemented
					pass
			
			if matches:
				# Show bonus icon on the tile being placed
				for resource_id in yields.keys():
					var amount = yields[resource_id]
					if tile_highlighter:
						tile_highlighter.add_adjacency_bonus_display(coord, resource_id, amount)

func _on_action_menu_closed():
	"""Action menu closed - only clear highlights if NOT in a special mode"""
	# Don't clear highlights if we're in train mode or expand mode - those modes
	# handle their own highlights separately
	if is_train_mode or is_expand_mode:
		return
	
	if selected_building_id != "":
		selected_building_id = ""
		clear_tile_highlights()

func _on_highlighted_tile_clicked(coord: Vector2i):
	"""Handle click on a highlighted tile (from TileHighlighter signal)"""
	print("_on_highlighted_tile_clicked: ", coord)
	
	if selected_building_id != "":
		print("  In building mode - placing building")
		place_building_at_coord(coord)
	elif is_train_mode:
		print("  In train mode - starting training")
		start_training_at_building(coord)
	elif is_expand_mode:
		print("  In expand mode - expanding")
		expand_to_tile(coord)

# === Expand Mode ===

func _on_expand_requested():
	"""Player clicked the Expand button"""
	is_expand_mode = true
	selected_building_id = ""  # Cancel any building selection
	print("Entered expand mode")
	
	# Hide tile info panel when entering expand mode
	if tile_info_panel:
		tile_info_panel.hide_panel()
	
	# Show expandable tiles
	highlight_expandable_tiles()

func highlight_expandable_tiles():
	"""Highlight tiles that can be claimed by the city"""
	# Clear existing highlights
	if tile_highlighter:
		tile_highlighter.clear_all()
	
	# Get all tiles adjacent to city but not in city
	var expandable_coords = get_expandable_tile_coords()
	var available_admin = current_city.get_available_admin_capacity()
	
	for coord in expandable_coords:
		# Calculate admin cost for this tile
		var admin_cost = calculate_tile_admin_cost(coord)
		
		# Determine color based on whether we can afford it
		var color: Color
		if admin_cost <= available_admin:
			color = Color.GREEN  # Can afford
		else:
			color = Color(1.0, 0.5, 0.0)  # Orange - cannot afford
		
		# Highlight with admin cost display
		tile_highlighter.highlight_tile_with_admin_cost(coord, color, admin_cost)

func get_expandable_tile_coords() -> Array[Vector2i]:
	"""Get all tiles that are adjacent to the city but not part of it"""
	var expandable: Array[Vector2i] = []
	var seen := {}
	
	# For each city tile, check its neighbors
	for city_coord in current_city.tiles.keys():
		var neighbors = get_hex_neighbors(city_coord)
		for neighbor in neighbors:
			# Skip if already in city
			if current_city.has_tile(neighbor):
				continue
			# Skip if already seen
			if seen.has(neighbor):
				continue
			# Skip if owned by another city
			if city_manager.is_tile_owned(neighbor):
				continue
			
			seen[neighbor] = true
			expandable.append(neighbor)
	
	return expandable

func get_hex_neighbors(coord: Vector2i) -> Array[Vector2i]:
	"""Get the 6 adjacent hex coordinates"""
	var neighbors: Array[Vector2i] = []
	var directions = [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
	]
	for dir in directions:
		neighbors.append(coord + dir)
	return neighbors

func calculate_tile_admin_cost(coord: Vector2i) -> float:
	"""Calculate the admin cost to claim a tile"""
	var distance = current_city.calculate_distance_from_center(coord)
	return current_city.calculate_tile_claim_cost(distance)

func try_expand_at_mouse():
	"""Try to expand to the tile at mouse position"""
	if not is_expand_mode:
		return
	
	# Get world position
	var camera = get_viewport().get_camera_2d()
	var world_pos = camera.get_global_mouse_position()
	var coord = WorldUtil.pixel_to_axial(world_pos)
	
	# Check if this is a valid (highlighted) tile
	if tile_highlighter and tile_highlighter.highlighted_tiles.has(coord):
		# Valid tile - try to expand
		expand_to_tile(coord)
	else:
		# Invalid tile - exit expand mode
		print("Clicked invalid tile, exiting expand mode")
		is_expand_mode = false
		clear_tile_highlights()

func expand_to_tile(coord: Vector2i):
	"""Attempt to claim a tile for the city"""
	var admin_cost = calculate_tile_admin_cost(coord)
	var available_admin = current_city.get_available_admin_capacity()
	
	if admin_cost > available_admin:
		print("✗ Cannot expand: Insufficient administrative capacity (need %.1f, have %.1f)" % [admin_cost, available_admin])
		return
	
	# Add tile to city
	current_city.add_tile(coord)
	city_manager.tile_ownership[coord] = current_city.city_id
	
	print("✓ Expanded city to ", coord, " (admin cost: %.1f)" % admin_cost)
	
	# Recalculate stats (this will update admin capacity used)
	current_city.recalculate_city_stats()
	
	# Update displays
	city_header.update_display()
	
	# Refresh the expandable tiles display
	highlight_expandable_tiles()
	
	# Update the dimmer to show the new city boundary
	var world = get_tree().get_first_node_in_group("world")
	if not world:
		# Try parent chain
		var parent = get_parent()
		while parent:
			if parent.has_method("get") and parent.get("city_tile_dimmer"):
				parent.city_tile_dimmer.activate(current_city)
				break
			parent = parent.get_parent()

# === Train Mode ===

func _on_train_requested(unit_id: String):
	"""Player requested to train a unit - enter building selection mode"""
	print("CityOverlay: _on_train_requested called with unit_id: ", unit_id)
	
	# Get training cost
	var training_cost = Registry.units.get_training_cost(unit_id)
	print("  Training cost: ", training_cost)
	
	# Check if we can afford it first using city's storage system
	var can_afford = current_city.has_resources(training_cost)
	
	if not can_afford:
		var missing = current_city.get_missing_resources(training_cost)
		var missing_parts: Array[String] = []
		for resource_id in missing.keys():
			var available = current_city.get_total_resource(resource_id)
			var needed = training_cost[resource_id]
			missing_parts.append("%s (need %.0f, have %.0f)" % [resource_id.capitalize(), needed, available])
		var msg = "Not enough resources: " + ", ".join(missing_parts)
		print("✗ " + msg)
		_show_toast_error(msg)
		return
	
	# Check if any building can train this unit
	var trainable_at = Registry.units.get_trained_at(unit_id)
	print("  Trainable at buildings: ", trainable_at)
	var has_training_building = false
	for coord in current_city.building_instances.keys():
		var instance: BuildingInstance = current_city.building_instances[coord]
		print("  Checking building %s at %v: operational=%s, can_train=%s" % [
			instance.building_id, coord, instance.is_operational(), 
			instance.building_id in trainable_at
		])
		if instance.is_operational() and instance.building_id in trainable_at:
			has_training_building = true
			break
	
	if not has_training_building:
		var msg = "No operational building available to train this unit"
		print("✗ " + msg)
		_show_toast_error(msg)
		return
	
	print("  Entering train mode...")
	
	# Enter training mode - select building to train at
	is_train_mode = true
	selected_unit_for_training = unit_id
	selected_building_id = ""  # Clear any building placement
	is_expand_mode = false
	
	# Close menus (this will NOT clear highlights because is_train_mode is now true)
	action_menu.close_all_menus()
	
	# Hide tile info panel
	if tile_info_panel:
		tile_info_panel.hide_panel()
	
	# Highlight buildings that can train this unit
	print("  Highlighting training buildings...")
	highlight_training_buildings(unit_id)
	
	# Show instruction
	_show_toast_info("Select a building to train " + Registry.units.get_unit_name(unit_id))

func highlight_training_buildings(unit_id: String):
	"""Highlight buildings that can train the specified unit"""
	print("  highlight_training_buildings called for: ", unit_id)
	
	# Clear existing highlights
	if tile_highlighter:
		tile_highlighter.clear_all()
		print("    Cleared existing highlights")
	else:
		print("    WARNING: tile_highlighter is null!")
		return
	
	var trainable_at = Registry.units.get_trained_at(unit_id)
	var found_building = false
	
	print("    Looking for buildings: ", trainable_at)
	print("    City has %d building instances" % current_city.building_instances.size())
	
	# Check each building in the city
	for coord in current_city.building_instances.keys():
		var instance: BuildingInstance = current_city.building_instances[coord]
		
		print("    Checking %s at %v: operational=%s, in_list=%s, training=%s" % [
			instance.building_id, coord, instance.is_operational(),
			instance.building_id in trainable_at, instance.is_training()
		])
		
		# Must be operational and able to train this unit
		if not instance.is_operational():
			continue
		
		if not instance.building_id in trainable_at:
			continue
		
		# Check if already training
		var color: Color
		if instance.is_training():
			# Orange - building is busy
			color = Color(1.0, 0.5, 0.0)
		else:
			# Green - available
			color = Color.GREEN
		
		print("    Highlighting %v with color %s" % [coord, color])
		tile_highlighter.highlight_tile(coord, color)
		found_building = true
	
	if not found_building:
		print("✗ No buildings available to train this unit")
		is_train_mode = false
		selected_unit_for_training = ""
	else:
		print("    Found trainable buildings, train mode active")

func try_select_training_building_at_mouse():
	"""Try to select a building for training at mouse position"""
	print("try_select_training_building_at_mouse called")
	print("  is_train_mode: ", is_train_mode)
	print("  selected_unit_for_training: ", selected_unit_for_training)
	
	if not is_train_mode or selected_unit_for_training == "":
		print("  Aborting - not in train mode or no unit selected")
		return
	
	# Get world position
	var camera = get_viewport().get_camera_2d()
	var world_pos = camera.get_global_mouse_position()
	var coord = WorldUtil.pixel_to_axial(world_pos)
	
	print("  Clicked coord: ", coord, " (type: ", typeof(coord), ")")
	print("  Highlighted tiles: ", tile_highlighter.highlighted_tiles.keys() if tile_highlighter else "no highlighter")
	
	# Check if this is a valid (highlighted) tile
	if tile_highlighter and tile_highlighter.highlighted_tiles.has(coord):
		print("  Valid tile - starting training")
		# Valid tile - try to start training
		start_training_at_building(coord)
	else:
		# Invalid tile - exit training mode
		print("  Invalid tile (not highlighted), exiting training mode")
		is_train_mode = false
		selected_unit_for_training = ""
		clear_tile_highlights()

func start_training_at_building(coord: Vector2i):
	"""Start training the selected unit at the specified building"""
	if not current_city.building_instances.has(coord):
		print("✗ No building at this location")
		_show_toast_error("No building at this location")
		return
	
	var instance: BuildingInstance = current_city.building_instances[coord]
	
	# Check if building is already training
	if instance.is_training():
		var training_name = Registry.units.get_unit_name(instance.training_unit_id)
		print("✗ Building is already training: %s" % instance.training_unit_id)
		_show_toast_warning("This building is already training: " + training_name)
		return
	
	# Check if building can train this unit
	if not instance.can_train_unit(selected_unit_for_training):
		print("✗ This building cannot train this unit")
		_show_toast_error("This building cannot train this unit")
		return
	
	# Get training cost and turns
	var training_cost = Registry.units.get_training_cost(selected_unit_for_training)
	var training_turns = Registry.units.get_training_turns(selected_unit_for_training)
	
	# Double-check we can afford it using city's storage system
	if not current_city.has_resources(training_cost):
		var missing = current_city.get_missing_resources(training_cost)
		var missing_parts: Array[String] = []
		for resource_id in missing.keys():
			var available = current_city.get_total_resource(resource_id)
			var needed = training_cost[resource_id]
			missing_parts.append("%s (need %.0f, have %.0f)" % [resource_id.capitalize(), needed, available])
		print("✗ Cannot train: Not enough resources: " + ", ".join(missing_parts))
		_show_toast_error("Not enough resources: " + ", ".join(missing_parts))
		is_train_mode = false
		selected_unit_for_training = ""
		clear_tile_highlights()
		return
	
	# Deduct resources using city's storage system
	for resource_id in training_cost.keys():
		var cost = training_cost[resource_id]
		var consumed = current_city.consume_resource(resource_id, cost)
		print("  Deducted %s: %.1f" % [resource_id, consumed])
	
	# Start training at this building
	instance.start_training(selected_unit_for_training, training_turns)
	
	var unit_name = Registry.units.get_unit_name(selected_unit_for_training)
	var building_name = Registry.get_name_label("building", instance.building_id)
	print("✓ Started training: %s at %s" % [unit_name, building_name])
	print("  Cost: ", training_cost)
	print("  Turns: ", training_turns)
	
	# Exit training mode
	is_train_mode = false
	selected_unit_for_training = ""
	clear_tile_highlights()
	
	# Update displays
	city_header.update_display()
	
	# Update queue panel
	if queue_panel:
		queue_panel.update_display()
	
	# Show success message
	_show_toast_success("Training %s at %s (%d turns)" % [unit_name, building_name, training_turns])

# === Toast Notifications ===

var toast_layer: ToastNotification

func _show_toast_error(msg: String):
	_ensure_toast_layer()
	ToastNotification.show_error(msg)

func _show_toast_success(msg: String):
	_ensure_toast_layer()
	ToastNotification.show_success(msg)

func _show_toast_info(msg: String):
	_ensure_toast_layer()
	ToastNotification.show_message(msg, 2.5, "info")

func _show_toast_warning(msg: String):
	_ensure_toast_layer()
	ToastNotification.show_warning(msg)

func _ensure_toast_layer():
	if not toast_layer or not is_instance_valid(toast_layer):
		toast_layer = ToastNotification.new()
		toast_layer.name = "ToastNotification"
		get_tree().root.add_child(toast_layer)
