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

func get_perk_name(perk_id: String) -> String:
	"""Get localized name for a perk."""
	return Registry.get_name_label("perk", perk_id)

# === Visibility Checking ===

func is_perk_visible(perk_id: String, game_state: Dictionary, player_perks: Array = []) -> bool:
	"""Check if a perk should be shown in the UI.
	Unlocked perks are always visible. For locked perks, checks the visibility
	field which uses the same condition types as unlock_conditions."""
	# Unlocked perks are always visible
	if perk_id in player_perks:
		return true

	var perk = get_perk(perk_id)
	if perk.is_empty():
		return false

	# Check visibility settings
	if perk.has("visibility"):
		var visibility = perk.visibility

		# Always visible perks
		if visibility.get("always_visible", false):
			return true

		# Check show_when conditions — any one passing is enough (OR logic)
		if visibility.has("show_when"):
			for condition in visibility.show_when:
				if _check_condition(condition, game_state):
					return true
			return false

	# Default: visible (no visibility field = always visible, backward compatible)
	return true

# === Condition Checking ===

func check_unlock_conditions(perk_id: String, game_state: Dictionary) -> bool:
	"""Check if all unlock conditions for a perk are met.
	Conditions are an array of objects, each with a 'type' and parameters.
	All conditions must pass (AND logic)."""
	var perk = get_perk(perk_id)
	var conditions = perk.get("unlock_conditions", [])

	if conditions.is_empty():
		return true

	# Check exclusive_with against already-owned perks
	var exclusive_with = perk.get("exclusive_with", [])
	var player_perks = game_state.get("player_perks", [])
	for ex_perk in exclusive_with:
		if ex_perk in player_perks:
			return false

	for condition in conditions:
		if not _check_condition(condition, game_state):
			return false

	return true

func _check_condition(condition: Dictionary, game_state: Dictionary) -> bool:
	"""Check a single condition against the game state."""
	var type = condition.get("type", "")

	match type:
		"turn":
			return _check_range(game_state.get("current_turn", 0), condition)

		"milestone_unlocked":
			var milestone = condition.get("milestone", "")
			return milestone in game_state.get("unlocked_milestones", [])

		"milestone_locked":
			var milestone = condition.get("milestone", "")
			return milestone not in game_state.get("unlocked_milestones", [])

		"building_count":
			var building = condition.get("building", "")
			var count = game_state.get("building_counts", {}).get(building, 0)
			return _check_range(count, condition)

		"tiles_by_terrain":
			var terrain = condition.get("terrain", "")
			var count = game_state.get("terrain_counts", {}).get(terrain, 0)
			return _check_range(count, condition)

		"tiles_by_modifier":
			var modifier = condition.get("modifier", "")
			var count = game_state.get("modifier_counts", {}).get(modifier, 0)
			return _check_range(count, condition)

		"unit_count":
			var unit = condition.get("unit", "")
			var count = game_state.get("unit_counts", {}).get(unit, 0)
			return _check_range(count, condition)

		"resource_production":
			var resource = condition.get("resource", "")
			var amount = game_state.get("resource_production", {}).get(resource, 0.0)
			return _check_range(amount, condition)

		"resource_stored":
			var resource = condition.get("resource", "")
			var amount = game_state.get("resource_stored", {}).get(resource, 0.0)
			return _check_range(amount, condition)

		"city_population":
			# Any single city must have population in range
			var populations = game_state.get("city_populations", [])
			for pop in populations:
				if _check_range(pop, condition):
					return true
			return populations.is_empty() and not condition.has("min")

		"total_population":
			var total = game_state.get("total_population", 0)
			return _check_range(total, condition)

		"city_count":
			var count = game_state.get("city_count", 0)
			return _check_range(count, condition)

		"total_tiles":
			var count = game_state.get("total_tiles", 0)
			return _check_range(count, condition)

		_:
			push_warning("Unknown perk condition type: %s" % type)
			return true

func _check_range(value: float, condition: Dictionary) -> bool:
	"""Check if a value falls within the min/max range defined in a condition."""
	if condition.has("min") and value < condition.min:
		return false
	if condition.has("max") and value > condition.max:
		return false
	return true

# === Game State Builder ===

func build_game_state_for_player(player: Player, city_manager, unit_manager, world_query, current_turn: int, last_report = null) -> Dictionary:
	"""Build a comprehensive game state snapshot for perk condition checking."""
	var state := {}
	state["current_turn"] = current_turn
	state["unlocked_milestones"] = Registry.tech.get_unlocked_milestones()
	state["player_perks"] = player.civilization_perks.duplicate()

	# Count buildings across all player cities
	var building_counts := {}
	var resource_stored := {}
	var city_populations: Array[float] = []
	var total_population: float = 0.0
	var city_count: int = 0
	var total_tiles: int = 0
	var terrain_counts := {}
	var modifier_counts := {}

	for city in player.get_all_cities():
		if city.is_abandoned:
			continue
		city_count += 1
		total_tiles += city.tiles.size()

		# Count buildings
		for instance in city.building_instances.values():
			var bid = instance.building_id
			building_counts[bid] = building_counts.get(bid, 0) + 1

		# Count stored resources
		for res_id in Registry.resources.get_all_resource_ids():
			var amount = city.get_total_resource(res_id)
			if amount > 0:
				resource_stored[res_id] = resource_stored.get(res_id, 0.0) + amount

		# City population
		var pop = city.get_total_resource("population")
		city_populations.append(pop)
		total_population += pop

		# Count terrain and modifiers on owned tiles
		if world_query:
			for coord in city.tiles.keys():
				var terrain_data = world_query.get_terrain_data(coord)
				if terrain_data:
					var tid = terrain_data.terrain_id
					terrain_counts[tid] = terrain_counts.get(tid, 0) + 1
					for mod_id in terrain_data.modifiers:
						modifier_counts[mod_id] = modifier_counts.get(mod_id, 0) + 1

	state["building_counts"] = building_counts
	state["terrain_counts"] = terrain_counts
	state["modifier_counts"] = modifier_counts
	state["resource_stored"] = resource_stored
	state["city_populations"] = city_populations
	state["total_population"] = total_population
	state["city_count"] = city_count
	state["total_tiles"] = total_tiles

	# Count units by type
	var unit_counts := {}
	if unit_manager:
		for unit in unit_manager.get_all_units():
			if unit.owner_id == player.player_id:
				var utype = unit.unit_type
				unit_counts[utype] = unit_counts.get(utype, 0) + 1
	state["unit_counts"] = unit_counts

	# Resource production from last turn report
	var resource_production := {}
	if last_report:
		for city_id in last_report.city_reports.keys():
			var city_report = last_report.city_reports[city_id]
			if city_report.has_method("get_net_production"):
				var net = city_report.get_net_production()
				for res_id in net.keys():
					resource_production[res_id] = resource_production.get(res_id, 0.0) + net[res_id]
	state["resource_production"] = resource_production

	return state

# === Effect Query Helpers ===

func get_production_multiplier(player: Player, building_id: String) -> float:
	"""Returns the combined production multiplier for a building from all player perks.
	Uses multiplicative stacking."""
	if not player:
		return 1.0
	var multiplier := 1.0
	for perk_id in player.civilization_perks:
		var perk = get_perk(perk_id)
		var mods = perk.get("effects", {}).get("building_modifiers", {})
		if mods.has(building_id):
			multiplier *= mods[building_id].get("production_multiplier", 1.0)
	return multiplier

func get_construction_cost_multiplier(player: Player, building_id: String) -> float:
	"""Returns the combined construction cost multiplier for a building from all player perks.
	Uses multiplicative stacking."""
	if not player:
		return 1.0
	var multiplier := 1.0
	for perk_id in player.civilization_perks:
		var perk = get_perk(perk_id)
		var mods = perk.get("effects", {}).get("building_modifiers", {})
		if mods.has(building_id):
			multiplier *= mods[building_id].get("construction_cost_multiplier", 1.0)
	return multiplier

func get_global_yield_bonuses(player: Player) -> Dictionary:
	"""Returns aggregated global yield bonuses {resource_id: total_bonus} from all player perks."""
	var bonuses := {}
	if not player:
		return bonuses
	for perk_id in player.civilization_perks:
		var perk = get_perk(perk_id)
		var global_yields = perk.get("effects", {}).get("yield_bonuses", {}).get("global", {})
		for res_id in global_yields.keys():
			bonuses[res_id] = bonuses.get(res_id, 0.0) + global_yields[res_id]
	return bonuses

func get_terrain_yield_bonuses(player: Player, terrain_id: String) -> Dictionary:
	"""Returns aggregated per-terrain yield bonuses for a specific terrain."""
	var bonuses := {}
	if not player:
		return bonuses
	for perk_id in player.civilization_perks:
		var perk = get_perk(perk_id)
		var per_terrain = perk.get("effects", {}).get("yield_bonuses", {}).get("per_terrain_type", {})
		if per_terrain.has(terrain_id):
			for res_id in per_terrain[terrain_id].keys():
				bonuses[res_id] = bonuses.get(res_id, 0.0) + per_terrain[terrain_id][res_id]
	return bonuses

func get_admin_distance_modifier(player: Player) -> float:
	"""Returns the sum of all admin_distance_multiplier_modifier values from player perks."""
	if not player:
		return 0.0
	var total := 0.0
	for perk_id in player.civilization_perks:
		var perk = get_perk(perk_id)
		total += perk.get("effects", {}).get("admin_distance_multiplier_modifier", 0.0)
	return total

func get_unlocked_unique_buildings(player: Player) -> Array:
	"""Returns all building IDs unlocked by player perks."""
	var buildings: Array = []
	if not player:
		return buildings
	for perk_id in player.civilization_perks:
		var perk = get_perk(perk_id)
		var unique = perk.get("effects", {}).get("unlocks_unique_buildings", [])
		for bid in unique:
			if bid not in buildings:
				buildings.append(bid)
	return buildings

func is_perk_locked_building(building_id: String) -> bool:
	"""Check if a building is only available through perk unlocks."""
	for perk_id in perks.keys():
		var unique = perks[perk_id].get("effects", {}).get("unlocks_unique_buildings", [])
		if building_id in unique:
			return true
	return false
