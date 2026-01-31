extends Node2D
class_name UnitVisual

# Visual representation of a unit on the map

const UNIT_SIZE = 48.0
const SELECTION_RING_WIDTH = 3.0
const HEALTH_BAR_WIDTH = 40.0
const HEALTH_BAR_HEIGHT = 6.0
const HEALTH_BAR_OFFSET = -32.0

var unit: Unit = null
var is_selected: bool = false

# Child nodes
var sprite: Sprite2D
var selection_ring: Node2D
var health_bar_bg: ColorRect
var health_bar_fill: ColorRect

# Colors
var selection_color := Color(1.0, 0.8, 0.0, 0.8)  # Golden yellow
var health_color_full := Color(0.2, 0.8, 0.2)     # Green
var health_color_half := Color(0.9, 0.7, 0.1)     # Yellow
var health_color_low := Color(0.9, 0.2, 0.2)      # Red

func _init():
	# Create sprite
	sprite = Sprite2D.new()
	sprite.name = "Sprite"
	add_child(sprite)
	
	# Create selection ring (drawn manually)
	selection_ring = Node2D.new()
	selection_ring.name = "SelectionRing"
	selection_ring.visible = false
	add_child(selection_ring)
	
	# Create health bar background
	health_bar_bg = ColorRect.new()
	health_bar_bg.name = "HealthBarBG"
	health_bar_bg.color = Color(0.2, 0.2, 0.2, 0.8)
	health_bar_bg.size = Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
	health_bar_bg.position = Vector2(-HEALTH_BAR_WIDTH / 2, HEALTH_BAR_OFFSET)
	add_child(health_bar_bg)
	
	# Create health bar fill
	health_bar_fill = ColorRect.new()
	health_bar_fill.name = "HealthBarFill"
	health_bar_fill.color = health_color_full
	health_bar_fill.size = Vector2(HEALTH_BAR_WIDTH - 2, HEALTH_BAR_HEIGHT - 2)
	health_bar_fill.position = Vector2(-HEALTH_BAR_WIDTH / 2 + 1, HEALTH_BAR_OFFSET + 1)
	add_child(health_bar_fill)

func setup(p_unit: Unit):
	unit = p_unit
	
	# Connect to unit signals
	unit.health_changed.connect(_on_health_changed)
	
	# Load sprite texture
	_load_sprite()
	
	# Update health bar
	update_health_bar()

func _load_sprite():
	var unit_data = Registry.units.get_unit(unit.unit_type)
	var visual_data = unit_data.get("visual", {})
	var sprite_path = visual_data.get("sprite", "")
	
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var texture = load(sprite_path)
		if texture:
			sprite.texture = texture
			# Scale to fit UNIT_SIZE
			var tex_size = texture.get_size()
			var scale_factor = UNIT_SIZE / max(tex_size.x, tex_size.y)
			sprite.scale = Vector2(scale_factor, scale_factor)
			return
	
	# Fallback: Create a placeholder colored circle
	_create_placeholder_sprite(visual_data.get("color", "#FFFFFF"))

func _create_placeholder_sprite(color_string: String):
	# Create an image-based placeholder
	var color = Color(color_string)
	var img = Image.create(int(UNIT_SIZE), int(UNIT_SIZE), false, Image.FORMAT_RGBA8)
	
	var center = Vector2(UNIT_SIZE / 2, UNIT_SIZE / 2)
	var radius = UNIT_SIZE / 2 - 2
	
	# Draw a filled circle
	for x in range(int(UNIT_SIZE)):
		for y in range(int(UNIT_SIZE)):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= radius:
				# Add slight gradient for depth
				var shade = 1.0 - (dist / radius) * 0.3
				img.set_pixel(x, y, Color(color.r * shade, color.g * shade, color.b * shade, 1.0))
			elif dist <= radius + 1:
				# Anti-aliased edge
				var alpha = 1.0 - (dist - radius)
				img.set_pixel(x, y, Color(color.r * 0.7, color.g * 0.7, color.b * 0.7, alpha))
	
	var texture = ImageTexture.create_from_image(img)
	sprite.texture = texture

func _draw():
	# Draw selection ring if selected
	if is_selected:
		var radius = UNIT_SIZE / 2 + 4
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, selection_color, SELECTION_RING_WIDTH, true)
		
		# Draw animated dashes
		var time = Time.get_ticks_msec() / 500.0
		for i in range(8):
			var angle = time + i * TAU / 8
			var start_angle = angle
			var end_angle = angle + TAU / 16
			draw_arc(Vector2.ZERO, radius, start_angle, end_angle, 4, Color.WHITE, SELECTION_RING_WIDTH + 1, true)

func set_selected(selected: bool):
	is_selected = selected
	selection_ring.visible = selected
	queue_redraw()

func update_health_bar():
	if unit == null:
		return
	
	var health_pct = unit.get_health_percentage()
	
	# Update fill width
	var fill_width = (HEALTH_BAR_WIDTH - 2) * health_pct
	health_bar_fill.size.x = fill_width
	
	# Update color based on health
	if health_pct > 0.66:
		health_bar_fill.color = health_color_full
	elif health_pct > 0.33:
		health_bar_fill.color = health_color_half
	else:
		health_bar_fill.color = health_color_low
	
	# Hide health bar if at full health
	health_bar_bg.visible = health_pct < 1.0
	health_bar_fill.visible = health_pct < 1.0

func _on_health_changed(_new_health: int, _max_health: int):
	update_health_bar()

func _process(_delta: float):
	# Redraw for selection animation
	if is_selected:
		queue_redraw()
