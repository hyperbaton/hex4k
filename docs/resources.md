# Resources

Resources are the economy foundation of Hex4k. Each resource is defined in its own JSON file under `data/resources/`.

## File Location

```
data/resources/<resource_id>.json
```

The filename (without `.json`) becomes the resource ID used to reference it elsewhere (e.g., in building production, unit costs).

## Schema

```json
{
  "tags": ["storable", "decaying", "tradeable"],
  "decay": {
    "rate_per_turn": 0.05
  },
  "cap": {
    "mode": "soft",
    "penalties": [
      {
        "type": "production_penalty",
        "curve": "quadratic"
      }
    ]
  },
  "knowledge": {
    "accepted_by_branches": ["all"]
  },
  "visual": {
    "icon": "res://assets/icons/food.svg",
    "color": "#E8B830"
  },
  "milestones_required": []
}
```

## Fields

### `tags` (Array, required)

Defines the resource's behavior. A resource can have multiple tags.

| Tag | Description |
|-----|-------------|
| `storable` | Can be accumulated in building storage pools across turns |
| `flow` | Per-turn only; not stored between turns |
| `cap` | Acts as a capacity limiter (e.g., admin capacity). Requires the `cap` object |
| `decaying` | Loses a percentage per turn. Requires the `decay` object |
| `tradeable` | Can be transported by caravan units |
| `population` | Treated as population by the city system |
| `knowledge` | Research-type resource that feeds into tech branches. Requires the `knowledge` object |

### `decay` (Object, optional)

Only relevant if `tags` includes `"decaying"`.

| Field | Type | Description |
|-------|------|-------------|
| `rate_per_turn` | float | Fraction of stored amount lost each turn (0.05 = 5%) |

### `cap` (Object, optional)

Only relevant if `tags` includes `"cap"`.

| Field | Type | Description |
|-------|------|-------------|
| `mode` | string | `"soft"` (penalties when exceeded) or `"hard"` (cannot exceed) |
| `penalties` | Array | List of penalty effects when the cap is exceeded |

Each penalty entry:

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | Penalty type, e.g. `"production_penalty"` |
| `curve` | string | How the penalty scales, e.g. `"quadratic"` |

### `knowledge` (Object, optional)

Only relevant if `tags` includes `"knowledge"`.

| Field | Type | Description |
|-------|------|-------------|
| `accepted_by_branches` | Array | Tech branch IDs this resource feeds into, or `["all"]` for all branches |

### `visual` (Object, optional)

| Field | Type | Description |
|-------|------|-------------|
| `icon` | string | Path to the icon asset |
| `color` | string | Hex color for UI display |

### `milestones_required` (Array, optional)

List of milestone IDs that must be unlocked before this resource appears in the game. Empty array means always available.

## Examples

### Storable, Perishable Resource (Food)

```json
{
  "tags": ["storable", "decaying", "tradeable"],
  "decay": {
    "rate_per_turn": 0.05
  },
  "visual": {
    "icon": "res://assets/icons/food.svg",
    "color": "#E8B830"
  },
  "milestones_required": []
}
```

### Flow/Knowledge Resource (Research)

```json
{
  "tags": ["flow", "knowledge"],
  "knowledge": {
    "accepted_by_branches": ["all"]
  },
  "visual": {
    "icon": "res://assets/icons/research.svg",
    "color": "#4A90E2"
  },
  "milestones_required": []
}
```

### Cap Resource (Admin Capacity)

```json
{
  "tags": ["cap"],
  "cap": {
    "mode": "soft",
    "penalties": [
      {
        "type": "production_penalty",
        "curve": "quadratic"
      }
    ]
  },
  "visual": {
    "icon": "res://assets/icons/admin_capacity.svg",
    "color": "#9B30FF"
  },
  "milestones_required": []
}
```

### Population Resource

```json
{
  "tags": ["storable", "population"],
  "visual": {
    "icon": "res://assets/icons/population.svg",
    "color": "#FFD700"
  },
  "milestones_required": []
}
```

## How Resources are Used

- **Buildings** produce and consume resources (see [buildings.md](buildings.md))
- **Storage pools** in buildings define where storable resources are kept
- **Decay** is reduced by certain buildings (e.g., granary reduces food decay)
- **Cap resources** like admin_capacity limit city expansion and building placement
- **Knowledge resources** feed into the tech tree to unlock milestones
- **Population** is stored in housing buildings and consumed by production buildings as workforce
