# City System Documentation

## Overview

The City System manages cities, their tiles, buildings, and resources. It's designed to support multiplayer and AI opponents.

## Architecture

```
CityManager (Node, Global)
├── Players (Dictionary)
│   └── Player (RefCounted)
│       └── Cities (Array)
│           └── City (RefCounted)
│               ├── Tiles (Dictionary)
│               │   └── CityTile (RefCounted)
│               └── ResourceLedger (RefCounted)
```

## Core Classes

### Player
Represents a player (human or AI).

```gdscript
var player = Player.new("player1", "Alice", true)
player.add_perk("maritime_power")
```

### City
Central entity managing tiles, buildings, and resources.

```gdscript
var city = City.new("city1", "New Rome", Vector2i(0, 0))
city.add_tile(Vector2i(1, 0))
city.start_construction(Vector2i(1, 0), "farm")
```

**Key Features:**
- Tracks all tiles and buildings
- Manages resource ledger
- Handles construction queue
- Calculates admin capacity
- Ensures contiguity

### CityTile
Represents a single tile in a city.

```gdscript
var tile = CityTile.new(Vector2i(0, 0))
tile.set_building("farm")
tile.add_resource("food", 100.0)
```

### ResourceLedger
Tracks resources with detailed breakdown.

```gdscript
var ledger = ResourceLedger.new()
ledger.add_production("food", 5.0)
ledger.add_consumption("food", 2.0)
var net = ledger.get_net_change("food")  # 3.0
```

**Breakdown Categories:**
- **Production** - What buildings produce
- **Consumption** - What buildings consume
- **Trade Incoming** - From caravan routes
- **Trade Outgoing** - To caravan routes
- **Decay** - Spoilage/rot

### CityManager
Global manager (should be autoload or added to game scene).

```gdscript
# Access via node reference or make it autoload
var city_mgr = get_node("/root/CityManager")

# Create players
var player = city_mgr.create_player("p1", "Alice")

# Found cities
var city = city_mgr.found_city("New Rome", Vector2i(0, 0), "p1")

# Expand cities
city_mgr.expand_city_to_tile(city.city_id, Vector2i(1, 0))

# Place buildings
city_mgr.place_building(city.city_id, Vector2i(1, 0), "farm")

# Process turns
city_mgr.process_all_cities_turn()
```

## City Founding

Cities can be founded at valid locations:

```gdscript
# Check if location is valid
var check = city_mgr.can_found_city_here(coord)
if check.can_found:
    var city = city_mgr.found_city("City Name", coord, player_id)
```

**Requirements:**
- Tile not already owned
- Minimum distance from other cities (default: 7 tiles)
- Valid terrain (TODO: implement terrain checks)

## City Expansion

Cities expand by claiming adjacent tiles:

```gdscript
# Check if can expand
var check = city_mgr.can_city_expand_to_tile(city_id, new_coord)
if check.can_expand:
    city_mgr.expand_city_to_tile(city_id, new_coord)
```

**Requirements:**
- Tile not owned
- Maintains contiguity
- Sufficient admin capacity

### Administrative Capacity

Buildings cost admin capacity based on distance:
```
admin_cost = base + (distance² × multiplier)
```

Cities need admin-producing buildings (city center, civic buildings) to expand.

## Building System

### Placement

```gdscript
# Check if can place
var check = city.can_place_building(coord, "farm")
if check.can_place:
    city.start_construction(coord, "farm")
```

**Requirements:**
- Tile in city
- No existing building
- Valid terrain
- Tech unlocked
- Sufficient admin capacity

### Construction

Buildings take multiple turns and cost resources per turn:

```gdscript
# Construction happens automatically during city.process_turn()
# Progress tracked in city.construction_queue

# Each turn:
# 1. Check if resources available
# 2. Deduct cost_per_turn
# 3. Decrement turns_remaining
# 4. Complete when turns_remaining == 0
```

### Demolition

```gdscript
city_mgr.demolish_building(city_id, coord)
# - Instantaneous
# - No resource refund
# - Frees admin capacity
```

## Resource Management

### Storage

Resources stored across all storage buildings:

```gdscript
# City calculates total storage automatically
city.recalculate_city_stats()

# Check resource availability
if city.resources.has_resource("food", 100.0):
    # Can afford
    pass
```

### Per-Turn Flows

Resources calculated each turn:

```gdscript
# Get breakdown
var net = city.resources.get_net_change("food")
var internal = city.resources.get_internal_change("food")  # prod - cons
var trade = city.resources.get_trade_change("food")  # in - out

# Display to player
print("Food: %+.1f/turn" % net)
print("  Internal: %+.1f" % internal)
print("  Trade: %+.1f" % trade)
print("  Decay: %.1f" % city.resources.decay.get("food", 0.0))
```

### Decay

Perishable resources decay per turn:

```gdscript
# Calculated automatically in city.calculate_decay()
# Based on:
# - Resource's base_rate_per_turn
# - Storage building decay reduction (TODO)

# Example: Food with 5% decay per turn
var stored = 100.0
var decay = stored * 0.05  # 5.0 per turn
```

## Population System

Population works as a resource with special handling:

```gdscript
# Housing provides storage capacity
city.population_capacity = sum of all housing buildings

# Production buildings produce population (represent workforce availability)
# Consumption represents workforce usage

# Each turn:
population_stored += production - consumption
population_stored = clamp(population_stored, 0, population_capacity)
total_population = int(population_stored)  # Display value
```

## Turn Processing

Cities process turns automatically:

```gdscript
func process_turn():
	1. Process construction (advance projects)
	2. Recalculate city stats (production, capacity, etc.)
	3. Check building consumption (disable if insufficient)
	4. Apply resource changes (production - consumption + trade - decay)
	5. Update population
```

Call from game loop:
```gdscript
func end_turn():
	city_mgr.process_all_cities_turn()
```

## Tile Ownership

CityManager tracks which city owns each tile:

```gdscript
# Check ownership
if city_mgr.is_tile_owned(coord):
	var city = city_mgr.get_city_at_tile(coord)
	print("Tile owned by: ", city.city_name)
```

**Properties:**
- Exclusive (one city per tile)
- Tracked globally
- Updated on expansion/founding/destruction

## Contiguity

Cities must remain contiguous:

```gdscript
# Check if adding tile maintains contiguity
if city.is_contiguous(new_coord):
	# Safe to add
	pass
```

A tile is contiguous if it has at least one adjacent tile in the city.

## Frontier Tiles

Cities track their frontier (edge tiles):

```gdscript
city.update_frontier()
for coord in city.frontier_tiles:
	# These tiles can expand the city
	pass
```

Useful for:
- Showing expansion options
- Border defense
- Visual highlights

## Example: Complete City Lifecycle

```gdscript
# 1. Create player
var player = city_mgr.create_player("p1", "Alice")

# 2. Found city
var city = city_mgr.found_city("Rome", Vector2i(0, 0), "p1", "city_center")

# 3. Wait for admin capacity from city center
city.process_turn()

# 4. Expand to new tile
city_mgr.expand_city_to_tile(city.city_id, Vector2i(1, 0))

# 5. Start building a farm
city_mgr.place_building(city.city_id, Vector2i(1, 0), "farm")

# 6. Process turns until built
for i in range(10):
	city.process_turn()
	if city.construction_queue.is_empty():
		print("Farm completed!")
		break

# 7. Check production
city.recalculate_city_stats()
print("Food production: ", city.resources.production.get("food", 0.0))
```

## Testing

Run `test/scenes/CitySystemTest.tscn` to verify the city system works correctly.

## TODO / Future Enhancements

- [ ] Building states (enabled/disabled based on consumption)
- [ ] Terrain checking for city founding
- [ ] Fresh water requirements
- [ ] Building upgrade system
- [ ] Construction queue UI
- [ ] Trade route integration
- [ ] Building maintenance costs
- [ ] City happiness/unrest
- [ ] Governors (for AI cities)
