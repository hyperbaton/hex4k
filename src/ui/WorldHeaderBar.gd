extends HBoxContainer
class_name WorldHeaderBar

signal menu_pressed
signal tech_tree_pressed
signal perks_pressed

var menu_button: Button
var tech_tree_button: Button
var perks_button: Button

func _ready():
	# Position at top-left with margin
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = 10
	offset_top = 10
	offset_right = 300
	offset_bottom = 46
	add_theme_constant_override("separation", 8)

	# Button style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.85)
	style.border_color = Color(0.4, 0.4, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.25, 0.25, 0.35, 0.9)
	hover_style.border_color = Color(0.5, 0.5, 0.6)
	hover_style.set_border_width_all(1)
	hover_style.set_corner_radius_all(4)
	hover_style.set_content_margin_all(6)
	hover_style.content_margin_left = 12
	hover_style.content_margin_right = 12

	# Menu button
	menu_button = _create_button("Menu", style, hover_style)
	menu_button.pressed.connect(func(): menu_pressed.emit())
	add_child(menu_button)

	# Tech Tree button
	tech_tree_button = _create_button("Tech Tree", style, hover_style)
	tech_tree_button.pressed.connect(func(): tech_tree_pressed.emit())
	add_child(tech_tree_button)

	# Perks button
	perks_button = _create_button("Perks", style, hover_style)
	perks_button.pressed.connect(func(): perks_pressed.emit())
	add_child(perks_button)

func _create_button(text: String, normal_style: StyleBoxFlat, hover_style: StyleBoxFlat) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(80, 30)
	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)
	btn.add_theme_font_size_override("font_size", 14)
	return btn

func show_bar():
	visible = true

func hide_bar():
	visible = false
