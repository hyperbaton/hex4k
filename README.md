# Hex4k

A moddable, turn-based civilization-building strategy game built with Godot 4.

## Features

- **Hexagonal Grid System**: Procedurally generated world with chunk-based loading
- **Modular Data System**: All game content defined in JSON files for easy modding
- **Tech Tree**: Multiple research branches with milestone-based progression
- **City Building**: Resource management, building placement, and administrative capacity
- **Dynamic Terrain**: Multiple terrain types with modifiers and resources

## Project Structure

```
Hex4k/
├── data/               # JSON data files for game content
│   ├── terrains/       # Terrain type definitions
│   ├── resources/      # Resource definitions
│   ├── buildings/      # Building definitions
│   ├── tech/          # Tech branches and milestones
│   ├── units/         # Unit definitions
│   ├── perks/         # Civilization perk definitions
│   └── localization/  # Translation files
├── src/               # GDScript source code
│   ├── core/          # Core game systems
│   ├── registry/      # Data loading and management
│   ├── world/         # World generation and rendering
│   ├── model/         # Data models
│   ├── tech/          # Technology system
│   └── ui/            # User interface
├── scenes/            # Godot scene files
├── test/              # Integration tests
└── assets/            # Art, fonts, and other assets
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
- [x] Procedural terrain generation
- [x] Chunk-based world with save/load
- [x] JSON data loading system
- [x] Registry architecture for game data
- [x] Tile selection and UI
- [x] Technology tree structure

### In Progress 🚧
- [ ] Building placement system
- [ ] Resource production and consumption
- [ ] City management

### Planned 📋
- [ ] Unit system and movement
- [ ] Combat mechanics
- [ ] Caravan routes and trade
- [ ] Civilization perks
- [ ] AI opponents
- [ ] Multiplayer support

## TODO
- ~~Click to show tile info doesn't work~~ ✅ Fixed!
- Prompt name of save at new game and at load
- Implement dirty flag in chunks to only save modified chunks
- Fix chunk loading radius (convert from rhombus to circular)
- Fix missing chunks in northwest quadrant

## Modding

All game content is defined in JSON files in the `data/` folder. To create a mod:

1. Create new JSON files following the schema
2. Place them in the appropriate `data/` subfolder
3. Reference the new IDs in other data files as needed

Detailed modding documentation coming soon!

## License

See [LICENSE](LICENSE) for details.
