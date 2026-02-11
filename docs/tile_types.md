# Tile Types

Tile types define the visual representation for combinations of a base terrain and modifiers. They control which sprite is displayed on the map. Each tile type is defined in its own JSON file under `data/tile_types/`.

## File Location

```
data/tile_types/<tile_type_id>.json
```

## Schema

```json
{
  "id": "grassland_dense_forest",
  "display_name": "Dense Forest",
  "base_terrain": "grassland",
  "required_modifiers": ["dense_forest"],
  "visual": {
    "sprite": "res://assets/tiles/grassland_dense_forest.svg",
    "color": "#2D5A1E"
  }
}
```

## Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier, should match the filename |
| `display_name` | string | Name shown to the player |
| `base_terrain` | string | Terrain ID this tile type applies to |
| `required_modifiers` | Array | Modifier IDs that must be present for this tile type to display |
| `visual.sprite` | string | Path to the SVG sprite |
| `visual.color` | string | Hex color for the tile |

## How Tile Type Resolution Works

When the game needs to display a tile, it checks the tile's terrain and active modifiers, then finds the most specific tile type that matches:

1. It looks for tile types with the same `base_terrain`
2. Among those, it selects the one whose `required_modifiers` best match the tile's actual modifiers
3. More specific matches (more required modifiers) are preferred
4. If no tile type matches, the bare terrain is used as a fallback

## Examples

### Simple Terrain (Grassland)

No modifiers required - this is the default display for grassland tiles:

```json
{
  "id": "grassland",
  "display_name": "Grassland",
  "base_terrain": "grassland",
  "required_modifiers": [],
  "visual": {
    "sprite": "res://assets/tiles/grassland.svg",
    "color": "#7CBA5B"
  }
}
```

### Composite Terrain (Grassland + Dense Forest)

Displayed when a grassland tile has the `dense_forest` modifier:

```json
{
  "id": "grassland_dense_forest",
  "display_name": "Dense Forest",
  "base_terrain": "grassland",
  "required_modifiers": ["dense_forest"],
  "visual": {
    "sprite": "res://assets/tiles/grassland_dense_forest.svg",
    "color": "#2D5A1E"
  }
}
```

## Notes

- Tile types are purely visual - they don't affect gameplay mechanics. Gameplay is driven by the base terrain and modifiers independently.
- The naming convention is `<terrain>_<modifier1>_<modifier2>` for composite types.
