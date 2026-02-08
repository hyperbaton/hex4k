extends RefCounted
class_name BuildingInstance

# Represents an instance of a building placed in a city tile.
# Uses StoragePool model for resource storage.
# Production/consumption use unified array format.

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

# Storage pools — replaces flat stored_resources dict
var storage_pools: Array = []  # Array of StoragePool instances

# Cache for building data
var _building_data: Dictionary = {}

# Training queue (for buildings that can train units)
var training_unit_id: String = ""  # Currently training unit type
var training_turns_remaining: int = 0
var training_total_turns: int = 0

# === StoragePool Inner Class ===

class StoragePool:
	var capacity: float = 0.0
	var accepted_resources: Array = []  # Explicit resource IDs
	var accepted_tags: Array = []       # Tag-based matching
	var stored: Dictionary = {}         # resource_id -> float
	var decay_reduction: Dictionary = {}  # resource_id -> float multiplier
	
	func _init(pool_def: Dictionary = {}):
		capacity = pool_def.get("capacity", 0.0)
		accepted_resources = pool_def.get("accepted_resources", [])
		accepted_tags = pool_def.get("accepted_tags", [])
		decay_reduction = pool_def.get("decay_reduction", {})
	
	func get_total_stored() -> float:
		var total := 0.0
		for amount in stored.values():
			total += amount
		return total
	
	func get_available_space() -> float:
		return max(0.0, capacity - get_total_stored())
	
	func can_accept(resource_id: String) -> bool:
		"""Check if this pool accepts a specific resource by ID or tag."""
		if resource_id in accepted_resources:
			return true
		for tag in accepted_tags:
			if Registry.resources.has_tag(resource_id, tag):
				return true
		return false
	
	func add(resource_id: String, amount: float) -> float:
		"""Add resource to pool. Returns amount actually stored."""
		if not can_accept(resource_id):
			return 0.0
		var space = get_available_space()
		var to_store = min(amount, space)
		if to_store > 0:
			stored[resource_id] = stored.get(resource_id, 0.0) + to_store
		return to_store
	
	func remove(resource_id: String, amount: float) -> float:
		"""Remove resource from pool. Returns amount actually removed."""
		var current = stored.get(resource_id, 0.0)
		var to_remove = min(amount, current)
		if to_remove > 0:
			stored[resource_id] = current - to_remove
			if stored[resource_id] <= 0.001:
				stored.erase(resource_id)
		return to_remove
	
	func get_stored_amount(resource_id: String) -> float:
		return stored.get(resource_id, 0.0)
	
	func get_decay_reduction_for(resource_id: String) -> float:
		"""Get decay reduction multiplier. 1.0 = no reduction applied to this pool."""
		return decay_reduction.get(resource_id, 1.0)
	
	func to_dict() -> Dictionary:
		return {
			"capacity": capacity,
			"accepted_resources": accepted_resources.duplicate(),
			"accepted_tags": accepted_tags.duplicate(),
			"stored": stored.duplicate(),
			"decay_reduction": decay_reduction.duplicate()
		}
	
	static func from_dict(data: Dictionary) -> StoragePool:
		var pool = StoragePool.new()
		pool.capacity = data.get("capacity", 0.0)
		pool.accepted_resources = data.get("accepted_resources", [])
		pool.accepted_tags = data.get("accepted_tags", [])
		pool.stored = data.get("stored", {})
		pool.decay_reduction = data.get("decay_reduction", {})
		return pool

# === Initialization ===

func _init(id: String, coord: Vector2i):
	building_id = id
	tile_coord = coord
	_building_data = Registry.buildings.get_building(id)
	_init_storage_pools()

func _init_storage_pools():
	"""Initialize storage pools from building definition."""
	storage_pools.clear()
	var pool_defs = Registry.buildings.get_storage_pools(building_id)
	for pool_def in pool_defs:
		var pool = StoragePool.new(pool_def)
		storage_pools.append(pool)

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
	return is_upgrading() and upgrade_cost_per_turn.size() > 0

func can_start_upgrade() -> bool:
	"""Check if this building can start an upgrade"""
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
	"""Complete the upgrade - transforms this building into the target.
	Returns the new building_id. Stored resources are preserved where possible."""
	var new_building_id = upgrading_to
	var old_building_id = building_id
	
	# Collect all stored resources before changing pools
	var preserved_resources := {}
	for pool in storage_pools:
		for res_id in pool.stored.keys():
			preserved_resources[res_id] = preserved_resources.get(res_id, 0.0) + pool.stored[res_id]
	
	# Update to new building
	building_id = new_building_id
	_building_data = Registry.buildings.get_building(new_building_id)
	
	# Clear upgrade state
	upgrading_to = ""
	upgrade_turns_remaining = 0
	upgrade_total_turns = 0
	upgrade_cost_per_turn.clear()
	
	# Re-initialize storage pools for new building
	_init_storage_pools()
	
	# Transfer resources that the new building can store
	for res_id in preserved_resources.keys():
		var amount = preserved_resources[res_id]
		if amount > 0:
			var stored = add_resource(res_id, amount)
			if stored < amount:
				print("  Upgrade spillage: %.1f %s (exceeded new capacity)" % [amount - stored, res_id])
	
	print("BuildingInstance: Completed upgrade from %s to %s at %v" % [
		old_building_id, new_building_id, tile_coord
	])
	
	return new_building_id

# === Resource Storage (Pool Model) ===

func can_store(resource_id: String) -> bool:
	"""Check if any pool in this building can accept a specific resource."""
	for pool in storage_pools:
		if pool.can_accept(resource_id):
			return true
	return false

func get_storage_capacity(resource_id: String) -> float:
	"""Get total storage capacity for a resource across all accepting pools."""
	var total := 0.0
	for pool in storage_pools:
		if pool.can_accept(resource_id):
			total += pool.capacity
	return total

func get_stored_amount(resource_id: String) -> float:
	"""Get total stored amount of a resource across all pools."""
	var total := 0.0
	for pool in storage_pools:
		total += pool.get_stored_amount(resource_id)
	return total

func get_available_space(resource_id: String) -> float:
	"""Get available space for a resource across all accepting pools."""
	var total := 0.0
	for pool in storage_pools:
		if pool.can_accept(resource_id):
			total += pool.get_available_space()
	return total

func add_resource(resource_id: String, amount: float) -> float:
	"""Add resources to storage pools. Returns the amount actually stored.
	Fills pools in order; excess is not stored (caller handles spillage)."""
	var remaining = amount
	var total_stored := 0.0
	
	for pool in storage_pools:
		if remaining <= 0:
			break
		var stored = pool.add(resource_id, remaining)
		total_stored += stored
		remaining -= stored
	
	return total_stored

func remove_resource(resource_id: String, amount: float) -> float:
	"""Remove resources from storage pools. Returns amount actually removed.
	Scans all pools for this resource."""
	var remaining = amount
	var total_removed := 0.0
	
	for pool in storage_pools:
		if remaining <= 0:
			break
		var removed = pool.remove(resource_id, remaining)
		total_removed += removed
		remaining -= removed
	
	return total_removed

func get_all_stored_resources() -> Dictionary:
	"""Get a combined view of all stored resources across all pools."""
	var result := {}
	for pool in storage_pools:
		for res_id in pool.stored.keys():
			result[res_id] = result.get(res_id, 0.0) + pool.stored[res_id]
	return result

func get_resources_by_tag(tag: String) -> Dictionary:
	"""Get all stored resources that have a specific tag. Returns {resource_id: amount}."""
	var result := {}
	var all_stored = get_all_stored_resources()
	for res_id in all_stored.keys():
		if Registry.resources.has_tag(res_id, tag):
			result[res_id] = all_stored[res_id]
	return result

func remove_resource_by_tag(tag: String, amount: float) -> Dictionary:
	"""Remove resources by tag, consuming from the most abundant first.
	Returns {resource_id: amount_removed} for each resource consumed."""
	var tagged = get_resources_by_tag(tag)
	if tagged.is_empty():
		return {}
	
	# Sort by abundance (most first), alphabetical tiebreaker
	var sorted_ids := tagged.keys()
	sorted_ids.sort_custom(func(a, b):
		if tagged[a] != tagged[b]:
			return tagged[a] > tagged[b]
		return a < b
	)
	
	var result := {}
	var remaining = amount
	
	for res_id in sorted_ids:
		if remaining <= 0:
			break
		var removed = remove_resource(res_id, remaining)
		if removed > 0:
			result[res_id] = removed
			remaining -= removed
	
	return result

# === Production & Consumption ===

func get_production() -> Array:
	"""Get what this building produces per turn (array format)."""
	return Registry.buildings.get_produces(building_id)

func get_consumption() -> Array:
	"""Get what this building consumes per turn (array format)."""
	return Registry.buildings.get_consumes(building_id)

func get_penalty() -> Array:
	"""Get the penalty applied when consumption is not met (array format)."""
	return Registry.buildings.get_penalty(building_id)

# === Admin Cost (backward compat) ===

func get_admin_cost(distance_from_center: int) -> float:
	"""DEPRECATED: Admin cost is now a consumption entry. This wraps for backward compat."""
	if is_disabled():
		return get_disabled_admin_cost()
	return Registry.buildings.get_admin_cost(building_id, distance_from_center)

func get_disabled_admin_cost() -> float:
	"""Get the admin cost when disabled (default 0)"""
	if _building_data.has("disabled_admin_cost"):
		return _building_data.disabled_admin_cost
	return 0.0

# === Research Output (backward compat) ===

func get_research_output() -> Dictionary:
	"""DEPRECATED: Research is now in produces array. This wraps for backward compat."""
	return Registry.buildings.get_branch_specific_research(building_id)

# === Decay ===

func get_decay_reduction(resource_id: String) -> float:
	"""Get the best decay reduction multiplier for a resource across all pools that store it."""
	var best_reduction := 1.0
	for pool in storage_pools:
		if pool.get_stored_amount(resource_id) > 0:
			var reduction = pool.get_decay_reduction_for(resource_id)
			best_reduction = min(best_reduction, reduction)
	return best_reduction

func apply_decay(adjacency_decay_bonus: Dictionary = {}) -> Dictionary:
	"""Apply decay to stored resources across all pools. Returns dictionary of decayed amounts.
	adjacency_decay_bonus: resource_id -> float modifier from nearby buildings."""
	var decayed: Dictionary = {}
	
	for pool in storage_pools:
		for resource_id in pool.stored.keys():
			var base_decay_rate = Registry.resources.get_decay_rate(resource_id)
			if base_decay_rate <= 0:
				continue
			
			var decay_modifier = pool.get_decay_reduction_for(resource_id)
			# Apply adjacency bonuses (can reduce further, clamp to minimum 0.05)
			decay_modifier += adjacency_decay_bonus.get(resource_id, 0.0)
			decay_modifier = max(0.05, decay_modifier)
			var actual_decay_rate = base_decay_rate * decay_modifier
			
			var stored = pool.stored[resource_id]
			var decay_amount = stored * actual_decay_rate
			
			if decay_amount > 0:
				pool.stored[resource_id] = max(0.0, stored - decay_amount)
				decayed[resource_id] = decayed.get(resource_id, 0.0) + decay_amount
				if pool.stored[resource_id] <= 0.001:
					pool.stored.erase(resource_id)
	
	return decayed

# === Training ===

func can_train_units() -> bool:
	"""Check if this building can train any units"""
	if not is_operational():
		return false
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
	var pools_data := []
	for pool in storage_pools:
		pools_data.append(pool.to_dict())
	
	return {
		"building_id": building_id,
		"tile_coord": [tile_coord.x, tile_coord.y],
		"status": status,
		"turns_remaining": turns_remaining,
		"cost_per_turn": cost_per_turn,
		"storage_pools": pools_data,
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
	instance.training_unit_id = data.get("training_unit_id", "")
	instance.training_turns_remaining = data.get("training_turns_remaining", 0)
	instance.training_total_turns = data.get("training_total_turns", 0)
	instance.upgrading_to = data.get("upgrading_to", "")
	instance.upgrade_turns_remaining = data.get("upgrade_turns_remaining", 0)
	instance.upgrade_total_turns = data.get("upgrade_total_turns", 0)
	instance.upgrade_cost_per_turn = data.get("upgrade_cost_per_turn", {})
	
	# Load storage pool contents
	if data.has("storage_pools"):
		# New format: restore pool stored data
		var saved_pools = data.storage_pools
		for i in range(min(saved_pools.size(), instance.storage_pools.size())):
			instance.storage_pools[i].stored = saved_pools[i].get("stored", {})
	elif data.has("stored_resources"):
		# Legacy format: migrate flat stored_resources into pools
		var old_stored = data.stored_resources
		for res_id in old_stored.keys():
			if old_stored[res_id] > 0:
				instance.add_resource(res_id, old_stored[res_id])
	
	return instance
