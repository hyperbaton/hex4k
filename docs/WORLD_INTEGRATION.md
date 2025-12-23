# World Integration Documentation

## Overview

The world integration connects the terrain/chunk system with the city/gameplay system through two key components:
- **TileView** - Unified read-only view of a tile
- **WorldQuery** - Bridge between World and CityManager

## Architecture

```
World (Node2D)
├── ChunkManager (terrain data)
├── CityManager (gameplay data)
└── WorldQuery (bridge)
    └── Creates TileView objects
```

## TileView Class

A **read-only** unified view combining terrain and gameplay data.

### Creation

```gdscript
var view = world_query.get_tile_view(Vector2i(5, 5))
```

### Terrain Information

```gdscript
view.get_terrain_id()      # "grassland"
view.get_terrain_name()    # "Grassland" (localized)
view.get_altitude()        # 0.45
view.get_humidity()        # 0.6
view.is_river()            # false
view.get_terrain_color()   # Color from registry
```

### Ownership Information

```gdscript
view.is_claimed()          # true if part of a city
view.get_city_name()       # "Rome"
view.get_owner_name()      # "Player 1"
view.is_city_center()      # false
view.get_distance_from_center()  # 3
view.is_frontier()         # true if at city edge
```

### Building Information

```gdscript
view.has_building()        # true if building present
view.get_building_id()     # "farm"
view.get_building_name()   # "Farm" (localized)
view.get_building_category()  # "production"
view.can_units_stand()     # true/false
```

### Production Information

```gdscript
view.get_production()      # {"food": 4.0}
view.get_consumption()     # {"population": 1.0}
view.get_net_production("food")  # 3.0 (prod - cons)
```

### Display Helpers

```gdscript
# Summary for UI
var summary = view.get_display_summary()
# {
#   coord: Vector2i(5, 5),
#   terrain: "Grassland",
#   is_claimed: true,
#   city_name: "Rome",
#   building: "Farm",
#   ...
# }

# Tooltip text
var tooltip = view.get_tooltip_text()
print(tooltip)
# Tile (5, 5)
# Terrain: Grassland
# City: Rome
# Owner: Player 1
# Distance: 3 from center
# 
# Building: Farm
# Produces:
#   +4.0 Food
# Consumes:
#   -1.0 Population
```

### Multiplayer Support

```gdscript
# Filter what's visible to a specific player
var visible = view.get_visible_to_player("player1")
# Shows all details for own tiles
# Shows limited info for enemy tiles
```

## WorldQuery Class

Bridge between terrain and gameplay systems.

### Setup

```gdscript
# In World._ready()
world_query.initialize(self, city_manager)
```

### Getting TileViews

```gdscript
# Single tile
var view = world_query.get_tile_view(Vector2i(5, 5))

# Area of tiles
var views = world_query.get_tile_views_in_area(center, radius)

# All tiles in a city
var city_views = world_query.get_tile_views_for_city(city_id)

# Visible tiles for a player (multiplayer)
var player_views = world_query.get_visible_tiles_for_player(player_id)
```

### Building Placement Queries

```gdscript
# Check if can build
var check = world_query.can_build_here(coord, "farm")
if check.can_build:
    # Place building
    city_manager.place_building(city_id, coord, "farm")
else:
    print("Cannot build: ", check.reason)

# Get all buildable buildings at location
var buildable = world_query.get_buildable_buildings(coord)
for building_id in buildable:
    print("Can build: ", building_id)
```

### City Expansion Queries

```gdscript
# Check if can expand
var check = world_query.can_city_expand_here(coord)
if check.can_expand:
    city_manager.expand_city_to_tile(check.city_id, coord)
else:
    print("Cannot expand: ", check.reason)

# Find adjacent cities
var adjacent = world_query.get_adjacent_cities(coord)
```

### City Founding Queries

```gdscript
# Check specific location
var check = world_query.can_found_city_here(coord)
if check.can_found:
    city_manager.found_city("New City", coord, player_id)

# Find suitable locations in area
var suitable = world_query.get_suitable_city_locations(center, radius)
for coord in suitable:
    print("Can found city at: ", coord)
```

### Hex Utilities

```gdscript
# Get neighbors
var neighbors = world_query.get_hex_neighbors(coord)  # 6 adjacent tiles

# Calculate distance
var dist = world_query.calculate_hex_distance(a, b)

# Get ring of tiles
var ring = world_query.get_tiles_in_range(center, min_range, max_range)
```

### Terrain Access

```gdscript
# Get raw terrain data
var terrain_data = world_query.get_terrain_data(coord)

# Get terrain ID
var terrain_id = world_query.get_terrain_id(coord)
```

## Integration with Existing Systems

### World Class

```gdscript
extends Node2D

@onready var city_manager := $CityManager
@onready var world_query := $WorldQuery
@onready var chunk_manager := $ChunkManager

func _ready():
    world_query.initialize(self, city_manager)

# Provide terrain data access
func get_tile_data(coord: Vector2i) -> HexTileData:
    return chunk_manager.get_tile_data(coord)
```

### ChunkManager Updates

Added methods:
```gdscript
func get_tile_data(coord: Vector2i) -> HexTileData:
    # Returns terrain data for a coordinate
    
func get_tile_at_coords(q: int, r: int) -> HexTile:
    # Returns visual HexTile node
```

### UI Integration

```gdscript
# TileInfoPanel now supports TileView
func show_tile_view(view: TileView):
    title_label.text = "Tile Information"
    coords_label.text = "Coordinates: (%d, %d)" % [view.coord.x, view.coord.y]
    # ... show all info from view
```

## Usage Examples

### Example 1: Tile Selection

```gdscript
# When player clicks a tile
func _on_tile_clicked(coord: Vector2i):
    var view = world_query.get_tile_view(coord)
    
    if not view:
        return
    
    # Show in UI
    tile_info_panel.show_tile_view(view)
    
    # Highlight tile
    if view.is_claimed():
        print("This tile belongs to: ", view.get_city_name())
```

### Example 2: Building Menu

```gdscript
# Show buildings that can be placed
func show_building_menu(coord: Vector2i):
    var buildable = world_query.get_buildable_buildings(coord)
    
    building_menu.clear()
    for building_id in buildable:
        var name = Registry.get_name("building", building_id)
        building_menu.add_item(name, building_id)
```

### Example 3: City Overview

```gdscript
# Display all tiles in a city
func show_city_overview(city_id: String):
    var views = world_query.get_tile_views_for_city(city_id)
    
    for view in views:
        var item = TileListItem.new()
        item.coord = view.coord
        item.terrain = view.get_terrain_name()
        item.building = view.get_building_name()
        
        city_list.add_child(item)
```

### Example 4: Expansion Highlights

```gdscript
# Show tiles where city can expand
func highlight_expansion_options(city: City):
    for coord in city.frontier_tiles:
        var neighbors = world_query.get_hex_neighbors(coord)
        
        for neighbor in neighbors:
            var check = world_query.can_city_expand_here(neighbor)
            
            if check.can_expand:
                highlight_tile(neighbor, Color.GREEN)
```

### Example 5: Multiplayer Visibility

```gdscript
# Send only visible info to client
func send_visible_world(player_id: String):
    var visible_views = world_query.get_visible_tiles_for_player(player_id)
    
    for view in visible_views:
        var data = view.get_visible_to_player(player_id)
        send_to_client(player_id, data)
```

## Benefits of This Design

### ✅ Clean Separation
- Terrain system independent of gameplay
- City system independent of rendering
- Clear boundaries between concerns

### ✅ Memory Efficient
- TileViews created on-demand (not stored)
- Only claimed tiles have CityTile objects
- Terrain data loaded/unloaded with chunks

### ✅ Easy to Use
- Single object (TileView) for all tile info
- No manual synchronization needed
- Consistent API across codebase

### ✅ Multiplayer Ready
- Built-in visibility filtering
- Easy to hide enemy information
- Supports fog of war

### ✅ Moddable
- Terrain mods don't affect cities
- City mods don't affect world gen
- Clear extension points

## Testing

Run `test/scenes/WorldIntegrationTest.tscn` to verify:
- TileView creation
- City founding in world
- Building placement with terrain checks
- WorldQuery helper methods

## Common Patterns

### Pattern: Check Before Action

```gdscript
# Always check before modifying
var check = world_query.can_build_here(coord, building_id)
if check.can_build:
    city_manager.place_building(city_id, coord, building_id)
else:
    show_error(check.reason)
```

### Pattern: Display Current State

```gdscript
# Use TileView for read-only display
var view = world_query.get_tile_view(coord)
label.text = view.get_tooltip_text()
```

### Pattern: Iterate City Tiles

```gdscript
# Get all tiles at once
var views = world_query.get_tile_views_for_city(city_id)
for view in views:
    process_tile(view)
```

## Performance Considerations

- **TileViews are lightweight** - Create freely, don't store
- **WorldQuery caches nothing** - Always queries fresh data
- **Chunk loading is lazy** - Only loads when accessed
- **Use batch queries** - `get_tile_views_in_area()` is more efficient than individual calls

## Future Enhancements

- [ ] Pathfinding integration
- [ ] Unit vision/fog of war
- [ ] Tile improvements (roads, farms on same tile)
- [ ] Dynamic terrain changes (erosion, flooding)
- [ ] Border visualization
- [ ] Territory influence maps
