class_name WorldUtil

static func axial_to_pixel(q: int, r: int) -> Vector2:
	var x = WorldConfig.HEX_SIZE * 3.0/2.0 * q
	var y = WorldConfig.HEX_SIZE * sqrt(3) * (r + q / 2.0)
	return Vector2(x, y)

static func pixel_to_axial(pos: Vector2) -> Vector2i:
	var q = (2.0 / 3.0 * pos.x) / WorldConfig.HEX_SIZE
	var r = (-1.0 / 3.0 * pos.x + sqrt(3) / 3.0 * pos.y) / WorldConfig.HEX_SIZE
	return axial_round(q, r)

static func axial_round(qf: float, rf: float) -> Vector2i:
	var sf = -qf - rf

	var q = round(qf)
	var r = round(rf)
	var s = round(sf)

	var q_diff = abs(q - qf)
	var r_diff = abs(r - rf)
	var s_diff = abs(s - sf)

	if q_diff > r_diff and q_diff > s_diff:
		q = -r - s
	elif r_diff > s_diff:
		r = -q - s

	return Vector2i(q, r)
