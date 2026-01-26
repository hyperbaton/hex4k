extends RefCounted
class_name CityTile

# Represents a tile that belongs to a city
# Note: Building data is now tracked in City.building_instances using BuildingInstance
# This class primarily tracks tile-level data and coordinates

var tile_coord: Vector2i  # Axial coordinates (q, r)
var building_id: String = ""  # Building ID on this tile (for quick reference)
var is_city_center: bool = false
var distance_from_center: int = 0  # Pathfinding distance from city center

func _init(coord: Vector2i):
	tile_coord = coord

func has_building() -> bool:
	return building_id != ""
