extends PanelContainer
class_name TileInfoPanel

@onready var title_label = $VBoxContainer/Title
@onready var coords_label = $VBoxContainer/Coords
@onready var terrain_label = $VBoxContainer/Terrain

var modifiers_label: Label = null

func _ready():
	# Create modifiers label if it doesn't exist
	var vbox = $VBoxContainer
	if vbox:
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

func hide_panel():
	visible = false
