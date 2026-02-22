extends PanelContainer
class_name CargoDialog

# Dialog for transferring resources between a unit and a city

signal transfer_completed
signal dialog_closed

var unit: Unit = null
var city: City = null

# UI elements
var title_label: Label
var resource_rows: VBoxContainer
var close_button: Button
var transfer_entries: Array[Dictionary] = []  # {resource_id, city_label, cargo_label, slider}

func _ready():
	_setup_ui()
	hide()

func _setup_ui():
	custom_minimum_size = Vector2(480, 400)
	
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
	
	# Column headers
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	main_vbox.add_child(header)
	
	var city_header = Label.new()
	city_header.text = "City Storage"
	city_header.add_theme_font_size_override("font_size", 14)
	city_header.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	city_header.custom_minimum_size.x = 100
	city_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(city_header)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	var transfer_header = Label.new()
	transfer_header.text = "← Transfer →"
	transfer_header.add_theme_font_size_override("font_size", 12)
	transfer_header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	transfer_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transfer_header.custom_minimum_size.x = 180
	header.add_child(transfer_header)
	
	var spacer2 = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer2)
	
	var cargo_header = Label.new()
	cargo_header.text = "Unit Cargo"
	cargo_header.add_theme_font_size_override("font_size", 14)
	cargo_header.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	cargo_header.custom_minimum_size.x = 100
	cargo_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(cargo_header)
	
	# Scrollable resource rows
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 220
	main_vbox.add_child(scroll)
	
	resource_rows = VBoxContainer.new()
	resource_rows.add_theme_constant_override("separation", 6)
	resource_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(resource_rows)
	
	# Cargo capacity bar
	var capacity_hbox = HBoxContainer.new()
	capacity_hbox.add_theme_constant_override("separation", 8)
	main_vbox.add_child(capacity_hbox)
	
	var cap_label = Label.new()
	cap_label.text = "Cargo:"
	cap_label.add_theme_font_size_override("font_size", 13)
	capacity_hbox.add_child(cap_label)
	
	var capacity_bar = ProgressBar.new()
	capacity_bar.name = "CapacityBar"
	capacity_bar.custom_minimum_size = Vector2(200, 16)
	capacity_bar.show_percentage = false
	capacity_hbox.add_child(capacity_bar)
	
	var capacity_text = Label.new()
	capacity_text.name = "CapacityText"
	capacity_text.add_theme_font_size_override("font_size", 13)
	capacity_hbox.add_child(capacity_text)
	
	# Separator
	main_vbox.add_child(HSeparator.new())
	
	# Buttons
	var button_row = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(button_row)
	
	var confirm_button = Button.new()
	confirm_button.text = "Confirm Transfers"
	confirm_button.custom_minimum_size = Vector2(150, 36)
	confirm_button.pressed.connect(_on_confirm_pressed)
	_style_button(confirm_button, Color(0.2, 0.45, 0.3))
	button_row.add_child(confirm_button)
	
	close_button = Button.new()
	close_button.text = "Cancel"
	close_button.custom_minimum_size = Vector2(100, 36)
	close_button.pressed.connect(_on_close_pressed)
	_style_button(close_button, Color(0.4, 0.25, 0.2))
	button_row.add_child(close_button)

func _style_button(button: Button, color: Color):
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	button.add_theme_stylebox_override("normal", style)
	
	var hover = style.duplicate()
	hover.bg_color = color.lightened(0.15)
	button.add_theme_stylebox_override("hover", hover)

func open(p_unit: Unit, p_city: City):
	"""Open the dialog for a unit at a city"""
	unit = p_unit
	city = p_city
	
	if not unit or not city:
		return
	
	title_label.text = "%s ↔ %s" % [unit.get_display_name(), city.city_name]
	
	_build_resource_rows()
	_update_capacity_display()
	
	# Center on screen
	await get_tree().process_frame
	var viewport_size = get_viewport().get_visible_rect().size
	position = (viewport_size - size) / 2
	
	show()

func _build_resource_rows():
	"""Build transfer rows for each available resource"""
	# Clear existing rows
	for child in resource_rows.get_children():
		child.queue_free()
	transfer_entries.clear()
	
	# Collect all resources that exist in either city or cargo
	var resource_ids: Array[String] = []
	
	for resource_id in Registry.resources.get_all_resource_ids():
		var city_amount = city.get_total_resource(resource_id)
		var cargo_amount = unit.get_cargo_amount(resource_id)
		# Only show resources that are present or could be produced
		if city_amount > 0 or cargo_amount > 0:
			# Don't allow transferring population
			if Registry.resources.has_tag(resource_id, "population"):
				continue
			# Skip non-storable flow resources (admin_capacity, etc.)
			if not Registry.resources.has_tag(resource_id, "storable"):
				continue
			resource_ids.append(resource_id)
	
	if resource_ids.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No resources to transfer"
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		resource_rows.add_child(empty_label)
		return
	
	for resource_id in resource_ids:
		_add_resource_row(resource_id)

func _add_resource_row(resource_id: String):
	"""Add a row for transferring a resource"""
	var city_amount = city.get_total_resource(resource_id)
	var cargo_amount = unit.get_cargo_amount(resource_id)
	var total = city_amount + cargo_amount
	
	if total <= 0:
		return
	
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	resource_rows.add_child(row)
	
	# Resource name
	var name_label = Label.new()
	name_label.text = Registry.get_name_label("resource", resource_id)
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	name_label.custom_minimum_size.x = 70
	row.add_child(name_label)
	
	# City amount
	var city_label = Label.new()
	city_label.text = "%.0f" % city_amount
	city_label.add_theme_font_size_override("font_size", 13)
	city_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	city_label.custom_minimum_size.x = 40
	city_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(city_label)
	
	# Slider: left = all in city, right = all in cargo
	var slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = total
	slider.value = cargo_amount  # Current cargo amount
	slider.step = 1
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 160
	row.add_child(slider)
	
	# Cargo amount
	var cargo_label = Label.new()
	cargo_label.text = "%.0f" % cargo_amount
	cargo_label.add_theme_font_size_override("font_size", 13)
	cargo_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	cargo_label.custom_minimum_size.x = 40
	cargo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(cargo_label)
	
	var entry = {
		resource_id = resource_id,
		city_label = city_label,
		cargo_label = cargo_label,
		slider = slider,
		total = total,
		original_cargo = cargo_amount
	}
	transfer_entries.append(entry)
	
	# Connect slider to update labels
	slider.value_changed.connect(_on_slider_changed.bind(entry))

func _on_slider_changed(new_value: float, entry: Dictionary):
	"""Update labels and enforce cargo capacity when slider moves"""
	# Calculate total cargo across all sliders
	var total_cargo: float = 0.0
	for e in transfer_entries:
		if e.resource_id == entry.resource_id:
			total_cargo += new_value
		else:
			total_cargo += e.slider.value

	# If over cargo capacity, clamp this slider
	if total_cargo > unit.cargo_capacity:
		var excess = total_cargo - unit.cargo_capacity
		new_value = max(0, new_value - excess)
		entry.slider.set_value_no_signal(new_value)

	# Check city storage capacity when moving resources to city
	var delta_to_city = entry.original_cargo - new_value  # positive = resources going to city
	if delta_to_city > 0:
		var available = city.get_available_storage(entry.resource_id)
		if delta_to_city > available:
			new_value = max(0, entry.original_cargo - available)
			entry.slider.set_value_no_signal(new_value)

	var city_amount = entry.total - new_value
	entry.city_label.text = "%.0f" % city_amount
	entry.cargo_label.text = "%.0f" % new_value

	_update_capacity_display()

func _update_capacity_display():
	"""Update the cargo capacity bar"""
	var total_cargo: float = 0.0
	for entry in transfer_entries:
		total_cargo += entry.slider.value
	
	var bar = find_child("CapacityBar") as ProgressBar
	var text = find_child("CapacityText") as Label
	
	if bar:
		bar.max_value = unit.cargo_capacity
		bar.value = total_cargo
		
		if total_cargo > unit.cargo_capacity * 0.9:
			bar.modulate = Color(0.9, 0.4, 0.3)
		elif total_cargo > unit.cargo_capacity * 0.6:
			bar.modulate = Color(0.9, 0.8, 0.3)
		else:
			bar.modulate = Color(0.3, 0.8, 0.4)
	
	if text:
		text.text = "%.0f / %d" % [total_cargo, unit.cargo_capacity]

func _on_confirm_pressed():
	"""Apply all transfers"""
	if not unit or not city:
		return
	
	for entry in transfer_entries:
		var resource_id = entry.resource_id
		var desired_cargo = entry.slider.value
		var current_cargo = unit.get_cargo_amount(resource_id)
		var diff = desired_cargo - current_cargo
		
		if abs(diff) < 0.01:
			continue
		
		if diff > 0:
			# Loading: city -> unit
			var available = city.get_total_resource(resource_id)
			var to_transfer = min(diff, available)
			if to_transfer > 0:
				city.consume_resource(resource_id, to_transfer)
				unit.add_cargo(resource_id, to_transfer)
				print("Loaded %.0f %s from %s" % [to_transfer, resource_id, city.city_name])
		else:
			# Unloading: unit -> city
			var to_transfer = abs(diff)
			var removed = unit.remove_cargo(resource_id, to_transfer)
			if removed > 0:
				var stored = city.store_resource(resource_id, removed)
				if stored < removed:
					# City couldn't store everything (shared pool full), keep remainder in cargo
					var remainder = removed - stored
					unit.add_cargo(resource_id, remainder)
					print("Unloaded %.0f %s to %s (%.0f returned to cargo - storage full)" % [stored, resource_id, city.city_name, remainder])
				else:
					print("Unloaded %.0f %s to %s" % [removed, resource_id, city.city_name])
	
	emit_signal("transfer_completed")
	hide()

func _on_close_pressed():
	emit_signal("dialog_closed")
	hide()

func _input(event: InputEvent):
	if visible and event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			_on_close_pressed()
			get_viewport().set_input_as_handled()
