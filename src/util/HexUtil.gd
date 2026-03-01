extends RefCounted
class_name HexUtil

## Static hex coordinate utility functions.
## Uses axial coordinates (q, r) stored as Vector2i.

# The six axial neighbor directions for offset-independent hex grids
const DIRECTIONS = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1)
]

static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	"""Calculate hex distance between two axial coordinates"""
	var q_diff = abs(a.x - b.x)
	var r_diff = abs(a.y - b.y)
	var s_diff = abs((-a.x - a.y) - (-b.x - b.y))
	return maxi(q_diff, maxi(r_diff, s_diff))

static func get_neighbors(coord: Vector2i) -> Array[Vector2i]:
	"""Get the 6 adjacent hex coordinates"""
	var neighbors: Array[Vector2i] = []
	for dir in DIRECTIONS:
		neighbors.append(coord + dir)
	return neighbors

static func get_ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	"""Get all hex coordinates at exactly the given ring distance from center.
	Ring 0 returns just the center tile."""
	if radius == 0:
		return [center]

	var results: Array[Vector2i] = []
	# Start at the hex that is `radius` steps in direction 4 (0, -1) from center
	var coord = center + DIRECTIONS[4] * radius

	# Walk along each of the 6 edges of the ring
	for edge in 6:
		for step in radius:
			results.append(coord)
			coord = coord + DIRECTIONS[edge]

	return results

static func get_spiral(center: Vector2i, max_radius: int) -> Array[Vector2i]:
	"""Get all hex coordinates from center outward in spiral order (ring 0, 1, 2, ...).
	Includes the center tile."""
	var results: Array[Vector2i] = []
	for r in range(0, max_radius + 1):
		results.append_array(get_ring(center, r))
	return results

static func get_coords_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]:
	"""Get all hex coordinates within the given radius (inclusive).
	Order is not guaranteed to be spiral — use get_spiral() if order matters."""
	var results: Array[Vector2i] = []
	for q in range(center.x - radius, center.x + radius + 1):
		for r in range(center.y - radius, center.y + radius + 1):
			var coord = Vector2i(q, r)
			if hex_distance(center, coord) <= radius:
				results.append(coord)
	return results
