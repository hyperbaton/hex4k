extends RefCounted
class_name OriginSpawner

## Handles finding valid spawn locations and applying origin configurations.
## Used by World.gd to set up player starts and (future) AI empire spawns.

# References set by World before calling apply_origin()
var world_node: Node2D  # World scene — provides get_tile_data()
var city_manager: CityManager
var unit_manager: UnitManager
var fog_manager: FogOfWarManager
var chunk_manager: Node  # ChunkManager — provides get_tile_data() with lazy generation

# Tracks placed spawn positions for distance enforcement
var _placed_spawns: Array[Vector2i] = []

# Tile data cache for spawn search (avoids redundant generation)
var _tile_cache: Dictionary = {}  # Vector2i -> HexTileData

func initialize(p_world: Node2D, p_city_manager: CityManager, p_unit_manager: UnitManager, p_fog_manager: FogOfWarManager, p_chunk_manager: Node):
	world_node = p_world
	city_manager = p_city_manager
	unit_manager = p_unit_manager
	fog_manager = p_fog_manager
	chunk_manager = p_chunk_manager

# =============================================================================
# Main Entry Point
# =============================================================================

func apply_origin(origin_id: String, player_id: String, player_name: String) -> Vector2i:
	"""Apply a full origin: find spawn, create player, set up tech/perks/units/settlements.
	Returns the spawn coordinate."""
	if not Registry.origins.has_origin(origin_id):
		push_error("Origin '%s' not found" % origin_id)
		return Vector2i.ZERO

	# 1. Find valid spawn location
	var spawn_coord := find_spawn_location(origin_id)

	# 2. Create player
	city_manager.create_player(player_id, player_name)
	var player := city_manager.get_player(player_id)
	player.origin_id = origin_id

	# 3. Apply tech (with branch derivation from milestones)
	_apply_tech(origin_id)

	# 4. Apply perks
	_apply_perks(player, origin_id)

	# 5. Place settlements (if any)
	for settlement_config in Registry.origins.get_starting_settlements(origin_id):
		_place_settlement(spawn_coord, settlement_config, player_id)

	# 6. Place units (with passability checks and spiral placement)
	_place_units(spawn_coord, Registry.origins.get_starting_units(origin_id), player_id)

	# 7. Reveal fog of war
	var explored_radius: int = Registry.origins.get_spawn_config(origin_id).get("initial_explored_radius", 5)
	_reveal_explored_area(player_id, spawn_coord, explored_radius)

	# 8. Track this spawn position for future distance checks
	_placed_spawns.append(spawn_coord)

	# Clear tile cache (no longer needed)
	_tile_cache.clear()

	return spawn_coord

# =============================================================================
# Phase 2: Spawn Algorithm
# =============================================================================

func find_spawn_location(origin_id: String) -> Vector2i:
	"""Find the best spawn location for an origin using scored candidate search."""
	var config := Registry.origins.get_spawn_config(origin_id)
	var min_r: int = config.get("min_radius", 0)
	var max_r: int = config.get("search_radius", 30)
	var min_player_dist: int = config.get("min_distance_from_other_players", 20)
	var conditions: Array = config.get("terrain_conditions", [])
	var max_attempts: int = config.get("max_attempts", 50)
	var retry_step: int = config.get("retry_step", 5)

	var best_coord := Vector2i.ZERO
	var best_score := -1.0

	# Phase 1: Sample random candidates in the ring
	var sample_count := mini(max_attempts, 30)
	for i in sample_count:
		var candidate := _random_coord_in_ring(min_r, max_r)

		if _too_close_to_players(candidate, min_player_dist):
			continue

		var result := _evaluate_conditions(candidate, conditions)
		if result.score > best_score:
			best_score = result.score
			best_coord = candidate
		if result.passed:
			_apply_force_modifiers(candidate, config)
			return candidate

	# Phase 2: Spiral from best candidate
	var remaining := max_attempts - sample_count
	var current := best_coord
	for i in remaining:
		current = _offset_random_direction(current, retry_step)
		current = _clamp_to_ring(current, min_r, max_r)

		if _too_close_to_players(current, min_player_dist):
			continue

		var result := _evaluate_conditions(current, conditions)
		if result.score > best_score:
			best_score = result.score
			best_coord = current
		if result.passed:
			_apply_force_modifiers(current, config)
			return current

	# Fallback: best we found
	push_warning("[Origin: %s] No perfect spawn after %d attempts, using best match (score: %.2f)" %
		[origin_id, max_attempts, best_score])
	_apply_force_modifiers(best_coord, config)
	return best_coord

# --- Spawn helpers ---

func _get_tile_data(coord: Vector2i) -> HexTileData:
	"""Get tile data with caching. Uses ChunkManager which lazily generates terrain."""
	if _tile_cache.has(coord):
		return _tile_cache[coord]
	var data: HexTileData = chunk_manager.get_tile_data(coord)
	if data:
		_tile_cache[coord] = data
	return data

func _random_coord_in_ring(min_radius: int, max_radius: int) -> Vector2i:
	"""Generate a random hex coordinate within the ring [min_radius, max_radius]."""
	# Generate random q and r, then check if within ring
	for _attempt in 50:
		var q := randi_range(-max_radius, max_radius)
		var r := randi_range(-max_radius, max_radius)
		var coord := Vector2i(q, r)
		var dist := HexUtil.hex_distance(Vector2i.ZERO, coord)
		if dist >= min_radius and dist <= max_radius:
			return coord
	# Fallback: return a point on the min_radius ring
	if min_radius > 0:
		var ring := HexUtil.get_ring(Vector2i.ZERO, min_radius)
		return ring[randi() % ring.size()]
	return Vector2i.ZERO

func _too_close_to_players(coord: Vector2i, min_dist: int) -> bool:
	"""Check if a coordinate is too close to any already-placed player spawn."""
	for placed in _placed_spawns:
		if HexUtil.hex_distance(coord, placed) < min_dist:
			return true
	return false

func _offset_random_direction(coord: Vector2i, distance: int) -> Vector2i:
	"""Move coord in a random hex direction by the given distance."""
	var dir: Vector2i = HexUtil.DIRECTIONS[randi() % 6]
	return coord + dir * distance

func _clamp_to_ring(coord: Vector2i, min_radius: int, max_radius: int) -> Vector2i:
	"""Clamp a coordinate to stay within the ring [min_radius, max_radius] from origin."""
	var dist := HexUtil.hex_distance(Vector2i.ZERO, coord)
	if dist >= min_radius and dist <= max_radius:
		return coord
	# If too far out, scale back toward center
	if dist > max_radius and dist > 0:
		var scale := float(max_radius) / float(dist)
		return Vector2i(roundi(coord.x * scale), roundi(coord.y * scale))
	# If too close, push outward along the same direction
	if dist < min_radius and dist > 0:
		var scale := float(min_radius) / float(dist)
		return Vector2i(roundi(coord.x * scale), roundi(coord.y * scale))
	# dist == 0 and min_radius > 0: pick a random ring tile
	if min_radius > 0:
		var ring := HexUtil.get_ring(Vector2i.ZERO, min_radius)
		return ring[randi() % ring.size()]
	return coord

func _evaluate_conditions(coord: Vector2i, conditions: Array) -> Dictionary:
	"""Evaluate all terrain conditions for a candidate spawn location.
	Returns {passed: bool, score: float, failures: Array[String]}."""
	var score := 0.0
	var failures: Array[String] = []
	var total := conditions.size()

	for condition in conditions:
		var passed := false
		var cond_type: String = condition.get("type", "")

		match cond_type:
			"terrain":
				var count := _count_terrain_in_radius(coord, condition.get("terrain_id", ""), condition.get("radius", 3))
				passed = _check_min_max(count, condition)
			"modifier":
				var count := _count_modifier_in_radius(coord, condition.get("modifier_id", ""), condition.get("radius", 3))
				passed = _check_min_max(count, condition)
			"terrain_tag":
				var count := _count_terrain_tag_in_radius(coord, condition.get("tag", ""), condition.get("radius", 3))
				passed = _check_min_max(count, condition)
			"center_terrain":
				var tile := _get_tile_data(coord)
				if tile:
					passed = (tile.terrain_id == condition.get("terrain_id", ""))
			"center_passable":
				var tile := _get_tile_data(coord)
				if tile:
					var movement_type: String = condition.get("movement_type", "foot")
					var cost := Registry.units.get_effective_movement_cost(movement_type, tile.terrain_id, tile.modifiers)
					passed = (cost > 0)

		if passed:
			score += 1.0
		else:
			failures.append(cond_type)

	return {passed = failures.is_empty(), score = score / maxf(total, 1.0), failures = failures}

func _check_min_max(count: int, condition: Dictionary) -> bool:
	"""Check if a count satisfies min/max constraints."""
	var min_val = condition.get("min")
	var max_val = condition.get("max")
	if min_val != null and count < int(min_val):
		return false
	if max_val != null and count > int(max_val):
		return false
	return true

func _count_terrain_in_radius(center: Vector2i, terrain_id: String, radius: int) -> int:
	"""Count tiles with a specific terrain ID within a radius."""
	var count := 0
	for coord in HexUtil.get_coords_in_radius(center, radius):
		var tile := _get_tile_data(coord)
		if tile and tile.terrain_id == terrain_id:
			count += 1
	return count

func _count_modifier_in_radius(center: Vector2i, modifier_id: String, radius: int) -> int:
	"""Count tiles with a specific modifier within a radius."""
	var count := 0
	for coord in HexUtil.get_coords_in_radius(center, radius):
		var tile := _get_tile_data(coord)
		if tile and tile.has_modifier(modifier_id):
			count += 1
	return count

func _count_terrain_tag_in_radius(center: Vector2i, tag: String, radius: int) -> int:
	"""Count tiles whose terrain category matches a tag within a radius."""
	var count := 0
	for coord in HexUtil.get_coords_in_radius(center, radius):
		var tile := _get_tile_data(coord)
		if tile:
			var terrain := Registry.terrains.get_terrain(tile.terrain_id)
			if terrain.get("category", "") == tag:
				count += 1
	return count

# --- Force Modifiers ---

func _apply_force_modifiers(spawn_coord: Vector2i, spawn_config: Dictionary):
	"""Inject guaranteed modifiers near the spawn location."""
	var force_mods: Array = spawn_config.get("force_modifiers", [])

	for force_mod in force_mods:
		var modifier_id: String = force_mod.get("modifier_id", "")
		var radius: int = force_mod.get("radius", 4)
		var target_count: int = force_mod.get("count", 1)
		var terrain_filter: Array = force_mod.get("terrain_filter", [])

		# Find eligible tiles
		var eligible: Array[Vector2i] = []
		for coord in HexUtil.get_coords_in_radius(spawn_coord, radius):
			var tile := _get_tile_data(coord)
			if not tile:
				continue
			# Skip if already has this modifier
			if tile.has_modifier(modifier_id):
				continue
			# Check terrain filter
			if not terrain_filter.is_empty() and tile.terrain_id not in terrain_filter:
				continue
			# Check modifier's own terrain conditions
			var mod_data := Registry.modifiers.get_modifier(modifier_id)
			var allowed_terrains: Array = mod_data.get("terrain_types", [])
			if not allowed_terrains.is_empty() and tile.terrain_id not in allowed_terrains:
				continue
			eligible.append(coord)

		# Place modifiers
		var placed := 0
		eligible.shuffle()
		for coord in eligible:
			if placed >= target_count:
				break
			var tile := _get_tile_data(coord)
			if tile:
				tile.add_modifier(modifier_id)
				placed += 1

		if placed < target_count:
			push_warning("[Origin] Force modifier '%s' — only %d/%d eligible tiles found within radius %d" %
				[modifier_id, placed, target_count, radius])

# =============================================================================
# Phase 3: Tech, Perks, Unit Placement, Fog Reveal
# =============================================================================

func _apply_tech(origin_id: String):
	"""Apply starting technology with branch level derivation from milestones."""
	var tech_config := Registry.origins.get_starting_tech(origin_id)
	var milestones: Array = tech_config.get("milestones", [])
	var explicit_progress: Dictionary = tech_config.get("branch_progress", {})

	# Step 1: Derive minimum branch levels from milestones
	var derived_progress: Dictionary = {}  # branch_id -> float

	for milestone_id in milestones:
		var milestone := Registry.tech.get_milestone(milestone_id)
		if milestone.is_empty():
			push_warning("[Origin: %s] Milestone '%s' not found" % [origin_id, milestone_id])
			continue
		var requirements: Array = milestone.get("requirements", [])
		for req in requirements:
			var branch: String = req.get("branch", "")
			var level: float = req.get("level", 0.0)
			if not derived_progress.has(branch) or derived_progress[branch] < level:
				derived_progress[branch] = level

	# Step 2: Merge with explicit branch_progress (take max)
	for branch_id in explicit_progress:
		var explicit_level: float = explicit_progress[branch_id]
		if not derived_progress.has(branch_id) or derived_progress[branch_id] < explicit_level:
			derived_progress[branch_id] = explicit_level

	# Step 3: Apply branch progress
	for branch_id in derived_progress:
		Registry.tech.set_branch_progress(branch_id, derived_progress[branch_id])

	# Step 4: Unlock all specified milestones
	for milestone_id in milestones:
		Registry.tech.unlock_milestone(milestone_id)

	# Step 5: Check if derived progress enables additional milestones
	Registry.tech.check_milestone_unlocks()

func _apply_perks(player: Player, origin_id: String):
	"""Grant starting perks to the player."""
	for perk_id in Registry.origins.get_starting_perks(origin_id):
		player.add_perk(perk_id)

func _place_units(spawn_coord: Vector2i, unit_entries: Array, player_id: String):
	"""Place starting units using hex spiral placement from the spawn center."""
	var occupied: Dictionary = {}  # Vector2i -> true (tracks placed units)

	for unit_entry in unit_entries:
		var unit_type: String = unit_entry.get("unit_type", "")
		if not Registry.units.has_unit(unit_type):
			push_warning("[Origin] Unit type '%s' not found, skipping" % unit_type)
			continue

		# Find a valid tile using spiral outward from spawn
		var placed_coord := _find_passable_tile(spawn_coord, unit_type, occupied)
		if placed_coord == Vector2i(-9999, -9999):
			push_warning("[Origin] Could not find passable tile for unit '%s' within 5 rings" % unit_type)
			continue

		# Spawn the unit
		var unit := unit_manager.spawn_unit(unit_type, player_id, placed_coord)
		if unit:
			occupied[placed_coord] = true
			# Apply ability overrides
			_apply_unit_ability_overrides(unit, unit_entry)

func _find_passable_tile(center: Vector2i, unit_type: String, occupied: Dictionary) -> Vector2i:
	"""Find the nearest unoccupied passable tile for a unit using spiral search."""
	var unit_data := Registry.units.get_unit(unit_type)
	var movement_type: String = unit_data.get("movement_type", "foot")

	for ring_radius in range(0, 6):  # Search up to 5 rings out
		var ring_coords := HexUtil.get_ring(center, ring_radius)
		for coord in ring_coords:
			if occupied.has(coord):
				continue
			# Check if another unit is already at this position
			if unit_manager.get_unit_at(coord):
				continue
			var tile := _get_tile_data(coord)
			if not tile:
				continue
			var cost := Registry.units.get_effective_movement_cost(movement_type, tile.terrain_id, tile.modifiers)
			if cost > 0:
				return coord

	return Vector2i(-9999, -9999)  # Sentinel: not found

func _apply_unit_ability_overrides(unit: Unit, origin_entry: Dictionary):
	"""Apply ability parameter overrides from the origin config to a spawned unit."""
	var ability_overrides: Dictionary = origin_entry.get("abilities", {})

	for ability_id in ability_overrides:
		# Validate unit has this ability
		if not unit.has_ability(ability_id):
			push_warning("[Origin] Unit '%s' does not have ability '%s', skipping override" %
				[unit.unit_type, ability_id])
			continue

		var params: Dictionary = ability_overrides[ability_id]

		# Handle transport cargo
		if ability_id == "transport" and params.has("cargo"):
			if not unit.has_cargo_capacity():
				push_warning("[Origin] Unit '%s' has no cargo capacity, cannot set cargo" % unit.unit_type)
				continue
			for resource_id in params.cargo:
				var amount: float = float(params.cargo[resource_id])
				var loaded := unit.add_cargo(resource_id, amount)
				if loaded < amount:
					push_warning("[Origin] Unit '%s' cargo overflow — tried %.0f %s, loaded %.0f" %
						[unit.unit_type, amount, resource_id, loaded])

func _reveal_explored_area(player_id: String, center: Vector2i, radius: int):
	"""Mark tiles within radius as explored in the fog of war."""
	for coord in HexUtil.get_coords_in_radius(center, radius):
		fog_manager.explored_tiles[coord] = true

# =============================================================================
# Phase 4: Settlement Placement
# =============================================================================

func _place_settlement(spawn_coord: Vector2i, settlement_config: Dictionary, player_id: String):
	"""Place a settlement from the origin config at the specified offset from spawn."""
	var settlement_type: String = settlement_config.get("settlement_type", "encampment")
	var offset: Array = settlement_config.get("offset", [0, 0])
	var city_coord := spawn_coord + Vector2i(int(offset[0]), int(offset[1]))

	# Determine name
	var city_name: String = ""
	if settlement_config.has("name") and settlement_config.get("name") != null:
		city_name = settlement_config.get("name")
	elif settlement_config.has("name_prefix") and settlement_config.get("name_prefix") != null:
		city_name = settlement_config.get("name_prefix") + str(randi() % 1000)
	else:
		city_name = "Settlement"

	# Found the settlement (skip naming dialog — origin settlements are auto-named)
	var city := city_manager.found_city(city_name, city_coord, player_id, settlement_type)
	if not city:
		push_warning("[Origin] Failed to found settlement at %v" % city_coord)
		return

	# Override population
	var target_pop: int = settlement_config.get("population", 0)
	if target_pop > 0:
		# Clear default population and set from origin
		var current_pop := city.get_total_resource("population")
		if current_pop > 0:
			city.consume_resource("population", current_pop)
		city.store_resource("population", target_pop)

	# Override resources
	var resources: Dictionary = settlement_config.get("resources", {})
	for resource_id in resources:
		var amount: float = float(resources[resource_id])
		city.store_resource(resource_id, amount)

	# Place buildings
	var buildings: Array = settlement_config.get("buildings", [])
	for building_config in buildings:
		_place_building(city, city_coord, building_config)

	# Recalculate stats after all modifications
	city.recalculate_city_stats()

func _place_building(city: City, city_coord: Vector2i, building_config: Dictionary):
	"""Place a building within a settlement according to its placement rules."""
	var building_id: String = building_config.get("building_id", "")
	var placement: String = building_config.get("placement", "center")

	if not Registry.buildings.building_exists(building_id):
		push_warning("[Origin] Building '%s' not found, skipping" % building_id)
		return

	# Handle force_modifier on the target tile
	var force_modifier: String = building_config.get("force_modifier", "")

	# Find the target tile
	var target_coord := _find_building_tile(city, city_coord, building_config)
	if target_coord == Vector2i(-9999, -9999):
		push_warning("[Origin] Could not find valid tile for building '%s' near city at %v" %
			[building_id, city_coord])
		return

	# Skip if this is the center tile and already has the city center building
	if placement == "center" and city.building_instances.has(city_coord):
		# Center already has a building from founding — this is expected for longhouse etc.
		return

	# Apply force_modifier if specified
	if force_modifier != "":
		var tile := _get_tile_data(target_coord)
		if tile and not tile.has_modifier(force_modifier):
			tile.add_modifier(force_modifier)

	# Ensure the tile is part of the city
	if not city.tiles.has(target_coord):
		city.add_tile(target_coord, false)
		city_manager.tile_ownership[target_coord] = city.city_id

	# Create and place the building instance (already built, active)
	var instance := BuildingInstance.new(building_id, target_coord)
	instance.set_active()
	city.building_instances[target_coord] = instance

	# Update tile's building reference
	var city_tile = city.get_tile(target_coord)
	if city_tile:
		city_tile.building_id = building_id

func _find_building_tile(city: City, city_coord: Vector2i, building_config: Dictionary) -> Vector2i:
	"""Find a valid tile for building placement based on placement rules."""
	var placement: String = building_config.get("placement", "center")
	var search_radius: int = building_config.get("radius", 3)
	var terrain_req: Array = building_config.get("terrain_required", [])
	var modifier_req: Array = building_config.get("modifier_required", [])

	if placement == "center":
		return city_coord

	# For "adjacent" and "radius" — search outward from city center
	var max_ring: int = search_radius if placement == "radius" else 5

	for ring in range(1, max_ring + 1):
		for coord in HexUtil.get_ring(city_coord, ring):
			var tile := _get_tile_data(coord)
			if not tile:
				continue
			# Check terrain requirement
			if not terrain_req.is_empty() and tile.terrain_id not in terrain_req:
				continue
			# Check modifier requirement
			if not modifier_req.is_empty():
				var has_all := true
				for mod in modifier_req:
					if not tile.has_modifier(mod):
						has_all = false
						break
				if not has_all:
					continue
			# Check no building already placed here
			if city.building_instances.has(coord):
				continue
			return coord

	return Vector2i(-9999, -9999)  # Not found
