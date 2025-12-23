# Modifier Schema

Defines tile modifiers that affect gameplay.

## Structure

```json
{
  "modifier_id": {
    "name": "string",
    "description": "string",
    "type": "resource_deposit|terrain_transform|yield_bonus|permanent|temporary",
    "duration": int,
    "effects": {
      "yields": {
        "resource_id": float
      },
      "terrain_transform": "terrain_id",
      "provides_resource": "resource_id",
      "movement_cost_modifier": float,
      "building_cost_modifier": float
    },
    "conditions": {
      "terrain_types": ["terrain_id"],
      "altitude_min": float,
      "altitude_max": float,
      "requires_modifiers": ["modifier_id"],
      "prohibits_modifiers": ["modifier_id"]
    },
    "generation": {
      "spawn_chance": float,
      "altitude_min": float,
      "altitude_max": float,
      "humidity_min": float,
      "humidity_max": float,
      "temperature_min": float,
      "temperature_max": float,
      "terrain_types": ["terrain_id"]
    },
    "visual": {
      "icon": "path/to/icon.png",
      "overlay_color": "#RRGGBBAA",
      "overlay_sprite": "path/to/overlay.png"
    },
    "milestones_required": ["milestone_id"]
  }
}
```

## Field Descriptions

- **modifier_id**: Unique identifier (e.g., "copper_deposit", "fertile_soil")
- **name**: Display name
- **description**: What this modifier does
- **type**: Classification for behavior
  - `resource_deposit`: Provides extractable resources
  - `terrain_transform`: Changes terrain type
  - `yield_bonus`: Adds to tile yields
  - `permanent`: Never expires
  - `temporary`: Expires after duration
- **duration**: Turns before expiring (-1 = permanent)
- **effects**: What this modifier does
  - **yields**: Bonus resources per turn (stacks with terrain/building yields)
  - **terrain_transform**: Changes tile terrain to specified type
  - **provides_resource**: Resource available for extraction (e.g., copper, oil)
  - **movement_cost_modifier**: Added to terrain movement cost
  - **building_cost_modifier**: Multiplier for building costs on this tile
- **conditions**: Where/how this modifier can exist
  - **terrain_types**: Can only exist on these terrains
  - **altitude_min/max**: Procedural generation bounds
  - **requires_modifiers**: Needs these modifiers present
  - **prohibits_modifiers**: Cannot coexist with these modifiers
- **generation**: Procedural generation parameters
  - **spawn_chance**: Probability during world gen (0.0-1.0)
  - **altitude/humidity/temperature**: Generation bounds
  - **terrain_types**: Only spawn on these terrains
- **visual**: How to display this modifier
- **milestones_required**: Tech needed to see/use this modifier

## Notes

- Modifiers stack additively
- Some modifiers conflict via `prohibits_modifiers`
- No limit on modifiers per tile
- Temporary modifiers can be added during gameplay (events, buildings, etc.)

## Examples

```json
{
  "copper_deposit": {
    "name": "Copper Deposit",
    "description": "Rich veins of copper ore",
    "type": "resource_deposit",
    "duration": -1,
    "effects": {
      "yields": {
        "production": 1.0
      },
      "terrain_transform": "",
      "provides_resource": "copper",
      "movement_cost_modifier": 0.0,
      "building_cost_modifier": 1.0
    },
    "conditions": {
      "terrain_types": ["hills", "mountain"],
      "altitude_min": 0.6,
      "altitude_max": 1.0,
      "requires_modifiers": [],
      "prohibits_modifiers": ["iron_deposit", "gold_deposit"]
    },
    "generation": {
      "spawn_chance": 0.08,
      "altitude_min": 0.6,
      "altitude_max": 1.0,
      "humidity_min": 0.0,
      "humidity_max": 1.0,
      "temperature_min": 0.0,
      "temperature_max": 1.0,
      "terrain_types": ["hills", "mountain"]
    },
    "visual": {
      "icon": "res://assets/icons/modifiers/copper.png",
      "overlay_color": "#FF6F00AA",
      "overlay_sprite": "res://assets/overlays/copper_deposit.png"
    },
    "milestones_required": ["Mining_1"]
  },

  "fertile_soil": {
    "name": "Fertile Soil",
    "description": "Exceptionally rich earth perfect for farming",
    "type": "yield_bonus",
    "duration": -1,
    "effects": {
      "yields": {
        "food": 2.0
      },
      "terrain_transform": "",
      "provides_resource": "",
      "movement_cost_modifier": 0.0,
      "building_cost_modifier": 1.0
    },
    "conditions": {
      "terrain_types": ["grassland", "plains"],
      "altitude_min": 0.3,
      "altitude_max": 0.7,
      "requires_modifiers": [],
      "prohibits_modifiers": []
    },
    "generation": {
      "spawn_chance": 0.05,
      "altitude_min": 0.3,
      "altitude_max": 0.7,
      "humidity_min": 0.5,
      "humidity_max": 1.0,
      "temperature_min": 0.3,
      "temperature_max": 0.8,
      "terrain_types": ["grassland", "plains"]
    },
    "visual": {
      "icon": "res://assets/icons/modifiers/fertile.png",
      "overlay_color": "#4CAF5066",
      "overlay_sprite": ""
    },
    "milestones_required": []
  },

  "volcanic_activity": {
    "name": "Volcanic Activity",
    "description": "Geological forces transform this mountain into a volcano",
    "type": "terrain_transform",
    "duration": -1,
    "effects": {
      "yields": {
        "production": 2.0
      },
      "terrain_transform": "volcano",
      "provides_resource": "",
      "movement_cost_modifier": 1.0,
      "building_cost_modifier": 1.5
    },
    "conditions": {
      "terrain_types": ["mountain"],
      "altitude_min": 0.85,
      "altitude_max": 1.0,
      "requires_modifiers": [],
      "prohibits_modifiers": []
    },
    "generation": {
      "spawn_chance": 0.02,
      "altitude_min": 0.9,
      "altitude_max": 1.0,
      "humidity_min": 0.0,
      "humidity_max": 1.0,
      "temperature_min": 0.0,
      "temperature_max": 1.0,
      "terrain_types": ["mountain"]
    },
    "visual": {
      "icon": "res://assets/icons/modifiers/volcano.png",
      "overlay_color": "#FF5722FF",
      "overlay_sprite": "res://assets/overlays/volcano.png"
    },
    "milestones_required": []
  },

  "flood_fertility": {
    "name": "Flood Enrichment",
    "description": "Recent flooding has enriched the soil",
    "type": "temporary",
    "duration": 20,
    "effects": {
      "yields": {
        "food": 1.0
      },
      "terrain_transform": "",
      "provides_resource": "",
      "movement_cost_modifier": 0.0,
      "building_cost_modifier": 1.0
    },
    "conditions": {
      "terrain_types": ["grassland", "plains"],
      "altitude_min": 0.0,
      "altitude_max": 0.5,
      "requires_modifiers": [],
      "prohibits_modifiers": []
    },
    "generation": {
      "spawn_chance": 0.0,
      "altitude_min": 0.0,
      "altitude_max": 0.0,
      "humidity_min": 0.0,
      "humidity_max": 0.0,
      "temperature_min": 0.0,
      "temperature_max": 0.0,
      "terrain_types": []
    },
    "visual": {
      "icon": "res://assets/icons/modifiers/flood_fertile.png",
      "overlay_color": "#2196F344",
      "overlay_sprite": ""
    },
    "milestones_required": []
  },

  "oil_deposit": {
    "name": "Oil Deposit",
    "description": "Ancient organic matter compressed into petroleum",
    "type": "resource_deposit",
    "duration": -1,
    "effects": {
      "yields": {},
      "terrain_transform": "",
      "provides_resource": "oil",
      "movement_cost_modifier": 0.0,
      "building_cost_modifier": 1.0
    },
    "conditions": {
      "terrain_types": ["coast", "ocean", "desert"],
      "altitude_min": 0.0,
      "altitude_max": 0.8,
      "requires_modifiers": [],
      "prohibits_modifiers": []
    },
    "generation": {
      "spawn_chance": 0.03,
      "altitude_min": 0.0,
      "altitude_max": 0.8,
      "humidity_min": 0.0,
      "humidity_max": 0.4,
      "temperature_min": 0.0,
      "temperature_max": 1.0,
      "terrain_types": ["coast", "ocean", "desert"]
    },
    "visual": {
      "icon": "res://assets/icons/modifiers/oil.png",
      "overlay_color": "#212121AA",
      "overlay_sprite": "res://assets/overlays/oil_deposit.png"
    },
    "milestones_required": ["Petroleum_1"]
  }
}
```
