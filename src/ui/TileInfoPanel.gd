extends PanelContainer
class_name TileInfoPanel

@onready var title_label = $VBoxContainer/Title
@onready var coords_label = $VBoxContainer/Coords
@onready var terrain_label = $VBoxContainer/Terrain

func show_tile(tile: HexTile):
	visible = true
	title_label.text = "Tile Information"
	coords_label.text = "Coordinates: (%d, %d)" % [tile.q, tile.r]
	terrain_label.text = "Terrain: %s" % tile.terrain_id

func hide_panel():
	visible = false
