extends RefCounted
class_name TradeRouteManager

# Manages all trade routes in the game.
# Handles route creation/removal, convoy assignment, pathfinding through
# trade route markers, and per-turn resource transfers.

signal route_created(route: TradeRoute)
signal route_removed(route_id: String)
signal convoy_assigned(route_id: String, unit_id: String)
signal convoy_unassigned(route_id: String, unit_id: String)

var routes: Dictionary = {}  # route_id -> TradeRoute
var _next_route_num: int = 0

var city_manager: CityManager
var unit_manager: UnitManager
var world_query: Node  # WorldQuery

func _init(p_city_manager: CityManager = null, p_unit_manager: UnitManager = null, p_world_query: Node = null):
	city_manager = p_city_manager
	unit_manager = p_unit_manager
	world_query = p_world_query

# === Route Creation / Removal ===

func create_route(city_a_id: String, city_b_id: String, unit_type: String, owner_id: String) -> TradeRoute:
	"""Create a new trade route between two cities.
	Returns the route or null if creation fails."""
	# Validate cities exist
	var city_a = city_manager.get_city(city_a_id)
	var city_b = city_manager.get_city(city_b_id)
	if not city_a or not city_b:
		push_warning("TradeRouteManager: City not found")
		return null

	# Validate capacity
	if get_remaining_trade_route_capacity(city_a_id) <= 0:
		push_warning("TradeRouteManager: %s has no trade route capacity" % city_a.city_name)
		return null
	if get_remaining_trade_route_capacity(city_b_id) <= 0:
		push_warning("TradeRouteManager: %s has no trade route capacity" % city_b.city_name)
		return null

	# Find path through trade route markers
	var path = find_marked_path(city_a_id, city_b_id, unit_type)
	if path.is_empty():
		push_warning("TradeRouteManager: No marked path between cities for %s" % unit_type)
		return null

	# Create route
	_next_route_num += 1
	var route = TradeRoute.new()
	route.route_id = "route_%d" % _next_route_num
	route.city_a_id = city_a_id
	route.city_b_id = city_b_id
	route.unit_type = unit_type
	route.owner_id = owner_id
	route.path = path
	route.distance = path.size()
	route.avg_movement_cost = calculate_avg_movement_cost(path, unit_type)
	route.recalculate_throughput()

	routes[route.route_id] = route

	print("TradeRouteManager: Created route %s (%s <-> %s, type: %s, dist: %d)" % [
		route.route_id, city_a.city_name, city_b.city_name, unit_type, route.distance])

	emit_signal("route_created", route)
	return route

func remove_route(route_id: String):
	"""Remove a trade route, returning all convoys to the map."""
	if not routes.has(route_id):
		return

	var route: TradeRoute = routes[route_id]

	# Return convoys to map
	var convoy_ids = []
	for convoy in route.convoys:
		convoy_ids.append(convoy.unit_id)

	for unit_id in convoy_ids:
		unassign_convoy(route_id, unit_id)

	routes.erase(route_id)
	print("TradeRouteManager: Removed route %s" % route_id)
	emit_signal("route_removed", route_id)

# === Convoy Assignment ===

func assign_convoy(route_id: String, unit: Unit) -> bool:
	"""Assign a convoy unit to a trade route. Removes unit from map."""
	if not routes.has(route_id):
		return false

	var route: TradeRoute = routes[route_id]

	# Validate unit type matches route
	if unit.unit_type != route.unit_type:
		push_warning("TradeRouteManager: Unit type %s doesn't match route type %s" % [
			unit.unit_type, route.unit_type])
		return false

	# Check convoy capacity for the city the unit is in
	var city = city_manager.get_city_at_tile(unit.coord)
	if city and get_remaining_convoy_capacity(city.city_id) <= 0:
		push_warning("TradeRouteManager: No convoy capacity at %s" % city.city_name)
		return false

	# Assign unit — remove from map grid
	unit.is_assigned_to_trade_route = true
	unit_manager.remove_unit_from_map(unit)
	route.add_convoy(unit.unit_id, unit.cargo_capacity)

	print("TradeRouteManager: Assigned %s to route %s" % [unit.unit_id, route_id])
	emit_signal("convoy_assigned", route_id, unit.unit_id)
	return true

func unassign_convoy(route_id: String, unit_id: String) -> Unit:
	"""Unassign a convoy from a trade route. Returns unit to its home city
	(the city where it was trained), or city_a as fallback."""
	if not routes.has(route_id):
		return null

	var route: TradeRoute = routes[route_id]
	var convoy = route.remove_convoy(unit_id)
	if convoy.is_empty():
		return null

	var unit = unit_manager.get_unit(unit_id)
	if unit:
		unit.is_assigned_to_trade_route = false

		# Determine return city: prefer home city, fall back to city_a
		var return_city: City = null
		if unit.home_city_id != "":
			return_city = city_manager.get_city(unit.home_city_id)
		if not return_city:
			return_city = city_manager.get_city(route.city_a_id)

		if return_city:
			unit_manager.return_unit_to_map(unit, return_city.city_center_coord)

	print("TradeRouteManager: Unassigned %s from route %s" % [unit_id, route_id])
	emit_signal("convoy_unassigned", route_id, unit_id)
	return unit

# === Resource Allocation ===

func set_allocation(route_id: String, resource_id: String, amount: float, direction: String):
	"""Set resource allocation on a route."""
	if not routes.has(route_id):
		return
	routes[route_id].set_allocation(resource_id, amount, direction)

func remove_allocation(route_id: String, resource_id: String, direction: String):
	"""Remove resource allocation from a route."""
	if not routes.has(route_id):
		return
	routes[route_id].remove_allocation(resource_id, direction)

# === Queries ===

func get_route(route_id: String) -> TradeRoute:
	return routes.get(route_id)

func get_routes_for_city(city_id: String) -> Array[TradeRoute]:
	"""Get all routes involving a city."""
	var result: Array[TradeRoute] = []
	for route in routes.values():
		if route.involves_city(city_id):
			result.append(route)
	return result

func get_city_trade_route_capacity(city_id: String) -> int:
	"""Get total trade route capacity for a city from buildings."""
	var city = city_manager.get_city(city_id)
	if not city:
		return 0
	return city.get_trade_route_capacity()

func get_city_convoy_capacity(city_id: String) -> int:
	"""Get total convoy capacity for a city from buildings."""
	var city = city_manager.get_city(city_id)
	if not city:
		return 0
	return city.get_convoy_capacity()

func get_used_trade_route_count(city_id: String) -> int:
	"""Count how many routes this city is part of."""
	var count := 0
	for route in routes.values():
		if route.involves_city(city_id):
			count += 1
	return count

func get_used_convoy_count(city_id: String) -> int:
	"""Count how many convoys are assigned to routes from/to this city."""
	var count := 0
	for route in routes.values():
		if route.involves_city(city_id):
			count += route.convoys.size()
	return count

func get_remaining_trade_route_capacity(city_id: String) -> int:
	return get_city_trade_route_capacity(city_id) - get_used_trade_route_count(city_id)

func get_remaining_convoy_capacity(city_id: String) -> int:
	return get_city_convoy_capacity(city_id) - get_used_convoy_count(city_id)

func get_connectable_cities(city_id: String, unit_type: String) -> Array[Dictionary]:
	"""Get cities that can be connected to via trade route markers.
	Returns: Array of {city_id, city_name, distance, avg_cost, path}"""
	var result: Array[Dictionary] = []
	var source_city = city_manager.get_city(city_id)
	if not source_city:
		return result

	for city in city_manager.get_all_cities():
		if city.city_id == city_id:
			continue
		if city.is_abandoned:
			continue
		if city.owner != source_city.owner:
			continue  # Only own cities for now
		if get_remaining_trade_route_capacity(city.city_id) <= 0:
			continue

		# Check if already connected by a route of the same type
		var already_connected := false
		for route in routes.values():
			if route.unit_type == unit_type and route.involves_city(city_id) and route.involves_city(city.city_id):
				already_connected = true
				break
		if already_connected:
			continue

		var path = find_marked_path(city_id, city.city_id, unit_type)
		if path.is_empty():
			continue

		var avg_cost = calculate_avg_movement_cost(path, unit_type)
		result.append({
			"city_id": city.city_id,
			"city_name": city.city_name,
			"distance": path.size(),
			"avg_cost": avg_cost,
			"path": path
		})

	return result

# === Route Validation ===

func validate_route(route: TradeRoute) -> bool:
	"""Check if a route's marked path still exists."""
	var marker_id = Registry.modifiers.get_trade_route_marker_id(route.unit_type)

	for coord in route.path:
		# City tiles don't need markers
		if city_manager.is_tile_owned(coord):
			continue
		var terrain_data = world_query.get_terrain_data(coord)
		if not terrain_data:
			return false
		if not terrain_data.has_modifier(marker_id):
			return false
	return true

# === Trade Processing (called by TurnManager) ===

func process_trade(city: City, report) -> void:
	"""Process trade transfers for a city during the trade phase.
	Only processes allocations where this city is the source."""
	var city_routes = get_routes_for_city(city.city_id)

	for route in city_routes:
		if route.convoys.is_empty():
			continue
		if not validate_route(route):
			continue

		var remaining_throughput = route.total_throughput

		for alloc in route.allocations:
			if remaining_throughput <= 0.0:
				break

			var resource_id: String = alloc.resource_id
			var requested: float = alloc.amount
			var direction: String = alloc.direction

			# Determine source/dest
			var source_city_id: String
			var dest_city_id: String
			if direction == "a_to_b":
				source_city_id = route.city_a_id
				dest_city_id = route.city_b_id
			else:
				source_city_id = route.city_b_id
				dest_city_id = route.city_a_id

			# Only process when we're the source city
			if city.city_id != source_city_id:
				continue

			var actual = min(requested, remaining_throughput)
			actual = min(actual, city.get_total_resource(resource_id))

			if actual <= 0.0:
				continue

			var dest_city = city_manager.get_city(dest_city_id)
			if not dest_city:
				continue

			# Transfer resources
			city.consume_resource(resource_id, actual)
			dest_city.store_resource(resource_id, actual)
			remaining_throughput -= actual

			# Update ledgers
			city.resources.add_trade_outgoing(resource_id, actual)
			dest_city.resources.add_trade_incoming(resource_id, actual)

			# Report
			if report and report.has_method("add_trade_transfer"):
				report.add_trade_transfer(
					route.route_id, resource_id, actual, direction, dest_city_id)

			print("  Trade: %.1f %s from %s to %s (route %s)" % [
				actual, resource_id, city.city_name, dest_city.city_name, route.route_id])

# === A* Pathfinding Through Route Markers ===

func find_marked_path(city_a_id: String, city_b_id: String, unit_type: String) -> Array[Vector2i]:
	"""Find shortest path between two cities through trade route markers.
	City tiles count as connected (no marker needed inside city borders).
	Returns empty array if no path exists."""
	var city_a = city_manager.get_city(city_a_id)
	var city_b = city_manager.get_city(city_b_id)
	if not city_a or not city_b:
		return []

	var marker_id = Registry.modifiers.get_trade_route_marker_id(unit_type)
	var city_a_tiles: Dictionary = city_a.tiles  # coord -> CityTile
	var city_b_tiles: Dictionary = city_b.tiles

	# Get unit's movement type for cost calculation
	var unit_data = Registry.units.get_unit(unit_type)
	var movement_type_id: String = unit_data.get("movement_type", "foot")

	# A* search
	# Start from all border tiles of city A
	var open_set: Array = []  # Array of [f_score, g_score, coord, came_from_coord]
	var g_scores: Dictionary = {}  # coord -> best g_score
	var came_from: Dictionary = {}  # coord -> previous coord

	# Find a reference point in city B for heuristic
	var target_coord: Vector2i = city_b.city_center_coord

	# Initialize with city A border tiles
	for coord in city_a_tiles.keys():
		var neighbors = world_query.get_hex_neighbors(coord)
		var is_border := false
		for neighbor in neighbors:
			if not city_a_tiles.has(neighbor):
				is_border = true
				break
		if is_border:
			var h = world_query.calculate_hex_distance(coord, target_coord)
			open_set.append([h, 0, coord, Vector2i(-99999, -99999)])
			g_scores[coord] = 0

	# Also allow starting from any city A tile (for small cities)
	if open_set.is_empty():
		for coord in city_a_tiles.keys():
			var h = world_query.calculate_hex_distance(coord, target_coord)
			open_set.append([h, 0, coord, Vector2i(-99999, -99999)])
			g_scores[coord] = 0

	while not open_set.is_empty():
		# Find node with lowest f_score
		var best_idx := 0
		for i in range(1, open_set.size()):
			if open_set[i][0] < open_set[best_idx][0]:
				best_idx = i

		var current = open_set[best_idx]
		open_set.remove_at(best_idx)
		var current_f: int = current[0]
		var current_g: int = current[1]
		var current_coord: Vector2i = current[2]
		var from_coord: Vector2i = current[3]

		# Skip if we already found a better path to this node
		if g_scores.has(current_coord) and g_scores[current_coord] < current_g:
			continue

		# Record came_from
		if from_coord != Vector2i(-99999, -99999):
			came_from[current_coord] = from_coord

		# Check if we reached city B
		if city_b_tiles.has(current_coord):
			return _reconstruct_path(came_from, current_coord, city_a_tiles)

		# Explore neighbors
		var neighbors = world_query.get_hex_neighbors(current_coord)
		for neighbor in neighbors:
			# Is this neighbor a valid tile to traverse?
			var is_valid := false

			if city_b_tiles.has(neighbor):
				# Destination city tile - always valid
				is_valid = true
			elif city_a_tiles.has(neighbor):
				# Source city tile - always valid
				is_valid = true
			else:
				# Must have a trade route marker for this unit type
				var terrain_data = world_query.get_terrain_data(neighbor)
				if terrain_data and terrain_data.has_modifier(marker_id):
					is_valid = true

			if not is_valid:
				continue

			# Calculate movement cost for this tile
			var terrain_data = world_query.get_terrain_data(neighbor)
			if not terrain_data:
				continue

			var move_cost = Registry.units.get_effective_movement_cost(
				movement_type_id, terrain_data.terrain_id, terrain_data.modifiers)
			if move_cost < 0:
				continue  # Impassable for this unit type

			var new_g = current_g + move_cost
			if g_scores.has(neighbor) and g_scores[neighbor] <= new_g:
				continue

			g_scores[neighbor] = new_g
			var h = world_query.calculate_hex_distance(neighbor, target_coord)
			open_set.append([new_g + h, new_g, neighbor, current_coord])

	return []  # No path found

func _reconstruct_path(came_from: Dictionary, end_coord: Vector2i, city_a_tiles: Dictionary) -> Array[Vector2i]:
	"""Reconstruct path from A* came_from map. Excludes city A interior tiles."""
	var path: Array[Vector2i] = []
	var current = end_coord

	while came_from.has(current):
		path.append(current)
		current = came_from[current]

	# Add the start tile
	path.append(current)
	path.reverse()

	# Filter out interior city A tiles (keep border tiles that connect to the path)
	# Actually, keep all tiles - the path represents the full route
	return path

func calculate_avg_movement_cost(path: Array[Vector2i], unit_type: String) -> float:
	"""Calculate average movement cost across all route tiles."""
	if path.is_empty():
		return 1.0

	var unit_data = Registry.units.get_unit(unit_type)
	var movement_type_id: String = unit_data.get("movement_type", "foot")

	var total_cost: float = 0.0
	var tile_count: int = 0

	for coord in path:
		var terrain_data = world_query.get_terrain_data(coord)
		if not terrain_data:
			total_cost += 1.0
			tile_count += 1
			continue

		var cost = Registry.units.get_effective_movement_cost(
			movement_type_id, terrain_data.terrain_id, terrain_data.modifiers)
		if cost > 0:
			total_cost += cost
		else:
			total_cost += 1.0  # Fallback
		tile_count += 1

	return total_cost / max(tile_count, 1)

# === Save/Load ===

func to_dict() -> Dictionary:
	var routes_data: Dictionary = {}
	for route_id in routes:
		routes_data[route_id] = routes[route_id].to_dict()
	return {
		"routes": routes_data,
		"next_route_num": _next_route_num
	}

func from_dict(data: Dictionary):
	routes.clear()
	_next_route_num = data.get("next_route_num", 0)
	for route_id in data.get("routes", {}).keys():
		var route = TradeRoute.from_dict(data.routes[route_id])
		# Recalculate avg_movement_cost from live world data
		route.avg_movement_cost = calculate_avg_movement_cost(route.path, route.unit_type)
		route.recalculate_throughput()
		routes[route_id] = route
	print("TradeRouteManager: Loaded %d routes" % routes.size())
