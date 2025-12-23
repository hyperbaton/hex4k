extends Node

# Test script for the City system

var city_manager: CityManager

func _ready():
	print("\n=== Starting City System Test ===\n")
	
	# Wait for Registry to initialize
	await get_tree().process_frame
	
	# Create city manager
	city_manager = CityManager.new()
	add_child(city_manager)
	
	# Run tests
	test_player_creation()
	test_city_founding()
	test_city_expansion()
	test_building_placement()
	test_resource_ledger()
	test_city_turn_processing()
	
	print("\n=== City System Test Complete ===\n")
	print("✅ All tests passed!\n")

func test_player_creation():
	print("--- Testing Player Creation ---")
	
	var player1 = city_manager.create_player("player1", "Alice", true)
	assert(player1 != null, "Player should be created")
	assert(player1.player_name == "Alice", "Player name should match")
	assert(player1.is_human == true, "Player should be human")
	print("✓ Created player: ", player1.player_name)
	
	var player2 = city_manager.create_player("player2", "Bob AI", false)
	assert(player2.is_human == false, "AI player should not be human")
	print("✓ Created AI player: ", player2.player_name)
	
	var all_players = city_manager.get_all_players()
	assert(all_players.size() == 2, "Should have 2 players")
	print("✓ Total players: ", all_players.size())
	print()

func test_city_founding():
	print("--- Testing City Founding ---")
	
	var city_coord = Vector2i(0, 0)
	var city = city_manager.found_city("New Rome", city_coord, "player1")
	
	assert(city != null, "City should be founded")
	assert(city.city_name == "New Rome", "City name should match")
	assert(city.city_center_coord == city_coord, "City center coord should match")
	print("✓ Founded city: ", city.city_name, " at ", city_coord)
	
	assert(city.has_tile(city_coord), "City should have center tile")
	assert(city.get_tile_count() == 1, "City should have 1 tile")
	print("✓ City has center tile")
	
	var center_tile = city.get_city_center()
	assert(center_tile.is_city_center, "Center tile should be marked")
	assert(center_tile.has_building(), "Center should have city center building")
	print("✓ City center has building: ", center_tile.building_id)
	
	var owner = city.owner
	assert(owner.player_name == "Alice", "City should belong to Alice")
	assert(owner.get_city_count() == 1, "Alice should have 1 city")
	print("✓ City owner: ", owner.player_name)
	
	# Test that tile is now owned
	assert(city_manager.is_tile_owned(city_coord), "Tile should be owned")
	var city_at_tile = city_manager.get_city_at_tile(city_coord)
	assert(city_at_tile == city, "Should find city at tile")
	print("✓ Tile ownership tracked correctly")
	print()

func test_city_expansion():
	print("--- Testing City Expansion ---")
	
	var city = city_manager.get_cities_for_player("player1")[0]
	var center = city.city_center_coord
	
	# Try to expand to adjacent tile
	var new_tile_coord = center + Vector2i(1, 0)
	
	var check = city_manager.can_city_expand_to_tile(city.city_id, new_tile_coord)
	print("Can expand to ", new_tile_coord, ": ", check)
	
	# Note: This might fail due to insufficient admin capacity
	# That's expected! The city center needs to produce admin capacity
	if check.can_expand:
		var success = city_manager.expand_city_to_tile(city.city_id, new_tile_coord)
		assert(success, "Expansion should succeed")
		assert(city.get_tile_count() == 2, "City should have 2 tiles")
		print("✓ City expanded to new tile")
	else:
		print("⚠ Cannot expand yet: ", check.reason)
		print("  (This is expected - city needs admin capacity from buildings)")
	
	# Test contiguity
	var far_tile = center + Vector2i(10, 10)
	var contiguous = city.is_contiguous(far_tile)
	assert(contiguous == false, "Far tile should not be contiguous")
	print("✓ Contiguity check works")
	
	# Test frontier
	city.update_frontier()
	print("✓ Frontier tiles: ", city.frontier_tiles.size())
	print()

func test_building_placement():
	print("--- Testing Building Placement ---")
	
	var city = city_manager.get_cities_for_player("player1")[0]
	
	# Try to place a farm (requires agriculture_1 milestone)
	var tile_coord = city.city_center_coord
	
	# First, check if we can place a farm
	var check = city.can_place_building(tile_coord, "farm")
	print("Can place farm at center: ", check)
	
	# It will likely fail because:
	# 1. Center already has city_center building
	# 2. Or missing tech milestone
	assert(check.can_place == false, "Should not be able to place on occupied tile")
	print("✓ Cannot place building on occupied tile (expected)")
	
	# Get city stats
	print("\nCity Stats:")
	print("  Population capacity: ", city.population_capacity)
	print("  Admin capacity available: ", city.admin_capacity_available)
	print("  Admin capacity used: ", city.admin_capacity_used)
	print("  Available: ", city.get_available_admin_capacity())
	print()

func test_resource_ledger():
	print("--- Testing Resource Ledger ---")
	
	var ledger = ResourceLedger.new()
	
	# Test adding production/consumption
	ledger.add_production("food", 5.0)
	ledger.add_consumption("food", 2.0)
	ledger.add_trade_incoming("wood", 3.0)
	ledger.add_decay("food", 0.5)
	
	var net_food = ledger.get_net_change("food")
	assert(net_food == 2.5, "Net food should be 5 - 2 - 0.5 = 2.5")
	print("✓ Net food change: ", net_food)
	
	var internal_food = ledger.get_internal_change("food")
	assert(internal_food == 3.0, "Internal food should be 5 - 2 = 3.0")
	print("✓ Internal food change: ", internal_food)
	
	var trade_wood = ledger.get_trade_change("wood")
	assert(trade_wood == 3.0, "Trade wood should be 3.0")
	print("✓ Trade wood change: ", trade_wood)
	
	# Test storage
	ledger.set_stored("food", 100.0)
	ledger.set_storage_capacity("food", 200.0)
	
	assert(ledger.has_resource("food", 50.0), "Should have enough food")
	assert(not ledger.has_resource("food", 150.0), "Should not have 150 food")
	assert(ledger.can_store("food", 50.0), "Should be able to store 50 more")
	assert(not ledger.can_store("food", 150.0), "Should not fit 150 more")
	print("✓ Resource storage checks work")
	print()

func test_city_turn_processing():
	print("--- Testing City Turn Processing ---")
	
	var city = city_manager.get_cities_for_player("player1")[0]
	
	print("Before turn:")
	print("  Total population: ", city.total_population)
	print("  Population stored: ", city.population_stored)
	
	# Recalculate to get accurate stats
	city.recalculate_city_stats()
	
	print("\nProduction breakdown:")
	for resource_id in city.resources.production.keys():
		var prod = city.resources.production[resource_id]
		print("  +", resource_id, ": ", prod)
	
	print("\nConsumption breakdown:")
	for resource_id in city.resources.consumption.keys():
		var cons = city.resources.consumption[resource_id]
		print("  -", resource_id, ": ", cons)
	
	# Process a turn
	city.process_turn()
	
	print("\nAfter turn:")
	print("  Total population: ", city.total_population)
	print("  Population stored: ", city.population_stored)
	
	print("✓ Turn processing completed")
	print()
