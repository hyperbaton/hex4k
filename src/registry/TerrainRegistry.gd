extends RefCounted
class_name TerrainRegistry

var terrains := {}  # Dictionary<String, Dictionary>

func load_data():
	var dir = DirAccess.open("res://data/terrains")
	if not dir:
		push_error("Failed to open terrains directory")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".json"):
			var terrain_id = file_name.trim_suffix(".json")
			var terrain_data = _load_terrain_file("res://data/terrains/" + file_name)
			
			if terrain_data:
				terrains[terrain_id] = terrain_data
				print("Loaded terrain: ", terrain_id)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	print("Loaded %d terrains" % terrains.size())

func _load_terrain_file(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open terrain file: " + path)
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	
	if error != OK:
		push_error("Failed to parse terrain JSON: " + path)
		return {}
	
	return json.data

func get_terrain(id: String) -> Dictionary:
	return terrains.get(id, {})

func has_terrain(id: String) -> bool:
	return terrains.has(id)

func get_all_terrain_ids() -> Array:
	return terrains.keys()

func blocks_vision(terrain_id: String) -> bool:
	"""Check if a terrain type blocks line-of-sight"""
	var terrain = get_terrain(terrain_id)
	return terrain.get("blocks_vision", false)

func get_vision_bonus(terrain_id: String) -> int:
	"""Get the vision bonus granted to units/buildings on this terrain"""
	var terrain = get_terrain(terrain_id)
	return terrain.get("vision_bonus", 0)
