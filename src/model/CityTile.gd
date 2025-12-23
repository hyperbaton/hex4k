extends RefCounted
class_name CityTile

# Represents a tile that belongs to a city

var tile_coord: Vector2i  # Axial coordinates (q, r)
var building_id: String = ""  # Building on this tile (empty string if none)
var is_city_center: bool = false
var distance_from_center: int = 0  # Pathfinding distance from city center

# Resource storage (for storage buildings)
var stored_resources: Dictionary = {}  # resource_id -> float

func _init(coord: Vector2i):
	tile_coord = coord

func has_building() -> bool:
	return building_id != ""

func set_building(id: String):
	building_id = id
	
	# Initialize storage if this building provides storage
	if Registry.buildings.building_exists(id):
		var storage = Registry.buildings.get_storage_provided(id)
		for resource_id in storage.keys():
			if not stored_resources.has(resource_id):
				stored_resources[resource_id] = 0.0

func remove_building():
	building_id = ""
	# Note: stored_resources kept for now, could transfer to city center

func get_stored_amount(resource_id: String) -> float:
	return stored_resources.get(resource_id, 0.0)

func add_resource(resource_id: String, amount: float):
	stored_resources[resource_id] = stored_resources.get(resource_id, 0.0) + amount

func remove_resource(resource_id: String, amount: float) -> float:
	var available = stored_resources.get(resource_id, 0.0)
	var removed = min(available, amount)
	stored_resources[resource_id] = available - removed
	return removed

func get_storage_capacity(resource_id: String) -> float:
	if not has_building():
		return 0.0
	
	var storage = Registry.buildings.get_storage_provided(building_id)
	return storage.get(resource_id, 0.0)
