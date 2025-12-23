extends Node

# Integration test to verify all registry loading works correctly
# Uses the global Registry autoload singleton

func _ready():
	print("\n=== Starting Registry Load Test ===\n")
	
	# Wait one frame for Registry autoload to initialize
	await get_tree().process_frame
	
	# Run tests
	print("\n=== Testing Data Access ===\n")
	test_terrain()
	test_resources()
	test_buildings()
	test_tech()
	
	print("\n=== Registry Load Test Complete ===\n")
	print("✅ All tests passed!\n")

func test_terrain():
	print("--- Testing Terrain Registry ---")
	var grassland = Registry.terrains.get_terrain("grassland")
	assert(grassland.size() > 0, "Grassland data should exist")
	print("✓ Grassland data: ", grassland)
	
	var name = Registry.get_name_label("terrain", "grassland")
	assert(name == "Grassland", "Grassland localization should work")
	print("✓ Grassland name: ", name)
	
	var all_terrains = Registry.terrains.get_all_terrain_ids()
	print("✓ Total terrains loaded: ", all_terrains.size())
	print()

func test_resources():
	print("--- Testing Resource Registry ---")
	var food = Registry.resources.get_resource("food")
	assert(food.size() > 0, "Food data should exist")
	print("✓ Food data: ", food)
	
	var name = Registry.get_name_label("resource", "food")
	assert(name == "Food", "Food localization should work")
	print("✓ Food name: ", name)
	
	var is_storable = Registry.resources.is_storable("food")
	assert(is_storable == true, "Food should be storable")
	print("✓ Food is storable: ", is_storable)
	
	var all_resources = Registry.resources.get_all_resource_ids()
	print("✓ Total resources loaded: ", all_resources.size())
	print()

func test_buildings():
	print("--- Testing Building Registry ---")
	var farm = Registry.buildings.get_building("farm")
	assert(farm.size() > 0, "Farm data should exist")
	print("✓ Farm data exists")
	
	var name = Registry.get_name_label("building", "farm")
	assert(name == "Farm", "Farm localization should work")
	print("✓ Farm name: ", name)
	
	var admin_cost = Registry.buildings.get_admin_cost("farm", 3)
	print("✓ Farm admin cost at distance 3: ", admin_cost)
	
	var can_build = Registry.can_build("farm", "grassland")
	print("✓ Can build farm on grassland: ", can_build, " (may be false if milestone not unlocked)")
	
	var all_buildings = Registry.buildings.get_all_building_ids()
	print("✓ Total buildings loaded: ", all_buildings.size())
	print()

func test_tech():
	print("--- Testing Tech Registry ---")
	var agriculture = Registry.tech.get_branch("agriculture")
	assert(agriculture.size() > 0, "Agriculture branch should exist")
	print("✓ Agriculture branch data exists")
	
	var name = Registry.get_name_label("tech_branch", "agriculture")
	assert(name == "Agriculture", "Agriculture localization should work")
	print("✓ Agriculture name: ", name)
	
	var milestone = Registry.tech.get_milestone("agriculture_1")
	assert(milestone.size() > 0, "Milestone agriculture_1 should exist")
	print("✓ Milestone agriculture_1 exists")
	
	# Test research system
	print("\n--- Testing Research System ---")
	var initial_progress = Registry.tech.get_branch_progress("agriculture")
	assert(initial_progress == 0.0, "Initial progress should be 0")
	print("✓ Initial Agriculture progress: ", initial_progress)
	
	Registry.tech.add_research("agriculture", 3.0)
	var new_progress = Registry.tech.get_branch_progress("agriculture")
	assert(new_progress == 3.0, "Progress should be 3.0 after adding")
	print("✓ After adding 3.0 research: ", new_progress)
	
	var unlocked = Registry.tech.get_unlocked_milestones()
	print("✓ Unlocked milestones: ", unlocked)
	
	var all_branches = Registry.tech.get_all_branch_ids()
	print("✓ Total tech branches loaded: ", all_branches.size())
	print()
