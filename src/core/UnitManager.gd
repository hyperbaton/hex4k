extends RefCounted
class_name UnitManager

# Manages all units in the game

signal unit_spawned(unit: Unit)
signal unit_destroyed(unit: Unit)
signal unit_moved(unit: Unit, from_coord: Vector2i, to_coord: Vector2i)

var units: Dictionary = {}  # unit_id -> Unit
var units_by_coord: Dictionary = {}  # Vector2i -> Array[Unit] (multiple units can stack in some cases)
var next_unit_id: int = 1

func generate_unit_id() -> String:
	var id = "unit_%d" % next_unit_id
	next_unit_id += 1
	return id

func spawn_unit(unit_type: String, owner_id: String, coord: Vector2i, home_city_id: String = "") -> Unit:
	"""Spawn a new unit at the given coordinate"""
	var unit_id = generate_unit_id()
	var unit = Unit.new(unit_id, unit_type, owner_id, coord)
	unit.home_city_id = home_city_id
	
	# Connect signals
	unit.moved.connect(_on_unit_moved.bind(unit))
	unit.destroyed.connect(_on_unit_destroyed.bind(unit))
	
	# Add to tracking
	units[unit_id] = unit
	_add_unit_to_coord(unit, coord)
	
	print("UnitManager: Spawned %s at %s (id: %s)" % [unit_type, coord, unit_id])
	emit_signal("unit_spawned", unit)
	
	return unit

func remove_unit(unit_id: String):
	"""Remove a unit from the game"""
	if not units.has(unit_id):
		return
	
	var unit = units[unit_id]
	_remove_unit_from_coord(unit, unit.coord)
	units.erase(unit_id)
	
	emit_signal("unit_destroyed", unit)

func get_unit(unit_id: String) -> Unit:
	return units.get(unit_id)

func get_units_at(coord: Vector2i) -> Array:
	"""Get all units at a coordinate"""
	return units_by_coord.get(coord, [])

func get_unit_at(coord: Vector2i) -> Unit:
	"""Get the first unit at a coordinate (for single-unit-per-tile games)"""
	var units_here = get_units_at(coord)
	if units_here.is_empty():
		return null
	return units_here[0]

func has_unit_at(coord: Vector2i) -> bool:
	var units_here = units_by_coord.get(coord, [])
	return not units_here.is_empty()

func get_player_units(player_id: String) -> Array[Unit]:
	"""Get all units belonging to a player"""
	var result: Array[Unit] = []
	for unit in units.values():
		if unit.owner_id == player_id:
			result.append(unit)
	return result

func get_all_units() -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in units.values():
		result.append(unit)
	return result

func process_turn_start(player_id: String):
	"""Process start of turn for all units belonging to a player"""
	for unit in units.values():
		if unit.owner_id == player_id:
			unit.start_turn()

func _add_unit_to_coord(unit: Unit, coord: Vector2i):
	if not units_by_coord.has(coord):
		units_by_coord[coord] = []
	units_by_coord[coord].append(unit)

func _remove_unit_from_coord(unit: Unit, coord: Vector2i):
	if units_by_coord.has(coord):
		units_by_coord[coord].erase(unit)
		if units_by_coord[coord].is_empty():
			units_by_coord.erase(coord)

func _on_unit_moved(from_coord: Vector2i, to_coord: Vector2i, unit: Unit):
	_remove_unit_from_coord(unit, from_coord)
	_add_unit_to_coord(unit, to_coord)
	emit_signal("unit_moved", unit, from_coord, to_coord)

func _on_unit_destroyed(unit: Unit):
	remove_unit(unit.unit_id)

# === Movement Helpers ===

func get_reachable_tiles(unit: Unit, world_query) -> Dictionary:
	"""Get all tiles a unit can reach this turn with their movement costs"""
	var reachable: Dictionary = {}  # Vector2i -> movement_cost_to_reach
	var to_check: Array = [[unit.coord, 0]]  # [coord, cost_so_far]
	
	reachable[unit.coord] = 0
	
	while not to_check.is_empty():
		var current = to_check.pop_front()
		var current_coord: Vector2i = current[0]
		var current_cost: int = current[1]
		
		# Get neighbors
		var neighbors = _get_hex_neighbors(current_coord)
		
		for neighbor in neighbors:
			# Get terrain type
			var terrain_id = world_query.get_terrain_id(neighbor)
			if terrain_id == "":
				continue  # No terrain data
			
			# Get movement cost
			var move_cost = unit.get_movement_cost(terrain_id)
			if move_cost < 0:
				continue  # Impassable
			
			var total_cost = current_cost + move_cost
			
			# Check if within movement range
			if total_cost > unit.current_movement:
				continue
			
			# Check if we already have a cheaper path
			if reachable.has(neighbor) and reachable[neighbor] <= total_cost:
				continue
			
			# Check for enemy units (can't move through them)
			var units_there = get_units_at(neighbor)
			var blocked = false
			for other_unit in units_there:
				if other_unit.owner_id != unit.owner_id:
					blocked = true
					break
			
			if blocked:
				continue
			
			reachable[neighbor] = total_cost
			to_check.append([neighbor, total_cost])
	
	return reachable

func _get_hex_neighbors(coord: Vector2i) -> Array[Vector2i]:
	"""Get the 6 adjacent hex coordinates"""
	var neighbors: Array[Vector2i] = []
	var directions = [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
	]
	for dir in directions:
		neighbors.append(coord + dir)
	return neighbors

# === Save/Load ===

func get_save_data() -> Dictionary:
	var units_data = []
	for unit in units.values():
		units_data.append(unit.get_save_data())
	
	return {
		"next_unit_id": next_unit_id,
		"units": units_data
	}

func load_save_data(data: Dictionary):
	units.clear()
	units_by_coord.clear()
	
	next_unit_id = data.get("next_unit_id", 1)
	
	for unit_data in data.get("units", []):
		var unit = Unit.from_save_data(unit_data)
		unit.moved.connect(_on_unit_moved.bind(unit))
		unit.destroyed.connect(_on_unit_destroyed.bind(unit))
		units[unit.unit_id] = unit
		_add_unit_to_coord(unit, unit.coord)
