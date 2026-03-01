extends RefCounted
class_name OriginRegistry

## Stores all origin definitions.
## Origins define how a player (or AI empire) begins the game:
## starting location requirements, units, technology, perks, and optionally
## settlements with buildings. Data-driven via JSON files in data/origins/.

var origins: Dictionary = {}  # origin_id -> Dictionary (JSON data)

# Pre-built indexes
var _tag_index: Dictionary = {}  # tag -> Array[String] of origin IDs

func load_data():
	var dir = DirAccess.open("res://data/origins")
	if not dir:
		push_warning("No origins directory found — using defaults")
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".json"):
			var origin_id = file_name.trim_suffix(".json")
			var origin_data = _load_origin_file("res://data/origins/" + file_name)

			if origin_data:
				origins[origin_id] = origin_data
				_index_tags(origin_id, origin_data)
				print("Loaded origin: ", origin_id)

		file_name = dir.get_next()

	dir.list_dir_end()
	print("Loaded %d origins" % origins.size())

func _load_origin_file(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open origin file: " + path)
		return {}

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)

	if error != OK:
		push_error("Failed to parse origin JSON: " + path)
		return {}

	return json.data

func _index_tags(origin_id: String, data: Dictionary):
	"""Build tag index for fast lookups"""
	var tags = data.get("tags", [])
	for tag in tags:
		if not _tag_index.has(tag):
			_tag_index[tag] = []
		_tag_index[tag].append(origin_id)

func validate():
	"""Validate all references after all registries are loaded.
	Logs warnings for missing references — does NOT crash (mods may have partial data)."""
	for origin_id in origins:
		var data: Dictionary = origins[origin_id]
		var prefix = "[Origin: %s]" % origin_id

		# Validate tech milestones
		var tech: Dictionary = data.get("tech", {})
		for milestone_id in tech.get("milestones", []):
			if not Registry.tech.milestone_exists(milestone_id):
				push_warning("%s Milestone '%s' not found in TechRegistry" % [prefix, milestone_id])

		# Validate tech branch_progress branches
		for branch_id in tech.get("branch_progress", {}):
			if not Registry.tech.branch_exists(branch_id):
				push_warning("%s Branch '%s' not found in TechRegistry" % [prefix, branch_id])

		# Validate perks
		for perk_id in data.get("perks", []):
			if not Registry.perks.has_perk(perk_id):
				push_warning("%s Perk '%s' not found in PerkRegistry" % [prefix, perk_id])

		# Validate units
		for unit_entry in data.get("units", []):
			var unit_type: String = unit_entry.get("unit_type", "")
			if not Registry.units.has_unit(unit_type):
				push_warning("%s Unit type '%s' not found in UnitRegistry" % [prefix, unit_type])

		# Validate settlements
		for settlement_entry in data.get("settlements", []):
			var settlement_type: String = settlement_entry.get("settlement_type", "")
			if not Registry.settlements.type_exists(settlement_type):
				push_warning("%s Settlement type '%s' not found in SettlementRegistry" % [prefix, settlement_type])

			for building_entry in settlement_entry.get("buildings", []):
				var building_id: String = building_entry.get("building_id", "")
				if not Registry.buildings.building_exists(building_id):
					push_warning("%s Building '%s' not found in BuildingRegistry" % [prefix, building_id])

		# Validate terrain_conditions references
		var spawn: Dictionary = data.get("spawn", {})
		for condition in spawn.get("terrain_conditions", []):
			var cond_type: String = condition.get("type", "")
			match cond_type:
				"terrain", "center_terrain":
					var terrain_id: String = condition.get("terrain_id", "")
					if not Registry.terrains.has_terrain(terrain_id):
						push_warning("%s Terrain '%s' not found in TerrainRegistry" % [prefix, terrain_id])
				"modifier":
					var modifier_id: String = condition.get("modifier_id", "")
					if not Registry.modifiers.modifier_exists(modifier_id):
						push_warning("%s Modifier '%s' not found in ModifierRegistry" % [prefix, modifier_id])

		# Validate force_modifiers references
		for force_mod in spawn.get("force_modifiers", []):
			var modifier_id: String = force_mod.get("modifier_id", "")
			if not Registry.modifiers.modifier_exists(modifier_id):
				push_warning("%s Force modifier '%s' not found in ModifierRegistry" % [prefix, modifier_id])
			for terrain_id in force_mod.get("terrain_filter", []):
				if not Registry.terrains.has_terrain(terrain_id):
					push_warning("%s Terrain filter '%s' not found in TerrainRegistry" % [prefix, terrain_id])

# === Core API ===

func get_origin(origin_id: String) -> Dictionary:
	"""Get the full origin definition"""
	if not origins.has(origin_id):
		push_warning("Origin not found: " + origin_id)
		return {}
	return origins[origin_id]

func has_origin(origin_id: String) -> bool:
	return origins.has(origin_id)

func get_all_origin_ids() -> Array[String]:
	var result: Array[String] = []
	for key in origins.keys():
		result.append(key)
	return result

func get_origins_by_tag(tag: String) -> Array[String]:
	"""Get all origin IDs that have a specific tag"""
	var result: Array[String] = []
	if _tag_index.has(tag):
		for origin_id in _tag_index[tag]:
			result.append(origin_id)
	return result

# === Convenience Accessors ===

func get_spawn_config(origin_id: String) -> Dictionary:
	var data = get_origin(origin_id)
	return data.get("spawn", {})

func get_terrain_conditions(origin_id: String) -> Array:
	var spawn = get_spawn_config(origin_id)
	return spawn.get("terrain_conditions", [])

func get_starting_units(origin_id: String) -> Array:
	var data = get_origin(origin_id)
	return data.get("units", [])

func get_starting_tech(origin_id: String) -> Dictionary:
	var data = get_origin(origin_id)
	return data.get("tech", {})

func get_starting_perks(origin_id: String) -> Array:
	var data = get_origin(origin_id)
	return data.get("perks", [])

func get_starting_settlements(origin_id: String) -> Array:
	var data = get_origin(origin_id)
	return data.get("settlements", [])

func get_min_turns(origin_id: String) -> int:
	var spawn = get_spawn_config(origin_id)
	return spawn.get("min_turns", 0)

func get_min_radius(origin_id: String) -> int:
	var spawn = get_spawn_config(origin_id)
	return spawn.get("min_radius", 0)
