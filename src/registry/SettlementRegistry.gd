extends RefCounted
class_name SettlementRegistry

# Stores all settlement type definitions.
# Settlement types control tile costs, building restrictions, expansion limits,
# and transitions between settlement forms (e.g., encampment → village → town).

var types := {}  # type_id -> Dictionary (JSON data)

# Pre-built indexes
var _tag_index := {}  # tag -> Array[String] of type IDs

func load_data():
	var dir = DirAccess.open("res://data/settlements")
	if not dir:
		push_warning("No settlements directory found — using defaults")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".json"):
			var type_id = file_name.trim_suffix(".json")
			var type_data = _load_type_file("res://data/settlements/" + file_name)
			
			if type_data:
				types[type_id] = type_data
				_index_tags(type_id, type_data)
				print("Loaded settlement type: ", type_id)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	print("Loaded %d settlement types" % types.size())

func _load_type_file(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open settlement type file: " + path)
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	
	if error != OK:
		push_error("Failed to parse settlement type JSON: " + path)
		return {}
	
	return json.data

func _index_tags(type_id: String, data: Dictionary):
	"""Build tag index for fast lookups"""
	var tags = data.get("tags", [])
	for tag in tags:
		if not _tag_index.has(tag):
			_tag_index[tag] = []
		_tag_index[tag].append(type_id)

# === Core API ===

func get_type(type_id: String) -> Dictionary:
	"""Get the full settlement type definition"""
	if not types.has(type_id):
		push_warning("Settlement type not found: " + type_id)
		return {}
	return types[type_id]

func type_exists(type_id: String) -> bool:
	return types.has(type_id)

func get_all_type_ids() -> Array:
	return types.keys()

func has_tag(type_id: String, tag: String) -> bool:
	"""Check if a settlement type has a specific tag"""
	var type_data = get_type(type_id)
	var tags = type_data.get("tags", [])
	return tag in tags

func get_types_by_tag(tag: String) -> Array[String]:
	"""Get all settlement type IDs that have a specific tag"""
	var result: Array[String] = []
	if _tag_index.has(tag):
		for type_id in _tag_index[tag]:
			result.append(type_id)
	return result

# === Tile Costs ===

func get_tile_costs(type_id: String) -> Array:
	"""Get the tile cost definitions for a settlement type.
	Returns array of cost entries, each with: resource, base_cost, distance_multiplier,
	distance_exponent, distance_to, exempt_center, exempt_within."""
	var type_data = get_type(type_id)
	return type_data.get("tile_costs", [])

func calculate_tile_cost(type_id: String, resource_id: String, distance: int, is_center: bool) -> float:
	"""Calculate the tile maintenance cost for a specific resource at a given distance.
	Returns 0.0 if this settlement type doesn't have a tile cost for this resource."""
	var tile_costs = get_tile_costs(type_id)
	
	for cost_entry in tile_costs:
		if cost_entry.get("resource", "") != resource_id:
			continue
		
		# Check exemptions
		if is_center and cost_entry.get("exempt_center", false):
			return 0.0
		
		var exempt_within = cost_entry.get("exempt_within", 0)
		if exempt_within > 0 and distance <= exempt_within:
			return 0.0
		
		var base_cost = cost_entry.get("base_cost", 0.0)
		var multiplier = cost_entry.get("distance_multiplier", 0.0)
		var exponent = cost_entry.get("distance_exponent", 1)
		
		return base_cost + (pow(distance, exponent) * multiplier)
	
	return 0.0

func get_all_tile_cost_resources(type_id: String) -> Array[String]:
	"""Get all resource IDs that have tile costs for this settlement type"""
	var result: Array[String] = []
	var tile_costs = get_tile_costs(type_id)
	for cost_entry in tile_costs:
		var resource = cost_entry.get("resource", "")
		if resource != "" and resource not in result:
			result.append(resource)
	return result

# === Tile Limits ===

func get_max_tiles(type_id: String) -> int:
	"""Get max tile count. 0 = unlimited."""
	var type_data = get_type(type_id)
	var limits = type_data.get("tile_limits", {})
	return limits.get("max_tiles", 0)

func is_expansion_allowed(type_id: String) -> bool:
	"""Check if the settlement type allows claiming new tiles"""
	var type_data = get_type(type_id)
	var limits = type_data.get("tile_limits", {})
	return limits.get("expansion_allowed", true)

# === Founding ===

func get_founding_info(type_id: String) -> Dictionary:
	"""Get founding configuration (unit type, initial buildings, resources)"""
	var type_data = get_type(type_id)
	return type_data.get("founding", {})

func get_founded_by(type_id: String) -> String:
	"""Get which unit type founds this settlement"""
	var founding = get_founding_info(type_id)
	return founding.get("founded_by", "")

func get_initial_buildings(type_id: String) -> Array:
	"""Get building IDs automatically placed at founding"""
	var founding = get_founding_info(type_id)
	return founding.get("initial_buildings", [])

func get_initial_resources(type_id: String) -> Dictionary:
	"""Get resources granted at founding"""
	var founding = get_founding_info(type_id)
	return founding.get("initial_resources", {})

# === Transitions ===

func get_transitions(type_id: String) -> Array:
	"""Get all possible transitions from this settlement type"""
	var type_data = get_type(type_id)
	return type_data.get("transitions", [])

func get_transition_to(type_id: String, target_type: String) -> Dictionary:
	"""Get a specific transition definition. Returns empty dict if not found."""
	var transitions = get_transitions(type_id)
	for transition in transitions:
		if transition.get("target", "") == target_type:
			return transition
	return {}

# === Bonuses ===

func get_bonuses(type_id: String) -> Dictionary:
	"""Get settlement-wide bonuses"""
	var type_data = get_type(type_id)
	return type_data.get("bonuses", {})

# === Building Compatibility ===

func can_build_in(building_id: String, settlement_type: String) -> bool:
	"""Check if a building can be placed in a settlement of this type.
	Buildings with no settlement_types/settlement_tags restrictions are allowed everywhere."""
	var building = Registry.buildings.get_building(building_id)
	if building.is_empty():
		return false
	
	var allowed_types = building.get("settlement_types", [])
	var allowed_tags = building.get("settlement_tags", [])
	
	# If neither is specified, building is allowed everywhere
	if allowed_types.is_empty() and allowed_tags.is_empty():
		return true
	
	# Check explicit type match
	if settlement_type in allowed_types:
		return true
	
	# Check tag match
	for tag in allowed_tags:
		if has_tag(settlement_type, tag):
			return true
	
	return false

# === Visual ===

func get_visual(type_id: String) -> Dictionary:
	var type_data = get_type(type_id)
	return type_data.get("visual", {})

func get_label_prefix(type_id: String) -> String:
	var visual = get_visual(type_id)
	return visual.get("label_prefix", "")
