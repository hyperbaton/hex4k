# Hex4k

A moddable, turn-based civilization-building strategy game built with Godot 4.

## Features

- **Hexagonal Grid System**: Procedurally generated world with chunk-based loading
- **Modular Data System**: All game content defined in JSON files for easy modding
- **Tech Tree**: Multiple research branches with focus branches, milestones, and unlocks
- **Settlements**: Resource management, building placement, upgrades, and city expansion
- **Resource System**: Production, consumption, transportation, and tile modifiers
- **Units**: Unit system with abilities and movement types
- **Dynamic Terrain**: Multiple terrain types with modifiers and resources
- **Turn-Based**: Turn cycle management system

## Project Structure

```
Hex4k/
├── data/               # JSON data files for game content
│   ├── abilities/      # Unit ability definitions
│   ├── buildings/      # Building definitions
│   ├── localization/   # Translation files
│   ├── modifiers/      # Terrain/tile modifier definitions
│   ├── movement_types/ # Movement type definitions
│   ├── perks/          # Civilization perk definitions
│   ├── resources/      # Resource definitions
│   ├── schemas/        # Schema documentation
│   ├── settlements/    # Settlement definitions
│   ├── tech/           # Tech branches and milestones
│   ├── terrains/       # Terrain type definitions
│   ├── tile_types/     # Tile type definitions
│   └── units/          # Unit definitions
├── src/                # GDScript source code
│   ├── config/         # Configuration management
│   ├── core/           # Core game systems
│   ├── model/          # Data models
│   ├── registry/       # Data loading and management
│   ├── tech/           # Technology system
│   ├── ui/             # User interface
│   └── util/           # Utility functions
├── docs/               # Documentation
├── scenes/             # Godot scene files
├── test/               # Integration tests
└── assets/             # Art, fonts, and other assets
```

## Testing

The project includes integration tests to ensure functionality. See [test/README.md](test/README.md) for details.

To run tests:
1. Open a test scene from `test/scenes/`
2. Press F6 to run
3. Check output console for results

## Development Roadmap

### Completed ✅
- [x] Hexagonal grid system with axial coordinates
- [x] Procedural terrain generation with rivers and altitude
- [x] Chunk-based world with save/load
- [x] JSON data loading system
- [x] Registry architecture for game data
- [x] Tile selection and UI
- [x] Technology tree with focus branches and milestones
- [x] Building placement, upgrades, disabling, and demolition
- [x] Resource production, consumption, and transportation
- [x] Settlement system and city management
- [x] City expansion and abandoned cities
- [x] Tile modifiers
- [x] Unit system with abilities
- [x] Turn management system

### In Progress 🚧
- [ ] Combat mechanics
- [ ] Civilization perks

### Planned 📋
- [ ] AI opponents
- [ ] Multiplayer support

## TODO
- Prompt name of save at new game and at load
- Implement dirty flag in chunks to only save modified chunks
- Fix chunk loading radius (convert from rhombus to circular)
- Fix missing chunks in northwest quadrant

## Modding

All game content is defined in JSON files in the `data/` folder. To create a mod:

1. Create new JSON files following the schema
2. Place them in the appropriate `data/` subfolder
3. Reference the new IDs in other data files as needed

See the `docs/` folder for detailed JSON schema documentation for each entity type:

- [Resources](docs/resources.md) - Economy resources (food, wood, research, etc.)
- [Buildings](docs/buildings.md) - City buildings with production, storage, and requirements
- [Terrains](docs/terrains.md) - Base terrain types and world generation
- [Tile Types](docs/tile_types.md) - Visual combinations of terrain + modifiers
- [Modifiers](docs/modifiers.md) - Tile features, resource deposits, yield bonuses
- [Tech Tree](docs/tech.md) - Research branches and milestones
- [Units](docs/units.md) - Mobile entities with stats and abilities
- [Abilities](docs/abilities.md) - Data-driven unit actions
- [Settlements](docs/settlements.md) - Settlement types and evolution
- [Movement Types](docs/movement_types.md) - Terrain traversal costs per unit type
- [Perks](docs/perks.md) - Civilization-wide bonuses
- [Turn Processing](docs/turn_processing.md) - Turn cycle phases and city processing

## License

See [LICENSE](LICENSE) for details.
