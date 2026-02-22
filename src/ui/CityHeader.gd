extends PanelContainer
class_name CityHeader

# Top bar showing city info

signal clicked

@onready var city_name_label := $HBoxContainer/CityName
@onready var population_display := $HBoxContainer/PopulationDisplay
@onready var resources_container := $HBoxContainer/ResourcesContainer

var current_city: City
var trade_route_manager: TradeRouteManager  # For trade route capacity display
var admin_display: HBoxContainer  # Admin capacity display
var trade_display: HBoxContainer  # Trade route capacity display
var convoy_display: HBoxContainer  # Convoy capacity display

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
	var pop_text = "%d / %d" % [current_city.get_total_population(), current_city.get_population_capacity()]
	population_display.get_node("Label").text = pop_text
	
	# Resources
	update_resources()
	
	# Admin capacity
	update_admin_display()

	# Trade route capacity
	update_trade_display()

	# Convoy capacity
	update_convoy_display()

func update_resources():
	# Clear existing resource displays
	for child in resources_container.get_children():
		child.queue_free()
	
	# Display resources that have storage in this city AND are unlocked
	for resource_id in Registry.resources.get_all_resource_ids():
		if not Registry.resources.has_tag(resource_id, "storable"):
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
	var used = current_city.get_cap_used("admin_capacity")
	var total = current_city.get_cap_available("admin_capacity")
	var available = current_city.get_cap_remaining("admin_capacity")
	
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

func update_trade_display():
	"""Update the trade route capacity display"""
	# Remove old display if it exists
	if trade_display and is_instance_valid(trade_display):
		trade_display.queue_free()
		trade_display = null

	if not current_city:
		return

	# Only show if city has any trade route capacity
	var total_capacity = current_city.get_trade_route_capacity()
	if total_capacity <= 0:
		return

	# Get used count from trade route manager
	var used: int = 0
	if trade_route_manager:
		used = trade_route_manager.get_used_trade_route_count(current_city.city_id)

	# Create new trade display
	trade_display = HBoxContainer.new()
	trade_display.add_theme_constant_override("separation", 4)

	# Separator
	trade_display.add_child(VSeparator.new())

	# Icon
	var icon_container = TextureRect.new()
	icon_container.custom_minimum_size = Vector2(24, 24)
	icon_container.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_container.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var icon_path = "res://assets/icons/trade_route_capacity.svg"
	if ResourceLoader.exists(icon_path):
		var texture = load(icon_path)
		if texture:
			icon_container.texture = texture
	trade_display.add_child(icon_container)

	# Label: used / total
	var label = Label.new()
	label.text = "%d / %d" % [used, total_capacity]
	label.add_theme_font_size_override("font_size", 14)

	# Color based on capacity
	var available = total_capacity - used
	if available <= 0:
		label.add_theme_color_override("font_color", Color.RED)
	elif available == 1:
		label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		label.add_theme_color_override("font_color", Color.WHITE)

	trade_display.add_child(label)

	# Tooltip
	trade_display.tooltip_text = "Trade Routes: %d / %d" % [used, total_capacity]
	trade_display.mouse_filter = Control.MOUSE_FILTER_STOP

	resources_container.add_child(trade_display)

func update_convoy_display():
	"""Update the convoy capacity display"""
	# Remove old display if it exists
	if convoy_display and is_instance_valid(convoy_display):
		convoy_display.queue_free()
		convoy_display = null

	if not current_city:
		return

	# Only show if city has any convoy capacity
	var total_capacity = current_city.get_convoy_capacity()
	if total_capacity <= 0:
		return

	# Get used count from trade route manager
	var used: int = 0
	if trade_route_manager:
		used = trade_route_manager.get_used_convoy_count(current_city.city_id)

	# Create new convoy display
	convoy_display = HBoxContainer.new()
	convoy_display.add_theme_constant_override("separation", 4)

	# Separator
	convoy_display.add_child(VSeparator.new())

	# Icon - reuse trade route icon but with a convoy label
	var icon_label = Label.new()
	icon_label.text = "Convoys"
	icon_label.add_theme_font_size_override("font_size", 12)
	icon_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	convoy_display.add_child(icon_label)

	# Label: used / total
	var label = Label.new()
	label.text = "%d / %d" % [used, total_capacity]
	label.add_theme_font_size_override("font_size", 14)

	# Color based on capacity
	var available = total_capacity - used
	if available <= 0:
		label.add_theme_color_override("font_color", Color.RED)
	elif available == 1:
		label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		label.add_theme_color_override("font_color", Color.WHITE)

	convoy_display.add_child(label)

	# Tooltip
	convoy_display.tooltip_text = "Convoy Slots: %d / %d" % [used, total_capacity]
	convoy_display.mouse_filter = Control.MOUSE_FILTER_STOP

	resources_container.add_child(convoy_display)

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
