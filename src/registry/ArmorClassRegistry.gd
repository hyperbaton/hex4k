extends RefCounted
class_name ArmorClassRegistry

# Registry for armor class definitions - loaded from data/armor_classes/

var armor_classes: Dictionary = {}  # armor_class_id -> data

func load_data():
	var dir_path = "res://data/armor_classes"
	var dir = DirAccess.open(dir_path)
	if not dir:
		push_error("ArmorClassRegistry: Cannot open directory: " + dir_path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var armor_id = file_name.trim_suffix(".json")
			var file_path = dir_path + "/" + file_name
			var data = _load_json_file(file_path)
			if not data.is_empty():
				armor_classes[armor_id] = data
				print("  Loaded armor class: ", armor_id)
		file_name = dir.get_next()

	dir.list_dir_end()
	print("ArmorClassRegistry: Loaded %d armor classes" % armor_classes.size())

func _load_json_file(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("ArmorClassRegistry: Cannot open file: " + path)
		return {}

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("ArmorClassRegistry: JSON parse error in %s: %s" % [path, json.get_error_message()])
		return {}

	return json.data

func get_armor_class(armor_class_id: String) -> Dictionary:
	"""Get the full armor class definition by ID"""
	return armor_classes.get(armor_class_id, {})

func get_defenses(armor_class_id: String) -> Array:
	"""Get the defenses array for an armor class"""
	var data = get_armor_class(armor_class_id)
	return data.get("defenses", [])

func get_matching_defenses(armor_class_id: String, attack_type: String) -> Array:
	"""Get defenses that include the given attack_type"""
	var matching: Array = []
	for defense in get_defenses(armor_class_id):
		var attack_types = defense.get("attack_types", [])
		if attack_type in attack_types:
			matching.append(defense)
	return matching

func armor_class_exists(armor_class_id: String) -> bool:
	return armor_classes.has(armor_class_id)
