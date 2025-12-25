extends Control
class_name CityHeader

# Top bar showing city info

signal clicked

@onready var city_name_label := $HBoxContainer/CityName
@onready var population_display := $HBoxContainer/PopulationDisplay
@onready var resources_container := $HBoxContainer/ResourcesContainer

var current_city: City

func _ready():
	custom_minimum_size = Vector2(0, 60)

func set_city(city: City):
	current_city = city
	update_display()

func update_display():
	if not current_city:
		return
	
	# City name
	city_name_label.text = current_city.city_name
	
	# Population
	var pop_text = "%d / %d" % [current_city.total_population, int(current_city.population_capacity)]
	population_display.get_node("Label").text = pop_text
	
	# Resources
	update_resources()

func update_resources():
	# Clear existing resource displays
	for child in resources_container.get_children():
		child.queue_free()
	
	# Get all resources with storage or flow
	var all_resources = current_city.resources.get_all_resources()
	
	# Add display for each resource
	for resource_id in all_resources:
		if not Registry.resources.is_storable(resource_id):
			continue  # Skip flow resources for header
		
		var stored = current_city.resources.get_stored(resource_id)
		var capacity = current_city.resources.get_storage_capacity(resource_id)
		
		if capacity > 0 or stored > 0:
			add_resource_display(resource_id, stored, capacity)

func add_resource_display(resource_id: String, amount: float, capacity: float):
	var display = HBoxContainer.new()
	display.add_theme_constant_override("separation", 4)
	
	# Icon (placeholder)
	var icon = ColorRect.new()
	icon.custom_minimum_size = Vector2(24, 24)
	icon.color = get_resource_color(resource_id)
	display.add_child(icon)
	
	# Amount text
	var label = Label.new()
	label.text = "%.0f/%.0f" % [amount, capacity]
	label.add_theme_font_size_override("font_size", 14)
	display.add_child(label)
	
	resources_container.add_child(display)

func get_resource_color(resource_id: String) -> Color:
	var resource = Registry.resources.get_resource(resource_id)
	if resource.has("visual") and resource.visual.has("color"):
		return Color(resource.visual.color)
	return Color.WHITE

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("clicked")
		accept_event()
