extends RefCounted
class_name TileTypeRegistry

# Registry for tile types - visual combinations of terrain + modifiers

var tile_types: Dictionary = {}  # tile_type_id -> data
var _terrain_index: Dictionary = {}  # terrain_id -> Array[tile_type_id] (sorted by specificity)

func load_data():
	var dir_path = "res://data/tile_types"
	var dir = DirAccess.open(dir_path)
	
	if not dir:
		push_error("TileTypeRegistry: Cannot open tile_types directory: " + dir_path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var file_path = dir_path + "/" + file_name
			_load_tile_type_file(file_path)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	# Build terrain index for fast lookups
	_build_terrain_index()
	
	print("TileTypeRegistry: Loaded %d tile types" % tile_types.size())

func _load_tile_type_file(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("TileTypeRegistry: Cannot open file: " + file_path)
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("TileTypeRegistry: JSON parse error in %s: %s" % [file_path, json.get_error_message()])
		return
	
	var data = json.data
	if not data.has("id"):
		push_error("TileTypeRegistry: Tile type missing 'id' in " + file_path)
		return
	
	tile_types[data.id] = data

func _build_terrain_index():
	"""Build an index mapping terrain_id -> list of tile_types sorted by specificity"""
	_terrain_index.clear()
	
	for tile_type_id in tile_types.keys():
		var data = tile_types[tile_type_id]
		var terrain = data.get("base_terrain", "")
		
		if terrain == "":
			continue
		
		if not _terrain_index.has(terrain):
			_terrain_index[terrain] = []
		
		_terrain_index[terrain].append(tile_type_id)
	
	# Sort each terrain's tile types by number of required modifiers (descending)
	# This ensures more specific matches are checked first
	for terrain in _terrain_index.keys():
		_terrain_index[terrain].sort_custom(_sort_by_specificity)

func _sort_by_specificity(a: String, b: String) -> bool:
	"""Sort tile types by number of required modifiers (most specific first)"""
	var a_mods = tile_types[a].get("required_modifiers", []).size()
	var b_mods = tile_types[b].get("required_modifiers", []).size()
	return a_mods > b_mods

func get_tile_type(tile_type_id: String) -> Dictionary:
	"""Get tile type definition by ID"""
	return tile_types.get(tile_type_id, {})

func get_display_name(tile_type_id: String) -> String:
	var data = get_tile_type(tile_type_id)
	return data.get("display_name", tile_type_id.capitalize())

func get_visual(tile_type_id: String) -> Dictionary:
	var data = get_tile_type(tile_type_id)
	return data.get("visual", {})

func resolve_tile_type(terrain_id: String, modifiers: Array) -> String:
	"""
	Find the best matching tile type for a terrain + modifiers combination.
	Returns the tile_type_id, or the terrain_id as fallback.
	"""
	if not _terrain_index.has(terrain_id):
		# No tile types defined for this terrain, use terrain_id as fallback
		return terrain_id
	
	var candidates = _terrain_index[terrain_id]
	
	# Check each candidate (sorted by specificity, most specific first)
	for tile_type_id in candidates:
		var data = tile_types[tile_type_id]
		var required = data.get("required_modifiers", [])
		
		# Check if all required modifiers are present
		if _has_all_modifiers(modifiers, required):
			return tile_type_id
	
	# No specific match found, return base terrain type if it exists
	if tile_types.has(terrain_id):
		return terrain_id
	
	# Ultimate fallback
	return terrain_id

func _has_all_modifiers(tile_modifiers: Array, required: Array) -> bool:
	"""Check if tile_modifiers contains all required modifiers"""
	for req in required:
		if not tile_modifiers.has(req):
			return false
	return true

func get_all_tile_types_for_terrain(terrain_id: String) -> Array:
	"""Get all tile types that can appear on a given terrain"""
	return _terrain_index.get(terrain_id, [])
