# CLAUDE.md

## Project Overview

Hex4k is a moddable, turn-based civilization-building strategy game built with **Godot 4.5** using **GDScript**. All game content is data-driven via JSON files, making the game highly moddable.

## Architecture

### Autoloads (Global Singletons)

| Singleton | Path | Purpose |
|-----------|------|---------|
| `GameState` | `src/core/GameState.gd` | Game mode (NEW_GAME/LOAD_GAME), save ID, world seed |
| `Registry` | `src/core/Registry.gd` | Master registry holding all loaded game data |

Access registries from anywhere: `Registry.buildings.get_building("farm")`, `Registry.tech.is_milestone_unlocked("masonry")`.

### Key Patterns

- **Registry pattern**: Static game data loaded from JSON at startup. Each entity type has a dedicated registry class under `src/registry/` extending `RefCounted`.
- **Manager pattern**: Runtime state managed by classes like `CityManager`, `UnitManager`, `TurnManager` (also `RefCounted`).
- **Data-driven design**: Buildings, resources, units, tech, modifiers, settlements, abilities, perks — all defined in JSON under `data/`.
- **Tag-based systems**: Resources use tags (`storable`, `flow`, `cap`, `decaying`, `knowledge`, `population`, `tradeable`) for flexible behavior. Settlements and buildings also use tags.
- **Storage pool model**: Buildings have typed storage pools that accept specific resources or resource tags.

### Directory Structure

```
data/               # JSON game content (one file per entity, snake_case IDs)
src/
  core/             # GameState, Registry, TurnManager, CityManager, UnitManager
  registry/         # Data registries (ResourceRegistry, BuildingRegistry, etc.)
  model/            # Runtime data models (City, BuildingInstance, ResourceLedger, Unit)
  config/           # Constants (WorldConfig, CityConfig)
  tech/             # Tech tree UI and logic
  ui/               # UI scenes and scripts
  util/             # Utility functions
docs/               # Entity schema documentation and system guides
scenes/             # Godot .tscn scene files
test/               # Integration tests (scenes + scripts)
assets/             # Art, fonts, icons
```

## Coding Conventions

### Naming

- **Classes**: `PascalCase` with `class_name` declaration (e.g., `class_name BuildingRegistry`)
- **Functions/variables**: `snake_case` (e.g., `load_data()`, `get_building()`)
- **Private methods**: Leading underscore (e.g., `_load_json_file()`, `_index_tags()`)
- **Signals**: `snake_case` with descriptive names (e.g., `signal unit_spawned(unit: Unit)`)
- **Constants**: `UPPER_SNAKE_CASE` in config files (e.g., `HEX_SIZE = 32.0`)
- **JSON file names**: `snake_case` matching the entity ID (e.g., `crop_field.json`)

### Type Hints

Use GDScript type hints everywhere:

```gdscript
var units: Dictionary = {}
var active_buildings: Array[String] = []
func get_building(building_id: String) -> Dictionary:
```

### Signals

```gdscript
signal unit_moved(unit: Unit, from_coord: Vector2i, to_coord: Vector2i)

# Connect with .connect() and .bind() for context
unit.moved.connect(_on_unit_moved.bind(unit))
```

### Documentation

Use triple-quote docstrings:

```gdscript
func get_produces(building_id: String) -> Array:
    """Get the produces array. Each entry: {resource, quantity, [branch]}"""
```

## Data Files

All game content lives in `data/` as individual JSON files. The filename (without `.json`) is the entity ID.

| Directory | Registry | Example |
|-----------|----------|---------|
| `data/resources/` | `ResourceRegistry` | `food.json`, `admin_capacity.json` |
| `data/buildings/` | `BuildingRegistry` | `granary.json`, `crop_field.json` |
| `data/terrains/` | `TerrainRegistry` | `plains.json`, `mountain.json` |
| `data/tile_types/` | `TileTypeRegistry` | `grassland_dense_forest.json` |
| `data/modifiers/` | `ModifierRegistry` | `copper_deposit.json`, `fertile_soil.json` |
| `data/tech/milestones/` | `TechRegistry` | `fermentation.json`, `masonry.json` |
| `data/tech/branches.json` | `TechRegistry` | Single file with all branches |
| `data/units/` | `UnitRegistry` | `settler.json`, `caravan.json` |
| `data/abilities/` | `AbilityRegistry` | `found_city.json`, `melee_attack.json` |
| `data/settlements/` | `SettlementRegistry` | `encampment.json`, `village.json` |
| `data/movement_types/` | `UnitRegistry` | `foot.json` |
| `data/perks/` | `PerkRegistry` | `agricultural_society.json` |
| `data/localization/` | `LocalizationRegistry` | `en.json` |

See `docs/` for detailed JSON schema documentation for each entity type.

## Turn Processing

The `TurnManager` processes cities through 9 phases per turn:

1. **Caps** → 2. **Production** → 3. **Modifier Consumption** → 4. **Consumption** → 5. **Construction** → 6. **Upgrades** → 7. **Training** → 8. **Population** → 9. **Decay**

See `docs/turn_processing.md` for full details.

## Testing

Tests are scene-based under `test/`:

1. Open a test scene from `test/scenes/` (e.g., `RegistryTest.tscn`)
2. Run with F6
3. Check output console — tests use `assert()` and descriptive `print()` output

```gdscript
func test_feature():
    print("--- Testing Feature ---")
    assert(condition, "Error message")
    print("✓ Test passed")
```

## Localization

Single JSON file per language at `data/localization/<lang>.json` (currently only `en.json`). Nested structure: `category → entity_id → { name, description }`.

```gdscript
Registry.localization.get_name("building", "farm")        # "Farm"
Registry.localization.get_description("terrain", "plains") # "Flat, open terrain..."
```

## Common Tasks

### Adding a new resource

1. Create `data/resources/<id>.json` with `tags`, `visual`, and optional `decay`/`cap`/`knowledge` sections
2. Add localization entry in `data/localization/en.json` under `"resource"`
3. Reference in building `production`/`consumes`/`storage` as needed

### Adding a new building

1. Create `data/buildings/<id>.json` with category, construction, requirements, production, and provides sections
2. Add localization entry under `"building"`
3. Ensure required milestones exist in `data/tech/milestones/`

### Adding a new milestone

1. Create `data/tech/milestones/<id>.json` with branch, requirements, and visibility
2. Add localization entry under `"milestone"`
3. Reference in building/unit/resource `milestones_required` arrays

### Adding a new unit

1. Create `data/units/<id>.json` with category, training, stats, combat, movement_type, and abilities
2. Add localization entry under `"unit"`
3. Ensure referenced abilities exist in `data/abilities/`
4. Ensure `trained_at` buildings exist
