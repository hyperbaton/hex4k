extends RefCounted
class_name ResourceRegistry

var resources := {}  # Dictionary<String, Dictionary>

func load_data():
	var dir = DirAccess.open("res://data/resources")
	if not dir:
		push_error("Failed to open resources directory")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".json"):
			var resource_id = file_name.trim_suffix(".json")
			var resource_data = _load_resource_file("res://data/resources/" + file_name)
			
			if resource_data:
				resources[resource_id] = resource_data
				print("Loaded resource: ", resource_id)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	print("Loaded %d resources" % resources.size())

func _load_resource_file(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open resource file: " + path)
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	
	if error != OK:
		push_error("Failed to parse resource JSON: " + path)
		return {}
	
	return json.data

func get_resource(id: String) -> Dictionary:
	return resources.get(id, {})

func has_resource(id: String) -> bool:
	return resources.has(id)

func get_all_resource_ids() -> Array:
	return resources.keys()

func is_storable(id: String) -> bool:
	var res = get_resource(id)
	return res.get("type", "") == "storable"

func is_flow(id: String) -> bool:
	var res = get_resource(id)
	return res.get("type", "") == "flow"
