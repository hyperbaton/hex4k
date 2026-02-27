extends Button

var save_dialog: ConfirmationDialog
var name_input: LineEdit

func _ready():
	self.pressed.connect(_on_save_pressed)
	_create_save_dialog()

func _create_save_dialog():
	save_dialog = ConfirmationDialog.new()
	save_dialog.title = "Save Game"
	save_dialog.ok_button_text = "Save"
	save_dialog.min_size = Vector2i(350, 0)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 8
	vbox.offset_top = 8
	vbox.offset_right = -8
	vbox.offset_bottom = -8

	var label: Label = Label.new()
	label.text = "Enter a name for this save:"
	vbox.add_child(label)

	name_input = LineEdit.new()
	name_input.placeholder_text = "My Save"
	name_input.max_length = 64
	vbox.add_child(name_input)

	save_dialog.add_child(vbox)
	save_dialog.confirmed.connect(_on_save_confirmed)
	name_input.text_submitted.connect(func(_t): _on_save_confirmed())

	add_child(save_dialog)

func _on_save_pressed():
	# Default name based on current turn
	var world_node = get_node("../../..")
	var turn: int = world_node.turn_manager.current_turn if world_node.turn_manager else 1
	name_input.text = "Save - Turn %d" % turn
	save_dialog.popup_centered()
	name_input.select_all()
	name_input.grab_focus()

func _on_save_confirmed():
	save_dialog.hide()
	var save_name: String = name_input.text.strip_edges()
	if save_name.is_empty():
		save_name = "Save"

	# Generate a filesystem-safe save_id from the name
	var save_id: String = _sanitize_save_id(save_name)

	# Ensure unique ID by appending a number if it already exists
	var base_id: String = save_id
	var counter: int = 2
	while DirAccess.dir_exists_absolute("user://saves/%s" % save_id):
		save_id = "%s_%d" % [base_id, counter]
		counter += 1

	GameState.save_id = save_id
	GameState.save_display_name = save_name

	var world_node = get_node("../../..")
	world_node.save_game()

func _sanitize_save_id(raw_name: String) -> String:
	"""Convert a display name to a safe directory name"""
	var result: String = raw_name.to_lower().strip_edges()
	result = result.replace(" ", "_")
	# Keep only ASCII letters, digits, and underscores
	var clean: String = ""
	for i in result.length():
		var c: String = result[i]
		var code: int = c.unicode_at(0)
		if (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95:
			clean += c
	if clean.is_empty():
		clean = "save"
	return clean
