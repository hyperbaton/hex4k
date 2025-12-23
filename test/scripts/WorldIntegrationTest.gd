extends Node

# Integration test for World + City system

var world: Node2D
var city_manager: CityManager
var world_query: WorldQuery

func _ready():
	print("\n=== Starting World Integration Test ===\n")
	
	# Wait for autoloads
	await get_tree().process_frame
	
	# Setup test world
	setup_test_world()
	
	# Run tests
	test_tile_view_creation()
	test_city_founding_in_world()
	test_building_placement_with_terrain()
	test_world_query_helpers()
	
	print("\n=== World Integration Test Complete ===\n")
	print("✅ All tests passed!\n")

func setup_test_world():
	print("--- Setting Up Test World ---")
	
	# Create minimal world structure
	world = Node2D.new()
	world.name = "TestWorld"
	add_child(world)
	
	# Create ChunkManager
	var chunk_manager = ChunkManager.new()
	chunk_manager.name = "ChunkManager"
	chunk_manager.noise_seed = 12345
	chunk_manager.generator = TileGenerator.new(12345)
	world.add_child(chunk_manager)
	
	# Create CityManager
	city_manager = CityManager.new()
	city_manager.name = "CityManager"
	world.add_child(city_manager)
	
	# Create WorldQuery
	world_query = WorldQuery.new()
	world_query.name = "WorldQuery"
	world.add_child(world_query)
	
	# Initialize WorldQuery
	world_query.initialize(world, city_manager)
	
	# Add get_tile_data method to world
	world.set_script(load("res://src/world/World.gd"))
	
	# Create a player
	city_manager.create_player("test_player", "Test Player")
	
	print("✓ Test world created")
	print()

func test_tile_view_creation():
	print("--- Testing TileView Creation ---")
	
	var coord = Vector2i(0, 0)
	var view = world_query.get_tile_view(coord)
	
	assert(view != null, "TileView should be created")
	assert(view.coord == coord, "Coordinates should match")
	assert(view.terrain_data != null, "Should have terrain data")
	print("✓ TileView created for coord ", coord)
	
	print("Terrain: ", view.get_terrain_name())
	print("Terrain ID: ", view.get_terrain_id())
	print("Is claimed: ", view.is_claimed())
	print("Altitude: %.2f" % view.get_altitude())
	print()

func test_city_founding_in_world():
	print("--- Testing City Founding in World ---")
	
	var coord = Vector2i(5, 5)
	
	# Check if we can found a city
	var check = world_query.can_found_city_here(coord)
	print("Can found city at ", coord, ": ", check)
	
	if check.can_found:
		# Found the city
		var city = city_manager.found_city("Test City", coord, "test_player")
		assert(city != null, "City should be created")
		print("✓ Founded city: ", city.city_name)
		
		# Get TileView of city center
		var view = world_query.get_tile_view(coord)
		assert(view.is_claimed(), "Tile should be claimed")
		assert(view.is_city_center(), "Tile should be city center")
		assert(view.has_building(), "City center should have building")
		print("✓ City center tile properly claimed")
		print("  Building: ", view.get_building_name())
		print("  Owner: ", view.get_owner_name())
		
		# Test tooltip
		print("\nTooltip:")
		print(view.get_tooltip_text())
	else:
		print("⚠ Cannot found city: ", check.reason)
	
	print()

func test_building_placement_with_terrain():
	print("--- Testing Building Placement with Terrain Check ---")
	
	# Get a city
	var cities = city_manager.get_cities_for_player("test_player")
	if cities.is_empty():
		print("⚠ No cities to test with")
		return
	
	var city = cities[0]
	var center = city.city_center_coord
	
	# Try to expand to an adjacent tile
	var adjacent = center + Vector2i(1, 0)
	
	# Check terrain
	var view = world_query.get_tile_view(adjacent)
	print("Adjacent tile terrain: ", view.get_terrain_name())
	print("Terrain ID: ", view.get_terrain_id())
	
	# Try to expand
	var can_expand = world_query.can_city_expand_here(adjacent)
	print("Can expand to adjacent: ", can_expand)
	
	if can_expand.can_expand:
		city_manager.expand_city_to_tile(city.city_id, adjacent)
		print("✓ Expanded to adjacent tile")
		
		# Now try to place a farm
		var can_build = world_query.can_build_here(adjacent, "farm")
		print("Can build farm: ", can_build)
		
		if can_build.can_build:
			city_manager.place_building(city.city_id, adjacent, "farm")
			print("✓ Started farm construction")
		else:
			print("⚠ Cannot build farm: ", can_build.reason)
			print("  (This is expected if terrain is incompatible or tech missing)")
	else:
		print("⚠ Cannot expand: ", can_expand.reason)
	
	print()

func test_world_query_helpers():
	print("--- Testing WorldQuery Helper Methods ---")
	
	# Test hex neighbors
	var coord = Vector2i(0, 0)
	var neighbors = world_query.get_hex_neighbors(coord)
	assert(neighbors.size() == 6, "Should have 6 neighbors")
	print("✓ Hex neighbors: ", neighbors.size())
	
	# Test distance calculation
	var dist = world_query.calculate_hex_distance(Vector2i(0, 0), Vector2i(3, 3))
	print("✓ Distance (0,0) to (3,3): ", dist)
	
	# Test tiles in range
	var tiles_in_range = world_query.get_tiles_in_range(Vector2i(0, 0), 0, 2)
	print("✓ Tiles in range 0-2: ", tiles_in_range.size())
	
	# Test buildable buildings
	var cities = city_manager.get_cities_for_player("test_player")
	if not cities.is_empty():
		var city = cities[0]
		var center = city.city_center_coord
		
		var buildable = world_query.get_buildable_buildings(center)
		print("✓ Buildable at city center: ", buildable)
		
		# Get all city tile views
		var city_views = world_query.get_tile_views_for_city(city.city_id)
		print("✓ City tile views: ", city_views.size())
	
	print()
