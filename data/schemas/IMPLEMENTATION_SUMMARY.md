# Hex4k - JSON Schema Implementation Summary

## Overview
This document summarizes the JSON-based data system implemented for Hex4k. All game content is defined in JSON files, making the game fully moddable.

## Registry System

### Autoload Singletons
- **Registry**: Master registry that loads all data at startup
  - `Registry.resources` - ResourceRegistry
  - `Registry.terrains` - TerrainRegistry
  - `Registry.buildings` - BuildingRegistry
  - `Registry.tech` - TechRegistry
  - `Registry.modifiers` - ModifierRegistry

### Usage Example
```gdscript
# Check if player can build something
if Registry.can_build("farm", "grassland"):
	# Build the farm
	pass

# Get resource info
var decay = Registry.resources.get_decay_rate("food")

# Add research points
Registry.tech.add_research("Agriculture", 5.0)

# Check milestone unlock
if Registry.has_milestone("Agriculture_1"):
	# Enable farms in UI
	pass
```

## Data File Structure

```
data/
├── schemas/                 # Documentation (not loaded by game)
│   ├── TERRAIN_SCHEMA.md
│   ├── RESOURCE_SCHEMA.md
│   ├── BUILDING_SCHEMA.md
│   ├── TECH_BRANCH_SCHEMA.md
│   ├── MILESTONE_SCHEMA.md
│   └── MODIFIER_SCHEMA.md
│
├── terrains.json           # Terrain type definitions
├── resources.json          # Resource definitions
├── buildings.json          # Building definitions
├── modifiers.json          # Tile modifier definitions
│
└── tech/
	├── branches.json       # Tech branch definitions
	└── milestones.json     # Tech milestone definitions
```

## Key Design Principles

### 1. Resources
- **Two types**: `storable` (accumulates) and `flow` (per-turn only)
- **Decay**: Perishable resources lose % per turn
- **Storage**: City-specific, buildings add capacity

### 2. Buildings
- **Admin Cost Formula**: `base * multiplier * (distance² + 1)`
- **Construction**: Spent over multiple turns, can pause
- **Requirements**: Terrain, milestones, adjacency
- **Production**: Per-turn yields and consumption
- **Branch Research**: Auto-generated research for specific branches

### 3. Tech Tree
- **Float Progress**: Branches use decimal research points, not levels
- **Milestones**: Separate entities with arbitrary unlock thresholds
- **Visibility**: Can be hidden or conditionally shown
- **Dependencies**: Downstream (milestones → branches, entities → milestones)

### 4. Modifiers
- **Types**: Resource deposits, terrain transforms, yield bonuses, temporary
- **Stacking**: Additive with conflicts possible
- **Generation**: Procedural spawn during world gen
- **Duration**: Permanent (-1) or temporary (N turns)

### 5. Cities
- **Admin Capacity**: Per-turn flow resource
- **Distance Cost**: Quadratic penalty for sprawl
- **Tile Ownership**: Exclusive per city
- **Expansion**: Build on tile → tile joins city

## Implementation Status

### ✅ Completed
- [x] JSON schema design
- [x] Registry system architecture
- [x] ResourceRegistry + loader
- [x] TerrainRegistry + loader
- [x] BuildingRegistry + loader
- [x] TechRegistry + loader (branches + milestones)
- [x] ModifierRegistry + loader
- [x] Master Registry autoload
- [x] Example data files
- [x] Schema documentation

### 🚧 Next Steps
1. **Integrate with tile generation**
   - Use TerrainRegistry in TileGenerator
   - Apply modifiers during world gen
   
2. **Create City entity**
   - Resource storage per city
   - Building placement system
   - Admin capacity calculation
   
3. **Building placement system**
   - UI for selecting buildings
   - Placement validation
   - Construction queue
   
4. **Tech tree UI**
   - Display branches and progress
   - Assign research points
   - Show unlocked milestones
   
5. **Resource management**
   - Flow calculations per turn
   - Storage and decay
   - Inter-city trade (caravans)

## Modding Instructions

To create a mod:

1. **Copy data directory** to create mod structure
2. **Edit JSON files** with your content
3. **Replace assets** (sprites, icons) referenced in JSON
4. **No code changes needed** - all logic reads from JSON

### Example: Adding a New Building

Create entry in `buildings.json`:
```json
{
  "bakery": {
	"name": "Bakery",
	"description": "Transforms grain into bread",
	"category": "production",
	"construction": {
	  "cost": {"wood": 25, "production": 35},
	  "turns": 3
	},
	"production": {
	  "per_turn": {"food": 5.0},
	  "requires": {"grain": 2.0, "population": 1.0}
	},
	"milestones_required": ["Agriculture_2"]
  }
}
```

Game automatically loads and validates on startup!

## File Naming Conventions

- **IDs**: lowercase_with_underscores (e.g., `city_center`, `fertile_soil`)
- **Milestones**: `BranchName_Number` or descriptive (e.g., `Agriculture_1`, `Steel`)
- **Categories**: lowercase (e.g., `housing`, `production`, `military`)

## Validation

Each registry validates JSON on load:
- File existence checks
- JSON parse error handling
- Type validation
- Reference validation (e.g., milestone IDs exist)

Errors logged to console with helpful messages.

## Performance Notes

- All JSON loaded once at startup
- Stored in memory as dictionaries
- Fast lookup by ID
- No runtime file I/O
- Negligible memory footprint (<1MB for full game data)
