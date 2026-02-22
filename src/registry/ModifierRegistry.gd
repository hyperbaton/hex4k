extends RefCounted
class_name ModifierRegistry

# Registry for tile modifiers - terrain features and resource deposits
# Note: Effects (yields, movement costs) are defined on the RECEIVERS (buildings, movement_types),
# not on modifiers themselves. This follows the principle that effects belong to the receiver.

var modifiers := {}  # Dictionary<String, Dictionary>
var generation_cache: Array[Dictionary] = []  # Cached data for terrain generation

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
	
	# Build generation cache
	_build_generation_cache()
	
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

func _build_generation_cache():
	"""Build a cache of modifier generation parameters for efficient terrain gen."""
	generation_cache.clear()

	for modifier_id in modifiers.keys():
		var modifier = modifiers[modifier_id]
		var conflicts = modifier.get("conflicts_with", [])
		var rules: Array = modifier.get("generation_rules", [])

		for gen in rules:
			generation_cache.append({
				"id": modifier_id,
				"spawn_chance": gen.get("spawn_chance", 0.0),
				"altitude_min": gen.get("altitude_min", 0.0),
				"altitude_max": gen.get("altitude_max", 1.0),
				"humidity_min": gen.get("humidity_min", 0.0),
				"humidity_max": gen.get("humidity_max", 1.0),
				"temperature_min": gen.get("temperature_min", 0.0),
				"temperature_max": gen.get("temperature_max", 1.0),
				"terrain_types": gen.get("terrain_types", []),
				"cluster_size": gen.get("cluster_size", 1.0),
				"cluster_falloff": gen.get("cluster_falloff", 1.0),
				"conflicts_with": conflicts
			})

	print("ModifierRegistry: Built generation cache with %d entries" % generation_cache.size())

func get_generation_cache() -> Array[Dictionary]:
	"""Get the cached generation data for terrain generation"""
	return generation_cache

# === Basic Accessors ===

func get_modifier(id: String) -> Dictionary:
	return modifiers.get(id, {})

func has_modifier(id: String) -> bool:
	return modifiers.has(id)

func modifier_exists(id: String) -> bool:
	return modifiers.has(id)

func get_all_modifier_ids() -> Array:
	return modifiers.keys()

func get_modifier_type(modifier_id: String) -> String:
	"""Get the type of modifier (terrain_feature, resource_deposit, yield_modifier)"""
	var modifier = get_modifier(modifier_id)
	return modifier.get("type", "")

func get_conflicts(modifier_id: String) -> Array:
	"""Get list of modifier IDs this modifier conflicts with"""
	var modifier = get_modifier(modifier_id)
	return modifier.get("conflicts_with", [])

# === Display Helpers ===

func get_modifier_name(modifier_id: String) -> String:
	"""Get localized name for a modifier"""
	return Registry.localization.get_name("modifier", modifier_id)

func get_modifier_description(modifier_id: String) -> String:
	"""Get localized description for a modifier"""
	return Registry.localization.get_description("modifier", modifier_id)

func get_modifier_icon(modifier_id: String) -> String:
	"""Get icon path for a modifier"""
	var modifier = get_modifier(modifier_id)
	var visual = modifier.get("visual", {})
	return visual.get("icon", "")

func get_modifier_overlay_color(modifier_id: String) -> Color:
	"""Get overlay color for a modifier"""
	var modifier = get_modifier(modifier_id)
	var visual = modifier.get("visual", {})
	var color_str = visual.get("overlay_color", "#FFFFFF00")
	return Color.from_string(color_str, Color.TRANSPARENT)

# === Condition Checking ===

func get_required_milestones(modifier_id: String) -> Array:
	"""Get milestones required to utilize this modifier"""
	var modifier = get_modifier(modifier_id)
	return modifier.get("milestones_required", [])

func can_exist_on_terrain(modifier_id: String, terrain_id: String) -> bool:
	"""Check if a modifier can exist on a given terrain type"""
	var modifier = get_modifier(modifier_id)
	var conditions = modifier.get("conditions", {})
	var allowed_terrains = conditions.get("terrain_types", [])
	
	if allowed_terrains.is_empty():
		return true  # No restriction
	
	return terrain_id in allowed_terrains

func are_modifiers_compatible(modifier_a: String, modifier_b: String) -> bool:
	"""Check if two modifiers can coexist on the same tile"""
	var conflicts_a = get_conflicts(modifier_a)
	var conflicts_b = get_conflicts(modifier_b)
	
	return not (modifier_b in conflicts_a or modifier_a in conflicts_b)

func blocks_vision(modifier_id: String) -> bool:
	"""Check if a modifier blocks line-of-sight"""
	var modifier = get_modifier(modifier_id)
	return modifier.get("blocks_vision", false)

# === Trade Route Helpers ===

func is_trade_route_marker(modifier_id: String) -> bool:
	"""Check if a modifier is a trade route marker (encoded as trade_route_marker_{unit_type})"""
	return modifier_id.begins_with("trade_route_marker_")

func get_trade_route_marker_unit_type(modifier_id: String) -> String:
	"""Extract the unit type from a trade route marker modifier ID."""
	if is_trade_route_marker(modifier_id):
		return modifier_id.substr("trade_route_marker_".length())
	return ""

func get_trade_route_marker_id(unit_type: String) -> String:
	"""Get the trade route marker modifier ID for a given unit type."""
	return "trade_route_marker_" + unit_type
