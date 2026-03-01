extends CanvasLayer
class_name GameMenuDialog

signal closed
signal save_requested(save_name: String, save_id: String)

var dimmer: ColorRect
var panel: PanelContainer
var save_panel: PanelContainer
var load_panel: PanelContainer
var name_input: LineEdit
var save_list: ItemList
var is_open: bool = false

# Reference to world node (set by World.gd)
var world_node: Node = null

func _ready():
	layer = 90
	visible = false

	# Dimmer background
	dimmer = ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.5)
	dimmer.gui_input.connect(_on_dimmer_input)
	add_child(dimmer)

	# Main menu panel
	panel = _create_panel()
	add_child(panel)

	# Save sub-panel (hidden by default)
	save_panel = _create_save_panel()
	add_child(save_panel)

	# Load sub-panel (hidden by default)
	load_panel = _create_load_panel()
	add_child(load_panel)

func _create_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "MenuPanel"
	p.custom_minimum_size = Vector2(280, 0)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = -140
	p.offset_right = 140
	p.offset_top = -130
	p.offset_bottom = 130

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.border_color = Color(0.4, 0.4, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	p.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	p.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Game Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Button style
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.2, 0.28, 0.9)
	btn_style.border_color = Color(0.35, 0.35, 0.45)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(4)
	btn_style.set_content_margin_all(8)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.3, 0.3, 0.4, 0.95)
	btn_hover.border_color = Color(0.5, 0.5, 0.6)
	btn_hover.set_border_width_all(1)
	btn_hover.set_corner_radius_all(4)
	btn_hover.set_content_margin_all(8)

	# Save World
	var save_btn := _styled_button("Save World", btn_style, btn_hover)
	save_btn.pressed.connect(_on_save_pressed)
	vbox.add_child(save_btn)

	# Load World
	var load_btn := _styled_button("Load World", btn_style, btn_hover)
	load_btn.pressed.connect(_on_load_pressed)
	vbox.add_child(load_btn)

	# Main Menu
	var menu_btn := _styled_button("Main Menu", btn_style, btn_hover)
	menu_btn.pressed.connect(_on_main_menu_pressed)
	vbox.add_child(menu_btn)

	# Exit
	var exit_btn := _styled_button("Exit", btn_style, btn_hover)
	exit_btn.pressed.connect(_on_exit_pressed)
	vbox.add_child(exit_btn)

	return p

func _create_save_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "SavePanel"
	p.visible = false
	p.custom_minimum_size = Vector2(350, 0)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = -175
	p.offset_right = 175
	p.offset_top = -80
	p.offset_bottom = 80

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.border_color = Color(0.4, 0.4, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	p.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	p.add_child(vbox)

	var title := Label.new()
	title.text = "Save Game"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var label := Label.new()
	label.text = "Enter a name for this save:"
	label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(label)

	name_input = LineEdit.new()
	name_input.placeholder_text = "My Save"
	name_input.max_length = 64
	name_input.text_submitted.connect(func(_t): _on_save_confirmed())
	vbox.add_child(name_input)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(80, 32)
	cancel_btn.pressed.connect(_on_save_cancel)
	btn_row.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "Save"
	confirm_btn.custom_minimum_size = Vector2(80, 32)
	confirm_btn.pressed.connect(_on_save_confirmed)
	btn_row.add_child(confirm_btn)

	return p

func _create_load_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "LoadPanel"
	p.visible = false
	p.custom_minimum_size = Vector2(420, 300)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = -210
	p.offset_right = 210
	p.offset_top = -150
	p.offset_bottom = 150

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.border_color = Color(0.4, 0.4, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	p.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	p.add_child(vbox)

	var title := Label.new()
	title.text = "Load Game"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var label := Label.new()
	label.text = "Select a saved game:"
	label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(label)

	save_list = ItemList.new()
	save_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	save_list.allow_reselect = true
	save_list.item_activated.connect(func(_idx): _on_load_confirmed())
	vbox.add_child(save_list)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(80, 32)
	cancel_btn.pressed.connect(_on_load_cancel)
	btn_row.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "Load"
	confirm_btn.custom_minimum_size = Vector2(80, 32)
	confirm_btn.pressed.connect(_on_load_confirmed)
	btn_row.add_child(confirm_btn)

	return p

func _styled_button(text: String, normal: StyleBoxFlat, hover: StyleBoxFlat) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 36)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_font_size_override("font_size", 15)
	return btn

func open_menu():
	is_open = true
	visible = true
	panel.visible = true
	save_panel.visible = false
	load_panel.visible = false

func close_menu():
	is_open = false
	visible = false
	panel.visible = false
	save_panel.visible = false
	load_panel.visible = false
	closed.emit()

func _on_dimmer_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Only close if neither sub-panel is open
		if not save_panel.visible and not load_panel.visible:
			close_menu()

func _unhandled_input(event: InputEvent):
	if not is_open:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if save_panel.visible:
			_on_save_cancel()
		elif load_panel.visible:
			_on_load_cancel()
		else:
			close_menu()
		get_viewport().set_input_as_handled()

# === Save ===

func _on_save_pressed():
	panel.visible = false
	save_panel.visible = true
	# Default name based on current turn
	var turn: int = 1
	if world_node and world_node.turn_manager:
		turn = world_node.turn_manager.current_turn
	name_input.text = "Save - Turn %d" % turn
	name_input.select_all()
	name_input.grab_focus()

func _on_save_confirmed():
	var save_name: String = name_input.text.strip_edges()
	if save_name.is_empty():
		save_name = "Save"

	var save_id: String = _sanitize_save_id(save_name)
	var base_id: String = save_id
	var counter: int = 2
	while DirAccess.dir_exists_absolute("user://saves/%s" % save_id):
		save_id = "%s_%d" % [base_id, counter]
		counter += 1

	GameState.save_id = save_id
	GameState.save_display_name = save_name

	if world_node:
		world_node.save_game()

	close_menu()

func _on_save_cancel():
	save_panel.visible = false
	panel.visible = true

func _sanitize_save_id(raw_name: String) -> String:
	var result: String = raw_name.to_lower().strip_edges()
	result = result.replace(" ", "_")
	var clean: String = ""
	for i in result.length():
		var c: String = result[i]
		var code: int = c.unicode_at(0)
		if (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95:
			clean += c
	if clean.is_empty():
		clean = "save"
	return clean

# === Load ===

func _on_load_pressed():
	var saves: Array[Dictionary] = _find_saves()
	if saves.is_empty():
		# Show a brief message then return to menu
		save_list.clear()
		save_list.add_item("No saved games found.")
		panel.visible = false
		load_panel.visible = true
		return

	save_list.clear()
	for save in saves:
		var display: String = save.display_name
		if save.current_turn > 0:
			display += "  (Turn %d)" % save.current_turn
		if not save.timestamp.is_empty():
			display += "  -  %s" % _format_timestamp(save.timestamp)
		save_list.add_item(display)
		save_list.set_item_metadata(save_list.item_count - 1, save.save_id)

	save_list.select(0)
	panel.visible = false
	load_panel.visible = true

func _on_load_confirmed():
	var selected: PackedInt32Array = save_list.get_selected_items()
	if selected.is_empty():
		return
	var meta = save_list.get_item_metadata(selected[0])
	if meta == null:
		return  # "No saves" placeholder
	var save_id: String = meta
	close_menu()
	GameState.load_game(save_id)
	get_tree().change_scene_to_file("res://scenes/GameRoot.tscn")

func _on_load_cancel():
	load_panel.visible = false
	panel.visible = true

func _find_saves() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var saves_path: String = "user://saves"
	if not DirAccess.dir_exists_absolute(saves_path):
		return results

	var dir: DirAccess = DirAccess.open(saves_path)
	if not dir:
		return results

	dir.list_dir_begin()
	var folder: String = dir.get_next()
	while folder != "":
		if dir.current_is_dir() and folder != "." and folder != "..":
			var meta_path: String = "%s/%s/meta.json" % [saves_path, folder]
			if FileAccess.file_exists(meta_path):
				var meta_file: FileAccess = FileAccess.open(meta_path, FileAccess.READ)
				var meta: Variant = JSON.parse_string(meta_file.get_as_text())
				meta_file.close()
				if meta is Dictionary:
					results.append({
						"save_id": folder,
						"display_name": meta.get("display_name", folder),
						"current_turn": meta.get("current_turn", 0),
						"timestamp": meta.get("timestamp", ""),
					})
		folder = dir.get_next()
	dir.list_dir_end()

	results.sort_custom(func(a, b): return a.timestamp > b.timestamp)
	return results

func _format_timestamp(ts: String) -> String:
	if ts.length() < 16:
		return ts
	var date_part: String = ts.substr(0, 10)
	var time_part: String = ts.substr(11, 5)
	return "%s %s" % [date_part, time_part]

# === Main Menu / Exit ===

func _on_main_menu_pressed():
	close_menu()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_exit_pressed():
	get_tree().quit()
