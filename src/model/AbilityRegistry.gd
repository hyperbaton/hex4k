extends RefCounted
class_name AbilityRegistry

# Registry for unit abilities - loads from JSON and handles ability logic

var abilities: Dictionary = {}  # ability_id -> ability_data
var _loaded: bool = false

func _init():
	_load_all_abilities()

func _load_all_abilities():
	if _loaded:
		return
	
	var dir_path = "res://data/abilities"
	var dir = DirAccess.open(dir_path)
	
	if not dir:
		push_error("AbilityRegistry: Cannot open abilities directory: " + dir_path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var file_path = dir_path + "/" + file_name
			_load_ability_file(file_path)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	_loaded = true
	print("AbilityRegistry: Loaded %d abilities" % abilities.size())

func _load_ability_file(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("AbilityRegistry: Cannot open file: " + file_path)
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("AbilityRegistry: JSON parse error in %s: %s" % [file_path, json.get_error_message()])
		return
	
	var data = json.data
	if not data.has("id"):
		push_error("AbilityRegistry: Ability missing 'id' in " + file_path)
		return
	
	abilities[data.id] = data
	print("  Loaded ability: ", data.id)

func get_ability(ability_id: String) -> Dictionary:
	"""Get ability definition by ID"""
	return abilities.get(ability_id, {})

func get_ability_name(ability_id: String) -> String:
	var ability = get_ability(ability_id)
	return ability.get("name", ability_id.capitalize())

func get_ability_description(ability_id: String) -> String:
	var ability = get_ability(ability_id)
	return ability.get("description", "")

func get_ability_icon(ability_id: String) -> String:
	var ability = get_ability(ability_id)
	return ability.get("icon", "")

func get_ability_category(ability_id: String) -> String:
	var ability = get_ability(ability_id)
	return ability.get("category", "general")

# === Condition Checking ===

func check_conditions(ability_id: String, unit: Unit, context: Dictionary) -> Dictionary:
	"""
	Check if ability conditions are met.
	Returns {can_use: bool, reason: String}
	Context should contain: world_query, city_manager, unit_manager
	"""
	var ability = get_ability(ability_id)
	if ability.is_empty():
		return {can_use = false, reason = "Unknown ability"}
	
	var conditions = ability.get("conditions", [])
	
	for condition in conditions:
		var result = _check_single_condition(condition, unit, context)
		if not result.passed:
			return {can_use = false, reason = result.message}
	
	return {can_use = true, reason = ""}

func _check_single_condition(condition: Dictionary, unit: Unit, context: Dictionary) -> Dictionary:
	var condition_type = condition.get("type", "")
	var message = condition.get("message", "Condition not met")
	
	match condition_type:
		"not_on_city":
			var city_manager = context.get("city_manager")
			if city_manager and city_manager.get_city_at_tile(unit.coord):
				return {passed = false, message = message}
		
		"terrain_allows_city":
			var world_query = context.get("world_query")
			if world_query:
				var terrain_id = world_query.get_terrain_id(unit.coord)
				# Water and other impassable terrain can't have cities
				if terrain_id in ["ocean", "deep_ocean", "lake"]:
					return {passed = false, message = message}
		
		"min_distance_from_city":
			var distance = condition.get("distance", 3)
			var city_manager = context.get("city_manager")
			if city_manager:
				for city in city_manager.get_all_cities():
					var city_distance = _hex_distance(unit.coord, city.city_center_coord)
					if city_distance < distance:
						return {passed = false, message = message}
		
		"not_fortified":
			if unit.is_fortified:
				return {passed = false, message = message}
		
		"has_movement":
			if unit.current_movement <= 0:
				return {passed = false, message = message}
		
		"not_acted":
			if unit.has_acted:
				return {passed = false, message = message}
		
		"adjacent_enemy":
			var unit_manager = context.get("unit_manager")
			if unit_manager:
				var has_enemy = false
				for neighbor in _get_hex_neighbors(unit.coord):
					var enemy = unit_manager.get_unit_at(neighbor)
					if enemy and enemy.owner_id != unit.owner_id:
						has_enemy = true
						break
				if not has_enemy:
					return {passed = false, message = message}
		
		_:
			push_warning("AbilityRegistry: Unknown condition type: " + condition_type)
	
	return {passed = true, message = ""}

func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var q_diff = abs(a.x - b.x)
	var r_diff = abs(a.y - b.y)
	var s_diff = abs((-a.x - a.y) - (-b.x - b.y))
	return int((q_diff + r_diff + s_diff) / 2)

func _get_hex_neighbors(coord: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var directions = [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
	]
	for dir in directions:
		neighbors.append(coord + dir)
	return neighbors

# === Ability Execution ===

func execute_ability(ability_id: String, unit: Unit, params: Dictionary, context: Dictionary) -> Dictionary:
	"""
	Execute an ability.
	Returns {success: bool, message: String, results: Dictionary}
	"""
	var ability = get_ability(ability_id)
	if ability.is_empty():
		return {success = false, message = "Unknown ability", results = {}}
	
	# Check conditions first
	var condition_check = check_conditions(ability_id, unit, context)
	if not condition_check.can_use:
		return {success = false, message = condition_check.reason, results = {}}
	
	# Apply costs
	var costs = ability.get("costs", {})
	_apply_costs(unit, costs)
	
	# Execute effects
	var effects = ability.get("effects", [])
	var results = {}
	
	for effect in effects:
		var effect_result = _execute_effect(effect, unit, params, context)
		if not effect_result.success:
			return {success = false, message = effect_result.message, results = results}
		results.merge(effect_result.data)
	
	# Handle unit consumption
	if costs.get("consumes_unit", false):
		results["unit_consumed"] = true
	
	return {success = true, message = "Ability executed", results = results}

func _apply_costs(unit: Unit, costs: Dictionary):
	var movement_cost = costs.get("movement", 0)
	if movement_cost == "all":
		unit.current_movement = 0
	elif movement_cost is int or movement_cost is float:
		unit.current_movement = max(0, unit.current_movement - int(movement_cost))
	
	if costs.get("ends_turn", false):
		unit.has_acted = true

func _execute_effect(effect: Dictionary, unit: Unit, params: Dictionary, context: Dictionary) -> Dictionary:
	var effect_type = effect.get("type", "")
	
	match effect_type:
		"found_city":
			return _effect_found_city(effect, unit, params, context)
		
		"set_fortified":
			unit.is_fortified = effect.get("value", true)
			return {success = true, message = "", data = {}}
		
		"melee_combat":
			return _effect_melee_combat(effect, unit, params, context)
		
		_:
			push_warning("AbilityRegistry: Unknown effect type: " + effect_type)
			return {success = true, message = "", data = {}}

func _effect_found_city(effect: Dictionary, unit: Unit, params: Dictionary, context: Dictionary) -> Dictionary:
	var city_manager = context.get("city_manager")
	if not city_manager:
		return {success = false, message = "No city manager", data = {}}
	
	# Resolve parameters (replace ${param} with actual values)
	var building_id = _resolve_param(effect.get("city_center_building", "city_center"), params)
	var name_prefix = _resolve_param(effect.get("city_name_prefix", "New "), params)
	
	# Generate city name
	var city_count = city_manager.get_all_cities().size() + 1
	var city_name = name_prefix + "Settlement " + str(city_count)
	
	# Found the city
	var city = city_manager.found_city(city_name, unit.coord, unit.owner_id, building_id)
	
	if city:
		return {success = true, message = "", data = {city = city, city_id = city.city_id}}
	else:
		return {success = false, message = "Failed to found city", data = {}}

func _effect_melee_combat(effect: Dictionary, unit: Unit, params: Dictionary, context: Dictionary) -> Dictionary:
	# TODO: Implement combat system
	# This is a placeholder for future combat implementation
	var target = context.get("target_unit")
	if not target:
		return {success = false, message = "No target selected", data = {}}
	
	var damage_multiplier = _resolve_param(effect.get("damage_multiplier", 1.0), params)
	var base_damage = unit.attack * float(damage_multiplier)
	
	target.take_damage(int(base_damage))
	
	return {success = true, message = "", data = {damage_dealt = base_damage}}

func _resolve_param(value, params: Dictionary):
	"""Resolve ${param_name} references in values"""
	if value is String and value.begins_with("${") and value.ends_with("}"):
		var param_name = value.substr(2, value.length() - 3)
		return params.get(param_name, value)
	return value

# === Unit Ability Helpers ===

func get_unit_abilities(unit: Unit) -> Array:
	"""Get all abilities available to a unit (from its unit type definition)"""
	var unit_data = Registry.units.get_unit(unit.unit_type)
	return unit_data.get("abilities", [])

func get_available_abilities(unit: Unit, context: Dictionary) -> Array:
	"""Get abilities the unit can currently use (conditions met)"""
	var available = []
	var unit_abilities = get_unit_abilities(unit)
	
	for ability_ref in unit_abilities:
		var ability_id = ability_ref.get("ability_id", "")
		var check = check_conditions(ability_id, unit, context)
		
		available.append({
			ability_id = ability_id,
			params = ability_ref.get("params", {}),
			can_use = check.can_use,
			reason = check.reason
		})
	
	return available
