# Perks

Perks are civilization-wide bonuses that auto-unlock when specific conditions are met at the end of each turn. They provide lasting modifiers to buildings, units, yields, and more. Each perk is defined in its own JSON file under `data/perks/`.

## File Location

```
data/perks/<perk_id>.json
```

## Schema

```json
{
  "category": "economic",

  "unlock_conditions": [
    { "type": "milestone_unlocked", "milestone": "seed_selection" },
    { "type": "building_count", "building": "crop_field", "min": 5 },
    { "type": "turn", "min": 10, "max": 100 }
  ],

  "effects": {
    "building_modifiers": {
      "crop_field": {
        "production_multiplier": 1.25,
        "construction_cost_multiplier": 0.8
      }
    },
    "unit_modifiers": {},
    "yield_bonuses": {
      "global": { "food": 2 },
      "per_terrain_type": {}
    },
    "admin_distance_multiplier_modifier": 0.0,
    "unlocks_tech_branch": null,
    "unlocks_unique_buildings": []
  },

  "visual": {
    "icon": "res://assets/icons/perk_agricultural.png",
    "aesthetic_tag": "agricultural"
  },

  "exclusive_with": [],

  "visibility": {
    "always_visible": false,
    "show_when": [
      { "type": "milestone_unlocked", "milestone": "seed_selection" }
    ]
  }
}
```

## Fields

### `category` (string, required)

| Value | Description |
|-------|-------------|
| `"economic"` | Production and trade bonuses |
| `"cultural"` | Research and cultural bonuses |
| `"military"` | Combat and unit bonuses |
| `"scientific"` | Research-focused bonuses |

### `unlock_conditions` (Array, required)

Array of condition objects. All conditions must be met simultaneously (AND logic). Each condition has a `type` and type-specific parameters. All numeric conditions support optional `min` and `max` bounds.

#### Condition Types

| Type | Parameters | Description |
|------|-----------|-------------|
| `turn` | `min`, `max` | Current turn number |
| `milestone_unlocked` | `milestone` | Specific milestone must be unlocked |
| `milestone_locked` | `milestone` | Specific milestone must NOT be unlocked |
| `building_count` | `building`, `min`, `max` | Total buildings of this type across all player cities |
| `tiles_by_terrain` | `terrain`, `min`, `max` | Owned tiles with this terrain type |
| `tiles_by_modifier` | `modifier`, `min`, `max` | Owned tiles with this modifier |
| `unit_count` | `unit`, `min`, `max` | Units of this type owned by player |
| `resource_production` | `resource`, `min`, `max` | Net production per turn (from last turn report) |
| `resource_stored` | `resource`, `min`, `max` | Total stored across all cities |
| `city_population` | `min`, `max` | Any single city has population in range |
| `total_population` | `min`, `max` | Sum of all city populations |
| `city_count` | `min`, `max` | Number of non-abandoned cities |
| `total_tiles` | `min`, `max` | Total tiles owned across all cities |

All `min`/`max` are optional. Omit to skip that bound.

#### Example Conditions

```json
"unlock_conditions": [
  { "type": "turn", "min": 15, "max": 150 },
  { "type": "milestone_unlocked", "milestone": "livestock_domestication" },
  { "type": "building_count", "building": "herding_grounds", "min": 3 },
  { "type": "tiles_by_terrain", "terrain": "steppe", "min": 4 },
  { "type": "city_count", "min": 2 }
]
```

### `effects` (Object, required)

What the perk provides once unlocked.

#### `building_modifiers` (Object)

Per-building modifications. Keys are building IDs. Multiple perks stack multiplicatively.

| Field | Type | Description |
|-------|------|-------------|
| `production_multiplier` | float | Multiplier on all production (1.25 = +25%) |
| `construction_cost_multiplier` | float | Multiplier on construction costs (0.8 = -20%) |

#### `unit_modifiers` (Object)

Per-unit modifications (same structure as building modifiers).

#### `yield_bonuses` (Object)

| Field | Type | Description |
|-------|------|-------------|
| `global` | Object | Resource bonuses applied once per city per turn. Keys are resource IDs |
| `per_terrain_type` | Object | Bonuses per terrain type on each building tile. Keys are terrain IDs, values are resource objects |

#### Other Effects

| Field | Type | Description |
|-------|------|-------------|
| `admin_distance_multiplier_modifier` | float | Added to the admin distance cost multiplier (negative = cheaper) |
| `unlocks_tech_branch` | string/null | Unlocks a tech branch ID (reserved for future use) |
| `unlocks_unique_buildings` | Array | Building IDs made available only through this perk |

### `visual` (Object, optional)

| Field | Type | Description |
|-------|------|-------------|
| `icon` | string | Path to the perk icon |
| `aesthetic_tag` | string | Visual theme tag for UI styling |

### `exclusive_with` (Array, optional)

List of perk IDs that cannot be active at the same time as this perk. If one is already active, the other cannot be unlocked.

### `visibility` (Object, optional)

Controls when the perk is shown in the Perks UI. Unlocked perks are always shown regardless of visibility settings. If omitted, the perk is always visible (backward compatible).

| Field | Type | Description |
|-------|------|-------------|
| `always_visible` | bool | If `true`, perk is always shown even when locked. Default: `false` |
| `show_when` | Array | Array of conditions (same types as `unlock_conditions`). If **any** condition passes (OR logic), the perk is shown. If all fail, the perk is hidden |

The `show_when` conditions use the same condition types as `unlock_conditions` (see Condition Types table above). This allows flexible visibility rules like showing a perk when its prerequisite milestone is unlocked, or when the player has built enough of a certain building.

#### Example Visibility Configurations

```json
// Show when prerequisite milestone is unlocked (most common)
"visibility": {
  "always_visible": false,
  "show_when": [
    { "type": "milestone_unlocked", "milestone": "seed_selection" }
  ]
}

// Hidden perk — only shown once unlocked
"visibility": {
  "always_visible": false,
  "show_when": []
}

// Always visible (same as omitting visibility entirely)
"visibility": {
  "always_visible": true
}
```

## Example

### Agricultural Society

Boosts crop field production and reduces construction cost:

```json
{
  "category": "economic",
  "unlock_conditions": [
    { "type": "milestone_unlocked", "milestone": "seed_selection" },
    { "type": "building_count", "building": "crop_field", "min": 5 },
    { "type": "turn", "min": 10, "max": 100 }
  ],
  "effects": {
    "building_modifiers": {
      "crop_field": {
        "production_multiplier": 1.25,
        "construction_cost_multiplier": 0.8
      }
    },
    "unit_modifiers": {},
    "yield_bonuses": {
      "global": { "food": 2 },
      "per_terrain_type": {}
    },
    "admin_distance_multiplier_modifier": 0.0,
    "unlocks_tech_branch": null,
    "unlocks_unique_buildings": []
  },
  "visual": {
    "icon": "res://assets/icons/perk_agricultural.png",
    "aesthetic_tag": "agricultural"
  },
  "exclusive_with": [],
  "visibility": {
    "always_visible": false,
    "show_when": [
      { "type": "milestone_unlocked", "milestone": "seed_selection" }
    ]
  }
}
```

## How Perks Work

1. **Detection**: At the end of each turn, after milestone detection, the system checks all unowned perks for every player
2. **Game State Snapshot**: A comprehensive game state is built including building counts, terrain tiles, unit counts, resource production/storage, population, etc.
3. **Condition Checking**: Each condition in the `unlock_conditions` array is checked against the snapshot — all must pass
4. **Auto-Unlock**: When all conditions pass and the perk isn't blocked by `exclusive_with`, it's automatically added to the player
5. **Effect Application**: Effects are applied continuously during turn processing (production multipliers, yield bonuses, cost reductions)
6. **UI**: Players can view perks via the Perks button in the world view — unlocked perks are always shown, locked perks are only shown if their `visibility` conditions are met

## Notes

- Perks are permanent once unlocked — they cannot be lost
- Production multipliers from multiple perks stack multiplicatively
- Global yield bonuses and admin distance modifiers stack additively
- Buildings listed in `unlocks_unique_buildings` cannot be built without the perk
