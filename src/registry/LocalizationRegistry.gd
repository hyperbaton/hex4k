extends RefCounted
class_name LocalizationRegistry

var current_language := "en"
var data := {}

func load_data():
	var path = "res://data/localization/%s.json" % current_language
	var file = FileAccess.open(path, FileAccess.READ)
	
	if not file:
		push_error("Failed to load localization file: " + path)
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	
	if error != OK:
		push_error("Failed to parse localization JSON: " + path)
		return
	
	data = json.data
	print("Loaded localization for language: ", current_language)

func get_name(category: String, id: String) -> String:
	if data.has(category) and data[category].has(id):
		return data[category][id].get("name", id)
	return id

func get_description(category: String, id: String) -> String:
	if data.has(category) and data[category].has(id):
		return data[category][id].get("description", "")
	return ""

func set_language(lang: String):
	current_language = lang
	load_data()
