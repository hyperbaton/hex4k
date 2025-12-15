extends Node


class_name DataLoader


var terrains = {}
var modifiers = {}
var buildings = {}
var units = {}
var tech_tree = {}


func _ready():
	load_all()


func load_json(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Cannot open: " + path)
		return {}
	var text = file.get_as_text()
	return JSON.parse_string(text)


func load_all():
	terrains = load_json("res://data/terrains.json")
	modifiers = load_json("res://data/modifiers.json")
	buildings = load_json("res://data/buildings.json")
	units = load_json("res://data/units.json")
	tech_tree = load_json("res://data/tech_tree.json")
