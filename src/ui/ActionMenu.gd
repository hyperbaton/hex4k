extends Control
class_name ActionMenu

# Bottom circular action buttons with expanding menus

signal build_requested(building_id: String)
signal train_requested
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
var category_buttons: Array[CircularButton] = []
var building_buttons: Array[CircularButton] = []

var menu_state := MenuState.CLOSED

enum MenuState {
	CLOSED,
	ACTIONS_OPEN,
	CATEGORIES_OPEN,
	BUILDINGS_OPEN
}

func _ready():
	setup_action_buttons()
	
	# Connect to viewport size changes
	get_viewport().size_changed.connect(_on_viewport_resized)
	
	# Enable input processing
	set_process_input(true)

func _input(event: InputEvent):
	"""Handle input for buttons - check clicks on circular buttons"""
	if not visible:
		return
	
	# Handle mouse motion for hover effects
	if event is InputEventMouseMotion:
		var mouse_pos = event.global_position
		
		# Update hover state for all buttons
		if build_button:
			var was_hovered = build_button.is_hovered
			build_button.is_hovered = build_button.is_point_inside(mouse_pos)
			if was_hovered != build_button.is_hovered:
				build_button.queue_redraw()
		
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
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = event.global_position
		
		if event.pressed:
			# Check if click is on any button
			if build_button and build_button.is_point_inside(mouse_pos):
				print("ActionMenu._input: Click on build button detected!")
				build_button._gui_input(event)
				get_viewport().set_input_as_handled()
				return
			
			for button in category_buttons:
				if is_instance_valid(button) and button.is_point_inside(mouse_pos):
					print("ActionMenu._input: Click on category button detected!")
					button._gui_input(event)
					get_viewport().set_input_as_handled()
					return
			
			for button in building_buttons:
				if is_instance_valid(button) and button.is_point_inside(mouse_pos):
					print("ActionMenu._input: Click on building button detected!")
					button._gui_input(event)
					get_viewport().set_input_as_handled()
					return
		else:
			# Mouse release - forward to buttons that might be pressed
			if build_button and build_button.is_pressed:
				print("ActionMenu._input: Release on build button!")
				build_button._gui_input(event)
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

func _on_viewport_resized():
	"""Reposition buttons when viewport size changes"""
	position_action_buttons()
	reposition_category_buttons()
	reposition_building_buttons()

func setup_action_buttons():
	# Create main action buttons
	build_button = create_circular_button("Build", Color.BLUE)
	build_button.pressed.connect(_on_build_pressed)
	buttons_container.add_child(build_button)
	
	# Position at bottom center
	position_action_buttons()

func position_action_buttons():
	if not build_button:
		return
	var viewport_size = get_viewport_rect().size
	var center_x = viewport_size.x / 2
	var bottom_y = viewport_size.y - 80
	
	# Position the build button at bottom center
	build_button.position = Vector2(center_x - build_button.radius, bottom_y - build_button.radius)

func reposition_category_buttons():
	"""Reposition category buttons in horizontal line above build button"""
	if category_buttons.is_empty():
		return
	
	var build_center = build_button.position + Vector2(build_button.radius, build_button.radius)
	var row_y = build_center.y - BUTTON_RADIUS * 3
	
	var total_width = category_buttons.size() * (BUTTON_RADIUS * 2) + (category_buttons.size() - 1) * 20
	var start_x = build_center.x - total_width / 2
	
	for i in range(category_buttons.size()):
		if not is_instance_valid(category_buttons[i]):
			continue
		var x = start_x + i * (BUTTON_RADIUS * 2 + 20)
		category_buttons[i].position = Vector2(x, row_y - BUTTON_RADIUS)

func reposition_building_buttons():
	"""Reposition building buttons in horizontal line above category buttons"""
	if building_buttons.is_empty():
		return
	
	var build_center = build_button.position + Vector2(build_button.radius, build_button.radius)
	var row_y = build_center.y - BUTTON_RADIUS * 6
	
	var total_width = building_buttons.size() * (BUTTON_RADIUS * 2) + (building_buttons.size() - 1) * 20
	var start_x = build_center.x - total_width / 2
	
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
	print("Build pressed! Current state: ", menu_state)
	if menu_state == MenuState.CLOSED:
		# First click - show categories
		menu_state = MenuState.ACTIONS_OPEN
		show_building_categories()
	elif menu_state == MenuState.CATEGORIES_OPEN or menu_state == MenuState.BUILDINGS_OPEN:
		# Already open - close
		close_all_menus()
	else:
		# ACTIONS_OPEN state - show categories
		show_building_categories()

func show_building_categories():
	menu_state = MenuState.CATEGORIES_OPEN
	
	# Clear existing
	for button in category_buttons:
		button.queue_free()
	category_buttons.clear()
	
	# Get all building categories
	var categories = get_building_categories()
	
	# Position buttons in a horizontal line above the build button
	var build_center = build_button.position + Vector2(build_button.radius, build_button.radius)
	var row_y = build_center.y - BUTTON_RADIUS * 3  # One row above, with spacing
	
	# Calculate total width needed
	var total_width = categories.size() * (BUTTON_RADIUS * 2) + (categories.size() - 1) * 20  # 20px spacing
	var start_x = build_center.x - total_width / 2
	
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
	var build_center = build_button.position + Vector2(build_button.radius, build_button.radius)
	var row_y = build_center.y - BUTTON_RADIUS * 6  # Two rows above build button
	
	# Calculate total width needed
	var total_width = buildings.size() * (BUTTON_RADIUS * 2) + (buildings.size() - 1) * 20
	var start_x = build_center.x - total_width / 2
	
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
	emit_signal("build_requested", building_id)
	# Keep menu open for now so player can see tile highlights

func get_building_categories() -> Array[String]:
	var categories: Array[String] = []
	var seen = {}
	
	for building_id in Registry.buildings.get_all_building_ids():
		var building = Registry.buildings.get_building(building_id)
		var category = building.get("category", "")
		
		if category != "" and not seen.has(category):
			categories.append(category)
			seen[category] = true
	
	return categories

func get_available_buildings_in_category(category: String) -> Array[String]:
	var buildings: Array[String] = []
	
	for building_id in Registry.buildings.get_all_building_ids():
		var building = Registry.buildings.get_building(building_id)
		
		if building.get("category", "") == category:
			# Check if tech is unlocked
			var milestones = Registry.buildings.get_required_milestones(building_id)
			if Registry.has_all_milestones(milestones):
				buildings.append(building_id)
	
	return buildings

func close_all_menus():
	menu_state = MenuState.CLOSED
	
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
	if build_button and build_button.is_point_inside(mouse_pos):
		return true
	
	# Check category buttons
	for button in category_buttons:
		if is_instance_valid(button) and button.is_point_inside(mouse_pos):
			return true
	
	# Check building buttons
	for button in building_buttons:
		if is_instance_valid(button) and button.is_point_inside(mouse_pos):
			return true
	
	return false
