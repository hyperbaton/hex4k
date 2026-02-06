extends RefCounted
class_name TechRegistry

# Stores tech branches and milestones
var branches := {}
var milestones := {}

# Track player's research progress
var branch_progress := {}  # branch_id -> float (research points)
var unlocked_milestones := []  # Array of milestone_ids
var preferred_research_branch: String = ""  # Branch to direct generic research to (empty = random)

func load_data():
	load_branches()
	load_milestones()
	initialize_progress()

func load_branches():
	var path = "res://data/tech/branches.json"
	if not FileAccess.file_exists(path):
		push_error("Tech branches file not found: " + path)
		return
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open tech branches: " + path)
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	
	if error != OK:
		push_error("Failed to parse branches JSON: " + json.get_error_message())
		return
	
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Branches JSON root must be a dictionary")
		return
	
	branches = data
	print("Loaded ", branches.size(), " tech branches")

func load_milestones():
	"""Load all milestone files from the milestones directory"""
	var dir_path = "res://data/tech/milestones"
	var dir = DirAccess.open(dir_path)
	
	if not dir:
		push_error("Failed to open milestones directory: " + dir_path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var milestone_id = file_name.get_basename()  # Remove .json extension
			var file_path = dir_path + "/" + file_name
			
			var milestone_data = _load_json_file(file_path)
			if not milestone_data.is_empty():
				milestones[milestone_id] = milestone_data
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	print("Loaded ", milestones.size(), " tech milestones")

func _load_json_file(path: String) -> Dictionary:
	"""Helper to load a single JSON file"""
	if not FileAccess.file_exists(path):
		push_error("File not found: " + path)
		return {}
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open file: " + path)
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	
	if error != OK:
		push_error("Failed to parse JSON in %s: %s" % [path, json.get_error_message()])
		return {}
	
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("JSON root must be a dictionary in: " + path)
		return {}
	
	return data

func initialize_progress():
	for branch_id in branches.keys():
		branch_progress[branch_id] = 0.0

func get_branch(branch_id: String) -> Dictionary:
	if not branches.has(branch_id):
		push_warning("Branch not found: " + branch_id)
		return {}
	return branches[branch_id]

func get_branch_name(branch_id: String) -> String:
	var branch = get_branch(branch_id)
	return branch.get("name", branch_id.capitalize())

func get_branch_color(branch_id: String) -> Color:
	var branch = get_branch(branch_id)
	var color_str = branch.get("color", "#FFFFFF")
	return Color(color_str)

func get_branch_icon_path(branch_id: String) -> String:
	"""Get the path to the branch's icon"""
	var branch = get_branch(branch_id)
	return branch.get("icon", "")

func get_branch_starts_from(branch_id: String) -> Dictionary:
	"""Returns {branch, milestone} or empty dict if root branch"""
	var branch = get_branch(branch_id)
	var starts_from = branch.get("starts_from", null)
	if starts_from == null:
		return {}
	return starts_from

func get_milestone(milestone_id: String) -> Dictionary:
	if not milestones.has(milestone_id):
		push_warning("Milestone not found: " + milestone_id)
		return {}
	return milestones[milestone_id]

func get_milestone_name(milestone_id: String) -> String:
	var milestone = get_milestone(milestone_id)
	return milestone.get("name", milestone_id)

func get_milestone_level(milestone_id: String) -> float:
	"""Get the level at which this milestone is unlocked (position on branch)"""
	var milestone = get_milestone(milestone_id)
	if milestone.has("requirements") and milestone.requirements.size() > 0:
		# Return the first requirement's level (primary branch position)
		return milestone.requirements[0].get("level", 0.0)
	return 0.0

func get_milestone_branch(milestone_id: String) -> String:
	"""Get the branch this milestone belongs to"""
	var milestone = get_milestone(milestone_id)
	return milestone.get("branch", "")

func get_milestone_branches(milestone_id: String) -> Array[String]:
	"""Get all branches this milestone belongs to (for compatibility, returns array with single branch)"""
	var result: Array[String] = []
	var branch = get_milestone_branch(milestone_id)
	if branch != "":
		result.append(branch)
	return result

func get_milestones_for_branch(branch_id: String) -> Array[String]:
	"""Get all milestones that belong to a specific branch"""
	var result: Array[String] = []
	for milestone_id in milestones.keys():
		var milestone = milestones[milestone_id]
		if milestone.get("branch", "") == branch_id:
			result.append(milestone_id)
	return result

func branch_exists(branch_id: String) -> bool:
	return branches.has(branch_id)

func milestone_exists(milestone_id: String) -> bool:
	return milestones.has(milestone_id)

func get_branch_progress(branch_id: String) -> float:
	return branch_progress.get(branch_id, 0.0)

func set_branch_progress(branch_id: String, progress: float):
	"""Set branch progress directly (useful for testing)"""
	if branch_exists(branch_id):
		branch_progress[branch_id] = progress
		check_milestone_unlocks()

func add_research(branch_id: String, points: float):
	if not branch_exists(branch_id):
		push_warning("Cannot add research to non-existent branch: " + branch_id)
		return
	
	branch_progress[branch_id] = branch_progress.get(branch_id, 0.0) + points
	check_milestone_unlocks()

func is_milestone_unlocked(milestone_id: String) -> bool:
	return milestone_id in unlocked_milestones

func can_unlock_milestone(milestone_id: String) -> bool:
	if is_milestone_unlocked(milestone_id):
		return false
	
	var milestone = get_milestone(milestone_id)
	if not milestone.has("requirements"):
		return false
	
	for req in milestone.requirements:
		var branch_id = req.get("branch", "")
		var level = req.get("level", 0.0)
		
		if get_branch_progress(branch_id) < level:
			return false
	
	return true

func check_milestone_unlocks():
	for milestone_id in milestones.keys():
		if not is_milestone_unlocked(milestone_id) and can_unlock_milestone(milestone_id):
			unlock_milestone(milestone_id)

func unlock_milestone(milestone_id: String):
	if milestone_id in unlocked_milestones:
		return
	
	unlocked_milestones.append(milestone_id)
	print("Unlocked milestone: ", milestone_id)
	
	# TODO: Emit signal for UI update

func is_milestone_visible(milestone_id: String) -> bool:
	if is_milestone_unlocked(milestone_id):
		return true
	
	var milestone = get_milestone(milestone_id)
	
	# Check visibility settings
	if milestone.has("visibility"):
		# Always visible milestones
		if milestone.visibility.get("always_visible", false):
			return true
		
		# Check show_when conditions
		if milestone.visibility.has("show_when"):
			for condition in milestone.visibility.show_when:
				var branch_id = condition.get("branch", "")
				var level = condition.get("level", 0.0)
				
				if get_branch_progress(branch_id) >= level:
					return true
			return false
	
	return false

func is_branch_unlocked(branch_id: String) -> bool:
	"""Check if a branch is accessible (parent milestone unlocked or root branch)"""
	var branch = get_branch(branch_id)
	var starts_from = branch.get("starts_from", null)
	
	# Root branches are always unlocked
	if starts_from == null:
		return true
	
	# Check if parent milestone is unlocked
	var parent_milestone = starts_from.get("milestone", "")
	return is_milestone_unlocked(parent_milestone)

func is_branch_visible(branch_id: String) -> bool:
	"""Check if a branch should be visible based on visibility settings"""
	var branch = get_branch(branch_id)
	if branch.is_empty():
		return false
	
	# Check explicit visibility settings first
	if branch.has("visibility"):
		var visibility = branch.visibility
		
		# Always visible branches
		if visibility.get("always_visible", false):
			return true
		
		# Check show_when conditions (same as milestones)
		if visibility.has("show_when"):
			for condition in visibility.show_when:
				var req_branch = condition.get("branch", "")
				var req_level = condition.get("level", 0.0)
				
				if get_branch_progress(req_branch) >= req_level:
					return true
	
	# For branches with starts_from, check if parent milestone is visible
	var starts_from = branch.get("starts_from", null)
	if starts_from != null:
		var parent_milestone = starts_from.get("milestone", "")
		return is_milestone_visible(parent_milestone)
	
	# Default: not visible (unless explicitly set)
	return false

func get_root_branches() -> Array[String]:
	"""Get branches that don't spawn from other branches"""
	var result: Array[String] = []
	for branch_id in branches.keys():
		var branch = branches[branch_id]
		if branch.get("starts_from", null) == null:
			result.append(branch_id)
	return result

func get_child_branches(branch_id: String) -> Array[String]:
	"""Get branches that spawn from this branch"""
	var result: Array[String] = []
	for child_id in branches.keys():
		var child = branches[child_id]
		var starts_from = child.get("starts_from", null)
		if starts_from != null and starts_from.get("branch", "") == branch_id:
			result.append(child_id)
	return result

func get_all_branch_ids() -> Array:
	return branches.keys()

func get_all_milestone_ids() -> Array:
	return milestones.keys()

func get_unlocked_milestones() -> Array:
	return unlocked_milestones.duplicate()

func get_max_level_in_data() -> float:
	"""Get the maximum level value across all milestones (for scaling)"""
	var max_level = 0.0
	for milestone_id in milestones.keys():
		var level = get_milestone_level(milestone_id)
		if level > max_level:
			max_level = level
	return max_level

func set_preferred_research_branch(branch_id: String):
	"""Set the branch where generic research is directed"""
	if branch_id == "" or branch_exists(branch_id):
		preferred_research_branch = branch_id
		print("Preferred research branch set to: %s" % (branch_id if branch_id != "" else "(random)"))

func get_preferred_research_branch() -> String:
	return preferred_research_branch

func get_generic_research_target() -> String:
	"""Get the branch to direct generic research to. Returns preferred if set, otherwise random visible branch."""
	if preferred_research_branch != "" and branch_exists(preferred_research_branch):
		return preferred_research_branch
	
	# Pick a random visible branch
	var visible: Array[String] = []
	for branch_id in branches.keys():
		if is_branch_visible(branch_id):
			visible.append(branch_id)
	
	if visible.is_empty():
		return ""
	
	return visible[randi() % visible.size()]
