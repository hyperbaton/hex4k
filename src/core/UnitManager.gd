extends Node
class_name UnitManager

# Manages all units in the game world

signal unit_created(unit: Unit)
signal unit_destroyed(unit: Unit)
signal unit_moved(unit: Unit, from: Vector2i, to: Vector2i)
signal unit_selected(unit: Unit)
signal unit_deselected

# All units in the game
var units: Dictionary = {}  # id -> Unit

# Spatial index: position -> Array of unit IDs
var units_at_position: Dictionary = {}  # Vector2i -> Array[int]

# Currently selected unit
var selected_unit: Unit = null

# ID counter for creating new units
var next_unit_id: int = 1

# Reference to the game world (for terrain queries)
var world_query = null  # Will be set by GameManager

# Visual container for unit sprites
var visual_container: Node2D = null

func _ready():
	# Create container for unit visuals
	visual_container = Node2D.new()
	visual_container.name = "UnitVisuals"
	visual_container.z_index = 10  # Above terrain and buildings
	add_child(visual_container)

func set_world_query(query):
	"""Set the world query reference for terrain lookups"""
	world_query = query

# === Unit Creation ===

func create_unit(unit_type: String, owner_id: int, position: Vector2i) -> Unit:
	"""Create a new unit at the specified position"""
	var unit = Unit.new(next_unit_id, unit_type, owner_id, position)
	next_unit_id += 1
	
	# Register the unit
	units[unit.id] = unit
	_add_unit_to_position(unit.id, position)
	
	# Connect signals
	unit.position_changed.connect(_on_unit_position_changed.bind(unit))
	unit.unit_died.connect(_on_unit_died.bind(unit))
	
	# Create visual representation
	_create_unit_visual(unit)
	
	emit_signal("unit_created", unit)
	print("Created unit %s (id=%d) at %s" % [unit_type, unit.id, position])
	
	return unit

func destroy_unit(unit: Unit):
	"""Remove a unit from the game"""
	if not units.has(unit.id):
		return
	
	# Remove from spatial index
	_remove_unit_from_position(unit.id, unit.hex_position)
	
	# Remove visual
	if unit.visual_node and is_instance_valid(unit.visual_node):
		unit.visual_node.queue_free()
	
	# Deselect if selected
	if selected_unit == unit:
		deselect_unit()
	
	# Remove from units dictionary
	units.erase(unit.id)
	
	emit_signal("unit_destroyed", unit)
	print("Destroyed unit %s (id=%d)" % [unit.unit_type, unit.id])

# === Spatial Index Management ===

func _add_unit_to_position(unit_id: int, position: Vector2i):
	if not units_at_position.has(position):
		units_at_position[position] = []
	units_at_position[position].append(unit_id)

func _remove_unit_from_position(unit_id: int, position: Vector2i):
	if units_at_position.has(position):
		units_at_position[position].erase(unit_id)
		if units_at_position[position].is_empty():
			units_at_position.erase(position)

func get_units_at(position: Vector2i) -> Array[Unit]:
	"""Get all units at a specific position"""
	var result: Array[Unit] = []
	if units_at_position.has(position):
		for unit_id in units_at_position[position]:
			if units.has(unit_id):
				result.append(units[unit_id])
	return result

func get_unit_at(position: Vector2i) -> Unit:
	"""Get the first unit at a position (or null if none)"""
	var units_here = get_units_at(position)
	if units_here.is_empty():
		return null
	return units_here[0]

func has_unit_at(position: Vector2i) -> bool:
	"""Check if there's any unit at a position"""
	return units_at_position.has(position) and not units_at_position[position].is_empty()

func has_enemy_unit_at(position: Vector2i, for_player_id: int) -> bool:
	"""Check if there's an enemy unit at a position"""
	for unit in get_units_at(position):
		if unit.owner_id != for_player_id:
			return true
	return false

func has_friendly_unit_at(position: Vector2i, for_player_id: int) -> bool:
	"""Check if there's a friendly unit at a position"""
	for unit in get_units_at(position):
		if unit.owner_id == for_player_id:
			return true
	return false

# === Selection ===

func select_unit(unit: Unit):
	"""Select a unit"""
	if selected_unit == unit:
		return
	
	if selected_unit != null:
		deselect_unit()
	
	selected_unit = unit
	_update_unit_visual_selection(unit, true)
	emit_signal("unit_selected", unit)

func deselect_unit():
	"""Deselect the currently selected unit"""
	if selected_unit == null:
		return
	
	var old_unit = selected_unit
	_update_unit_visual_selection(selected_unit, false)
	selected_unit = null
	emit_signal("unit_deselected")

func get_selected_unit() -> Unit:
	return selected_unit

func has_selected_unit() -> bool:
	return selected_unit != null

# === Movement ===

func get_valid_move_targets(unit: Unit) -> Array[Vector2i]:
	"""Get all tiles the unit can move to with remaining movement points"""
	var result: Array[Vector2i] = []
	
	if not unit.has_movement():
		return result
	
	# Get adjacent hexes
	var neighbors = _get_hex_neighbors(unit.hex_position)
	
	for neighbor in neighbors:
		var move_cost = get_movement_cost(unit, neighbor)
		if move_cost > 0 and move_cost <= unit.movement_remaining:
			# Check if tile is not blocked by enemy unit (for civil units)
			if unit.is_civil() and has_enemy_unit_at(neighbor, unit.owner_id):
				continue
			
			# For now, allow only one unit per tile (can be changed later)
			if has_unit_at(neighbor):
				continue
			
			result.append(neighbor)
	
	return result

func get_movement_cost(unit: Unit, target_position: Vector2i) -> int:
	"""Get the movement cost for a unit to move to a target position"""
	if world_query == null:
		push_warning("UnitManager: world_query not set, cannot calculate movement cost")
		return -1
	
	# Get terrain at target position
	var terrain_type = world_query.get_terrain_type(target_position)
	if terrain_type == "":
		return -1  # Invalid position
	
	return unit.get_movement_cost_to(terrain_type)

func move_unit(unit: Unit, target_position: Vector2i) -> bool:
	"""Attempt to move a unit to a target position"""
	var move_cost = get_movement_cost(unit, target_position)
	
	if move_cost <= 0:
		print("Cannot move to %s - terrain impassable" % target_position)
		return false
	
	if move_cost > unit.movement_remaining:
		print("Cannot move to %s - not enough movement points (%d required, %d remaining)" % 
			[target_position, move_cost, unit.movement_remaining])
		return false
	
	# Check for blocking units
	if has_unit_at(target_position):
		print("Cannot move to %s - tile occupied" % target_position)
		return false
	
	# Perform the move
	var old_position = unit.hex_position
	_remove_unit_from_position(unit.id, old_position)
	unit.move_to(target_position, move_cost)
	_add_unit_to_position(unit.id, target_position)
	
	# Update visual position
	_update_unit_visual_position(unit)
	
	emit_signal("unit_moved", unit, old_position, target_position)
	return true

# === Turn Management ===

func start_turn_for_player(player_id: int):
	"""Start the turn for all units belonging to a player"""
	for unit in units.values():
		if unit.owner_id == player_id:
			unit.start_turn()

func end_turn_for_player(player_id: int):
	"""End the turn for all units belonging to a player"""
	for unit in units.values():
		if unit.owner_id == player_id:
			unit.end_turn()

# === Visual Management ===

func _create_unit_visual(unit: Unit):
	"""Create the visual representation of a unit"""
	var visual = UnitVisual.new()
	visual.setup(unit)
	visual_container.add_child(visual)
	unit.visual_node = visual
	_update_unit_visual_position(unit)

func _update_unit_visual_position(unit: Unit):
	"""Update the visual position of a unit"""
	if unit.visual_node == null or not is_instance_valid(unit.visual_node):
		return
	
	# Convert hex position to world position
	var world_pos = _hex_to_world(unit.hex_position)
	unit.visual_node.position = world_pos

func _update_unit_visual_selection(unit: Unit, is_selected: bool):
	"""Update the visual selection state of a unit"""
	if unit.visual_node and is_instance_valid(unit.visual_node):
		unit.visual_node.set_selected(is_selected)

# === Hex Utilities ===

func _get_hex_neighbors(hex_pos: Vector2i) -> Array[Vector2i]:
	"""Get all adjacent hex positions"""
	var neighbors: Array[Vector2i] = []
	
	# Offset coordinates for odd-q layout
	var is_odd_col = hex_pos.x % 2 != 0
	
	# Direction offsets for odd-q vertical layout
	var directions: Array
	if is_odd_col:
		directions = [
			Vector2i(0, -1),   # North
			Vector2i(1, 0),    # Northeast
			Vector2i(1, 1),    # Southeast
			Vector2i(0, 1),    # South
			Vector2i(-1, 1),   # Southwest
			Vector2i(-1, 0)    # Northwest
		]
	else:
		directions = [
			Vector2i(0, -1),   # North
			Vector2i(1, -1),   # Northeast
			Vector2i(1, 0),    # Southeast
			Vector2i(0, 1),    # South
			Vector2i(-1, 0),   # Southwest
			Vector2i(-1, -1)   # Northwest
		]
	
	for dir in directions:
		neighbors.append(hex_pos + dir)
	
	return neighbors

func _hex_to_world(hex_pos: Vector2i) -> Vector2:
	"""Convert hex coordinates to world position"""
	# Assuming same layout as the rest of the game
	const HEX_SIZE = 64.0
	const SQRT_3 = 1.732050808
	
	var x = HEX_SIZE * 1.5 * hex_pos.x
	var y = HEX_SIZE * SQRT_3 * (hex_pos.y + 0.5 * (hex_pos.x & 1))
	
	return Vector2(x, y)

# === Signal Handlers ===

func _on_unit_position_changed(old_pos: Vector2i, new_pos: Vector2i, unit: Unit):
	# Spatial index is already updated in move_unit()
	pass

func _on_unit_died(unit: Unit):
	destroy_unit(unit)

# === Queries ===

func get_units_for_player(player_id: int) -> Array[Unit]:
	"""Get all units belonging to a player"""
	var result: Array[Unit] = []
	for unit in units.values():
		if unit.owner_id == player_id:
			result.append(unit)
	return result

func get_all_units() -> Array[Unit]:
	"""Get all units in the game"""
	var result: Array[Unit] = []
	for unit in units.values():
		result.append(unit)
	return result

# === Serialization ===

func to_dict() -> Dictionary:
	var units_data = []
	for unit in units.values():
		units_data.append(unit.to_dict())
	
	return {
		"next_unit_id": next_unit_id,
		"units": units_data
	}

func from_dict(data: Dictionary):
	# Clear existing units
	for unit in units.values():
		if unit.visual_node and is_instance_valid(unit.visual_node):
			unit.visual_node.queue_free()
	units.clear()
	units_at_position.clear()
	
	next_unit_id = data.get("next_unit_id", 1)
	
	for unit_data in data.get("units", []):
		var unit = Unit.from_dict(unit_data)
		units[unit.id] = unit
		_add_unit_to_position(unit.id, unit.hex_position)
		unit.position_changed.connect(_on_unit_position_changed.bind(unit))
		unit.unit_died.connect(_on_unit_died.bind(unit))
		_create_unit_visual(unit)
