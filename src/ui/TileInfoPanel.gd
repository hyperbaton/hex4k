extends PanelContainer
class_name TileInfoPanel

@onready var title_label = $VBoxContainer/Title
@onready var coords_label = $VBoxContainer/Coords
@onready var terrain_label = $VBoxContainer/Terrain

func show_tile(tile: HexTile):
	"""Legacy method for showing a HexTile"""
	visible = true
	title_label.text = "Tile Information"
	coords_label.text = "Coordinates: (%d, %d)" % [tile.data.q, tile.data.r]
	terrain_label.text = "Terrain: %s" % tile.data.terrain_id

func show_tile_view(view: TileView):
	"""New method for showing a TileView with full information"""
	visible = true
	
	# Use the tooltip text which has all the information
	var info = view.get_tooltip_text()
	
	# For now, parse it into the labels
	# TODO: Expand UI to show more info
	title_label.text = "Tile Information"
	coords_label.text = "Coordinates: (%d, %d)" % [view.coord.x, view.coord.y]
	
	var terrain_text = "Terrain: %s" % view.get_terrain_name()
	
	if view.is_claimed():
		terrain_text += "\nCity: %s" % view.get_city_name()
		terrain_text += "\nOwner: %s" % view.get_owner_name()
		
		if view.has_building():
			terrain_text += "\nBuilding: %s" % view.get_building_name()
	
	terrain_label.text = terrain_text

func hide_panel():
	visible = false
