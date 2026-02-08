extends RefCounted
class_name BuildingRegistry

# Stores all building definitions.
# Production uses unified array format: produces/consumes are arrays of entry objects.
# Storage uses pool model: provides.storage is an array of pool definitions.

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

# === Construction ===

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

# === Production & Consumption (New Array Format) ===

func get_produces(building_id: String) -> Array:
	"""Get the produces array. Each entry: {resource, quantity, [branch]}"""
	var building = get_building(building_id)
	var production = building.get("production", {})
	return production.get("produces", [])

func get_consumes(building_id: String) -> Array:
	"""Get the consumes array. Each entry: {resource|tag, quantity, [distance_cost]}"""
	var building = get_building(building_id)
	var production = building.get("production", {})
	return production.get("consumes", [])

func get_penalty(building_id: String) -> Array:
	"""Get per-turn penalty array. Each entry: {resource, quantity}"""
	var building = get_building(building_id)
	var penalty = building.get("per_turn_penalty", [])
	if penalty is Array:
		return penalty
	# Legacy dict format fallback
	if penalty is Dictionary:
		var result := []
		for res_id in penalty.keys():
			result.append({"resource": res_id, "quantity": penalty[res_id]})
		return result
	return []

# === Storage Pools ===

func get_storage_pools(building_id: String) -> Array:
	"""Get storage pool definitions. Each pool: {capacity, accepted_resources?, accepted_tags?, decay_reduction?}"""
	var building = get_building(building_id)
	var provides = building.get("provides", {})
	return provides.get("storage", [])

func get_total_storage_for_resource(building_id: String, resource_id: String) -> float:
	"""Get total storage capacity across all pools that can accept this resource."""
	var total := 0.0
	for pool in get_storage_pools(building_id):
		if _pool_accepts_resource(pool, resource_id):
			total += pool.get("capacity", 0.0)
	return total

func _pool_accepts_resource(pool: Dictionary, resource_id: String) -> bool:
	"""Check if a storage pool definition accepts a specific resource."""
	var accepted_resources = pool.get("accepted_resources", [])
	if resource_id in accepted_resources:
		return true
	
	var accepted_tags = pool.get("accepted_tags", [])
	for tag in accepted_tags:
		if Registry.resources.has_tag(resource_id, tag):
			return true
	
	return false

func get_pool_decay_reduction(pool: Dictionary, resource_id: String) -> float:
	"""Get decay reduction for a resource in a specific pool definition."""
	var decay_reduction = pool.get("decay_reduction", {})
	return decay_reduction.get(resource_id, 1.0)

# === Adjacency & Terrain ===

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

func get_modifier_consumption(building_id: String) -> Array:
	"""Get modifier consumption rules for this building.
	Returns array of dicts: [{modifier_id, chance_percent, radius, transforms_to?}]"""
	var building = get_building(building_id)
	return building.get("modifier_consumption", [])

func get_adjacency_decay_bonuses(building_id: String) -> Array:
	"""Get adjacency-based decay reduction bonuses for this building.
	Returns array of dicts: [{source_type, source_id, radius, requires_active, decay_reduction}]"""
	var building = get_building(building_id)
	return building.get("adjacency_decay_bonuses", [])

# === Placement & Requirements ===

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

func get_required_adjacent_modifiers(building_id: String) -> Array:
	"""Get list of modifier IDs required adjacent to the building"""
	var building = get_building(building_id)
	if not building.has("requirements"):
		return []
	var reqs = building.requirements
	if not reqs.has("required_adjacent"):
		return []
	return reqs.required_adjacent.get("modifiers", [])

# === Building Properties ===

func allows_units_on_tile(building_id: String) -> bool:
	var building = get_building(building_id)
	return building.get("can_units_stand", false)

func get_max_per_city(building_id: String) -> int:
	"""Get the maximum number of this building allowed per city. 0 means unlimited."""
	var building = get_building(building_id)
	return building.get("max_per_city", 0)

func is_city_center(building_id: String) -> bool:
	"""Check if this building is a city center (cannot be demolished or disabled)"""
	var building = get_building(building_id)
	return building.get("is_city_center", false)

func get_building_capacity(building_id: String) -> int:
	"""Get the building capacity this building provides (how many constructions it enables)"""
	var building = get_building(building_id)
	if building.has("provides"):
		return building.provides.get("building_capacity", 0)
	return 0

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

func get_caravan_capacity(building_id: String) -> int:
	var building = get_building(building_id)
	if building.has("provides"):
		return building.provides.get("caravan_capacity", 0)
	return 0

# === Upgrades ===

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
	"""Get upgrade information for a building."""
	var target = get_upgrade_target(building_id)
	if target == "":
		return {}
	
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

# === Query Helpers ===

func get_all_building_ids() -> Array:
	return buildings.keys()

func get_buildings_by_category(category: String) -> Array:
	var result = []
	for id in buildings.keys():
		var building = buildings[id]
		if building.get("category", "") == category:
			result.append(id)
	return result

func produces_resource(building_id: String, resource_id: String) -> bool:
	"""Check if a building produces a specific resource."""
	for entry in get_produces(building_id):
		if entry.get("resource", "") == resource_id:
			return true
	return false

func consumes_resource(building_id: String, resource_id: String) -> bool:
	"""Check if a building consumes a specific resource (by ID, not tag)."""
	for entry in get_consumes(building_id):
		if entry.get("resource", "") == resource_id:
			return true
	return false

func get_buildings_that_produce(resource_id: String) -> Array:
	"""Get all building IDs that produce a specific resource."""
	var result := []
	for id in buildings.keys():
		if produces_resource(id, resource_id):
			result.append(id)
	return result

# === Backward Compatibility Wrappers ===
# TODO: Remove these in Phase 6 cleanup after all consumers are updated.

func get_production_per_turn(building_id: String) -> Dictionary:
	"""DEPRECATED: Use get_produces() instead. Returns old-style dict for backward compat."""
	var result := {}
	for entry in get_produces(building_id):
		var res_id = entry.get("resource", "")
		if res_id != "" and not entry.has("branch"):
			# Only include non-branch entries (old format didn't have branch entries here)
			result[res_id] = entry.get("quantity", 0.0)
	return result

func get_consumption_per_turn(building_id: String) -> Dictionary:
	"""DEPRECATED: Use get_consumes() instead. Returns old-style dict for backward compat."""
	var result := {}
	for entry in get_consumes(building_id):
		var res_id = entry.get("resource", "")
		if res_id != "" and res_id != "admin_capacity":
			# Exclude admin_capacity (was separate in old format)
			result[res_id] = entry.get("quantity", 0.0)
	return result

func get_branch_specific_research(building_id: String) -> Dictionary:
	"""DEPRECATED: Research is now in produces array with branch field."""
	var result := {}
	for entry in get_produces(building_id):
		if entry.get("resource", "") == "research" and entry.has("branch"):
			result[entry.branch] = entry.get("quantity", 0.0)
	return result

func get_admin_cost(building_id: String, distance: int) -> float:
	"""DEPRECATED: Admin cost is now a consumes entry with distance_cost."""
	for entry in get_consumes(building_id):
		if entry.get("resource", "") == "admin_capacity":
			var base = entry.get("quantity", 1.0)
			var dist_cost = entry.get("distance_cost", {})
			var multiplier = dist_cost.get("multiplier", 0.0)
			return base + (distance * distance * multiplier)
	return 0.0

func get_admin_capacity(building_id: String) -> float:
	"""DEPRECATED: Admin capacity is now a produces entry."""
	for entry in get_produces(building_id):
		if entry.get("resource", "") == "admin_capacity":
			return entry.get("quantity", 0.0)
	return 0.0

func get_storage_provided(building_id: String) -> Dictionary:
	"""DEPRECATED: Use get_storage_pools() instead. Returns old-style flat dict."""
	var result := {}
	for pool in get_storage_pools(building_id):
		var capacity = pool.get("capacity", 0.0)
		var accepted = pool.get("accepted_resources", [])
		var accepted_tags = pool.get("accepted_tags", [])
		
		# For tag-based pools, get all matching resources
		if not accepted_tags.is_empty():
			for tag in accepted_tags:
				for res_id in Registry.resources.get_resources_by_tag(tag):
					if not result.has(res_id):
						result[res_id] = 0.0
					result[res_id] += capacity
		
		# For explicit resource pools, split capacity equally
		if not accepted.is_empty():
			for res_id in accepted:
				if not result.has(res_id):
					result[res_id] = 0.0
				result[res_id] += capacity
	
	return result

func get_storage_decay_reduction(building_id: String) -> Dictionary:
	"""DEPRECATED: Decay reduction is now per-pool."""
	var result := {}
	for pool in get_storage_pools(building_id):
		var decay_red = pool.get("decay_reduction", {})
		for res_id in decay_red.keys():
			result[res_id] = decay_red[res_id]
	return result

func get_population_capacity(building_id: String) -> int:
	"""DEPRECATED: Population capacity is now a storage pool with population tag."""
	var total := 0
	for pool in get_storage_pools(building_id):
		var accepted_tags = pool.get("accepted_tags", [])
		if "population" in accepted_tags:
			total += int(pool.get("capacity", 0))
	return total
