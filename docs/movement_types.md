# Movement Types

Movement types define how different units traverse terrain. They override the base terrain movement cost with per-terrain costs, and can also define costs for modifiers like roads. Each movement type is defined in its own JSON file under `data/movement_types/`.

## File Location

```
data/movement_types/<movement_type_id>.json
```

## Schema

```json
{
  "name": "Foot",
  "description": "Standard movement on foot. Hindered by rough terrain.",
  "terrain_costs": {
    "grassland": 1,
    "plains": 1,
    "meadow": 1,
    "forest": 2,
    "rolling_hills": 2,
    "sharp_hills": 3,
    "steppe": 1,
    "savannah": 1,
    "floodplains": 2,
    "marsh": 3,
    "beach": 1
  },
  "modifier_costs": {
    "path": 1,
    "paved_road": 1
  }
}
```

## Fields

### `name` (string, required)

Display name for the movement type.

### `description` (string, required)

Describes how this movement type behaves.

### `terrain_costs` (Object, required)

Movement point cost per terrain type. Keys are terrain IDs, values are integers.

| Value | Meaning |
|-------|---------|
| `1` | Easy terrain (1 movement point) |
| `2` | Moderate terrain |
| `3` | Difficult terrain |
| `-1` | Impassable for this movement type |

Terrains not listed use their default `movement_cost` from the terrain definition.

### `modifier_costs` (Object, optional)

Movement cost overrides when specific modifiers are present on the tile. When a modifier is present, its cost replaces the terrain cost (whichever is lower).

For example, a `paved_road` modifier with cost `1` means any tile with a paved road costs only 1 movement point regardless of terrain.

## Examples

### Foot

Standard movement, struggles with rough terrain:

```json
{
  "name": "Foot",
  "description": "Standard movement on foot. Hindered by rough terrain.",
  "terrain_costs": {
    "grassland": 1,
    "plains": 1,
    "meadow": 1,
    "forest": 2,
    "rolling_hills": 2,
    "sharp_hills": 3,
    "steppe": 1,
    "savannah": 1,
    "floodplains": 2,
    "marsh": 3,
    "beach": 1
  },
  "modifier_costs": {
    "path": 1,
    "paved_road": 1
  }
}
```

### Cart

Wheeled transport, cannot cross very rough terrain:

```json
{
  "name": "Cart",
  "description": "Wheeled transport. Slow on rough terrain but benefits from roads.",
  "terrain_costs": {
    "grassland": 2,
    "plains": 2,
    "meadow": 2,
    "forest": 3,
    "rolling_hills": 3,
    "sharp_hills": -1,
    "steppe": 2,
    "savannah": 2,
    "floodplains": 3,
    "marsh": -1,
    "beach": 2
  },
  "modifier_costs": {
    "path": 1,
    "paved_road": 1
  }
}
```

Note how carts cannot enter sharp hills (`-1`) or marshes (`-1`), but roads normalize the cost to 1.

## Notes

- Units reference movement types via the `movement_type` field in their JSON definition.
- A unit's `stats.movement` determines how many movement points it has per turn, and the movement type determines how those points are spent per tile.
