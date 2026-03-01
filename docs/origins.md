# Origins

Origins define how a player (or AI empire) begins the game: spawn location requirements, starting units, technology, perks, and optionally pre-built settlements. Each origin is defined in its own JSON file under `data/origins/`.

## File Location

```
data/origins/<origin_id>.json
```

## Schema

```json
{
  "tags": ["standard", "balanced"],

  "spawn": {
    "search_radius": 25,
    "min_radius": 0,
    "retry_step": 4,
    "max_attempts": 40,
    "min_distance_from_other_players": 20,
    "min_turns": 0,
    "initial_explored_radius": 5,
    "terrain_conditions": [
      { "type": "center_passable", "movement_type": "foot" },
      { "type": "terrain_tag", "tag": "land", "radius": 3, "min": 15 },
      { "type": "modifier", "modifier_id": "fresh_water", "radius": 4, "min": 1 }
    ],
    "force_modifiers": [
      { "modifier_id": "copper_deposit", "radius": 4, "count": 1, "terrain_filter": ["rolling_hills"] }
    ]
  },

  "tech": {
    "milestones": ["fire_mastery"],
    "branch_progress": {
      "agriculture": 10.0
    }
  },

  "perks": ["agricultural_society"],

  "units": [
    { "unit_type": "nomadic_band" },
    { "unit_type": "explorer" },
    {
      "unit_type": "caravan",
      "abilities": {
        "transport": {
          "cargo": { "food": 20, "wood": 10 }
        }
      }
    }
  ],

  "settlements": [
    {
      "settlement_type": "encampment",
      "name": "Homestead",
      "offset": [0, 0],
      "population": 12,
      "resources": { "food": 50, "wood": 30 },
      "buildings": [
        { "building_id": "longhouse", "placement": "center" },
        {
          "building_id": "crop_field",
          "placement": "adjacent",
          "terrain_required": ["plains", "meadow"]
        }
      ]
    }
  ],

  "visual": {
    "icon": "res://assets/icons/origins/default.svg",
    "color": "#4A7C59"
  }
}
```

## Fields

### `tags` (Array, required)

Categorization tags for filtering, grouping, and mod compatibility. Also serves as the difficulty indicator — no separate difficulty field.

Examples: `["standard"]`, `["nomadic", "steppe", "easy"]`, `["scenario", "settled", "hard"]`

### `spawn` (Object, required)

Controls where the player spawns and what the algorithm searches for.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `search_radius` | int | 30 | Max hex distance from world origin (0,0) to search |
| `min_radius` | int | 0 | Minimum distance from world origin. Together with `search_radius`, defines a ring |
| `retry_step` | int | 5 | Hex distance to jump between failed attempts in phase 2 |
| `max_attempts` | int | 50 | Hard cap on placement attempts before using best-scoring fallback |
| `min_distance_from_other_players` | int | 20 | Minimum hex distance from any already-placed player/AI start |
| `min_turns` | int | 0 | Minimum game turn before this origin can spawn (0 = game start) |
| `initial_explored_radius` | int | 5 | Hex radius revealed in fog of war at spawn |
| `terrain_conditions` | Array | [] | Spatial requirements the spawn location must satisfy |
| `force_modifiers` | Array | [] | Modifiers to guarantee near the spawn after location is chosen |

### `spawn.terrain_conditions` (Array)

Each condition is evaluated against the candidate spawn tile. All conditions must pass for a perfect match; partial matches are scored proportionally for fallback selection.

#### Condition Types

**`terrain`** — Count tiles of a specific terrain within a radius

```json
{ "type": "terrain", "terrain_id": "steppe", "radius": 5, "min": 8, "max": null }
```

**`modifier`** — Count tiles with a specific modifier within a radius

```json
{ "type": "modifier", "modifier_id": "fresh_water", "radius": 3, "min": 1 }
```

**`terrain_tag`** — Count tiles whose terrain `category` matches a tag within a radius

```json
{ "type": "terrain_tag", "tag": "land", "radius": 3, "min": 18 }
```

> Note: This checks the terrain JSON's `category` field (e.g., `"land"`, `"water"`), not a `tags` array.

**`center_terrain`** — Require the spawn tile itself to be a specific terrain

```json
{ "type": "center_terrain", "terrain_id": "steppe" }
```

**`center_passable`** — Require the spawn tile to be passable for a movement type

```json
{ "type": "center_passable", "movement_type": "foot" }
```

All counting conditions support optional `min` and `max` (omitted = no constraint).

### `spawn.force_modifiers` (Array)

After the spawn location is chosen, these modifiers are injected into nearby terrain. Ensures game balance — e.g., a player always has copper nearby even if world generation didn't place it.

| Field | Type | Description |
|-------|------|-------------|
| `modifier_id` | string | Modifier to place |
| `radius` | int | Search radius from spawn center for eligible tiles |
| `count` | int | How many tiles to place this modifier on |
| `terrain_filter` | Array | Only place on these terrain types (optional, empty = any) |

The algorithm finds eligible tiles (matching terrain filter, no conflicting modifiers), shuffles them, and places up to `count`. If fewer eligible tiles exist, a warning is logged.

### `tech` (Object, optional)

Starting technology state.

| Field | Type | Description |
|-------|------|-------------|
| `milestones` | Array | Milestone IDs to unlock at game start |
| `branch_progress` | Object | Branch ID → minimum progress level |

**Branch level derivation:** When milestones are specified, the system automatically derives the required branch levels from each milestone's `requirements` array. For each branch, it takes the maximum between the milestone-derived level and any explicit `branch_progress` value. This means modders don't need to manually look up and duplicate branch levels — specifying `"milestones": ["fire_mastery"]` automatically sets `gathering_and_crafting` to the level fire_mastery requires.

After setting branch progress, all specified milestones are unlocked, then a sweep checks if the derived progress enables any additional milestones not explicitly listed.

### `perks` (Array, optional)

Perk IDs granted immediately at game start, bypassing normal unlock conditions. Perks handle civilization identity, unique buildings, tech branch access, etc.

### `units` (Array, optional)

Starting units placed near the spawn location.

| Field | Type | Description |
|-------|------|-------------|
| `unit_type` | string | Unit type ID from `data/units/` |
| `abilities` | Object | Ability parameter overrides (optional) |

Units are placed in array order using hex spiral placement: starting from the spawn tile (ring 0), then ring 1, ring 2, etc. Each unit is placed on the first unoccupied tile passable for its movement type.

#### Ability Overrides

The `abilities` field sets initial state for ability-related data. The key is the ability ID, the value is ability-specific parameters.

```json
{
  "unit_type": "caravan",
  "abilities": {
    "transport": {
      "cargo": { "food": 20, "wood": 10 }
    }
  }
}
```

Validation:
- Unit doesn't have the ability → warning logged, override skipped
- `transport.cargo` on unit with no `cargo_capacity` → warning logged, skipped
- Total cargo exceeds `cargo_capacity` → warning logged, fills to capacity

### `settlements` (Array, optional)

Pre-built settlements placed at game start.

| Field | Type | Description |
|-------|------|-------------|
| `settlement_type` | string | Settlement type ID from `data/settlements/` |
| `name` | string | Exact settlement name (optional, takes priority) |
| `name_prefix` | string | Prefix for auto-generated name (optional) |
| `offset` | [int, int] | Hex offset from spawn center as `[q, r]` |
| `population` | int | Starting population (overrides settlement default) |
| `resources` | Object | Starting resources added to city storage |
| `buildings` | Array | Buildings to pre-place (see below) |

Names are auto-assigned for origin settlements — naming dialogs are skipped.

#### Settlement Buildings

| Field | Type | Description |
|-------|------|-------------|
| `building_id` | string | Building type ID |
| `placement` | string | `"center"`, `"adjacent"`, or `"radius"` |
| `radius` | int | Search radius for `"radius"` placement (default: 3) |
| `terrain_required` | Array | Terrain types the tile must have (optional) |
| `modifier_required` | Array | Modifiers the tile must have (optional) |
| `force_modifier` | string | Force-add a modifier to the tile before building (optional) |

**Placement modes:**
- **`"center"`** — Place on the city center tile (e.g., longhouse). Skipped if center already has a building from founding.
- **`"adjacent"`** — Search ring 1 outward for a matching tile (up to 5 rings).
- **`"radius"`** — Search within the configured `radius` from city center.

### `visual` (Object, optional)

| Field | Type | Description |
|-------|------|-------------|
| `icon` | string | Path to origin icon for selection UI |
| `color` | string | Hex color for UI accent |

## Spawn Algorithm

The spawn algorithm uses a two-phase scored search:

1. **Random sampling** (up to 30 candidates) — Pick random coordinates within the `[min_radius, search_radius]` ring from world origin. Each is scored against terrain conditions. First perfect match wins.

2. **Directed search** (remaining attempts) — Starting from the best candidate found, jump in random hex directions by `retry_step`, clamped to the ring. Continue scoring until a perfect match is found.

3. **Fallback** — If no perfect match after `max_attempts`, use the highest-scoring candidate. A warning is logged.

After the location is chosen, `force_modifiers` are injected and units/settlements are placed.

## Save/Load

Only the `origin_id` string is saved per player and in the game state — the full origin config is always looked up from the registry. This means:
- Save files stay small
- Mod updates to origin JSON are reflected on existing saves

## Localization

Add entries under the `"origin"` category in `data/localization/en.json`:

```json
{
  "origin": {
    "default": {
      "name": "Wandering Tribe",
      "description": "A small nomadic band seeking fertile lands to settle."
    }
  }
}
```

## Registry API

Access via `Registry.origins`:

```gdscript
Registry.origins.get_origin("default")              # Full origin dict
Registry.origins.has_origin("steppe_nomads")         # Existence check
Registry.origins.get_all_origin_ids()                # All IDs
Registry.origins.get_origins_by_tag("nomadic")       # Filter by tag

# Convenience accessors
Registry.origins.get_spawn_config("default")         # Spawn section
Registry.origins.get_starting_units("default")       # Units array
Registry.origins.get_starting_tech("default")        # Tech section
Registry.origins.get_starting_perks("default")       # Perks array
Registry.origins.get_starting_settlements("default") # Settlements array
Registry.origins.get_min_turns("default")            # Min turn for spawning
Registry.origins.get_min_radius("default")           # Min radius from origin
```

## Adding a New Origin

1. Create `data/origins/<id>.json` with the schema above
2. Add localization entry in `data/localization/en.json` under `"origin"`
3. Ensure all referenced units, milestones, perks, buildings, settlement types, terrains, and modifiers exist in their respective registries
4. The origin is validated at load time — missing references log warnings but don't crash (mod-friendly)

## Error Logging

All validation and runtime errors use `push_warning()` with clear, actionable messages prefixed by `[Origin: <id>]`:

**Registry validation (at load):**
```
[Origin: steppe_nomads] Unit type 'horse_rider' not found in UnitRegistry
[Origin: steppe_nomads] Milestone 'horseback_riding' not found in TechRegistry
[Origin: established_village] Building 'longhouse' not found in BuildingRegistry
```

**Runtime (during spawn):**
```
[Origin] Unit 'caravan' does not have ability 'transport', skipping override
[Origin] Could not find passable tile for unit 'nomadic_band' within 5 rings
[Origin] Could not find valid tile for building 'crop_field' near city at (5, 3)
[Origin: default] No perfect spawn after 40 attempts, using best match (score: 0.67)
[Origin] Force modifier 'copper_deposit' — only 0/1 eligible tiles found within radius 4
```

## New Game UI

The `NewGameScreen` (`src/ui/NewGameScreen.gd`, scene at `scenes/NewGameScreen.tscn`) provides the pre-game setup screen where the player selects an origin and configures the world seed.

### Screen Flow

```
MainMenu → "New Game" → NewGameScreen → "Start Game" → GameRoot (World)
```

Pressing "Back" returns to the MainMenu.

### Layout

The screen is a full-screen `PanelContainer` with:

- **Left column**: `ItemList` of all available origins, sorted alphabetically with "default" pinned to the top. Each entry shows the localized name plus tags in brackets (e.g., `Wandering Tribe  [standard, balanced]`).
- **Right column**: `RichTextLabel` showing the selected origin's details:
  - Name and description (from localization)
  - Starting units (localized names)
  - Starting technology (milestone names)
  - Starting settlements (name + type)
  - Starting perks (localized names)
  - Tags
- **Seed row**: A `LineEdit` with a default random seed and a "Random" button to regenerate.
- **Bottom buttons**: "Back" and "Start Game".

### Origin Filtering

Only origins with `min_turns == 0` are intended as player-selectable origins. Origins with `min_turns > 0` (like `rival_tribe`) still appear in the list but are designed as AI empire templates — future UI iterations could filter these out.

### How It Starts the Game

When "Start Game" is clicked:

```gdscript
GameState.start_new_game(seed_value, selected_origin_id)
get_tree().change_scene_to_file("res://scenes/GameRoot.tscn")
```

The seed input supports integers, or arbitrary strings (hashed to an integer).

## AI Empire Spawning

The `EmpireSpawnManager` (`src/core/EmpireSpawnManager.gd`) handles automatic spawning of AI empires during gameplay. Origins with `min_turns > 0` serve as templates for late-game AI empires that appear after a certain number of turns.

### How It Works

1. **Initialization**: Created by `World.gd` during game setup, receives references to `OriginSpawner` and `CityManager`.
2. **Turn hook**: `World._on_turn_completed()` calls `empire_spawn_manager.check_empire_spawns(current_turn)` each turn end.
3. **Eligibility check**: For each origin, the manager checks:
   - Has it already been spawned? (each origin spawns at most once)
   - Is `min_turns > 0`? (origins with `min_turns == 0` are player-only)
   - Is `current_turn >= min_turns`? (turn threshold met)
4. **Spawning**: If eligible, creates an AI player using `OriginSpawner.apply_origin()` and marks the player as non-human (`is_human = false`).

### AI Player Naming

AI empires are named using the origin's localized name with "Empire" appended:

```
"Rival Tribe" → "Rival Tribe Empire"
```

Player IDs are auto-generated: `ai_1`, `ai_2`, etc.

### Signals

```gdscript
signal empire_spawned(player_id: String, origin_id: String, coord: Vector2i)
```

Emitted after each successful AI empire spawn, useful for UI notifications or game events.

### Save/Load

The manager saves:
- `spawned_origins`: Array of origin IDs already used (prevents re-spawning on load)
- `ai_counter`: Current AI player ID counter (ensures unique IDs across saves)

```gdscript
# Saved in World.gd save data under "empire_spawn_manager"
{
  "spawned_origins": ["rival_tribe"],
  "ai_counter": 1
}
```

### Designing AI Origins

When creating an origin intended for late-game AI spawning:

| Consideration | Recommendation |
|---------------|----------------|
| `min_turns` | Set to the turn you want the AI to appear (e.g., 50) |
| `min_radius` | Set high (e.g., 40+) so the AI spawns far from the player |
| `search_radius` | Set wider than `min_radius` (e.g., 80) for more spawn options |
| `min_distance_from_other_players` | Set high (e.g., 25+) to avoid crowding |
| Tags | Include `"ai"` and/or `"late_game"` for clarity |
| Tech | Give competitive tech to match the game stage |
| Units | Include military units for an immediate threat |

## Examples

### Default Origin

The standard balanced start with a nomadic band and explorer:

```json
{
  "tags": ["standard", "balanced"],
  "spawn": {
    "search_radius": 25,
    "min_radius": 0,
    "retry_step": 4,
    "max_attempts": 40,
    "min_distance_from_other_players": 20,
    "min_turns": 0,
    "initial_explored_radius": 5,
    "terrain_conditions": [
      { "type": "center_passable", "movement_type": "foot" },
      { "type": "terrain_tag", "tag": "land", "radius": 3, "min": 15 },
      { "type": "modifier", "modifier_id": "fresh_water", "radius": 4, "min": 1 }
    ],
    "force_modifiers": []
  },
  "tech": {
    "milestones": [],
    "branch_progress": {}
  },
  "perks": [],
  "units": [
    { "unit_type": "nomadic_band" },
    { "unit_type": "explorer" }
  ],
  "settlements": [],
  "visual": {
    "icon": "res://assets/icons/origins/default.svg",
    "color": "#4A7C59"
  }
}
```

### Steppe Nomads

A nomadic start on steppe terrain with fire mastery tech and extra exploration:

```json
{
  "tags": ["nomadic", "steppe"],
  "spawn": {
    "search_radius": 35,
    "min_radius": 0,
    "retry_step": 5,
    "max_attempts": 60,
    "min_distance_from_other_players": 20,
    "min_turns": 0,
    "initial_explored_radius": 7,
    "terrain_conditions": [
      { "type": "center_terrain", "terrain_id": "steppe" },
      { "type": "terrain", "terrain_id": "steppe", "radius": 5, "min": 10 },
      { "type": "terrain", "terrain_id": "ocean", "radius": 10, "max": 0 },
      { "type": "modifier", "modifier_id": "fresh_water", "radius": 5, "min": 1 }
    ],
    "force_modifiers": []
  },
  "tech": {
    "milestones": ["fire_mastery"],
    "branch_progress": {}
  },
  "perks": [],
  "units": [
    { "unit_type": "nomadic_band" },
    { "unit_type": "explorer" },
    { "unit_type": "explorer" }
  ],
  "settlements": [],
  "visual": {
    "icon": "res://assets/icons/origins/steppe_nomads.svg",
    "color": "#8B7D3C"
  }
}
```

Key design points:
- Uses `center_terrain` to guarantee spawn on steppe
- Excludes ocean within 10 hex radius (inland focus)
- Extra explorer unit for fast scouting
- Wider `search_radius` (35) and more `max_attempts` (60) since steppe terrain may be less common

### Established Village

An easier start with a pre-built settlement, agriculture tech, and guaranteed copper:

```json
{
  "tags": ["scenario", "settled", "easy"],
  "spawn": {
    "search_radius": 20,
    "terrain_conditions": [
      { "type": "center_passable", "movement_type": "foot" },
      { "type": "terrain_tag", "tag": "land", "radius": 4, "min": 20 },
      { "type": "modifier", "modifier_id": "fresh_water", "radius": 3, "min": 2 }
    ],
    "force_modifiers": [
      { "modifier_id": "copper_deposit", "radius": 5, "count": 1, "terrain_filter": ["rolling_hills", "sharp_hills"] }
    ]
  },
  "tech": {
    "milestones": ["fire_mastery", "digging_sticks"],
    "branch_progress": {
      "agriculture": 10.0,
      "construction": 5.0
    }
  },
  "perks": ["agricultural_society"],
  "units": [
    { "unit_type": "explorer" }
  ],
  "settlements": [
    {
      "settlement_type": "encampment",
      "name": "Homestead",
      "offset": [0, 0],
      "population": 12,
      "resources": { "food": 50, "wood": 30, "stone": 20 },
      "buildings": [
        { "building_id": "longhouse", "placement": "center" },
        {
          "building_id": "crop_field",
          "placement": "adjacent",
          "terrain_required": ["plains", "meadow", "grassland"]
        }
      ]
    }
  ],
  "visual": {
    "icon": "res://assets/icons/origins/established_village.svg",
    "color": "#2E8B57"
  }
}
```

Key design points:
- Pre-built encampment with longhouse and crop field — player skips the founding phase
- `force_modifiers` guarantees copper nearby on hilly terrain
- Explicit `branch_progress` supplements what milestones auto-derive
- Two milestones are specified; branch levels are calculated automatically from their requirements, then raised to at least `agriculture: 10.0` and `construction: 5.0`

### Rival Tribe (AI Empire)

A late-game AI opponent that appears after turn 50:

```json
{
  "tags": ["ai", "aggressive", "late_game"],
  "spawn": {
    "search_radius": 80,
    "min_radius": 40,
    "retry_step": 6,
    "max_attempts": 30,
    "min_distance_from_other_players": 25,
    "min_turns": 50,
    "initial_explored_radius": 4,
    "terrain_conditions": [
      { "type": "center_passable", "movement_type": "foot" },
      { "type": "terrain_tag", "tag": "land", "radius": 3, "min": 12 }
    ],
    "force_modifiers": []
  },
  "tech": {
    "milestones": ["fire_mastery", "lithic_reduction", "masonry"],
    "branch_progress": {}
  },
  "perks": [],
  "units": [
    { "unit_type": "nomadic_band" },
    { "unit_type": "club_wielder" },
    { "unit_type": "club_wielder" },
    { "unit_type": "explorer" }
  ],
  "settlements": [],
  "visual": {
    "icon": "res://assets/icons/origins/rival_tribe.svg",
    "color": "#8B2500"
  }
}
```

Key design points:
- `min_turns: 50` — not available at game start, spawned automatically by `EmpireSpawnManager`
- `min_radius: 40` — spawns far from the world center, away from the player
- `search_radius: 80` — wide search area for distant placement
- Relaxed terrain conditions (just needs passable land) since far-off terrain is less predictable
- Multiple combat units for an immediate military presence
- Three milestones give competitive tech matching the mid-game stage

## Notes

- Origins are loaded last in the registry initialization sequence so validation can cross-reference all other registries.
- The `terrain_tag` condition type checks the terrain's `category` field in the terrain JSON (e.g., `"land"`, `"water"`).
- Tile data for the spawn search is lazily generated via `ChunkManager` — no visual chunks are needed during the search.
- The spawner caches tile data during the search to avoid redundant generation when candidate neighborhoods overlap.
- Origins with `min_turns > 0` are used as AI empire templates — the `EmpireSpawnManager` checks them each turn and spawns AI empires once the turn threshold is met. Each such origin spawns at most one AI empire per game.
- The `OriginSpawner` class (`src/core/OriginSpawner.gd`) handles all spawn logic and is created by `World.gd` during game initialization.
- The `EmpireSpawnManager` class (`src/core/EmpireSpawnManager.gd`) manages late-game spawns and is hooked into `World._on_turn_completed()`.
- The `NewGameScreen` (`src/ui/NewGameScreen.gd`) provides the pre-game origin selection UI, accessible from the main menu.
