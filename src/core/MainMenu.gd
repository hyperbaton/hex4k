extends Control

var load_dialog: ConfirmationDialog
var save_list: ItemList
var no_saves_dialog: AcceptDialog

func _ready():
	$ButtonContainer/ButtonNewGame.pressed.connect(_on_new_game)
	$ButtonContainer/ButtonLoadGame.pressed.connect(_on_load_game)
	$ButtonContainer/ButtonQuit.pressed.connect(_on_quit)

	$VersionLabel.text = GameConfig.VERSION

	_create_load_dialog()
	_create_no_saves_dialog()

func _create_load_dialog():
	load_dialog = ConfirmationDialog.new()
	load_dialog.title = "Load Game"
	load_dialog.ok_button_text = "Load"
	load_dialog.min_size = Vector2i(420, 300)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 8
	vbox.offset_top = 8
	vbox.offset_right = -8
	vbox.offset_bottom = -8

	var label: Label = Label.new()
	label.text = "Select a saved game:"
	vbox.add_child(label)

	save_list = ItemList.new()
	save_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	save_list.allow_reselect = true
	save_list.item_activated.connect(func(_idx): _on_load_confirmed())
	vbox.add_child(save_list)

	load_dialog.add_child(vbox)
	load_dialog.confirmed.connect(_on_load_confirmed)
	add_child(load_dialog)

func _create_no_saves_dialog():
	no_saves_dialog = AcceptDialog.new()
	no_saves_dialog.title = "No Saves Found"
	no_saves_dialog.dialog_text = "No saved games were found.\nStart a new game first!"
	no_saves_dialog.min_size = Vector2i(300, 0)
	add_child(no_saves_dialog)

func _on_new_game():
	GameState.start_new_game(randi())
	get_tree().change_scene_to_file("res://scenes/GameRoot.tscn")

func _on_quit():
	get_tree().quit()

func _on_load_game():
	var saves: Array[Dictionary] = _find_saves()
	if saves.is_empty():
		no_saves_dialog.popup_centered()
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
	load_dialog.popup_centered()

func _on_load_confirmed():
	var selected: PackedInt32Array = save_list.get_selected_items()
	if selected.is_empty():
		return
	var save_id: String = save_list.get_item_metadata(selected[0])
	load_dialog.hide()
	GameState.load_game(save_id)
	get_tree().change_scene_to_file("res://scenes/GameRoot.tscn")

func _find_saves() -> Array[Dictionary]:
	"""Scan user://saves/ for save directories with meta.json"""
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

	# Sort by timestamp descending (most recent first)
	results.sort_custom(func(a, b): return a.timestamp > b.timestamp)
	return results

func _format_timestamp(ts: String) -> String:
	"""Format '2026-01-15T14:30:00' into a friendlier string"""
	if ts.length() < 16:
		return ts
	# Extract date and time parts
	var date_part: String = ts.substr(0, 10)
	var time_part: String = ts.substr(11, 5)
	return "%s %s" % [date_part, time_part]
