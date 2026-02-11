# Perks

Perks are civilization-wide bonuses that unlock when specific conditions are met. They provide lasting modifiers to buildings, units, yields, and more. Each perk is defined in its own JSON file under `data/perks/`.

## File Location

```
data/perks/<perk_id>.json
```

## Schema

```json
{
  "category": "economic",

  "unlock_conditions": {
    "milestones_before": {
      "agriculture_2": true
    },
    "milestones_not_researched": {},
    "cities_with_buildings": {
      "farm": 5
    },
    "tiles_owned_by_terrain": {},
    "turn_range": {
      "min": 10,
      "max": 100
    }
  },

  "effects": {
    "building_modifiers": {
      "farm": {
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

  "exclusive_with": []
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

### `unlock_conditions` (Object, required)

All conditions must be met simultaneously for the perk to unlock.

| Field | Type | Description |
|-------|------|-------------|
| `milestones_before` | Object | Milestones that must already be unlocked. Keys are milestone IDs, values are `true` |
| `milestones_not_researched` | Object | Milestones that must NOT be unlocked |
| `cities_with_buildings` | Object | Requires cities containing these buildings. Keys are building IDs, values are minimum count |
| `tiles_owned_by_terrain` | Object | Requires ownership of tiles with specific terrains. Keys are terrain IDs, values are minimum count |
| `turn_range` | Object | Turn window during which the perk can unlock |

**`turn_range`:**

| Field | Type | Description |
|-------|------|-------------|
| `min` | int | Earliest turn the perk can unlock |
| `max` | int | Latest turn; perk cannot unlock after this |

### `effects` (Object, required)

What the perk provides once unlocked.

#### `building_modifiers` (Object)

Per-building modifications. Keys are building IDs:

| Field | Type | Description |
|-------|------|-------------|
| `production_multiplier` | float | Multiplier on all production (1.25 = +25%) |
| `construction_cost_multiplier` | float | Multiplier on construction costs (0.8 = -20%) |

#### `unit_modifiers` (Object)

Per-unit modifications (same structure as building modifiers).

#### `yield_bonuses` (Object)

| Field | Type | Description |
|-------|------|-------------|
| `global` | Object | Resource bonuses applied globally. Keys are resource IDs |
| `per_terrain_type` | Object | Bonuses per terrain. Keys are terrain IDs, values are resource objects |

#### Other Effects

| Field | Type | Description |
|-------|------|-------------|
| `admin_distance_multiplier_modifier` | float | Modifies the admin distance cost multiplier |
| `unlocks_tech_branch` | string/null | Unlocks a tech branch ID |
| `unlocks_unique_buildings` | Array | Building IDs made available only through this perk |

### `visual` (Object, optional)

| Field | Type | Description |
|-------|------|-------------|
| `icon` | string | Path to the perk icon |
| `aesthetic_tag` | string | Visual theme tag for UI styling |

### `exclusive_with` (Array, optional)

List of perk IDs that cannot be active at the same time as this perk. If one is already active, the other cannot be unlocked.

## Example

### Agricultural Society

Boosts farm production and reduces farm construction cost:

```json
{
  "category": "economic",
  "unlock_conditions": {
    "milestones_before": { "agriculture_2": true },
    "milestones_not_researched": {},
    "cities_with_buildings": { "farm": 5 },
    "tiles_owned_by_terrain": {},
    "turn_range": { "min": 10, "max": 100 }
  },
  "effects": {
    "building_modifiers": {
      "farm": {
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
  "exclusive_with": []
}
```
