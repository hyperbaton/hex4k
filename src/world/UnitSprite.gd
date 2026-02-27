extends Node2D
class_name UnitSprite

# Visual representation of a unit on the map

signal step_animation_finished

var unit: Unit
var unit_icon: Sprite2D
var selection_ring: Node2D
var health_bar: Node2D
var movement_indicator: Label

var is_selected: bool = false
var _current_tween: Tween = null

func _ready():
	_create_visuals()

func _create_visuals():
	# Unit icon (circular background with icon)
	unit_icon = Sprite2D.new()
	unit_icon.name = "UnitIcon"
	add_child(unit_icon)
	
	# Selection ring
	selection_ring = Node2D.new()
	selection_ring.name = "SelectionRing"
	selection_ring.visible = false
	add_child(selection_ring)
	
	# Health bar
	health_bar = Node2D.new()
	health_bar.name = "HealthBar"
	add_child(health_bar)
	
	# Movement indicator
	movement_indicator = Label.new()
	movement_indicator.name = "MovementIndicator"
	movement_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	movement_indicator.add_theme_font_size_override("font_size", 12)
	movement_indicator.add_theme_color_override("font_color", Color.WHITE)
	movement_indicator.add_theme_color_override("font_outline_color", Color.BLACK)
	movement_indicator.add_theme_constant_override("outline_size", 2)
	add_child(movement_indicator)

func setup(p_unit: Unit):
	unit = p_unit
	
	# Connect signals
	unit.health_changed.connect(_on_health_changed)
	unit.moved.connect(_on_unit_moved)
	
	# Load visual
	_load_unit_visual()
	_update_health_bar()
	_update_movement_indicator()
	
	# Position at unit's coordinate
	position = WorldUtil.axial_to_pixel(unit.coord.x, unit.coord.y)

func _load_unit_visual():
	var unit_data = Registry.units.get_unit(unit.unit_type)
	var visual_data = unit_data.get("visual", {})
	var sprite_path = visual_data.get("sprite", "")
	
	# Try to load the sprite
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var texture = load(sprite_path)
		if texture:
			unit_icon.texture = texture
			# Scale to fit hex
			var tex_size = texture.get_size()
			var target_size = 48.0
			var scale_factor = target_size / max(tex_size.x, tex_size.y)
			unit_icon.scale = Vector2(scale_factor, scale_factor)
	else:
		# Create placeholder circle
		_create_placeholder_icon(visual_data)

func _create_placeholder_icon(visual_data: Dictionary):
	# Create a simple colored circle as placeholder
	var color_str = visual_data.get("color", "#888888")
	var color = Color.from_string(color_str, Color.GRAY)
	
	# Create a simple texture
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var center = Vector2(16, 16)
	var radius = 14.0
	
	for x in range(32):
		for y in range(32):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= radius:
				image.set_pixel(x, y, color)
			elif dist <= radius + 1:
				# Anti-aliased edge
				var alpha = 1.0 - (dist - radius)
				image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	
	var texture = ImageTexture.create_from_image(image)
	unit_icon.texture = texture
	unit_icon.scale = Vector2(1.5, 1.5)

func _update_health_bar():
	# Clear existing
	for child in health_bar.get_children():
		child.queue_free()
	
	if unit.current_health >= unit.max_health:
		health_bar.visible = false
		return
	
	health_bar.visible = true
	
	# Background
	var bg = ColorRect.new()
	bg.size = Vector2(30, 4)
	bg.position = Vector2(-15, -30)
	bg.color = Color.DARK_RED
	health_bar.add_child(bg)
	
	# Health fill
	var fill = ColorRect.new()
	var fill_percent = float(unit.current_health) / float(unit.max_health)
	fill.size = Vector2(30 * fill_percent, 4)
	fill.position = Vector2(-15, -30)
	fill.color = Color.GREEN if fill_percent > 0.5 else (Color.YELLOW if fill_percent > 0.25 else Color.RED)
	health_bar.add_child(fill)

func _update_movement_indicator():
	movement_indicator.text = str(unit.current_movement)
	movement_indicator.position = Vector2(-6, 15)
	
	# Hide if no movement
	movement_indicator.visible = unit.current_movement > 0

func set_selected(selected: bool):
	is_selected = selected
	selection_ring.visible = selected
	
	if selected:
		_draw_selection_ring()
	
	# Update modulate for visual feedback
	if selected:
		modulate = Color(1.2, 1.2, 1.2)  # Slightly brighter
	else:
		modulate = Color.WHITE

func _draw_selection_ring():
	# Clear existing
	for child in selection_ring.get_children():
		child.queue_free()
	
	# Create a simple ring indicator using a custom draw node
	var ring_draw = SelectionRingNode.new()
	selection_ring.add_child(ring_draw)

func _on_health_changed(_new_health: int, _max_health: int):
	_update_health_bar()

func _on_unit_moved(_from: Vector2i, to: Vector2i):
	"""Animate one movement step. Emits step_animation_finished when done."""
	var target_pos = WorldUtil.axial_to_pixel(to.x, to.y)

	# Kill any existing tween (safety)
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	_current_tween = create_tween()
	_current_tween.tween_property(self, "position", target_pos, 0.2).set_ease(Tween.EASE_IN_OUT)
	_current_tween.finished.connect(_on_step_tween_finished, CONNECT_ONE_SHOT)

	_update_movement_indicator()

func _on_step_tween_finished():
	_current_tween = null
	emit_signal("step_animation_finished")

func _process(_delta: float):
	# Keep the unit facing up (no rotation from hex grid)
	rotation = 0
	
	# Animate selection ring if selected
	if is_selected and selection_ring.visible:
		selection_ring.rotation += _delta * 2.0

# Inner class for drawing selection ring
class SelectionRingNode extends Node2D:
	func _draw():
		var radius = 28.0
		var color = Color.YELLOW
		var segments = 16
		var gap_ratio = 0.3  # 30% gap between dashes
		
		for i in range(segments):
			var start_angle = i * TAU / segments
			var end_angle = start_angle + (TAU / segments) * (1.0 - gap_ratio)
			draw_arc(Vector2.ZERO, radius, start_angle, end_angle, 8, color, 2.0)
