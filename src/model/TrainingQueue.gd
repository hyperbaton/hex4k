extends RefCounted
class_name TrainingQueue

# Manages unit training for a city

signal training_completed(unit_id: String)
signal training_progress(unit_id: String, turns_remaining: int)

# Training slot - one unit at a time per city (can expand later)
var current_training: Dictionary = {}  # { "unit_id": String, "turns_remaining": int, "total_turns": int }

func is_training() -> bool:
	return not current_training.is_empty()

func get_current_unit_id() -> String:
	return current_training.get("unit_id", "")

func get_turns_remaining() -> int:
	return current_training.get("turns_remaining", 0)

func get_total_turns() -> int:
	return current_training.get("total_turns", 0)

func get_progress_percent() -> float:
	if current_training.is_empty():
		return 0.0
	var total = current_training.get("total_turns", 1)
	var remaining = current_training.get("turns_remaining", 0)
	return float(total - remaining) / float(total) * 100.0

func start_training(unit_id: String, turns: int) -> bool:
	"""Start training a unit. Returns false if already training."""
	if is_training():
		return false
	
	current_training = {
		"unit_id": unit_id,
		"turns_remaining": turns,
		"total_turns": turns
	}
	print("TrainingQueue: Started training %s (%d turns)" % [unit_id, turns])
	return true

func cancel_training() -> String:
	"""Cancel current training. Returns the unit_id that was cancelled."""
	var unit_id = get_current_unit_id()
	current_training.clear()
	return unit_id

func process_turn() -> String:
	"""Process one turn of training. Returns unit_id if training completed, empty string otherwise."""
	if not is_training():
		return ""
	
	current_training["turns_remaining"] -= 1
	var remaining = current_training["turns_remaining"]
	var unit_id = current_training["unit_id"]
	
	emit_signal("training_progress", unit_id, remaining)
	
	if remaining <= 0:
		# Training complete!
		current_training.clear()
		emit_signal("training_completed", unit_id)
		return unit_id
	
	return ""

func get_save_data() -> Dictionary:
	return current_training.duplicate()

func load_save_data(data: Dictionary):
	current_training = data.duplicate()
