extends Control
class_name NewGameScreen

## New Game setup screen: origin selection, seed input, start button.
## Shown after clicking "New Game" on the main menu.

var origin_list: ItemList
var origin_description: RichTextLabel
var seed_input: LineEdit
var start_button: Button
var back_button: Button

var _origin_ids: Array[String] = []
var _selected_origin_id: String = "default"

func _ready():
	_build_ui()
	_populate_origins()

func _build_ui():
	# Main layout: full screen panel
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "New Game"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Content: two columns (origin list | description)
	var content := HSplitContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.split_offset = 300
	vbox.add_child(content)

	# Left column: origin list
	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 8)
	content.add_child(left_vbox)

	var origin_label := Label.new()
	origin_label.text = "Select Origin"
	origin_label.add_theme_font_size_override("font_size", 18)
	left_vbox.add_child(origin_label)

	origin_list = ItemList.new()
	origin_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	origin_list.allow_reselect = false
	origin_list.item_selected.connect(_on_origin_selected)
	left_vbox.add_child(origin_list)

	# Right column: description + settings
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 12)
	content.add_child(right_vbox)

	var desc_label := Label.new()
	desc_label.text = "Origin Details"
	desc_label.add_theme_font_size_override("font_size", 18)
	right_vbox.add_child(desc_label)

	origin_description = RichTextLabel.new()
	origin_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	origin_description.bbcode_enabled = true
	origin_description.scroll_following = false
	right_vbox.add_child(origin_description)

	# Seed row
	var seed_hbox := HBoxContainer.new()
	seed_hbox.add_theme_constant_override("separation", 8)
	right_vbox.add_child(seed_hbox)

	var seed_label := Label.new()
	seed_label.text = "World Seed:"
	seed_hbox.add_child(seed_label)

	seed_input = LineEdit.new()
	seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_input.placeholder_text = "Random"
	seed_input.text = str(randi())
	seed_hbox.add_child(seed_input)

	var random_button := Button.new()
	random_button.text = "Random"
	random_button.pressed.connect(_on_random_seed)
	seed_hbox.add_child(random_button)

	# Bottom buttons
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	button_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(button_row)

	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(120, 40)
	back_button.pressed.connect(_on_back)
	button_row.add_child(back_button)

	start_button = Button.new()
	start_button.text = "Start Game"
	start_button.custom_minimum_size = Vector2(160, 40)
	start_button.pressed.connect(_on_start_game)
	button_row.add_child(start_button)

func _populate_origins():
	"""Load all origins into the list"""
	origin_list.clear()
	_origin_ids.clear()

	var all_ids := Registry.origins.get_all_origin_ids()
	# Sort: put "default" first, then alphabetical
	all_ids.sort()
	if "default" in all_ids:
		all_ids.erase("default")
		all_ids.insert(0, "default")

	for origin_id in all_ids:
		var origin_data: Dictionary = Registry.origins.get_origin(origin_id)
		var display_name: String = Registry.localization.get_name("origin", origin_id)
		if display_name.is_empty() or display_name == origin_id:
			display_name = origin_id.capitalize()

		# Show tags as suffix
		var tags: Array = origin_data.get("tags", [])
		var tag_text := ""
		if not tags.is_empty():
			tag_text = "  [%s]" % ", ".join(tags)

		origin_list.add_item(display_name + tag_text)
		_origin_ids.append(origin_id)

	# Select the first item (default)
	if origin_list.item_count > 0:
		origin_list.select(0)
		_on_origin_selected(0)

func _on_origin_selected(index: int):
	"""Update the description panel when an origin is selected"""
	if index < 0 or index >= _origin_ids.size():
		return

	_selected_origin_id = _origin_ids[index]
	var origin_data: Dictionary = Registry.origins.get_origin(_selected_origin_id)

	var display_name: String = Registry.localization.get_name("origin", _selected_origin_id)
	if display_name.is_empty() or display_name == _selected_origin_id:
		display_name = _selected_origin_id.capitalize()

	var description: String = Registry.localization.get_description("origin", _selected_origin_id)
	if description.is_empty():
		description = "No description available."

	# Build details text
	var text := "[b]%s[/b]\n\n%s\n\n" % [display_name, description]

	# Starting units
	var units: Array = origin_data.get("units", [])
	if not units.is_empty():
		text += "[b]Starting Units:[/b]\n"
		for unit_entry in units:
			var unit_type: String = unit_entry.get("unit_type", "")
			var unit_name: String = Registry.localization.get_name("unit", unit_type)
			if unit_name.is_empty() or unit_name == unit_type:
				unit_name = unit_type.capitalize()
			text += "  • %s\n" % unit_name
		text += "\n"

	# Starting tech
	var tech: Dictionary = origin_data.get("tech", {})
	var milestones: Array = tech.get("milestones", [])
	if not milestones.is_empty():
		text += "[b]Starting Technology:[/b]\n"
		for milestone_id in milestones:
			var ms_name: String = Registry.localization.get_name("milestone", milestone_id)
			if ms_name.is_empty() or ms_name == milestone_id:
				ms_name = milestone_id.capitalize()
			text += "  • %s\n" % ms_name
		text += "\n"

	# Starting settlements
	var settlements: Array = origin_data.get("settlements", [])
	if not settlements.is_empty():
		text += "[b]Starting Settlements:[/b]\n"
		for settlement in settlements:
			var stype: String = settlement.get("settlement_type", "")
			var sname: String = settlement.get("name", stype.capitalize())
			text += "  • %s (%s)\n" % [sname, stype]
		text += "\n"

	# Perks
	var perks: Array = origin_data.get("perks", [])
	if not perks.is_empty():
		text += "[b]Starting Perks:[/b]\n"
		for perk_id in perks:
			var perk_name: String = Registry.localization.get_name("perk", perk_id)
			if perk_name.is_empty() or perk_name == perk_id:
				perk_name = perk_id.capitalize()
			text += "  • %s\n" % perk_name
		text += "\n"

	# Tags
	var tags: Array = origin_data.get("tags", [])
	if not tags.is_empty():
		text += "[color=gray]Tags: %s[/color]\n" % ", ".join(tags)

	origin_description.text = text

func _on_random_seed():
	seed_input.text = str(randi())

func _on_start_game():
	var seed_value: int = 0
	if seed_input.text.is_empty():
		seed_value = randi()
	elif seed_input.text.is_valid_int():
		seed_value = seed_input.text.to_int()
	else:
		# Use string hash as seed
		seed_value = seed_input.text.hash()

	GameState.start_new_game(seed_value, _selected_origin_id)
	get_tree().change_scene_to_file("res://scenes/GameRoot.tscn")

func _on_back():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
