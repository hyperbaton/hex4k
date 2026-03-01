extends RefCounted
class_name EmpireSpawnManager

## Manages late-game AI empire spawning.
## Checks eligible origins each turn and spawns new empires when conditions are met.
## Origins with min_turns > 0 are candidates for late-game spawning.

signal empire_spawned(player_id: String, origin_id: String, coord: Vector2i)

var origin_spawner: OriginSpawner
var city_manager: CityManager

# Track which origins have already been spawned (each origin spawns at most once)
var _spawned_origins: Dictionary = {}  # origin_id -> true

# Counter for generating unique AI player IDs
var _ai_counter: int = 0

func initialize(p_origin_spawner: OriginSpawner, p_city_manager: CityManager):
	origin_spawner = p_origin_spawner
	city_manager = p_city_manager

func check_empire_spawns(current_turn: int):
	"""Called each turn end to check if any AI empires should spawn.
	Origins with min_turns > 0 are checked for eligibility."""
	for origin_id in Registry.origins.get_all_origin_ids():
		# Skip already spawned origins
		if _spawned_origins.has(origin_id):
			continue

		var min_turns: int = Registry.origins.get_min_turns(origin_id)
		# min_turns == 0 means player-only origin, not eligible for late spawning
		if min_turns <= 0:
			continue

		# Check turn threshold
		if current_turn < min_turns:
			continue

		# Try to spawn
		_try_spawn_empire(origin_id)

func _try_spawn_empire(origin_id: String):
	"""Attempt to spawn an AI empire using the given origin."""
	_ai_counter += 1
	var player_id := "ai_%d" % _ai_counter

	# Get a display name from localization
	var display_name: String = Registry.localization.get_name("origin", origin_id)
	if display_name.is_empty() or display_name == origin_id:
		display_name = origin_id.capitalize()
	var player_name := "%s Empire" % display_name

	print("=== Spawning AI empire: %s (origin: %s) ===" % [player_name, origin_id])

	var spawn_coord := origin_spawner.apply_origin(origin_id, player_id, player_name)

	# Mark the player as AI (non-human)
	var player := city_manager.get_player(player_id)
	if player:
		player.is_human = false

	# Track that this origin has been used
	_spawned_origins[origin_id] = true

	emit_signal("empire_spawned", player_id, origin_id, spawn_coord)
	print("=== AI empire '%s' spawned at %v ===" % [player_name, spawn_coord])

# === Save/Load ===

func get_save_data() -> Dictionary:
	return {
		"spawned_origins": _spawned_origins.keys(),
		"ai_counter": _ai_counter
	}

func load_save_data(data: Dictionary):
	_spawned_origins.clear()
	for origin_id in data.get("spawned_origins", []):
		_spawned_origins[origin_id] = true
	_ai_counter = data.get("ai_counter", 0)
