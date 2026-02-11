# Buildings

Buildings are the core of city management. They produce and consume resources, provide storage, generate research, and define the settlement's capabilities. Each building is defined in its own JSON file under `data/buildings/`.

## File Location

```
data/buildings/<building_id>.json
```

## Schema

```json
{
  "category": "production",

  "construction": {
    "initial_cost": { "wood": 12, "tools": 5 },
    "cost_per_turn": {},
    "total_turns": 3
  },

  "requirements": {
    "terrain_types": ["plains", "meadow", "floodplains"],
    "terrain_exclude": ["ocean", "mountain", "lake"],
    "required_modifiers": [],
    "required_adjacent": {
      "building_ids": [],
      "building_categories": [],
      "min_count": 0,
      "max_distance": 1
    },
    "prohibited_adjacent": {
      "building_ids": [],
      "building_categories": [],
      "min_distance": 0
    },
    "requires_city_center_connection": true,
    "milestones_required": ["soil_tillage"]
  },

  "production": {
    "produces": [
      { "resource": "food", "quantity": 8 },
      { "resource": "research", "quantity": 0.25, "branch": "agriculture" }
    ],
    "consumes": [
      { "resource": "population", "quantity": 1 },
      { "resource": "admin_capacity", "quantity": 1.0, "distance_cost": { "multiplier": 0.1, "distance_to": "nearest_source" } }
    ]
  },

  "per_turn_penalty": [
    { "resource": "population", "quantity": 3 }
  ],

  "adjacency_bonuses": [
    {
      "source_type": "terrain",
      "source_id": "river",
      "radius": 1,
      "yields": { "food": 1.5 }
    }
  ],

  "adjacency_decay_bonuses": [
    {
      "source_type": "building",
      "source_id": "smoke_house",
      "radius": 2,
      "requires_active": true,
      "decay_reduction": { "food": -0.15 }
    }
  ],

  "terrain_bonuses": {
    "floodplains": { "food": 3 }
  },

  "modifier_consumption": [],

  "provides": {
    "storage": [
      {
        "capacity": 80,
        "accepted_resources": ["food"],
        "accepted_tags": ["population"],
        "decay_reduction": { "food": 0.35 }
      }
    ],
    "building_capacity": 1,
    "caravan_capacity": 0
  },

  "on_construction_complete": {
    "research": { "agriculture": 2.0 }
  },

  "disabled_admin_cost": 0.0,
  "disabled_consumption": {},
  "demolition_cost": { "wood": 2 },
  "upgrades_from": "cultivated_plot",
  "upgrades_to": null,
  "max_per_city": 0,
  "can_units_stand": false,
  "has_orientation": false,
  "is_city_center": false,
  "settlement_types": [],
  "settlement_tags": [],

  "visual": {
    "sprite": "res://assets/buildings/crop_field.svg",
    "color": "#7CB342"
  }
}
```

## Fields

### `category` (string, required)

Building classification. Affects placement rules and UI grouping.

| Value | Description |
|-------|-------------|
| `"production"` | Produces resources each turn |
| `"housing"` | Provides population storage |
| `"storage"` | Provides resource storage pools |
| `"city_center"` | Settlement center building (one per city) |

### `construction` (Object, required)

| Field | Type | Description |
|-------|------|-------------|
| `initial_cost` | Object | Resources paid upfront to start construction. Keys are resource IDs |
| `cost_per_turn` | Object | Resources consumed each turn during construction |
| `total_turns` | int | Number of turns to complete |

### `requirements` (Object, required)

Defines where the building can be placed.

| Field | Type | Description |
|-------|------|-------------|
| `terrain_types` | Array | Terrain IDs where this building can be placed |
| `terrain_exclude` | Array | Terrain IDs where this building cannot be placed |
| `required_modifiers` | Array | Modifier IDs that must be present on the tile |
| `required_adjacent` | Object | Requires nearby buildings (see below) |
| `prohibited_adjacent` | Object | Cannot be near certain buildings (see below) |
| `requires_city_center_connection` | bool | Must be reachable from the city center |
| `milestones_required` | Array | Milestone IDs that must be unlocked |

**`required_adjacent`:**

| Field | Type | Description |
|-------|------|-------------|
| `building_ids` | Array | Specific building IDs that must be nearby |
| `building_categories` | Array | Building categories that must be nearby |
| `min_count` | int | Minimum number of matching adjacent buildings (0 = no requirement) |
| `max_distance` | int | Maximum hex distance to check for adjacency |

**`prohibited_adjacent`:**

| Field | Type | Description |
|-------|------|-------------|
| `building_ids` | Array | Buildings that cannot be nearby |
| `building_categories` | Array | Categories that cannot be nearby |
| `min_distance` | int | Minimum distance these must be from this building |

### `production` (Object, required)

#### `produces` (Array)

Each entry:

| Field | Type | Description |
|-------|------|-------------|
| `resource` | string | Resource ID produced |
| `quantity` | float | Amount per turn |
| `branch` | string | Optional. If set, the produced resource goes to this specific tech branch |

#### `consumes` (Array)

Each entry:

| Field | Type | Description |
|-------|------|-------------|
| `resource` | string | Resource ID consumed. Can also be a tag (e.g., `"storable"`) |
| `tag` | string | Alternative to `resource`. Consumes from any resource with this tag |
| `quantity` | float | Amount per turn |
| `distance_cost` | Object | Optional. Adds distance-based cost scaling |

**`distance_cost`:**

| Field | Type | Description |
|-------|------|-------------|
| `multiplier` | float | Extra cost per unit of distance |
| `distance_to` | string | `"nearest_source"` or `"city_center"` |

### `per_turn_penalty` (Array, optional)

Resources consumed unconditionally each turn, even if the building is disabled. Used for upkeep costs.

Each entry: `{ "resource": "population", "quantity": 3 }`

### `adjacency_bonuses` (Array, optional)

Bonus yields from nearby terrain or buildings.

| Field | Type | Description |
|-------|------|-------------|
| `source_type` | string | `"terrain"` or `"building"` |
| `source_id` | string | Terrain ID or building ID |
| `radius` | int | Hex distance to check |
| `yields` | Object | Bonus resources. Keys are resource IDs |

### `adjacency_decay_bonuses` (Array, optional)

Decay reduction from nearby buildings.

| Field | Type | Description |
|-------|------|-------------|
| `source_type` | string | `"building"` |
| `source_id` | string | Building ID |
| `radius` | int | Hex distance to check |
| `requires_active` | bool | Source building must be active (not disabled) |
| `decay_reduction` | Object | Decay rate changes. Negative values reduce decay |

### `terrain_bonuses` (Object, optional)

Extra yields based on the tile's terrain. Keys are terrain IDs, values are resource yield objects.

```json
{
  "floodplains": { "food": 3 }
}
```

### `provides` (Object, optional)

#### `storage` (Array)

Each pool:

| Field | Type | Description |
|-------|------|-------------|
| `capacity` | float | Total storage capacity for this pool |
| `accepted_resources` | Array | Specific resource IDs this pool stores |
| `accepted_tags` | Array | Resource tags this pool accepts (e.g., `["population"]`) |
| `decay_reduction` | Object | Reduces decay for stored resources. Keys are resource IDs, values are reduction fractions |

A building can have multiple storage pools with different capacities and accepted resources.

#### `building_capacity` (int, optional)

Number of additional buildings this building allows in the city.

#### `caravan_capacity` (int, optional)

Number of caravan units this building can support.

### `on_construction_complete` (Object, optional)

One-time effects when construction finishes.

| Field | Type | Description |
|-------|------|-------------|
| `research` | Object | Research points granted. Keys are branch IDs, values are amounts |

### Other Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `disabled_admin_cost` | float | 0.0 | Admin capacity cost when building is disabled |
| `disabled_consumption` | Object | {} | Resources consumed even when disabled |
| `demolition_cost` | Object | {} | Resources required to demolish |
| `upgrades_from` | string/null | null | Building ID this upgrades from |
| `upgrades_to` | string/null | null | Building ID this can upgrade to |
| `max_per_city` | int | 0 | Maximum instances per city (0 = unlimited) |
| `can_units_stand` | bool | false | Whether units can occupy this tile |
| `has_orientation` | bool | false | Whether the building has a directional facing |
| `is_city_center` | bool | false | Whether this is a city center building |
| `settlement_types` | Array | [] | Restrict to specific settlement type IDs |
| `settlement_tags` | Array | [] | Restrict to settlements with specific tags |

## Examples

### Production Building (Crop Field)

Produces food, consumes workers and admin capacity, gets bonuses near water:

```json
{
  "category": "production",
  "construction": {
    "initial_cost": { "wood": 12, "tools": 5 },
    "cost_per_turn": {},
    "total_turns": 3
  },
  "requirements": {
    "terrain_types": ["plains", "meadow", "floodplains", "grassland"],
    "terrain_exclude": ["ocean", "mountain", "lake", "forest"],
    "milestones_required": ["soil_tillage"]
  },
  "production": {
    "produces": [
      { "resource": "food", "quantity": 8 },
      { "resource": "research", "quantity": 0.25, "branch": "agriculture" }
    ],
    "consumes": [
      { "resource": "population", "quantity": 1 },
      { "resource": "tools", "quantity": 1 },
      { "resource": "admin_capacity", "quantity": 1.0, "distance_cost": { "multiplier": 0.1, "distance_to": "nearest_source" } }
    ]
  },
  "adjacency_bonuses": [
    { "source_type": "terrain", "source_id": "river", "radius": 1, "yields": { "food": 1.5 } }
  ],
  "upgrades_from": "cultivated_plot"
}
```

### Storage Building (Granary)

Stores food with decay reduction:

```json
{
  "category": "storage",
  "construction": {
    "initial_cost": { "wood": 15, "stone": 8 },
    "total_turns": 3
  },
  "requirements": {
    "milestones_required": ["seed_selection"]
  },
  "provides": {
    "storage": [
      {
        "capacity": 80,
        "accepted_resources": ["food"],
        "decay_reduction": { "food": 0.35 }
      }
    ]
  }
}
```

### City Center (Tribal Camp)

Produces admin capacity, stores multiple resource types, limits to one per city:

```json
{
  "category": "city_center",
  "production": {
    "produces": [{ "resource": "admin_capacity", "quantity": 50.0 }],
    "consumes": [{ "resource": "food", "quantity": 2 }]
  },
  "provides": {
    "storage": [
      { "capacity": 10, "accepted_tags": ["population"] },
      { "capacity": 20, "accepted_resources": ["food"] },
      { "capacity": 25, "accepted_resources": ["wood", "stone", "tools"] }
    ],
    "building_capacity": 1
  },
  "max_per_city": 1,
  "is_city_center": true,
  "can_units_stand": true
}
```
