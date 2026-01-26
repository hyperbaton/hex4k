extends RefCounted
class_name TurnReport

# Stores the results of processing a turn for all cities

var turn_number: int = 0
var city_reports: Dictionary = {}  # city_id -> CityTurnReport
var global_events: Array[Dictionary] = []
var critical_alerts: Array[Dictionary] = []
var milestones_unlocked: Array[String] = []

func add_city_report(city_id: String, report: CityTurnReport):
	city_reports[city_id] = report

func get_city_report(city_id: String) -> CityTurnReport:
	return city_reports.get(city_id)

func add_global_event(event_type: String, data: Dictionary = {}):
	global_events.append({
		"type": event_type,
		"data": data
	})

func add_critical_alert(alert_type: String, city_id: String, message: String, data: Dictionary = {}):
	critical_alerts.append({
		"type": alert_type,
		"city_id": city_id,
		"message": message,
		"data": data
	})

func add_milestone_unlocked(milestone_id: String):
	milestones_unlocked.append(milestone_id)
	add_global_event("milestone_unlocked", {"milestone_id": milestone_id})
	add_critical_alert("milestone", "", "Milestone Unlocked: " + Registry.tech.get_milestone_name(milestone_id), {"milestone_id": milestone_id})

func has_critical_alerts() -> bool:
	return not critical_alerts.is_empty()

func get_summary() -> String:
	"""Get a brief text summary of the turn"""
	var lines: Array[String] = []
	lines.append("=== Turn %d Summary ===" % turn_number)
	
	if not milestones_unlocked.is_empty():
		lines.append("Milestones Unlocked: %d" % milestones_unlocked.size())
	
	for city_id in city_reports.keys():
		var report = city_reports[city_id]
		lines.append("\n[%s]" % city_id)
		lines.append(report.get_summary())
	
	if not critical_alerts.is_empty():
		lines.append("\n!!! Critical Alerts: %d !!!" % critical_alerts.size())
		for alert in critical_alerts:
			lines.append("  - %s" % alert.message)
	
	return "\n".join(lines)


class CityTurnReport extends RefCounted:
	"""Report for a single city's turn processing"""
	
	var city_id: String
	var city_name: String
	
	# Admin capacity
	var admin_capacity_used: float = 0.0
	var admin_capacity_available: float = 0.0
	var admin_ratio: float = 0.0
	var production_efficiency: float = 1.0
	
	# Production summary
	var production: Dictionary = {}  # resource_id -> amount produced
	var production_after_efficiency: Dictionary = {}  # After admin malus
	var spillage: Dictionary = {}  # resource_id -> amount spilled
	
	# Consumption summary
	var consumption: Dictionary = {}  # resource_id -> amount consumed
	var penalties_applied: Dictionary = {}  # resource_id -> amount from penalties
	
	# Building status changes
	var buildings_activated: Array[Dictionary] = []  # [{coord, building_id}]
	var buildings_waiting: Array[Dictionary] = []  # [{coord, building_id, missing_resources}]
	var buildings_penalized: Array[Dictionary] = []  # [{coord, building_id, penalty}]
	
	# Construction
	var constructions_progressed: Array[Dictionary] = []  # [{coord, building_id, turns_remaining}]
	var constructions_completed: Array[Dictionary] = []  # [{coord, building_id}]
	var constructions_paused: Array[Dictionary] = []  # [{coord, building_id, missing_resources}]
	var completion_rewards: Dictionary = {}  # resource_id -> amount from building completion
	var completion_research_rewards: Dictionary = {}  # branch_id -> points from building completion
	
	# Decay
	var decay_summary: Dictionary = {}  # resource_id -> total decayed
	
	# Research
	var research_generated: Dictionary = {}  # branch_id -> points
	
	# Population
	var population_change: float = 0.0
	var population_total: int = 0
	var population_capacity: int = 0
	
	# Resource totals (end of turn)
	var resource_totals: Dictionary = {}  # resource_id -> amount stored
	
	func _init(id: String, name: String):
		city_id = id
		city_name = name
	
	func add_production(resource_id: String, amount: float, after_efficiency: float):
		production[resource_id] = production.get(resource_id, 0.0) + amount
		production_after_efficiency[resource_id] = production_after_efficiency.get(resource_id, 0.0) + after_efficiency
	
	func add_spillage(resource_id: String, amount: float):
		spillage[resource_id] = spillage.get(resource_id, 0.0) + amount
	
	func add_consumption(resource_id: String, amount: float):
		consumption[resource_id] = consumption.get(resource_id, 0.0) + amount
	
	func add_penalty(resource_id: String, amount: float):
		penalties_applied[resource_id] = penalties_applied.get(resource_id, 0.0) + amount
	
	func add_building_activated(coord: Vector2i, building_id: String):
		buildings_activated.append({"coord": coord, "building_id": building_id})
	
	func add_building_waiting(coord: Vector2i, building_id: String, missing: Dictionary):
		buildings_waiting.append({"coord": coord, "building_id": building_id, "missing_resources": missing})
	
	func add_building_penalized(coord: Vector2i, building_id: String, penalty: Dictionary):
		buildings_penalized.append({"coord": coord, "building_id": building_id, "penalty": penalty})
	
	func add_construction_progressed(coord: Vector2i, building_id: String, turns_left: int):
		constructions_progressed.append({"coord": coord, "building_id": building_id, "turns_remaining": turns_left})
	
	func add_construction_completed(coord: Vector2i, building_id: String):
		constructions_completed.append({"coord": coord, "building_id": building_id})
	
	func add_construction_paused(coord: Vector2i, building_id: String, missing: Dictionary):
		constructions_paused.append({"coord": coord, "building_id": building_id, "missing_resources": missing})
	
	func add_completion_reward(resource_id: String, amount: float):
		"""Track resources granted when a building completes construction"""
		completion_rewards[resource_id] = completion_rewards.get(resource_id, 0.0) + amount
	
	func add_completion_research_reward(branch_id: String, points: float):
		"""Track research granted when a building completes construction"""
		completion_research_rewards[branch_id] = completion_research_rewards.get(branch_id, 0.0) + points
	
	func add_decay(resource_id: String, amount: float):
		decay_summary[resource_id] = decay_summary.get(resource_id, 0.0) + amount
	
	func add_research(branch_id: String, points: float):
		research_generated[branch_id] = research_generated.get(branch_id, 0.0) + points
	
	func get_summary() -> String:
		var lines: Array[String] = []
		
		# Admin efficiency
		if admin_ratio > 1.0:
			lines.append("  Admin Overload: %.0f%% efficiency" % (production_efficiency * 100))
		
		# Production
		if not production_after_efficiency.is_empty():
			var prod_parts: Array[String] = []
			for res_id in production_after_efficiency.keys():
				prod_parts.append("%s: +%.1f" % [res_id, production_after_efficiency[res_id]])
			lines.append("  Produced: " + ", ".join(prod_parts))
		
		# Consumption
		if not consumption.is_empty():
			var cons_parts: Array[String] = []
			for res_id in consumption.keys():
				cons_parts.append("%s: -%.1f" % [res_id, consumption[res_id]])
			lines.append("  Consumed: " + ", ".join(cons_parts))
		
		# Penalties
		if not penalties_applied.is_empty():
			var penalty_parts: Array[String] = []
			for res_id in penalties_applied.keys():
				penalty_parts.append("%s: -%.1f" % [res_id, penalties_applied[res_id]])
			lines.append("  Penalties: " + ", ".join(penalty_parts))
		
		# Spillage
		if not spillage.is_empty():
			var spill_parts: Array[String] = []
			for res_id in spillage.keys():
				spill_parts.append("%s: %.1f" % [res_id, spillage[res_id]])
			lines.append("  Spillage: " + ", ".join(spill_parts))
		
		# Buildings
		if not constructions_completed.is_empty():
			lines.append("  Completed: %d buildings" % constructions_completed.size())
		
		# Completion rewards
		if not completion_rewards.is_empty():
			var reward_parts: Array[String] = []
			for res_id in completion_rewards.keys():
				reward_parts.append("%s: +%.1f" % [res_id, completion_rewards[res_id]])
			lines.append("  Completion rewards: " + ", ".join(reward_parts))
		
		if not completion_research_rewards.is_empty():
			var research_parts: Array[String] = []
			for branch_id in completion_research_rewards.keys():
				research_parts.append("%s: +%.2f" % [branch_id, completion_research_rewards[branch_id]])
			lines.append("  Completion research: " + ", ".join(research_parts))
		
		if not buildings_waiting.is_empty():
			lines.append("  Waiting for resources: %d buildings" % buildings_waiting.size())
		
		if not constructions_paused.is_empty():
			lines.append("  Construction paused: %d buildings" % constructions_paused.size())
		
		# Research
		if not research_generated.is_empty():
			var research_parts: Array[String] = []
			for branch_id in research_generated.keys():
				research_parts.append("%s: +%.2f" % [branch_id, research_generated[branch_id]])
			lines.append("  Research: " + ", ".join(research_parts))
		
		# Population
		if population_change != 0:
			var sign = "+" if population_change > 0 else ""
			lines.append("  Population: %s%.0f (Total: %d/%d)" % [sign, population_change, population_total, population_capacity])
		
		if lines.is_empty():
			return "  No significant changes"
		
		return "\n".join(lines)
