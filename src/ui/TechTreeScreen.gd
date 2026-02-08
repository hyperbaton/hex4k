extends CanvasLayer
class_name TechTreeScreen

# Full-screen tech tree visualization with metro-map style branches

signal closed

const BACKGROUND_COLOR = Color(0.12, 0.14, 0.22)  # Deep unsaturated blue
const LOCKED_COLOR_MULT = 0.4  # How much to dim locked portions
const BRANCH_WIDTH = 12.0  # Width of branch lines
const MILESTONE_RADIUS = 16.0  # Radius of milestone circles
const BRANCH_SPACING = 120.0  # Vertical spacing between branches
const LEVEL_SCALE = 60.0  # Pixels per research level unit
const MARGIN_LEFT = 130.0  # Left margin
const MARGIN_TOP = 100.0  # Top margin
const FORK_DIAGONAL_LENGTH = 40.0  # How far child branches travel diagonally
const ICON_SIZE = 40.0  # Size of branch icons
const ICON_OFFSET = 90.0  # How far before branch start the icon appears

var is_open := false

# Cached branch icon textures
var branch_icons: Dictionary = {}  # branch_id -> Texture2D

# Camera/view state
var view_offset := Vector2.ZERO
var view_zoom := 1.0
var is_dragging := false
var drag_start_pos := Vector2.ZERO
var drag_start_offset := Vector2.ZERO
var drag_distance := 0.0  # Track how far we dragged

# UI elements
var background: ColorRect
var close_button: Button
var tree_container: Control  # Container for the tree drawing
var tree_drawer: TechTreeDrawer  # Custom drawing node
var info_popup: PanelContainer  # Popup for branch/milestone info

# Layout data (computed once, deterministic)
var branch_y_positions: Dictionary = {}  # branch_id -> y position
var branch_layouts: Dictionary = {}  # branch_id -> {start_x, y, color, milestones: [{x, id, visible, unlocked}]}

# Currently displayed branch in popup (for focus button)
var _popup_branch_id: String = ""

func _ready():
	layer = 100  # Above everything else
	_create_ui()
	hide_screen()
	
	# Start with process mode disabled
	process_mode = Node.PROCESS_MODE_DISABLED

func _create_ui():
	# Root control to hold everything (needed for proper anchor behavior in CanvasLayer)
	var root = Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP  # Block all input from going through
	add_child(root)
	
	# Background
	background = ColorRect.new()
	background.name = "Background"
	background.color = BACKGROUND_COLOR
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(background)
	
	# Tree container (for panning/zooming) - this is a SubViewportContainer approach
	# Actually, let's use a simpler approach with a Control that we transform
	tree_container = Control.new()
	tree_container.name = "TreeContainer"
	tree_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	tree_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tree_container)
	
	# Tree drawer (custom drawing)
	tree_drawer = TechTreeDrawer.new()
	tree_drawer.name = "TreeDrawer"
	tree_drawer.tech_screen = self
	tree_container.add_child(tree_drawer)
	
	# Info popup (hidden by default)
	_create_info_popup(root)
	
	# Close button
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "✕"
	close_button.add_theme_font_size_override("font_size", 28)
	close_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_button.offset_left = -60
	close_button.offset_right = -10
	close_button.offset_top = 10
	close_button.offset_bottom = 60
	close_button.pressed.connect(_on_close_pressed)
	root.add_child(close_button)
	
	# Connect input
	background.gui_input.connect(_on_background_input)

func _create_info_popup(parent: Control):
	info_popup = PanelContainer.new()
	info_popup.name = "InfoPopup"
	info_popup.visible = false
	info_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var outer_vbox = VBoxContainer.new()
	outer_vbox.name = "OuterVBox"
	outer_vbox.add_theme_constant_override("separation", 8)
	info_popup.add_child(outer_vbox)
	
	var hbox = HBoxContainer.new()
	hbox.name = "HBox"
	hbox.add_theme_constant_override("separation", 12)
	outer_vbox.add_child(hbox)
	
	# Icon container with TextureRect
	var icon_rect = TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.custom_minimum_size = Vector2(48, 48)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(icon_rect)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	hbox.add_child(vbox)
	
	var title_label = Label.new()
	title_label.name = "Title"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	
	var detail_label = Label.new()
	detail_label.name = "Detail"
	detail_label.add_theme_font_size_override("font_size", 14)
	detail_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(detail_label)
	
	# Unlocks section (hidden by default)
	var unlocks_separator = HSeparator.new()
	unlocks_separator.name = "UnlocksSeparator"
	unlocks_separator.visible = false
	outer_vbox.add_child(unlocks_separator)
	
	var unlocks_label = Label.new()
	unlocks_label.name = "UnlocksLabel"
	unlocks_label.text = "Unlocks:"
	unlocks_label.add_theme_font_size_override("font_size", 13)
	unlocks_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	unlocks_label.visible = false
	outer_vbox.add_child(unlocks_label)
	
	var unlocks_container = HBoxContainer.new()
	unlocks_container.name = "UnlocksContainer"
	unlocks_container.add_theme_constant_override("separation", 10)
	unlocks_container.visible = false
	outer_vbox.add_child(unlocks_container)
	
	# Focus Research button (hidden by default, shown for branches)
	var focus_button = Button.new()
	focus_button.name = "FocusButton"
	focus_button.text = "⬤ Focus Research Here"
	focus_button.add_theme_font_size_override("font_size", 13)
	focus_button.visible = false
	focus_button.pressed.connect(_on_focus_research_pressed)
	outer_vbox.add_child(focus_button)
	
	parent.add_child(info_popup)

func _on_close_pressed():
	hide_screen()

func _on_background_input(event: InputEvent):
	# Handle panning (click and drag)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_start_pos = event.global_position
				drag_start_offset = view_offset
				drag_distance = 0.0
				hide_info_popup()
			else:
				# On release, check if this was a click (not a drag)
				if drag_distance < 5.0:
					# This was a click - check for branch/milestone
					_handle_click(event.global_position)
				is_dragging = false
			background.accept_event()  # Consume the event
		
		# Handle zooming (scroll wheel)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at_point(event.global_position, 1.1)  # Zoom in
			background.accept_event()  # Consume the event so world doesn't zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at_point(event.global_position, 0.9)  # Zoom out
			background.accept_event()  # Consume the event so world doesn't zoom
	
	elif event is InputEventMouseMotion:
		if is_dragging:
			var delta = event.global_position - drag_start_pos
			drag_distance = delta.length()
			view_offset = drag_start_offset + delta / view_zoom
			_update_tree_transform()

func _handle_click(screen_pos: Vector2):
	"""Handle a click (not a drag) on the tech tree"""
	var world_pos = _screen_to_world(screen_pos)
	
	# Check for milestone click first (higher priority)
	var milestone_id = get_milestone_at_point(world_pos)
	if milestone_id != "":
		show_milestone_info(milestone_id, screen_pos)
		return
	
	# Check for branch click
	var branch_id = get_branch_at_point(world_pos)
	if branch_id != "":
		show_branch_info(branch_id, screen_pos)
		return

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	# Convert screen position to tree world coordinates
	# Reverse the transform: position = base + offset * zoom
	# So: world = (screen - base) / zoom - offset
	var base_position = Vector2(MARGIN_LEFT, MARGIN_TOP)
	return (screen_pos - base_position) / view_zoom - view_offset

func _zoom_at_point(point: Vector2, factor: float):
	var old_zoom = view_zoom
	view_zoom = clamp(view_zoom * factor, 0.25, 3.0)
	
	# Adjust offset to zoom towards mouse position
	# We want the world point under the mouse to stay in the same screen position
	var base_position = Vector2(MARGIN_LEFT, MARGIN_TOP)
	var world_pos_before = (point - base_position) / old_zoom - view_offset
	var world_pos_after = (point - base_position) / view_zoom - view_offset
	view_offset += world_pos_after - world_pos_before
	
	_update_tree_transform()

func _update_tree_transform():
	# Position tree drawer so that (0,0) in tree space is at top-left with margins
	# Then apply panning offset and zoom
	var base_position = Vector2(MARGIN_LEFT, MARGIN_TOP)
	
	tree_drawer.position = base_position + view_offset * view_zoom
	tree_drawer.scale = Vector2(view_zoom, view_zoom)
	tree_drawer.queue_redraw()

func _input(event: InputEvent):
	if not is_open:
		return
	
	# Handle ESC to close
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide_screen()
		get_viewport().set_input_as_handled()

func show_screen():
	visible = true
	is_open = true
	view_offset = Vector2.ZERO
	view_zoom = 1.0
	
	# Load branch icons
	_load_branch_icons()
	
	# Compute layout
	compute_branch_layout()
	
	_update_tree_transform()
	tree_drawer.queue_redraw()
	
	# Ensure we capture all input by setting process mode
	process_mode = Node.PROCESS_MODE_ALWAYS

func hide_screen():
	visible = false
	is_open = false
	hide_info_popup()
	process_mode = Node.PROCESS_MODE_DISABLED
	emit_signal("closed")

func _load_branch_icons():
	"""Load icon textures for all branches"""
	branch_icons.clear()
	var all_branches = Registry.tech.get_all_branch_ids()
	
	for branch_id in all_branches:
		var icon_path = Registry.tech.get_branch_icon_path(branch_id)
		if icon_path != "" and ResourceLoader.exists(icon_path):
			var texture = load(icon_path)
			if texture:
				branch_icons[branch_id] = texture

func compute_branch_layout():
	"""Compute deterministic positions for all branches and milestones"""
	branch_y_positions.clear()
	branch_layouts.clear()
	
	# Get all branches and filter to only visible ones
	var all_branches = Registry.tech.get_all_branch_ids()
	var visible_branches: Array[String] = []
	for branch_id in all_branches:
		if Registry.tech.is_branch_visible(branch_id):
			visible_branches.append(branch_id)
	
	# Get visible root branches and assign Y positions
	var root_branches = Registry.tech.get_root_branches()
	var y_pos = 0.0
	
	# First pass: assign Y positions to visible root branches
	for branch_id in root_branches:
		if not Registry.tech.is_branch_visible(branch_id):
			continue
		branch_y_positions[branch_id] = y_pos
		y_pos += BRANCH_SPACING
	
	# Second pass: assign Y positions to visible child branches (recursively)
	var processed = {}
	for branch_id in branch_y_positions.keys():
		processed[branch_id] = true
	
	# Keep processing until all visible branches have positions
	var iterations = 0
	while processed.size() < visible_branches.size() and iterations < 100:
		iterations += 1
		for branch_id in visible_branches:
			if processed.has(branch_id):
				continue
			
			var starts_from = Registry.tech.get_branch_starts_from(branch_id)
			if starts_from.is_empty():
				continue
			
			var parent_branch = starts_from.get("branch", "")
			if not processed.has(parent_branch):
				continue
			
			# Place child branch below parent with offset
			var parent_y = branch_y_positions[parent_branch]
			branch_y_positions[branch_id] = y_pos
			y_pos += BRANCH_SPACING
			processed[branch_id] = true
	
	# Third pass: compute full layout for each visible branch
	for branch_id in visible_branches:
		_compute_branch_layout(branch_id)

func _compute_branch_layout(branch_id: String):
	var branch = Registry.tech.get_branch(branch_id)
	var color = Registry.tech.get_branch_color(branch_id)
	var y = branch_y_positions.get(branch_id, 0.0)
	
	# Determine start X
	var start_x = 0.0
	var starts_from = Registry.tech.get_branch_starts_from(branch_id)
	var fork_from_x = 0.0
	var fork_from_y = 0.0
	
	if not starts_from.is_empty():
		var parent_branch = starts_from.get("branch", "")
		var parent_milestone = starts_from.get("milestone", "")
		var parent_y = branch_y_positions.get(parent_branch, 0.0)
		
		# Get the X position of the parent milestone (including parent's own offset)
		var parent_start_x = 0.0
		if branch_layouts.has(parent_branch):
			parent_start_x = branch_layouts[parent_branch].start_x
		var milestone_level = Registry.tech.get_milestone_level(parent_milestone)
		fork_from_x = parent_start_x + milestone_level * LEVEL_SCALE
		fork_from_y = parent_y
		start_x = fork_from_x  # Child branch starts at same X as parent milestone
	
	# Collect milestones with their positions (now using get_milestones_for_branch)
	var milestone_ids = Registry.tech.get_milestones_for_branch(branch_id)
	var milestones_data = []
	
	for milestone_id in milestone_ids:
		var level = Registry.tech.get_milestone_level(milestone_id)
		var is_visible = Registry.tech.is_milestone_visible(milestone_id)
		var is_unlocked = Registry.tech.is_milestone_unlocked(milestone_id)
		
		milestones_data.append({
			"id": milestone_id,
			"x": start_x + level * LEVEL_SCALE,
			"visible": is_visible,
			"unlocked": is_unlocked
		})
	
	# Sort milestones by X position
	milestones_data.sort_custom(func(a, b): return a.x < b.x)
	
	# Get current progress
	var progress = Registry.tech.get_branch_progress(branch_id)
	var progress_x = start_x + progress * LEVEL_SCALE
	
	# Compute end X: max of furthest VISIBLE milestone and current progress, plus padding
	var furthest_x = start_x  # Baseline
	for m in milestones_data:
		if m.visible and m.x > furthest_x:
			furthest_x = m.x
	
	var end_x = max(furthest_x, progress_x) + 50.0
	
	branch_layouts[branch_id] = {
		"start_x": start_x,
		"end_x": end_x,
		"y": y,
		"color": color,
		"progress_x": progress_x,
		"milestones": milestones_data,
		"fork_from_x": fork_from_x,
		"fork_from_y": fork_from_y,
		"has_parent": not starts_from.is_empty()
	}

func get_branch_at_point(world_pos: Vector2) -> String:
	"""Check if a point is on a branch line"""
	for branch_id in branch_layouts.keys():
		var layout = branch_layouts[branch_id]
		var y = layout.y
		var start_x = layout.start_x
		var end_x = layout.end_x
		
		# Check if point is within branch bounds (with some tolerance)
		if abs(world_pos.y - y) <= BRANCH_WIDTH and world_pos.x >= start_x - 10 and world_pos.x <= end_x + 10:
			return branch_id
	
	return ""

func get_milestone_at_point(world_pos: Vector2) -> String:
	"""Check if a point is on a milestone"""
	for branch_id in branch_layouts.keys():
		var layout = branch_layouts[branch_id]
		var y = layout.y
		
		for milestone in layout.milestones:
			if not milestone.visible:
				continue
			
			var milestone_pos = Vector2(milestone.x, y)
			if world_pos.distance_to(milestone_pos) <= MILESTONE_RADIUS + 5:
				return milestone.id
	
	return ""

func show_branch_info(branch_id: String, screen_pos: Vector2):
	var branch_name = Registry.tech.get_branch_name(branch_id)
	var progress = Registry.tech.get_branch_progress(branch_id)
	
	var icon_rect = info_popup.get_node("OuterVBox/HBox/Icon") as TextureRect
	var title = info_popup.get_node("OuterVBox/HBox/VBox/Title") as Label
	var detail = info_popup.get_node("OuterVBox/HBox/VBox/Detail") as Label
	var focus_btn = info_popup.get_node("OuterVBox/FocusButton") as Button
	
	# Set icon if available
	if branch_icons.has(branch_id):
		icon_rect.texture = branch_icons[branch_id]
		icon_rect.visible = true
	else:
		icon_rect.texture = null
		icon_rect.visible = false
	
	title.text = branch_name
	detail.text = "Progress: %.1f" % progress
	
	# Hide unlocks section for branches
	_hide_unlocks_section()
	
	# Show focus research button
	_popup_branch_id = branch_id
	var current_focus = Registry.tech.get_preferred_research_branch()
	if current_focus == branch_id:
		focus_btn.text = "\u2b24 Research Focused Here"
		focus_btn.disabled = true
	else:
		focus_btn.text = "\u2b24 Focus Research Here"
		focus_btn.disabled = false
	focus_btn.visible = true
	
	_show_popup_at(screen_pos)

func show_milestone_info(milestone_id: String, screen_pos: Vector2):
	var milestone_name = Registry.tech.get_milestone_name(milestone_id)
	var milestone_branch = Registry.tech.get_milestone_branch(milestone_id)
	var is_unlocked = Registry.tech.is_milestone_unlocked(milestone_id)
	
	var icon_rect = info_popup.get_node("OuterVBox/HBox/Icon") as TextureRect
	var title = info_popup.get_node("OuterVBox/HBox/VBox/Title") as Label
	var detail = info_popup.get_node("OuterVBox/HBox/VBox/Detail") as Label
	
	# Set branch icon if available
	if milestone_branch != "" and branch_icons.has(milestone_branch):
		icon_rect.texture = branch_icons[milestone_branch]
		icon_rect.visible = true
	else:
		icon_rect.texture = null
		icon_rect.visible = false
	
	title.text = milestone_name
	
	var branch_name = Registry.tech.get_branch_name(milestone_branch) if milestone_branch != "" else "Unknown"
	var status = "Unlocked" if is_unlocked else "Locked"
	detail.text = "%s\nBranch: %s" % [status, branch_name]
	
	# Populate unlocks section
	var unlocks = _get_milestone_unlock_items(milestone_id)
	_populate_unlocks_section(unlocks)
	
	# Hide focus button for milestones
	var focus_btn = info_popup.get_node("OuterVBox/FocusButton") as Button
	focus_btn.visible = false
	_popup_branch_id = ""
	
	_show_popup_at(screen_pos)

func _on_focus_research_pressed():
	"""Handle the Focus Research button press"""
	if _popup_branch_id == "":
		return
	
	var current_focus = Registry.tech.get_preferred_research_branch()
	if current_focus == _popup_branch_id:
		# Already focused — unfocus (back to random)
		Registry.tech.set_preferred_research_branch("")
	else:
		Registry.tech.set_preferred_research_branch(_popup_branch_id)
	
	# Update button state
	var focus_btn = info_popup.get_node("OuterVBox/FocusButton") as Button
	var new_focus = Registry.tech.get_preferred_research_branch()
	if new_focus == _popup_branch_id:
		focus_btn.text = "\u2b24 Research Focused Here"
		focus_btn.disabled = true
	else:
		focus_btn.text = "\u2b24 Focus Research Here"
		focus_btn.disabled = false
	
	# Redraw to update visual indicator
	tree_drawer.queue_redraw()

func _get_milestone_unlock_items(milestone_id: String) -> Array[Dictionary]:
	"""Get buildings and resources unlocked by this milestone, with icon paths and names."""
	var items: Array[Dictionary] = []
	
	# Check buildings
	for building_id in Registry.buildings.get_all_building_ids():
		var milestones_req = Registry.buildings.get_required_milestones(building_id)
		if milestone_id in milestones_req:
			var building = Registry.buildings.get_building(building_id)
			var icon_path = building.get("visual", {}).get("sprite", "")
			items.append({
				"id": building_id,
				"name": Registry.get_name_label("building", building_id),
				"icon_path": icon_path,
				"type": "building"
			})
	
	# Check resources
	for resource_id in Registry.resources.get_all_resource_ids():
		var milestones_req = Registry.resources.get_required_milestones(resource_id)
		if milestone_id in milestones_req:
			var resource = Registry.resources.get_resource(resource_id)
			var icon_path = resource.get("visual", {}).get("icon", "")
			items.append({
				"id": resource_id,
				"name": Registry.get_name_label("resource", resource_id),
				"icon_path": icon_path,
				"type": "resource"
			})
	
	return items

func _populate_unlocks_section(unlocks: Array[Dictionary]):
	"""Show or hide the unlocks section and populate it with icons."""
	var separator = info_popup.get_node("OuterVBox/UnlocksSeparator")
	var label = info_popup.get_node("OuterVBox/UnlocksLabel")
	var container = info_popup.get_node("OuterVBox/UnlocksContainer") as HBoxContainer
	
	# Clear previous icons
	for child in container.get_children():
		child.queue_free()
	
	if unlocks.is_empty():
		_hide_unlocks_section()
		return
	
	separator.visible = true
	label.visible = true
	container.visible = true
	
	for item in unlocks:
		var item_vbox = VBoxContainer.new()
		item_vbox.add_theme_constant_override("separation", 2)
		item_vbox.set_h_size_flags(Control.SIZE_SHRINK_CENTER)
		
		# Icon
		var tex_rect = TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(32, 32)
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		if item.icon_path != "" and ResourceLoader.exists(item.icon_path):
			tex_rect.texture = load(item.icon_path)
		
		item_vbox.add_child(tex_rect)
		
		# Name label
		var name_label = Label.new()
		name_label.text = item.name
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		# Color-code by type
		if item.type == "building":
			name_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		else:
			name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
		
		item_vbox.add_child(name_label)
		container.add_child(item_vbox)

func _hide_unlocks_section():
	"""Hide the unlocks section of the info popup."""
	var separator = info_popup.get_node("OuterVBox/UnlocksSeparator")
	var label = info_popup.get_node("OuterVBox/UnlocksLabel")
	var container = info_popup.get_node("OuterVBox/UnlocksContainer")
	separator.visible = false
	label.visible = false
	container.visible = false

func _show_popup_at(screen_pos: Vector2):
	info_popup.visible = true
	
	# Position popup near click, but keep on screen
	var viewport_size = get_viewport().get_visible_rect().size
	var popup_size = info_popup.size
	
	var x = min(screen_pos.x + 10, viewport_size.x - popup_size.x - 10)
	var y = min(screen_pos.y + 10, viewport_size.y - popup_size.y - 10)
	
	info_popup.position = Vector2(x, y)

func hide_info_popup():
	info_popup.visible = false


# === Inner class for drawing ===

class TechTreeDrawer extends Node2D:
	var tech_screen: TechTreeScreen
	
	func _draw():
		if not tech_screen:
			return
		
		# First pass: Draw all branch lines (shadows first, then lines)
		for branch_id in tech_screen.branch_layouts.keys():
			_draw_branch_shadow(branch_id)
		
		for branch_id in tech_screen.branch_layouts.keys():
			_draw_branch_lines(branch_id)
		
		# Second pass: Draw all milestones on top
		for branch_id in tech_screen.branch_layouts.keys():
			_draw_branch_milestones(branch_id)
		
		# Third pass: Draw branch icons
		for branch_id in tech_screen.branch_layouts.keys():
			_draw_branch_icon(branch_id)
		
		# Fourth pass: Draw focus indicator on preferred branch
		_draw_focus_indicator()
	
	func _draw_branch_shadow(branch_id: String):
		var layout = tech_screen.branch_layouts[branch_id]
		var y = layout.y
		var start_x = layout.start_x
		var end_x = layout.end_x
		var has_parent = layout.has_parent
		var fork_from_x = layout.fork_from_x
		var fork_from_y = layout.fork_from_y
		
		var width = tech_screen.BRANCH_WIDTH
		var shadow_color = Color(0, 0, 0, 0.4)
		var shadow_offset = Vector2(3, 3)
		
		# Draw fork diagonal shadow if this is a child branch
		if has_parent:
			var fork_start = Vector2(fork_from_x, fork_from_y)
			var elbow_point = Vector2(start_x + tech_screen.FORK_DIAGONAL_LENGTH, y)
			
			# Shadow for diagonal
			draw_line(fork_start + shadow_offset, elbow_point + shadow_offset, shadow_color, width + 2)
			# Shadow for elbow joint (circle to smooth the corner)
			draw_circle(elbow_point + shadow_offset, (width + 2) / 2.0, shadow_color)
			
			start_x = elbow_point.x
		
		# Draw main horizontal shadow
		draw_line(Vector2(start_x, y) + shadow_offset, Vector2(end_x, y) + shadow_offset, shadow_color, width + 2)
	
	func _draw_branch_lines(branch_id: String):
		var layout = tech_screen.branch_layouts[branch_id]
		var color = layout.color
		var y = layout.y
		var start_x = layout.start_x
		var end_x = layout.end_x
		var progress_x = layout.progress_x
		var has_parent = layout.has_parent
		var fork_from_x = layout.fork_from_x
		var fork_from_y = layout.fork_from_y
		
		var width = tech_screen.BRANCH_WIDTH
		
		# Colors
		var unlocked_color = color
		var locked_color = color.darkened(0.6)
		locked_color.a = 0.5
		
		var elbow_x = start_x
		
		# Draw fork diagonal if this is a child branch
		if has_parent:
			var fork_start = Vector2(fork_from_x, fork_from_y)
			var elbow_point = Vector2(start_x + tech_screen.FORK_DIAGONAL_LENGTH, y)
			elbow_x = elbow_point.x
			
			# Diagonal line (locked color)
			draw_line(fork_start, elbow_point, locked_color, width)
			# Elbow joint circle (to smooth the corner)
			draw_circle(elbow_point, width / 2.0, locked_color)
		
		# Draw locked portion (full length)
		draw_line(Vector2(elbow_x, y), Vector2(end_x, y), locked_color, width)
		
		# Draw unlocked portion (up to progress)
		if progress_x > start_x:
			# If branch has parent, we need to draw from fork point
			if has_parent:
				var fork_start = Vector2(fork_from_x, fork_from_y)
				var elbow_point = Vector2(start_x + tech_screen.FORK_DIAGONAL_LENGTH, y)
				
				# Check if progress covers the diagonal
				if progress_x > elbow_point.x:
					# Draw full diagonal as unlocked
					draw_line(fork_start, elbow_point, unlocked_color, width)
					draw_circle(elbow_point, width / 2.0, unlocked_color)
					# Draw horizontal portion
					var unlocked_end_x = min(progress_x, end_x)
					draw_line(Vector2(elbow_point.x, y), Vector2(unlocked_end_x, y), unlocked_color, width)
			else:
				var unlocked_end_x = min(progress_x, end_x)
				draw_line(Vector2(start_x, y), Vector2(unlocked_end_x, y), unlocked_color, width)
	
	func _draw_branch_milestones(branch_id: String):
		var layout = tech_screen.branch_layouts[branch_id]
		var color = layout.color
		var y = layout.y
		var progress_x = layout.progress_x
		var start_x = layout.start_x
		
		# Colors
		var unlocked_color = color
		var locked_color = color.darkened(0.6)
		locked_color.a = 0.5
		var shadow_color = Color(0, 0, 0, 0.4)
		
		# Draw milestones
		for milestone in layout.milestones:
			if not milestone.visible:
				continue
			
			var mx = milestone.x
			var is_unlocked = milestone.unlocked
			
			var milestone_color = unlocked_color if is_unlocked else locked_color
			var milestone_pos = Vector2(mx, y)
			
			# Shadow
			draw_circle(milestone_pos + Vector2(2, 2), tech_screen.MILESTONE_RADIUS, shadow_color)
			
			# Outer circle
			draw_circle(milestone_pos, tech_screen.MILESTONE_RADIUS, milestone_color)
			
			# Inner circle (slightly darker)
			draw_circle(milestone_pos, tech_screen.MILESTONE_RADIUS * 0.6, milestone_color.darkened(0.2))
	
	func _draw_branch_icon(branch_id: String):
		"""Draw the branch icon at the start of the branch"""
		if not tech_screen.branch_icons.has(branch_id):
			return
		
		var layout = tech_screen.branch_layouts[branch_id]
		var y = layout.y
		var start_x = layout.start_x
		var has_parent = layout.has_parent
		var color = layout.color
		
		# Calculate icon position
		var icon_x: float
		if has_parent:
			# For child branches, place icon at the elbow point (where horizontal starts)
			var elbow_x = start_x + tech_screen.FORK_DIAGONAL_LENGTH
			icon_x = elbow_x - tech_screen.ICON_OFFSET
		else:
			# For root branches, place icon before branch start
			icon_x = start_x - tech_screen.ICON_OFFSET
		
		var icon_pos = Vector2(icon_x, y)
		var icon_size = tech_screen.ICON_SIZE
		var half_size = icon_size / 2.0
		
		var texture = tech_screen.branch_icons[branch_id]
		
		# Draw circular background with branch color
		var shadow_color = Color(0, 0, 0, 0.4)
		draw_circle(icon_pos + Vector2(2, 2), half_size + 4, shadow_color)
		draw_circle(icon_pos, half_size + 4, color.darkened(0.3))
		draw_circle(icon_pos, half_size + 2, color)
		
		# Draw the icon texture
		var tex_size = texture.get_size()
		var scale_factor = icon_size / max(tex_size.x, tex_size.y)
		var draw_size = tex_size * scale_factor
		var draw_rect = Rect2(icon_pos - draw_size / 2.0, draw_size)
		draw_texture_rect(texture, draw_rect, false)
	
	func _draw_focus_indicator():
		"""Draw a visual indicator at the beginning of the focused branch"""
		var focused_branch = Registry.tech.get_preferred_research_branch()
		if focused_branch == "" or not tech_screen.branch_layouts.has(focused_branch):
			return
		
		var layout = tech_screen.branch_layouts[focused_branch]
		var y = layout.y
		var start_x = layout.start_x
		var has_parent = layout.has_parent
		var color = layout.color
		
		# Position beacon at branch start (after elbow for child branches)
		var beacon_x = start_x
		if has_parent:
			beacon_x = start_x + tech_screen.FORK_DIAGONAL_LENGTH
		
		# Offset to the left of the branch line start
		var beacon_pos = Vector2(beacon_x - 40, y)
		
		# Outer glow
		var glow_color = Color(0.9, 0.85, 0.4, 0.3)
		draw_circle(beacon_pos, 18, glow_color)
		
		# Inner circle with branch color
		draw_circle(beacon_pos, 12, color)
		draw_circle(beacon_pos, 9, color.lightened(0.3))
		
		# Simple star/compass shape to indicate focus
		var icon_color = Color(1, 1, 1, 0.9)
		var r = 5.0
		for i in range(4):
			var angle = i * PI / 2.0
			var from_pt = beacon_pos + Vector2(cos(angle), sin(angle)) * r
			var to_pt = beacon_pos - Vector2(cos(angle), sin(angle)) * r
			draw_line(from_pt, to_pt, icon_color, 1.5)
