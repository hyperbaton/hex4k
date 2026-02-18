# Settlements

Settlements define the types of cities that can be founded and how they evolve. They control initial setup, tile costs, expansion limits, and transitions to more advanced settlement types. Each settlement type is defined in its own JSON file under `data/settlements/`.

## File Location

```
data/settlements/<settlement_id>.json
```

## Schema

```json
{
  "tags": ["rural"],

  "tile_costs": [
	{
	  "resource": "admin_capacity",
	  "base_cost": 0.5,
	  "distance_multiplier": 0.1,
	  "distance_exponent": 1,
	  "distance_to": "city_center",
	  "exempt_center": true
	}
  ],

  "tile_limits": {
	"max_tiles": 0,
	"expansion_allowed": true
  },

  "founding": {
	"founded_by": "settler",
	"initial_buildings": ["longhouse"],
	"initial_tiles": 1,
	"initial_resources": {
	  "food": 15,
	  "wood": 10,
	  "stone": 5
	}
  },

  "transitions": [
	{
	  "target": "village",
	  "trigger": "building_upgrade",
	  "trigger_building": "longhouse",
	  "target_building": "tribal_camp"
	}
  ],

  "bonuses": {},

  "visual": {
	"map_icon": "",
	"color": "#A0522D",
	"label_prefix": ""
  },

  "milestones_required": []
}
```

## Fields

### `tags` (Array, optional)

Classification tags for the settlement. Buildings can use `settlement_tags` to restrict placement to settlements with specific tags.

### `tile_costs` (Array, required)

Defines the per-tile resource cost for owning tiles. Each entry:

| Field | Type | Description |
|-------|------|-------------|
| `resource` | string | Resource ID consumed per tile |
| `base_cost` | float | Base cost per tile |
| `distance_multiplier` | float | Additional cost per unit of distance |
| `distance_exponent` | int | How distance scales the cost (1 = linear, 2 = quadratic) |
| `distance_to` | string | What distance is measured from: `"city_center"` |
| `exempt_center` | bool | If true, the city center tile is free |
| `exempt_within` | int | Optional. Tiles within this distance are free |

**Cost formula:**
```
cost = base_cost + distance_multiplier * distance^distance_exponent
```

### `tile_limits` (Object, required)

| Field | Type | Description |
|-------|------|-------------|
| `max_tiles` | int | Maximum tiles the settlement can own (0 = unlimited) |
| `expansion_allowed` | bool | Whether the settlement can expand at all |

### `founding` (Object, required)

What happens when this settlement is created.

| Field | Type | Description |
|-------|------|-------------|
| `founded_by` | string | Unit ID that founds this settlement type |
| `initial_buildings` | Array | Building IDs placed automatically on founding |
| `initial_tiles` | int | Number of tiles claimed on founding |
| `initial_resources` | Object | Resources granted at founding. Keys are resource IDs |

### `transitions` (Array, optional)

Rules for evolving into a more advanced settlement type.

Each transition:

| Field | Type | Description |
|-------|------|-------------|
| `target` | string | Settlement type ID to transition to |
| `trigger` | string | What triggers the transition: `"building_upgrade"` |
| `trigger_building` | string | Building ID that must be upgraded |
| `target_building` | string | Building ID it must be upgraded to |

### `bonuses` (Object, optional)

Settlement-level stat modifiers (currently unused, reserved for future).

### `visual` (Object, optional)

| Field | Type | Description |
|-------|------|-------------|
| `map_icon` | string | Path to map icon (empty = use default) |
| `color` | string | Hex color for map display |
| `label_prefix` | string | Prefix added to city name display |

### `milestones_required` (Array, optional)

Milestone IDs required to found this settlement type.

## Example

### Encampment

The basic starting settlement, founded by settlers:

```json
{
  "tags": ["rural"],
  "tile_costs": [
	{
	  "resource": "admin_capacity",
	  "base_cost": 0.5,
	  "distance_multiplier": 0.1,
	  "distance_exponent": 1,
	  "distance_to": "city_center",
	  "exempt_center": true
	}
  ],
  "tile_limits": {
	"max_tiles": 0,
	"expansion_allowed": true
  },
  "founding": {
	"founded_by": "settler",
	"initial_buildings": ["longhouse"],
	"initial_tiles": 1,
	"initial_resources": {
	  "food": 15,
	  "wood": 10,
	  "stone": 5
	}
  },
  "transitions": [
	{
	  "target": "village",
	  "trigger": "building_upgrade",
	  "trigger_building": "longhouse",
	  "target_building": "tribal_camp"
	}
  ],
  "bonuses": {},
  "visual": {
	"map_icon": "",
	"color": "#A0522D",
	"label_prefix": ""
  },
  "milestones_required": []
}
```

## Notes

- The settler unit references the settlement type in its `found_city` ability params: `"settlement_type": "encampment"`.
- Settlement transitions happen automatically when the trigger condition is met (e.g., upgrading a longhouse to a tribal camp evolves an encampment into a village).
- Buildings can be restricted to specific settlement types via `settlement_types` or `settlement_tags` in the building JSON.
