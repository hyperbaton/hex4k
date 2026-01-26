extends RefCounted
class_name BuildingInstance

# Represents an instance of a building placed in a city tile
# Tracks status, stored resources, and construction progress

enum Status {
	ACTIVE,              # Operating normally, will produce
	EXPECTING_RESOURCES, # Waiting for resources, will try to activate
	CONSTRUCTING,        # Under construction, progressing
	CONSTRUCTION_PAUSED, # Construction halted due to missing resources
	DISABLED             # Manually disabled by player
}

var building_id: String
var tile_coord: Vector2i
var status: Status = Status.CONSTRUCTING

# Construction tracking
var turns_remaining: int = 0
var cost_per_turn: Dictionary = {}

# Storage for storage buildings
var stored_resources: Dictionary = {}  # resource_id -> float

# Cache for building data
var _building_data: Dictionary = {}

func _init(id: String, coord: Vector2i):
	building_id = id
	tile_coord = coord
	_building_data = Registry.buildings.get_building(id)
	
	# Initialize storage capacity if this building provides storage
	_init_storage()

func _init_storage():
	"""Initialize storage slots based on building definition"""
	var storage = Registry.buildings.get_storage_provided(building_id)
	for resource_id in storage.keys():
		stored_resources[resource_id] = 0.0

# === Status Management ===

func is_active() -> bool:
	return status == Status.ACTIVE

func is_expecting_resources() -> bool:
	return status == Status.EXPECTING_RESOURCES

func is_constructing() -> bool:
	return status == Status.CONSTRUCTING

func is_construction_paused() -> bool:
	return status == Status.CONSTRUCTION_PAUSED

func is_disabled() -> bool:
	return status == Status.DISABLED

func is_operational() -> bool:
	"""Returns true if the building is operational (not under construction or disabled)"""
	return status == Status.ACTIVE or status == Status.EXPECTING_RESOURCES

func can_produce() -> bool:
	"""Returns true if the building can produce this turn (only ACTIVE)"""
	return status == Status.ACTIVE

func is_under_construction() -> bool:
	"""Returns true if the building is being built (CONSTRUCTING or CONSTRUCTION_PAUSED)"""
	return status == Status.CONSTRUCTING or status == Status.CONSTRUCTION_PAUSED

func set_active():
	status = Status.ACTIVE

func set_expecting_resources():
	status = Status.EXPECTING_RESOURCES

func set_constructing():
	status = Status.CONSTRUCTING

func set_construction_paused():
	status = Status.CONSTRUCTION_PAUSED

func set_disabled():
	status = Status.DISABLED

func get_status_name() -> String:
	match status:
		Status.ACTIVE: return "Active"
		Status.EXPECTING_RESOURCES: return "Waiting for Resources"
		Status.CONSTRUCTING: return "Under Construction"
		Status.CONSTRUCTION_PAUSED: return "Construction Paused"
		Status.DISABLED: return "Disabled"
	return "Unknown"

# === Construction ===

func start_construction(total_turns: int, per_turn_cost: Dictionary):
	"""Initialize construction for this building"""
	status = Status.CONSTRUCTING
	turns_remaining = total_turns
	cost_per_turn = per_turn_cost.duplicate()

func advance_construction() -> bool:
	"""Advance construction by one turn. Returns true if completed."""
	turns_remaining -= 1
	if turns_remaining <= 0:
		complete_construction()
		return true
	return false

func complete_construction():
	"""Mark construction as complete"""
	status = Status.EXPECTING_RESOURCES
	turns_remaining = 0
	cost_per_turn.clear()

# === Resource Storage ===

func get_storage_capacity(resource_id: String) -> float:
	"""Get the storage capacity for a specific resource"""
	var storage = Registry.buildings.get_storage_provided(building_id)
	return storage.get(resource_id, 0.0)

func get_stored_amount(resource_id: String) -> float:
	"""Get the amount of a resource stored"""
	return stored_resources.get(resource_id, 0.0)

func get_available_space(resource_id: String) -> float:
	"""Get the available space for a resource"""
	var capacity = get_storage_capacity(resource_id)
	var stored = get_stored_amount(resource_id)
	return max(0.0, capacity - stored)

func can_store(resource_id: String) -> bool:
	"""Check if this building can store a specific resource"""
	return get_storage_capacity(resource_id) > 0

func add_resource(resource_id: String, amount: float) -> float:
	"""
	Add resources to storage. Returns the amount actually stored.
	Excess is not stored (caller should handle spillage).
	"""
	if not can_store(resource_id):
		return 0.0
	
	var available_space = get_available_space(resource_id)
	var to_store = min(amount, available_space)
	
	stored_resources[resource_id] = get_stored_amount(resource_id) + to_store
	return to_store

func remove_resource(resource_id: String, amount: float) -> float:
	"""
	Remove resources from storage. Returns the amount actually removed.
	"""
	var stored = get_stored_amount(resource_id)
	var to_remove = min(amount, stored)
	
	stored_resources[resource_id] = stored - to_remove
	return to_remove

func get_all_stored_resources() -> Dictionary:
	"""Get a copy of all stored resources"""
	return stored_resources.duplicate()

# === Production & Consumption ===

func get_production() -> Dictionary:
	"""Get what this building produces per turn"""
	return Registry.buildings.get_production_per_turn(building_id)

func get_consumption() -> Dictionary:
	"""Get what this building consumes per turn"""
	return Registry.buildings.get_consumption_per_turn(building_id)

func get_penalty() -> Dictionary:
	"""Get the penalty applied when consumption is not met"""
	if _building_data.has("per_turn_penalty"):
		return _building_data.per_turn_penalty
	return {}

func get_research_output() -> Dictionary:
	"""Get the research output for tech branches"""
	return Registry.buildings.get_branch_specific_research(building_id)

# === Admin Cost ===

func get_admin_cost(distance_from_center: int) -> float:
	"""Get the admin cost for this building based on distance"""
	if is_disabled():
		# Disabled buildings may have reduced admin cost
		return get_disabled_admin_cost()
	return Registry.buildings.get_admin_cost(building_id, distance_from_center)

func get_disabled_admin_cost() -> float:
	"""Get the admin cost when disabled (default 0)"""
	if _building_data.has("disabled_admin_cost"):
		return _building_data.disabled_admin_cost
	return 0.0

# === Decay ===

func get_decay_reduction(resource_id: String) -> float:
	"""Get the decay reduction multiplier for a resource (1.0 = no reduction)"""
	var decay_reduction = Registry.buildings.get_storage_decay_reduction(building_id)
	return decay_reduction.get(resource_id, 1.0)

func apply_decay() -> Dictionary:
	"""Apply decay to stored resources. Returns dictionary of decayed amounts."""
	var decayed: Dictionary = {}
	
	for resource_id in stored_resources.keys():
		var base_decay_rate = Registry.resources.get_decay_rate(resource_id)
		if base_decay_rate <= 0:
			continue
		
		var decay_modifier = get_decay_reduction(resource_id)
		var actual_decay_rate = base_decay_rate * decay_modifier
		
		var stored = stored_resources[resource_id]
		var decay_amount = stored * actual_decay_rate
		
		if decay_amount > 0:
			stored_resources[resource_id] = max(0.0, stored - decay_amount)
			decayed[resource_id] = decay_amount
	
	return decayed

# === Serialization ===

func to_dict() -> Dictionary:
	"""Serialize to dictionary for saving"""
	return {
		"building_id": building_id,
		"tile_coord": [tile_coord.x, tile_coord.y],
		"status": status,
		"turns_remaining": turns_remaining,
		"cost_per_turn": cost_per_turn,
		"stored_resources": stored_resources
	}

static func from_dict(data: Dictionary) -> BuildingInstance:
	"""Deserialize from dictionary"""
	var coord = Vector2i(data.tile_coord[0], data.tile_coord[1])
	var instance = BuildingInstance.new(data.building_id, coord)
	instance.status = data.status
	instance.turns_remaining = data.get("turns_remaining", 0)
	instance.cost_per_turn = data.get("cost_per_turn", {})
	instance.stored_resources = data.get("stored_resources", {})
	return instance
