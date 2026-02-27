# Save/Load System

## Overview

The save/load system persists the full game state to `user://saves/<save_id>/`. Each save is a directory containing:

| File | Format | Contents |
|------|--------|----------|
| `meta.json` | JSON | Display name, seed, turn number, timestamp (for save list UI) |
| `game_state.json` | JSON | All runtime game state (cities, units, tech, fog, trade routes) |
| `chunks/chunk_<q>_<r>.bin` | Binary | Terrain data for each generated chunk |

## Save Flow

### Trigger

1. **SaveButton** (`src/ui/SaveButton.gd`) — a `Button` in the world UI.
2. Player clicks it → dialog opens with default name `"Save - Turn X"`.
3. On confirm, `_on_save_confirmed()`:
   - Sanitizes the display name into a filesystem-safe `save_id` (lowercase, underscores, ASCII only).
   - Appends `_2`, `_3`... if the directory already exists.
   - Sets `GameState.save_id` and `GameState.save_display_name`.
   - Calls `World.save_game()`.

### World.save_game() (`src/world/World.gd:1122`)

Orchestrates saving in three steps:

```
1. chunk_manager.save_world()          # Binary terrain chunks
2. chunk_manager.save_meta(turn)       # meta.json
3. Build game_data dict → write game_state.json
```

#### Step 1: Terrain Chunks (Binary)

`ChunkManager.save_world()` iterates all entries in `chunk_data` (Dictionary of `Vector2i → ChunkData`) and calls `ChunkData.save_chunk()` for each.

**ChunkData binary format** (`src/model/ChunkData.gd`):
```
[int16 chunk_q] [int16 chunk_r] [int32 tile_count]
For each tile:
  [int16 q] [int16 r]
  [float altitude] [float humidity] [float temperature]
  [variant is_river]
  [pascal_string terrain_id]
  [int16 modifier_count]
  For each modifier:
    [pascal_string modifier_id]
```

Path: `user://saves/<save_id>/chunks/chunk_<q>_<r>.bin`

Directory creation is handled by `get_chunk_path()` which creates `saves/`, `saves/<save_id>/`, and `saves/<save_id>/chunks/` as needed.

#### Step 2: Metadata (JSON)

`ChunkManager.save_meta()` writes `meta.json`:
```json
{
  "seed": 12345,
  "save_version": 1,
  "display_name": "Save - Turn 5",
  "current_turn": 5,
  "timestamp": "2026-01-15T14:30:00"
}
```

#### Step 3: Game State (JSON)

`World.save_game()` builds a dictionary and writes `game_state.json`:

```json
{
  "save_version": 1,
  "current_turn": 5,
  "current_player_id": "player1",
  "city_manager": { ... },
  "units": { ... },
  "trade_routes": { ... },
  "fog_of_war": { ... },
  "tech": { ... }
}
```

Each subsystem provides its own serialization via `get_save_data()` or `to_dict()`.

## Load Flow

### Trigger

1. **MainMenu** (`src/core/MainMenu.gd`) — "Load Game" button.
2. `_on_load_game()` scans `user://saves/` for directories containing `meta.json`.
3. Reads each `meta.json` to build the save list (display name, turn, timestamp).
4. Sorted by timestamp descending (most recent first).
5. Player selects a save → `_on_load_confirmed()`:
   - Calls `GameState.load_game(save_id)` which sets `mode = LOAD_GAME` and `save_id`.
   - Transitions to `GameRoot.tscn` via `change_scene_to_file`.

### GameState Modes (`src/core/GameState.gd`)

```gdscript
enum Mode { NEW_GAME, LOAD_GAME }
```

- `start_new_game(seed)` — sets mode to NEW_GAME, clears save_id
- `load_game(save_id)` — sets mode to LOAD_GAME, stores save_id

### ChunkManager._ready() (Terrain Load)

When mode is `LOAD_GAME`:
1. `load_meta()` — reads `meta.json`, restores `GameState.world_seed`.
2. Creates `TileGenerator` with the restored seed (for procedurally generating chunks not yet saved).
3. `load_world(save_id)` → `load_visible_chunks()` — loads chunks around camera.

**Key detail**: `get_or_create_chunk_data()` checks if a `.bin` file exists for a chunk. If yes, loads from file; if not, procedurally generates it. This means only visited chunks are saved; unvisited areas regenerate deterministically from the seed.

### World._ready() (Full State Load)

After `ChunkManager._ready()` loads terrain, `World._ready()` checks `GameState.mode`:

```
LOAD_GAME:
  1. load_existing_world()     # Restore all game state from game_state.json
  2. unit_layer.create_sprites_for_existing_units()  # Visual sprites
  3. Initialize fog of war
  4. chunk_manager.update_chunks(camera_pos)  # Force chunk refresh
  5. _restore_loaded_chunk_visuals()           # Building sprites on tiles
```

### World.load_existing_world() (`src/world/World.gd:1066`)

Reads `game_state.json` and restores subsystems **in dependency order**:

| Order | Subsystem | Method | Source Key |
|-------|-----------|--------|------------|
| 1 | Tech | `Registry.tech.load_save_data()` | `tech` |
| 2 | Turn counter | Direct assignment | `current_turn` |
| 3 | Current player | Direct assignment | `current_player_id` |
| 4 | Cities + Players | `city_manager.load_save_data()` | `city_manager` |
| 5 | Units | `unit_manager.load_save_data()` | `units` |
| 6 | Trade Routes | `trade_route_manager.from_dict()` | `trade_routes` |
| 7 | Fog of War | `fog_manager.load_save_data()` | `fog_of_war` |

Tech is loaded first because city stat recalculation may check milestone unlocks.

After loading, the camera focuses on the player's first city (or first unit if no cities).

## Serialization Details per Subsystem

### TechRegistry (`src/registry/TechRegistry.gd`)

**Saved**: `branch_progress` (Dictionary), `unlocked_milestones` (Array), `preferred_research_branch` (String).

**Load**: Overlays saved progress onto existing branches (missing branches get 0.0). Milestones are restored directly.

### CityManager (`src/core/CityManager.gd`)

**Saved**: Arrays of `players` and `cities`, each serialized via `to_dict()`.

**Load**: Clears all state, restores players first, then cities. For each city:
- Rebuilds `tile_ownership` from city tile coords.
- Reconnects `city.owner` reference to the loaded Player object.
- Calls `city.recalculate_city_stats()` to restore cap state.

### Player (`src/model/Player.gd`)

**Saved**: `player_id`, `player_name`, `is_human`, `civilization_perks`.

**Note**: `cities` array is NOT saved — it's rebuilt during CityManager load by reconnecting owner references.

### City (`src/model/City.gd`)

**Saved**:
- Core: `city_id`, `city_name`, `owner_id`, `settlement_type`, `city_center_coord`, `is_abandoned`
- Tiles: Array of `{coord, building_id, is_city_center, distance_from_center}`
- Buildings: Array of BuildingInstance dicts

**Load**: `City.from_dict()` static constructor. Rebuilds tiles, building instances, and frontier.

**Not saved** (recomputed): `cap_state`, `frontier_tiles` (via `update_frontier()`), `resources` (ResourceLedger — legacy).

### BuildingInstance (`src/model/BuildingInstance.gd`)

**Saved**:
- Core: `building_id`, `tile_coord`, `status` (enum int)
- Construction: `turns_remaining`, `cost_per_turn`
- Upgrade: `upgrading_to`, `upgrade_turns_remaining`, `upgrade_total_turns`, `upgrade_cost_per_turn`
- Training: `training_unit_id`, `training_turns_remaining`, `training_total_turns`
- Storage: `storage_pools` array (each pool: `capacity`, `accepted_resources`, `accepted_tags`, `stored`, `decay_reduction`)

**Load**: `BuildingInstance.from_dict()` creates a new instance (which re-initializes pools from registry), then overlays saved `stored` data onto the pools. Supports legacy `stored_resources` flat dict migration.

### UnitManager (`src/core/UnitManager.gd`)

**Saved**: `next_unit_id` (int), `units` (array of Unit dicts).

**Load**: Clears state, restores each unit, reconnects signals (`moved`, `destroyed`), rebuilds `units_by_coord` spatial index.

### Unit (`src/model/Unit.gd`)

**Saved**: `unit_id`, `unit_type`, `owner_id`, `coord` (`{x, y}`), `home_city_id`, `current_health`, `current_movement`, `is_fortified`, `has_acted`, `attacks_remaining`, `cargo`, `is_exploring_route`, `is_assigned_to_trade_route`.

**Load**: `Unit.from_save_data()` creates via constructor (which loads base stats from registry), then overlays saved runtime state. This means `max_health`, `max_movement`, `vision_range`, `armor_class_ids`, `movement_type`, and `cargo_capacity` come from the registry, not the save.

### TradeRouteManager (`src/core/TradeRouteManager.gd`)

**Saved**: `routes` dict (each via `TradeRoute.to_dict()`), `_next_route_num`.

**Load**: Restores routes, then **recalculates** `avg_movement_cost` from live world data and `total_throughput`.

### TradeRoute (`src/model/TradeRoute.gd`)

**Saved**: `route_id`, `city_a_id`, `city_b_id`, `unit_type`, `path` (array of `[q, r]`), `owner_id`, `convoys`, `allocations`.

**Not saved** (recomputed): `distance` (from path.size()), `avg_movement_cost`, `total_throughput`.

### FogOfWarManager (`src/core/FogOfWarManager.gd`)

**Saved**: `player_id`, `explored_tiles` (array of `[q, r]` pairs).

**Not saved**: `visible_tiles` — fully recomputed via `recalculate_visibility()` after all cities/units are loaded.

### HexTileData / Chunks (Binary)

**Saved per tile**: `q`, `r`, `altitude`, `humidity`, `temperature`, `is_river`, `terrain_id`, `modifiers[]`.

**Backward compatible**: `read_tile()` checks `eof_reached()` before reading modifiers, so old saves without modifiers still load.

## Post-Load Visual Restoration

After data is loaded, visuals need to be set up:

1. **Unit sprites**: `unit_layer.create_sprites_for_existing_units()` — creates `UnitSprite` nodes for all loaded units (since `UnitLayer.setup()` ran before units existed).

2. **Building sprites**: `_restore_loaded_chunk_visuals()` iterates all loaded chunks, checks each tile against `city_manager` for building instances, and calls `tile.set_building(building_id, is_under_construction)`.

3. **Chunk refresh**: `chunk_manager.update_chunks(camera.global_position)` forces loading chunks around the restored camera position.

4. **Fog of war**: `fog_manager.recalculate_visibility()` recomputes visible tiles from all current vision sources.

5. **Chunk-loaded signal**: `_on_chunk_loaded()` is connected to restore building visuals whenever new chunks come into view during gameplay.

## Important Notes

- **Save versioning**: Both `meta.json` and `game_state.json` include `save_version: 1`. No migration logic exists yet.
- **Save ID uniqueness**: Ensured by appending `_2`, `_3`, etc. if the directory exists.
- **No overwrite**: Each save creates a new directory. No update-in-place mechanism.
- **No delete**: No UI to delete saves.
- **Chunk generation fallback**: Unvisited chunks are not saved — they regenerate from the seed, ensuring deterministic world generation.
- **Registry dependency**: Unit stats, building definitions, and other static data come from the registry (JSON files), NOT from the save. If game data changes between save and load, behavior may differ.
