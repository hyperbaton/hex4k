extends PanelContainer
class_name CityHeader

# Top bar showing city info

signal clicked

@onready var city_name_label := $HBoxContainer/CityName
@onready var population_display := $HBoxContainer/PopulationDisplay
@onready var resources_container := $HBoxContainer/ResourcesContainer

var current_city: City

# Cache for loaded textures
static var icon_cache: Dictionary = {}

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
	
	# Get resource data
	var resource_data = Registry.resources.get_resource(resource_id)
	var icon_path = ""
	if resource_data.has("visual") and resource_data.visual.has("icon"):
		icon_path = resource_data.visual.icon
	
	# Icon
	var icon_container = TextureRect.new()
	icon_container.custom_minimum_size = Vector2(24, 24)
	icon_container.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_container.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	
	# Try to load icon texture
	var texture = load_resource_icon(icon_path, resource_id)
	if texture:
		icon_container.texture = texture
	else:
		# Fallback to colored rect
		var fallback = ColorRect.new()
		fallback.custom_minimum_size = Vector2(24, 24)
		fallback.color = get_resource_color(resource_id)
		display.add_child(fallback)
		icon_container.queue_free()
		icon_container = null
	
	if icon_container:
		display.add_child(icon_container)
	
	# Amount text
	var label = Label.new()
	label.text = "%.0f" % amount
	label.add_theme_font_size_override("font_size", 14)
	display.add_child(label)
	
	# Set up tooltip
	var resource_name = Registry.get_name_label("resource", resource_id)
	display.tooltip_text = "%s\n%.0f / %.0f" % [resource_name, amount, capacity]
	display.mouse_filter = Control.MOUSE_FILTER_STOP
	
	resources_container.add_child(display)

func load_resource_icon(icon_path: String, resource_id: String) -> Texture2D:
	"""Load and cache resource icon"""
	if icon_path == "":
		return null
	
	# Check cache first
	if icon_cache.has(resource_id):
		return icon_cache[resource_id]
	
	# Try to load
	if ResourceLoader.exists(icon_path):
		var texture = load(icon_path)
		if texture:
			icon_cache[resource_id] = texture
			return texture
	
	return null

func get_resource_color(resource_id: String) -> Color:
	var resource = Registry.resources.get_resource(resource_id)
	if resource.has("visual") and resource.visual.has("color"):
		return Color(resource.visual.color)
	return Color.WHITE

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("clicked")
		accept_event()
