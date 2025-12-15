extends Node
class_name TechnologyTree


var branches = {}
var levels = {}


func initialize(data):
	branches = data
	for branch in branches.keys():
		levels[branch] = 0


func can_unlock(branch: String) -> bool:
	var reqs = branches[branch].get("requires", [])
	for req in reqs:
		var b = req["branch"]
		var lvl = req["level"]
		if levels.get(b, 0) < lvl:
			return false
	return true
