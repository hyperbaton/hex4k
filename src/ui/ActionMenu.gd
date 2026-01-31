extends Control
class_name ActionMenu

# Bottom circular action buttons with expanding menus

signal build_requested(building_id: String)
signal expand_requested
signal train_requested(unit_id: String)
signal routes_requested
signal closed

const BUTTON_RADIUS = 40.0
const BUTTON_SPACING = 100.0
const CATEGORY_OFFSET = 120.0
const BUILDING_OFFSET = 180.0

@onready var buttons_container := $ButtonsContainer
@onready var categories_container := $CategoriesContainer
@onready var buildings_container := $BuildingsContainer

var build_button: CircularButton
var expand_button: CircularButton
var train_button: CircularButton
var action_buttons: Array[CircularButton] = []  # All main action buttons
var category_buttons: Array[CircularButton] = []
var building_buttons: Array[CircularButton] = []
var unit_buttons: Array[CircularButton] = []  # Unit selection buttons

var current_city: City  # Reference to current city for checking build limits

var menu_state := MenuState.CLOSED

# Building info panel
var info_panel: PanelContainer
var selected_building_id: String = ""
var selected_unit_id: String = ""
var is_showing_unit_info: bool = false  # Track if showing unit or building info

enum MenuState {
	CLOSED,
	ACTIONS_OPEN,
	CATEGORIES_OPEN,
	BUILDINGS_OPEN,
	INFO_PANEL_OPEN,
	UNITS_OPEN,
	UNIT_INFO_OPEN
}

func _ready():
	setup_action_buttons()
	_create_info_panel()
	
	# Connect to viewport size changes
	get_viewport().size_changed.connect(_on_viewport_resized)
	
	# Enable input processing
	set_process_input(true)

func set_city(city: City):
	"""Set the current city reference for checking build limits"""
	current_city = city

func _input(event: InputEvent):
	"""Handle input for buttons - check clicks on circular buttons"""
	if not visible:
		return
	
	# Handle mouse motion for hover effects
	if event is InputEventMouseMotion:
		var mouse_pos = event.global_position
		
		# Update hover state for all action buttons
		for button in action_buttons:
			if is_instance_valid(button):
				var was_hovered = button.is_hovered
				button.is_hovered = button.is_point_inside(mouse_pos)
				if was_hovered != button.is_hovered:
					button.queue_redraw()
		
		for button in category_buttons:
			if is_instance_valid(button):
				var was_hovered = button.is_hovered
				button.is_hovered = button.is_point_inside(mouse_pos)
				if was_hovered != button.is_hovered:
					button.queue_redraw()
		
		for button in building_buttons:
			if is_instance_valid(button):
				var was_hovered = button.is_hovered
				button.is_hovered = button.is_point_inside(mouse_pos)
				if was_hovered != button.is_hovered:
					button.queue_redraw()
		
		for button in unit_buttons:
			if is_instance_valid(button):
				var was_hovered = button.is_hovered
				button.is_hovered = button.is_point_inside(mouse_pos)
				if was_hovered != button.is_hovered:
					button.queue_redraw()
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = event.global_position
		
		if event.pressed:
			# Check if click is on any action button
			for button in action_buttons:
				if is_instance_valid(button) and button.is_point_inside(mouse_pos):
					button._gui_input(event)
					get_viewport().set_input_as_handled()
					return
			
			for button in category_buttons:
				if is_instance_valid(button) and button.is_point_inside(mouse_pos):
					button._gui_input(event)
					get_viewport().set_input_as_handled()
					return
			
			for button in building_buttons:
				if is_instance_valid(button) and button.is_point_inside(mouse_pos):
					button._gui_input(event)
					get_viewport().set_input_as_handled()
					return
			
			for button in unit_buttons:
				if is_instance_valid(button) and button.is_point_inside(mouse_pos):
					button._gui_input(event)
					get_viewport().set_input_as_handled()
					return
		else:
			# Mouse release - forward to buttons that might be pressed
			for button in action_buttons:
				if is_instance_valid(button) and button.is_pressed:
					button._gui_input(event)
					get_viewport().set_input_as_handled()
					return
			
			for button in category_buttons:
				if is_instance_valid(button) and button.is_pressed:
					button._gui_input(event)
					get_viewport().set_input_as_handled()
					return
			
			for button in building_buttons:
				if is_instance_valid(button) and button.is_pressed:
					button._gui_input(event)
					get_viewport().set_input_as_handled()
					return
			
			for button in unit_buttons:
				if is_instance_valid(button) and button.is_pressed:
					button._gui_input(event)
					get_viewport().set_input_as_handled()
					return

func _on_viewport_resized():
	"""Reposition buttons when viewport size changes"""
	position_action_buttons()
	reposition_category_buttons()
	reposition_building_buttons()
	_reposition_info_panel()

func setup_action_buttons():
	# Create main action buttons
	build_button = create_circular_button("Build", Color(0.2, 0.4, 0.8))  # Blue
	build_button.pressed.connect(_on_build_pressed)
	buttons_container.add_child(build_button)
	action_buttons.append(build_button)
	
	train_button = create_circular_button("Train", Color(0.8, 0.4, 0.2))  # Orange
	train_button.pressed.connect(_on_train_pressed)
	buttons_container.add_child(train_button)
	action_buttons.append(train_button)
	
	expand_button = create_circular_button("Expand", Color(0.2, 0.7, 0.3))  # Green
	expand_button.pressed.connect(_on_expand_pressed)
	buttons_container.add_child(expand_button)
	action_buttons.append(expand_button)
	
	# Position at bottom center
	position_action_buttons()

func position_action_buttons():
	if action_buttons.is_empty():
		return
	var viewport_size = get_viewport_rect().size
	var center_x = viewport_size.x / 2
	var bottom_y = viewport_size.y - 80
	
	# Calculate total width for all action buttons
	var button_spacing = 20
	var total_width = action_buttons.size() * (BUTTON_RADIUS * 2) + (action_buttons.size() - 1) * button_spacing
	var start_x = center_x - total_width / 2
	
	# Position each action button
	for i in range(action_buttons.size()):
		var button = action_buttons[i]
		if is_instance_valid(button):
			var x = start_x + i * (BUTTON_RADIUS * 2 + button_spacing)
			button.position = Vector2(x, bottom_y - BUTTON_RADIUS)

func reposition_category_buttons():
	"""Reposition category buttons in horizontal line above action buttons"""
	if category_buttons.is_empty():
		return
	
	var viewport_size = get_viewport_rect().size
	var center_x = viewport_size.x / 2
	var bottom_y = viewport_size.y - 80
	var row_y = bottom_y - BUTTON_RADIUS * 3
	
	var total_width = category_buttons.size() * (BUTTON_RADIUS * 2) + (category_buttons.size() - 1) * 20
	var start_x = center_x - total_width / 2
	
	for i in range(category_buttons.size()):
		if not is_instance_valid(category_buttons[i]):
			continue
		var x = start_x + i * (BUTTON_RADIUS * 2 + 20)
		category_buttons[i].position = Vector2(x, row_y - BUTTON_RADIUS)

func reposition_building_buttons():
	"""Reposition building buttons in horizontal line above category buttons"""
	if building_buttons.is_empty():
		return
	
	var viewport_size = get_viewport_rect().size
	var center_x = viewport_size.x / 2
	var bottom_y = viewport_size.y - 80
	var row_y = bottom_y - BUTTON_RADIUS * 6
	
	var total_width = building_buttons.size() * (BUTTON_RADIUS * 2) + (building_buttons.size() - 1) * 20
	var start_x = center_x - total_width / 2
	
	for i in range(building_buttons.size()):
		if not is_instance_valid(building_buttons[i]):
			continue
		var x = start_x + i * (BUTTON_RADIUS * 2 + 20)
		building_buttons[i].position = Vector2(x, row_y - BUTTON_RADIUS)

func create_circular_button(text: String, color: Color) -> CircularButton:
	var button = CircularButton.new()
	button.button_text = text
	button.button_color = color
	button.radius = BUTTON_RADIUS
	return button

func _on_build_pressed():
	if menu_state == MenuState.CLOSED:
		# First click - show categories
		menu_state = MenuState.ACTIONS_OPEN
		show_building_categories()
	elif menu_state == MenuState.CATEGORIES_OPEN or menu_state == MenuState.BUILDINGS_OPEN or menu_state == MenuState.INFO_PANEL_OPEN:
		# Already showing build menus - close
		close_all_menus()
	elif menu_state == MenuState.UNITS_OPEN or menu_state == MenuState.UNIT_INFO_OPEN:
		# Switching from train to build
		show_building_categories()
	else:
		# ACTIONS_OPEN state - show categories
		show_building_categories()

func _on_expand_pressed():
	"""Handle expand button press"""
	close_all_menus()
	emit_signal("expand_requested")

func _on_train_pressed():
	"""Handle train button press"""
	if menu_state == MenuState.CLOSED:
		menu_state = MenuState.ACTIONS_OPEN
		show_trainable_units()
	elif menu_state == MenuState.UNITS_OPEN or menu_state == MenuState.UNIT_INFO_OPEN:
		close_all_menus()
	else:
		# Close building menus and show units
		close_all_menus()
		menu_state = MenuState.ACTIONS_OPEN
		show_trainable_units()

func show_trainable_units():
	"""Show units that can be trained at the current city"""
	menu_state = MenuState.UNITS_OPEN
	is_showing_unit_info = false
	
	# Hide info panel
	_hide_info_panel()
	
	# Clear existing category and building buttons
	for button in category_buttons:
		if is_instance_valid(button):
			button.queue_free()
	category_buttons.clear()
	
	for button in building_buttons:
		if is_instance_valid(button):
			button.queue_free()
	building_buttons.clear()
	
	# Clear existing unit buttons
	for button in unit_buttons:
		if is_instance_valid(button):
			button.queue_free()
	unit_buttons.clear()
	
	# Get available units
	var units = get_available_units()
	
	if units.is_empty():
		print("No units available to train")
		return
	
	# Position buttons in a horizontal line above action buttons
	var viewport_size = get_viewport_rect().size
	var center_x = viewport_size.x / 2
	var bottom_y = viewport_size.y - 80
	var row_y = bottom_y - BUTTON_RADIUS * 3
	
	# Calculate total width needed
	var total_width = units.size() * (BUTTON_RADIUS * 2) + (units.size() - 1) * 20
	var start_x = center_x - total_width / 2
	
	for i in range(units.size()):
		var unit_id = units[i]
		var unit_name = Registry.units.get_unit_name(unit_id)
		
		var button = create_circular_button(unit_name, Color(0.8, 0.5, 0.2))  # Orange for units
		button.pressed.connect(_on_unit_pressed.bind(unit_id))
		
		# Position in horizontal line
		var x = start_x + i * (BUTTON_RADIUS * 2 + 20)
		button.position = Vector2(x, row_y - BUTTON_RADIUS)
		
		buttons_container.add_child(button)
		unit_buttons.append(button)
		
		animate_button_appear(button)

func get_available_units() -> Array[String]:
	"""Get units that can be trained at the current city"""
	var units: Array[String] = []
	
	if not current_city:
		return units
	
	# Get OPERATIONAL buildings in this city that can train units
	var city_buildings: Array[String] = []
	for coord in current_city.building_instances.keys():
		var instance = current_city.building_instances[coord] as BuildingInstance
		if instance and instance.is_operational():
			city_buildings.append(instance.building_id)
	
	# Check each unit
	for unit_id in Registry.units.get_all_unit_ids():
		# Check if unit is unlocked
		if not Registry.units.is_unit_unlocked(unit_id):
			continue
		
		# Check if any of the city's OPERATIONAL buildings can train this unit
		var trained_at = Registry.units.get_trained_at(unit_id)
		var can_train = false
		for building_id in trained_at:
			if building_id in city_buildings:
				can_train = true
				break
		
		if can_train:
			units.append(unit_id)
	
	return units

func _on_unit_pressed(unit_id: String):
	"""Handle unit button press - show unit info"""
	print("Unit button pressed: ", unit_id)
	selected_unit_id = unit_id
	menu_state = MenuState.UNIT_INFO_OPEN
	is_showing_unit_info = true
	_show_unit_info(unit_id)

func _show_unit_info(unit_id: String):
	"""Populate and show the info panel with unit details"""
	if not info_panel:
		return
	
	var unit = Registry.units.get_unit(unit_id)
	if unit.is_empty():
		return
	
	var vbox = info_panel.get_node("VBox")
	
	# Set unit name
	var name_label = vbox.get_node("NameLabel") as Label
	name_label.text = Registry.units.get_unit_name(unit_id)
	
	# Training costs text
	var costs_label = vbox.get_node("CostsLabel") as Label
	var costs_text = ""
	
	var training_cost = Registry.units.get_training_cost(unit_id)
	if not training_cost.is_empty():
		var cost_parts = []
		for resource in training_cost:
			cost_parts.append("%s: %d" % [resource.capitalize(), training_cost[resource]])
		costs_text += "Training Cost: " + ", ".join(cost_parts) + "\n"
	
	var turns = Registry.units.get_training_turns(unit_id)
	costs_text += "Training Time: %d turns" % turns
	
	costs_label.text = costs_text
	
	# Stats text
	var production_label = vbox.get_node("ProductionLabel") as Label
	var stats_text = ""
	
	var health = Registry.units.get_stat(unit_id, "health", 0)
	var movement = Registry.units.get_stat(unit_id, "movement", 0)
	var vision = Registry.units.get_stat(unit_id, "vision", 0)
	
	stats_text += "Health: %d" % health
	stats_text += "  |  Movement: %d" % movement
	stats_text += "  |  Vision: %d" % vision
	
	production_label.text = stats_text
	
	# Special info
	var special_label = vbox.get_node("SpecialLabel") as Label
	var special_parts = []
	
	# Combat stats
	var combat = unit.get("combat", {})
	var attack = combat.get("attack", 0)
	var defense = combat.get("defense", 0)
	if attack > 0 or defense > 0:
		special_parts.append("Combat: Atk %d / Def %d" % [attack, defense])
	
	# Maintenance
	var maintenance = Registry.units.get_maintenance(unit_id)
	if not maintenance.is_empty():
		var maint_parts = []
		for resource in maintenance:
			maint_parts.append("%s %s/turn" % [str(maintenance[resource]), resource.capitalize()])
		special_parts.append("Maintenance: " + ", ".join(maint_parts))
	
	# Abilities
	var abilities = unit.get("abilities", [])
	if not abilities.is_empty():
		special_parts.append("Abilities: " + ", ".join(abilities))
	
	# Category
	var category = Registry.units.get_unit_category(unit_id)
	special_parts.append("Type: " + category.capitalize())
	
	if special_parts.is_empty():
		special_label.visible = false
	else:
		special_label.visible = true
		special_label.text = "\n".join(special_parts)
	
	# Update the button text
	var btn_container = vbox.get_node_or_null("HBoxContainer")
	if not btn_container:
		# Find the button container
		for child in vbox.get_children():
			if child is HBoxContainer:
				btn_container = child
				break
	
	if btn_container:
		var build_btn = btn_container.get_node_or_null("BuildButton")
		if build_btn:
			build_btn.text = "Train"
	
	# Position and show panel
	_reposition_info_panel()
	info_panel.visible = true
	
	# Animate appearance
	info_panel.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(info_panel, "modulate:a", 1.0, 0.2)

func _on_build_button_in_panel_pressed():
	"""Called when the Build/Train button in the info panel is pressed"""
	print("ActionMenu: _on_build_button_in_panel_pressed called")
	print("  is_showing_unit_info: ", is_showing_unit_info)
	print("  selected_unit_id: ", selected_unit_id)
	print("  selected_building_id: ", selected_building_id)
	
	if is_showing_unit_info and selected_unit_id != "":
		print("  Emitting train_requested signal for: ", selected_unit_id)
		emit_signal("train_requested", selected_unit_id)
		_hide_info_panel()
	elif selected_building_id != "":
		print("  Emitting build_requested signal for: ", selected_building_id)
		emit_signal("build_requested", selected_building_id)
		_hide_info_panel()
	else:
		print("  WARNING: No unit or building selected!")

func show_building_categories():
	menu_state = MenuState.CATEGORIES_OPEN
	
	# Hide info panel
	_hide_info_panel()
	
	# Clear existing category buttons
	for button in category_buttons:
		if is_instance_valid(button):
			button.queue_free()
	category_buttons.clear()
	
	# Clear building buttons
	for button in building_buttons:
		if is_instance_valid(button):
			button.queue_free()
	building_buttons.clear()
	
	# Clear unit buttons (important for switching from Train to Build)
	for button in unit_buttons:
		if is_instance_valid(button):
			button.queue_free()
	unit_buttons.clear()
	
	# Get all building categories
	var categories = get_building_categories()
	
	# Position buttons in a horizontal line above action buttons
	var viewport_size = get_viewport_rect().size
	var center_x = viewport_size.x / 2
	var bottom_y = viewport_size.y - 80
	var row_y = bottom_y - BUTTON_RADIUS * 3  # One row above, with spacing
	
	# Calculate total width needed
	var total_width = categories.size() * (BUTTON_RADIUS * 2) + (categories.size() - 1) * 20  # 20px spacing
	var start_x = center_x - total_width / 2
	
	for i in range(categories.size()):
		var category = categories[i]
		
		var button = create_circular_button(category.capitalize(), Color.GREEN)
		button.pressed.connect(_on_category_pressed.bind(category))
		
		# Position in horizontal line
		var x = start_x + i * (BUTTON_RADIUS * 2 + 20)
		button.position = Vector2(x, row_y - BUTTON_RADIUS)
		
		categories_container.add_child(button)
		category_buttons.append(button)
		
		# Animate appearance
		animate_button_appear(button)

func _on_category_pressed(category: String):
	show_buildings_in_category(category)

func show_buildings_in_category(category: String):
	menu_state = MenuState.BUILDINGS_OPEN
	
	# Hide info panel when switching categories
	_hide_info_panel()
	
	# Clear existing
	for button in building_buttons:
		button.queue_free()
	building_buttons.clear()
	
	# Get buildings in category (filtered by tech)
	var buildings = get_available_buildings_in_category(category)
	
	if buildings.is_empty():
		print("No buildings available in category: ", category)
		return
	
	# Position buttons in a horizontal line above the category buttons
	var viewport_size = get_viewport_rect().size
	var center_x = viewport_size.x / 2
	var bottom_y = viewport_size.y - 80
	var row_y = bottom_y - BUTTON_RADIUS * 6  # Two rows above action buttons
	
	# Calculate total width needed
	var total_width = buildings.size() * (BUTTON_RADIUS * 2) + (buildings.size() - 1) * 20
	var start_x = center_x - total_width / 2
	
	for i in range(buildings.size()):
		var building_id = buildings[i]
		var building_name = Registry.get_name_label("building", building_id)
		
		var button = create_circular_button(building_name, Color.YELLOW)
		button.pressed.connect(_on_building_pressed.bind(building_id))
		
		# Position in horizontal line
		var x = start_x + i * (BUTTON_RADIUS * 2 + 20)
		button.position = Vector2(x, row_y - BUTTON_RADIUS)
		
		buildings_container.add_child(button)
		building_buttons.append(button)
		
		animate_button_appear(button)

func _on_building_pressed(building_id: String):
	print("Building button pressed: ", building_id)
	selected_building_id = building_id
	selected_unit_id = ""
	is_showing_unit_info = false
	menu_state = MenuState.INFO_PANEL_OPEN
	_show_building_info(building_id)

func get_building_categories() -> Array[String]:
	"""Get categories that have at least one available building"""
	var categories: Array[String] = []
	var seen = {}
	
	for building_id in Registry.buildings.get_all_building_ids():
		var building = Registry.buildings.get_building(building_id)
		var category = building.get("category", "")
		
		# Skip empty categories or already seen
		if category == "" or seen.has(category):
			continue
		
		# Check if this building's tech is unlocked
		var milestones = Registry.buildings.get_required_milestones(building_id)
		if not Registry.has_all_milestones(milestones):
			continue
		
		# Check max per city limit
		var max_per_city = Registry.buildings.get_max_per_city(building_id)
		if max_per_city > 0 and current_city:
			var current_count = current_city.count_buildings(building_id)
			if current_count >= max_per_city:
				continue  # This building has reached its limit
		
		# This category has at least one available building
		categories.append(category)
		seen[category] = true
	
	return categories

func get_available_buildings_in_category(category: String) -> Array[String]:
	var buildings: Array[String] = []
	
	for building_id in Registry.buildings.get_all_building_ids():
		var building = Registry.buildings.get_building(building_id)
		
		if building.get("category", "") != category:
			continue
		
		# Check if tech is unlocked
		var milestones = Registry.buildings.get_required_milestones(building_id)
		if not Registry.has_all_milestones(milestones):
			continue
		
		# Check max per city limit
		var max_per_city = Registry.buildings.get_max_per_city(building_id)
		if max_per_city > 0 and current_city:
			var current_count = current_city.count_buildings(building_id)
			if current_count >= max_per_city:
				continue  # This building has reached its limit
		
		buildings.append(building_id)
	
	return buildings

func close_all_menus():
	menu_state = MenuState.CLOSED
	selected_building_id = ""
	selected_unit_id = ""
	is_showing_unit_info = false
	
	# Hide info panel
	_hide_info_panel()
	
	# Clear category buttons
	for button in category_buttons:
		if is_instance_valid(button):
			animate_button_disappear(button)
	category_buttons.clear()
	
	# Clear building buttons
	for button in building_buttons:
		if is_instance_valid(button):
			animate_button_disappear(button)
	building_buttons.clear()
	
	# Clear unit buttons
	for button in unit_buttons:
		if is_instance_valid(button):
			animate_button_disappear(button)
	unit_buttons.clear()
	
	emit_signal("closed")

func animate_button_appear(button: Control):
	button.modulate.a = 0
	button.scale = Vector2.ZERO
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(button, "modulate:a", 1.0, 0.2)
	tween.tween_property(button, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func animate_button_disappear(button: Control):
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(button, "modulate:a", 0.0, 0.15)
	tween.tween_property(button, "scale", Vector2.ZERO, 0.2)
	tween.tween_callback(button.queue_free).set_delay(0.2)

func is_mouse_over() -> bool:
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Check action buttons (use circular hit test)
	for button in action_buttons:
		if is_instance_valid(button) and button.is_point_inside(mouse_pos):
			return true
	
	# Check category buttons
	for button in category_buttons:
		if is_instance_valid(button) and button.is_point_inside(mouse_pos):
			return true
	
	# Check building buttons
	for button in building_buttons:
		if is_instance_valid(button) and button.is_point_inside(mouse_pos):
			return true
	
	# Check unit buttons
	for button in unit_buttons:
		if is_instance_valid(button) and button.is_point_inside(mouse_pos):
			return true
	
	# Check info panel
	if info_panel and info_panel.visible:
		var panel_rect = Rect2(info_panel.global_position, info_panel.size)
		if panel_rect.has_point(mouse_pos):
			return true
	
	return false

# ============== Building Info Panel ==============

func _create_info_panel():
	"""Create the building info panel (initially hidden)"""
	info_panel = PanelContainer.new()
	info_panel.name = "BuildingInfoPanel"
	info_panel.visible = false
	info_panel.custom_minimum_size = Vector2(320, 200)
	
	# Add a stylebox for better visibility
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style.border_color = Color(0.4, 0.4, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	info_panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 8)
	info_panel.add_child(vbox)
	
	# Building name
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	vbox.add_child(name_label)
	
	# Separator
	var sep1 = HSeparator.new()
	vbox.add_child(sep1)
	
	# Costs section
	var costs_label = Label.new()
	costs_label.name = "CostsLabel"
	costs_label.add_theme_font_size_override("font_size", 14)
	costs_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(costs_label)
	
	# Production section
	var production_label = Label.new()
	production_label.name = "ProductionLabel"
	production_label.add_theme_font_size_override("font_size", 14)
	production_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	vbox.add_child(production_label)
	
	# Special info section
	var special_label = Label.new()
	special_label.name = "SpecialLabel"
	special_label.add_theme_font_size_override("font_size", 13)
	special_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	vbox.add_child(special_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)
	
	# Build button
	var build_btn = Button.new()
	build_btn.name = "BuildButton"
	build_btn.text = "Build"
	build_btn.custom_minimum_size = Vector2(100, 36)
	build_btn.pressed.connect(_on_build_button_in_panel_pressed)
	
	var btn_container = HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_child(build_btn)
	vbox.add_child(btn_container)
	
	add_child(info_panel)

func _show_building_info(building_id: String):
	"""Populate and show the building info panel"""
	if not info_panel:
		return
	
	var building = Registry.buildings.get_building(building_id)
	if building.is_empty():
		return
	
	var vbox = info_panel.get_node("VBox")
	
	# Set building name
	var name_label = vbox.get_node("NameLabel") as Label
	name_label.text = Registry.get_name_label("building", building_id)
	
	# Build costs text
	var costs_label = vbox.get_node("CostsLabel") as Label
	var costs_text = ""
	
	# Initial cost
	var initial_cost = Registry.buildings.get_initial_construction_cost(building_id)
	if not initial_cost.is_empty():
		var cost_parts = []
		for resource in initial_cost:
			cost_parts.append("%s: %d" % [resource.capitalize(), initial_cost[resource]])
		costs_text += "Initial Cost: " + ", ".join(cost_parts) + "\n"
	
	# Per-turn construction cost
	var per_turn_cost = Registry.buildings.get_construction_cost(building_id)
	if not per_turn_cost.is_empty():
		var cost_parts = []
		for resource in per_turn_cost:
			cost_parts.append("%s: %d" % [resource.capitalize(), per_turn_cost[resource]])
		costs_text += "Per Turn: " + ", ".join(cost_parts) + "\n"
	
	# Construction time
	var turns = Registry.buildings.get_construction_turns(building_id)
	costs_text += "Build Time: %d turns" % turns
	
	# Admin cost
	var admin_base = building.get("admin_cost", {}).get("base", 0.0)
	if admin_base > 0:
		costs_text += "\nAdmin Cost: %.1f" % admin_base
	
	costs_label.text = costs_text
	
	# Production text
	var production_label = vbox.get_node("ProductionLabel") as Label
	var prod_text = ""
	
	var produces = Registry.buildings.get_production_per_turn(building_id)
	if not produces.is_empty():
		var prod_parts = []
		for resource in produces:
			prod_parts.append("+%s %s" % [str(produces[resource]), resource.capitalize()])
		prod_text += "Produces: " + ", ".join(prod_parts) + "\n"
	
	var consumes = Registry.buildings.get_consumption_per_turn(building_id)
	if not consumes.is_empty():
		var cons_parts = []
		for resource in consumes:
			cons_parts.append("-%s %s" % [str(consumes[resource]), resource.capitalize()])
		prod_text += "Consumes: " + ", ".join(cons_parts)
	
	if prod_text == "":
		prod_text = "No production"
	
	production_label.text = prod_text.strip_edges()
	
	# Special info
	var special_label = vbox.get_node("SpecialLabel") as Label
	var special_parts = []
	
	# Max per city
	var max_per_city = Registry.buildings.get_max_per_city(building_id)
	if max_per_city > 0:
		special_parts.append("Max per city: %d" % max_per_city)
	
	# Admin capacity provided
	var admin_cap = Registry.buildings.get_admin_capacity(building_id)
	if admin_cap > 0:
		special_parts.append("Provides Admin: +%.1f" % admin_cap)
	
	# Population capacity
	var pop_cap = Registry.buildings.get_population_capacity(building_id)
	if pop_cap > 0:
		special_parts.append("Housing: +%d" % pop_cap)
	
	# Storage
	var storage = Registry.buildings.get_storage_provided(building_id)
	if not storage.is_empty():
		for resource in storage:
			special_parts.append("Storage %s: +%d" % [resource.capitalize(), storage[resource]])
	
	# Adjacency bonuses
	var adj_bonuses = Registry.buildings.get_adjacency_bonuses(building_id)
	if not adj_bonuses.is_empty():
		special_parts.append("Has adjacency bonuses")
	
	# Terrain requirements
	if building.has("requirements"):
		var reqs = building.requirements
		if reqs.has("terrain_types") and not reqs.terrain_types.is_empty():
			var terrain_names = []
			for t in reqs.terrain_types:
				terrain_names.append(t.capitalize())
			special_parts.append("Terrain: " + ", ".join(terrain_names))
	
	if special_parts.is_empty():
		special_label.visible = false
	else:
		special_label.visible = true
		special_label.text = "\n".join(special_parts)
	
	# Update the button text to "Build"
	var btn_container = vbox.get_node_or_null("HBoxContainer")
	if not btn_container:
		# Find the button container
		for child in vbox.get_children():
			if child is HBoxContainer:
				btn_container = child
				break
	
	if btn_container:
		var build_btn = btn_container.get_node_or_null("BuildButton")
		if build_btn:
			build_btn.text = "Build"
	
	# Position and show panel
	_reposition_info_panel()
	info_panel.visible = true
	
	# Animate appearance
	info_panel.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(info_panel, "modulate:a", 1.0, 0.2)

func _hide_info_panel():
	"""Hide the building info panel"""
	if info_panel and info_panel.visible:
		var tween = create_tween()
		tween.tween_property(info_panel, "modulate:a", 0.0, 0.15)
		tween.tween_callback(func(): info_panel.visible = false)

func _reposition_info_panel():
	"""Position the info panel above the building buttons"""
	if not info_panel:
		return
	
	var viewport_size = get_viewport_rect().size
	var bottom_y = viewport_size.y - 80
	
	# Position panel well above the building buttons row
	# Building buttons are at roughly bottom_y - BUTTON_RADIUS * 6
	# Use a larger offset to ensure no overlap
	var panel_bottom_y = bottom_y - BUTTON_RADIUS * 10
	
	var panel_width = info_panel.custom_minimum_size.x
	var panel_height = info_panel.custom_minimum_size.y
	var panel_x = (viewport_size.x - panel_width) / 2
	var panel_y = panel_bottom_y - panel_height
	
	# Ensure panel stays on screen
	panel_x = clamp(panel_x, 20, viewport_size.x - panel_width - 20)
	panel_y = clamp(panel_y, 20, viewport_size.y - panel_height - 20)
	
	info_panel.position = Vector2(panel_x, panel_y)
