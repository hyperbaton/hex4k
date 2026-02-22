extends PanelContainer
class_name TradeRouteDetailsPanel

# Detail panel for managing a single trade route.
# Shows convoy list (with remove) and resource allocation management.

signal closed
signal route_changed  # Emitted when convoys or allocations change

var route: TradeRoute = null
var trade_route_manager: TradeRouteManager = null
var city_manager: CityManager = null
var unit_manager: UnitManager = null

# UI references
var title_label: Label
var stats_label: Label
var convoy_list: VBoxContainer
var allocation_list: VBoxContainer
var remaining_label: Label
var resource_selector: OptionButton
var amount_spin: SpinBox
var direction_selector: OptionButton
var add_button: Button

# Cached city names for direction labels
var _city_a_name: String = ""
var _city_b_name: String = ""

func _ready():
	_setup_ui()
	hide()

func _setup_ui():
	custom_minimum_size = Vector2(520, 480)

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
	title_label.text = "Route Details"
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(title_label)

	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.pressed.connect(_on_close_pressed)
	title_hbox.add_child(close_btn)

	main_vbox.add_child(HSeparator.new())

	# Stats row
	stats_label = Label.new()
	stats_label.add_theme_font_size_override("font_size", 13)
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	main_vbox.add_child(stats_label)

	# Scrollable content
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 280
	main_vbox.add_child(scroll)

	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 10)
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_vbox)

	# === Convoys Section ===
	var convoy_header = Label.new()
	convoy_header.name = "ConvoyHeader"
	convoy_header.text = "Convoys"
	convoy_header.add_theme_font_size_override("font_size", 15)
	convoy_header.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	content_vbox.add_child(convoy_header)

	convoy_list = VBoxContainer.new()
	convoy_list.add_theme_constant_override("separation", 4)
	content_vbox.add_child(convoy_list)

	content_vbox.add_child(HSeparator.new())

	# === Allocations Section ===
	var alloc_header = Label.new()
	alloc_header.text = "Resource Allocations"
	alloc_header.add_theme_font_size_override("font_size", 15)
	alloc_header.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	content_vbox.add_child(alloc_header)

	remaining_label = Label.new()
	remaining_label.add_theme_font_size_override("font_size", 12)
	remaining_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.6))
	content_vbox.add_child(remaining_label)

	# Add allocation row
	var add_row = HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 6)
	content_vbox.add_child(add_row)

	resource_selector = OptionButton.new()
	resource_selector.custom_minimum_size.x = 120
	resource_selector.add_theme_font_size_override("font_size", 12)
	add_row.add_child(resource_selector)

	amount_spin = SpinBox.new()
	amount_spin.min_value = 0.5
	amount_spin.max_value = 100.0
	amount_spin.step = 0.5
	amount_spin.value = 1.0
	amount_spin.custom_minimum_size.x = 80
	add_row.add_child(amount_spin)

	direction_selector = OptionButton.new()
	direction_selector.custom_minimum_size.x = 140
	direction_selector.add_theme_font_size_override("font_size", 12)
	add_row.add_child(direction_selector)

	add_button = Button.new()
	add_button.text = "Add"
	add_button.custom_minimum_size = Vector2(50, 28)
	add_button.pressed.connect(_on_add_allocation_pressed)
	add_row.add_child(add_button)

	# Existing allocations list
	allocation_list = VBoxContainer.new()
	allocation_list.add_theme_constant_override("separation", 4)
	content_vbox.add_child(allocation_list)

	# Bottom close button
	main_vbox.add_child(HSeparator.new())
	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(bottom_hbox)

	var bottom_close = Button.new()
	bottom_close.text = "Close"
	bottom_close.custom_minimum_size = Vector2(100, 36)
	bottom_close.pressed.connect(_on_close_pressed)
	bottom_hbox.add_child(bottom_close)

func open(p_route: TradeRoute, p_trade_route_manager: TradeRouteManager,
		p_city_manager: CityManager, p_unit_manager: UnitManager):
	"""Open the details panel for a specific route."""
	route = p_route
	trade_route_manager = p_trade_route_manager
	city_manager = p_city_manager
	unit_manager = p_unit_manager

	# Cache city names
	var city_a = city_manager.get_city(route.city_a_id)
	var city_b = city_manager.get_city(route.city_b_id)
	_city_a_name = city_a.city_name if city_a else route.city_a_id
	_city_b_name = city_b.city_name if city_b else route.city_b_id

	title_label.text = "%s ↔ %s" % [_city_a_name, _city_b_name]

	refresh()
	show()

func refresh():
	"""Rebuild all dynamic content."""
	if not route:
		return

	# Stats
	stats_label.text = "Dist: %d | Throughput: %.1f/turn | Allocated: %.1f/turn" % [
		route.distance, route.total_throughput, route.get_total_allocated()
	]

	_refresh_convoys()
	_refresh_allocations()
	_refresh_add_row()

func _refresh_convoys():
	"""Rebuild the convoy list."""
	for child in convoy_list.get_children():
		child.queue_free()

	# Update header text
	var header = find_child("ConvoyHeader") as Label
	if header:
		header.text = "Convoys (%d)" % route.convoys.size()

	if route.convoys.is_empty():
		var empty = Label.new()
		empty.text = "No convoys assigned"
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		convoy_list.add_child(empty)
		return

	for convoy in route.convoys:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		convoy_list.add_child(row)

		# Unit display name
		var unit = unit_manager.get_unit(convoy.unit_id) if unit_manager else null
		var display_name: String
		if unit:
			display_name = "%s (%s)" % [unit.get_display_name(), convoy.unit_id]
		else:
			display_name = "%s (%s)" % [Registry.units.get_unit_name(route.unit_type), convoy.unit_id]

		var name_label = Label.new()
		name_label.text = display_name
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		# Cargo capacity
		var cap_label = Label.new()
		cap_label.text = "cap: %d" % convoy.cargo_capacity
		cap_label.add_theme_font_size_override("font_size", 11)
		cap_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		row.add_child(cap_label)

		# Remove button
		var remove_btn = Button.new()
		remove_btn.text = "Remove"
		remove_btn.custom_minimum_size = Vector2(65, 24)
		remove_btn.pressed.connect(_on_remove_convoy.bind(convoy.unit_id))
		row.add_child(remove_btn)

func _refresh_allocations():
	"""Rebuild the allocation list."""
	for child in allocation_list.get_children():
		child.queue_free()

	remaining_label.text = "Remaining throughput: %.1f/turn" % route.get_remaining_throughput()

	if route.allocations.is_empty():
		var empty = Label.new()
		empty.text = "No allocations configured"
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		allocation_list.add_child(empty)
		return

	for alloc in route.allocations:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		allocation_list.add_child(row)

		# Resource name
		var res_name = Registry.get_name_label("resource", alloc.resource_id)
		var name_label = Label.new()
		name_label.text = res_name
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.custom_minimum_size.x = 80
		row.add_child(name_label)

		# Amount
		var amt_label = Label.new()
		amt_label.text = "%.1f/turn" % alloc.amount
		amt_label.add_theme_font_size_override("font_size", 12)
		amt_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
		amt_label.custom_minimum_size.x = 70
		row.add_child(amt_label)

		# Direction
		var dir_label = Label.new()
		if alloc.direction == "a_to_b":
			dir_label.text = "%s → %s" % [_city_a_name, _city_b_name]
		else:
			dir_label.text = "%s → %s" % [_city_b_name, _city_a_name]
		dir_label.add_theme_font_size_override("font_size", 11)
		dir_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		dir_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(dir_label)

		# Remove button
		var remove_btn = Button.new()
		remove_btn.text = "✕"
		remove_btn.custom_minimum_size = Vector2(28, 24)
		remove_btn.pressed.connect(_on_remove_allocation.bind(alloc.resource_id, alloc.direction))
		row.add_child(remove_btn)

func _refresh_add_row():
	"""Update the resource dropdown and direction selector."""
	resource_selector.clear()
	direction_selector.clear()

	# Populate tradeable resources that exist in either city
	var city_a = city_manager.get_city(route.city_a_id)
	var city_b = city_manager.get_city(route.city_b_id)
	var tradeable = Registry.resources.get_resources_by_tag("tradeable")

	for resource_id in tradeable:
		var has_stock := false
		if city_a and city_a.get_total_resource(resource_id) > 0:
			has_stock = true
		if city_b and city_b.get_total_resource(resource_id) > 0:
			has_stock = true
		# Also show resources that are already allocated (even if stock is 0 now)
		for alloc in route.allocations:
			if alloc.resource_id == resource_id:
				has_stock = true
				break
		if has_stock:
			resource_selector.add_item(Registry.get_name_label("resource", resource_id))
			resource_selector.set_item_metadata(resource_selector.item_count - 1, resource_id)

	# Direction options
	direction_selector.add_item("%s → %s" % [_city_a_name, _city_b_name])
	direction_selector.set_item_metadata(0, "a_to_b")
	direction_selector.add_item("%s → %s" % [_city_b_name, _city_a_name])
	direction_selector.set_item_metadata(1, "b_to_a")

	# Clamp spin box max to remaining throughput
	var remaining = route.get_remaining_throughput()
	amount_spin.max_value = max(0.5, remaining)
	amount_spin.value = min(amount_spin.value, amount_spin.max_value)

	# Disable add if no throughput or no resources
	add_button.disabled = (remaining < 0.01 or resource_selector.item_count == 0)

# === Actions ===

func _on_remove_convoy(unit_id: String):
	if not trade_route_manager or not route:
		return
	trade_route_manager.unassign_convoy(route.route_id, unit_id)
	refresh()
	emit_signal("route_changed")

func _on_add_allocation_pressed():
	if not route or resource_selector.selected < 0 or direction_selector.selected < 0:
		return

	var resource_id: String = resource_selector.get_item_metadata(resource_selector.selected)
	var amount: float = amount_spin.value
	var direction: String = direction_selector.get_item_metadata(direction_selector.selected)

	if amount <= 0:
		return

	# Clamp to remaining throughput
	var remaining = route.get_remaining_throughput()
	amount = min(amount, remaining)

	trade_route_manager.set_allocation(route.route_id, resource_id, amount, direction)
	refresh()
	emit_signal("route_changed")

func _on_remove_allocation(resource_id: String, direction: String):
	if not trade_route_manager or not route:
		return
	trade_route_manager.remove_allocation(route.route_id, resource_id, direction)
	refresh()
	emit_signal("route_changed")

func _on_close_pressed():
	close()

func close():
	route = null
	hide()
	emit_signal("closed")

func _input(event: InputEvent):
	if visible and event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			_on_close_pressed()
			get_viewport().set_input_as_handled()
