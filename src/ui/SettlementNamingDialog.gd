extends PanelContainer
class_name SettlementNamingDialog

# Dialog for naming a new settlement before founding it

signal name_confirmed(city_name: String)
signal dialog_closed

var title_label: Label
var name_input: LineEdit
var error_label: Label

func _ready():
	_setup_ui()
	hide()

func _setup_ui():
	custom_minimum_size = Vector2(360, 0)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 1.0)
	style.border_color = Color(0.4, 0.35, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	add_child(main_vbox)

	# Title
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title_label)

	# Separator
	main_vbox.add_child(HSeparator.new())

	# Name label
	var prompt_label = Label.new()
	prompt_label.text = "Settlement name:"
	prompt_label.add_theme_font_size_override("font_size", 14)
	prompt_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	main_vbox.add_child(prompt_label)

	# Name input
	name_input = LineEdit.new()
	name_input.custom_minimum_size = Vector2(320, 32)
	name_input.add_theme_font_size_override("font_size", 15)
	name_input.max_length = 30
	name_input.text_submitted.connect(_on_text_submitted)
	main_vbox.add_child(name_input)

	# Error label (hidden by default)
	error_label = Label.new()
	error_label.add_theme_font_size_override("font_size", 12)
	error_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
	error_label.hide()
	main_vbox.add_child(error_label)

	# Separator
	main_vbox.add_child(HSeparator.new())

	# Buttons
	var button_row = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(button_row)

	var confirm_button = Button.new()
	confirm_button.text = "Found Settlement"
	confirm_button.custom_minimum_size = Vector2(150, 36)
	confirm_button.pressed.connect(_on_confirm_pressed)
	_style_button(confirm_button, Color(0.2, 0.45, 0.3))
	button_row.add_child(confirm_button)

	var cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(100, 36)
	cancel_button.pressed.connect(_on_cancel_pressed)
	_style_button(cancel_button, Color(0.4, 0.25, 0.2))
	button_row.add_child(cancel_button)

func _style_button(button: Button, color: Color):
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	button.add_theme_stylebox_override("normal", style)

	var hover = style.duplicate()
	hover.bg_color = color.lightened(0.15)
	button.add_theme_stylebox_override("hover", hover)

func open(settlement_type: String, default_name: String):
	"""Open the dialog for naming a new settlement"""
	var type_name = Registry.localization.get_name("settlement", settlement_type)
	if type_name.is_empty():
		type_name = settlement_type.capitalize()
	title_label.text = "Found %s" % type_name

	name_input.text = default_name
	error_label.hide()

	# Center on screen
	await get_tree().process_frame
	var viewport_size = get_viewport().get_visible_rect().size
	position = (viewport_size - size) / 2

	show()

	# Focus and select all text so the player can immediately type a new name
	name_input.grab_focus()
	name_input.select_all()

func _on_text_submitted(_text: String):
	"""Enter key pressed in the input field"""
	_on_confirm_pressed()

func _on_confirm_pressed():
	var city_name = name_input.text.strip_edges()
	if city_name.is_empty():
		error_label.text = "Name cannot be empty"
		error_label.show()
		return

	error_label.hide()
	emit_signal("name_confirmed", city_name)
	hide()

func _on_cancel_pressed():
	emit_signal("dialog_closed")
	hide()

func _input(event: InputEvent):
	if visible and event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			_on_cancel_pressed()
			get_viewport().set_input_as_handled()
