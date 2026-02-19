extends PanelContainer
class_name UnitInfoPanel

# Panel displayed on the right side when a unit is selected

signal close_requested
signal fortify_action_requested

var current_unit: Unit = null
var _is_enemy: bool = false

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

var cargo_container: VBoxContainer
var cargo_capacity_label: Label
var cargo_items_container: VBoxContainer

var actions_container: VBoxContainer
var actions_sep: HSeparator
var actions_header_label: Label
var fortify_button: Button

func _ready():
	_setup_ui()
	visible = false

func _setup_ui():
	custom_minimum_size = Vector2(220, 0)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	style.border_color = Color(0.3, 0.3, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	add_child(main_vbox)
	
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

	# Armor
	var def_label = Label.new()
	def_label.text = "Armor:"
	def_label.add_theme_font_size_override("font_size", 14)
	stats_grid.add_child(def_label)

	defense_label = Label.new()
	defense_label.add_theme_font_size_override("font_size", 14)
	stats_grid.add_child(defense_label)
	
	# Cargo section (hidden by default)
	var cargo_sep = HSeparator.new()
	cargo_sep.name = "CargoSep"
	main_vbox.add_child(cargo_sep)
	
	cargo_container = VBoxContainer.new()
	cargo_container.name = "CargoContainer"
	cargo_container.add_theme_constant_override("separation", 4)
	main_vbox.add_child(cargo_container)
	
	var cargo_header = Label.new()
	cargo_header.text = "Cargo"
	cargo_header.add_theme_font_size_override("font_size", 14)
	cargo_container.add_child(cargo_header)
	
	cargo_capacity_label = Label.new()
	cargo_capacity_label.add_theme_font_size_override("font_size", 12)
	cargo_capacity_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	cargo_container.add_child(cargo_capacity_label)
	
	cargo_items_container = VBoxContainer.new()
	cargo_items_container.add_theme_constant_override("separation", 2)
	cargo_container.add_child(cargo_items_container)
	
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
	
	# Actions separator
	actions_sep = HSeparator.new()
	main_vbox.add_child(actions_sep)

	# Actions
	actions_header_label = Label.new()
	actions_header_label.text = "Actions"
	actions_header_label.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(actions_header_label)
	
	actions_container = VBoxContainer.new()
	actions_container.add_theme_constant_override("separation", 4)
	main_vbox.add_child(actions_container)
	
	fortify_button = Button.new()
	fortify_button.text = "Fortify"
	fortify_button.pressed.connect(_on_fortify_pressed)
	actions_container.add_child(fortify_button)

func show_unit(unit: Unit):
	_show_unit_internal(unit, false)

func show_enemy_unit(unit: Unit):
	"""Show an enemy unit's info (read-only, no actions, limited detail)."""
	_show_unit_internal(unit, true)

func _show_unit_internal(unit: Unit, is_enemy: bool):
	# Disconnect from previous unit
	if current_unit != null and current_unit.health_changed.is_connected(_on_unit_health_changed):
		current_unit.health_changed.disconnect(_on_unit_health_changed)

	current_unit = unit
	_is_enemy = is_enemy

	if unit == null:
		visible = false
		return

	visible = true
	_update_display()

	# Connect to unit signals for live updates
	if not unit.health_changed.is_connected(_on_unit_health_changed):
		unit.health_changed.connect(_on_unit_health_changed)

func hide_panel():
	if current_unit != null:
		if current_unit.health_changed.is_connected(_on_unit_health_changed):
			current_unit.health_changed.disconnect(_on_unit_health_changed)
	
	current_unit = null
	visible = false

func refresh():
	"""Refresh the display (call after cargo changes, movement, etc.)"""
	_update_display()

func _update_display():
	if current_unit == null:
		return

	# Panel border color: red tint for enemies
	var style = get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.border_color = Color(0.6, 0.25, 0.25) if _is_enemy else Color(0.3, 0.3, 0.4)

	# Unit name
	unit_name_label.text = Registry.units.get_unit_name(current_unit.unit_type)

	# Category (from registry, not from Unit model)
	var unit_data = Registry.units.get_unit(current_unit.unit_type)
	var category = unit_data.get("category", "civil").capitalize()
	var suffix = " (Enemy)" if _is_enemy else ""
	category_label.text = category + " Unit" + suffix
	
	# Icon
	_load_unit_icon()
	
	# Health
	health_bar.max_value = current_unit.max_health
	health_bar.value = current_unit.current_health
	health_label.text = " %d / %d" % [current_unit.current_health, current_unit.max_health]
	
	# Update health bar color (get_health_percent returns 0-100)
	var health_pct = current_unit.get_health_percent()
	if health_pct > 66.0:
		health_bar.modulate = Color(0.3, 0.9, 0.3)
	elif health_pct > 33.0:
		health_bar.modulate = Color(0.9, 0.8, 0.2)
	else:
		health_bar.modulate = Color(0.9, 0.3, 0.3)
	
	# Movement — hide current movement for enemies
	if _is_enemy:
		movement_label.text = str(current_unit.max_movement)
	else:
		movement_label.text = "%d / %d" % [current_unit.current_movement, current_unit.max_movement]
	
	# Combat stats — show attack strength from ability params, armor class names
	var attack_str = "—"
	if current_unit.can_attack():
		var atk_params = _get_attack_params(current_unit)
		if not atk_params.is_empty():
			attack_str = "%s %s" % [str(atk_params.get("strength", 0)), atk_params.get("attack_type", "")]
	attack_label.text = attack_str

	var armor_names: Array[String] = []
	for ac_id in current_unit.armor_class_ids:
		armor_names.append(Registry.localization.get_name("armor_class", ac_id))
	defense_label.text = ", ".join(armor_names) if not armor_names.is_empty() else "None"

	# Color attack based on unit type
	if current_unit.is_civil():
		attack_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		attack_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Owner and position
	owner_label.text = "Owner: %s" % current_unit.owner_id
	position_label.text = "Position: (%d, %d)" % [current_unit.coord.x, current_unit.coord.y]
	
	# Hide cargo and actions for enemy units
	if _is_enemy:
		cargo_container.visible = false
		var cargo_sep = find_child("CargoSep")
		if cargo_sep:
			cargo_sep.visible = false
		actions_sep.visible = false
		actions_header_label.visible = false
		actions_container.visible = false
	else:
		# Update cargo display
		_update_cargo()
		# Update action buttons
		actions_sep.visible = true
		actions_header_label.visible = true
		actions_container.visible = true
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

func _update_cargo():
	if current_unit == null:
		return
	
	var has_cargo = current_unit.has_cargo_capacity()
	cargo_container.visible = has_cargo
	
	var cargo_sep = find_child("CargoSep")
	if cargo_sep:
		cargo_sep.visible = has_cargo
	
	if not has_cargo:
		return
	
	# Capacity display
	var total = current_unit.get_total_cargo()
	var capacity = current_unit.cargo_capacity
	cargo_capacity_label.text = "%.0f / %d" % [total, capacity]
	
	# Clear and rebuild cargo items
	for child in cargo_items_container.get_children():
		child.queue_free()
	
	var all_cargo = current_unit.get_all_cargo()
	if all_cargo.is_empty():
		var empty_label = Label.new()
		empty_label.text = "  (empty)"
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		cargo_items_container.add_child(empty_label)
	else:
		for resource_id in all_cargo.keys():
			var amount = all_cargo[resource_id]
			if amount <= 0:
				continue
			var item_label = Label.new()
			var resource_name = Registry.get_name_label("resource", resource_id)
			item_label.text = "  %s: %.0f" % [resource_name, amount]
			item_label.add_theme_font_size_override("font_size", 12)
			item_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
			cargo_items_container.add_child(item_label)

func _update_actions():
	# Fortify button
	fortify_button.disabled = current_unit.is_fortified or not current_unit.can_move()
	if current_unit.is_fortified:
		fortify_button.text = "Fortified"
	else:
		fortify_button.text = "Fortify"

func _on_unit_health_changed(_new_health: int, _max_health: int):
	_update_display()

func _get_attack_params(unit: Unit) -> Dictionary:
	"""Get attack params from unit's first military ability."""
	var unit_data = Registry.units.get_unit(unit.unit_type)
	var unit_abilities = unit_data.get("abilities", [])
	for ability_ref in unit_abilities:
		var ability_id: String = ""
		var params: Dictionary = {}
		if ability_ref is Dictionary:
			ability_id = ability_ref.get("ability_id", "")
			params = ability_ref.get("params", {})
		elif ability_ref is String:
			ability_id = ability_ref
		var ability_data = Registry.abilities.get_ability(ability_id)
		if ability_data.get("category", "") == "military":
			return params
	return {}

func _on_fortify_pressed():
	if current_unit != null:
		current_unit.fortify()
		_update_display()
		emit_signal("fortify_action_requested")
