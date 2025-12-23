extends RefCounted
class_name Player

# Represents a player in the game (human or AI)

var player_id: String  # Unique identifier
var player_name: String
var is_human: bool = true
var civilization_perks: Array[String] = []  # List of perk IDs

# Cities owned by this player
var cities: Array[City] = []

func _init(id: String, name: String, human: bool = true):
	player_id = id
	player_name = name
	is_human = human

func add_city(city: City):
	if not cities.has(city):
		cities.append(city)
		city.owner = self

func remove_city(city: City):
	cities.erase(city)

func get_city_count() -> int:
	return cities.size()

func has_perk(perk_id: String) -> bool:
	return perk_id in civilization_perks

func add_perk(perk_id: String):
	if not has_perk(perk_id):
		civilization_perks.append(perk_id)
		print("Player %s gained perk: %s" % [player_name, perk_id])

func get_all_cities() -> Array[City]:
	return cities
