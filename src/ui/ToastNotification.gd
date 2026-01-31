extends CanvasLayer
class_name ToastNotification

# Simple toast notification system for showing feedback messages

static var instance: ToastNotification = null

var toast_container: VBoxContainer
var active_toasts: Array[Control] = []

func _init():
	layer = 100  # Above everything
	ToastNotification.instance = self

func _ready():
	_create_toast_container()

func _create_toast_container():
	toast_container = VBoxContainer.new()
	toast_container.name = "ToastContainer"
	toast_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	toast_container.anchor_left = 1.0
	toast_container.anchor_right = 1.0
	toast_container.offset_left = -320
	toast_container.offset_right = -20
	toast_container.offset_top = 80
	toast_container.add_theme_constant_override("separation", 8)
	add_child(toast_container)

static func show_message(text: String, duration: float = 3.0, type: String = "info"):
	if instance:
		instance._show_toast(text, duration, type)

static func show_error(text: String, duration: float = 4.0):
	show_message(text, duration, "error")

static func show_success(text: String, duration: float = 3.0):
	show_message(text, duration, "success")

static func show_warning(text: String, duration: float = 3.5):
	show_message(text, duration, "warning")

func _show_toast(text: String, duration: float, type: String):
	var toast = _create_toast_panel(text, type)
	toast_container.add_child(toast)
	active_toasts.append(toast)
	
	# Animate in
	toast.modulate.a = 0
	toast.position.x = 50
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(toast, "modulate:a", 1.0, 0.2)
	tween.tween_property(toast, "position:x", 0.0, 0.3).set_ease(Tween.EASE_OUT)
	
	# Schedule removal
	await get_tree().create_timer(duration).timeout
	_remove_toast(toast)

func _create_toast_panel(text: String, type: String) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	
	# Style based on type
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	
	match type:
		"error":
			style.bg_color = Color(0.6, 0.15, 0.15, 0.95)
			style.border_color = Color(0.8, 0.3, 0.3)
		"success":
			style.bg_color = Color(0.15, 0.5, 0.2, 0.95)
			style.border_color = Color(0.3, 0.7, 0.4)
		"warning":
			style.bg_color = Color(0.6, 0.4, 0.1, 0.95)
			style.border_color = Color(0.8, 0.6, 0.2)
		_:  # info
			style.bg_color = Color(0.15, 0.25, 0.4, 0.95)
			style.border_color = Color(0.3, 0.5, 0.7)
	
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(label)
	
	return panel

func _remove_toast(toast: Control):
	if not is_instance_valid(toast):
		return
	
	# Animate out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(toast, "modulate:a", 0.0, 0.2)
	tween.tween_property(toast, "position:x", 50.0, 0.2)
	tween.tween_callback(func():
		active_toasts.erase(toast)
		toast.queue_free()
	)
