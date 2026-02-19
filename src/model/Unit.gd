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
var armor_class_ids: Array[String] = []
var attacks_remaining: int = 0

# Movement
var movement_type: String = "foot"  # References movement_types JSON

# Cargo/Inventory (for transport units)
var cargo: Dictionary = {}  # resource_id -> float
var cargo_capacity: int = 0  # Max total cargo weight

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
	var armor_ids = combat.get("armor_classes", [])
	armor_class_ids.clear()
	for id in armor_ids:
		armor_class_ids.append(id)

	movement_type = unit_data.get("movement_type", "foot")
	cargo_capacity = stats.get("cargo_capacity", 0)

func start_turn():
	"""Called at the start of each turn"""
	current_movement = max_movement
	has_acted = false
	attacks_remaining = _get_attacks_per_turn()

	# Fortified units heal slightly
	if is_fortified:
		heal(5)

func _get_attacks_per_turn() -> int:
	"""Get attacks_per_turn from the unit's first military ability, or 0 if none."""
	var unit_data = Registry.units.get_unit(unit_type)
	var combat = unit_data.get("combat", {})
	if not combat.get("can_attack", false):
		return 0
	var unit_abilities = unit_data.get("abilities", [])
	for ability_ref in unit_abilities:
		var ability_id: String = ""
		var params: Dictionary = {}
		if ability_ref is Dictionary:
			ability_id = ability_ref.get("ability_id", "")
			params = ability_ref.get("params", {})
		elif ability_ref is String:
			ability_id = ability_ref
		var ability_data = Registry.abilities.get_ability(ability_id)
		if ability_data.get("category", "") == "military":
			return params.get("attacks_per_turn", 1)
	return 0

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
	"""Apply raw damage to the unit (already resolved by CombatResolver)"""
	current_health -= amount

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

func is_civil() -> bool:
	return Registry.units.is_civil_unit(unit_type)

func is_military() -> bool:
	return Registry.units.is_military_unit(unit_type)

func can_attack() -> bool:
	var unit_data = Registry.units.get_unit(unit_type)
	var combat = unit_data.get("combat", {})
	return combat.get("can_attack", false) and attacks_remaining > 0

func get_movement_cost(terrain_type: String) -> int:
	"""Get the movement cost to enter a terrain type. Returns -1 if impassable."""
	return Registry.units.get_terrain_cost(movement_type, terrain_type)

func can_traverse(terrain_type: String) -> bool:
	return get_movement_cost(terrain_type) > 0

func get_display_name() -> String:
	return Registry.units.get_unit_name(unit_type)

func get_health_percent() -> float:
	return float(current_health) / float(max_health) * 100.0

# === Cargo/Inventory ===

func has_cargo_capacity() -> bool:
	"""Check if this unit can carry cargo"""
	return cargo_capacity > 0

func get_total_cargo() -> float:
	"""Get the total amount of cargo currently carried"""
	var total: float = 0.0
	for amount in cargo.values():
		total += amount
	return total

func get_cargo_space() -> float:
	"""Get remaining cargo space"""
	return max(0.0, cargo_capacity - get_total_cargo())

func add_cargo(resource_id: String, amount: float) -> float:
	"""Add resources to cargo. Returns amount actually loaded."""
	var space = get_cargo_space()
	var to_load = min(amount, space)
	if to_load <= 0:
		return 0.0
	cargo[resource_id] = cargo.get(resource_id, 0.0) + to_load
	return to_load

func remove_cargo(resource_id: String, amount: float) -> float:
	"""Remove resources from cargo. Returns amount actually removed."""
	var carried = cargo.get(resource_id, 0.0)
	var to_remove = min(amount, carried)
	if to_remove <= 0:
		return 0.0
	cargo[resource_id] = carried - to_remove
	if cargo[resource_id] <= 0:
		cargo.erase(resource_id)
	return to_remove

func get_cargo_amount(resource_id: String) -> float:
	"""Get amount of a specific resource in cargo"""
	return cargo.get(resource_id, 0.0)

func has_cargo(resource_id: String, amount: float) -> bool:
	"""Check if unit has at least this much of a resource in cargo"""
	return cargo.get(resource_id, 0.0) >= amount

func get_all_cargo() -> Dictionary:
	"""Get a copy of all cargo"""
	return cargo.duplicate()

func has_ability(ability_id: String) -> bool:
	"""Check if this unit has a specific ability"""
	var unit_data = Registry.units.get_unit(unit_type)
	var abilities = unit_data.get("abilities", [])
	for ability in abilities:
		if ability is Dictionary:
			if ability.get("ability_id", "") == ability_id:
				return true
		elif ability is String:
			if ability == ability_id:
				return true
	return false

func get_ability_params(ability_id: String) -> Dictionary:
	"""Get the params for a specific ability"""
	var unit_data = Registry.units.get_unit(unit_type)
	var abilities = unit_data.get("abilities", [])
	for ability in abilities:
		if ability is Dictionary:
			if ability.get("ability_id", "") == ability_id:
				return ability.get("params", {})
	return {}

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
		"has_acted": has_acted,
		"attacks_remaining": attacks_remaining,
		"cargo": cargo.duplicate()
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
	unit.attacks_remaining = data.get("attacks_remaining", 0)
	unit.cargo = data.get("cargo", {})
	return unit
