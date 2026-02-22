extends PanelContainer
class_name TradeRouteCreationDialog

# Dialog for creating a new trade route from a city.
# Shows connectable cities and lets the player pick a destination and convoy type.

signal route_created(route: TradeRoute)
signal dialog_closed

var source_city_id: String = ""
var trade_route_manager: TradeRouteManager = null
var city_manager: CityManager = null

# UI elements
var title_label: Label
var unit_type_selector: OptionButton
var destination_list: VBoxContainer
var close_button: Button
var no_destinations_label: Label

# Available unit types for routes (convoy-capable)
var _available_unit_types: Array[String] = []

func _ready():
	_setup_ui()
	hide()

func _setup_ui():
	custom_minimum_size = Vector2(480, 400)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 1.0)
	style.border_color = Color(0.35, 0.4, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	add_child(main_vbox)

	# Title
	title_label = Label.new()
	title_label.text = "Create Trade Route"
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title_label)

	main_vbox.add_child(HSeparator.new())

	# Unit type selector
	var type_hbox = HBoxContainer.new()
	type_hbox.add_theme_constant_override("separation", 8)
	main_vbox.add_child(type_hbox)

	var type_label = Label.new()
	type_label.text = "Convoy Type:"
	type_label.add_theme_font_size_override("font_size", 14)
	type_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	type_hbox.add_child(type_label)

	unit_type_selector = OptionButton.new()
	unit_type_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unit_type_selector.item_selected.connect(_on_unit_type_changed)
	type_hbox.add_child(unit_type_selector)

	# Scrollable destination list
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 200
	main_vbox.add_child(scroll)

	destination_list = VBoxContainer.new()
	destination_list.add_theme_constant_override("separation", 8)
	destination_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(destination_list)

	# No destinations label
	no_destinations_label = Label.new()
	no_destinations_label.text = "No reachable cities found.\nMark a route with Explore Route first."
	no_destinations_label.add_theme_font_size_override("font_size", 13)
	no_destinations_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	no_destinations_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_destinations_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	no_destinations_label.visible = false
	destination_list.add_child(no_destinations_label)

	# Close button
	close_button = Button.new()
	close_button.text = "Cancel"
	close_button.custom_minimum_size = Vector2(120, 36)
	close_button.pressed.connect(_on_close_pressed)
	var btn_container = HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_child(close_button)
	main_vbox.add_child(btn_container)

func open(p_source_city_id: String, p_trade_route_manager: TradeRouteManager, p_city_manager: CityManager):
	"""Open the dialog to create a route from the given city."""
	source_city_id = p_source_city_id
	trade_route_manager = p_trade_route_manager
	city_manager = p_city_manager

	var source_city = city_manager.get_city(source_city_id)
	title_label.text = "Create Route from %s" % (source_city.city_name if source_city else source_city_id)

	_populate_unit_types()
	_refresh_destinations()
	show()

func _populate_unit_types():
	"""Populate the unit type selector with convoy-capable unit types."""
	unit_type_selector.clear()
	_available_unit_types.clear()

	# Find all unit types that have cargo_capacity
	for unit_id in Registry.units.get_all_unit_ids():
		var unit_data = Registry.units.get_unit(unit_id)
		var stats = unit_data.get("stats", {})
		if stats.get("cargo_capacity", 0) > 0:
			_available_unit_types.append(unit_id)
			unit_type_selector.add_item(Registry.units.get_unit_name(unit_id))

func _on_unit_type_changed(_index: int):
	_refresh_destinations()

func _refresh_destinations():
	"""Refresh the destination list based on selected unit type."""
	# Clear existing entries
	for child in destination_list.get_children():
		if child != no_destinations_label:
			child.queue_free()

	if _available_unit_types.is_empty() or not trade_route_manager:
		no_destinations_label.visible = true
		return

	var selected_idx = unit_type_selector.selected
	if selected_idx < 0 or selected_idx >= _available_unit_types.size():
		no_destinations_label.visible = true
		return

	var unit_type = _available_unit_types[selected_idx]
	var connectable = trade_route_manager.get_connectable_cities(source_city_id, unit_type)

	if connectable.is_empty():
		no_destinations_label.visible = true
		return

	no_destinations_label.visible = false

	for dest_info in connectable:
		var entry = _create_destination_entry(dest_info, unit_type)
		destination_list.add_child(entry)

func _create_destination_entry(dest_info: Dictionary, unit_type: String) -> PanelContainer:
	"""Create a UI entry for a connectable destination city."""
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.1)
	style.set_border_width_all(1)
	style.border_color = Color(0.25, 0.35, 0.25)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# Destination info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = dest_info.city_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	info_vbox.add_child(name_label)

	var detail_label = Label.new()
	detail_label.text = "Distance: %d tiles | Avg cost: %.1f" % [dest_info.distance, dest_info.avg_cost]
	detail_label.add_theme_font_size_override("font_size", 11)
	detail_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	info_vbox.add_child(detail_label)

	# Connect button
	var connect_btn = Button.new()
	connect_btn.text = "Connect"
	connect_btn.custom_minimum_size = Vector2(90, 32)
	connect_btn.pressed.connect(_on_connect_pressed.bind(dest_info.city_id, unit_type))
	hbox.add_child(connect_btn)

	return panel

func _on_connect_pressed(dest_city_id: String, unit_type: String):
	"""Handle clicking the Connect button."""
	if not trade_route_manager:
		return

	var source_city = city_manager.get_city(source_city_id)
	var owner_id = source_city.owner.player_id if source_city and source_city.owner else ""

	var route = trade_route_manager.create_route(source_city_id, dest_city_id, unit_type, owner_id)
	if route:
		print("✓ Trade route created: %s" % route.route_id)
		emit_signal("route_created", route)
		close()
	else:
		print("✗ Failed to create trade route")

func _on_close_pressed():
	close()

func close():
	source_city_id = ""
	hide()
	emit_signal("dialog_closed")
