extends Node2D

@onready var grid := $HexGrid
@onready var tile_info_panel := $UI/Root/TileInfoPanel

func _ready():
	grid.tile_selected.connect(_on_tile_selected)

func _on_tile_selected(tile: HexTile):
	tile_info_panel.show_tile(tile)

func initialize_world():
	grid.generate_grid()
