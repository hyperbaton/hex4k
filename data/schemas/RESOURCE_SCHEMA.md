# Resource Schema

Defines resources that can be produced, stored, and consumed.

## Structure

```json
{
  "resource_id": {
	"name": "string",
	"description": "string",
	"type": "storable|flow",
	"category": "material|food|abstract|population",
	"storage": {
	  "decay_rate": float,
	  "base_capacity": int
	},
	"visual": {
	  "icon": "path/to/icon.png",
	  "color": "#RRGGBB"
	},
	"milestones_required": ["milestone_id"]
  }
}
```

## Field Descriptions

- **resource_id**: Unique identifier (e.g., "food", "wood", "research_points")
- **name**: Display name
- **description**: What this resource represents
- **type**: 
  - `storable`: Can accumulate (wood, iron, food)
  - `flow`: Per-turn only, doesn't accumulate (admin_capacity, research_points)
- **category**: Broad classification for UI grouping
- **storage.decay_rate**: Percentage lost per turn (0.0 to 1.0). Only for storable resources.
  - 0.0 = no decay
  - 0.05 = 5% loss per turn
- **storage.base_capacity**: Default storage limit per city (storage buildings add to this)
- **visual**: UI rendering info
- **milestones_required**: Tech needed to unlock this resource

## Examples

```json
{
  "food": {
    "name": "Food",
    "description": "Sustains population and enables growth",
    "type": "storable",
    "category": "food",
    "storage": {
      "decay_rate": 0.02,
      "base_capacity": 100
    },
    "visual": {
      "icon": "res://assets/icons/food.png",
      "color": "#FFC107"
    },
    "milestones_required": []
  },
  
  "wood": {
    "name": "Wood",
    "description": "Essential construction material",
    "type": "storable",
    "category": "material",
    "storage": {
      "decay_rate": 0.0,
      "base_capacity": 500
    },
    "visual": {
      "icon": "res://assets/icons/wood.png",
      "color": "#8D6E63"
    },
    "milestones_required": []
  },
  
  "admin_capacity": {
    "name": "Administrative Capacity",
    "description": "Represents organizational efficiency for managing city tiles",
    "type": "flow",
    "category": "abstract",
    "storage": {
      "decay_rate": 0.0,
      "base_capacity": 0
    },
    "visual": {
      "icon": "res://assets/icons/admin.png",
      "color": "#9C27B0"
    },
    "milestones_required": []
  },
  
  "research_points": {
    "name": "Research Points",
    "description": "Generic scientific progress assigned to tech branches",
    "type": "flow",
    "category": "abstract",
    "storage": {
      "decay_rate": 0.0,
      "base_capacity": 0
    },
    "visual": {
      "icon": "res://assets/icons/research.png",
      "color": "#2196F3"
    },
    "milestones_required": []
  },
  
  "population": {
    "name": "Population",
    "description": "Workforce available for buildings",
    "type": "storable",
    "category": "population",
    "storage": {
      "decay_rate": 0.0,
      "base_capacity": 10
    },
    "visual": {
      "icon": "res://assets/icons/population.png",
      "color": "#FF5722"
    },
    "milestones_required": []
  }
}
```
