extends RefCounted
class_name ResourceLedger

# Tracks resources for a city with detailed breakdown

# Total resources stored across all buildings
var total_stored: Dictionary = {}  # resource_id -> float

# Per-turn flows
var production: Dictionary = {}  # resource_id -> float (what buildings produce)
var consumption: Dictionary = {}  # resource_id -> float (what buildings consume)
var trade_incoming: Dictionary = {}  # resource_id -> float (from caravans)
var trade_outgoing: Dictionary = {}  # resource_id -> float (to caravans)
var decay: Dictionary = {}  # resource_id -> float (spoilage/rot)

# Storage capacity
var storage_capacity: Dictionary = {}  # resource_id -> float

func clear_flows():
	"""Called at the start of turn calculation"""
	production.clear()
	consumption.clear()
	trade_incoming.clear()
	trade_outgoing.clear()
	decay.clear()

func add_production(resource_id: String, amount: float):
	production[resource_id] = production.get(resource_id, 0.0) + amount

func add_consumption(resource_id: String, amount: float):
	consumption[resource_id] = consumption.get(resource_id, 0.0) + amount

func add_trade_incoming(resource_id: String, amount: float):
	trade_incoming[resource_id] = trade_incoming.get(resource_id, 0.0) + amount

func add_trade_outgoing(resource_id: String, amount: float):
	trade_outgoing[resource_id] = trade_outgoing.get(resource_id, 0.0) + amount

func add_decay(resource_id: String, amount: float):
	decay[resource_id] = decay.get(resource_id, 0.0) + amount

func get_net_change(resource_id: String) -> float:
	"""Total change per turn (can be positive or negative)"""
	var prod = production.get(resource_id, 0.0)
	var cons = consumption.get(resource_id, 0.0)
	var trade_in = trade_incoming.get(resource_id, 0.0)
	var trade_out = trade_outgoing.get(resource_id, 0.0)
	var decay_amount = decay.get(resource_id, 0.0)
	
	return prod - cons + trade_in - trade_out - decay_amount

func get_internal_change(resource_id: String) -> float:
	"""Change due to internal production/consumption only"""
	var prod = production.get(resource_id, 0.0)
	var cons = consumption.get(resource_id, 0.0)
	return prod - cons

func get_trade_change(resource_id: String) -> float:
	"""Change due to trade only"""
	var trade_in = trade_incoming.get(resource_id, 0.0)
	var trade_out = trade_outgoing.get(resource_id, 0.0)
	return trade_in - trade_out

func get_stored(resource_id: String) -> float:
	return total_stored.get(resource_id, 0.0)

func set_stored(resource_id: String, amount: float):
	total_stored[resource_id] = max(0.0, amount)

func add_stored(resource_id: String, amount: float):
	var current = total_stored.get(resource_id, 0.0)
	var capacity = storage_capacity.get(resource_id, INF)
	total_stored[resource_id] = clamp(current + amount, 0.0, capacity)

func has_resource(resource_id: String, amount: float) -> bool:
	return get_stored(resource_id) >= amount

func consume(resource_id: String, amount: float, reason: String = "") -> bool:
	"""Consume resources from storage. Returns true if successful."""
	if not has_resource(resource_id, amount):
		return false
	var current = total_stored.get(resource_id, 0.0)
	total_stored[resource_id] = current - amount
	if reason != "":
		print("  Consumed %.1f %s for %s" % [amount, resource_id, reason])
	return true

func can_store(resource_id: String, amount: float) -> bool:
	var current = get_stored(resource_id)
	var capacity = storage_capacity.get(resource_id, INF)
	return current + amount <= capacity

func get_storage_capacity(resource_id: String) -> float:
	return storage_capacity.get(resource_id, 0.0)

func set_storage_capacity(resource_id: String, capacity: float):
	storage_capacity[resource_id] = capacity

func get_all_resources() -> Array:
	"""Returns all resource IDs that have any activity"""
	var all_resources = {}
	for dict in [total_stored, production, consumption, trade_incoming, trade_outgoing, decay]:
		for res_id in dict.keys():
			all_resources[res_id] = true
	return all_resources.keys()
