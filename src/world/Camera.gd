extends Camera2D

const SPEED := 800
const MIN_ZOOM := 0.25
const MAX_ZOOM := 3.0

# Drag panning state
var is_dragging := false
var drag_start_mouse := Vector2.ZERO
var drag_start_camera := Vector2.ZERO

func _process(delta: float):
	# Arrow key panning
	var dir := Vector2.ZERO
	if Input.is_action_pressed("ui_right"): dir.x += 1
	if Input.is_action_pressed("ui_left"): dir.x -= 1
	if Input.is_action_pressed("ui_down"): dir.y += 1
	if Input.is_action_pressed("ui_up"): dir.y -= 1
	position += dir.normalized() * SPEED * delta

func _unhandled_input(event: InputEvent):
	# Mouse drag panning (middle or right mouse button)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				is_dragging = true
				drag_start_mouse = event.global_position
				drag_start_camera = position
			else:
				is_dragging = false

		# Zoom with scroll wheel (towards mouse cursor)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at_mouse(1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at_mouse(0.9)

	elif event is InputEventMouseMotion and is_dragging:
		# Move camera opposite to mouse drag direction, scaled by zoom
		var delta = event.global_position - drag_start_mouse
		position = drag_start_camera - delta / zoom

func _zoom_at_mouse(factor: float):
	"""Zoom towards/away from the mouse cursor position"""
	var mouse_world_before = get_global_mouse_position()
	zoom *= factor
	zoom = zoom.clamp(Vector2(MIN_ZOOM, MIN_ZOOM), Vector2(MAX_ZOOM, MAX_ZOOM))
	var mouse_world_after = get_global_mouse_position()
	position += mouse_world_before - mouse_world_after

func focus_on_coord(coord: Vector2i):
	"""Center the camera on a hex coordinate"""
	position = WorldUtil.axial_to_pixel(coord.x, coord.y)
