extends RefCounted
class_name Player

# Represents a player in the game (human or AI)

var player_id: String  # Unique identifier
var player_name: String
var is_human: bool = true
var civilization_perks: Array[String] = []  # List of perk IDs
var origin_id: String = ""  # Which origin this player started with

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

func has_lost() -> bool:
	"""Check if this player has lost (no cities remaining)"""
	return cities.is_empty()

# === Save/Load ===

func to_dict() -> Dictionary:
	return {
		"player_id": player_id,
		"player_name": player_name,
		"is_human": is_human,
		"civilization_perks": civilization_perks.duplicate(),
		"origin_id": origin_id
	}

static func from_dict(data: Dictionary) -> Player:
	var player = Player.new(
		data.get("player_id", ""),
		data.get("player_name", ""),
		data.get("is_human", true)
	)
	for perk in data.get("civilization_perks", []):
		player.civilization_perks.append(perk)
	player.origin_id = data.get("origin_id", "")
	return player
