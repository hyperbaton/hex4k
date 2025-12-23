# Terrain Type Schema

Defines the properties of terrain types that tiles can have.

## Structure

```json
{
  "terrain_id": {
    "name": "string",
    "description": "string",
    "movement_cost": float,
    "base_yields": {
      "resource_id": float
    },
    "allows_building_categories": ["category"],
    "prohibits_building_categories": ["category"],
    "allows_units": ["unit_category"],
    "prohibits_units": ["unit_category"],
    "generation": {
      "altitude_min": float,
      "altitude_max": float,
      "humidity_min": float,
      "humidity_max": float,
      "temperature_min": float,
      "temperature_max": float
    },
    "milestones_required": ["milestone_id"],
    "visual": {
      "color": "#RRGGBB",
      "sprite": "path/to/sprite.png"
    }
  }
}
```

## Field Descriptions

- **terrain_id**: Unique identifier (e.g., "grassland", "mountain")
- **name**: Display name shown to player
- **description**: Flavor text about the terrain
- **movement_cost**: How many movement points to enter (1.0 = normal)
- **base_yields**: Resources produced by empty tiles of this terrain per turn
- **allows_building_categories**: Which building categories can be placed here
- **prohibits_building_categories**: Which building categories cannot be placed here
- **allows_units**: Which unit categories can enter this terrain
- **prohibits_units**: Which unit categories cannot enter this terrain
- **generation**: Procedural generation parameters (all values 0.0 to 1.0)
- **milestones_required**: Tech milestones needed to access/use this terrain
- **visual**: Rendering information

## Example

```json
{
  "grassland": {
    "name": "Grassland",
    "description": "Flat, fertile plains ideal for agriculture",
    "movement_cost": 1.0,
    "base_yields": {
      "food": 2.0
    },
    "allows_building_categories": ["housing", "production", "civic"],
    "prohibits_building_categories": ["naval"],
    "allows_units": ["land", "civilian"],
    "prohibits_units": ["naval"],
    "generation": {
      "altitude_min": 0.35,
      "altitude_max": 0.70,
      "humidity_min": 0.40,
      "humidity_max": 0.85,
      "temperature_min": 0.30,
      "temperature_max": 0.80
    },
    "milestones_required": [],
    "visual": {
      "color": "#4CAF50",
      "sprite": "res://assets/terrains/grassland.png"
    }
  }
}
```
