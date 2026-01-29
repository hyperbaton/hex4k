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

func has_flag(id: String, flag_name: String) -> bool:
	"""Check if a resource has a specific flag enabled"""
	var res = get_resource(id)
	var flags = res.get("flags", {})
	return flags.get(flag_name, false)

func is_population_resource(id: String) -> bool:
	"""Check if this resource contributes to population count"""
	return has_flag(id, "population")

func is_decaying(id: String) -> bool:
	"""Check if this resource decays over time"""
	return has_flag(id, "decaying")

func is_tradeable(id: String) -> bool:
	"""Check if this resource can be traded"""
	return has_flag(id, "tradeable")

func get_decay_rate(id: String) -> float:
	"""Get the base decay rate per turn for a resource"""
	var res = get_resource(id)
	if not res.has("storage"):
		return 0.0
	var decay_data = res.storage.get("decay", {})
	if not decay_data.get("enabled", false):
		return 0.0
	return decay_data.get("base_rate_per_turn", 0.0)

func get_category(id: String) -> String:
	"""Get the category of a resource"""
	var res = get_resource(id)
	return res.get("category", "")

func get_all_population_resources() -> Array[String]:
	"""Get all resources that have the population flag"""
	var result: Array[String] = []
	for res_id in resources.keys():
		if is_population_resource(res_id):
			result.append(res_id)
	return result

func get_required_milestones(id: String) -> Array:
	"""Get the milestones required to unlock this resource"""
	var res = get_resource(id)
	return res.get("milestones_required", [])

func is_resource_unlocked(id: String) -> bool:
	"""Check if a resource is unlocked (all required milestones are unlocked)"""
	var milestones = get_required_milestones(id)
	
	# If no milestones required, it's always unlocked
	if milestones.is_empty():
		return true
	
	# Check if all required milestones are unlocked
	for milestone_id in milestones:
		if not Registry.tech.is_milestone_unlocked(milestone_id):
			return false
	
	return true
