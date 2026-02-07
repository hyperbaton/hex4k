extends RefCounted
class_name BuildingInstance

# Represents an instance of a building placed in a city tile
# Tracks status, stored resources, construction progress, and upgrades

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

# Upgrade tracking - building operates normally while upgrading
var upgrading_to: String = ""  # Target building ID
var upgrade_turns_remaining: int = 0
var upgrade_total_turns: int = 0
var upgrade_cost_per_turn: Dictionary = {}

# Storage for storage buildings
var stored_resources: Dictionary = {}  # resource_id -> float

# Cache for building data
var _building_data: Dictionary = {}

# Training queue (for buildings that can train units)
var training_unit_id: String = ""  # Currently training unit type
var training_turns_remaining: int = 0
var training_total_turns: int = 0

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
	var base_status = ""
	match status:
		Status.ACTIVE: base_status = "Active"
		Status.EXPECTING_RESOURCES: base_status = "Waiting for Resources"
		Status.CONSTRUCTING: base_status = "Under Construction"
		Status.CONSTRUCTION_PAUSED: base_status = "Construction Paused"
		Status.DISABLED: base_status = "Disabled"
		_: base_status = "Unknown"
	
	# Add upgrade indicator if upgrading
	if is_upgrading():
		var target_name = Registry.get_name_label("building", upgrading_to)
		base_status += " (Upgrading to %s)" % target_name
	
	return base_status

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

# === Upgrade System ===

func is_upgrading() -> bool:
	"""Check if this building is currently being upgraded"""
	return upgrading_to != ""

func is_upgrade_paused() -> bool:
	"""Check if upgrade is paused due to missing resources"""
	# We track this implicitly - if upgrading but didn't progress last turn
	return is_upgrading() and upgrade_cost_per_turn.size() > 0

func can_start_upgrade() -> bool:
	"""Check if this building can start an upgrade"""
	# Cannot upgrade if:
	# - Already upgrading
	# - Under construction
	# - Disabled
	# - No upgrade target defined
	if is_upgrading():
		return false
	if is_under_construction():
		return false
	if is_disabled():
		return false
	
	var target = Registry.buildings.get_upgrade_target(building_id)
	return target != ""

func get_upgrade_target() -> String:
	"""Get the building this can upgrade to"""
	return Registry.buildings.get_upgrade_target(building_id)

func start_upgrade(target_building_id: String, total_turns: int, per_turn_cost: Dictionary):
	"""Start upgrading this building to another building type"""
	upgrading_to = target_building_id
	upgrade_turns_remaining = total_turns
	upgrade_total_turns = total_turns
	upgrade_cost_per_turn = per_turn_cost.duplicate()
	print("BuildingInstance: Started upgrade from %s to %s at %v (%d turns)" % [
		building_id, target_building_id, tile_coord, total_turns
	])

func advance_upgrade() -> bool:
	"""Advance upgrade by one turn. Returns true if completed."""
	if not is_upgrading():
		return false
	
	upgrade_turns_remaining -= 1
	if upgrade_turns_remaining <= 0:
		return true  # Upgrade complete - caller handles the replacement
	return false

func cancel_upgrade() -> Dictionary:
	"""Cancel the current upgrade. Returns info about what was cancelled."""
	var info = {
		"target": upgrading_to,
		"turns_remaining": upgrade_turns_remaining,
		"total_turns": upgrade_total_turns
	}
	upgrading_to = ""
	upgrade_turns_remaining = 0
	upgrade_total_turns = 0
	upgrade_cost_per_turn.clear()
	return info

func get_upgrade_progress_percent() -> float:
	"""Get upgrade progress as percentage (0-100)"""
	if not is_upgrading() or upgrade_total_turns == 0:
		return 0.0
	return float(upgrade_total_turns - upgrade_turns_remaining) / float(upgrade_total_turns) * 100.0

func complete_upgrade() -> String:
	"""
	Complete the upgrade - transforms this building into the target.
	Returns the new building_id.
	Note: Stored resources are preserved if the new building can store them.
	"""
	var new_building_id = upgrading_to
	var old_building_id = building_id
	var preserved_resources = stored_resources.duplicate()
	
	# Update to new building
	building_id = new_building_id
	_building_data = Registry.buildings.get_building(new_building_id)
	
	# Clear upgrade state
	upgrading_to = ""
	upgrade_turns_remaining = 0
	upgrade_total_turns = 0
	upgrade_cost_per_turn.clear()
	
	# Re-initialize storage for new building
	stored_resources.clear()
	_init_storage()
	
	# Transfer resources that the new building can store
	for resource_id in preserved_resources.keys():
		var amount = preserved_resources[resource_id]
		if amount > 0 and can_store(resource_id):
			var capacity = get_storage_capacity(resource_id)
			stored_resources[resource_id] = min(amount, capacity)
			if amount > capacity:
				print("  Upgrade spillage: %.1f %s (exceeded new capacity)" % [amount - capacity, resource_id])
	
	print("BuildingInstance: Completed upgrade from %s to %s at %v" % [
		old_building_id, new_building_id, tile_coord
	])
	
	return new_building_id

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

func apply_decay(adjacency_decay_bonus: Dictionary = {}) -> Dictionary:
	"""Apply decay to stored resources. Returns dictionary of decayed amounts.
	adjacency_decay_bonus: resource_id -> float modifier from nearby buildings (negative = less decay)"""
	var decayed: Dictionary = {}
	
	for resource_id in stored_resources.keys():
		var base_decay_rate = Registry.resources.get_decay_rate(resource_id)
		if base_decay_rate <= 0:
			continue
		
		var decay_modifier = get_decay_reduction(resource_id)
		# Apply adjacency bonuses (can reduce further, clamp to minimum 0.05)
		decay_modifier += adjacency_decay_bonus.get(resource_id, 0.0)
		decay_modifier = max(0.05, decay_modifier)
		var actual_decay_rate = base_decay_rate * decay_modifier
		
		var stored = stored_resources[resource_id]
		var decay_amount = stored * actual_decay_rate
		
		if decay_amount > 0:
			stored_resources[resource_id] = max(0.0, stored - decay_amount)
			decayed[resource_id] = decay_amount
	
	return decayed

# === Training ===

func can_train_units() -> bool:
	"""Check if this building can train any units"""
	if not is_operational():
		return false
	# Check if any unit lists this building in trained_at
	for unit_id in Registry.units.get_all_unit_ids():
		var trained_at = Registry.units.get_trained_at(unit_id)
		if building_id in trained_at:
			return true
	return false

func can_train_unit(unit_id: String) -> bool:
	"""Check if this building can train a specific unit"""
	if not is_operational():
		return false
	var trained_at = Registry.units.get_trained_at(unit_id)
	return building_id in trained_at

func is_training() -> bool:
	"""Check if this building is currently training a unit"""
	return training_unit_id != ""

func start_training(unit_id: String, turns: int) -> bool:
	"""Start training a unit. Returns false if already training."""
	if is_training():
		return false
	if not can_train_unit(unit_id):
		return false
	
	training_unit_id = unit_id
	training_turns_remaining = turns
	training_total_turns = turns
	print("BuildingInstance: Started training %s at %v (%d turns)" % [unit_id, tile_coord, turns])
	return true

func cancel_training() -> String:
	"""Cancel current training. Returns the unit_id that was cancelled."""
	var unit_id = training_unit_id
	training_unit_id = ""
	training_turns_remaining = 0
	training_total_turns = 0
	return unit_id

func advance_training() -> String:
	"""Advance training by one turn. Returns unit_id if completed, empty string otherwise."""
	if not is_training():
		return ""
	
	training_turns_remaining -= 1
	
	if training_turns_remaining <= 0:
		# Training complete!
		var completed_unit = training_unit_id
		training_unit_id = ""
		training_turns_remaining = 0
		training_total_turns = 0
		return completed_unit
	
	return ""

func get_training_progress_percent() -> float:
	"""Get training progress as percentage (0-100)"""
	if not is_training() or training_total_turns == 0:
		return 0.0
	return float(training_total_turns - training_turns_remaining) / float(training_total_turns) * 100.0

# === Serialization ===

func to_dict() -> Dictionary:
	"""Serialize to dictionary for saving"""
	return {
		"building_id": building_id,
		"tile_coord": [tile_coord.x, tile_coord.y],
		"status": status,
		"turns_remaining": turns_remaining,
		"cost_per_turn": cost_per_turn,
		"stored_resources": stored_resources,
		"training_unit_id": training_unit_id,
		"training_turns_remaining": training_turns_remaining,
		"training_total_turns": training_total_turns,
		"upgrading_to": upgrading_to,
		"upgrade_turns_remaining": upgrade_turns_remaining,
		"upgrade_total_turns": upgrade_total_turns,
		"upgrade_cost_per_turn": upgrade_cost_per_turn
	}

static func from_dict(data: Dictionary) -> BuildingInstance:
	"""Deserialize from dictionary"""
	var coord = Vector2i(data.tile_coord[0], data.tile_coord[1])
	var instance = BuildingInstance.new(data.building_id, coord)
	instance.status = data.status
	instance.turns_remaining = data.get("turns_remaining", 0)
	instance.cost_per_turn = data.get("cost_per_turn", {})
	instance.stored_resources = data.get("stored_resources", {})
	instance.training_unit_id = data.get("training_unit_id", "")
	instance.training_turns_remaining = data.get("training_turns_remaining", 0)
	instance.training_total_turns = data.get("training_total_turns", 0)
	instance.upgrading_to = data.get("upgrading_to", "")
	instance.upgrade_turns_remaining = data.get("upgrade_turns_remaining", 0)
	instance.upgrade_total_turns = data.get("upgrade_total_turns", 0)
	instance.upgrade_cost_per_turn = data.get("upgrade_cost_per_turn", {})
	return instance
