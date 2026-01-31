extends RefCounted
class_name Unit

# Represents a unit on the map

signal moved(from_coord: Vector2i, to_coord: Vector2i)
signal health_changed(new_health: int, max_health: int)
signal destroyed

var unit_id: String  # Unique instance ID
var unit_type: String  # Type from registry (e.g., "explorer", "settler")
var owner_id: String  # Player ID who owns this unit

# Position
var coord: Vector2i  # Current hex coordinate
var home_city_id: String  # City where this unit was trained

# Stats (loaded from registry, can be modified by upgrades/effects)
var max_health: int = 100
var current_health: int = 100
var max_movement: int = 2
var current_movement: int = 2
var vision_range: int = 2
var attack: int = 0
var defense: int = 0

# Movement
var movement_type: String = "foot"  # References movement_types JSON

# State
var is_fortified: bool = false
var has_acted: bool = false  # Has performed an action this turn (attack, ability, etc.)

func _init(p_unit_id: String, p_unit_type: String, p_owner_id: String, p_coord: Vector2i):
	unit_id = p_unit_id
	unit_type = p_unit_type
	owner_id = p_owner_id
	coord = p_coord
	
	# Load stats from registry
	_load_stats_from_registry()

func _load_stats_from_registry():
	"""Load base stats from unit registry"""
	var unit_data = Registry.units.get_unit(unit_type)
	if unit_data.is_empty():
		push_error("Unit type not found in registry: " + unit_type)
		return
	
	var stats = unit_data.get("stats", {})
	max_health = stats.get("health", 100)
	current_health = max_health
	max_movement = stats.get("movement", 2)
	current_movement = max_movement
	vision_range = stats.get("vision", 2)
	
	var combat = unit_data.get("combat", {})
	attack = combat.get("attack", 0)
	defense = combat.get("defense", 0)
	
	movement_type = unit_data.get("movement_type", "foot")

func start_turn():
	"""Called at the start of each turn"""
	current_movement = max_movement
	has_acted = false
	
	# Fortified units heal slightly
	if is_fortified:
		heal(5)

func move_to(new_coord: Vector2i, movement_cost: int) -> bool:
	"""Move unit to a new coordinate. Returns true if successful."""
	if movement_cost > current_movement:
		return false
	
	var old_coord = coord
	coord = new_coord
	current_movement -= movement_cost
	is_fortified = false  # Moving breaks fortification
	
	emit_signal("moved", old_coord, new_coord)
	return true

func can_move() -> bool:
	return current_movement > 0 and not is_fortified

func take_damage(amount: int):
	"""Apply damage to the unit"""
	var actual_damage = max(1, amount - defense)
	current_health -= actual_damage
	
	emit_signal("health_changed", current_health, max_health)
	
	if current_health <= 0:
		current_health = 0
		emit_signal("destroyed")

func heal(amount: int):
	"""Heal the unit"""
	current_health = min(current_health + amount, max_health)
	emit_signal("health_changed", current_health, max_health)

func fortify():
	"""Fortify in place (skip turn for defensive bonus)"""
	is_fortified = true
	current_movement = 0
	has_acted = true

func get_effective_defense() -> int:
	"""Get defense including fortification bonus"""
	var bonus = 2 if is_fortified else 0
	return defense + bonus

func is_civil() -> bool:
	return Registry.units.is_civil_unit(unit_type)

func is_military() -> bool:
	return Registry.units.is_military_unit(unit_type)

func can_attack() -> bool:
	var unit_data = Registry.units.get_unit(unit_type)
	var combat = unit_data.get("combat", {})
	return combat.get("can_attack", false) and not has_acted

func get_movement_cost(terrain_type: String) -> int:
	"""Get the movement cost to enter a terrain type. Returns -1 if impassable."""
	return Registry.units.get_terrain_cost(movement_type, terrain_type)

func can_traverse(terrain_type: String) -> bool:
	return get_movement_cost(terrain_type) > 0

func get_display_name() -> String:
	return Registry.units.get_unit_name(unit_type)

func get_health_percent() -> float:
	return float(current_health) / float(max_health) * 100.0

# === Save/Load ===

func get_save_data() -> Dictionary:
	return {
		"unit_id": unit_id,
		"unit_type": unit_type,
		"owner_id": owner_id,
		"coord": {"x": coord.x, "y": coord.y},
		"home_city_id": home_city_id,
		"current_health": current_health,
		"current_movement": current_movement,
		"is_fortified": is_fortified,
		"has_acted": has_acted
	}

static func from_save_data(data: Dictionary) -> Unit:
	var coord_data = data.get("coord", {"x": 0, "y": 0})
	var unit = Unit.new(
		data.get("unit_id", ""),
		data.get("unit_type", ""),
		data.get("owner_id", ""),
		Vector2i(coord_data.x, coord_data.y)
	)
	unit.home_city_id = data.get("home_city_id", "")
	unit.current_health = data.get("current_health", unit.max_health)
	unit.current_movement = data.get("current_movement", unit.max_movement)
	unit.is_fortified = data.get("is_fortified", false)
	unit.has_acted = data.get("has_acted", false)
	return unit
