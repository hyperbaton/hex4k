extends RefCounted
class_name CombatResolver

# Stateless combat resolution utility.
# All methods take explicit parameters — no internal state.

func resolve_attack(attacker: Unit, defender: Unit, attack_params: Dictionary) -> Dictionary:
	"""
	Resolve a full attack sequence: main attack, retaliation, and counter attack.
	attack_params: { strength: float, attack_type: String, range: int }
	Returns combat result dictionary.
	"""
	var strength: float = attack_params.get("strength", 10.0)
	var attack_type: String = attack_params.get("attack_type", "blunt")
	var attack_range: int = attack_params.get("range", 1)

	var result = {
		success = true,
		main_attack = {
			damage_dealt = 0,
			retaliation_damage = 0,
			armor_used = "",
			defender_killed = false
		},
		counter_attack = {
			occurred = false,
			damage_dealt = 0,
			armor_used = "",
			attacker_killed = false
		}
	}

	# === MAIN ATTACK (attacker -> defender) ===
	var best_armor = _find_best_armor(defender, attack_type, strength, defender.is_fortified)

	if best_armor.is_empty():
		# No matching armor — full damage
		var damage = max(1, int(strength))
		defender.take_damage(damage)
		result.main_attack.damage_dealt = damage
	else:
		result.main_attack.armor_used = best_armor.armor_class_id
		result.main_attack.damage_dealt = best_armor.damage
		result.main_attack.retaliation_damage = best_armor.retaliation

		defender.take_damage(best_armor.damage)

		if best_armor.retaliation > 0:
			attacker.take_damage(best_armor.retaliation)

	result.main_attack.defender_killed = defender.current_health <= 0

	# === COUNTER ATTACK (defender -> attacker, if eligible) ===
	if not result.main_attack.defender_killed and attacker.current_health > 0:
		var counter_result = _try_counter_attack(attacker, defender, best_armor, attack_range)
		result.counter_attack = counter_result

	return result

func _find_best_armor(unit: Unit, attack_type: String, strength: float, is_fortified: bool) -> Dictionary:
	"""
	Find the defense entry across all armor classes that produces the LEAST damage.
	Returns { armor_class_id, defense, damage, reduction, retaliation } or empty if none found.
	"""
	var best: Dictionary = {}
	var best_damage: float = INF

	for armor_class_id in unit.armor_class_ids:
		var matching = Registry.armor_classes.get_matching_defenses(armor_class_id, attack_type)
		for defense in matching:
			var calc = _calculate_damage(strength, defense, is_fortified)
			if calc.damage < best_damage:
				best_damage = calc.damage
				best = {
					armor_class_id = armor_class_id,
					defense = defense,
					damage = calc.damage,
					reduction = calc.reduction,
					retaliation = calc.retaliation
				}

	return best

func _calculate_damage(strength: float, defense: Dictionary, is_fortified: bool) -> Dictionary:
	"""
	Calculate damage from strength against a single defense entry.
	Returns { damage: int, reduction: float, retaliation: int }
	"""
	var damage_reduction: float = defense.get("damage_reduction", 0.0)
	var min_damage: int = defense.get("min_damage", 1)
	var min_damage_reduction: int = defense.get("min_damage_reduction", 0)
	var retaliation_pct: float = defense.get("retaliation", 0.0)

	# Fortification multiplier on damage_reduction
	if is_fortified:
		damage_reduction *= 1.25

	var reduction: float = strength * damage_reduction
	if reduction < min_damage_reduction:
		reduction = min_damage_reduction

	var damage: float = strength - reduction
	if damage < min_damage:
		damage = min_damage

	var final_damage: int = max(min_damage, int(damage))
	var retaliation: int = int(final_damage * retaliation_pct)

	return {
		damage = final_damage,
		reduction = reduction,
		retaliation = retaliation
	}

func _try_counter_attack(attacker: Unit, defender: Unit, main_armor: Dictionary, attack_range: int) -> Dictionary:
	"""Attempt a counter attack from defender back to attacker."""
	var result = {
		occurred = false,
		damage_dealt = 0,
		armor_used = "",
		attacker_killed = false
	}

	if main_armor.is_empty():
		return result

	var defense_entry: Dictionary = main_armor.get("defense", {})
	var counter_attack_pct: float = defense_entry.get("counter_attack", 0.0)
	var counter_range: int = defense_entry.get("counter_range", 0)

	if counter_attack_pct <= 0.0 or counter_range <= 0:
		return result

	# Check if attacker is within counter range
	var distance = _hex_distance(attacker.coord, defender.coord)
	if distance > counter_range:
		return result

	# Find defender's attack ability to get their attack strength/type
	var defender_attack = _get_unit_attack_params(defender)
	if defender_attack.is_empty():
		return result

	var counter_strength: float = float(defender_attack.get("strength", 10.0)) * counter_attack_pct
	var counter_type: String = defender_attack.get("attack_type", "blunt")

	# Resolve counter against attacker's armor (no retaliation, no further counters)
	var best_armor = _find_best_armor(attacker, counter_type, counter_strength, attacker.is_fortified)

	result.occurred = true

	if best_armor.is_empty():
		var damage = max(1, int(counter_strength))
		attacker.take_damage(damage)
		result.damage_dealt = damage
	else:
		result.armor_used = best_armor.armor_class_id
		result.damage_dealt = best_armor.damage
		attacker.take_damage(best_armor.damage)
		# No retaliation on counter attacks

	result.attacker_killed = attacker.current_health <= 0
	return result

func _get_unit_attack_params(unit: Unit) -> Dictionary:
	"""Get the attack parameters from a unit's first attack ability."""
	var unit_data = Registry.units.get_unit(unit.unit_type)
	var abilities = unit_data.get("abilities", [])

	for ability_ref in abilities:
		var ability_id: String = ""
		var params: Dictionary = {}

		if ability_ref is Dictionary:
			ability_id = ability_ref.get("ability_id", "")
			params = ability_ref.get("params", {})
		elif ability_ref is String:
			ability_id = ability_ref

		var ability_data = Registry.abilities.get_ability(ability_id)
		if ability_data.get("category", "") == "military":
			# Merge default params with unit-specific overrides
			var ability_params = ability_data.get("params", {})
			var resolved: Dictionary = {}
			for key in ability_params:
				resolved[key] = params.get(key, ability_params[key].get("default", 0))
			return resolved

	return {}

func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var q_diff = abs(a.x - b.x)
	var r_diff = abs(a.y - b.y)
	var s_diff = abs((-a.x - a.y) - (-b.x - b.y))
	return int((q_diff + r_diff + s_diff) / 2)
