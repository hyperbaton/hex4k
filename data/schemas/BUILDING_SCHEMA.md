# Building Schema

Defines buildings that can be constructed on tiles.

## Structure

```json
{
  "building_id": {
	"name": "string",
	"description": "string",
	"category": "housing|production|civic|military|monument|commerce|storage|road|city_center|fortification",
	"allows_units_on_tile": boolean,
	"construction": {
	  "cost": {
		"resource_id": float
	  },
	  "turns": int
	},
	"admin_cost": {
	  "base": float,
	  "distance_multiplier": float
	},
	"requirements": {
	  "terrain_types": ["terrain_id"],
	  "terrain_exclude": ["terrain_id"],
	  "required_modifiers": ["modifier_id"],
	  "prohibited_modifiers": ["modifier_id"],
	  "required_adjacent": {
		"building_ids": ["building_id"],
		"min_count": int,
		"max_distance": int
	  },
	  "prohibited_adjacent": {
		"building_ids": ["building_id"],
		"min_distance": int
	  },
	  "milestones_required": ["milestone_id"]
	},
	"production": {
	  "per_turn": {
		"resource_id": float
	  },
	  "requires": {
		"resource_id": float
	  },
	  "branch_specific": {
		"branch_id": float
	  }
	},
	"adjacency_bonuses": [
	  {
		"source": "terrain|building|modifier",
		"id": "string",
		"yields": {
		  "resource_id": float
		}
	  }
	],
	"provides": {
	  "population_capacity": int,
	  "storage": {
		"resource_id": int
	  },
	  "storage_decay_reduction": {
		"resource_id": float
	  }
	},
	"upgrades_to": "building_id",
	"upgrade_cost": {
	  "resource_id": float,
	  "turns": int
	},
	"visual": {
	  "sprite": "path/to/sprite.png",
	  "color": "#RRGGBB"
	}
  }
}
```

## Field Descriptions

- **building_id**: Unique identifier
- **name**: Display name
- **description**: What this building does
- **category**: Building type for categorization and requirements
- **allows_units_on_tile**: Whether units can stand on this building's tile
- **construction.cost**: Resources needed to build (spent over construction period)
- **construction.turns**: How many turns to build
- **admin_cost.base**: Base administrative cost for this building type
- **admin_cost.distance_multiplier**: Multiplier for distance² formula
  - Final cost = `base * multiplier * (distance_from_city_center² + 1)`
- **requirements**: Conditions to place this building
  - **terrain_types**: Must be on one of these terrains
  - **terrain_exclude**: Cannot be on these terrains
  - **required_modifiers**: Tile must have these modifiers
  - **prohibited_modifiers**: Tile cannot have these modifiers
  - **required_adjacent**: Must have nearby buildings
  - **prohibited_adjacent**: Cannot be near these buildings
  - **milestones_required**: Tech needed to unlock
- **production.per_turn**: Resources produced each turn
- **production.requires**: Resources consumed each turn (building disabled if unavailable)
- **production.branch_specific**: Research points for specific tech branch (automatic)
- **adjacency_bonuses**: Bonus yields from neighboring tiles/buildings
- **provides.population_capacity**: Max population this building can house
- **provides.storage**: Storage capacity added for each resource
- **provides.storage_decay_reduction**: Reduces decay rate for resources (0.0-1.0)
- **upgrades_to**: Building ID this can upgrade to
- **upgrade_cost**: Cost to upgrade (building remains functional during upgrade)
- **visual**: Rendering information

## Examples

```json
{
  "city_center": {
    "name": "City Center",
    "description": "The heart of your civilization",
    "category": "city_center",
    "allows_units_on_tile": false,
    "construction": {
      "cost": {
        "production": 50
      },
      "turns": 1
    },
    "admin_cost": {
      "base": 0.0,
      "distance_multiplier": 0.0
    },
    "requirements": {
      "terrain_types": ["grassland", "plains", "desert"],
      "terrain_exclude": ["ocean", "mountain"],
      "required_modifiers": [],
      "prohibited_modifiers": [],
      "required_adjacent": {},
      "prohibited_adjacent": {},
      "milestones_required": []
    },
    "production": {
      "per_turn": {
        "population": 1.0,
        "admin_capacity": 5.0
      },
      "requires": {},
      "branch_specific": {}
    },
    "adjacency_bonuses": [],
    "provides": {
      "population_capacity": 5,
      "storage": {
        "food": 100,
        "wood": 50
      },
      "storage_decay_reduction": {}
    },
    "upgrades_to": "palace",
    "upgrade_cost": {
      "stone": 100,
      "turns": 10
    },
    "visual": {
      "sprite": "res://assets/buildings/city_center.png",
      "color": "#FFD700"
    }
  },

  "farm": {
    "name": "Farm",
    "description": "Produces food from fertile land",
    "category": "production",
    "allows_units_on_tile": true,
    "construction": {
      "cost": {
        "wood": 20,
        "production": 30
      },
      "turns": 3
    },
    "admin_cost": {
      "base": 1.0,
      "distance_multiplier": 1.0
    },
    "requirements": {
      "terrain_types": ["grassland", "plains"],
      "terrain_exclude": ["mountain", "ocean"],
      "required_modifiers": [],
      "prohibited_modifiers": [],
      "required_adjacent": {},
      "prohibited_adjacent": {},
      "milestones_required": ["Agriculture_1"]
    },
    "production": {
      "per_turn": {
        "food": 3.0
      },
      "requires": {
        "population": 1.0
      },
      "branch_specific": {
        "Agriculture": 0.1
      }
    },
    "adjacency_bonuses": [
      {
        "source": "terrain",
        "id": "grassland",
        "yields": {
          "food": 1.0
        }
      },
      {
        "source": "building",
        "id": "farm",
        "yields": {
          "food": 0.5
        }
      },
      {
        "source": "modifier",
        "id": "fertile_soil",
        "yields": {
          "food": 2.0
        }
      }
    ],
    "provides": {
      "population_capacity": 0,
      "storage": {},
      "storage_decay_reduction": {}
    },
    "upgrades_to": "irrigated_farm",
    "upgrade_cost": {
      "production": 50,
      "turns": 5
    },
    "visual": {
      "sprite": "res://assets/buildings/farm.png",
      "color": "#8BC34A"
    }
  },

  "road": {
    "name": "Road",
    "description": "Enables trade and unit movement",
    "category": "road",
    "allows_units_on_tile": true,
    "construction": {
      "cost": {
        "stone": 10,
        "production": 20
      },
      "turns": 2
    },
    "admin_cost": {
      "base": 0.5,
      "distance_multiplier": 0.5
    },
    "requirements": {
      "terrain_types": ["grassland", "plains", "desert", "forest"],
      "terrain_exclude": ["ocean", "mountain", "hills"],
      "required_modifiers": [],
      "prohibited_modifiers": [],
      "required_adjacent": {},
      "prohibited_adjacent": {},
      "milestones_required": ["Construction_1"]
    },
    "production": {
      "per_turn": {},
      "requires": {},
      "branch_specific": {}
    },
    "adjacency_bonuses": [],
    "provides": {
      "population_capacity": 0,
      "storage": {},
      "storage_decay_reduction": {}
    },
    "upgrades_to": "paved_road",
    "upgrade_cost": {
      "stone": 30,
      "turns": 3
    },
    "visual": {
      "sprite": "res://assets/buildings/road.png",
      "color": "#795548"
    }
  },

  "granary": {
    "name": "Granary",
    "description": "Stores food and reduces spoilage",
    "category": "storage",
    "allows_units_on_tile": false,
    "construction": {
      "cost": {
        "wood": 40,
        "stone": 20,
        "production": 50
      },
      "turns": 5
    },
    "admin_cost": {
      "base": 2.0,
      "distance_multiplier": 1.0
    },
    "requirements": {
      "terrain_types": ["grassland", "plains", "desert"],
      "terrain_exclude": ["ocean", "mountain"],
      "required_modifiers": [],
      "prohibited_modifiers": [],
      "required_adjacent": {
        "building_ids": ["city_center"],
        "min_count": 1,
        "max_distance": 5
      },
      "prohibited_adjacent": {},
      "milestones_required": ["Agriculture_2"]
    },
    "production": {
      "per_turn": {},
      "requires": {
        "population": 0.5
      },
      "branch_specific": {}
    },
    "adjacency_bonuses": [],
    "provides": {
      "population_capacity": 0,
      "storage": {
        "food": 500
      },
      "storage_decay_reduction": {
        "food": 0.5
      }
    },
    "upgrades_to": "cold_storage",
    "upgrade_cost": {
      "stone": 100,
      "turns": 8
    },
    "visual": {
      "sprite": "res://assets/buildings/granary.png",
      "color": "#F57C00"
    }
  }
}
```

## Notes

- Buildings with `category: "city_center"` should be unique per city and immovable
- Roads form networks - pathfinding should find connected road tiles
- Admin cost formula: `base * distance_multiplier * (distance² + 1)`
- Buildings are disabled (not demolished) when admin capacity is insufficient
