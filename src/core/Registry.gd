extends Node

# Master registry that holds all game data
# This is loaded as an autoload singleton

var resources: ResourceRegistry
var terrains: TerrainRegistry
var buildings: BuildingRegistry
var tech: TechRegistry
var modifiers: ModifierRegistry
var units: UnitRegistry
var perks: PerkRegistry
var localization: LocalizationRegistry
var abilities: AbilityRegistry
var tile_types: TileTypeRegistry
var settlements: SettlementRegistry
var armor_classes: ArmorClassRegistry

func _ready():
	print("=== Initializing Game Registries ===")
	
	# Create registry instances (they are RefCounted, not Nodes)
	localization = LocalizationRegistry.new()
	resources = ResourceRegistry.new()
	terrains = TerrainRegistry.new()
	buildings = BuildingRegistry.new()
	tech = TechRegistry.new()
	modifiers = ModifierRegistry.new()
	units = UnitRegistry.new()
	perks = PerkRegistry.new()
	abilities = AbilityRegistry.new()
	tile_types = TileTypeRegistry.new()
	settlements = SettlementRegistry.new()
	armor_classes = ArmorClassRegistry.new()

	# Load all data
	localization.load_data()
	armor_classes.load_data()
	terrains.load_data()
	resources.load_data()
	modifiers.load_data()
	tech.load_data()
	buildings.load_data()
	units.load_data()
	perks.load_data()
	tile_types.load_data()
	settlements.load_data()
	# AbilityRegistry loads in _init()
	
	print("=== Registry Initialization Complete ===")

# Convenience methods for localization

func get_name_label(category: String, id: String) -> String:
	return localization.get_name(category, id)

func get_description(category: String, id: String) -> String:
	return localization.get_description(category, id)

# Convenience methods for checking requirements

func has_milestone(milestone_id: String) -> bool:
	return tech.is_milestone_unlocked(milestone_id)

func has_all_milestones(milestone_ids: Array) -> bool:
	for id in milestone_ids:
		if not tech.is_milestone_unlocked(id):
			return false
	return true

func can_build(building_id: String, terrain_id: String) -> bool:
	if not buildings.building_exists(building_id):
		return false
	
	# Check terrain compatibility
	if not buildings.can_place_on_terrain(building_id, terrain_id):
		return false
	
	# Check tech requirements
	var required_milestones = buildings.get_required_milestones(building_id)
	if not has_all_milestones(required_milestones):
		return false
	
	return true

func can_use_modifier(modifier_id: String) -> bool:
	if not modifiers.modifier_exists(modifier_id):
		return false
	
	var modifier = modifiers.get_modifier(modifier_id)
	var required_milestones = modifier.get("milestones_required", [])
	
	return has_all_milestones(required_milestones)
