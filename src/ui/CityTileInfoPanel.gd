extends PanelContainer
class_name CityTileInfoPanel

# Left sidebar panel that displays tile and building information in city view

signal closed
signal building_action_requested(action: String, coord: Vector2i)  # action: "enable", "disable", "demolish"

var current_coord: Vector2i
var current_city: City
var world_query: WorldQuery

var title_label: Label
var terrain_section: PanelContainer
var building_section: PanelContainer
var actions_section: PanelContainer
var close_button: Button

# Action buttons
var enable_button: Button
var disable_button: Button
var demolish_button: Button

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
	
	# === Actions Section ===
	actions_section = _create_actions_section()
	content_vbox.add_child(actions_section)

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

func _create_actions_section() -> PanelContainer:
	"""Create the actions section with enable/disable/demolish buttons"""
	var panel = PanelContainer.new()
	panel.name = "ActionsSection"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.10)
	style.border_color = Color(0.25, 0.2, 0.2)
	style.border_width_top = 1
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
	accent_bar.color = Color(0.7, 0.45, 0.35)
	accent_bar.custom_minimum_size = Vector2(4, 0)
	header_hbox.add_child(accent_bar)
	
	# Section title
	var header_label = Label.new()
	header_label.name = "SectionTitle"
	header_label.text = "  ACTIONS"
	header_label.add_theme_font_size_override("font_size", 11)
	header_label.add_theme_color_override("font_color", Color(0.7, 0.45, 0.35))
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_label.custom_minimum_size = Vector2(0, 32)
	header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_hbox.add_child(header_label)
	
	# Content container with buttons
	var content_margin = MarginContainer.new()
	content_margin.name = "ContentMargin"
	content_margin.add_theme_constant_override("margin_left", SECTION_MARGIN)
	content_margin.add_theme_constant_override("margin_right", SECTION_MARGIN)
	content_margin.add_theme_constant_override("margin_top", 8)
	content_margin.add_theme_constant_override("margin_bottom", SECTION_MARGIN)
	vbox.add_child(content_margin)
	
	var buttons_vbox = VBoxContainer.new()
	buttons_vbox.name = "Content"
	buttons_vbox.add_theme_constant_override("separation", 8)
	content_margin.add_child(buttons_vbox)
	
	# Enable button
	enable_button = _create_action_button("Enable", Color(0.3, 0.7, 0.4), "Reactivate this building")
	enable_button.pressed.connect(_on_enable_pressed)
	buttons_vbox.add_child(enable_button)
	
	# Disable button
	disable_button = _create_action_button("Disable", Color(0.7, 0.6, 0.3), "Stop production and consumption")
	disable_button.pressed.connect(_on_disable_pressed)
	buttons_vbox.add_child(disable_button)
	
	# Demolish button
	demolish_button = _create_action_button("Demolish", Color(0.8, 0.35, 0.3), "Remove this building")
	demolish_button.pressed.connect(_on_demolish_pressed)
	buttons_vbox.add_child(demolish_button)
	
	return panel

func _create_action_button(text: String, color: Color, tooltip_text: String) -> Button:
	"""Create a styled action button"""
	var button = Button.new()
	button.text = text
	button.tooltip_text = tooltip_text
	button.custom_minimum_size = Vector2(0, 32)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Style the button
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.8)
	normal_style.border_color = color
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 0.9)
	hover_style.border_color = color
	hover_style.set_border_width_all(2)
	hover_style.set_corner_radius_all(4)
	button.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, 1.0)
	pressed_style.border_color = color
	pressed_style.set_border_width_all(2)
	pressed_style.set_corner_radius_all(4)
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	var disabled_style = StyleBoxFlat.new()
	disabled_style.bg_color = Color(0.15, 0.15, 0.15, 0.6)
	disabled_style.border_color = Color(0.3, 0.3, 0.3)
	disabled_style.set_border_width_all(1)
	disabled_style.set_corner_radius_all(4)
	button.add_theme_stylebox_override("disabled", disabled_style)
	
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color.lightened(0.2))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.4))
	
	return button

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
		_update_actions_section(city)
		actions_section.visible = true
	else:
		building_section.visible = false
		actions_section.visible = false
	
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
	
	# Show modifiers/features
	var modifiers = tile_view.get_modifiers()
	if not modifiers.is_empty():
		content.add_child(_create_separator())
		content.add_child(_create_subsection_label("Features"))
		
		for mod_id in modifiers:
			var mod_name = Registry.modifiers.get_modifier_name(mod_id)
			var mod_type = Registry.modifiers.get_modifier_type(mod_id)
			var mod_desc = Registry.modifiers.get_modifier_description(mod_id)
			
			# Choose icon and color based on modifier type
			var icon = "◆"
			var color = Color(0.7, 0.8, 0.6)
			
			match mod_type:
				"resource_deposit":
					icon = "💎"
					color = Color(0.8, 0.7, 0.5)
				"terrain_feature":
					icon = "🌿"
					color = Color(0.6, 0.8, 0.5)
				"yield_modifier":
					icon = "⬆"
					color = Color(0.5, 0.7, 0.9)
			
			content.add_child(_create_info_row(icon, mod_name, color))
			
			# Show description if available
			if mod_desc != "" and mod_desc != mod_name:
				var mod_desc_label = Label.new()
				mod_desc_label.text = "   " + mod_desc
				mod_desc_label.add_theme_font_size_override("font_size", 11)
				mod_desc_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
				mod_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				content.add_child(mod_desc_label)
	
	# Distance from city center
	var distance = tile_view.get_distance_from_center()
	if distance >= 0:
		content.add_child(_create_separator())
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
	
	# Calculate production bonuses from terrain, modifiers, and adjacency
	var bonuses = _calculate_building_bonuses(building_id, tile_view)
	
	# Production (base + bonuses)
	var production = Registry.buildings.get_production_per_turn(building_id)
	if not production.is_empty() or not bonuses.is_empty():
		content.add_child(_create_separator())
		content.add_child(_create_subsection_label("Production"))
		
		# Get all resource IDs that have production or bonuses
		var all_resources: Array[String] = []
		for res_id in production.keys():
			if not res_id in all_resources:
				all_resources.append(res_id)
		for res_id in bonuses.keys():
			if not res_id in all_resources:
				all_resources.append(res_id)
		
		for res_id in all_resources:
			var base_amount = production.get(res_id, 0.0)
			var bonus_amount = bonuses.get(res_id, 0.0)
			var res_name = Registry.localization.get_name("resource", res_id)
			
			if bonus_amount != 0:
				# Show base + bonus breakdown
				content.add_child(_create_resource_row_with_bonus(res_name, base_amount, bonus_amount))
			else:
				content.add_child(_create_resource_row(res_name, base_amount, true))
	
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

func _create_resource_row_with_bonus(resource_name: String, base_amount: float, bonus_amount: float) -> HBoxContainer:
	"""Create a row showing resource production with bonus breakdown"""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	
	var name_label = Label.new()
	name_label.text = resource_name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)
	
	var total = base_amount + bonus_amount
	var amount_label = Label.new()
	
	# Format: "+total (base +bonus)" or "+total (base -penalty)"
	var bonus_sign = "+" if bonus_amount >= 0 else ""
	if base_amount > 0:
		amount_label.text = "+%.1f (%.1f %s%.1f)" % [total, base_amount, bonus_sign, bonus_amount]
	else:
		# Pure bonus with no base production
		amount_label.text = "+%.1f (bonus)" % total
	
	amount_label.add_theme_font_size_override("font_size", 12)
	
	# Color based on total and bonus
	if bonus_amount > 0:
		amount_label.add_theme_color_override("font_color", Color(0.5, 0.95, 0.6))  # Bright green for positive bonus
	else:
		amount_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.4))  # Yellow-ish for negative bonus
	
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(amount_label)
	
	return hbox

func _calculate_building_bonuses(building_id: String, tile_view: TileView) -> Dictionary:
	"""Calculate production bonuses from terrain, modifiers, and adjacency"""
	var bonuses: Dictionary = {}
	
	if not world_query:
		return bonuses
	
	# Get terrain data for this tile
	var terrain_data = world_query.get_terrain_data(current_coord)
	if not terrain_data:
		return bonuses
	
	# 1. Terrain bonuses - bonus from being ON specific terrain
	var terrain_bonuses = Registry.buildings.get_terrain_bonuses(building_id)
	if terrain_bonuses.has(terrain_data.terrain_id):
		var terrain_yields = terrain_bonuses[terrain_data.terrain_id]
		for resource_id in terrain_yields.keys():
			bonuses[resource_id] = bonuses.get(resource_id, 0.0) + terrain_yields[resource_id]
	
	# 2. Modifier bonuses - bonus from modifiers ON this tile
	var modifier_bonuses = Registry.buildings.get_modifier_bonuses(building_id)
	for mod_id in terrain_data.modifiers:
		if modifier_bonuses.has(mod_id):
			var mod_yields = modifier_bonuses[mod_id]
			for resource_id in mod_yields.keys():
				bonuses[resource_id] = bonuses.get(resource_id, 0.0) + mod_yields[resource_id]
	
	# 3. Adjacency bonuses - bonus from adjacent terrain/buildings/modifiers
	var adjacency_bonuses = Registry.buildings.get_adjacency_bonuses(building_id)
	
	for bonus in adjacency_bonuses:
		var source_type = bonus.get("source_type", "")
		var source_id = bonus.get("source_id", "")
		var yields = bonus.get("yields", {})
		var radius = bonus.get("radius", 1)
		
		# Count matching adjacent sources
		var matching_count = _count_adjacent_sources(source_type, source_id, radius)
		
		if matching_count > 0:
			for resource_id in yields.keys():
				var bonus_per_source = yields[resource_id]
				bonuses[resource_id] = bonuses.get(resource_id, 0.0) + (bonus_per_source * matching_count)
	
	return bonuses

func _count_adjacent_sources(source_type: String, source_id: String, radius: int) -> int:
	"""Count how many matching sources are adjacent to the current tile"""
	var count = 0
	
	if not world_query:
		return count
	
	# Get all tiles within radius (excluding self)
	var neighbors = world_query.get_tiles_in_range(current_coord, 1, radius)
	
	for neighbor_coord in neighbors:
		var matched = false
		
		match source_type:
			"terrain":
				# Check terrain type
				var terrain_id = world_query.get_terrain_id(neighbor_coord)
				matched = (terrain_id == source_id)
			
			"modifier":
				# Check for modifier on tile
				var neighbor_data = world_query.get_terrain_data(neighbor_coord)
				if neighbor_data:
					matched = neighbor_data.has_modifier(source_id)
			
			"building":
				# Check for building
				if current_city and current_city.has_building(neighbor_coord):
					var neighbor_instance = current_city.get_building_instance(neighbor_coord)
					if neighbor_instance:
						matched = (neighbor_instance.building_id == source_id)
			
			"building_category":
				# Check for building category
				if current_city and current_city.has_building(neighbor_coord):
					var neighbor_instance = current_city.get_building_instance(neighbor_coord)
					if neighbor_instance:
						var neighbor_building = Registry.buildings.get_building(neighbor_instance.building_id)
						matched = (neighbor_building.get("category", "") == source_id)
			
			"river":
				# Check for river
				var neighbor_data = world_query.get_terrain_data(neighbor_coord)
				if neighbor_data:
					matched = neighbor_data.is_river
		
		if matched:
			count += 1
	
	return count

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

func _update_actions_section(city: City):
	"""Update the actions section based on building state"""
	var instance = city.get_building_instance(current_coord)
	if not instance:
		actions_section.visible = false
		return
	
	# Check if it's a city center (no actions allowed)
	if Registry.buildings.is_city_center(instance.building_id):
		actions_section.visible = false
		return
	
	# Check if under construction (no actions allowed)
	if instance.is_under_construction():
		actions_section.visible = false
		return
	
	# Update Enable button
	var can_enable = city.can_enable_building(current_coord)
	enable_button.visible = instance.is_disabled()
	enable_button.disabled = not can_enable.can_enable
	if can_enable.can_enable:
		enable_button.tooltip_text = "Reactivate this building"
	else:
		enable_button.tooltip_text = can_enable.reason
	
	# Update Disable button
	var can_disable = city.can_disable_building(current_coord)
	disable_button.visible = not instance.is_disabled()
	disable_button.disabled = not can_disable.can_disable
	if can_disable.can_disable:
		disable_button.tooltip_text = "Stop production and consumption"
	else:
		disable_button.tooltip_text = can_disable.reason
	
	# Update Demolish button
	var can_demolish = city.can_demolish_building(current_coord)
	demolish_button.visible = true
	demolish_button.disabled = not can_demolish.can_demolish
	
	# Build demolish tooltip with cost info
	var demolish_tooltip = "Remove this building"
	if not can_demolish.cost.is_empty():
		demolish_tooltip += "\nCost: "
		var cost_parts = []
		for res_id in can_demolish.cost.keys():
			var res_name = Registry.get_name_label("resource", res_id)
			cost_parts.append("%s x%.0f" % [res_name, can_demolish.cost[res_id]])
		demolish_tooltip += ", ".join(cost_parts)
	
	if not can_demolish.can_demolish:
		demolish_tooltip += "\n" + can_demolish.reason
	
	demolish_button.tooltip_text = demolish_tooltip

func _on_enable_pressed():
	"""Handle enable button click"""
	emit_signal("building_action_requested", "enable", current_coord)

func _on_disable_pressed():
	"""Handle disable button click"""
	emit_signal("building_action_requested", "disable", current_coord)

func _on_demolish_pressed():
	"""Handle demolish button click"""
	emit_signal("building_action_requested", "demolish", current_coord)

func _on_close_pressed():
	"""Handle close button click"""
	visible = false
	emit_signal("closed")

func hide_panel():
	"""Hide the panel"""
	visible = false

func refresh():
	"""Refresh the panel with current data"""
	if visible and current_city and world_query:
		show_tile(current_coord, current_city, world_query)
