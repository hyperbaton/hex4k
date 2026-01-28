extends PanelContainer
class_name CityTileInfoPanel

# Left sidebar panel that displays tile and building information in city view

signal closed

var current_coord: Vector2i
var current_city: City
var world_query: WorldQuery

var title_label: Label
var terrain_section: PanelContainer
var building_section: PanelContainer
var close_button: Button

const PANEL_WIDTH := 300
const SECTION_MARGIN := 12
const ITEM_SPACING := 6

func _ready():
	_setup_panel()
	visible = false

func _setup_panel():
	"""Create the panel UI structure as a left sidebar"""
	# Main panel style - dark semi-transparent background
	var main_style = StyleBoxFlat.new()
	main_style.bg_color = Color(0.08, 0.08, 0.10, 0.92)
	main_style.border_color = Color(0.25, 0.25, 0.30)
	main_style.border_width_right = 2
	main_style.set_content_margin_all(0)
	add_theme_stylebox_override("panel", main_style)
	
	# Fixed width, full height (will be set in show_tile)
	custom_minimum_size = Vector2(PANEL_WIDTH, 400)
	size = Vector2(PANEL_WIDTH, 600)
	
	# Main vertical container
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	add_child(main_vbox)
	
	# === Header Section ===
	var header_panel = _create_header_section()
	main_vbox.add_child(header_panel)
	
	# === Scroll container for content ===
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)
	
	var content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 0)
	scroll.add_child(content_vbox)
	
	# === Terrain Section ===
	terrain_section = _create_section("TERRAIN", Color(0.6, 0.55, 0.4))
	content_vbox.add_child(terrain_section)
	
	# === Building Section ===
	building_section = _create_section("BUILDING", Color(0.4, 0.55, 0.7))
	content_vbox.add_child(building_section)

func _create_header_section() -> PanelContainer:
	"""Create the header with title and close button"""
	var panel = PanelContainer.new()
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.border_width_bottom = 1
	style.set_content_margin_all(SECTION_MARGIN)
	panel.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	panel.add_child(hbox)
	
	title_label = Label.new()
	title_label.text = "Tile Info"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title_label)
	
	close_button = Button.new()
	close_button.text = "✕"
	close_button.add_theme_font_size_override("font_size", 14)
	close_button.custom_minimum_size = Vector2(28, 28)
	close_button.pressed.connect(_on_close_pressed)
	hbox.add_child(close_button)
	
	return panel

func _create_section(section_title: String, accent_color: Color) -> PanelContainer:
	"""Create a collapsible section with header"""
	var panel = PanelContainer.new()
	panel.name = section_title + "Section"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12)
	style.border_color = Color(0.2, 0.2, 0.25)
	style.border_width_bottom = 1
	style.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.name = "MainVBox"
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)
	
	# Section header with accent color bar
	var header_hbox = HBoxContainer.new()
	header_hbox.name = "Header"
	header_hbox.add_theme_constant_override("separation", 0)
	vbox.add_child(header_hbox)
	
	# Accent color bar
	var accent_bar = ColorRect.new()
	accent_bar.color = accent_color
	accent_bar.custom_minimum_size = Vector2(4, 0)
	header_hbox.add_child(accent_bar)
	
	# Section title
	var header_label = Label.new()
	header_label.name = "SectionTitle"
	header_label.text = "  " + section_title
	header_label.add_theme_font_size_override("font_size", 11)
	header_label.add_theme_color_override("font_color", accent_color)
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_label.custom_minimum_size = Vector2(0, 32)
	header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_hbox.add_child(header_label)
	
	# Content container
	var content = VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", ITEM_SPACING)
	
	var content_margin = MarginContainer.new()
	content_margin.name = "ContentMargin"
	content_margin.add_theme_constant_override("margin_left", SECTION_MARGIN)
	content_margin.add_theme_constant_override("margin_right", SECTION_MARGIN)
	content_margin.add_theme_constant_override("margin_top", 8)
	content_margin.add_theme_constant_override("margin_bottom", SECTION_MARGIN)
	content_margin.add_child(content)
	vbox.add_child(content_margin)
	
	return panel

func _get_section_content(section: PanelContainer) -> VBoxContainer:
	"""Get the content container from a section"""
	return section.get_node("MainVBox/ContentMargin/Content")

func show_tile(coord: Vector2i, city: City, p_world_query: WorldQuery):
	"""Show information about a tile"""
	current_coord = coord
	current_city = city
	world_query = p_world_query
	
	# Clear previous content
	_clear_section_content(terrain_section)
	_clear_section_content(building_section)
	
	# Get tile view
	var tile_view = world_query.get_tile_view(coord)
	if not tile_view:
		visible = false
		return
	
	# Update title
	title_label.text = "Tile (%d, %d)" % [coord.x, coord.y]
	
	# Populate terrain info
	_populate_terrain_info(tile_view)
	terrain_section.visible = true
	
	# Populate building info if present
	if tile_view.has_building():
		_populate_building_info(tile_view, city)
		building_section.visible = true
	else:
		building_section.visible = false
	
	# Position on left side of screen, full height with some margin
	var viewport_size = get_viewport().get_visible_rect().size
	var margin_top = 80  # Leave space for the city header
	var margin_bottom = 100  # Leave space for action menu
	position = Vector2(0, margin_top)
	size = Vector2(PANEL_WIDTH, viewport_size.y - margin_top - margin_bottom)
	
	visible = true

func _populate_terrain_info(tile_view: TileView):
	"""Populate the terrain section"""
	var content = _get_section_content(terrain_section)
	var terrain_id = tile_view.get_terrain_id()
	var terrain_name = Registry.localization.get_name("terrain", terrain_id)
	var terrain_desc = Registry.localization.get_description("terrain", terrain_id)
	
	# Terrain name
	var name_label = Label.new()
	name_label.text = terrain_name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	content.add_child(name_label)
	
	# Terrain description
	if terrain_desc != "":
		var desc_label = Label.new()
		desc_label.text = terrain_desc
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(desc_label)
	
	# Show river if applicable
	if tile_view.is_river():
		content.add_child(_create_info_row("🌊", "River", Color(0.4, 0.6, 0.9)))
	
	# Distance from city center
	var distance = tile_view.get_distance_from_center()
	if distance >= 0:
		content.add_child(_create_info_row("📍", "Distance: %d from center" % distance, Color(0.6, 0.6, 0.6)))

func _populate_building_info(tile_view: TileView, city: City):
	"""Populate the building section"""
	var content = _get_section_content(building_section)
	var building_id = tile_view.get_building_id()
	var building_name = Registry.localization.get_name("building", building_id)
	var building_desc = Registry.localization.get_description("building", building_id)
	
	# Building name
	var name_label = Label.new()
	name_label.text = building_name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.75, 0.88, 0.98))
	content.add_child(name_label)
	
	# Building description
	if building_desc != "":
		var desc_label = Label.new()
		desc_label.text = building_desc
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(desc_label)
	
	# Separator
	content.add_child(_create_separator())
	
	# Get building instance for status
	var instance = city.get_building_instance(current_coord)
	if instance:
		# Status row
		var status_text = _get_status_text(instance.status)
		var status_color = _get_status_color(instance.status)
		content.add_child(_create_info_row("◉", status_text, status_color))
		
		# Show turns remaining if under construction
		if instance.is_under_construction() and instance.turns_remaining > 0:
			content.add_child(_create_info_row("⏱", "%d turns remaining" % instance.turns_remaining, Color(0.8, 0.7, 0.4)))
	
	# Production
	var production = Registry.buildings.get_production_per_turn(building_id)
	if not production.is_empty():
		content.add_child(_create_separator())
		content.add_child(_create_subsection_label("Production"))
		for res_id in production.keys():
			var res_name = Registry.localization.get_name("resource", res_id)
			content.add_child(_create_resource_row(res_name, production[res_id], true))
	
	# Consumption
	var consumption = Registry.buildings.get_consumption_per_turn(building_id)
	if not consumption.is_empty():
		content.add_child(_create_separator())
		content.add_child(_create_subsection_label("Consumption"))
		for res_id in consumption.keys():
			var res_name = Registry.localization.get_name("resource", res_id)
			content.add_child(_create_resource_row(res_name, consumption[res_id], false))
	
	# Storage
	var storage = Registry.buildings.get_storage_provided(building_id)
	if not storage.is_empty():
		content.add_child(_create_separator())
		content.add_child(_create_subsection_label("Storage Capacity"))
		for res_id in storage.keys():
			var res_name = Registry.localization.get_name("resource", res_id)
			content.add_child(_create_capacity_row(res_name, storage[res_id]))
	
	# Other stats
	var admin_cap = Registry.buildings.get_admin_capacity(building_id)
	var pop_cap = Registry.buildings.get_population_capacity(building_id)
	
	if admin_cap > 0 or pop_cap > 0:
		content.add_child(_create_separator())
		content.add_child(_create_subsection_label("Provides"))
		
		if admin_cap > 0:
			content.add_child(_create_info_row("📋", "Admin capacity: +%.1f" % admin_cap, Color(0.7, 0.6, 0.9)))
		
		if pop_cap > 0:
			content.add_child(_create_info_row("🏠", "Housing: %d" % pop_cap, Color(0.8, 0.7, 0.6)))

func _create_info_row(icon: String, text: String, color: Color) -> HBoxContainer:
	"""Create a row with icon and text"""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	
	var icon_label = Label.new()
	icon_label.text = icon
	icon_label.add_theme_font_size_override("font_size", 12)
	icon_label.custom_minimum_size = Vector2(20, 0)
	hbox.add_child(icon_label)
	
	var text_label = Label.new()
	text_label.text = text
	text_label.add_theme_font_size_override("font_size", 12)
	text_label.add_theme_color_override("font_color", color)
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(text_label)
	
	return hbox

func _create_resource_row(resource_name: String, amount: float, is_production: bool) -> HBoxContainer:
	"""Create a row showing resource production/consumption"""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	
	var name_label = Label.new()
	name_label.text = resource_name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)
	
	var amount_label = Label.new()
	var sign = "+" if is_production else "-"
	amount_label.text = "%s%.1f" % [sign, amount]
	amount_label.add_theme_font_size_override("font_size", 12)
	amount_label.add_theme_color_override("font_color", Color(0.5, 0.85, 0.5) if is_production else Color(0.85, 0.5, 0.5))
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(amount_label)
	
	return hbox

func _create_capacity_row(resource_name: String, capacity: int) -> HBoxContainer:
	"""Create a row showing storage capacity"""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	
	var name_label = Label.new()
	name_label.text = resource_name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)
	
	var capacity_label = Label.new()
	capacity_label.text = str(capacity)
	capacity_label.add_theme_font_size_override("font_size", 12)
	capacity_label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.85))
	capacity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(capacity_label)
	
	return hbox

func _create_subsection_label(text: String) -> Label:
	"""Create a subsection header label"""
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	return label

func _create_separator() -> HSeparator:
	"""Create a visual separator"""
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	return sep

func _get_status_text(status: int) -> String:
	match status:
		BuildingInstance.Status.ACTIVE:
			return "Active"
		BuildingInstance.Status.EXPECTING_RESOURCES:
			return "Waiting for resources"
		BuildingInstance.Status.CONSTRUCTING:
			return "Under construction"
		BuildingInstance.Status.CONSTRUCTION_PAUSED:
			return "Construction paused"
		BuildingInstance.Status.DISABLED:
			return "Disabled"
		_:
			return "Unknown"

func _get_status_color(status: int) -> Color:
	match status:
		BuildingInstance.Status.ACTIVE:
			return Color(0.5, 0.9, 0.5)
		BuildingInstance.Status.EXPECTING_RESOURCES:
			return Color(0.9, 0.7, 0.3)
		BuildingInstance.Status.CONSTRUCTING:
			return Color(0.5, 0.7, 0.9)
		BuildingInstance.Status.CONSTRUCTION_PAUSED:
			return Color(0.9, 0.5, 0.3)
		BuildingInstance.Status.DISABLED:
			return Color(0.5, 0.5, 0.5)
		_:
			return Color(0.7, 0.7, 0.7)

func _clear_section_content(section: PanelContainer):
	"""Clear all children from a section's content"""
	var content = _get_section_content(section)
	for child in content.get_children():
		child.queue_free()

func _on_close_pressed():
	"""Handle close button click"""
	visible = false
	emit_signal("closed")

func hide_panel():
	"""Hide the panel"""
	visible = false
