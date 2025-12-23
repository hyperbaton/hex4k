extends RefCounted
class_name ModifierRegistry

var modifiers := {}  # Dictionary<String, Dictionary>

func load_data():
	var dir = DirAccess.open("res://data/modifiers")
	if not dir:
		push_error("Failed to open modifiers directory")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".json"):
			var modifier_id = file_name.trim_suffix(".json")
			var modifier_data = _load_modifier_file("res://data/modifiers/" + file_name)
			
			if modifier_data:
				modifiers[modifier_id] = modifier_data
				print("Loaded modifier: ", modifier_id)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	print("Loaded %d modifiers" % modifiers.size())

func _load_modifier_file(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open modifier file: " + path)
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	
	if error != OK:
		push_error("Failed to parse modifier JSON: " + path)
		return {}
	
	return json.data

func get_modifier(id: String) -> Dictionary:
	return modifiers.get(id, {})

func has_modifier(id: String) -> bool:
	return modifiers.has(id)

func get_all_modifier_ids() -> Array:
	return modifiers.keys()
