extends PanelContainer
class_name ResourceDetailPanel

# Full-screen resource breakdown panel showing expected production/consumption for next turn

signal closed

@onready var close_button := $MarginContainer/VBoxContainer/Header/CloseButton
@onready var resource_list := $MarginContainer/VBoxContainer/ScrollContainer/ResourceList

var current_city: City

# Cached calculations for display
var calculated_production: Dictionary = {}  # resource_id -> amount
var calculated_consumption: Dictionary = {}  # resource_id -> amount
var calculated_decay: Dictionary = {}  # resource_id -> amount

func _ready():
	visible = false
	close_button.pressed.connect(_on_close_pressed)

func show_panel(city: City):
	current_city = city
	_calculate_city_flows()
	update_display()
	visible = true

func hide_panel():
	visible = false
	emit_signal("closed")

func _calculate_city_flows():
	"""Calculate expected production, consumption, and decay for next turn"""
	calculated_production.clear()
	calculated_consumption.clear()
	calculated_decay.clear()
	
	if not current_city:
		return
	
	# Skip calculations for abandoned cities
	if current_city.is_abandoned:
		return
	
	# Calculate admin efficiency (same formula as TurnManager)
	var admin_ratio = current_city.admin_capacity_used / max(current_city.admin_capacity_available, 0.001)
	var efficiency = _calculate_production_efficiency(admin_ratio)
	
	# Iterate through all building instances
	for coord in current_city.building_instances.keys():
		var instance: BuildingInstance = current_city.building_instances[coord]
		
		# Production: Only ACTIVE buildings produce
		if instance.is_active():
			var production = instance.get_production()
			for resource_id in production.keys():
				var amount = production[resource_id] * efficiency
				calculated_production[resource_id] = calculated_production.get(resource_id, 0.0) + amount
		
		# Consumption: ACTIVE and EXPECTING_RESOURCES buildings consume
		if instance.is_active() or instance.is_expecting_resources():
			var consumption = instance.get_consumption()
			for resource_id in consumption.keys():
				var amount = consumption[resource_id]
				calculated_consumption[resource_id] = calculated_consumption.get(resource_id, 0.0) + amount
	
	# Calculate decay based on current storage
	for resource_id in Registry.resources.get_all_resource_ids():
		var decay_rate = Registry.resources.get_decay_rate(resource_id)
		if decay_rate > 0:
			var stored = current_city.get_total_resource(resource_id)
			if stored > 0:
				# Decay calculation matches BuildingInstance.apply_decay()
				var decay_amount = stored * decay_rate
				calculated_decay[resource_id] = decay_amount

func _calculate_production_efficiency(admin_ratio: float) -> float:
	"""Calculate production efficiency based on admin ratio (matches TurnManager)"""
	if admin_ratio <= 1.0:
		return 1.0
	var overage = admin_ratio - 1.0
	var penalty = pow(overage, 1.5)
	return clamp(1.0 - penalty, 0.0, 1.0)

func update_display():
	# Clear existing list
	for child in resource_list.get_children():
		child.queue_free()
	
	if not current_city:
		return
	
	# Show abandoned status if applicable
	if current_city.is_abandoned:
		var abandoned_label = Label.new()
		abandoned_label.text = "This city is abandoned. No production or consumption."
		abandoned_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5))
		resource_list.add_child(abandoned_label)
		
		var sep = HSeparator.new()
		resource_list.add_child(sep)
	
	# Show efficiency warning if admin overloaded
	var admin_ratio = current_city.admin_capacity_used / max(current_city.admin_capacity_available, 0.001)
	if admin_ratio > 1.0 and not current_city.is_abandoned:
		var efficiency = _calculate_production_efficiency(admin_ratio)
		var warning_label = Label.new()
		warning_label.text = "⚠ Admin overloaded! Production efficiency: %.0f%%" % (efficiency * 100)
		warning_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
		resource_list.add_child(warning_label)
		
		var sep = HSeparator.new()
		resource_list.add_child(sep)
	
	# Add header
	add_list_header()
	
	# Collect all resources that are relevant (have storage, production, or consumption)
	var relevant_resources: Array[String] = []
	for resource_id in Registry.resources.get_all_resource_ids():
		# Skip resources that haven't been unlocked yet
		if not Registry.resources.is_resource_unlocked(resource_id):
			continue
		
		var stored = current_city.get_total_resource(resource_id)
		var capacity = current_city.get_total_storage_capacity(resource_id)
		var production = calculated_production.get(resource_id, 0.0)
		var consumption = calculated_consumption.get(resource_id, 0.0)
		
		# Show if has storage capacity, current stock, or any flow
		if capacity > 0 or stored > 0 or production > 0 or consumption > 0:
			relevant_resources.append(resource_id)
	
	# Add each relevant resource
	for resource_id in relevant_resources:
		add_resource_row(resource_id)
	
	# Add totals row
	add_totals_row()

func add_list_header():
	var header = create_resource_row(
		"Resource",
		"Stored",
		"Capacity",
		"Production",
		"Consumption",
		"Decay",
		"Net"
	)
	
	# Style header
	for child in header.get_children():
		if child is Label:
			child.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	
	resource_list.add_child(header)
	
	# Separator
	var sep = HSeparator.new()
	resource_list.add_child(sep)

func add_resource_row(resource_id: String):
	var name_label = Registry.get_name_label("resource", resource_id)
	var stored = current_city.get_total_resource(resource_id)
	var capacity = current_city.get_total_storage_capacity(resource_id)
	var production = calculated_production.get(resource_id, 0.0)
	var consumption = calculated_consumption.get(resource_id, 0.0)
	var decay = calculated_decay.get(resource_id, 0.0)
	var net = production - consumption - decay
	
	var row = create_resource_row(
		name_label,
		"%.1f" % stored,
		"%.0f" % capacity if capacity > 0 else "-",
		"%+.1f" % production if production > 0 else "-",
		"-%.1f" % consumption if consumption > 0 else "-",
		"-%.1f" % decay if decay > 0 else "-",
		"%+.1f" % net if net != 0 else "0"
	)
	
	# Color code the net value
	var net_label = row.get_child(6) as Label
	if net_label:
		if net > 0:
			net_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
		elif net < 0:
			net_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5))
	
	# Color production green
	var prod_label = row.get_child(3) as Label
	if prod_label and production > 0:
		prod_label.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6))
	
	# Color consumption red
	var cons_label = row.get_child(4) as Label
	if cons_label and consumption > 0:
		cons_label.add_theme_color_override("font_color", Color(0.85, 0.6, 0.6))
	
	# Color decay orange
	var decay_label = row.get_child(5) as Label
	if decay_label and decay > 0:
		decay_label.add_theme_color_override("font_color", Color(0.85, 0.7, 0.5))
	
	# Highlight row if storage is getting full or empty
	if capacity > 0:
		var fill_ratio = stored / capacity
		if fill_ratio >= 0.9:
			# Storage almost full - might spill
			for child in row.get_children():
				if child is Label:
					child.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
		elif stored > 0 and fill_ratio <= 0.1 and net < 0:
			# Storage almost empty and draining
			for child in row.get_children():
				if child is Label:
					child.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
	
	resource_list.add_child(row)

func add_totals_row():
	var sep = HSeparator.new()
	resource_list.add_child(sep)
	
	# Calculate totals
	var total_prod = 0.0
	var total_cons = 0.0
	var total_decay = 0.0
	
	for amount in calculated_production.values():
		total_prod += amount
	
	for amount in calculated_consumption.values():
		total_cons += amount
	
	for amount in calculated_decay.values():
		total_decay += amount
	
	var total_net = total_prod - total_cons - total_decay
	
	var row = create_resource_row(
		"TOTALS",
		"-",
		"-",
		"%+.1f" % total_prod if total_prod > 0 else "-",
		"-%.1f" % total_cons if total_cons > 0 else "-",
		"-%.1f" % total_decay if total_decay > 0 else "-",
		"%+.1f" % total_net if total_net != 0 else "0"
	)
	
	# Style totals row
	for child in row.get_children():
		if child is Label:
			child.add_theme_color_override("font_color", Color(0.9, 0.9, 0.7))
	
	resource_list.add_child(row)

func create_resource_row(name: String, stored: String, capacity: String, 
						 production: String, consumption: String,
						 decay: String, net: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	
	add_label(row, name, 150, true)  # Name is left-aligned
	add_label(row, stored, 80)
	add_label(row, capacity, 80)
	add_label(row, production, 80)
	add_label(row, consumption, 80)
	add_label(row, decay, 80)
	add_label(row, net, 80)
	
	return row

func add_label(container: Container, text: String, min_width: float, align_left: bool = false):
	var label = Label.new()
	label.text = text
	label.custom_minimum_size.x = min_width
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if align_left else HORIZONTAL_ALIGNMENT_RIGHT
	container.add_child(label)

func _on_close_pressed():
	hide_panel()
