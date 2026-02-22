extends RefCounted
class_name TradeRoute

# Represents a single active trade route between two cities.
# Routes are type-specific: only one convoy unit type per route.

var route_id: String
var city_a_id: String
var city_b_id: String
var unit_type: String  # Convoy unit type (e.g., "caravan", "hand_cart")
var path: Array[Vector2i] = []  # Ordered tiles forming the route
var distance: int = 0  # path.size()
var avg_movement_cost: float = 1.0  # Average movement cost per tile for this unit_type
var owner_id: String

# Assigned convoys (units abstracted into this route)
var convoys: Array[Dictionary] = []
# Each: { unit_id: String, cargo_capacity: int }

# Resource allocations: what to transfer each turn
var allocations: Array[Dictionary] = []
# Each: { resource_id: String, amount: float, direction: String ("a_to_b" or "b_to_a") }

# Cached throughput
var total_throughput: float = 0.0

func get_cargo_per_turn() -> float:
	"""Calculate total cargo that can be transferred per turn.
	Formula: sum(capacity) * movement / (avg_cost * 2 * distance)
	The *2 accounts for round trips."""
	if distance <= 0 or avg_movement_cost <= 0:
		return 0.0

	var unit_data = Registry.units.get_unit(unit_type)
	var movement: int = unit_data.get("stats", {}).get("movement", 2)

	var total_capacity: float = 0.0
	for convoy in convoys:
		total_capacity += convoy.cargo_capacity

	return total_capacity * movement / (avg_movement_cost * 2.0 * distance)

func recalculate_throughput():
	total_throughput = get_cargo_per_turn()

func get_total_allocated() -> float:
	"""Get total resources allocated across both directions."""
	var total := 0.0
	for alloc in allocations:
		total += alloc.amount
	return total

func get_remaining_throughput() -> float:
	"""Get throughput remaining after allocations."""
	return max(0.0, total_throughput - get_total_allocated())

func add_convoy(unit_id: String, p_cargo_capacity: int):
	convoys.append({
		"unit_id": unit_id,
		"cargo_capacity": p_cargo_capacity
	})
	recalculate_throughput()

func remove_convoy(unit_id: String) -> Dictionary:
	for i in range(convoys.size()):
		if convoys[i].unit_id == unit_id:
			var convoy = convoys[i]
			convoys.remove_at(i)
			recalculate_throughput()
			_clamp_allocations()
			return convoy
	return {}

func set_allocation(resource_id: String, amount: float, direction: String):
	"""Set or update a resource allocation. Removes if amount <= 0."""
	# Remove existing allocation for this resource+direction
	for i in range(allocations.size() - 1, -1, -1):
		if allocations[i].resource_id == resource_id and allocations[i].direction == direction:
			allocations.remove_at(i)

	if amount > 0:
		allocations.append({
			"resource_id": resource_id,
			"amount": amount,
			"direction": direction
		})

func remove_allocation(resource_id: String, direction: String):
	set_allocation(resource_id, 0.0, direction)

func _clamp_allocations():
	"""Clamp allocations to not exceed throughput after convoy removal."""
	var total = get_total_allocated()
	if total <= total_throughput:
		return
	var scale = total_throughput / max(total, 0.001)
	for alloc in allocations:
		alloc.amount *= scale

func get_other_city_id(city_id: String) -> String:
	"""Get the other city in this route."""
	if city_id == city_a_id:
		return city_b_id
	return city_a_id

func involves_city(city_id: String) -> bool:
	return city_id == city_a_id or city_id == city_b_id

# === Save/Load ===

func to_dict() -> Dictionary:
	var path_data: Array = []
	for p in path:
		path_data.append([p.x, p.y])

	return {
		"route_id": route_id,
		"city_a_id": city_a_id,
		"city_b_id": city_b_id,
		"unit_type": unit_type,
		"path": path_data,
		"owner_id": owner_id,
		"convoys": convoys.duplicate(true),
		"allocations": allocations.duplicate(true)
	}

static func from_dict(data: Dictionary) -> TradeRoute:
	var route = TradeRoute.new()
	route.route_id = data.get("route_id", "")
	route.city_a_id = data.get("city_a_id", "")
	route.city_b_id = data.get("city_b_id", "")
	route.unit_type = data.get("unit_type", "")
	route.owner_id = data.get("owner_id", "")

	route.path = []
	for p in data.get("path", []):
		route.path.append(Vector2i(p[0], p[1]))
	route.distance = route.path.size()

	route.convoys = data.get("convoys", []).duplicate(true)
	route.allocations = data.get("allocations", []).duplicate(true)
	# avg_movement_cost must be recalculated from world data on load
	return route
