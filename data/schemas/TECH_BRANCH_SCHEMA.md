# Tech Branch Schema

Defines technology branches that can be researched.

## Structure

```json
{
  "branch_id": {
    "name": "string",
    "description": "string",
    "color": "#RRGGBB",
    "icon": "path/to/icon.png",
    "requires": [
      {
        "branch": "branch_id",
        "level": float
      }
    ]
  }
}
```

## Field Descriptions

- **branch_id**: Unique identifier (e.g., "Agriculture", "Warfare")
- **name**: Display name
- **description**: What this branch represents
- **color**: UI color for this branch
- **icon**: Icon for UI display
- **requires**: Other branches that must reach certain levels before this unlocks
  - **branch**: ID of required branch
  - **level**: Research points needed in that branch

## Notes

- Research progress is a **float** (not integer levels)
- Players assign generic research points to branches
- Some buildings produce branch-specific research automatically
- Branches unlock independently when requirements are met

## Examples

```json
{
  "Agriculture": {
    "name": "Agriculture",
    "description": "The science of cultivating plants and livestock for sustenance",
    "color": "#4CAF50",
    "icon": "res://assets/icons/tech/agriculture.png",
    "requires": []
  },
  
  "Construction": {
    "name": "Construction",
    "description": "Building techniques and architectural knowledge",
    "color": "#795548",
    "icon": "res://assets/icons/tech/construction.png",
    "requires": []
  },
  
  "Mining": {
    "name": "Mining",
    "description": "Extraction of minerals and resources from the earth",
    "color": "#9E9E9E",
    "icon": "res://assets/icons/tech/mining.png",
    "requires": [
      {
        "branch": "Construction",
        "level": 5.0
      }
    ]
  },
  
  "Metallurgy": {
    "name": "Metallurgy",
    "description": "The art of working with metals",
    "color": "#FF5722",
    "icon": "res://assets/icons/tech/metallurgy.png",
    "requires": [
      {
        "branch": "Mining",
        "level": 3.0
      }
    ]
  },
  
  "Administration": {
    "name": "Administration",
    "description": "Organizational systems for managing complex societies",
    "color": "#9C27B0",
    "icon": "res://assets/icons/tech/administration.png",
    "requires": []
  },
  
  "Warfare": {
    "name": "Warfare",
    "description": "Military tactics and weapon development",
    "color": "#F44336",
    "icon": "res://assets/icons/tech/warfare.png",
    "requires": []
  },
  
  "Philosophy": {
    "name": "Philosophy",
    "description": "Systematic study of fundamental questions",
    "color": "#2196F3",
    "icon": "res://assets/icons/tech/philosophy.png",
    "requires": [
      {
        "branch": "Administration",
        "level": 10.0
      }
    ]
  }
}
```
