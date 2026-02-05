extends PanelContainer
class_name CityQueuePanel

# Displays construction and training queues for the city

signal closed

var current_city: City
var vbox: VBoxContainer
var construction_section: VBoxContainer
var upgrade_section: VBoxContainer
var training_section: VBoxContainer

func _ready():
	_setup_panel()

func _setup_panel():
	# Panel styling
	custom_minimum_size = Vector2(280, 200)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	style.border_color = Color(0.3, 0.3, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	
	# Main container
	vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)
	
	# Header
	var header = HBoxContainer.new()
	vbox.add_child(header)
	
	var title = Label.new()
	title.text = "City Queues"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)
	
	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	# Construction section
	var const_header = Label.new()
	const_header.text = "Construction"
	const_header.add_theme_font_size_override("font_size", 14)
	const_header.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	vbox.add_child(const_header)
	
	construction_section = VBoxContainer.new()
	construction_section.add_theme_constant_override("separation", 4)
	vbox.add_child(construction_section)
	
	# Upgrade section
	var upgrade_header = Label.new()
	upgrade_header.text = "Upgrades"
	upgrade_header.add_theme_font_size_override("font_size", 14)
	upgrade_header.add_theme_color_override("font_color", Color(0.6, 0.7, 1.0))
	vbox.add_child(upgrade_header)
	
	upgrade_section = VBoxContainer.new()
	upgrade_section.add_theme_constant_override("separation", 4)
	vbox.add_child(upgrade_section)
	
	# Training section
	var train_header = Label.new()
	train_header.text = "Training"
	train_header.add_theme_font_size_override("font_size", 14)
	train_header.add_theme_color_override("font_color", Color(1.0, 0.7, 0.5))
	vbox.add_child(train_header)
	
	training_section = VBoxContainer.new()
	training_section.add_theme_constant_override("separation", 4)
	vbox.add_child(training_section)
	
	# Position on right side of screen
	_position_panel()
	
	visible = false

func _position_panel():
	var viewport_size = get_viewport().get_visible_rect().size
	position = Vector2(viewport_size.x - custom_minimum_size.x - 20, 80)

func show_panel(city: City):
	current_city = city
	update_display()
	visible = true
	
	# Animate appearance
	modulate.a = 0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

func hide_panel():
	if visible:
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.15)
		tween.tween_callback(func(): visible = false)

func update_display():
	if not current_city:
		return
	
	_update_construction_section()
	_update_upgrade_section()
	_update_training_section()

func _update_construction_section():
	# Clear existing entries
	for child in construction_section.get_children():
		child.queue_free()
	
	var has_construction = false
	
	for coord in current_city.building_instances.keys():
		var instance: BuildingInstance = current_city.building_instances[coord]
		
		if instance.is_under_construction():
			has_construction = true
			var entry = _create_construction_entry(instance)
			construction_section.add_child(entry)
	
	if not has_construction:
		var empty_label = Label.new()
		empty_label.text = "No buildings under construction"
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		construction_section.add_child(empty_label)

func _update_upgrade_section():
	# Clear existing entries
	for child in upgrade_section.get_children():
		child.queue_free()
	
	var has_upgrades = false
	
	for coord in current_city.building_instances.keys():
		var instance: BuildingInstance = current_city.building_instances[coord]
		
		if instance.is_upgrading():
			has_upgrades = true
			var entry = _create_upgrade_entry(instance)
			upgrade_section.add_child(entry)
	
	if not has_upgrades:
		var empty_label = Label.new()
		empty_label.text = "No upgrades in progress"
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		upgrade_section.add_child(empty_label)

func _update_training_section():
	# Clear existing entries
	for child in training_section.get_children():
		child.queue_free()
	
	var has_training = false
	
	for coord in current_city.building_instances.keys():
		var instance: BuildingInstance = current_city.building_instances[coord]
		
		if instance.is_training():
			has_training = true
			var entry = _create_training_entry(instance)
			training_section.add_child(entry)
	
	if not has_training:
		var empty_label = Label.new()
		empty_label.text = "No units in training"
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		training_section.add_child(empty_label)

func _create_construction_entry(instance: BuildingInstance) -> HBoxContainer:
	var entry = HBoxContainer.new()
	entry.add_theme_constant_override("separation", 8)
	
	# Building name
	var name_label = Label.new()
	name_label.text = Registry.get_name_label("building", instance.building_id)
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.add_child(name_label)
	
	# Progress bar container
	var progress_container = HBoxContainer.new()
	progress_container.add_theme_constant_override("separation", 4)
	entry.add_child(progress_container)
	
	# Simple progress indicator
	var status_label = Label.new()
	if instance.is_construction_paused():
		status_label.text = "PAUSED"
		status_label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		status_label.text = "%d turns" % instance.turns_remaining
		status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	status_label.add_theme_font_size_override("font_size", 12)
	progress_container.add_child(status_label)
	
	return entry

func _create_upgrade_entry(instance: BuildingInstance) -> VBoxContainer:
	var entry = VBoxContainer.new()
	entry.add_theme_constant_override("separation", 2)
	
	# Top row: From -> To and turns
	var top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	entry.add_child(top_row)
	
	# Upgrade path: Building Name → Target Name
	var from_name = Registry.get_name_label("building", instance.building_id)
	var to_name = Registry.get_name_label("building", instance.upgrading_to)
	
	var path_label = Label.new()
	path_label.text = "%s → %s" % [from_name, to_name]
	path_label.add_theme_font_size_override("font_size", 13)
	path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(path_label)
	
	# Turns remaining
	var turns_label = Label.new()
	turns_label.text = "%d turns" % instance.upgrade_turns_remaining
	turns_label.add_theme_font_size_override("font_size", 12)
	turns_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	top_row.add_child(turns_label)
	
	# Progress bar
	var progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 6)
	progress_bar.max_value = 100
	progress_bar.value = instance.get_upgrade_progress_percent()
	progress_bar.show_percentage = false
	entry.add_child(progress_bar)
	
	return entry

func _create_training_entry(instance: BuildingInstance) -> VBoxContainer:
	var entry = VBoxContainer.new()
	entry.add_theme_constant_override("separation", 2)
	
	# Top row: Unit name and turns
	var top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	entry.add_child(top_row)
	
	# Unit name
	var name_label = Label.new()
	name_label.text = Registry.units.get_unit_name(instance.training_unit_id)
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(name_label)
	
	# Turns remaining
	var turns_label = Label.new()
	turns_label.text = "%d turns" % instance.training_turns_remaining
	turns_label.add_theme_font_size_override("font_size", 12)
	turns_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	top_row.add_child(turns_label)
	
	# Bottom row: Building name (where it's being trained)
	var building_label = Label.new()
	building_label.text = "at " + Registry.get_name_label("building", instance.building_id)
	building_label.add_theme_font_size_override("font_size", 11)
	building_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	entry.add_child(building_label)
	
	# Progress bar
	var progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 6)
	progress_bar.max_value = 100
	progress_bar.value = instance.get_training_progress_percent()
	progress_bar.show_percentage = false
	entry.add_child(progress_bar)
	
	return entry

func _on_close_pressed():
	hide_panel()
	emit_signal("closed")
