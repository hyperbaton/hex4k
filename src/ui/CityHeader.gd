extends PanelContainer
class_name CityHeader

# Top bar showing city info

signal clicked

@onready var city_name_label := $HBoxContainer/CityName
@onready var population_display := $HBoxContainer/PopulationDisplay
@onready var resources_container := $HBoxContainer/ResourcesContainer

var current_city: City
var admin_display: HBoxContainer  # Admin capacity display

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
	
	# City name (with abandoned indicator)
	if current_city.is_abandoned:
		city_name_label.text = current_city.city_name + " [ABANDONED]"
		city_name_label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4))
	else:
		city_name_label.text = current_city.city_name
		city_name_label.remove_theme_color_override("font_color")
	
	# Population
	var pop_text = "%d / %d" % [current_city.total_population, int(current_city.population_capacity)]
	population_display.get_node("Label").text = pop_text
	
	# Resources
	update_resources()
	
	# Admin capacity
	update_admin_display()

func update_resources():
	# Clear existing resource displays
	for child in resources_container.get_children():
		child.queue_free()
	
	# Display resources that have storage in this city AND are unlocked
	for resource_id in Registry.resources.get_all_resource_ids():
		if not Registry.resources.is_storable(resource_id):
			continue  # Skip non-storable resources for header
		
		# Skip resources that haven't been unlocked yet
		if not Registry.resources.is_resource_unlocked(resource_id):
			continue
		
		var stored = current_city.get_total_resource(resource_id)
		var capacity = current_city.get_total_storage_capacity(resource_id)
		
		if capacity > 0 or stored > 0:
			add_resource_display(resource_id, stored, capacity)

func update_admin_display():
	"""Update the administrative capacity display"""
	# Remove old display if it exists
	if admin_display and is_instance_valid(admin_display):
		admin_display.queue_free()
		admin_display = null
	
	# Create new admin display
	admin_display = HBoxContainer.new()
	admin_display.add_theme_constant_override("separation", 4)
	
	# Add separator
	var separator = VSeparator.new()
	admin_display.add_child(separator)
	
	# Icon - try to load admin_capacity icon
	var icon_container = TextureRect.new()
	icon_container.custom_minimum_size = Vector2(24, 24)
	icon_container.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_container.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	
	var icon_path = "res://assets/icons/admin_capacity.svg"
	if ResourceLoader.exists(icon_path):
		var texture = load(icon_path)
		if texture:
			icon_container.texture = texture
	admin_display.add_child(icon_container)
	
	# Admin text: used / total
	var used = current_city.admin_capacity_used
	var total = current_city.admin_capacity_available
	var available = current_city.get_available_admin_capacity()
	
	var label = Label.new()
	label.text = "%.1f / %.1f" % [used, total]
	label.add_theme_font_size_override("font_size", 14)
	
	# Color based on capacity status
	if available <= 0:
		label.add_theme_color_override("font_color", Color.RED)
	elif available < total * 0.2:
		label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		label.add_theme_color_override("font_color", Color.WHITE)
	
	admin_display.add_child(label)
	
	# Tooltip
	admin_display.tooltip_text = "Administrative Capacity\nUsed: %.1f\nTotal: %.1f\nAvailable: %.1f" % [used, total, available]
	admin_display.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Add to resources container (at the end)
	resources_container.add_child(admin_display)

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
