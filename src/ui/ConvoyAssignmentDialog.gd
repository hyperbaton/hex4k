extends PanelContainer
class_name ConvoyAssignmentDialog

# Dialog for assigning a convoy unit to a trade route.
# Opened via the "assign_convoy" ability when a trade unit is on a city.

signal convoy_assigned(route_id: String, unit: Unit)
signal dialog_closed

var unit: Unit = null
var city: City = null
var trade_route_manager: TradeRouteManager = null
var city_manager: CityManager = null

# UI elements
var title_label: Label
var route_list: VBoxContainer
var close_button: Button
var no_routes_label: Label

func _ready():
	_setup_ui()
	hide()

func _setup_ui():
	custom_minimum_size = Vector2(440, 360)

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
	title_label.text = "Assign to Trade Route"
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title_label)

	main_vbox.add_child(HSeparator.new())

	# Scrollable route list
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 200
	main_vbox.add_child(scroll)

	route_list = VBoxContainer.new()
	route_list.add_theme_constant_override("separation", 8)
	route_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(route_list)

	# No routes label (shown when no routes available)
	no_routes_label = Label.new()
	no_routes_label.text = "No trade routes available at this city."
	no_routes_label.add_theme_font_size_override("font_size", 14)
	no_routes_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4))
	no_routes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_routes_label.visible = false
	route_list.add_child(no_routes_label)

	# Close button
	close_button = Button.new()
	close_button.text = "Cancel"
	close_button.custom_minimum_size = Vector2(120, 36)
	close_button.pressed.connect(_on_close_pressed)
	main_vbox.add_child(close_button)

func open(p_unit: Unit, p_city: City, p_trade_route_manager: TradeRouteManager, p_city_manager: CityManager):
	"""Open the dialog for a convoy unit at a city."""
	unit = p_unit
	city = p_city
	trade_route_manager = p_trade_route_manager
	city_manager = p_city_manager

	title_label.text = "Assign %s to Route" % Registry.units.get_unit_name(unit.unit_type)

	_populate_routes()
	show()

func _populate_routes():
	"""Populate the route list with available routes."""
	# Clear existing entries (except no_routes_label)
	for child in route_list.get_children():
		if child != no_routes_label:
			child.queue_free()

	if not trade_route_manager or not city:
		no_routes_label.visible = true
		return

	var routes = trade_route_manager.get_routes_for_city(city.city_id)

	if routes.is_empty():
		no_routes_label.visible = true
		return

	no_routes_label.visible = false

	for route in routes:
		# Check unit type matches
		if route.unit_type != unit.unit_type:
			continue

		var entry = _create_route_entry(route)
		route_list.add_child(entry)

func _create_route_entry(route: TradeRoute) -> PanelContainer:
	"""Create a UI entry for a single route."""
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16)
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# Route info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	# City names
	var city_a = city_manager.get_city(route.city_a_id)
	var city_b = city_manager.get_city(route.city_b_id)
	var city_a_name = city_a.city_name if city_a else route.city_a_id
	var city_b_name = city_b.city_name if city_b else route.city_b_id

	var name_label = Label.new()
	name_label.text = "%s ↔ %s" % [city_a_name, city_b_name]
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	info_vbox.add_child(name_label)

	# Route details
	var detail_label = Label.new()
	detail_label.text = "Distance: %d | Convoys: %d | Throughput: %.1f/turn" % [
		route.distance, route.convoys.size(), route.total_throughput
	]
	detail_label.add_theme_font_size_override("font_size", 11)
	detail_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	info_vbox.add_child(detail_label)

	# Assign button
	var assign_btn = Button.new()
	assign_btn.text = "Assign"
	assign_btn.custom_minimum_size = Vector2(80, 32)
	assign_btn.pressed.connect(_on_assign_pressed.bind(route.route_id))
	hbox.add_child(assign_btn)

	return panel

func _on_assign_pressed(route_id: String):
	"""Handle clicking the Assign button for a route."""
	if not unit or not trade_route_manager:
		return

	var success = trade_route_manager.assign_convoy(route_id, unit)
	if success:
		print("✓ Assigned %s to route %s" % [unit.unit_id, route_id])
		emit_signal("convoy_assigned", route_id, unit)
	else:
		print("✗ Failed to assign %s to route %s" % [unit.unit_id, route_id])

	close()

func _on_close_pressed():
	close()

func close():
	unit = null
	city = null
	hide()
	emit_signal("dialog_closed")
