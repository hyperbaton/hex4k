# Terrains

Terrains define the base properties of each hex tile in the world. Each terrain is defined in its own JSON file under `data/terrains/`.

## File Location

```
data/terrains/<terrain_id>.json
```

## Schema

```json
{
  "movement_cost": 1.0,
  "passable": true,
  "category": "land",
  "generation": {
    "altitude_min": 0.35,
    "altitude_max": 0.55,
    "humidity_min": 0.40,
    "humidity_max": 0.60,
    "temperature_min": 0.35,
    "temperature_max": 0.70,
    "priority": 5
  },
  "visual": {
    "color": "#6AAA50",
    "sprite": "plains.svg"
  },
  "yields": {
    "food": 2
  }
}
```

## Fields

### `movement_cost` (float, required)

Base movement cost for units traversing this terrain. Higher values mean harder terrain. Movement types can override this per-terrain (see [movement_types.md](movement_types.md)).

### `passable` (bool, required)

Whether units can enter this terrain at all. Set to `false` for impassable terrain like deep ocean or mountains.

### `category` (string, required)

Terrain classification. Used by buildings and units to determine what's allowed.

| Value | Description |
|-------|-------------|
| `"land"` | Standard land terrain |

### `generation` (Object, required)

Controls where this terrain spawns during world generation. All range values are floats from 0.0 to 1.0.

| Field | Type | Description |
|-------|------|-------------|
| `altitude_min` | float | Minimum altitude for this terrain to spawn |
| `altitude_max` | float | Maximum altitude |
| `humidity_min` | float | Minimum humidity |
| `humidity_max` | float | Maximum humidity |
| `temperature_min` | float | Minimum temperature |
| `temperature_max` | float | Maximum temperature |
| `priority` | int | Tie-breaking priority when multiple terrains match (higher = preferred) |
| `special` | string | Optional. `"deprecated"` marks terrains no longer used in generation, `"modifier_only"` for terrains that only appear as modifiers |

### `visual` (Object, required)

| Field | Type | Description |
|-------|------|-------------|
| `color` | string | Hex color for map rendering |
| `sprite` | string | SVG filename for the terrain tile |

### `yields` (Object, optional)

Base resource yields per turn for this terrain. Keys are resource IDs, values are amounts.

```json
{
  "food": 2,
  "production": 1
}
```

## Example

### Plains

```json
{
  "movement_cost": 1.0,
  "passable": true,
  "category": "land",
  "generation": {
    "altitude_min": 0.35,
    "altitude_max": 0.55,
    "humidity_min": 0.40,
    "humidity_max": 0.60,
    "temperature_min": 0.35,
    "temperature_max": 0.70,
    "priority": 5
  },
  "visual": {
    "color": "#6AAA50",
    "sprite": "plains.svg"
  },
  "yields": {
    "food": 2
  }
}
```

## Notes

- Some terrain files are marked as deprecated (e.g., old `grassland.json` with `"special": "deprecated"`). These are kept for backward compatibility but won't generate in new worlds.
- Terrain IDs are referenced by buildings (in `terrain_types`/`terrain_exclude`), modifiers (in `conditions.terrain_types`), and tile types (in `base_terrain`).
