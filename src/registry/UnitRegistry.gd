extends RefCounted
class_name UnitRegistry

var units := {}  # Dictionary<String, Dictionary>

func load_data():
	var dir = DirAccess.open("res://data/units")
	if not dir:
		push_error("Failed to open units directory")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".json"):
			var unit_id = file_name.trim_suffix(".json")
			var unit_data = _load_unit_file("res://data/units/" + file_name)
			
			if unit_data:
				units[unit_id] = unit_data
				print("Loaded unit: ", unit_id)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	print("Loaded %d units" % units.size())

func _load_unit_file(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open unit file: " + path)
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	
	if error != OK:
		push_error("Failed to parse unit JSON: " + path)
		return {}
	
	return json.data

func get_unit(id: String) -> Dictionary:
	return units.get(id, {})

func has_unit(id: String) -> bool:
	return units.has(id)

func get_all_unit_ids() -> Array:
	return units.keys()

func get_units_by_category(category: String) -> Array:
	var result := []
	for id in units.keys():
		var unit = units[id]
		if unit.get("category", "") == category:
			result.append(id)
	return result
