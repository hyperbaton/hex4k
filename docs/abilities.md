# Abilities

Abilities define actions that units can perform on the map. They are data-driven and parameterizable, allowing units to share ability definitions with different configurations. Each ability is defined in its own JSON file under `data/abilities/`.

## File Location

```
data/abilities/<ability_id>.json
```

## Schema

```json
{
  "id": "found_city",
  "name": "Found City",
  "description": "Establish a new settlement on this tile",
  "icon": "res://assets/icons/abilities/found_city.svg",
  "category": "civil",

  "conditions": [
    {
      "type": "not_on_city",
      "message": "Cannot found a city on existing city territory"
    },
    {
      "type": "min_distance_from_city",
      "distance": 3,
      "message": "Too close to another city"
    }
  ],

  "costs": {
    "movement": "all",
    "consumes_unit": true,
    "ends_turn": true
  },

  "effects": [
    {
      "type": "found_city",
      "settlement_type": "${settlement_type}",
      "city_name_prefix": "${city_name_prefix}"
    }
  ],

  "targeting": {
    "type": "adjacent",
    "filter": "enemy_unit",
    "range": 1
  },

  "params": {
    "settlement_type": {
      "type": "string",
      "default": "encampment",
      "description": "Settlement type to found"
    }
  }
}
```

## Fields

### `id` (string, required)

Unique ability identifier, should match the filename.

### `name` (string, required)

Display name shown in the UI.

### `description` (string, required)

Tooltip description of what the ability does.

### `icon` (string, optional)

Path to the ability icon asset.

### `category` (string, required)

| Value | Description |
|-------|-------------|
| `"civil"` | Non-combat abilities (founding cities, building) |
| `"military"` | Combat abilities (attacking) |
| `"logistics"` | Transport and trade abilities |

### `conditions` (Array, required)

Checks that must pass before the ability can be used. Each condition:

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | Condition type (see table below) |
| `message` | string | Error message shown when condition fails |
| `distance` | int | Optional. Distance parameter for distance-based conditions |

**Condition types:**

| Type | Description |
|------|-------------|
| `not_on_city` | Tile must not be part of a city |
| `terrain_allows_city` | Terrain must allow city founding |
| `min_distance_from_city` | Must be at least `distance` hexes from any city |
| `has_movement` | Unit must have movement points remaining |
| `not_acted` | Unit must not have acted this turn |
| `adjacent_enemy` | An enemy unit must be in an adjacent hex |
| `on_city` | Unit must be on a city tile |
| `has_cargo_capacity` | Unit must have cargo capacity stat |

### `costs` (Object, required)

| Field | Type | Description |
|-------|------|-------------|
| `movement` | int or `"all"` | Movement points consumed. `"all"` uses all remaining |
| `consumes_unit` | bool | If true, the unit is destroyed after use |
| `ends_turn` | bool | If true, the unit cannot act further this turn |

### `effects` (Array, required)

What happens when the ability is activated. Each effect:

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | Effect type (see table below) |
| ... | | Additional fields depend on the effect type |

**Effect types:**

| Type | Description |
|------|-------------|
| `found_city` | Creates a new settlement. Fields: `settlement_type`, `city_name_prefix` |
| `melee_combat` | Initiates melee combat. Fields: `damage_multiplier`, `bonus_vs` |
| `open_cargo_dialog` | Opens the cargo transfer UI |

Effect fields can use `${param_name}` syntax to reference parameters defined in `params`.

### `targeting` (Object, optional)

For abilities that target other entities:

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | `"adjacent"` for neighboring hexes, `"self"` for current tile |
| `filter` | string | What can be targeted: `"enemy_unit"`, `"ally_unit"`, etc. |
| `range` | int | Maximum hex distance for targeting |

### `params` (Object, optional)

Parameterized values that units can customize when referencing this ability. Each parameter:

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | Data type: `"string"`, `"float"`, `"int"`, `"array"` |
| `default` | varies | Default value if the unit doesn't specify one |
| `description` | string | Description of the parameter |

Units override parameters using the parameterized ability format:
```json
{
  "ability_id": "found_city",
  "params": { "settlement_type": "encampment" }
}
```

## Examples

### Civil Ability (Found City)

```json
{
  "id": "found_city",
  "name": "Found City",
  "description": "Establish a new settlement on this tile",
  "category": "civil",
  "conditions": [
    { "type": "not_on_city", "message": "Cannot found a city on existing city territory" },
    { "type": "terrain_allows_city", "message": "Cannot found a city on this terrain" },
    { "type": "min_distance_from_city", "distance": 3, "message": "Too close to another city" }
  ],
  "costs": { "movement": "all", "consumes_unit": true },
  "effects": [
    { "type": "found_city", "settlement_type": "${settlement_type}", "city_name_prefix": "${city_name_prefix}" }
  ],
  "params": {
    "settlement_type": { "type": "string", "default": "encampment" },
    "city_name_prefix": { "type": "string", "default": "New " }
  }
}
```

### Military Ability (Melee Attack)

```json
{
  "id": "melee_attack",
  "name": "Attack",
  "description": "Engage an adjacent enemy in melee combat",
  "category": "military",
  "conditions": [
    { "type": "has_movement", "message": "No movement remaining" },
    { "type": "not_acted", "message": "Already acted this turn" },
    { "type": "adjacent_enemy", "message": "No adjacent enemy to attack" }
  ],
  "costs": { "movement": "all", "ends_turn": true },
  "effects": [
    { "type": "melee_combat", "damage_multiplier": "${damage_multiplier}", "bonus_vs": "${bonus_vs}" }
  ],
  "targeting": { "type": "adjacent", "filter": "enemy_unit", "range": 1 },
  "params": {
    "damage_multiplier": { "type": "float", "default": 1.0 },
    "bonus_vs": { "type": "array", "default": [] }
  }
}
```

### Logistics Ability (Transport)

```json
{
  "id": "transport",
  "name": "Load / Unload Cargo",
  "description": "Transfer resources between this unit and a city.",
  "category": "logistics",
  "conditions": [
    { "type": "on_city", "message": "Must be on a city tile to load or unload cargo" },
    { "type": "has_cargo_capacity", "message": "This unit cannot carry cargo" }
  ],
  "costs": { "movement": 1, "ends_turn": false },
  "effects": [{ "type": "open_cargo_dialog" }]
}
```
