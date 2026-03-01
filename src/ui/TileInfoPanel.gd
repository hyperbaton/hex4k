extends PanelContainer
class_name TileInfoPanel

var title_label: Label
var coords_label: Label
var terrain_label: Label
var modifiers_label: Label = null

func _ready():
	# Create internal structure (supports both scene-based and code-based instantiation)
	var vbox: VBoxContainer = get_node_or_null("VBoxContainer")
	if not vbox:
		vbox = VBoxContainer.new()
		vbox.name = "VBoxContainer"
		add_child(vbox)

	title_label = vbox.get_node_or_null("Title")
	if not title_label:
		title_label = Label.new()
		title_label.name = "Title"
		title_label.add_theme_font_size_override("font_size", 14)
		vbox.add_child(title_label)

	coords_label = vbox.get_node_or_null("Coords")
	if not coords_label:
		coords_label = Label.new()
		coords_label.name = "Coords"
		coords_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(coords_label)

	terrain_label = vbox.get_node_or_null("Terrain")
	if not terrain_label:
		terrain_label = Label.new()
		terrain_label.name = "Terrain"
		terrain_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(terrain_label)

	modifiers_label = Label.new()
	modifiers_label.name = "Modifiers"
	modifiers_label.add_theme_font_size_override("font_size", 12)
	modifiers_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.7))
	vbox.add_child(modifiers_label)

func show_tile(tile: HexTile):
	"""Legacy method for showing a HexTile"""
	visible = true
	title_label.text = "Tile Information"
	coords_label.text = "Coordinates: (%d, %d)" % [tile.data.q, tile.data.r]
	terrain_label.text = "Terrain: %s" % tile.data.terrain_id

	# Show modifiers
	if modifiers_label:
		if tile.data.modifiers.size() > 0:
			var mod_names = []
			for mod_id in tile.data.modifiers:
				mod_names.append(Registry.modifiers.get_modifier_name(mod_id))
			modifiers_label.text = "Features: " + ", ".join(mod_names)
			modifiers_label.visible = true
		else:
			modifiers_label.visible = false

func show_tile_view(view: TileView):
	"""New method for showing a TileView with full information"""
	visible = true

	title_label.text = "Tile Information"
	coords_label.text = "Coordinates: (%d, %d)" % [view.coord.x, view.coord.y]

	var terrain_text = "Terrain: %s" % view.get_terrain_name()

	if view.is_claimed():
		terrain_text += "\nCity: %s" % view.get_city_name()
		terrain_text += "\nOwner: %s" % view.get_owner_name()

		if view.has_building():
			terrain_text += "\nBuilding: %s" % view.get_building_name()

	terrain_label.text = terrain_text

	# Show modifiers (just names - effects are defined on buildings/movement types)
	if modifiers_label:
		var modifiers = view.get_modifiers()
		if modifiers.size() > 0:
			var mod_text = "Features:"
			for mod_id in modifiers:
				var mod_name = Registry.modifiers.get_modifier_name(mod_id)
				var mod_type = Registry.modifiers.get_modifier_type(mod_id)
				mod_text += "\n  • " + mod_name
				if mod_type == "resource_deposit":
					mod_text += " (deposit)"

			modifiers_label.text = mod_text
			modifiers_label.visible = true
		else:
			modifiers_label.visible = false

func show_explored_tile(tile: HexTile):
	"""Show limited info for explored but not currently visible tiles"""
	visible = true
	title_label.text = "Explored Tile"
	coords_label.text = "Coordinates: (%d, %d)" % [tile.data.q, tile.data.r]

	var terrain_name = Registry.localization.get_name("terrain", tile.data.terrain_id)
	if terrain_name == "":
		terrain_name = tile.data.terrain_id
	terrain_label.text = "Terrain: %s\n(Last seen)" % terrain_name

	if modifiers_label:
		modifiers_label.visible = false

func hide_panel():
	visible = false
