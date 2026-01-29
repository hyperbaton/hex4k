extends PanelContainer
class_name ResourceDetailPanel

# Full-screen resource breakdown panel

signal closed

@onready var close_button := $MarginContainer/VBoxContainer/Header/CloseButton
@onready var resource_list := $MarginContainer/VBoxContainer/ScrollContainer/ResourceList

var current_city: City

func _ready():
	visible = false
	close_button.pressed.connect(_on_close_pressed)

func show_panel(city: City):
	current_city = city
	update_display()
	visible = true

func hide_panel():
	visible = false
	emit_signal("closed")

func update_display():
	# Clear existing list
	for child in resource_list.get_children():
		child.queue_free()
	
	if not current_city:
		return
	
	# Add header
	add_list_header()
	
	# Add each unlocked resource
	var all_resources = current_city.resources.get_all_resources()
	
	for resource_id in all_resources:
		# Skip resources that haven't been unlocked yet
		if not Registry.resources.is_resource_unlocked(resource_id):
			continue
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
		"Trade",
		"Decay",
		"Net"
	)
	header.add_theme_font_size_override("font_size", 14)
	resource_list.add_child(header)
	
	# Separator
	var sep = HSeparator.new()
	resource_list.add_child(sep)

func add_resource_row(resource_id: String):
	var name_label = Registry.get_name_label("resource", resource_id)
	var stored = current_city.resources.get_stored(resource_id)
	var capacity = current_city.resources.get_storage_capacity(resource_id)
	var production = current_city.resources.production.get(resource_id, 0.0)
	var consumption = current_city.resources.consumption.get(resource_id, 0.0)
	var trade = current_city.resources.get_trade_change(resource_id)
	var decay = current_city.resources.decay.get(resource_id, 0.0)
	var net = current_city.resources.get_net_change(resource_id)
	
	var row = create_resource_row(
		name_label,
		"%.1f" % stored,
		"%.1f" % capacity if capacity > 0 else "-",
		"%+.1f" % production if production != 0 else "-",
		"%.1f" % consumption if consumption != 0 else "-",
		"%+.1f" % trade if trade != 0 else "-",
		"%.1f" % decay if decay != 0 else "-",
		"%+.1f" % net
	)
	
	resource_list.add_child(row)

func add_totals_row():
	var sep = HSeparator.new()
	resource_list.add_child(sep)
	
	# Calculate totals
	var total_prod = 0.0
	var total_cons = 0.0
	
	for resource_id in current_city.resources.production.keys():
		total_prod += current_city.resources.production[resource_id]
	
	for resource_id in current_city.resources.consumption.keys():
		total_cons += current_city.resources.consumption[resource_id]
	
	var row = create_resource_row(
		"TOTALS",
		"-",
		"-",
		"%+.1f" % total_prod,
		"%.1f" % total_cons,
		"-",
		"-",
		"-"
	)
	
	var label = row as HBoxContainer
	if label:
		label.add_theme_font_size_override("font_size", 14)
	
	resource_list.add_child(row)

func create_resource_row(name: String, stored: String, capacity: String, 
						 production: String, consumption: String,
						 trade: String, decay: String, net: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	
	add_label(row, name, 150)
	add_label(row, stored, 80)
	add_label(row, capacity, 80)
	add_label(row, production, 80)
	add_label(row, consumption, 80)
	add_label(row, trade, 80)
	add_label(row, decay, 80)
	add_label(row, net, 80)
	
	return row

func add_label(container: Container, text: String, min_width: float):
	var label = Label.new()
	label.text = text
	label.custom_minimum_size.x = min_width
	container.add_child(label)

func _on_close_pressed():
	hide_panel()
