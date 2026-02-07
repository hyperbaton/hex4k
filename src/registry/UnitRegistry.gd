extends RefCounted
class_name UnitRegistry

var units := {}  # Dictionary<String, Dictionary>
var movement_types := {}  # Dictionary<String, Dictionary>

func load_data():
	load_units()
	load_movement_types()

func load_units():
	var dir = DirAccess.open("res://data/units")
	if not dir:
		push_error("Failed to open units directory")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".json"):
			var unit_id = file_name.trim_suffix(".json")
			var unit_data = _load_json_file("res://data/units/" + file_name)
			
			if not unit_data.is_empty():
				units[unit_id] = unit_data
				print("Loaded unit: ", unit_id)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	print("Loaded %d units" % units.size())

func load_movement_types():
	var dir = DirAccess.open("res://data/movement_types")
	if not dir:
		push_error("Failed to open movement_types directory")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".json"):
			var type_id = file_name.trim_suffix(".json")
			var type_data = _load_json_file("res://data/movement_types/" + file_name)
			
			if not type_data.is_empty():
				movement_types[type_id] = type_data
				print("Loaded movement type: ", type_id)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	print("Loaded %d movement types" % movement_types.size())

func _load_json_file(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open file: " + path)
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	
	if error != OK:
		push_error("Failed to parse JSON: " + path)
		return {}
	
	return json.data

# === Unit Accessors ===

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

func get_unit_name(id: String) -> String:
	return Registry.get_name_label("unit", id)

func get_unit_category(id: String) -> String:
	var unit = get_unit(id)
	return unit.get("category", "")

func is_civil_unit(id: String) -> bool:
	return get_unit_category(id) == "civil"

func is_military_unit(id: String) -> bool:
	return get_unit_category(id) == "military"

func get_trained_at(id: String) -> Array:
	"""Get the list of buildings that can train this unit"""
	var unit = get_unit(id)
	return unit.get("trained_at", [])

func get_training_cost(id: String) -> Dictionary:
	"""Get the resource cost to train this unit"""
	var unit = get_unit(id)
	var training = unit.get("training", {})
	return training.get("cost", {})

func get_training_turns(id: String) -> int:
	"""Get the number of turns to train this unit"""
	var unit = get_unit(id)
	var training = unit.get("training", {})
	return training.get("turns", 1)

func get_milestones_required(id: String) -> Array:
	"""Get the milestones required to unlock this unit"""
	var unit = get_unit(id)
	return unit.get("milestones_required", [])

func is_unit_unlocked(id: String) -> bool:
	"""Check if a unit is unlocked (all required milestones are unlocked)"""
	var milestones = get_milestones_required(id)
	
	if milestones.is_empty():
		return true
	
	for milestone_id in milestones:
		if not Registry.tech.is_milestone_unlocked(milestone_id):
			return false
	
	return true

func get_units_trainable_at(building_id: String) -> Array[String]:
	"""Get all units that can be trained at a specific building"""
	var result: Array[String] = []
	for unit_id in units.keys():
		var trained_at = get_trained_at(unit_id)
		if building_id in trained_at:
			result.append(unit_id)
	return result

func get_stat(id: String, stat_name: String, default_value = 0):
	"""Get a specific stat from a unit"""
	var unit = get_unit(id)
	var stats = unit.get("stats", {})
	return stats.get(stat_name, default_value)

func get_combat_stat(id: String, stat_name: String, default_value = 0):
	"""Get a specific combat stat from a unit"""
	var unit = get_unit(id)
	var combat = unit.get("combat", {})
	return combat.get(stat_name, default_value)

func get_maintenance(id: String) -> Dictionary:
	"""Get the per-turn maintenance cost of a unit"""
	var unit = get_unit(id)
	return unit.get("maintenance", {})

# === Movement Type Accessors ===

func get_movement_type(type_id: String) -> Dictionary:
	return movement_types.get(type_id, {})

func has_movement_type(type_id: String) -> bool:
	return movement_types.has(type_id)

func get_terrain_cost(movement_type_id: String, terrain_type: String) -> int:
	"""Get the movement cost to enter a terrain type. Returns -1 if impassable."""
	var mt = get_movement_type(movement_type_id)
	var terrain_costs = mt.get("terrain_costs", {})
	
	if not terrain_costs.has(terrain_type):
		return -1  # Impassable
	
	return terrain_costs.get(terrain_type, -1)

func get_modifier_cost(movement_type_id: String, modifier_id: String) -> int:
	"""Get the movement cost override from a modifier. Returns -1 if no override defined."""
	var mt = get_movement_type(movement_type_id)
	var modifier_costs = mt.get("modifier_costs", {})
	return modifier_costs.get(modifier_id, -1)

func get_effective_movement_cost(movement_type_id: String, terrain_type: String, modifiers: Array) -> int:
	"""Get the effective movement cost considering terrain and any modifiers.
	Returns -1 if impassable."""
	var base_cost = get_terrain_cost(movement_type_id, terrain_type)
	if base_cost < 0:
		return -1  # Impassable terrain stays impassable
	
	# Check if any modifier provides a cheaper cost
	for modifier_id in modifiers:
		var mod_cost = get_modifier_cost(movement_type_id, modifier_id)
		if mod_cost > 0 and mod_cost < base_cost:
			base_cost = mod_cost
	
	return base_cost

func can_traverse_terrain(movement_type_id: String, terrain_type: String) -> bool:
	"""Check if a movement type can traverse a specific terrain"""
	return get_terrain_cost(movement_type_id, terrain_type) > 0

func get_infrastructure_data(modifier_id: String) -> Dictionary:
	"""Get infrastructure build data from modifier definition.
	Returns construction info if the modifier is buildable infrastructure, empty dict otherwise."""
	var mod_data = Registry.modifiers.get_modifier(modifier_id) if Registry.has("modifiers") else {}
	if mod_data.is_empty():
		# Try loading from modifier files directly
		var path = "res://data/modifiers/%s.json" % modifier_id
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				mod_data = json.data
			file.close()
	if mod_data.get("type", "") != "infrastructure":
		return {}
	return mod_data.get("construction", {})
