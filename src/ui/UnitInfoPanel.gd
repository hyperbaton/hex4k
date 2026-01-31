extends PanelContainer
class_name UnitInfoPanel

# Panel displayed on the right side when a unit is selected

signal close_requested
signal move_action_requested
signal fortify_action_requested

var current_unit: Unit = null

# UI Elements
var unit_name_label: Label
var unit_icon: TextureRect
var health_bar: ProgressBar
var health_label: Label
var movement_label: Label
var attack_label: Label
var defense_label: Label
var category_label: Label
var owner_label: Label
var position_label: Label

var actions_container: VBoxContainer
var move_button: Button
var fortify_button: Button

func _ready():
	_setup_ui()
	visible = false

func _setup_ui():
	custom_minimum_size = Vector2(220, 0)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(main_vbox)
	
	# Header with icon and name
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	main_vbox.add_child(header)
	
	unit_icon = TextureRect.new()
	unit_icon.custom_minimum_size = Vector2(48, 48)
	unit_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	unit_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header.add_child(unit_icon)
	
	var header_vbox = VBoxContainer.new()
	header.add_child(header_vbox)
	
	unit_name_label = Label.new()
	unit_name_label.add_theme_font_size_override("font_size", 18)
	header_vbox.add_child(unit_name_label)
	
	category_label = Label.new()
	category_label.add_theme_font_size_override("font_size", 12)
	category_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	header_vbox.add_child(category_label)
	
	# Separator
	main_vbox.add_child(HSeparator.new())
	
	# Health bar
	var health_container = VBoxContainer.new()
	main_vbox.add_child(health_container)
	
	var health_header = Label.new()
	health_header.text = "Health"
	health_header.add_theme_font_size_override("font_size", 12)
	health_container.add_child(health_header)
	
	var health_hbox = HBoxContainer.new()
	health_container.add_child(health_hbox)
	
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(140, 20)
	health_bar.show_percentage = false
	health_hbox.add_child(health_bar)
	
	health_label = Label.new()
	health_label.add_theme_font_size_override("font_size", 12)
	health_hbox.add_child(health_label)
	
	# Stats grid
	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 20)
	stats_grid.add_theme_constant_override("v_separation", 4)
	main_vbox.add_child(stats_grid)
	
	# Movement
	var mv_label = Label.new()
	mv_label.text = "Movement:"
	mv_label.add_theme_font_size_override("font_size", 14)
	stats_grid.add_child(mv_label)
	
	movement_label = Label.new()
	movement_label.add_theme_font_size_override("font_size", 14)
	stats_grid.add_child(movement_label)
	
	# Attack
	var atk_label = Label.new()
	atk_label.text = "Attack:"
	atk_label.add_theme_font_size_override("font_size", 14)
	stats_grid.add_child(atk_label)
	
	attack_label = Label.new()
	attack_label.add_theme_font_size_override("font_size", 14)
	stats_grid.add_child(attack_label)
	
	# Defense
	var def_label = Label.new()
	def_label.text = "Defense:"
	def_label.add_theme_font_size_override("font_size", 14)
	stats_grid.add_child(def_label)
	
	defense_label = Label.new()
	defense_label.add_theme_font_size_override("font_size", 14)
	stats_grid.add_child(defense_label)
	
	# Separator
	main_vbox.add_child(HSeparator.new())
	
	# Info section
	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 2)
	main_vbox.add_child(info_vbox)
	
	owner_label = Label.new()
	owner_label.add_theme_font_size_override("font_size", 12)
	owner_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	info_vbox.add_child(owner_label)
	
	position_label = Label.new()
	position_label.add_theme_font_size_override("font_size", 12)
	position_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	info_vbox.add_child(position_label)
	
	# Separator
	main_vbox.add_child(HSeparator.new())
	
	# Actions
	var actions_label = Label.new()
	actions_label.text = "Actions"
	actions_label.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(actions_label)
	
	actions_container = VBoxContainer.new()
	actions_container.add_theme_constant_override("separation", 4)
	main_vbox.add_child(actions_container)
	
	fortify_button = Button.new()
	fortify_button.text = "Fortify"
	fortify_button.pressed.connect(_on_fortify_pressed)
	actions_container.add_child(fortify_button)

func show_unit(unit: Unit):
	current_unit = unit
	
	if unit == null:
		visible = false
		return
	
	visible = true
	_update_display()
	
	# Connect to unit signals for live updates
	if not unit.health_changed.is_connected(_on_unit_health_changed):
		unit.health_changed.connect(_on_unit_health_changed)
	if not unit.movement_changed.is_connected(_on_unit_movement_changed):
		unit.movement_changed.connect(_on_unit_movement_changed)

func hide_panel():
	if current_unit != null:
		# Disconnect signals
		if current_unit.health_changed.is_connected(_on_unit_health_changed):
			current_unit.health_changed.disconnect(_on_unit_health_changed)
		if current_unit.movement_changed.is_connected(_on_unit_movement_changed):
			current_unit.movement_changed.disconnect(_on_unit_movement_changed)
	
	current_unit = null
	visible = false

func _update_display():
	if current_unit == null:
		return
	
	# Unit name
	unit_name_label.text = Registry.units.get_unit_name(current_unit.unit_type)
	
	# Category
	var category = current_unit.get_category().capitalize()
	category_label.text = category + " Unit"
	
	# Icon
	_load_unit_icon()
	
	# Health
	health_bar.max_value = current_unit.get_max_health()
	health_bar.value = current_unit.current_health
	health_label.text = " %d / %d" % [current_unit.current_health, current_unit.get_max_health()]
	
	# Update health bar color
	var health_pct = current_unit.get_health_percentage()
	if health_pct > 0.66:
		health_bar.modulate = Color(0.3, 0.9, 0.3)
	elif health_pct > 0.33:
		health_bar.modulate = Color(0.9, 0.8, 0.2)
	else:
		health_bar.modulate = Color(0.9, 0.3, 0.3)
	
	# Movement
	movement_label.text = "%d / %d" % [current_unit.movement_remaining, current_unit.get_max_movement()]
	
	# Combat stats
	attack_label.text = str(current_unit.get_attack())
	defense_label.text = str(current_unit.get_defense())
	
	# Color attack/defense based on unit type
	if current_unit.is_civil():
		attack_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		attack_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Owner and position
	owner_label.text = "Owner: Player %d" % current_unit.owner_id
	position_label.text = "Position: (%d, %d)" % [current_unit.hex_position.x, current_unit.hex_position.y]
	
	# Update action buttons
	_update_actions()

func _load_unit_icon():
	var unit_data = Registry.units.get_unit(current_unit.unit_type)
	var visual_data = unit_data.get("visual", {})
	var sprite_path = visual_data.get("sprite", "")
	
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var texture = load(sprite_path)
		if texture:
			unit_icon.texture = texture
			return
	
	# Fallback: create colored placeholder
	var color = Color(visual_data.get("color", "#FFFFFF"))
	var img = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(color)
	unit_icon.texture = ImageTexture.create_from_image(img)

func _update_actions():
	# Fortify button
	fortify_button.disabled = current_unit.is_fortified or not current_unit.has_movement()
	if current_unit.is_fortified:
		fortify_button.text = "Fortified"
	else:
		fortify_button.text = "Fortify"

func _on_unit_health_changed(_new_health: int, _max_health: int):
	_update_display()

func _on_unit_movement_changed(_remaining: int, _max_points: int):
	_update_display()

func _on_fortify_pressed():
	if current_unit != null:
		current_unit.fortify()
		_update_display()
		emit_signal("fortify_action_requested")
