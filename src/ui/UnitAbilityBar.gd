extends PanelContainer
class_name UnitAbilityBar

# UI bar showing available abilities for the selected unit

signal ability_requested(ability_id: String, params: Dictionary)

var current_unit: Unit = null
var ability_buttons: Array[Button] = []
var context: Dictionary = {}  # world_query, city_manager, unit_manager

var container: HBoxContainer
var unit_name_label: Label

func _ready():
	_setup_ui()
	hide()

func _setup_ui():
	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	style.border_color = Color(0.3, 0.3, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)
	
	# Main layout
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)
	
	# Unit name header
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	vbox.add_child(header)
	
	unit_name_label = Label.new()
	unit_name_label.add_theme_font_size_override("font_size", 16)
	unit_name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.7))
	header.add_child(unit_name_label)
	
	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	# Ability buttons container
	container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 10)
	vbox.add_child(container)

func set_context(p_context: Dictionary):
	"""Set the context for ability condition checking"""
	context = p_context

func show_unit_abilities(unit: Unit):
	"""Show abilities for the selected unit"""
	current_unit = unit
	
	if not unit:
		hide()
		return
	
	# Clear old buttons
	_clear_buttons()
	
	# Update unit name
	unit_name_label.text = unit.get_display_name()
	
	# Get available abilities
	var abilities = Registry.abilities.get_available_abilities(unit, context)
	
	if abilities.is_empty():
		hide()
		return
	
	# Create buttons for each ability
	for ability_data in abilities:
		var ability_id = ability_data.ability_id
		var params = ability_data.params
		var can_use = ability_data.can_use
		var reason = ability_data.reason
		
		var button = _create_ability_button(ability_id, params, can_use, reason)
		container.add_child(button)
		ability_buttons.append(button)
	
	# Position at bottom center of screen
	_position_bar()
	show()

func _create_ability_button(ability_id: String, params: Dictionary, can_use: bool, reason: String) -> Button:
	var button = Button.new()

	var ability_name = Registry.abilities.get_ability_name(ability_id)
	var ability_desc = Registry.abilities.get_ability_description(ability_id)

	# Check if this is a toggle ability that is currently active
	var is_toggle_active = _is_toggle_ability_active(ability_id)

	if is_toggle_active:
		button.text = _get_toggle_off_text(ability_id)
	else:
		button.text = ability_name

	button.custom_minimum_size = Vector2(100, 40)
	button.disabled = not can_use

	# Tooltip
	if can_use:
		if is_toggle_active:
			button.tooltip_text = ability_desc + "\n\n[Currently ACTIVE - click to deactivate]"
		else:
			button.tooltip_text = ability_desc
	else:
		button.tooltip_text = ability_desc + "\n\n[Cannot use: " + reason + "]"

	# Style
	if can_use:
		if is_toggle_active:
			# Active toggle style (green tones)
			var normal_style = StyleBoxFlat.new()
			normal_style.bg_color = Color(0.2, 0.55, 0.3)
			normal_style.set_corner_radius_all(4)
			normal_style.set_content_margin_all(8)
			button.add_theme_stylebox_override("normal", normal_style)

			var hover_style = StyleBoxFlat.new()
			hover_style.bg_color = Color(0.25, 0.65, 0.35)
			hover_style.set_corner_radius_all(4)
			hover_style.set_content_margin_all(8)
			button.add_theme_stylebox_override("hover", hover_style)

			var pressed_style = StyleBoxFlat.new()
			pressed_style.bg_color = Color(0.15, 0.45, 0.25)
			pressed_style.set_corner_radius_all(4)
			pressed_style.set_content_margin_all(8)
			button.add_theme_stylebox_override("pressed", pressed_style)
		else:
			# Normal style (blue tones)
			var normal_style = StyleBoxFlat.new()
			normal_style.bg_color = Color(0.2, 0.4, 0.6)
			normal_style.set_corner_radius_all(4)
			normal_style.set_content_margin_all(8)
			button.add_theme_stylebox_override("normal", normal_style)

			var hover_style = StyleBoxFlat.new()
			hover_style.bg_color = Color(0.25, 0.5, 0.7)
			hover_style.set_corner_radius_all(4)
			hover_style.set_content_margin_all(8)
			button.add_theme_stylebox_override("hover", hover_style)

			var pressed_style = StyleBoxFlat.new()
			pressed_style.bg_color = Color(0.15, 0.35, 0.5)
			pressed_style.set_corner_radius_all(4)
			pressed_style.set_content_margin_all(8)
			button.add_theme_stylebox_override("pressed", pressed_style)
	else:
		var disabled_style = StyleBoxFlat.new()
		disabled_style.bg_color = Color(0.2, 0.2, 0.2)
		disabled_style.set_corner_radius_all(4)
		disabled_style.set_content_margin_all(8)
		button.add_theme_stylebox_override("disabled", disabled_style)
		button.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))

	# Connect signal with ability info
	button.pressed.connect(_on_ability_button_pressed.bind(ability_id, params))

	return button

func _is_toggle_ability_active(ability_id: String) -> bool:
	"""Check if a toggle ability is currently active on the unit."""
	if not current_unit:
		return false
	match ability_id:
		"explore_route":
			return current_unit.is_exploring_route
	return false

func _get_toggle_off_text(ability_id: String) -> String:
	"""Get the button text for when a toggle ability is active (to deactivate)."""
	match ability_id:
		"explore_route":
			return "Stop Exploring"
	return "Deactivate"

func _on_ability_button_pressed(ability_id: String, params: Dictionary):
	print("Ability button pressed: ", ability_id)
	emit_signal("ability_requested", ability_id, params)

func _clear_buttons():
	for button in ability_buttons:
		button.queue_free()
	ability_buttons.clear()

func _position_bar():
	# Position at bottom center
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Wait for size to be calculated
	await get_tree().process_frame
	
	var bar_size = size
	position = Vector2(
		(viewport_size.x - bar_size.x) / 2,
		viewport_size.y - bar_size.y - 20
	)

func hide_bar():
	"""Hide the ability bar"""
	current_unit = null
	_clear_buttons()
	hide()

func refresh():
	"""Refresh the ability bar for the current unit"""
	if current_unit:
		show_unit_abilities(current_unit)
