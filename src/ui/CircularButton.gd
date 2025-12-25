extends Control
class_name CircularButton

# Round button for action menu

signal pressed

@export var button_text: String = "Button"
@export var button_color: Color = Color.BLUE
@export var radius: float = 40.0

var is_hovered := false
var is_pressed := false

func _ready():
	custom_minimum_size = Vector2(radius * 2, radius * 2)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _draw():
	var center = size / 2
	
	# Draw circle
	var color = button_color
	if is_pressed:
		color = color.darkened(0.3)
	elif is_hovered:
		color = color.lightened(0.2)
	
	draw_circle(center, radius, color)
	
	# Draw outline
	draw_arc(center, radius, 0, TAU, 32, Color.WHITE, 2.0)
	
	# Draw text - use black for light colors, white for dark colors
	var text_color = Color.WHITE
	if button_color.get_luminance() > 0.5:
		text_color = Color.BLACK
	
	var font = ThemeDB.fallback_font
	var font_size = 12
	var text_size = font.get_string_size(button_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = center - text_size / 2
	
	draw_string(font, text_pos, button_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, text_color)

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# When called from ActionMenu._input, we already verified the click is inside
			# So we can skip the distance check for forwarded events
			var is_forwarded = (event.position == Vector2.ZERO and event.global_position != Vector2.ZERO)
			
			print("CircularButton._gui_input: ", button_text, " - pressed=", event.pressed, ", is_forwarded=", is_forwarded)
			print("  -> event.global_position=", event.global_position, ", my global_position=", global_position, ", my position=", position)
			
			if event.pressed:
				print("  -> Mouse DOWN")
				is_pressed = true
				is_hovered = true
			else:
				print("  -> Mouse UP, is_pressed=", is_pressed)
				if is_pressed:
					print("  -> EMITTING PRESSED SIGNAL!")
					emit_signal("pressed")
				is_pressed = false
			queue_redraw()
			accept_event()
	
	elif event is InputEventMouseMotion:
		var local_pos = event.position
		var center = size / 2
		var distance = local_pos.distance_to(center)
		
		var was_hovered = is_hovered
		is_hovered = distance <= radius
		
		if was_hovered != is_hovered:
			queue_redraw()

func _notification(what):
	if what == NOTIFICATION_MOUSE_EXIT:
		is_hovered = false
		is_pressed = false
		queue_redraw()

func get_global_rectangle() -> Rect2:
	# Return the bounding rect of the circular button
	return Rect2(global_position, size)

func is_point_inside(global_point: Vector2) -> bool:
	"""Check if a global point is inside the circular button"""
	var center = global_position + size / 2
	var distance = global_point.distance_to(center)
	return distance <= radius
