# Registry System - Quick Reference

## Overview

The Registry is a global autoload singleton that provides access to all game data loaded from JSON files.

## Accessing Registry

Since Registry is an autoload, you can access it from anywhere without instantiation:

```gdscript
# NO need to do this:
# var registry = Registry.new()  ❌

# Just use it directly:
Registry.terrains.get_terrain("grassland")  ✓
```

## Available Registries

### Terrains
```gdscript
Registry.terrains.get_terrain("grassland")
Registry.terrains.has_terrain("ocean")
Registry.terrains.get_all_terrain_ids()
```

### Resources
```gdscript
Registry.resources.get_resource("food")
Registry.resources.is_storable("food")
Registry.resources.is_flow("admin_capacity")
Registry.resources.get_all_resource_ids()
```

### Buildings
```gdscript
Registry.buildings.get_building("farm")
Registry.buildings.get_admin_cost("farm", distance)
Registry.buildings.can_place_on_terrain("farm", "grassland")
Registry.buildings.get_construction_cost("farm")
Registry.buildings.get_production_per_turn("farm")
Registry.buildings.get_all_building_ids()
```

### Tech Tree
```gdscript
# Branches
Registry.tech.get_branch("agriculture")
Registry.tech.get_branch_progress("agriculture")
Registry.tech.add_research("agriculture", 10.0)
Registry.tech.is_branch_unlocked("mining")

# Milestones
Registry.tech.get_milestone("agriculture_1")
Registry.tech.is_milestone_unlocked("agriculture_1")
Registry.tech.is_milestone_visible("agriculture_2")
Registry.tech.get_unlocked_milestones()
```

### Modifiers
```gdscript
Registry.modifiers.get_modifier("copper_deposit")
Registry.modifiers.has_modifier("fertile_soil")
Registry.modifiers.get_all_modifier_ids()
```

### Units
```gdscript
Registry.units.get_unit("settler")
Registry.units.has_unit("warrior")
Registry.units.get_units_by_category("military")
```

### Perks
```gdscript
Registry.perks.get_perk("maritime_power")
Registry.perks.check_unlock_conditions("agricultural_society", game_state)
```

### Localization
```gdscript
Registry.get_name("terrain", "grassland")  # Returns "Grassland"
Registry.get_description("building", "farm")  # Returns description
```

## Convenience Methods

### Check Requirements
```gdscript
# Check if a milestone is unlocked
if Registry.has_milestone("agriculture_1"):
	print("Can build farms!")

# Check multiple milestones
var required = ["agriculture_1", "construction_1"]
if Registry.has_all_milestones(required):
	print("All requirements met!")

# Check if building can be placed
if Registry.can_build("farm", "grassland"):
	print("Valid placement!")

# Check if modifier can be used
if Registry.can_use_modifier("copper_deposit"):
	print("Milestone unlocked for this modifier!")
```

## Testing

Run `test/scenes/RegistryTest.tscn` to verify all registries are loading correctly.
