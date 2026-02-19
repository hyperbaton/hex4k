# Units

Units are mobile entities on the map that can move, perform abilities, and interact with cities. Each unit type is defined in its own JSON file under `data/units/`.

## File Location

```
data/units/<unit_id>.json
```

## Schema

```json
{
  "category": "civil",
  "trained_at": ["city_center", "longhouse", "tribal_camp"],
  "milestones_required": [],
  "training": {
    "cost": { "food": 50, "wood": 20, "tools": 5 },
    "turns": 5
  },
  "stats": {
    "health": 100,
    "movement": 2,
    "vision": 2,
    "cargo_capacity": 100
  },
  "combat": {
    "can_attack": false,
    "can_capture": false,
    "armor_classes": ["civilian"]
  },
  "movement_type": "foot",
  "maintenance": { "food": 2 },
  "abilities": [
    {
      "ability_id": "found_city",
      "params": {
        "settlement_type": "encampment",
        "city_name_prefix": "New "
      }
    }
  ],
  "visual": {
    "sprite": "res://assets/units/settler.svg",
    "color": "#2E8B57"
  }
}
```

## Fields

### `category` (string, required)

| Value | Description |
|-------|-------------|
| `"civil"` | Non-combat unit (settlers, caravans, explorers) |
| `"military"` | Combat unit |

### `trained_at` (Array, required)

List of building IDs where this unit can be trained.

### `milestones_required` (Array, optional)

Milestone IDs that must be unlocked to train this unit.

### `obsoleted_by` (Array, optional)

Milestone IDs that, when ANY is unlocked, prevent this unit from being trained. Existing units are not affected. Default is empty (never obsolete).

### `training` (Object, required)

| Field | Type | Description |
|-------|------|-------------|
| `cost` | Object | Resources required to train. Keys are resource IDs |
| `turns` | int | Number of turns to complete training |

### `stats` (Object, required)

| Field | Type | Description |
|-------|------|-------------|
| `health` | int | Hit points |
| `movement` | int | Movement points per turn (in hexes on flat terrain) |
| `vision` | int | Sight range in hexes |
| `cargo_capacity` | int | Optional. Resource carrying capacity for transport units |

### `combat` (Object, required)

| Field | Type | Description |
|-------|------|-------------|
| `can_attack` | bool | Whether this unit can initiate attacks |
| `can_capture` | bool | Whether this unit can capture cities |
| `armor_classes` | Array[string] | Armor class IDs that define how the unit absorbs damage (see [armor_classes.md](armor_classes.md)) |

### `movement_type` (string, required)

References a movement type ID (see [movement_types.md](movement_types.md)). Determines terrain traversal costs.

### `maintenance` (Object, required)

Resources consumed per turn to keep the unit alive. Keys are resource IDs.

### `abilities` (Array, required)

List of abilities the unit can use. Can be specified in two formats:

**Simple format** - just the ability ID string:
```json
"abilities": ["trade", "transport"]
```

**Parameterized format** - ability with custom parameters:
```json
"abilities": [
  {
    "ability_id": "found_city",
    "params": {
      "settlement_type": "encampment",
      "city_name_prefix": "New "
    }
  }
]
```

See [abilities.md](abilities.md) for ability definitions.

### `visual` (Object, required)

| Field | Type | Description |
|-------|------|-------------|
| `sprite` | string | Path to the unit sprite asset |
| `color` | string | Hex color for UI/map display |

## Examples

### Settler

Civil unit that founds new settlements:

```json
{
  "category": "civil",
  "trained_at": ["city_center", "longhouse", "tribal_camp"],
  "milestones_required": [],
  "training": {
    "cost": { "food": 50, "wood": 20, "tools": 5 },
    "turns": 5
  },
  "stats": { "health": 100, "movement": 2, "vision": 2 },
  "combat": { "can_attack": false, "can_capture": false, "armor_classes": ["civilian"] },
  "movement_type": "foot",
  "maintenance": { "food": 2 },
  "abilities": [
    {
      "ability_id": "found_city",
      "params": { "settlement_type": "encampment", "city_name_prefix": "New " }
    }
  ]
}
```

### Caravan

Transport unit with cargo capacity:

```json
{
  "category": "civil",
  "trained_at": ["city_center", "longhouse", "tribal_camp"],
  "milestones_required": ["pack_animal_domestication"],
  "training": {
    "cost": { "food": 30, "wood": 10 },
    "turns": 4
  },
  "stats": { "health": 80, "movement": 3, "vision": 2, "cargo_capacity": 100 },
  "combat": { "can_attack": false, "can_capture": false, "armor_classes": ["civilian"] },
  "movement_type": "foot",
  "maintenance": { "food": 1 },
  "abilities": ["trade", "transport"]
}
```
