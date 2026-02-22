extends RefCounted
class_name TurnReport

# Stores the results of processing a turn for all cities

var turn_number: int = 0
var city_reports: Dictionary = {}  # city_id -> CityTurnReport
var global_events: Array[Dictionary] = []
var critical_alerts: Array[Dictionary] = []
var milestones_unlocked: Array[String] = []
var perks_unlocked: Array[String] = []

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

func add_perk_unlocked(perk_id: String):
	perks_unlocked.append(perk_id)
	add_global_event("perk_unlocked", {"perk_id": perk_id})
	add_critical_alert("perk", "", "Perk Unlocked: " + Registry.perks.get_perk_name(perk_id), {"perk_id": perk_id})

func has_critical_alerts() -> bool:
	return not critical_alerts.is_empty()

func has_city_abandonments() -> bool:
	for alert in critical_alerts:
		if alert.type == "city_abandoned":
			return true
	return false

func has_player_defeats() -> bool:
	for alert in critical_alerts:
		if alert.type == "player_defeated":
			return true
	return false

func get_alerts_by_type(alert_type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for alert in critical_alerts:
		if alert.type == alert_type:
			result.append(alert)
	return result

func get_summary() -> String:
	"""Get a brief text summary of the turn"""
	var lines: Array[String] = []
	lines.append("=== Turn %d Summary ===" % turn_number)
	
	# Show milestones prominently at the top
	if not milestones_unlocked.is_empty():
		lines.append("")
		for milestone_id in milestones_unlocked:
			var milestone_name = Registry.tech.get_milestone_name(milestone_id)
			lines.append("\u2605 Milestone Unlocked: %s" % milestone_name)
			# Show what this milestone unlocks
			var unlocks = _get_milestone_unlocks(milestone_id)
			if not unlocks.is_empty():
				lines.append("  Unlocks: %s" % ", ".join(unlocks))

	# Show perks after milestones
	if not perks_unlocked.is_empty():
		lines.append("")
		for perk_id in perks_unlocked:
			var perk_name = Registry.perks.get_perk_name(perk_id)
			lines.append("\u2605 Perk Unlocked: %s" % perk_name)

	for city_id in city_reports.keys():
		var report = city_reports[city_id]
		lines.append("\n[%s]" % city_id)
		lines.append(report.get_summary())
	
	# Show non-milestone/perk critical alerts
	var other_alerts: Array[Dictionary] = []
	for alert in critical_alerts:
		if alert.type != "milestone" and alert.type != "perk":
			other_alerts.append(alert)
	
	if not other_alerts.is_empty():
		lines.append("\n!!! Alerts: %d !!!" % other_alerts.size())
		for alert in other_alerts:
			lines.append("  - %s" % alert.message)
	
	return "\n".join(lines)

func _get_milestone_unlocks(milestone_id: String) -> Array[String]:
	"""Get a list of things unlocked by this milestone (buildings, resources, etc.)"""
	var unlocks: Array[String] = []
	
	# Check buildings that require this milestone
	for building_id in Registry.buildings.get_all_building_ids():
		var milestones_req = Registry.buildings.get_required_milestones(building_id)
		if milestone_id in milestones_req:
			# Show if all required milestones are now unlocked
			if Registry.has_all_milestones(milestones_req):
				unlocks.append(Registry.get_name_label("building", building_id))
	
	# Check resources that require this milestone
	for resource_id in Registry.resources.get_all_resource_ids():
		var milestones_req = Registry.resources.get_required_milestones(resource_id)
		if milestone_id in milestones_req:
			if Registry.has_all_milestones(milestones_req):
				unlocks.append(Registry.get_name_label("resource", resource_id))
	
	return unlocks


class CityTurnReport extends RefCounted:
	"""Report for a single city's turn processing"""
	
	var city_id: String
	var city_name: String
	
	# Generic cap reports: { resource_id: { available, used, ratio, efficiency } }
	var cap_reports: Dictionary = {}
	
	# Overall production efficiency (minimum across all cap penalties)
	var production_efficiency: float = 1.0
	
	# Production summary
	var production: Dictionary = {}  # resource_id -> amount produced (raw)
	var production_after_efficiency: Dictionary = {}  # After cap penalties
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
	var constructions_queued: Array[Dictionary] = []  # [{coord, building_id, turns_remaining}] - waiting for building capacity
	var completion_rewards: Dictionary = {}  # resource_id -> amount from building completion
	var completion_research_rewards: Dictionary = {}  # branch_id -> points from building completion
	
	# Upgrades
	var upgrades_progressed: Array[Dictionary] = []  # [{coord, from_building_id, to_building_id, turns_remaining}]
	var upgrades_completed: Array[Dictionary] = []  # [{coord, from_building_id, to_building_id}]
	var upgrades_paused: Array[Dictionary] = []  # [{coord, from_building_id, to_building_id, missing_resources}]
	
	# Modifier consumption
	var modifiers_consumed: Array[Dictionary] = []  # [{building_coord, building_id, tile_coord, modifier_id, transforms_to}]
	
	# Decay
	var decay_summary: Dictionary = {}  # resource_id -> total decayed
	
	# Knowledge (research) produced
	var knowledge_produced: Dictionary = {}  # { resource_id: { branch_id: points, ... }, ... }
	var generic_knowledge_produced: Dictionary = {}  # { resource_id: total_generic }
	var generic_knowledge_targets: Dictionary = {}  # { resource_id: target_branch }
	
	# Population
	var population_change: float = 0.0
	var population_total: int = 0
	var population_capacity: int = 0
	
	# Trade transfers
	var trade_transfers: Array[Dictionary] = []  # [{route_id, resource_id, amount, direction, dest_city_id}]

	# Resource totals (end of turn)
	var resource_totals: Dictionary = {}  # resource_id -> amount stored
	
	func _init(id: String, name: String):
		city_id = id
		city_name = name
	
	# Cap reporting
	func set_cap_report(resource_id: String, available: float, used: float, ratio: float, efficiency: float):
		cap_reports[resource_id] = {
			"available": available,
			"used": used,
			"ratio": ratio,
			"efficiency": efficiency
		}
	
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
	
	func add_construction_queued(coord: Vector2i, building_id: String, turns_left: int):
		constructions_queued.append({"coord": coord, "building_id": building_id, "turns_remaining": turns_left})
	
	func add_modifier_consumed(building_coord: Vector2i, building_id: String, tile_coord: Vector2i, modifier_id: String, transforms_to: String):
		modifiers_consumed.append({"building_coord": building_coord, "building_id": building_id, "tile_coord": tile_coord, "modifier_id": modifier_id, "transforms_to": transforms_to})
	
	func add_upgrade_progressed(coord: Vector2i, from_building_id: String, to_building_id: String, turns_left: int):
		upgrades_progressed.append({"coord": coord, "from_building_id": from_building_id, "to_building_id": to_building_id, "turns_remaining": turns_left})
	
	func add_upgrade_completed(coord: Vector2i, from_building_id: String, to_building_id: String):
		upgrades_completed.append({"coord": coord, "from_building_id": from_building_id, "to_building_id": to_building_id})
	
	func add_upgrade_paused(coord: Vector2i, from_building_id: String, to_building_id: String, missing: Dictionary):
		upgrades_paused.append({"coord": coord, "from_building_id": from_building_id, "to_building_id": to_building_id, "missing_resources": missing})
	
	func add_decay(resource_id: String, amount: float):
		decay_summary[resource_id] = decay_summary.get(resource_id, 0.0) + amount
	
	func add_knowledge(knowledge_resource_id: String, branch_id: String, points: float):
		"""Track knowledge produced for a specific branch."""
		if not knowledge_produced.has(knowledge_resource_id):
			knowledge_produced[knowledge_resource_id] = {}
		knowledge_produced[knowledge_resource_id][branch_id] = knowledge_produced[knowledge_resource_id].get(branch_id, 0.0) + points
	
	func add_generic_knowledge(knowledge_resource_id: String, points: float):
		"""Track generic (unrouted) knowledge produced."""
		generic_knowledge_produced[knowledge_resource_id] = generic_knowledge_produced.get(knowledge_resource_id, 0.0) + points
	
	func set_generic_knowledge_target(knowledge_resource_id: String, target_branch: String):
		"""Record where generic knowledge was routed."""
		generic_knowledge_targets[knowledge_resource_id] = target_branch

	func add_trade_transfer(route_id: String, resource_id: String, amount: float, direction: String, dest_city_id: String):
		"""Track a resource transfer via trade route."""
		trade_transfers.append({
			"route_id": route_id,
			"resource_id": resource_id,
			"amount": amount,
			"direction": direction,
			"dest_city_id": dest_city_id
		})

	# === Backward Compatibility ===
	# TODO: Remove in Phase 6 cleanup.
	
	var admin_capacity_used: float:
		get:
			var cap = cap_reports.get("admin_capacity", {})
			return cap.get("used", 0.0)
		set(value):
			if not cap_reports.has("admin_capacity"):
				cap_reports["admin_capacity"] = {}
			cap_reports["admin_capacity"]["used"] = value
	
	var admin_capacity_available: float:
		get:
			var cap = cap_reports.get("admin_capacity", {})
			return cap.get("available", 0.0)
		set(value):
			if not cap_reports.has("admin_capacity"):
				cap_reports["admin_capacity"] = {}
			cap_reports["admin_capacity"]["available"] = value
	
	var admin_ratio: float:
		get:
			var cap = cap_reports.get("admin_capacity", {})
			return cap.get("ratio", 0.0)
		set(value):
			if not cap_reports.has("admin_capacity"):
				cap_reports["admin_capacity"] = {}
			cap_reports["admin_capacity"]["ratio"] = value
	
	var generic_research_produced: float:
		get: return generic_knowledge_produced.get("research", 0.0)
		set(value): generic_knowledge_produced["research"] = value
	
	var generic_research_target: String:
		get: return generic_knowledge_targets.get("research", "")
		set(value): generic_knowledge_targets["research"] = value
	
	var research_generated: Dictionary:
		get:
			# Flatten all knowledge into single dict for backward compat
			var result := {}
			for res_id in knowledge_produced.keys():
				for branch_id in knowledge_produced[res_id].keys():
					result[branch_id] = result.get(branch_id, 0.0) + knowledge_produced[res_id][branch_id]
			return result
		set(value): pass
	
	func add_research(branch_id: String, points: float):
		"""DEPRECATED: Use add_knowledge() with resource_id instead."""
		add_knowledge("research", branch_id, points)
	
	func get_summary() -> String:
		var lines: Array[String] = []
		
		# Cap efficiency
		for cap_id in cap_reports.keys():
			var cap = cap_reports[cap_id]
			var ratio = cap.get("ratio", 0.0)
			if ratio > 1.0:
				var eff = cap.get("efficiency", 1.0)
				var cap_name = Registry.get_name_label("resource", cap_id)
				lines.append("  %s Overload: %.0f%% efficiency" % [cap_name, eff * 100])
		
		# Production
		if not production_after_efficiency.is_empty():
			var prod_parts: Array[String] = []
			for res_id in production_after_efficiency.keys():
				# Skip knowledge resources in production display (shown separately)
				if not Registry.resources.has_tag(res_id, "knowledge"):
					prod_parts.append("%s: +%.1f" % [res_id, production_after_efficiency[res_id]])
			if not prod_parts.is_empty():
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
		
		if not constructions_queued.is_empty():
			lines.append("  Construction queued (no capacity): %d buildings" % constructions_queued.size())
		
		if not modifiers_consumed.is_empty():
			for event in modifiers_consumed:
				if event.transforms_to != "":
					lines.append("  Modifier: %s -> %s at %v" % [event.modifier_id, event.transforms_to, event.tile_coord])
				else:
					lines.append("  Modifier depleted: %s at %v" % [event.modifier_id, event.tile_coord])
		
		# Upgrades
		if not upgrades_completed.is_empty():
			for upgrade in upgrades_completed:
				var from_name = Registry.get_name_label("building", upgrade.from_building_id)
				var to_name = Registry.get_name_label("building", upgrade.to_building_id)
				lines.append("  Upgraded: %s -> %s" % [from_name, to_name])
		
		if not upgrades_paused.is_empty():
			lines.append("  Upgrade paused: %d buildings" % upgrades_paused.size())
		
		# Knowledge / Research
		var all_research = research_generated
		if not all_research.is_empty() or not generic_knowledge_produced.is_empty():
			var research_parts: Array[String] = []
			for branch_id in all_research.keys():
				research_parts.append("%s: +%.2f" % [branch_id, all_research[branch_id]])
			if not research_parts.is_empty():
				lines.append("  Research: " + ", ".join(research_parts))
			for res_id in generic_knowledge_produced.keys():
				var amount = generic_knowledge_produced[res_id]
				var target = generic_knowledge_targets.get(res_id, "")
				if amount > 0.0 and target != "":
					var target_name = Registry.tech.get_branch_name(target)
					lines.append("  Generic %s: +%.2f → %s" % [res_id, amount, target_name])
		
		# Trade transfers
		if not trade_transfers.is_empty():
			for transfer in trade_transfers:
				var dest_name = transfer.dest_city_id
				lines.append("  Trade: %.1f %s -> %s" % [transfer.amount, transfer.resource_id, dest_name])

		# Population
		if population_change != 0:
			var sign = "+" if population_change > 0 else ""
			lines.append("  Population: %s%.0f (Total: %d/%d)" % [sign, population_change, population_total, population_capacity])

		if lines.is_empty():
			return "  No significant changes"

		return "\n".join(lines)
