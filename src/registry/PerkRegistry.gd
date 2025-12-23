extends RefCounted
class_name PerkRegistry

var perks := {}  # Dictionary<String, Dictionary>

func load_data():
	var dir = DirAccess.open("res://data/perks")
	if not dir:
		push_error("Failed to open perks directory")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".json"):
			var perk_id = file_name.trim_suffix(".json")
			var perk_data = _load_perk_file("res://data/perks/" + file_name)
			
			if perk_data:
				perks[perk_id] = perk_data
				print("Loaded perk: ", perk_id)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	print("Loaded %d perks" % perks.size())

func _load_perk_file(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open perk file: " + path)
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	
	if error != OK:
		push_error("Failed to parse perk JSON: " + path)
		return {}
	
	return json.data

func get_perk(id: String) -> Dictionary:
	return perks.get(id, {})

func has_perk(id: String) -> bool:
	return perks.has(id)

func get_all_perk_ids() -> Array:
	return perks.keys()

func check_unlock_conditions(perk_id: String, game_state: Dictionary) -> bool:
	var perk = get_perk(perk_id)
	if not perk.has("unlock_conditions"):
		return true
	
	var conditions = perk.unlock_conditions
	
	# Check milestone requirements
	if conditions.has("milestones_before"):
		for milestone_id in conditions.milestones_before.keys():
			if not game_state.get("unlocked_milestones", []).has(milestone_id):
				return false
	
	if conditions.has("milestones_not_researched"):
		for milestone_id in conditions.milestones_not_researched.keys():
			if game_state.get("unlocked_milestones", []).has(milestone_id):
				return false
	
	# Additional condition checks would go here
	# (cities_with_buildings, tiles_owned_by_terrain, turn_range, etc.)
	
	return true
