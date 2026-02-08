extends RefCounted
class_name ResourceRegistry

# Stores all resource definitions using the tag-based schema.
# Resources are identified by tags rather than a fixed "type" field.
# Engine-coded tags: storable, flow, cap, population, decaying, tradeable, knowledge
# Grouping tags (no engine logic): raw_material, manufactured, crafted, luxury, basic, grain, etc.

var resources := {}  # Dictionary<String, Dictionary>

# Pre-built indexes for fast tag lookups
var _tag_index := {}  # tag -> Array[String] of resource IDs

func load_data():
	var dir = DirAccess.open("res://data/resources")
	if not dir:
		push_error("Failed to open resources directory")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".json"):
			var resource_id = file_name.trim_suffix(".json")
			var resource_data = _load_resource_file("res://data/resources/" + file_name)
			
			if resource_data:
				resources[resource_id] = resource_data
				_index_tags(resource_id, resource_data)
				print("Loaded resource: ", resource_id)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	print("Loaded %d resources" % resources.size())

func _load_resource_file(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open resource file: " + path)
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	
	if error != OK:
		push_error("Failed to parse resource JSON: " + path)
		return {}
	
	return json.data

func _index_tags(resource_id: String, data: Dictionary):
	"""Build tag index for fast lookups"""
	var tags = data.get("tags", [])
	for tag in tags:
		if not _tag_index.has(tag):
			_tag_index[tag] = []
		_tag_index[tag].append(resource_id)

# === Core Tag-Based API ===

func get_resource(id: String) -> Dictionary:
	"""Get the full resource definition"""
	return resources.get(id, {})

func has_resource(id: String) -> bool:
	return resources.has(id)

func get_all_resource_ids() -> Array:
	return resources.keys()

func get_tags(id: String) -> Array:
	"""Get all tags for a resource"""
	var res = get_resource(id)
	return res.get("tags", [])

func has_tag(id: String, tag: String) -> bool:
	"""Check if a resource has a specific tag"""
	var res = get_resource(id)
	var tags = res.get("tags", [])
	return tag in tags

func get_resources_by_tag(tag: String) -> Array[String]:
	"""Get all resource IDs that have a specific tag"""
	var result: Array[String] = []
	if _tag_index.has(tag):
		for res_id in _tag_index[tag]:
			result.append(res_id)
	return result

func get_resources_with_all_tags(required_tags: Array) -> Array[String]:
	"""Get all resource IDs that have ALL specified tags"""
	var result: Array[String] = []
	for res_id in resources.keys():
		var tags = get_tags(res_id)
		var has_all = true
		for tag in required_tags:
			if tag not in tags:
				has_all = false
				break
		if has_all:
			result.append(res_id)
	return result

func get_resources_with_any_tag(tag_list: Array) -> Array[String]:
	"""Get all resource IDs that have ANY of the specified tags"""
	var found := {}
	for tag in tag_list:
		if _tag_index.has(tag):
			for res_id in _tag_index[tag]:
				found[res_id] = true
	var result: Array[String] = []
	for res_id in found.keys():
		result.append(res_id)
	return result

func resource_matches_tag(resource_id: String, tag: String) -> bool:
	"""Check if a resource has a specific tag. Used for tag-based consumption/storage matching."""
	return has_tag(resource_id, tag)

# === Specific Config Accessors ===

func get_decay_rate(id: String) -> float:
	"""Get the base decay rate per turn. Returns 0.0 if resource doesn't decay."""
	if not has_tag(id, "decaying"):
		return 0.0
	var res = get_resource(id)
	var decay_config = res.get("decay", {})
	return decay_config.get("rate_per_turn", 0.0)

func get_cap_config(id: String) -> Dictionary:
	"""Get cap configuration for a cap resource. Returns empty dict if not a cap."""
	if not has_tag(id, "cap"):
		return {}
	var res = get_resource(id)
	return res.get("cap", {})

func get_cap_mode(id: String) -> String:
	"""Get cap mode: 'soft' or 'hard'. Returns '' if not a cap."""
	var config = get_cap_config(id)
	return config.get("mode", "")

func get_cap_penalties(id: String) -> Array:
	"""Get cap penalty definitions. Returns empty array if not a cap."""
	var config = get_cap_config(id)
	return config.get("penalties", [])

func get_knowledge_config(id: String) -> Dictionary:
	"""Get knowledge configuration. Returns empty dict if not a knowledge resource."""
	if not has_tag(id, "knowledge"):
		return {}
	var res = get_resource(id)
	return res.get("knowledge", {})

func get_accepted_branches(id: String) -> Array:
	"""Get which tech branches accept this knowledge resource. Returns ['all'] for generic."""
	var config = get_knowledge_config(id)
	return config.get("accepted_by_branches", [])

func get_visual(id: String) -> Dictionary:
	"""Get visual properties (icon, color)"""
	var res = get_resource(id)
	return res.get("visual", {})

func get_icon_path(id: String) -> String:
	var visual = get_visual(id)
	return visual.get("icon", "")

func get_color(id: String) -> String:
	var visual = get_visual(id)
	return visual.get("color", "#FFFFFF")

func get_required_milestones(id: String) -> Array:
	"""Get the milestones required to unlock this resource"""
	var res = get_resource(id)
	return res.get("milestones_required", [])

func is_resource_unlocked(id: String) -> bool:
	"""Check if a resource is unlocked (all required milestones are unlocked)"""
	var milestones = get_required_milestones(id)
	if milestones.is_empty():
		return true
	for milestone_id in milestones:
		if not Registry.tech.is_milestone_unlocked(milestone_id):
			return false
	return true

# === Backward Compatibility Wrappers ===
# These map old API calls to the new tag-based system.
# TODO: Remove these in Phase 6 cleanup after all consumers are updated.

func is_storable(id: String) -> bool:
	return has_tag(id, "storable")

func is_flow(id: String) -> bool:
	return has_tag(id, "flow")

func has_flag(id: String, flag_name: String) -> bool:
	"""Legacy: Check if a resource has a specific flag. Maps to tag check."""
	return has_tag(id, flag_name)

func is_population_resource(id: String) -> bool:
	return has_tag(id, "population")

func is_decaying(id: String) -> bool:
	return has_tag(id, "decaying")

func is_tradeable(id: String) -> bool:
	return has_tag(id, "tradeable")

func get_category(id: String) -> String:
	"""Legacy: Get the category of a resource. Now derived from tags."""
	# Check for category-like tags
	for tag in ["basic", "raw_material", "manufactured", "crafted", "luxury"]:
		if has_tag(id, tag):
			return tag
	return ""

func get_all_population_resources() -> Array[String]:
	"""Get all resources that have the population tag"""
	return get_resources_by_tag("population")
