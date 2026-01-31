extends Node2D
class_name UnitLayer

# Manages all unit visual sprites on the map

signal unit_clicked(unit: Unit)

var unit_manager: UnitManager
var unit_sprites: Dictionary = {}  # unit_id -> UnitSprite
var selected_unit: Unit = null

func setup(p_unit_manager: UnitManager):
	unit_manager = p_unit_manager
	
	# Connect to unit manager signals
	unit_manager.unit_spawned.connect(_on_unit_spawned)
	unit_manager.unit_destroyed.connect(_on_unit_destroyed)
	unit_manager.unit_moved.connect(_on_unit_moved)
	
	# Create sprites for any existing units
	for unit in unit_manager.get_all_units():
		_create_unit_sprite(unit)

func _on_unit_spawned(unit: Unit):
	_create_unit_sprite(unit)

func _on_unit_destroyed(unit: Unit):
	if unit_sprites.has(unit.unit_id):
		var sprite = unit_sprites[unit.unit_id]
		sprite.queue_free()
		unit_sprites.erase(unit.unit_id)
	
	if selected_unit == unit:
		selected_unit = null

func _on_unit_moved(unit: Unit, _from_coord: Vector2i, _to_coord: Vector2i):
	# The UnitSprite handles its own animation via signal
	pass

func _create_unit_sprite(unit: Unit) -> UnitSprite:
	var sprite = UnitSprite.new()
	add_child(sprite)  # Add to tree first so _ready() runs
	sprite.setup(unit)
	unit_sprites[unit.unit_id] = sprite
	return sprite

func get_unit_at_screen_pos(screen_pos: Vector2) -> Unit:
	"""Find unit at screen position"""
	# Convert to world position
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return null
	
	var world_pos = camera.get_global_mouse_position()
	var coord = WorldUtil.pixel_to_axial(world_pos)
	
	if unit_manager:
		return unit_manager.get_unit_at(coord)
	return null

func select_unit(unit: Unit):
	"""Select a unit"""
	# Deselect previous
	if selected_unit and unit_sprites.has(selected_unit.unit_id):
		unit_sprites[selected_unit.unit_id].set_selected(false)
	
	selected_unit = unit
	
	# Select new
	if unit and unit_sprites.has(unit.unit_id):
		unit_sprites[unit.unit_id].set_selected(true)

func deselect_unit():
	"""Deselect current unit"""
	select_unit(null)

func get_selected_unit() -> Unit:
	return selected_unit

func has_selection() -> bool:
	return selected_unit != null

func update_unit_display(unit: Unit):
	"""Force update of a unit's display"""
	if unit_sprites.has(unit.unit_id):
		var sprite = unit_sprites[unit.unit_id]
		sprite._update_health_bar()
		sprite._update_movement_indicator()

func refresh_all():
	"""Refresh all unit sprites"""
	for unit_id in unit_sprites.keys():
		var sprite = unit_sprites[unit_id]
		sprite._update_health_bar()
		sprite._update_movement_indicator()
