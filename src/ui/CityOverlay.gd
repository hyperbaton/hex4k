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

var is_open := false

var close_button: Button
var click_catcher: Control  # Invisible control to catch map clicks

func _ready():
	hide_overlay()
	
	# Connect signals
	action_menu.build_requested.connect(_on_build_requested)
	action_menu.expand_requested.connect(_on_expand_requested)
	action_menu.closed.connect(_on_action_menu_closed)
	resource_detail_panel.closed.connect(_on_resource_detail_closed)
	city_header.clicked.connect(_on_header_clicked)
	
	# Create invisible click catcher (replaces dimmer for click handling)
	_create_click_catcher()
	
	# Create close button
	_create_close_button()

func _create_click_catcher():
	"""Create an invisible full-screen control to catch map clicks"""
	click_catcher = Control.new()
	click_catcher.name = "ClickCatcher"
	click_catcher.anchors_preset = Control.PRESET_FULL_RECT
	click_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	click_catcher.gui_input.connect(_on_click_catcher_input)
	# Add as first child so other UI elements are on top
	add_child(click_catcher)
	move_child(click_catcher, 0)

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

func _input(event: InputEvent):
	"""Handle ESC key to close overlay and close button clicks"""
	if not is_open:
		return
	
	# Handle ESC key
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# If building is selected, cancel selection first
		if selected_building_id != "":
			selected_building_id = ""
			clear_tile_highlights()
			action_menu.close_all_menus()
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
		var click_pos = event.global_position
		
		# Check if click is on close button
		if close_button and close_button.get_global_rect().has_point(click_pos):
			close_overlay()
			get_viewport().set_input_as_handled()
			return
		
		# Check if click is on action menu buttons - if so, don't process
		if action_menu.is_mouse_over():
			return
		
		# Check if click is on header
		if city_header.get_global_rect().has_point(click_pos):
			return
		
		# Click was on the map area
		if selected_building_id != "":
			# In building mode - try to place or cancel
			try_place_building_at_mouse()
		elif is_expand_mode:
			# In expand mode - try to claim tile or cancel
			try_expand_at_mouse()
		else:
			# Not in any mode - close overlay
			close_overlay()
		
		# Mark as handled
		get_viewport().set_input_as_handled()

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
			print("✓ Started construction: ", selected_building_id, " at ", coord)
			
			# Update the visual tile
			update_tile_building_visual(coord, selected_building_id, true)  # true = under construction
			
			# Refresh city display
			current_city.recalculate_city_stats()
			city_header.update_display()
			
			# Clear selection and highlights
			selected_building_id = ""
			clear_tile_highlights()
			action_menu.close_all_menus()
	else:
		print("✗ Cannot build here: ", check.reason)

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
	"""Action menu closed"""
	if selected_building_id != "":
		selected_building_id = ""
		clear_tile_highlights()

func on_highlighted_tile_clicked(coord: Vector2i):
	"""Handle click on a highlighted tile"""
	if selected_building_id != "":
		place_building_at_coord(coord)
	elif is_expand_mode:
		expand_to_tile(coord)

# === Expand Mode ===

func _on_expand_requested():
	"""Player clicked the Expand button"""
	is_expand_mode = true
	selected_building_id = ""  # Cancel any building selection
	print("Entered expand mode")
	
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
