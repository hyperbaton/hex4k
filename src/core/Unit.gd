extends RefCounted
class_name Unit

# Unit instance representing a single unit in the game

signal health_changed(new_health: int, max_health: int)
signal movement_changed(remaining: int, max_points: int)
signal position_changed(old_pos: Vector2i, new_pos: Vector2i)
signal unit_died

# Unique identifier for this unit instance
var id: int = -1

# Unit type (references data in UnitRegistry)
var unit_type: String = ""

# Owner
var owner_id: int = -1  # Player ID

# Position (hex coordinates)
var hex_position: Vector2i = Vector2i.ZERO

# Current stats
var current_health: int = 100
var movement_remaining: int = 0

# State flags
var has_acted_this_turn: bool = false
var is_fortified: bool = false

# Experience (for future use)
var experience: int = 0

# Reference to the visual node (set by UnitManager)
var visual_node: Node2D = null

func _init(p_id: int, p_unit_type: String, p_owner_id: int, p_position: Vector2i):
	id = p_id
	unit_type = p_unit_type
	owner_id = p_owner_id
	hex_position = p_position
	
	# Initialize stats from unit data
	current_health = get_max_health()
	movement_remaining = get_max_movement()

# === Stat Getters (from registry data) ===

func get_max_health() -> int:
	return Registry.units.get_stat(unit_type, "health", 100)

func get_max_movement() -> int:
	return Registry.units.get_stat(unit_type, "movement_points", 2)

func get_movement_type() -> String:
	return Registry.units.get_stat(unit_type, "movement_type", "foot")

func get_vision_range() -> int:
	return Registry.units.get_stat(unit_type, "vision_range", 2)

func get_attack() -> int:
	return Registry.units.get_combat_stat(unit_type, "attack", 0)

func get_defense() -> int:
	return Registry.units.get_combat_stat(unit_type, "defense", 0)

func can_attack() -> bool:
	return Registry.units.get_combat_stat(unit_type, "can_attack", false)

func can_defend() -> bool:
	return Registry.units.get_combat_stat(unit_type, "can_defend", true)

func get_category() -> String:
	return Registry.units.get_unit_category(unit_type)

func is_civil() -> bool:
	return Registry.units.is_civil_unit(unit_type)

func is_military() -> bool:
	return Registry.units.is_military_unit(unit_type)

func get_maintenance() -> Dictionary:
	return Registry.units.get_maintenance(unit_type)

# === Health Management ===

func take_damage(amount: int):
	var old_health = current_health
	current_health = max(0, current_health - amount)
	emit_signal("health_changed", current_health, get_max_health())
	
	if current_health <= 0:
		emit_signal("unit_died")

func heal(amount: int):
	var old_health = current_health
	current_health = min(get_max_health(), current_health + amount)
	emit_signal("health_changed", current_health, get_max_health())

func get_health_percentage() -> float:
	var max_hp = get_max_health()
	if max_hp <= 0:
		return 0.0
	return float(current_health) / float(max_hp)

# === Movement ===

func get_movement_cost_to(terrain_type: String) -> int:
	"""Get the movement cost to enter a specific terrain type"""
	return Registry.units.get_terrain_cost(get_movement_type(), terrain_type)

func can_move_to_terrain(terrain_type: String) -> bool:
	"""Check if this unit can move to a specific terrain type"""
	var cost = get_movement_cost_to(terrain_type)
	return cost > 0 and cost <= movement_remaining

func spend_movement(amount: int):
	"""Spend movement points"""
	movement_remaining = max(0, movement_remaining - amount)
	emit_signal("movement_changed", movement_remaining, get_max_movement())

func has_movement() -> bool:
	"""Check if the unit has any movement points left"""
	return movement_remaining > 0

func move_to(new_position: Vector2i, movement_cost: int):
	"""Move the unit to a new position"""
	var old_pos = hex_position
	hex_position = new_position
	spend_movement(movement_cost)
	emit_signal("position_changed", old_pos, new_position)

# === Turn Management ===

func start_turn():
	"""Called at the start of the owner's turn"""
	movement_remaining = get_max_movement()
	has_acted_this_turn = false
	
	# Fortification bonus could be applied here
	if is_fortified:
		pass  # Could add healing or other bonuses

func end_turn():
	"""Called at the end of the owner's turn"""
	has_acted_this_turn = true

# === Fortification ===

func fortify():
	"""Set the unit to fortified state"""
	is_fortified = true
	movement_remaining = 0
	has_acted_this_turn = true

func unfortify():
	"""Remove fortified state"""
	is_fortified = false

# === Combat ===

func get_effective_defense() -> int:
	"""Get defense value including modifiers"""
	var base_defense = get_defense()
	
	# Fortification bonus
	if is_fortified:
		base_defense = int(base_defense * 1.25)
	
	# Health penalty (units below 50% health defend worse)
	var health_pct = get_health_percentage()
	if health_pct < 0.5:
		base_defense = int(base_defense * (0.5 + health_pct))
	
	return base_defense

func get_effective_attack() -> int:
	"""Get attack value including modifiers"""
	var base_attack = get_attack()
	
	# Health penalty
	var health_pct = get_health_percentage()
	if health_pct < 0.5:
		base_attack = int(base_attack * (0.5 + health_pct))
	
	return base_attack

# === Serialization ===

func to_dict() -> Dictionary:
	"""Serialize unit state for saving"""
	return {
		"id": id,
		"unit_type": unit_type,
		"owner_id": owner_id,
		"hex_position": {"x": hex_position.x, "y": hex_position.y},
		"current_health": current_health,
		"movement_remaining": movement_remaining,
		"has_acted_this_turn": has_acted_this_turn,
		"is_fortified": is_fortified,
		"experience": experience
	}

static func from_dict(data: Dictionary) -> Unit:
	"""Deserialize unit state from save data"""
	var pos = Vector2i(data.hex_position.x, data.hex_position.y)
	var unit = Unit.new(data.id, data.unit_type, data.owner_id, pos)
	unit.current_health = data.get("current_health", unit.get_max_health())
	unit.movement_remaining = data.get("movement_remaining", 0)
	unit.has_acted_this_turn = data.get("has_acted_this_turn", false)
	unit.is_fortified = data.get("is_fortified", false)
	unit.experience = data.get("experience", 0)
	return unit
