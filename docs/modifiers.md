# Modifiers

Modifiers are features applied to tiles that alter their properties - resource deposits, terrain features, yield bonuses, and more. They also control world generation spawning rules. Each modifier is defined in its own JSON file under `data/modifiers/`.

## File Location

```
data/modifiers/<modifier_id>.json
```

## Schema

```json
{
  "type": "resource_deposit",
  "duration": -1,
  "stackable": false,
  "conflicts_with": ["iron_deposit"],

  "conditions": {
    "terrain_types": ["mountain", "rolling_hills", "sharp_hills"],
    "altitude_min": 0.6,
    "altitude_max": 1.0,
    "requires_modifiers": [],
    "prohibits_modifiers": []
  },

  "generation": {
    "spawn_chance": 0.20,
    "altitude_min": 0.6,
    "altitude_max": 1.0,
    "humidity_min": 0.0,
    "humidity_max": 1.0,
    "temperature_min": 0.0,
    "temperature_max": 1.0,
    "terrain_types": ["mountain", "rolling_hills", "sharp_hills"],
    "cluster_size": 2.0,
    "cluster_falloff": 1.0
  },

  "visual": {
    "icon": "res://assets/icons/copper.png",
    "overlay_color": "#CD7F3280"
  },

  "milestones_required": []
}
```

## Fields

### `type` (string, required)

| Value | Description |
|-------|-------------|
| `"resource_deposit"` | Represents a harvestable resource on the tile |
| `"terrain_feature"` | A natural feature that affects the tile (bushes, springs, etc.) |
| `"yield_modifier"` | Modifies the base yields of the tile |

### `duration` (int, required)

How long the modifier lasts. `-1` means permanent (most modifiers are permanent).

### `stackable` (bool, required)

Whether multiple instances of this modifier can exist on the same tile.

### `conflicts_with` (Array, required)

List of modifier IDs that cannot coexist on the same tile. For example, a copper deposit and iron deposit might conflict.

### `conditions` (Object, required)

Defines where this modifier can exist (runtime validation).

| Field | Type | Description |
|-------|------|-------------|
| `terrain_types` | Array | Terrain IDs where this modifier can appear |
| `altitude_min` | float | Minimum altitude (0.0-1.0) |
| `altitude_max` | float | Maximum altitude (0.0-1.0) |
| `requires_modifiers` | Array | Other modifier IDs that must be present |
| `prohibits_modifiers` | Array | Modifier IDs that must not be present |

### `generation` (Object, required)

Controls spawning during world generation. All range values are 0.0-1.0.

| Field | Type | Description |
|-------|------|-------------|
| `spawn_chance` | float | Probability of spawning per eligible tile |
| `altitude_min` | float | Minimum altitude for spawning |
| `altitude_max` | float | Maximum altitude for spawning |
| `humidity_min` | float | Minimum humidity |
| `humidity_max` | float | Maximum humidity |
| `temperature_min` | float | Minimum temperature |
| `temperature_max` | float | Maximum temperature |
| `terrain_types` | Array | Terrain IDs where this can spawn |
| `cluster_size` | float | How large clusters of this modifier tend to be |
| `cluster_falloff` | float | How quickly spawn probability drops from cluster center |

### `visual` (Object, required)

| Field | Type | Description |
|-------|------|-------------|
| `icon` | string | Path to the modifier icon asset |
| `overlay_color` | string | RGBA hex color for the tile overlay (8 hex digits, last 2 are alpha) |

### `milestones_required` (Array, optional)

Milestone IDs that must be unlocked before this modifier is visible or harvestable.

## Examples

### Resource Deposit (Copper)

Found in mountainous terrain:

```json
{
  "type": "resource_deposit",
  "duration": -1,
  "stackable": false,
  "conflicts_with": ["iron_deposit"],
  "conditions": {
    "terrain_types": ["mountain", "rolling_hills", "sharp_hills"],
    "altitude_min": 0.6,
    "altitude_max": 1.0,
    "requires_modifiers": [],
    "prohibits_modifiers": []
  },
  "generation": {
    "spawn_chance": 0.20,
    "altitude_min": 0.6,
    "altitude_max": 1.0,
    "humidity_min": 0.0,
    "humidity_max": 1.0,
    "temperature_min": 0.0,
    "temperature_max": 1.0,
    "terrain_types": ["mountain", "rolling_hills", "sharp_hills"],
    "cluster_size": 2.0,
    "cluster_falloff": 1.0
  },
  "visual": {
    "icon": "res://assets/icons/copper.png",
    "overlay_color": "#CD7F3280"
  },
  "milestones_required": []
}
```

### Yield Modifier (Fertile Soil)

Stackable modifier found in lowland, humid terrain:

```json
{
  "type": "yield_modifier",
  "duration": -1,
  "stackable": true,
  "conflicts_with": [],
  "conditions": {
    "terrain_types": ["grassland", "plains"],
    "altitude_min": 0.3,
    "altitude_max": 0.7,
    "requires_modifiers": [],
    "prohibits_modifiers": []
  },
  "generation": {
    "spawn_chance": 0.05,
    "altitude_min": 0.3,
    "altitude_max": 0.7,
    "humidity_min": 0.5,
    "humidity_max": 1.0,
    "temperature_min": 0.3,
    "temperature_max": 0.8,
    "terrain_types": ["grassland", "plains"],
    "cluster_size": 1.5,
    "cluster_falloff": 0.8
  },
  "visual": {
    "icon": "res://assets/icons/fertile_soil.png",
    "overlay_color": "#4A9B4A80"
  },
  "milestones_required": []
}
```

## Notes

- Modifiers are referenced by buildings (via `required_modifiers` in requirements) and by tile types (via `required_modifiers` for visual display).
- The `generation` section is only used during world creation. The `conditions` section is used for runtime validation.
- Overlay colors use RGBA hex (8 digits). The last two digits are alpha, e.g., `80` = 50% opacity.
