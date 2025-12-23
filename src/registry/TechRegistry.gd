extends RefCounted
class_name TechRegistry

# Stores tech branches and milestones
var branches := {}
var milestones := {}

# Track player's research progress
var branch_progress := {}  # branch_id -> float (research points)
var unlocked_milestones := []  # Array of milestone_ids

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
	var path = "res://data/tech/milestones.json"
	if not FileAccess.file_exists(path):
		push_error("Milestones file not found: " + path)
		return
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open milestones: " + path)
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	
	if error != OK:
		push_error("Failed to parse milestones JSON: " + json.get_error_message())
		return
	
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Milestones JSON root must be a dictionary")
		return
	
	milestones = data
	print("Loaded ", milestones.size(), " tech milestones")

func initialize_progress():
	for branch_id in branches.keys():
		branch_progress[branch_id] = 0.0

func get_branch(branch_id: String) -> Dictionary:
	if not branches.has(branch_id):
		push_warning("Branch not found: " + branch_id)
		return {}
	return branches[branch_id]

func get_milestone(milestone_id: String) -> Dictionary:
	if not milestones.has(milestone_id):
		push_warning("Milestone not found: " + milestone_id)
		return {}
	return milestones[milestone_id]

func branch_exists(branch_id: String) -> bool:
	return branches.has(branch_id)

func milestone_exists(milestone_id: String) -> bool:
	return milestones.has(milestone_id)

func get_branch_progress(branch_id: String) -> float:
	return branch_progress.get(branch_id, 0.0)

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
	
	# Check if hidden
	if milestone.has("visibility"):
		if milestone.visibility.get("hidden", false):
			return false
		
		# Check show_when conditions
		if milestone.visibility.has("show_when"):
			for condition in milestone.visibility.show_when:
				var branch_id = condition.get("branch", "")
				var level = condition.get("level", 0.0)
				
				if get_branch_progress(branch_id) >= level:
					return true
			return false
	
	return true

func is_branch_unlocked(branch_id: String) -> bool:
	var branch = get_branch(branch_id)
	
	if not branch.has("requires"):
		return true
	
	for req in branch.requires:
		var req_branch = req.get("branch", "")
		var req_level = req.get("level", 0.0)
		
		if get_branch_progress(req_branch) < req_level:
			return false
	
	return true

func get_all_branch_ids() -> Array:
	return branches.keys()

func get_all_milestone_ids() -> Array:
	return milestones.keys()

func get_unlocked_milestones() -> Array:
	return unlocked_milestones.duplicate()
