# Resource System Refactoring Progress

## Phase 1: Resource Schema + Registry ✅ COMPLETE
- [x] Rewrite 14 resource JSONs to tag-based format
- [x] Rewrite ResourceRegistry.gd with tag-based API
- [x] Create SettlementRegistry.gd
- [x] Create data/settlements/encampment.json
- [x] Add settlements to Registry.gd

## Phase 2: Building Storage Pools ✅ COMPLETE
- [x] Create StoragePool inner class in BuildingInstance.gd
- [x] Rewrite BuildingInstance storage to use pools
- [x] Rewrite all 27 building JSON provides sections
- [x] Update BuildingRegistry.gd to parse new format
- [x] Add backward compatibility wrappers

## Phase 3: Production/Consumption Format ✅ COMPLETE
- [x] Rewrite all 27 building JSON production sections (arrays with objects)
- [x] Merge admin_cost into consumes entries with distance_cost
- [x] Merge branch_specific_research into produces entries with branch
- [x] Update BuildingRegistry.gd parsing
- [x] Update BuildingInstance.gd production/consumption methods

## Phase 4: Generic Cap System + City.gd + TurnManager.gd 🔄 IN PROGRESS
- [x] City.gd: Add settlement_type field
- [x] City.gd: Replace admin_capacity fields with generic cap_state
- [x] City.gd: Derive population from pool queries (remove dedicated fields)
- [x] City.gd: Replace calculate_tile_claim_cost() with settlement-based
- [x] City.gd: Rewrite recalculate_city_stats() → tag-driven
- [x] City.gd: Fix _clear_perishable_resources() (uses old API)
- [x] City.gd: Update can_place_building() for generic caps + settlement type
- [x] City.gd: Add consume_resource_by_tag(), get_resources_by_tag()
- [x] City.gd: Add settlement transition methods
- [x] TurnManager.gd: Rewrite _phase_admin_capacity() → _phase_caps()
- [x] TurnManager.gd: Rewrite _phase_production() for new array format
- [x] TurnManager.gd: Rewrite _phase_consumption() for new array format + tag consumption
- [x] TurnManager.gd: Rewrite _phase_population() → tag-driven
- [x] TurnManager.gd: Merge/rewrite _phase_research() → knowledge tag driven
- [x] TurnManager.gd: Use settlement type for tile costs
- [x] TurnReport.gd: Replace admin_capacity fields → generic cap_reports
- [x] CityConfig.gd: Remove tile cost constants
- [x] CityManager.gd: Use settlement type in founding/expansion

## Phase 5: Knowledge + Population Generalization ✅ (merged into Phase 4)

## Phase 6: Cleanup
- [ ] Remove backward compatibility wrappers in BuildingRegistry.gd
- [ ] Remove backward compatibility wrappers in ResourceRegistry.gd
- [ ] Remove backward compatibility wrappers in BuildingInstance.gd
- [ ] Audit all files for hardcoded resource name strings
- [ ] End-to-end testing
