extends PanelContainer
class_name TradeRoutePanel

# Panel showing trade routes for a city.
# Displays route details, convoy counts, throughput, and resource allocations.
# Accessible from the city overlay.

signal route_selected(route_id: String)
signal create_route_requested(city_id: String)
signal closed

var city: City = null
var trade_route_manager: TradeRouteManager = null
var city_manager: CityManager = null
var unit_manager: UnitManager = null

# UI elements
var title_label: Label
var route_list: VBoxContainer
var capacity_label: Label
var create_route_button: Button
var close_button: Button
var no_routes_label: Label

func _ready():
	_setup_ui()
	hide()

func _setup_ui():
	custom_minimum_size = Vector2(500, 420)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 1.0)
	style.border_color = Color(0.4, 0.35, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	add_child(main_vbox)

	# Title row
	var title_hbox = HBoxContainer.new()
	main_vbox.add_child(title_hbox)

	title_label = Label.new()
	title_label.text = "Trade Routes"
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(title_label)

	close_button = Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(32, 32)
	close_button.pressed.connect(_on_close_pressed)
	title_hbox.add_child(close_button)

	main_vbox.add_child(HSeparator.new())

	# Capacity info
	capacity_label = Label.new()
	capacity_label.add_theme_font_size_override("font_size", 13)
	capacity_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	main_vbox.add_child(capacity_label)

	# Scrollable route list
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 220
	main_vbox.add_child(scroll)

	route_list = VBoxContainer.new()
	route_list.add_theme_constant_override("separation", 8)
	route_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(route_list)

	# No routes message
	no_routes_label = Label.new()
	no_routes_label.text = "No active trade routes.\nUse convoy units with Explore Route to mark paths between cities."
	no_routes_label.add_theme_font_size_override("font_size", 13)
	no_routes_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	no_routes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_routes_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	no_routes_label.visible = false
	route_list.add_child(no_routes_label)

	# Bottom buttons
	var button_hbox = HBoxContainer.new()
	button_hbox.add_theme_constant_override("separation", 10)
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(button_hbox)

	create_route_button = Button.new()
	create_route_button.text = "Create New Route"
	create_route_button.custom_minimum_size = Vector2(160, 36)
	create_route_button.pressed.connect(_on_create_route_pressed)
	button_hbox.add_child(create_route_button)

func open(p_city: City, p_trade_route_manager: TradeRouteManager, p_city_manager: CityManager, p_unit_manager: UnitManager = null):
	"""Open the panel for a specific city."""
	city = p_city
	trade_route_manager = p_trade_route_manager
	city_manager = p_city_manager
	unit_manager = p_unit_manager

	title_label.text = "%s - Trade Routes" % city.city_name
	refresh()
	show()

func refresh():
	"""Refresh the panel contents."""
	if not city or not trade_route_manager:
		return

	# Update capacity
	var total_capacity = trade_route_manager.get_city_trade_route_capacity(city.city_id)
	var used = trade_route_manager.get_used_trade_route_count(city.city_id)
	var convoy_cap = trade_route_manager.get_city_convoy_capacity(city.city_id)
	var convoy_used = trade_route_manager.get_used_convoy_count(city.city_id)
	capacity_label.text = "Route Slots: %d / %d | Convoy Slots: %d / %d" % [
		used, total_capacity, convoy_used, convoy_cap
	]

	# Enable/disable create button
	create_route_button.disabled = (used >= total_capacity)

	# Clear existing entries
	for child in route_list.get_children():
		if child != no_routes_label:
			child.queue_free()

	var routes = trade_route_manager.get_routes_for_city(city.city_id)

	if routes.is_empty():
		no_routes_label.visible = true
		return

	no_routes_label.visible = false

	for route in routes:
		var entry = _create_route_entry(route)
		route_list.add_child(entry)

func _create_route_entry(route: TradeRoute) -> PanelContainer:
	"""Create a panel entry for a single trade route."""
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14)
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.28, 0.22)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Route header: city names
	var city_a = city_manager.get_city(route.city_a_id)
	var city_b = city_manager.get_city(route.city_b_id)
	var city_a_name = city_a.city_name if city_a else route.city_a_id
	var city_b_name = city_b.city_name if city_b else route.city_b_id

	var header = HBoxContainer.new()
	vbox.add_child(header)

	var name_label = Label.new()
	name_label.text = "%s ↔ %s" % [city_a_name, city_b_name]
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)

	var unit_type_label = Label.new()
	unit_type_label.text = Registry.units.get_unit_name(route.unit_type)
	unit_type_label.add_theme_font_size_override("font_size", 11)
	unit_type_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	header.add_child(unit_type_label)

	# Stats row
	var stats_label = Label.new()
	stats_label.text = "Dist: %d | Convoys: %d | Throughput: %.1f/turn" % [
		route.distance, route.convoys.size(), route.total_throughput
	]
	stats_label.add_theme_font_size_override("font_size", 11)
	stats_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vbox.add_child(stats_label)

	# Allocations
	if not route.allocations.is_empty():
		var alloc_label = Label.new()
		var alloc_parts: Array[String] = []
		for alloc in route.allocations:
			var dir_str = "→" if alloc.direction == "a_to_b" else "←"
			var res_name = Registry.get_name_label("resource", alloc.resource_id)
			alloc_parts.append("%.1f %s %s" % [alloc.amount, res_name, dir_str])
		alloc_label.text = "Transfers: " + ", ".join(alloc_parts)
		alloc_label.add_theme_font_size_override("font_size", 11)
		alloc_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
		vbox.add_child(alloc_label)

	# Action buttons
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 6)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_hbox)

	var details_btn = Button.new()
	details_btn.text = "Details"
	details_btn.custom_minimum_size = Vector2(70, 28)
	details_btn.pressed.connect(func(): emit_signal("route_selected", route.route_id))
	btn_hbox.add_child(details_btn)

	var remove_btn = Button.new()
	remove_btn.text = "Remove"
	remove_btn.custom_minimum_size = Vector2(70, 28)
	remove_btn.pressed.connect(_on_remove_route.bind(route.route_id))
	btn_hbox.add_child(remove_btn)

	return panel

func _on_create_route_pressed():
	if city:
		emit_signal("create_route_requested", city.city_id)

func _on_remove_route(route_id: String):
	if trade_route_manager:
		trade_route_manager.remove_route(route_id)
		refresh()

func _on_close_pressed():
	close()

func close():
	city = null
	hide()
	emit_signal("closed")
