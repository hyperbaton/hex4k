extends RefCounted
class_name City

# Represents a city with all its tiles, buildings, and resources.
# Uses tag-driven resource system with generic cap tracking and settlement types.

var city_id: String  # Unique identifier
var city_name: String
var owner: Player  # Reference to owning player (null if abandoned)

# Settlement type (determines tile costs, building restrictions, etc.)
var settlement_type: String = "encampment"

# Tiles
var tiles: Dictionary = {}  # Vector2i -> CityTile
var city_center_coord: Vector2i
var frontier_tiles: Array[Vector2i] = []  # Tiles at the edge of the city

# Buildings (using BuildingInstance for status tracking)
var building_instances: Dictionary = {}  # Vector2i -> BuildingInstance

# Generic cap state — replaces dedicated admin_capacity fields
# Structure: { resource_id: { available: float, used: float, ratio: float, efficiency: float } }
var cap_state: Dictionary = {}

# City state
var is_abandoned: bool = false  # True if city has been abandoned (population reached 0)

# Legacy resource ledger (for compatibility, will be phased out)
var resources: ResourceLedger

func _init(id: String, name: String, center_coord: Vector2i):
	city_id = id
	city_name = name
	city_center_coord = center_coord
	resources = ResourceLedger.new()

# === Tile Management ===

func add_tile(coord: Vector2i, is_center: bool = false) -> CityTile:
	"""Add a tile to the city"""
	if tiles.has(coord):
		return tiles[coord]
	
	var tile = CityTile.new(coord)
	tile.is_city_center = is_center
	
	if is_center:
		tile.distance_from_center = 0
	else:
		tile.distance_from_center = calculate_distance_from_center(coord)
	
	tiles[coord] = tile
	update_frontier()
	return tile

func remove_tile(coord: Vector2i):
	"""Remove a tile from the city"""
	if coord == city_center_coord:
		push_error("Cannot remove city center!")
		return
	
	tiles.erase(coord)
	update_frontier()

func has_tile(coord: Vector2i) -> bool:
	return tiles.has(coord)

func get_tile(coord: Vector2i) -> CityTile:
	return tiles.get(coord)

func get_city_center() -> CityTile:
	return tiles.get(city_center_coord)

func get_all_tiles() -> Array[CityTile]:
	var result: Array[CityTile] = []
	for tile in tiles.values():
		result.append(tile)
	return result

func get_tile_count() -> int:
	return tiles.size()

func calculate_distance_from_center(coord: Vector2i) -> int:
	"""Calculate hex distance from city center"""
	var q_diff = abs(coord.x - city_center_coord.x)
	var r_diff = abs(coord.y - city_center_coord.y)
	var s_diff = abs((-coord.x - coord.y) - (-city_center_coord.x - city_center_coord.y))
	return int((q_diff + r_diff + s_diff) / 2)

func update_frontier():
	"""Update which tiles are at the frontier of the city"""
	frontier_tiles.clear()
	
	for coord in tiles.keys():
		if is_frontier_tile(coord):
			frontier_tiles.append(coord)

func is_frontier_tile(coord: Vector2i) -> bool:
	"""Check if a tile is at the frontier (has non-city neighbors)"""
	var neighbors = get_hex_neighbors(coord)
	for neighbor in neighbors:
		if not tiles.has(neighbor):
			return true
	return false

func get_hex_neighbors(coord: Vector2i) -> Array[Vector2i]:
	"""Get the 6 adjacent hex coordinates"""
	var neighbors: Array[Vector2i] = []
	var directions = [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
	]
	for dir in directions:
		neighbors.append(coord + dir)
	return neighbors

func is_contiguous(new_coord: Vector2i) -> bool:
	"""Check if adding this tile would keep the city contiguous"""
	if tiles.is_empty():
		return true
	
	var neighbors = get_hex_neighbors(new_coord)
	for neighbor in neighbors:
		if tiles.has(neighbor):
			return true
	return false

# === Tile Costs (Settlement-Driven) ===

func calculate_tile_claim_cost(distance: int) -> Dictionary:
	"""Calculate per-resource tile maintenance cost at a given distance.
	Returns {resource_id: cost} based on settlement type's tile_costs config."""
	var costs := {}
	var tile_cost_entries = Registry.settlements.get_tile_costs(settlement_type)
	
	for entry in tile_cost_entries:
		var resource_id = entry.get("resource", "")
		if resource_id == "":
			continue
		
		var cost = Registry.settlements.calculate_tile_cost(
			settlement_type, resource_id, distance, false
		)
		if cost > 0:
			costs[resource_id] = cost
	
	return costs

func calculate_tile_claim_cost_for_resource(resource_id: String, distance: int, is_center: bool) -> float:
	"""Calculate tile cost for a specific resource at a given distance."""
	return Registry.settlements.calculate_tile_cost(settlement_type, resource_id, distance, is_center)

func get_max_tiles() -> int:
	"""Get maximum tile count for this settlement type. 0 = unlimited."""
	return Registry.settlements.get_max_tiles(settlement_type)

func can_expand_tiles() -> bool:
	"""Check if this settlement type allows expansion."""
	if not Registry.settlements.is_expansion_allowed(settlement_type):
		return false
	var max_tiles = get_max_tiles()
	if max_tiles > 0 and tiles.size() >= max_tiles:
		return false
	return true

# === Building Management ===

func get_building_instance(coord: Vector2i) -> BuildingInstance:
	"""Get the building instance at a coordinate"""
	return building_instances.get(coord)

func has_building(coord: Vector2i) -> bool:
	"""Check if there's a building at the coordinate"""
	return building_instances.has(coord)

func count_buildings(building_id: String) -> int:
	"""Count how many of a specific building exist (any status)"""
	var count = 0
	for instance in building_instances.values():
		if instance.building_id == building_id:
			count += 1
	return count

func is_tile_under_construction(coord: Vector2i) -> bool:
	"""Check if a tile has a building under construction"""
	var instance = building_instances.get(coord)
	if instance:
		return instance.is_under_construction()
	return false

func can_place_building(coord: Vector2i, building_id: String) -> Dictionary:
	"""
	Check if a building can be placed at the given coordinate.
	Returns {can_place: bool, reason: String}
	"""
	# Can't build in abandoned cities
	if is_abandoned:
		return {can_place = false, reason = "City is abandoned"}
	
	# Check if tile exists in city
	if not has_tile(coord):
		return {can_place = false, reason = "Tile not in city"}
	
	# Check if tile already has a building
	if has_building(coord):
		return {can_place = false, reason = "Tile already has a building"}
	
	# Check settlement type compatibility
	if not Registry.settlements.can_build_in(building_id, settlement_type):
		return {can_place = false, reason = "Cannot build in this settlement type"}
	
	# Check max per city limit
	var max_per_city = Registry.buildings.get_max_per_city(building_id)
	if max_per_city > 0:
		var current_count = count_buildings(building_id)
		if current_count >= max_per_city:
			var building_name = Registry.get_name_label("building", building_id)
			return {can_place = false, reason = "Maximum %s reached (%d)" % [building_name, max_per_city]}
	
	# Check tech requirements
	var required_milestones = Registry.buildings.get_required_milestones(building_id)
	if not Registry.has_all_milestones(required_milestones):
		return {can_place = false, reason = "Missing technology"}

	# Check if building is obsolete
	if Registry.buildings.is_obsolete(building_id):
		return {can_place = false, reason = "Obsolete building"}

	# Check perk-locked buildings (only available through perk unlocks)
	if Registry.perks.is_perk_locked_building(building_id):
		if not owner or building_id not in Registry.perks.get_unlocked_unique_buildings(owner):
			return {can_place = false, reason = "Requires a civilization perk"}

	# Check cap resources (generic: check all cap resources this building consumes)
	var consumes = Registry.buildings.get_consumes(building_id)
	var tile = get_tile(coord)
	for entry in consumes:
		var res_id = entry.get("resource", "")
		if res_id == "" or not Registry.resources.has_tag(res_id, "cap"):
			continue
		# Estimate the cost for this building at this distance
		var base_qty = entry.get("quantity", 0.0)
		var dist_cost = entry.get("distance_cost", {})
		var multiplier = dist_cost.get("multiplier", 0.0)
		var distance = tile.distance_from_center if tile else 0
		var estimated_cost = base_qty + (pow(distance, 2) * multiplier)
		
		var cap_info = cap_state.get(res_id, {})
		var available_cap = cap_info.get("available", 0.0) - cap_info.get("used", 0.0)
		if estimated_cost > available_cap:
			var res_name = Registry.get_name_label("resource", res_id)
			return {can_place = false, reason = "Insufficient %s" % res_name}
	
	# Check initial construction cost
	var initial_cost = Registry.buildings.get_initial_construction_cost(building_id)
	for resource_id in initial_cost.keys():
		var cost = initial_cost[resource_id]
		if get_total_resource(resource_id) < cost:
			var resource_name = Registry.get_name_label("resource", resource_id)
			return {can_place = false, reason = "Insufficient %s (need %d)" % [resource_name, cost]}
	
	return {can_place = true, reason = ""}

func start_construction(coord: Vector2i, building_id: String) -> bool:
	"""Start building construction at the given tile"""
	var check = can_place_building(coord, building_id)
	if not check.can_place:
		push_warning("Cannot build %s at %v: %s" % [building_id, coord, check.reason])
		return false
	
	# Deduct initial construction cost
	var initial_cost = Registry.buildings.get_initial_construction_cost(building_id)
	for resource_id in initial_cost.keys():
		var cost = initial_cost[resource_id]
		consume_resource(resource_id, cost)
		print("  Deducted initial cost: ", resource_id, " x", cost)
	
	# Create building instance
	var instance = BuildingInstance.new(building_id, coord)
	instance.start_construction(
		Registry.buildings.get_construction_turns(building_id),
		Registry.buildings.get_construction_cost(building_id)
	)
	
	building_instances[coord] = instance
	
	# Update tile reference (for visual compatibility)
	var tile = get_tile(coord)
	if tile:
		tile.building_id = building_id
	
	return true

func demolish_building(coord: Vector2i):
	"""Demolish a building at the given tile (internal, use try_demolish_building for player actions)"""
	if not has_building(coord):
		return
	
	building_instances.erase(coord)
	
	var tile = get_tile(coord)
	if tile:
		tile.building_id = ""

func can_disable_building(coord: Vector2i) -> Dictionary:
	"""Check if a building can be disabled. Returns {can_disable: bool, reason: String}"""
	if is_abandoned:
		return {can_disable = false, reason = "City is abandoned"}
	
	var instance = get_building_instance(coord)
	if not instance:
		return {can_disable = false, reason = "No building at this location"}
	
	# Can't disable city centers
	if Registry.buildings.is_city_center(instance.building_id):
		return {can_disable = false, reason = "Cannot disable city center"}
	
	# Can't disable buildings under construction
	if instance.is_under_construction():
		return {can_disable = false, reason = "Building is under construction"}
	
	# Can't disable already disabled buildings
	if instance.is_disabled():
		return {can_disable = false, reason = "Building is already disabled"}
	
	return {can_disable = true, reason = ""}

func disable_building(coord: Vector2i) -> bool:
	"""Disable a building at the given coordinate"""
	var check = can_disable_building(coord)
	if not check.can_disable:
		push_warning("Cannot disable building at %v: %s" % [coord, check.reason])
		return false
	
	var instance = get_building_instance(coord)
	instance.set_disabled()
	print("City: Disabled building %s at %v" % [instance.building_id, coord])
	return true

func can_enable_building(coord: Vector2i) -> Dictionary:
	"""Check if a building can be enabled. Returns {can_enable: bool, reason: String}"""
	if is_abandoned:
		return {can_enable = false, reason = "City is abandoned"}
	
	var instance = get_building_instance(coord)
	if not instance:
		return {can_enable = false, reason = "No building at this location"}
	
	# Can only enable disabled buildings
	if not instance.is_disabled():
		return {can_enable = false, reason = "Building is not disabled"}
	
	return {can_enable = true, reason = ""}

func enable_building(coord: Vector2i) -> bool:
	"""Enable a previously disabled building"""
	var check = can_enable_building(coord)
	if not check.can_enable:
		push_warning("Cannot enable building at %v: %s" % [coord, check.reason])
		return false
	
	var instance = get_building_instance(coord)
	# Set to expecting resources - the turn processor will activate it if resources are available
	instance.set_expecting_resources()
	print("City: Enabled building %s at %v" % [instance.building_id, coord])
	return true

func can_demolish_building(coord: Vector2i) -> Dictionary:
	"""Check if a building can be demolished. Returns {can_demolish: bool, reason: String, cost: Dictionary}"""
	if is_abandoned:
		return {can_demolish = false, reason = "City is abandoned", cost = {}}
	
	var instance = get_building_instance(coord)
	if not instance:
		return {can_demolish = false, reason = "No building at this location", cost = {}}
	
	# Can't demolish city centers
	if Registry.buildings.is_city_center(instance.building_id):
		return {can_demolish = false, reason = "Cannot demolish city center", cost = {}}
	
	# Can't demolish buildings under construction (use cancel instead)
	if instance.is_under_construction():
		return {can_demolish = false, reason = "Cannot demolish building under construction", cost = {}}
	
	# Check demolition cost
	var demolition_cost = Registry.buildings.get_demolition_cost(instance.building_id)
	var missing = get_missing_resources(demolition_cost)
	
	if not missing.is_empty():
		var missing_str = ""
		for res_id in missing.keys():
			var res_name = Registry.get_name_label("resource", res_id)
			missing_str += "%s (need %.0f more), " % [res_name, missing[res_id]]
		missing_str = missing_str.trim_suffix(", ")
		return {can_demolish = false, reason = "Insufficient resources: " + missing_str, cost = demolition_cost}
	
	return {can_demolish = true, reason = "", cost = demolition_cost}

func try_demolish_building(coord: Vector2i) -> bool:
	"""Attempt to demolish a building, paying the demolition cost"""
	var check = can_demolish_building(coord)
	if not check.can_demolish:
		push_warning("Cannot demolish building at %v: %s" % [coord, check.reason])
		return false
	
	var instance = get_building_instance(coord)
	var building_id = instance.building_id
	
	# Pay demolition cost
	for res_id in check.cost.keys():
		consume_resource(res_id, check.cost[res_id])
		print("  Deducted demolition cost: %s x%.0f" % [res_id, check.cost[res_id]])
	
	# Remove the building
	demolish_building(coord)
	print("City: Demolished building %s at %v" % [building_id, coord])
	return true

# === Abandonment ===

func abandon() -> Player:
	"""
	Abandon this city due to population reaching zero.
	Disables all buildings, clears perishable resources, and disowns the city.
	Returns the previous owner (for checking if they lost the game).
	"""
	if is_abandoned:
		return null  # Already abandoned
	
	var previous_owner = owner
	print("City %s is being abandoned!" % city_name)
	
	# Set abandoned state
	is_abandoned = true
	
	# Disable all buildings
	for coord in building_instances.keys():
		var instance: BuildingInstance = building_instances[coord]
		if not instance.is_under_construction():
			instance.set_disabled()
	
	# Clear all perishable (decaying) resources from storage
	_clear_perishable_resources()
	
	# Disown the city
	if owner:
		owner.remove_city(self)
		owner = null
	
	print("City %s has been abandoned" % city_name)
	return previous_owner

func _clear_perishable_resources():
	"""Clear all perishable/decaying resources from all storage buildings"""
	for instance in building_instances.values():
		var all_stored = instance.get_all_stored_resources()
		for resource_id in all_stored.keys():
			if Registry.resources.has_tag(resource_id, "decaying"):
				var amount = all_stored[resource_id]
				if amount > 0:
					instance.remove_resource(resource_id, amount)
					print("  Cleared %.1f %s (perishable)" % [amount, resource_id])

func reclaim(new_owner: Player):
	"""
	Reclaim an abandoned city for a new owner.
	Buildings remain disabled - the new owner must enable them manually.
	"""
	if not is_abandoned:
		push_warning("Cannot reclaim a city that is not abandoned")
		return
	
	if not new_owner:
		push_error("Cannot reclaim city without a valid owner")
		return
	
	owner = new_owner
	new_owner.add_city(self)
	is_abandoned = false
	
	# Give a small starting population by storing in population pools
	store_resource("population", 1)
	
	print("City %s has been reclaimed by %s" % [city_name, new_owner.player_name])

func should_check_abandonment() -> bool:
	"""Check if this city should be checked for abandonment (population at 0)"""
	return not is_abandoned and get_total_population() <= 0

# === Building Upgrades ===

func can_upgrade_building(coord: Vector2i) -> Dictionary:
	"""
	Check if a building can be upgraded.
	Returns {can_upgrade: bool, reason: String, upgrade_info: Dictionary}
	"""
	if is_abandoned:
		return {can_upgrade = false, reason = "City is abandoned", upgrade_info = {}}
	
	var instance = get_building_instance(coord)
	if not instance:
		return {can_upgrade = false, reason = "No building at this location", upgrade_info = {}}
	
	# Can't upgrade if already upgrading
	if instance.is_upgrading():
		var target_name = Registry.get_name_label("building", instance.upgrading_to)
		return {can_upgrade = false, reason = "Already upgrading to " + target_name, upgrade_info = {}}
	
	# Can't upgrade buildings under construction
	if instance.is_under_construction():
		return {can_upgrade = false, reason = "Building is under construction", upgrade_info = {}}
	
	# Can't upgrade disabled buildings
	if instance.is_disabled():
		return {can_upgrade = false, reason = "Building is disabled", upgrade_info = {}}
	
	# Check if building has an upgrade path
	var upgrade_info = Registry.buildings.get_upgrade_info(instance.building_id)
	if upgrade_info.is_empty():
		return {can_upgrade = false, reason = "No upgrade available", upgrade_info = {}}
	
	# Check tech requirements for target building
	var target_id = upgrade_info.target
	var required_milestones = Registry.buildings.get_required_milestones(target_id)
	if not Registry.has_all_milestones(required_milestones):
		var target_name = Registry.get_name_label("building", target_id)
		return {can_upgrade = false, reason = "Missing technology for " + target_name, upgrade_info = upgrade_info}

	# Check if target building is obsolete
	if Registry.buildings.is_obsolete(target_id):
		var target_name = Registry.get_name_label("building", target_id)
		return {can_upgrade = false, reason = target_name + " is obsolete", upgrade_info = upgrade_info}

	# Check initial cost
	var initial_cost = upgrade_info.initial_cost
	var missing = get_missing_resources(initial_cost)
	
	if not missing.is_empty():
		var missing_str = ""
		for res_id in missing.keys():
			var res_name = Registry.get_name_label("resource", res_id)
			missing_str += "%s (need %.0f more), " % [res_name, missing[res_id]]
		missing_str = missing_str.trim_suffix(", ")
		return {can_upgrade = false, reason = "Insufficient resources: " + missing_str, upgrade_info = upgrade_info}
	
	return {can_upgrade = true, reason = "", upgrade_info = upgrade_info}

func start_upgrade_building(coord: Vector2i) -> bool:
	"""Start upgrading a building at the given coordinate"""
	var check = can_upgrade_building(coord)
	if not check.can_upgrade:
		push_warning("Cannot upgrade building at %v: %s" % [coord, check.reason])
		return false
	
	var instance = get_building_instance(coord)
	var upgrade_info = check.upgrade_info
	
	# Pay initial upgrade cost
	for res_id in upgrade_info.initial_cost.keys():
		var cost = upgrade_info.initial_cost[res_id]
		consume_resource(res_id, cost)
		print("  Deducted upgrade cost: %s x%.0f" % [res_id, cost])
	
	# Start the upgrade process
	instance.start_upgrade(
		upgrade_info.target,
		upgrade_info.total_turns,
		upgrade_info.cost_per_turn
	)
	
	print("City: Started upgrade of %s to %s at %v" % [
		instance.building_id, upgrade_info.target, coord
	])
	return true

func cancel_upgrade_building(coord: Vector2i) -> bool:
	"""Cancel an in-progress upgrade"""
	var instance = get_building_instance(coord)
	if not instance:
		return false
	
	if not instance.is_upgrading():
		return false
	
	var cancelled_info = instance.cancel_upgrade()
	print("City: Cancelled upgrade to %s at %v" % [cancelled_info.target, coord])
	# Note: Resources are NOT refunded when cancelling
	return true

# === Resource Management (Per-Building Storage) ===

func get_total_resource(resource_id: String) -> float:
	"""Get total amount of a resource across all storage buildings"""
	var total: float = 0.0
	for instance in building_instances.values():
		total += instance.get_stored_amount(resource_id)
	return total

func get_total_storage_capacity(resource_id: String) -> float:
	"""Get total storage capacity for a resource across all buildings"""
	var total: float = 0.0
	for instance in building_instances.values():
		total += instance.get_storage_capacity(resource_id)
	return total

func get_available_storage(resource_id: String) -> float:
	"""Get available storage space for a resource"""
	var total: float = 0.0
	for instance in building_instances.values():
		total += instance.get_available_space(resource_id)
	return total

func store_resource(resource_id: String, amount: float) -> float:
	"""
	Store resources in available storage buildings.
	Returns the amount actually stored. Excess is not stored (spillage).
	"""
	var remaining = amount
	
	for instance in building_instances.values():
		if remaining <= 0:
			break
		
		if instance.can_store(resource_id):
			var stored = instance.add_resource(resource_id, remaining)
			remaining -= stored
	
	return amount - remaining  # Return amount stored

func consume_resource(resource_id: String, amount: float) -> float:
	"""
	Consume resources from storage buildings.
	Returns the amount actually consumed.
	"""
	var remaining = amount
	
	for instance in building_instances.values():
		if remaining <= 0:
			break
		
		var removed = instance.remove_resource(resource_id, remaining)
		remaining -= removed
	
	return amount - remaining  # Return amount consumed

func consume_resource_by_tag(tag: String, amount: float) -> Dictionary:
	"""Consume resources matching a tag, preferring most abundant.
	Returns {resource_id: amount_consumed} for each resource consumed."""
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
		var consumed = consume_resource(res_id, remaining)
		if consumed > 0:
			result[res_id] = consumed
			remaining -= consumed
	
	return result

func get_resources_by_tag(tag: String) -> Dictionary:
	"""Get all stored resources that have a specific tag. Returns {resource_id: total_amount}."""
	var result := {}
	for instance in building_instances.values():
		var tagged = instance.get_resources_by_tag(tag)
		for res_id in tagged.keys():
			result[res_id] = result.get(res_id, 0.0) + tagged[res_id]
	return result

func has_resources(requirements: Dictionary) -> bool:
	"""Check if the city has all required resources"""
	for resource_id in requirements.keys():
		if get_total_resource(resource_id) < requirements[resource_id]:
			return false
	return true

func get_missing_resources(requirements: Dictionary) -> Dictionary:
	"""Get dictionary of missing resources {resource_id: amount_missing}"""
	var missing: Dictionary = {}
	for resource_id in requirements.keys():
		var needed = requirements[resource_id]
		var available = get_total_resource(resource_id)
		if available < needed:
			missing[resource_id] = needed - available
	return missing

# === Population (Derived from Storage Pools) ===

func get_total_population() -> int:
	"""Get total population by summing all stored population-tagged resources."""
	var total := 0.0
	var pop_resources = Registry.resources.get_resources_by_tag("population")
	for res_id in pop_resources:
		total += get_total_resource(res_id)
	return int(total)

func get_population_capacity() -> int:
	"""Get total population capacity from all operational building pools that accept population."""
	var total := 0.0
	for instance in building_instances.values():
		if instance.is_operational():
			for pool in instance.storage_pools:
				if "population" in pool.accepted_tags:
					total += pool.capacity
	return int(total)

# === Cap Resources (Generic) ===

func get_cap_available(resource_id: String) -> float:
	"""Get available amount for a cap resource."""
	var info = cap_state.get(resource_id, {})
	return info.get("available", 0.0)

func get_cap_used(resource_id: String) -> float:
	"""Get used amount for a cap resource."""
	var info = cap_state.get(resource_id, {})
	return info.get("used", 0.0)

func get_cap_remaining(resource_id: String) -> float:
	"""Get remaining capacity for a cap resource."""
	return max(0.0, get_cap_available(resource_id) - get_cap_used(resource_id))

func get_cap_ratio(resource_id: String) -> float:
	"""Get usage ratio for a cap resource."""
	var info = cap_state.get(resource_id, {})
	return info.get("ratio", 0.0)

func get_cap_efficiency(resource_id: String) -> float:
	"""Get production efficiency modifier from a cap resource."""
	var info = cap_state.get(resource_id, {})
	return info.get("efficiency", 1.0)

# === Statistics Recalculation ===

func recalculate_city_stats():
	"""Recalculate all city statistics (call after building changes during player turn).
	Computes generic cap state for all cap resources."""
	cap_state.clear()
	
	# Find all cap resources involved (from tile costs and building production/consumption)
	var cap_resources := {}  # resource_id -> true
	
	# Tile costs define which cap resources are needed
	var tile_cost_resources = Registry.settlements.get_all_tile_cost_resources(settlement_type)
	for res_id in tile_cost_resources:
		cap_resources[res_id] = true
	
	# Also find cap resources from buildings
	for instance in building_instances.values():
		for entry in Registry.buildings.get_produces(instance.building_id):
			var res_id = entry.get("resource", "")
			if res_id != "" and Registry.resources.has_tag(res_id, "cap"):
				cap_resources[res_id] = true
		for entry in Registry.buildings.get_consumes(instance.building_id):
			var res_id = entry.get("resource", "")
			if res_id != "" and Registry.resources.has_tag(res_id, "cap"):
				cap_resources[res_id] = true
	
	# Calculate each cap resource
	for res_id in cap_resources.keys():
		var available := 0.0
		var used := 0.0
		
		# Sum production (available) from operational/constructing buildings
		for instance in building_instances.values():
			if instance.is_operational() or instance.is_under_construction():
				for entry in Registry.buildings.get_produces(instance.building_id):
					if entry.get("resource", "") == res_id:
						available += entry.get("quantity", 0.0)
		
		# Sum consumption from buildings (with distance costs)
		for coord in building_instances.keys():
			var instance: BuildingInstance = building_instances[coord]
			if instance.is_disabled():
				var disabled_cost = instance.get_disabled_admin_cost()
				if disabled_cost > 0 and res_id == "admin_capacity":
					used += disabled_cost
				continue
			
			for entry in Registry.buildings.get_consumes(instance.building_id):
				if entry.get("resource", "") == res_id:
					var base_qty = entry.get("quantity", 0.0)
					var dist_cost = entry.get("distance_cost", {})
					if not dist_cost.is_empty():
						var multiplier = dist_cost.get("multiplier", 0.0)
						# Apply perk admin distance modifier
						var perk_dist_mod = Registry.perks.get_admin_distance_modifier(owner) if owner else 0.0
						var effective_multiplier = max(0.0, multiplier + perk_dist_mod)
						var tile: CityTile = tiles.get(coord)
						var distance = tile.distance_from_center if tile else 0
						# TODO: Support "nearest_source" distance_to mode
						used += base_qty + (pow(distance, 2) * effective_multiplier)
					else:
						used += base_qty
		
		# Sum tile costs
		for coord in tiles.keys():
			var tile: CityTile = tiles[coord]
			used += Registry.settlements.calculate_tile_cost(
				settlement_type, res_id, tile.distance_from_center, tile.is_city_center
			)
		
		# Compute ratio and efficiency
		var ratio = used / max(available, 0.001)
		var efficiency = _calculate_cap_efficiency(res_id, ratio)
		
		cap_state[res_id] = {
			"available": available,
			"used": used,
			"ratio": ratio,
			"efficiency": efficiency
		}
	
	print("City stats recalculated: %s" % str(cap_state))

func _calculate_cap_efficiency(resource_id: String, ratio: float) -> float:
	"""Calculate production efficiency based on cap ratio and cap config."""
	if ratio <= 1.0:
		return 1.0
	
	var cap_config = Registry.resources.get_cap_config(resource_id)
	var penalties = cap_config.get("penalties", [])
	
	for penalty in penalties:
		var penalty_type = penalty.get("type", "")
		if penalty_type == "production_penalty":
			var curve = penalty.get("curve", "quadratic")
			var overage = ratio - 1.0
			match curve:
				"quadratic":
					return clamp(1.0 - pow(overage, 1.5), 0.0, 1.0)
				"linear":
					return clamp(1.0 - overage, 0.0, 1.0)
				"step":
					return 0.0 if ratio > 1.0 else 1.0
				_:
					return clamp(1.0 - pow(overage, 1.5), 0.0, 1.0)
	
	return 1.0

# === Building Capacity ===

func get_total_building_capacity() -> int:
	"""Get total building capacity from all operational buildings.
	This limits how many constructions can progress per turn."""
	var total: int = 0
	for instance in building_instances.values():
		if instance.is_operational():
			total += Registry.buildings.get_building_capacity(instance.building_id)
	return total

func get_constructions_in_progress() -> Array[Vector2i]:
	"""Get coordinates of all buildings currently under construction, in insertion order."""
	var coords: Array[Vector2i] = []
	for coord in building_instances.keys():
		var instance: BuildingInstance = building_instances[coord]
		if instance.is_under_construction():
			coords.append(coord)
	return coords

# === Settlement Transitions ===

func get_settlement_type() -> String:
	return settlement_type

func get_available_transitions() -> Array:
	"""Get all transitions whose requirements are currently met."""
	var transitions = Registry.settlements.get_transitions(settlement_type)
	var available := []
	
	for transition in transitions:
		var check = can_transition_to(transition.get("target", ""))
		if check.get("can", false):
			available.append(transition)
	
	return available

func can_transition_to(target_type: String) -> Dictionary:
	"""Check if settlement can transition to target type. Returns {can: bool, reason: String}."""
	var transition = Registry.settlements.get_transition_to(settlement_type, target_type)
	if transition.is_empty():
		return {"can": false, "reason": "No transition path to " + target_type}
	
	# Check requirements
	var reqs = transition.get("requirements", {})
	
	if reqs.has("min_population"):
		if get_total_population() < reqs.min_population:
			return {"can": false, "reason": "Need population %d" % reqs.min_population}
	
	if reqs.has("milestones"):
		for milestone_id in reqs.milestones:
			if not Registry.tech.is_milestone_unlocked(milestone_id):
				return {"can": false, "reason": "Missing milestone: " + milestone_id}
	
	# Check cost
	var cost = transition.get("cost", {})
	var missing = get_missing_resources(cost)
	if not missing.is_empty():
		return {"can": false, "reason": "Insufficient resources"}
	
	return {"can": true, "reason": ""}

func transition_settlement(new_type: String) -> bool:
	"""Transition to a new settlement type. Returns true on success."""
	var check = can_transition_to(new_type)
	if not check.can:
		push_warning("Cannot transition to %s: %s" % [new_type, check.reason])
		return false
	
	var transition = Registry.settlements.get_transition_to(settlement_type, new_type)
	
	# Pay cost
	var cost = transition.get("cost", {})
	for res_id in cost.keys():
		consume_resource(res_id, cost[res_id])
	
	var old_type = settlement_type
	settlement_type = new_type
	
	# Recalculate stats with new tile costs
	recalculate_city_stats()
	
	print("City %s transitioned: %s → %s" % [city_name, old_type, new_type])
	return true



# === Legacy Compatibility ===

func get_construction_at_tile(coord: Vector2i) -> Dictionary:
	"""Get construction info at a tile (legacy compatibility)"""
	var instance = building_instances.get(coord)
	if instance and instance.is_under_construction():
		return {
			tile_coord = coord,
			building_id = instance.building_id,
			turns_remaining = instance.turns_remaining,
			cost_per_turn = instance.cost_per_turn
		}
	return {}
