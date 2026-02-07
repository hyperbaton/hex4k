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
		
		"on_city":
			var city_manager = context.get("city_manager")
			if city_manager:
				var city = city_manager.get_city_at_tile(unit.coord)
				if not city:
					return {passed = false, message = message}
				# Must be same owner
				if city.owner and city.owner.player_id != unit.owner_id:
					return {passed = false, message = "Not your city"}
		
		"has_cargo_capacity":
			if not unit.has_cargo_capacity():
				return {passed = false, message = message}
		
		"tile_allows_infrastructure":
			var world_query = context.get("world_query")
			if world_query:
				var build_id = _get_unit_build_target(unit)
				if build_id == "":
					return {passed = false, message = "No buildable infrastructure"}
				var mod_data = Registry.modifiers.get_modifier(build_id)
				var terrain_data = world_query.get_terrain_data(unit.coord)
				if not terrain_data:
					return {passed = false, message = message}
				# Check if already has the modifier or a conflicting one
				if terrain_data.has_modifier(build_id):
					return {passed = false, message = "Path already exists here"}
				var conflicts = mod_data.get("conflicts_with", [])
				for conflict_id in conflicts:
					if terrain_data.has_modifier(conflict_id):
						return {passed = false, message = "A road already exists here"}
				# Check prohibited modifiers
				var conditions_data = mod_data.get("conditions", {})
				var prohibited = conditions_data.get("prohibits_modifiers", [])
				for p in prohibited:
					if terrain_data.has_modifier(p):
						return {passed = false, message = message}
				# Check terrain type is allowed
				var allowed_terrain = conditions_data.get("terrain_types", [])
				if not allowed_terrain.is_empty():
					var terrain_id = world_query.get_terrain_id(unit.coord)
					if terrain_id not in allowed_terrain:
						return {passed = false, message = "Terrain not suitable"}
				# Check milestones
				var req_milestones = mod_data.get("milestones_required", [])
				if not Registry.has_all_milestones(req_milestones):
					return {passed = false, message = "Technology not researched"}
		
		"has_cargo_for_build":
			var build_id = _get_unit_build_target(unit)
			if build_id != "":
				var mod_data = Registry.modifiers.get_modifier(build_id)
				var construction = mod_data.get("construction", {})
				var cost = construction.get("cost", {})
				for resource_id in cost.keys():
					if not unit.has_cargo(resource_id, cost[resource_id]):
						return {passed = false, message = "Need %s in cargo" % resource_id}
		
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
	if movement_cost is String and movement_cost == "all":
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
		
		"open_cargo_dialog":
			# Signal to UI layer to open the cargo management dialog
			return {success = true, message = "", data = {open_dialog = "cargo"}}
		
		"build_modifier":
			return _effect_build_modifier(unit, params, context)
		
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
		var ability_id: String = ""
		var params: Dictionary = {}
		
		if ability_ref is Dictionary:
			ability_id = ability_ref.get("ability_id", "")
			params = ability_ref.get("params", {})
		elif ability_ref is String:
			ability_id = ability_ref
		
		if ability_id == "":
			continue
		
		var check = check_conditions(ability_id, unit, context)
		
		available.append({
			ability_id = ability_id,
			params = params,
			can_use = check.can_use,
			reason = check.reason
		})
	
	return available

# === Infrastructure Building ===

func _get_unit_build_target(unit: Unit) -> String:
	"""Get the infrastructure modifier ID this unit can build.
	Looks at the build_infrastructure ability params for the 'builds' list."""
	var params = unit.get_ability_params("build_infrastructure")
	var builds = params.get("builds", [])
	if builds.is_empty():
		return ""
	# Return the first buildable infrastructure
	return builds[0]

func _effect_build_modifier(unit: Unit, params: Dictionary, context: Dictionary) -> Dictionary:
	"""Build an infrastructure modifier on the unit's current tile."""
	var world_query = context.get("world_query")
	if not world_query:
		return {success = false, message = "No world query available", data = {}}
	
	var build_id = _get_unit_build_target(unit)
	if build_id == "":
		return {success = false, message = "No buildable infrastructure", data = {}}
	
	var mod_data = Registry.modifiers.get_modifier(build_id)
	var construction = mod_data.get("construction", {})
	var cost = construction.get("cost", {})
	
	# Consume resources from cargo
	for resource_id in cost.keys():
		var amount = cost[resource_id]
		var removed = unit.remove_cargo(resource_id, amount)
		if removed < amount:
			return {success = false, message = "Not enough %s in cargo" % resource_id, data = {}}
	
	# Apply the modifier to the terrain
	var terrain_data = world_query.get_terrain_data(unit.coord)
	if terrain_data:
		terrain_data.add_modifier(build_id)
		print("Built %s at %v" % [build_id, unit.coord])
		return {success = true, message = "", data = {built_modifier = build_id, coord = unit.coord}}
	
	return {success = false, message = "Failed to modify terrain", data = {}}
