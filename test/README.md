# Test Suite

This folder contains integration tests for Hex4k. These tests help ensure that new features don't break existing functionality.

## Structure

```
test/
├── scenes/          # Test scenes that can be run in Godot
├── scripts/         # Test scripts
└── README.md        # This file
```

## Running Tests

### Individual Test Scenes

1. Open Godot
2. Navigate to the test scene (e.g., `test/scenes/RegistryTest.tscn`)
3. Press F6 to run the scene
4. Check the Output console for results

### Available Tests

#### RegistryTest.tscn
Tests the data loading system:
- ✓ Terrain loading from JSON
- ✓ Resource loading from JSON
- ✓ Building loading from JSON
- ✓ Tech tree loading (branches & milestones)
- ✓ Localization system
- ✓ Research progress tracking
- ✓ Milestone unlocking

**Expected Output:** All tests should pass with green checkmarks (✓)

## Writing New Tests

When adding new features, create corresponding test scenes:

1. Create a new script in `test/scripts/`
2. Create a scene in `test/scenes/` using that script
3. Use assertions to verify behavior
4. Print clear pass/fail messages
5. Document the test in this README

### Test Template

```gdscript
extends Node

func _ready():
    print("\n=== Starting [Feature] Test ===\n")
    
    # Setup
    var system = YourSystem.new()
    
    # Run tests
    test_feature_1()
    test_feature_2()
    
    print("\n=== Test Complete ===\n")
    print("✅ All tests passed!\n")

func test_feature_1():
    print("--- Testing Feature 1 ---")
    # Your test code
    assert(condition, "Error message")
    print("✓ Test passed")
```

## Best Practices

- **Isolation**: Each test should be independent
- **Clear Output**: Use descriptive print statements
- **Assertions**: Use `assert()` to verify expected behavior
- **Documentation**: Update this README when adding tests
- **Cleanup**: Tests should not leave side effects

## Future Tests

Planned test coverage:
- [ ] City system (resource storage, building placement)
- [ ] Building construction (turn-based, cost calculation)
- [ ] Resource production & consumption
- [ ] Adjacency bonus calculation
- [ ] Administrative capacity calculation
- [ ] Caravan routing
- [ ] Save/Load system
- [ ] Modifier stacking
- [ ] Tech tree visibility conditions
- [ ] Civilization perk unlocking
