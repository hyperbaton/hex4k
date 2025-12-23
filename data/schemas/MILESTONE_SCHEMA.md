# Tech Milestone Schema

Defines specific discoveries/inventions that unlock game content.

## Structure

```json
{
  "milestone_id": {
    "name": "string",
    "description": "string",
    "flavor_text": "string",
    "requirements": [
      {
        "branch": "branch_id",
        "level": float
      }
    ],
    "unlocks": {
      "buildings": ["building_id"],
      "units": ["unit_id"],
      "modifiers": ["modifier_id"],
      "resources": ["resource_id"],
      "perks": ["perk_id"],
      "terrain_types": ["terrain_id"]
    },
    "visibility": {
      "hidden": boolean,
      "show_when": [
        {
          "branch": "branch_id",
          "level": float
        }
      ]
    },
    "visual": {
      "icon": "path/to/icon.png"
    }
  }
}
```

## Field Descriptions

- **milestone_id**: Unique identifier (e.g., "Agriculture_1", "Irrigation")
- **name**: Display name
- **description**: What this milestone represents
- **flavor_text**: Historical/cultural context
- **requirements**: Tech branch levels needed to unlock
  - Can require multiple branches to reach specific levels
  - All requirements must be met
- **unlocks**: Game content enabled by this milestone
- **visibility.hidden**: If true, never shown until unlocked (surprise discovery)
- **visibility.show_when**: Conditions to reveal this milestone in UI before unlocking
- **visual**: UI icon

## Notes

- Milestones are checked against ALL branch requirements
- Buildings/units/etc reference milestones, not branches
- Milestone IDs often use convention: `BranchName_Number` (e.g., "Agriculture_2")
- Research levels are floats, so milestones can be at 2.5, 7.0, 200.0, etc.

## Examples

```json
{
  "Agriculture_1": {
    "name": "Plant Domestication",
    "description": "Understanding how to cultivate wild plants",
    "flavor_text": "The transition from gathering to growing marked humanity's first great leap forward.",
    "requirements": [
      {
        "branch": "Agriculture",
        "level": 2.5
      }
    ],
    "unlocks": {
      "buildings": ["farm"],
      "units": [],
      "modifiers": ["cultivated_soil"],
      "resources": [],
      "perks": [],
      "terrain_types": []
    },
    "visibility": {
      "hidden": false,
      "show_when": [
        {
          "branch": "Agriculture",
          "level": 1.0
        }
      ]
    },
    "visual": {
      "icon": "res://assets/icons/milestones/plant_domestication.png"
    }
  },

  "Agriculture_2": {
    "name": "Irrigation",
    "description": "Techniques for channeling water to crops",
    "flavor_text": "By commanding the flow of water, civilizations could bloom in arid lands.",
    "requirements": [
      {
        "branch": "Agriculture",
        "level": 7.0
      }
    ],
    "unlocks": {
      "buildings": ["irrigated_farm", "aqueduct"],
      "units": [],
      "modifiers": ["irrigated_land"],
      "resources": [],
      "perks": [],
      "terrain_types": []
    },
    "visibility": {
      "hidden": false,
      "show_when": [
        {
          "branch": "Agriculture",
          "level": 5.0
        }
      ]
    },
    "visual": {
      "icon": "res://assets/icons/milestones/irrigation.png"
    }
  },

  "Construction_1": {
    "name": "Mudbrick",
    "description": "Simple sun-dried clay bricks for construction",
    "flavor_text": "The first building blocks of civilization, literally.",
    "requirements": [
      {
        "branch": "Construction",
        "level": 1.0
      }
    ],
    "unlocks": {
      "buildings": ["house", "road"],
      "units": [],
      "modifiers": [],
      "resources": ["brick"],
      "perks": [],
      "terrain_types": []
    },
    "visibility": {
      "hidden": false,
      "show_when": [
        {
          "branch": "Construction",
          "level": 0.5
        }
      ]
    },
    "visual": {
      "icon": "res://assets/icons/milestones/mudbrick.png"
    }
  },

  "Steel": {
    "name": "Steel Production",
    "description": "Advanced metalworking techniques produce superior alloys",
    "flavor_text": "The secret of steel would reshape warfare and industry alike.",
    "requirements": [
      {
        "branch": "Mining",
        "level": 15.0
      },
      {
        "branch": "Metallurgy",
        "level": 20.0
      }
    ],
    "unlocks": {
      "buildings": ["steel_forge"],
      "units": ["steel_swordsman", "steel_armor"],
      "modifiers": [],
      "resources": ["steel"],
      "perks": [],
      "terrain_types": []
    },
    "visibility": {
      "hidden": false,
      "show_when": [
        {
          "branch": "Metallurgy",
          "level": 15.0
        }
      ]
    },
    "visual": {
      "icon": "res://assets/icons/milestones/steel.png"
    }
  },

  "Bureaucracy": {
    "name": "Bureaucratic Systems",
    "description": "Organized administration enables larger, more complex societies",
    "flavor_text": "The pen proved mightier than the sword in managing empires.",
    "requirements": [
      {
        "branch": "Administration",
        "level": 25.0
      }
    ],
    "unlocks": {
      "buildings": ["administrative_complex"],
      "units": [],
      "modifiers": ["efficient_administration"],
      "resources": [],
      "perks": ["organized_state"],
      "terrain_types": []
    },
    "visibility": {
      "hidden": false,
      "show_when": [
        {
          "branch": "Administration",
          "level": 20.0
        }
      ]
    },
    "visual": {
      "icon": "res://assets/icons/milestones/bureaucracy.png"
    }
  },

  "Secret_Discovery": {
    "name": "Ancient Wisdom",
    "description": "???",
    "flavor_text": "Some secrets are meant to be discovered, not taught.",
    "requirements": [
      {
        "branch": "Philosophy",
        "level": 50.0
      },
      {
        "branch": "Administration",
        "level": 30.0
      }
    ],
    "unlocks": {
      "buildings": ["philosopher_academy"],
      "units": [],
      "modifiers": [],
      "resources": [],
      "perks": ["enlightened_society"],
      "terrain_types": []
    },
    "visibility": {
      "hidden": true,
      "show_when": []
    },
    "visual": {
      "icon": "res://assets/icons/milestones/ancient_wisdom.png"
    }
  }
}
```

## Naming Convention

Suggested format: `BranchName_Number` or `DescriptiveName`
- Simple milestones: `Agriculture_1`, `Mining_2`, `Warfare_3`
- Complex/multi-branch: `Steel`, `Gunpowder`, `Bureaucracy`
- Surprises: `Secret_Discovery`, `Hidden_Knowledge`
