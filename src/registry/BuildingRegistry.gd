extends RefCounted
class_name BuildingRegistry

# Stores all building definitions
var buildings := {}

func load_data():
	var dir = DirAccess.open("res://data/buildings")
	if not dir:
		push_error("Failed to open buildings directory")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".json"):
			var building_id = file_name.trim_suffix(".json")
			var building_data = _load_building_file("res://data/buildings/" + file_name)
			
			if building_data:
				buildings[building_id] = building_data
				print("Loaded building: ", building_id)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	print("Loaded %d buildings" % buildings.size())

func _load_building_file(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open building file: " + path)
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	
	if error != OK:
		push_error("Failed to parse building JSON: " + path)
		return {}
	
	return json.data

func get_building(building_id: String) -> Dictionary:
	if not buildings.has(building_id):
		push_warning("Building not found: " + building_id)
		return {}
	return buildings[building_id]

func building_exists(building_id: String) -> bool:
	return buildings.has(building_id)

func get_construction_cost(building_id: String) -> Dictionary:
	"""Get the per-turn construction cost"""
	var building = get_building(building_id)
	if building.has("construction"):
		return building.construction.get("cost_per_turn", {})
	return {}

func get_initial_construction_cost(building_id: String) -> Dictionary:
	"""Get the initial (upfront) construction cost"""
	var building = get_building(building_id)
	if building.has("construction"):
		return building.construction.get("initial_cost", {})
	return {}

func get_construction_turns(building_id: String) -> int:
	var building = get_building(building_id)
	if building.has("construction"):
		return building.construction.get("total_turns", 1)
	return 1

func get_admin_cost(building_id: String, distance: int) -> float:
	var building = get_building(building_id)
	if not building.has("admin_cost"):
		return 1.0
	
	var base = building.admin_cost.get("base", 1.0)
	var multiplier = building.admin_cost.get("distance_multiplier", 0.1)
	
	# Quadratic formula: base + (distance² * multiplier)
	return base + (distance * distance * multiplier)

func get_production_per_turn(building_id: String) -> Dictionary:
	var building = get_building(building_id)
	if building.has("production"):
		return building.production.get("per_turn_produces", {})
	return {}

func get_consumption_per_turn(building_id: String) -> Dictionary:
	var building = get_building(building_id)
	if building.has("production"):
		return building.production.get("per_turn_consumes", {})
	return {}

func get_branch_specific_research(building_id: String) -> Dictionary:
	var building = get_building(building_id)
	if building.has("production"):
		return building.production.get("branch_specific_research", {})
	return {}

func allows_units_on_tile(building_id: String) -> bool:
	var building = get_building(building_id)
	return building.get("can_units_stand", false)

func get_adjacency_bonuses(building_id: String) -> Array:
	var building = get_building(building_id)
	return building.get("adjacency_bonuses", [])

func get_terrain_bonuses(building_id: String) -> Dictionary:
	"""Get production bonuses when placed on specific terrain types"""
	var building = get_building(building_id)
	return building.get("terrain_bonuses", {})

func get_modifier_bonuses(building_id: String) -> Dictionary:
	"""Get production bonuses when placed on tiles with specific modifiers"""
	var building = get_building(building_id)
	return building.get("modifier_bonuses", {})

func get_storage_provided(building_id: String) -> Dictionary:
	var building = get_building(building_id)
	if building.has("provides"):
		return building.provides.get("resource_storage", {})
	return {}

func get_storage_decay_reduction(building_id: String) -> Dictionary:
	var building = get_building(building_id)
	if building.has("provides"):
		return building.provides.get("decay_reduction", {})
	return {}

func get_population_capacity(building_id: String) -> int:
	var building = get_building(building_id)
	if building.has("provides"):
		return building.provides.get("population_storage", 0)
	return 0

func get_admin_capacity(building_id: String) -> float:
	var building = get_building(building_id)
	if building.has("provides"):
		return building.provides.get("admin_capacity", 0.0)
	return 0.0

func get_caravan_capacity(building_id: String) -> int:
	var building = get_building(building_id)
	if building.has("provides"):
		return building.provides.get("caravan_capacity", 0)
	return 0

func get_max_per_city(building_id: String) -> int:
	"""Get the maximum number of this building allowed per city. 0 means unlimited."""
	var building = get_building(building_id)
	return building.get("max_per_city", 0)

func can_place_on_terrain(building_id: String, terrain_id: String) -> bool:
	var building = get_building(building_id)
	if not building.has("requirements"):
		return true
	
	var reqs = building.requirements
	
	# Check terrain exclusions
	if reqs.has("terrain_exclude"):
		if terrain_id in reqs.terrain_exclude:
			return false
	
	# Check terrain requirements
	if reqs.has("terrain_types"):
		if reqs.terrain_types.size() > 0:
			return terrain_id in reqs.terrain_types
	
	return true

func get_required_milestones(building_id: String) -> Array:
	var building = get_building(building_id)
	if building.has("requirements"):
		return building.requirements.get("milestones_required", [])
	return []

func get_all_building_ids() -> Array:
	return buildings.keys()

func get_buildings_by_category(category: String) -> Array:
	var result = []
	for id in buildings.keys():
		var building = buildings[id]
		if building.get("category", "") == category:
			result.append(id)
	return result

func get_on_construction_complete(building_id: String) -> Dictionary:
	"""Get resources/research granted when construction completes"""
	var building = get_building(building_id)
	return building.get("on_construction_complete", {})

func get_demolition_cost(building_id: String) -> Dictionary:
	"""Get the cost to demolish this building"""
	var building = get_building(building_id)
	return building.get("demolition_cost", {})

func get_disabled_consumption(building_id: String) -> Dictionary:
	"""Get any consumption that occurs while the building is disabled (e.g. maintenance)"""
	var building = get_building(building_id)
	return building.get("disabled_consumption", {})

func is_city_center(building_id: String) -> bool:
	"""Check if this building is a city center (cannot be demolished or disabled)"""
	var building = get_building(building_id)
	return building.get("is_city_center", false)

func get_upgrade_target(building_id: String) -> String:
	"""Get the building ID this can upgrade to, or empty string if none"""
	var building = get_building(building_id)
	var target = building.get("upgrades_to", null)
	if target == null or target == "":
		return ""
	return target

func can_upgrade(building_id: String) -> bool:
	"""Check if this building can be upgraded"""
	return get_upgrade_target(building_id) != ""

func get_upgrade_info(building_id: String) -> Dictionary:
	"""
	Get upgrade information for a building.
	Returns: {target: String, initial_cost: Dictionary, cost_per_turn: Dictionary, total_turns: int}
	or empty dict if no upgrade available.
	"""
	var target = get_upgrade_target(building_id)
	if target == "":
		return {}
	
	# Get construction info from target building
	var target_building = get_building(target)
	if target_building.is_empty():
		return {}
	
	var construction = target_building.get("construction", {})
	
	return {
		"target": target,
		"initial_cost": construction.get("initial_cost", {}),
		"cost_per_turn": construction.get("cost_per_turn", {}),
		"total_turns": construction.get("total_turns", 1)
	}

func get_building_capacity(building_id: String) -> int:
	"""Get the building capacity this building provides (how many constructions it enables)"""
	var building = get_building(building_id)
	if building.has("provides"):
		return building.provides.get("building_capacity", 0)
	return 0

func get_modifier_consumption(building_id: String) -> Array:
	"""Get modifier consumption rules for this building.
	Returns array of dicts: [{modifier_id, chance_percent, radius, transforms_to?}]"""
	var building = get_building(building_id)
	return building.get("modifier_consumption", [])

func get_required_adjacent_modifiers(building_id: String) -> Array:
	"""Get list of modifier IDs required adjacent to the building"""
	var building = get_building(building_id)
	if not building.has("requirements"):
		return []
	var reqs = building.requirements
	if not reqs.has("required_adjacent"):
		return []
	return reqs.required_adjacent.get("modifiers", [])
