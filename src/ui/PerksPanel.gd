extends CanvasLayer
class_name PerksPanel

# Full-screen panel showing all civilization perks and their status.
# Follows the TechTreeScreen pattern (CanvasLayer, built in code).

signal closed

const BACKGROUND_COLOR = Color(0.12, 0.14, 0.22, 0.97)
const CARD_UNLOCKED_COLOR = Color(0.18, 0.25, 0.18)
const CARD_LOCKED_COLOR = Color(0.15, 0.15, 0.18)
const CARD_BORDER_UNLOCKED = Color(0.4, 0.7, 0.4)
const CARD_BORDER_LOCKED = Color(0.3, 0.3, 0.35)
const CATEGORY_COLORS = {
	"economic": Color(0.9, 0.75, 0.3),
	"cultural": Color(0.6, 0.5, 0.9),
	"military": Color(0.9, 0.4, 0.4),
	"scientific": Color(0.4, 0.7, 0.9)
}

var is_open := false
var player: Player = null

# UI elements
var background: ColorRect
var root_control: Control
var scroll_container: ScrollContainer
var grid_container: GridContainer
var close_button: Button
var title_label: Label

func _ready():
	layer = 100  # Above everything
	_create_ui()
	hide_panel()
	process_mode = Node.PROCESS_MODE_DISABLED

func _create_ui():
	# Root control
	root_control = Control.new()
	root_control.name = "Root"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_control)

	# Background
	background = ColorRect.new()
	background.name = "Background"
	background.color = BACKGROUND_COLOR
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(background)

	# Main vertical layout
	var main_vbox = VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.offset_left = 40
	main_vbox.offset_right = -40
	main_vbox.offset_top = 30
	main_vbox.offset_bottom = -30
	main_vbox.add_theme_constant_override("separation", 16)
	root_control.add_child(main_vbox)

	# Header row
	var header = HBoxContainer.new()
	header.name = "Header"
	main_vbox.add_child(header)

	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "Civilization Perks"
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "✕ Close"
	close_button.custom_minimum_size = Vector2(100, 36)
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)

	# Separator
	var sep = HSeparator.new()
	main_vbox.add_child(sep)

	# Scroll container
	scroll_container = ScrollContainer.new()
	scroll_container.name = "ScrollContainer"
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll_container)

	# Grid container for perk cards
	grid_container = GridContainer.new()
	grid_container.name = "PerkGrid"
	grid_container.columns = 3
	grid_container.add_theme_constant_override("h_separation", 16)
	grid_container.add_theme_constant_override("v_separation", 16)
	grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(grid_container)

func show_panel(p_player: Player = null):
	"""Show the perks panel for the given player."""
	player = p_player
	is_open = true
	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_refresh_cards()

func hide_panel():
	"""Hide the perks panel."""
	is_open = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED

func _on_close_pressed():
	hide_panel()
	closed.emit()

func _input(event: InputEvent):
	if not is_open:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func _refresh_cards():
	"""Rebuild all perk cards."""
	# Clear existing cards
	for child in grid_container.get_children():
		child.queue_free()

	# Get all perks and sort: unlocked first, then alphabetical
	var all_ids = Registry.perks.get_all_perk_ids()
	var unlocked_ids: Array[String] = []
	var locked_ids: Array[String] = []

	for perk_id in all_ids:
		if player and player.has_perk(perk_id):
			unlocked_ids.append(perk_id)
		else:
			locked_ids.append(perk_id)

	unlocked_ids.sort()
	locked_ids.sort()

	for perk_id in unlocked_ids:
		grid_container.add_child(_create_perk_card(perk_id, true))

	for perk_id in locked_ids:
		grid_container.add_child(_create_perk_card(perk_id, false))

func _create_perk_card(perk_id: String, is_unlocked: bool) -> PanelContainer:
	"""Create a single perk card widget."""
	var perk = Registry.perks.get_perk(perk_id)
	var category = perk.get("category", "economic")

	# Card container
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(320, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style = StyleBoxFlat.new()
	style.bg_color = CARD_UNLOCKED_COLOR if is_unlocked else CARD_LOCKED_COLOR
	style.border_color = CARD_BORDER_UNLOCKED if is_unlocked else CARD_BORDER_LOCKED
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", style)

	# Card content
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	# Header: name + category badge + unlock status
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	# Unlock icon
	var status_label = Label.new()
	if is_unlocked:
		status_label.text = "✓"
		status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	else:
		status_label.text = "✗"
		status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	status_label.add_theme_font_size_override("font_size", 18)
	header.add_child(status_label)

	# Perk name
	var name_label = Label.new()
	name_label.text = Registry.perks.get_perk_name(perk_id)
	name_label.add_theme_font_size_override("font_size", 16)
	if is_unlocked:
		name_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8))
	else:
		name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)

	# Category badge
	var cat_label = Label.new()
	cat_label.text = category.capitalize()
	cat_label.add_theme_font_size_override("font_size", 12)
	var cat_color = CATEGORY_COLORS.get(category, Color(0.6, 0.6, 0.6))
	if not is_unlocked:
		cat_color = cat_color.darkened(0.4)
	cat_label.add_theme_color_override("font_color", cat_color)
	header.add_child(cat_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = Registry.get_description("perk", perk_id)
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_unlocked:
		desc_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	else:
		desc_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	vbox.add_child(desc_label)

	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Effects section
	var effects_label = Label.new()
	effects_label.text = _format_effects(perk)
	effects_label.add_theme_font_size_override("font_size", 12)
	effects_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_unlocked:
		effects_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
	else:
		effects_label.add_theme_color_override("font_color", Color(0.45, 0.5, 0.5))
	vbox.add_child(effects_label)

	# Conditions section (only show for locked perks)
	if not is_unlocked:
		var cond_sep = HSeparator.new()
		vbox.add_child(cond_sep)

		var cond_label = Label.new()
		cond_label.text = _format_conditions(perk)
		cond_label.add_theme_font_size_override("font_size", 11)
		cond_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cond_label.add_theme_color_override("font_color", Color(0.55, 0.5, 0.4))
		vbox.add_child(cond_label)

	return card

func _format_effects(perk: Dictionary) -> String:
	"""Format perk effects into readable text."""
	var lines: Array[String] = []
	var effects = perk.get("effects", {})

	# Building modifiers
	var building_mods = effects.get("building_modifiers", {})
	for building_id in building_mods.keys():
		var mods = building_mods[building_id]
		var bname = Registry.get_name_label("building", building_id)
		var parts: Array[String] = []
		if mods.has("production_multiplier") and mods.production_multiplier != 1.0:
			var pct = int((mods.production_multiplier - 1.0) * 100)
			if pct > 0:
				parts.append("+%d%% production" % pct)
			else:
				parts.append("%d%% production" % pct)
		if mods.has("construction_cost_multiplier") and mods.construction_cost_multiplier != 1.0:
			var pct = int((1.0 - mods.construction_cost_multiplier) * 100)
			if pct > 0:
				parts.append("-%d%% build cost" % pct)
			else:
				parts.append("+%d%% build cost" % abs(pct))
		if not parts.is_empty():
			lines.append("%s: %s" % [bname, ", ".join(parts)])

	# Global yield bonuses
	var global_yields = effects.get("yield_bonuses", {}).get("global", {})
	for res_id in global_yields.keys():
		var amount = global_yields[res_id]
		if amount != 0:
			var rname = Registry.get_name_label("resource", res_id)
			lines.append("+%s %s (global)" % [str(amount), rname])

	# Per-terrain yield bonuses
	var per_terrain = effects.get("yield_bonuses", {}).get("per_terrain_type", {})
	for terrain_id in per_terrain.keys():
		var yields = per_terrain[terrain_id]
		var tname = Registry.get_name_label("terrain", terrain_id)
		for res_id in yields.keys():
			var amount = yields[res_id]
			if amount != 0:
				var rname = Registry.get_name_label("resource", res_id)
				lines.append("+%s %s on %s" % [str(amount), rname, tname])

	# Admin distance modifier
	var admin_mod = effects.get("admin_distance_multiplier_modifier", 0.0)
	if admin_mod != 0.0:
		if admin_mod < 0:
			lines.append("%.0f%% admin distance cost" % (admin_mod * 100))
		else:
			lines.append("+%.0f%% admin distance cost" % (admin_mod * 100))

	# Unique buildings
	var unique = effects.get("unlocks_unique_buildings", [])
	for bid in unique:
		var bname = Registry.get_name_label("building", bid)
		lines.append("Unlocks: %s" % bname)

	# Tech branch
	var branch = effects.get("unlocks_tech_branch", null)
	if branch and branch is String and branch != "":
		var bname = Registry.get_name_label("tech_branch", branch)
		lines.append("Unlocks branch: %s" % bname)

	if lines.is_empty():
		return "No effects"
	return "\n".join(lines)

func _format_conditions(perk: Dictionary) -> String:
	"""Format perk unlock conditions into readable text."""
	var lines: Array[String] = []
	var conditions = perk.get("unlock_conditions", [])

	for cond in conditions:
		var type = cond.get("type", "")
		match type:
			"turn":
				var parts: Array[String] = []
				if cond.has("min"):
					parts.append("after turn %d" % cond.min)
				if cond.has("max"):
					parts.append("before turn %d" % cond.max)
				if not parts.is_empty():
					lines.append("Turn: %s" % ", ".join(parts))
			"milestone_unlocked":
				var mname = Registry.get_name_label("milestone", cond.get("milestone", ""))
				lines.append("Requires: %s" % mname)
			"milestone_locked":
				var mname = Registry.get_name_label("milestone", cond.get("milestone", ""))
				lines.append("Blocked by: %s" % mname)
			"building_count":
				var bname = Registry.get_name_label("building", cond.get("building", ""))
				if cond.has("min"):
					lines.append("Own %d+ %s" % [cond.min, bname])
			"tiles_by_terrain":
				var tname = Registry.get_name_label("terrain", cond.get("terrain", ""))
				if cond.has("min"):
					lines.append("Own %d+ %s tiles" % [cond.min, tname])
			"tiles_by_modifier":
				var mname = Registry.get_name_label("modifier", cond.get("modifier", ""))
				if cond.has("min"):
					lines.append("Own %d+ %s tiles" % [cond.min, mname])
			"unit_count":
				var uname = Registry.get_name_label("unit", cond.get("unit", ""))
				if cond.has("min"):
					lines.append("Have %d+ %s" % [cond.min, uname])
			"resource_production":
				var rname = Registry.get_name_label("resource", cond.get("resource", ""))
				if cond.has("min"):
					lines.append("Produce %d+ %s/turn" % [cond.min, rname])
			"resource_stored":
				var rname = Registry.get_name_label("resource", cond.get("resource", ""))
				if cond.has("min"):
					lines.append("Store %d+ %s" % [cond.min, rname])
			"city_population":
				if cond.has("min"):
					lines.append("City with %d+ population" % cond.min)
			"total_population":
				if cond.has("min"):
					lines.append("Total population %d+" % cond.min)
			"city_count":
				if cond.has("min"):
					lines.append("Own %d+ cities" % cond.min)
			"total_tiles":
				if cond.has("min"):
					lines.append("Own %d+ tiles" % cond.min)

	# Exclusive_with
	var exclusive = perk.get("exclusive_with", [])
	for ex_id in exclusive:
		var pname = Registry.perks.get_perk_name(ex_id)
		lines.append("Exclusive with: %s" % pname)

	if lines.is_empty():
		return "No conditions"
	return "Requirements:\n" + "\n".join(lines)
