extends RefCounted
class_name UnitManager

# Manages all units in the game

signal unit_spawned(unit: Unit)
signal unit_destroyed(unit: Unit)
signal unit_moved(unit: Unit, from_coord: Vector2i, to_coord: Vector2i)
signal unit_movement_finished(unit: Unit, completed: bool)

var units: Dictionary = {}  # unit_id -> Unit
var units_by_coord: Dictionary = {}  # Vector2i -> Array[Unit] (multiple units can stack in some cases)
var next_unit_id: int = 1
var world_query = null  # WorldQuery reference for placing trade route markers

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
	"""Get the first non-trade-route-assigned unit at a coordinate"""
	var units_here = get_units_at(coord)
	for u in units_here:
		if not u.is_assigned_to_trade_route:
			return u
	return null

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

	# Place trade route marker if unit is in explore route mode
	if unit.is_exploring_route and unit.has_cargo_capacity() and world_query:
		_place_trade_route_marker(unit, to_coord)

	emit_signal("unit_moved", unit, from_coord, to_coord)

func _on_unit_destroyed(unit: Unit):
	remove_unit(unit.unit_id)

# === Movement Helpers ===

func get_reachable_tiles(unit: Unit, world_query) -> Dictionary:
	"""Get all tiles a unit can reach this turn with their movement costs.
	Tiles occupied by friendly units are traversable but not valid destinations."""
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
			# Get terrain data
			var terrain_data = world_query.get_terrain_data(neighbor)
			if not terrain_data:
				continue  # No terrain data

			var terrain_id = terrain_data.terrain_id

			# Get movement cost (considering modifiers like paths)
			var move_cost = Registry.units.get_effective_movement_cost(
				unit.movement_type, terrain_id, terrain_data.modifiers)
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

	# Remove tiles occupied by friendly units (can path through but not stop on)
	for coord in reachable.keys():
		if coord == unit.coord:
			continue  # Don't remove the unit's own tile
		if _has_friendly_unit_at(coord, unit.owner_id):
			reachable.erase(coord)

	return reachable

func _has_friendly_unit_at(coord: Vector2i, owner_id: String) -> bool:
	"""Check if there's a friendly unit at the given coordinate"""
	var units_there = get_units_at(coord)
	for other_unit in units_there:
		if other_unit.owner_id == owner_id:
			return true
	return false

func find_path(unit: Unit, target: Vector2i, world_query) -> Array[Vector2i]:
	"""Find the optimal path from unit's current position to target.
	Uses Dijkstra with parent pointers. Returns array of coordinates
	from start (exclusive) to target (inclusive). Empty if no path."""
	var start = unit.coord
	if start == target:
		return []

	var costs: Dictionary = {}      # Vector2i -> int (best cost to reach)
	var parents: Dictionary = {}    # Vector2i -> Vector2i (came from)
	var to_check: Array = [[start, 0]]  # [coord, cost_so_far]
	costs[start] = 0

	while not to_check.is_empty():
		# Find minimum cost entry
		var min_idx := 0
		for i in range(1, to_check.size()):
			if to_check[i][1] < to_check[min_idx][1]:
				min_idx = i
		var current = to_check[min_idx]
		to_check.remove_at(min_idx)

		var current_coord: Vector2i = current[0]
		var current_cost: int = current[1]

		# Skip if we already found a better path
		if current_cost > costs.get(current_coord, 999999):
			continue

		# Early exit if we reached target
		if current_coord == target:
			break

		for neighbor in _get_hex_neighbors(current_coord):
			var terrain_data = world_query.get_terrain_data(neighbor)
			if not terrain_data:
				continue

			var move_cost = Registry.units.get_effective_movement_cost(
				unit.movement_type, terrain_data.terrain_id, terrain_data.modifiers)
			if move_cost < 0:
				continue  # Impassable

			var total_cost = current_cost + move_cost
			if total_cost > unit.current_movement:
				continue

			# Check for enemy units blocking
			var units_there = get_units_at(neighbor)
			var blocked := false
			for other_unit in units_there:
				if other_unit.owner_id != unit.owner_id:
					blocked = true
					break
			if blocked:
				continue

			if total_cost < costs.get(neighbor, 999999):
				costs[neighbor] = total_cost
				parents[neighbor] = current_coord
				to_check.append([neighbor, total_cost])

	# Reconstruct path
	if not parents.has(target):
		return []

	var path: Array[Vector2i] = []
	var current = target
	while current != start:
		path.push_front(current)
		current = parents[current]

	return path

func get_step_cost(unit: Unit, to_coord: Vector2i, world_query) -> int:
	"""Get the movement cost for a single step to an adjacent tile.
	Returns -1 if the step is invalid."""
	var terrain_data = world_query.get_terrain_data(to_coord)
	if not terrain_data:
		return -1
	return Registry.units.get_effective_movement_cost(
		unit.movement_type, terrain_data.terrain_id, terrain_data.modifiers)

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

# === Trade Route Assignment ===

func remove_unit_from_map(unit: Unit):
	"""Remove a unit from the coord grid (for trade route assignment)."""
	_remove_unit_from_coord(unit, unit.coord)

func return_unit_to_map(unit: Unit, coord: Vector2i):
	"""Return a unit to the coord grid at the given position.
	Emits unit_moved so sprites and other systems update."""
	var old_coord = unit.coord
	unit.coord = coord
	_add_unit_to_coord(unit, coord)
	# Emit moved signal so UnitSprite repositions and UnitLayer updates visibility
	unit.emit_signal("moved", old_coord, coord)
	emit_signal("unit_moved", unit, old_coord, coord)

# === Trade Route Exploration ===

func _place_trade_route_marker(unit: Unit, coord: Vector2i):
	"""Place a trade route marker on the tile for this unit's type."""
	var terrain_data = world_query.get_terrain_data(coord)
	if not terrain_data:
		return
	var marker_id = Registry.modifiers.get_trade_route_marker_id(unit.unit_type)
	if not terrain_data.has_modifier(marker_id):
		terrain_data.add_modifier(marker_id)
		print("UnitManager: Placed trade route marker '%s' at %v" % [marker_id, coord])

# === Cargo Operations ===

func load_cargo_from_city(unit: Unit, city, resource_id: String, amount: float) -> float:
	"""Load resources from a city into a unit's cargo.
	Unit must be on a tile belonging to the city.
	Returns the amount actually loaded."""
	if not unit.has_cargo_capacity():
		print("UnitManager: Unit %s has no cargo capacity" % unit.unit_id)
		return 0.0
	
	# Check unit is on a city tile
	if not city.has_tile(unit.coord):
		print("UnitManager: Unit %s is not on a tile of city %s" % [unit.unit_id, city.city_name])
		return 0.0
	
	# Calculate how much we can take
	var available = city.get_total_resource(resource_id)
	var space = unit.get_cargo_space()
	var to_load = min(amount, min(available, space))
	
	if to_load <= 0:
		return 0.0
	
	# Transfer: city -> unit
	var consumed = city.consume_resource(resource_id, to_load)
	var loaded = unit.add_cargo(resource_id, consumed)
	
	print("UnitManager: Loaded %.1f %s from %s onto %s" % [loaded, resource_id, city.city_name, unit.unit_id])
	return loaded

func unload_cargo_to_city(unit: Unit, city, resource_id: String, amount: float) -> float:
	"""Unload resources from a unit's cargo into a city.
	Unit must be on a tile belonging to the city.
	Returns the amount actually unloaded."""
	if not unit.has_cargo_capacity():
		return 0.0
	
	# Check unit is on a city tile
	if not city.has_tile(unit.coord):
		print("UnitManager: Unit %s is not on a tile of city %s" % [unit.unit_id, city.city_name])
		return 0.0
	
	var carried = unit.get_cargo_amount(resource_id)
	var to_unload = min(amount, carried)
	
	if to_unload <= 0:
		return 0.0
	
	# Transfer: unit -> city
	var stored = city.store_resource(resource_id, to_unload)
	var removed = unit.remove_cargo(resource_id, stored)
	
	print("UnitManager: Unloaded %.1f %s from %s to %s" % [removed, resource_id, unit.unit_id, city.city_name])
	return removed

func unload_all_cargo_to_city(unit: Unit, city) -> Dictionary:
	"""Unload all cargo from unit to city. Returns dict of resource_id -> amount unloaded."""
	var unloaded: Dictionary = {}
	var cargo_copy = unit.get_all_cargo()
	
	for resource_id in cargo_copy.keys():
		var amount = unload_cargo_to_city(unit, city, resource_id, cargo_copy[resource_id])
		if amount > 0:
			unloaded[resource_id] = amount
	
	return unloaded

# === Infrastructure Building ===

func can_build_infrastructure(unit: Unit, modifier_id: String, world_query) -> Dictionary:
	"""Check if a unit can build infrastructure at its current location.
	Returns {can_build: bool, reason: String}"""
	# Check unit has the build_infrastructure ability
	if not unit.has_ability("build_infrastructure"):
		return {"can_build": false, "reason": "Unit cannot build infrastructure"}
	
	# Check modifier is in the unit's buildable list
	var params = unit.get_ability_params("build_infrastructure")
	var buildable = params.get("builds", [])
	if modifier_id not in buildable:
		return {"can_build": false, "reason": "Unit cannot build this type of infrastructure"}
	
	# Check unit hasn't acted this turn
	if unit.has_acted:
		return {"can_build": false, "reason": "Unit has already acted this turn"}
	
	# Get terrain data
	var terrain_data = world_query.get_terrain_data(unit.coord)
	if not terrain_data:
		return {"can_build": false, "reason": "Invalid terrain"}
	
	# Check modifier not already present
	if terrain_data.has_modifier(modifier_id):
		return {"can_build": false, "reason": "Infrastructure already exists here"}
	
	# Load infrastructure data to check terrain validity and costs
	var infra_data = _load_infrastructure_data(modifier_id)
	if infra_data.is_empty():
		return {"can_build": false, "reason": "Unknown infrastructure type"}
	
	# Check terrain is valid
	var valid_terrains = infra_data.get("conditions", {}).get("terrain_types", [])
	if not valid_terrains.is_empty() and terrain_data.terrain_id not in valid_terrains:
		return {"can_build": false, "reason": "Cannot build on this terrain"}
	
	# Check conflicts
	var conflicts = infra_data.get("conflicts_with", [])
	for conflict_id in conflicts:
		if terrain_data.has_modifier(conflict_id):
			return {"can_build": false, "reason": "Conflicts with existing infrastructure"}
	
	# Check construction cost against unit cargo
	var cost = infra_data.get("construction", {}).get("cost", {})
	for resource_id in cost.keys():
		if not unit.has_cargo(resource_id, cost[resource_id]):
			return {"can_build": false, "reason": "Not enough %s in cargo (need %.1f)" % [
				resource_id, cost[resource_id]]}
	
	# Check milestone requirements
	var milestones = infra_data.get("milestones_required", [])
	for milestone_id in milestones:
		if not Registry.tech.is_milestone_unlocked(milestone_id):
			return {"can_build": false, "reason": "Required technology not unlocked"}
	
	return {"can_build": true, "reason": ""}

func build_infrastructure(unit: Unit, modifier_id: String, world_query) -> bool:
	"""Build infrastructure at the unit's current location.
	Consumes resources from cargo and places the modifier on the terrain.
	Returns true if successful."""
	var check = can_build_infrastructure(unit, modifier_id, world_query)
	if not check.can_build:
		print("UnitManager: Cannot build %s: %s" % [modifier_id, check.reason])
		return false
	
	var terrain_data = world_query.get_terrain_data(unit.coord)
	var infra_data = _load_infrastructure_data(modifier_id)
	var cost = infra_data.get("construction", {}).get("cost", {})
	
	# Consume resources from cargo
	for resource_id in cost.keys():
		unit.remove_cargo(resource_id, cost[resource_id])
	
	# Place the modifier on the terrain
	terrain_data.add_modifier(modifier_id)
	
	# Mark unit as having acted
	unit.has_acted = true
	
	print("UnitManager: %s built %s at %v" % [unit.unit_id, modifier_id, unit.coord])
	return true

func _load_infrastructure_data(modifier_id: String) -> Dictionary:
	"""Get infrastructure modifier data from the registry.
	Returns the full modifier dict if it's infrastructure type, empty dict otherwise."""
	var data = Registry.modifiers.get_modifier(modifier_id)
	if data.get("type", "") == "infrastructure":
		return data
	return {}

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
