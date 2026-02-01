extends Node2D
class_name HexTile

var terrain_id: String
var modifier_ids: Array = []
var building_id: String = ""
var unit_id: String = ""
var is_under_construction: bool = false

var data: HexTileData
var terrain_sprite: Sprite2D
var building_sprite: Sprite2D
var modifier_container: Node2D
var modifier_sprites: Array[Sprite2D] = []
var use_sprite := false
var visual_needs_update := false

# Cache for loaded textures
static var texture_cache: Dictionary = {}
static var texture_load_attempted: Dictionary = {}
static var building_texture_cache: Dictionary = {}
static var building_texture_load_attempted: Dictionary = {}
static var modifier_texture_cache: Dictionary = {}
static var modifier_texture_load_attempted: Dictionary = {}

func _ready():
	# Create sprite for terrain
	terrain_sprite = Sprite2D.new()
	terrain_sprite.centered = true
	add_child(terrain_sprite)
	
	# Create container for modifier icons (on top of terrain, below building)
	modifier_container = Node2D.new()
	modifier_container.name = "ModifierContainer"
	add_child(modifier_container)
	
	# Create sprite for building (on top of everything)
	building_sprite = Sprite2D.new()
	building_sprite.centered = true
	building_sprite.visible = false
	add_child(building_sprite)
	
	# If setup was called before _ready, update visuals now
	if visual_needs_update:
		update_visual()

func setup_from_data(p_data: HexTileData):
	data = p_data
	modifier_ids = data.modifiers.duplicate()
	position = WorldUtil.axial_to_pixel(data.q, data.r)
	
	# If we're already in the tree, update now. Otherwise, flag for later.
	if is_inside_tree() and terrain_sprite:
		update_visual()
	else:
		visual_needs_update = true

var selected := false

func set_selected(value: bool):
	selected = value
	queue_redraw()

func _draw():
	# If no sprite, draw colored hex
	if not use_sprite:
		var color := get_terrain_color()
		draw_colored_polygon(get_hex_polygon_points(), color)
		draw_polyline(get_hex_points(), Color(0, 0, 0, 0.3), 1.0)
	
	# Get modifiers that are part of the tile type (don't draw overlay for these)
	var tile_type_id = data.get_tile_type_id()
	var tile_type_data = Registry.tile_types.get_tile_type(tile_type_id)
	var tile_type_modifiers = tile_type_data.get("required_modifiers", []) if not tile_type_data.is_empty() else []
	
	# Draw modifier overlay colors only for modifiers not in tile type (subtle tint)
	for mod_id in modifier_ids:
		if mod_id in tile_type_modifiers:
			continue  # Skip modifiers already represented by tile type
		var mod_data = Registry.modifiers.get_modifier(mod_id)
		var visual = mod_data.get("visual", {})
		var overlay_color_hex = visual.get("overlay_color", "")
		if overlay_color_hex != "":
			var overlay_color = Color.html(overlay_color_hex)
			draw_colored_polygon(get_hex_polygon_points(), overlay_color)
	
	# Draw selection highlight on top
	if selected:
		draw_polyline(get_hex_points(), Color.YELLOW, 3.0)

func get_hex_points() -> PackedVector2Array:
	"""Get hex outline points (7 points to close the shape)"""
	var points := PackedVector2Array()
	for i in range(7):
		var angle = PI / 3 * (i % 6) + PI / 6
		points.append(Vector2(
			WorldConfig.HEX_SIZE * sin(angle),
			WorldConfig.HEX_SIZE * cos(angle)
		))
	return points

func get_hex_polygon_points() -> PackedVector2Array:
	"""Get hex polygon points (6 points for fill)"""
	var points := PackedVector2Array()
	for i in range(6):
		var angle = PI / 3 * i + PI / 6
		points.append(Vector2(
			WorldConfig.HEX_SIZE * sin(angle),
			WorldConfig.HEX_SIZE * cos(angle)
		))
	return points

func update_visual():
	use_sprite = false
	
	if terrain_sprite:
		# Resolve tile type based on terrain + modifiers
		var tile_type_id = data.get_tile_type_id()
		
		# Try to load tile type sprite first, fallback to terrain
		var texture = load_tile_type_texture(tile_type_id)
		if not texture:
			texture = load_terrain_texture(data.terrain_id)
		
		if texture:
			terrain_sprite.texture = texture
			terrain_sprite.visible = true
			# Scale sprite to fit hex size (hex height is HEX_SIZE * 2)
			var target_size = WorldConfig.HEX_SIZE * 2.0
			var scale_factor = target_size / max(texture.get_width(), texture.get_height())
			terrain_sprite.scale = Vector2(scale_factor, scale_factor)
			use_sprite = true
		else:
			terrain_sprite.visible = false
	
	# Update modifier visuals (for modifiers that don't affect tile type)
	update_modifier_visuals()
	
	# Update building visual
	update_building_visual()
	
	queue_redraw()

func update_modifier_visuals():
	"""Update modifier icon sprites (for modifiers not represented by tile type)"""
	# Clear existing modifier sprites
	for sprite in modifier_sprites:
		sprite.queue_free()
	modifier_sprites.clear()
	
	if not modifier_container:
		return
	
	# Get modifiers that are part of the tile type (don't show icons for these)
	var tile_type_id = data.get_tile_type_id()
	var tile_type_data = Registry.tile_types.get_tile_type(tile_type_id)
	var tile_type_modifiers = tile_type_data.get("required_modifiers", []) if not tile_type_data.is_empty() else []
	
	# Filter out modifiers already represented by tile type
	var modifiers_to_show: Array = []
	for mod_id in modifier_ids:
		if not mod_id in tile_type_modifiers:
			modifiers_to_show.append(mod_id)
	
	if modifiers_to_show.is_empty():
		return
	
	# Create icons for each remaining modifier
	var icon_size = WorldConfig.HEX_SIZE * 0.5  # Slightly larger icons
	var icon_spacing = icon_size * 0.9
	var start_offset = -icon_spacing * (modifiers_to_show.size() - 1) / 2.0
	
	for i in range(modifiers_to_show.size()):
		var mod_id = modifiers_to_show[i]
		var texture = load_modifier_texture(mod_id)
		
		if texture:
			var sprite = Sprite2D.new()
			sprite.texture = texture
			sprite.centered = true
			
			# Scale to icon size
			var scale_factor = icon_size / max(texture.get_width(), texture.get_height())
			sprite.scale = Vector2(scale_factor, scale_factor)
			
			# Position icons in a row at the bottom of the hex
			sprite.position = Vector2(
				start_offset + i * icon_spacing,
				WorldConfig.HEX_SIZE * 0.5  # Bottom of hex
			)
			
			modifier_container.add_child(sprite)
			modifier_sprites.append(sprite)

func load_modifier_texture(modifier_id: String) -> Texture2D:
	"""Load and cache modifier texture"""
	# Return cached texture if available
	if modifier_texture_cache.has(modifier_id):
		return modifier_texture_cache[modifier_id]
	
	# Don't retry failed loads
	if modifier_texture_load_attempted.get(modifier_id, false):
		return null
	
	modifier_texture_load_attempted[modifier_id] = true
	
	# Get icon path from modifier data
	var mod_data = Registry.modifiers.get_modifier(modifier_id)
	var visual = mod_data.get("visual", {})
	var icon_path = visual.get("icon", "")
	
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var texture = load(icon_path)
		if texture:
			modifier_texture_cache[modifier_id] = texture
			return texture
	
	# Try default path
	var default_path = "res://assets/icons/modifiers/" + modifier_id + ".svg"
	if ResourceLoader.exists(default_path):
		var texture = load(default_path)
		if texture:
			modifier_texture_cache[modifier_id] = texture
			return texture
	
	# Try PNG fallback
	var png_path = default_path.replace(".svg", ".png")
	if ResourceLoader.exists(png_path):
		var texture = load(png_path)
		if texture:
			modifier_texture_cache[modifier_id] = texture
			return texture
	
	return null

func set_building(new_building_id: String, under_construction: bool = false):
	"""Set the building on this tile"""
	building_id = new_building_id
	is_under_construction = under_construction
	update_building_visual()

func clear_building():
	"""Remove the building from this tile"""
	building_id = ""
	is_under_construction = false
	if building_sprite:
		building_sprite.visible = false

func update_building_visual():
	"""Update the building sprite"""
	if not building_sprite:
		return
	
	if building_id == "":
		building_sprite.visible = false
		return
	
	# Determine which sprite to show
	var sprite_id = building_id
	if is_under_construction:
		sprite_id = "construction"
	
	# Try to load building texture
	var texture = load_building_texture(sprite_id)
	if texture:
		building_sprite.texture = texture
		building_sprite.visible = true
		# Scale building sprite to fit nicely on hex
		var target_size = WorldConfig.HEX_SIZE * 1.5  # Slightly smaller than terrain
		var scale_factor = target_size / max(texture.get_width(), texture.get_height())
		building_sprite.scale = Vector2(scale_factor, scale_factor)
		# Offset building sprite slightly upward to sit nicely on terrain
		building_sprite.position = Vector2(0, -WorldConfig.HEX_SIZE * 0.1)
	else:
		building_sprite.visible = false

func load_building_texture(sprite_id: String) -> Texture2D:
	"""Load and cache building texture"""
	# Return cached texture if available
	if building_texture_cache.has(sprite_id):
		return building_texture_cache[sprite_id]
	
	# Don't retry failed loads
	if building_texture_load_attempted.get(sprite_id, false):
		return null
	
	building_texture_load_attempted[sprite_id] = true
	
	# Try to get path from building data
	var svg_path = "res://assets/buildings/" + sprite_id + ".svg"
	
	# Check if building exists in registry and has custom path
	if sprite_id != "construction" and Registry.buildings.building_exists(sprite_id):
		var building_data = Registry.buildings.get_building(sprite_id)
		if building_data.has("visual") and building_data.visual.has("sprite"):
			svg_path = building_data.visual.sprite
	
	if ResourceLoader.exists(svg_path):
		var texture = load(svg_path)
		if texture:
			building_texture_cache[sprite_id] = texture
			return texture
	
	# Try PNG fallback
	var png_path = svg_path.replace(".svg", ".png")
	if ResourceLoader.exists(png_path):
		var texture = load(png_path)
		if texture:
			building_texture_cache[sprite_id] = texture
			return texture
	
	return null

# Cache for tile type textures
static var tile_type_texture_cache: Dictionary = {}
static var tile_type_texture_load_attempted: Dictionary = {}

func load_tile_type_texture(tile_type_id: String) -> Texture2D:
	"""Load and cache tile type texture"""
	# Return cached texture if available
	if tile_type_texture_cache.has(tile_type_id):
		return tile_type_texture_cache[tile_type_id]
	
	# Don't retry failed loads
	if tile_type_texture_load_attempted.get(tile_type_id, false):
		return null
	
	tile_type_texture_load_attempted[tile_type_id] = true
	
	# Get visual path from tile type registry
	var tile_type_data = Registry.tile_types.get_tile_type(tile_type_id)
	if not tile_type_data.is_empty():
		var visual = tile_type_data.get("visual", {})
		var sprite_path = visual.get("sprite", "")
		if sprite_path != "" and ResourceLoader.exists(sprite_path):
			var texture = load(sprite_path)
			if texture:
				tile_type_texture_cache[tile_type_id] = texture
				return texture
	
	# Try default path in tiles folder
	var svg_path = "res://assets/tiles/" + tile_type_id + ".svg"
	if ResourceLoader.exists(svg_path):
		var texture = load(svg_path)
		if texture:
			tile_type_texture_cache[tile_type_id] = texture
			return texture
	
	# Try PNG fallback
	var png_path = "res://assets/tiles/" + tile_type_id + ".png"
	if ResourceLoader.exists(png_path):
		var texture = load(png_path)
		if texture:
			tile_type_texture_cache[tile_type_id] = texture
			return texture
	
	return null

func load_terrain_texture(terrain_id: String) -> Texture2D:
	"""Load and cache terrain texture"""
	# Return cached texture if available
	if texture_cache.has(terrain_id):
		return texture_cache[terrain_id]
	
	# Don't retry failed loads
	if texture_load_attempted.get(terrain_id, false):
		return null
	
	texture_load_attempted[terrain_id] = true
	
	# Try to load SVG
	var svg_path = "res://assets/terrains/" + terrain_id + ".svg"
	if ResourceLoader.exists(svg_path):
		var texture = load(svg_path)
		if texture:
			texture_cache[terrain_id] = texture
			return texture
	
	# Try PNG fallback
	var png_path = "res://assets/terrains/" + terrain_id + ".png"
	if ResourceLoader.exists(png_path):
		var texture = load(png_path)
		if texture:
			texture_cache[terrain_id] = texture
			return texture
	
	return null

func get_terrain_color() -> Color:
	"""Get color from tile type or terrain registry"""
	# First try tile type color
	var tile_type_id = data.get_tile_type_id()
	var tile_type_data = Registry.tile_types.get_tile_type(tile_type_id)
	if not tile_type_data.is_empty():
		var visual = tile_type_data.get("visual", {})
		var color_hex = visual.get("color", "")
		if color_hex != "":
			return Color.html(color_hex)
	
	# Fallback to terrain color
	var terrain_data = Registry.terrains.get_terrain(data.terrain_id)
	var visual = terrain_data.get("visual", {})
	var color_hex = visual.get("color", "")
	
	if color_hex != "":
		return Color.html(color_hex)
	
	# Fallback colors for backwards compatibility
	match data.terrain_id:
		"river": return Color(0.25, 0.56, 0.75)
		"deep_ocean": return Color(0.10, 0.23, 0.42)
		"ocean": return Color(0.16, 0.35, 0.54)
		"coast": return Color(0.29, 0.54, 0.69)
		"lake": return Color(0.23, 0.48, 0.67)
		"sandy_desert": return Color(0.91, 0.84, 0.63)
		"rocky_desert": return Color(0.78, 0.66, 0.47)
		"steppe": return Color(0.78, 0.72, 0.38)
		"savannah": return Color(0.72, 0.66, 0.31)
		"plains": return Color(0.42, 0.67, 0.31)
		"meadow": return Color(0.50, 0.75, 0.38)
		"floodplains": return Color(0.31, 0.63, 0.25)
		"marsh": return Color(0.31, 0.47, 0.31)
		"tundra": return Color(0.66, 0.72, 0.63)
		"rolling_hills": return Color(0.54, 0.60, 0.38)
		"sharp_hills": return Color(0.48, 0.54, 0.35)
		"mountain": return Color(0.42, 0.42, 0.35)
		"high_mountain": return Color(0.91, 0.91, 0.94)
		"glacier": return Color(0.85, 0.91, 0.97)
		_: return Color.MAGENTA
