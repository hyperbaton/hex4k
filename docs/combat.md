# Combat System

This document describes the combat system: attack types, armor classes, combat resolution, and target selection.

## Implementation Status

| Feature | Status | Notes |
|---------|--------|-------|
| Armor classes & registry | **Implemented** | `data/armor_classes/`, `ArmorClassRegistry` |
| Attack types (string IDs) | **Implemented** | Referenced by armor defenses and attack abilities |
| CombatResolver | **Implemented** | `src/core/CombatResolver.gd` — main attack, retaliation, counter attack |
| Unit armor_classes field | **Implemented** | Replaces old `attack`/`defense` fields |
| attacks_remaining tracking | **Implemented** | Reset each turn from ability `attacks_per_turn` |
| Target selection UI | **Implemented** | Click-to-select targets, Escape/right-click to cancel |
| Fortification defense bonus | **Implemented** | 1.25x multiplier on `damage_reduction` |
| Health bar display | **Implemented** | UnitSprite shows bar when damaged, color-coded |
| Healing | **Implemented** | Fortified units heal 5 HP/turn |
| Unit destruction | **Implemented** | Signal-driven cleanup |
| Ranged combat | **Not implemented** | Framework supports range > 1 but no ranged units exist yet |
| City capture / siege | **Not implemented** | `can_capture` field exists but is unused |

## Core Concepts

### Attack Types

Plain string IDs (e.g., `"blunt"`, `"piercing"`, `"slashing"`). No separate data files — they exist only as keys referenced by armor class defenses and attack ability parameters.

### Armor Classes

Defined in `data/armor_classes/`. Each armor class contains an array of defense entries, each tuned to specific attack types. Units reference armor classes by ID in their `combat.armor_classes` array.

See [armor_classes.md](armor_classes.md) for the full schema.

### Attack Abilities

Attack strength and type are defined as parameters on combat abilities (e.g., `melee_attack`), overridden per unit:

```json
{
  "ability_id": "melee_attack",
  "params": {
    "strength": 12,
    "attack_type": "blunt",
    "range": 1,
    "attacks_per_turn": 1
  }
}
```

## Unit Combat Fields

```json
"combat": {
  "can_attack": true,
  "can_capture": false,
  "armor_classes": ["light_melee"]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `can_attack` | bool | Whether this unit can initiate attacks |
| `can_capture` | bool | Reserved for future city capture |
| `armor_classes` | Array[string] | Armor class IDs defining how the unit absorbs damage |

## Combat Resolution

Resolved by `CombatResolver.resolve_attack(attacker, defender, attack_params)`.

### 1. Main Attack (attacker -> defender)

1. Collect all armor classes on the defender
2. For each armor class, find defenses matching the attack type
3. Pick the defense that produces the **least damage** (best protection)
4. Calculate damage:
   - `effective_reduction = damage_reduction` (x1.25 if fortified)
   - `reduction = strength * effective_reduction`
   - If `reduction < min_damage_reduction`: use `min_damage_reduction`
   - `damage = strength - reduction`
   - If `damage < min_damage`: use `min_damage`
5. Apply damage to defender
6. Calculate `retaliation = damage * retaliation_pct`, apply to attacker

### 2. Counter Attack (defender -> attacker, if eligible)

After the main attack, the defender may counter attack if:
- Defender is still alive
- The matching defense has `counter_attack > 0` and `counter_range > 0`
- Attacker is within `counter_range` hexes

Counter attack resolution:
1. Find defender's first military ability to get their attack strength/type
2. `counter_strength = defender_strength * counter_attack`
3. Resolve against attacker's armor classes (same formula as main attack)
4. **No retaliation** on counter attacks
5. **No further counter attacks** (single pass)

### Result Dictionary

```
{
  success: bool,
  main_attack: {
    damage_dealt: int,
    retaliation_damage: int,
    armor_used: String,
    defender_killed: bool
  },
  counter_attack: {
    occurred: bool,
    damage_dealt: int,
    armor_used: String,
    attacker_killed: bool
  }
}
```

## Fortification

Fortified units receive a **1.25x multiplier** to `damage_reduction` on their armor. All other armor fields are unaffected.

| Aspect | Detail |
|--------|--------|
| Defense bonus | 1.25x damage_reduction |
| Healing | +5 HP per turn |
| Cost | Consumes all movement, ends turn |
| Breaks when | Unit moves to a new tile |
| Condition | Cannot fortify if already fortified |
| Persistence | Saved/loaded with unit state |

## Target Selection UI

When a combat ability is activated:

1. Valid enemy targets within range are highlighted in red
2. Click a highlighted target to attack
3. Right-click or Escape cancels target selection
4. After combat, movement highlights are restored for the surviving attacker

## Damage Model

`Unit.take_damage(amount)` applies raw damage directly — all reduction is handled by CombatResolver before calling this method.

- Emits `health_changed` signal (drives health bar updates)
- Emits `destroyed` signal when HP reaches 0

## Healing

- **Fortification healing:** Fortified units heal **5 HP per turn** at the start of their turn (`Unit.start_turn()`)
- **`Unit.heal(amount)`:** Restores HP up to `max_health`, emits `health_changed`

## Melee Attack Ability

Defined in `data/abilities/melee_attack.json`:

- **Conditions:** `has_movement`, `has_attacks_remaining`, `enemy_in_range`
- **Cost:** All movement, ends turn
- **Targeting:** Enemy units within `range` param (default 1)
- **Parameters:**
  - `strength` (float, default 10.0) — base attack damage
  - `attack_type` (string, default "blunt") — matched against armor defenses
  - `range` (int, default 1) — attack range in hexes
  - `attacks_per_turn` (int, default 1) — how many attacks per turn

## Enemy Interaction

### Movement Blocking

Implemented in `UnitManager.get_reachable_tiles()`: units cannot move through hexes occupied by enemy units.

### Enemy Detection

The `enemy_in_range` condition scans all enemy units and checks hex distance against the ability's `range` parameter. The older `adjacent_enemy` condition (range 1 only) still exists for backward compatibility.

## Unit Destruction

When a unit's health reaches 0:

1. `Unit.destroyed` signal fires
2. `UnitManager._on_unit_destroyed()` removes the unit from all tracking dictionaries
3. Unit is freed from the scene tree

**Not yet implemented:** death animations, combat log entries, cargo drops from destroyed transport units.

## Current Units

| Unit | Armor Classes | Attack | Abilities |
|------|--------------|--------|-----------|
| `club_wielder` | `light_melee` | 12 blunt, range 1 | melee_attack, fortify |
| `nomadic_band` | `civilian` | — | found_city |
| `nomadic_expedition` | `civilian` | — | found_city |
| `explorer` | `civilian` | — | fortify |
| `caravan` | `civilian` | — | trade, transport |
| `hand_cart` | `civilian` | — | transport, build_infrastructure |

## Key Files

| File | Role |
|------|------|
| `src/core/CombatResolver.gd` | Stateless combat resolution |
| `src/model/Unit.gd` | Unit model with health, armor_class_ids, attacks_remaining |
| `src/registry/ArmorClassRegistry.gd` | Armor class data loading and queries |
| `src/registry/AbilityRegistry.gd` | Ability conditions and combat effect handler |
| `src/world/World.gd` | Target selection UI flow |
| `data/armor_classes/` | Armor class definitions |
| `data/abilities/melee_attack.json` | Melee attack ability |
| `data/abilities/fortify.json` | Fortify ability |

## Signal Flow

```
Combat ability requested (World._on_ability_requested)
  → Enter target selection mode (highlight valid targets)
  → Player clicks target
  → CombatResolver.resolve_attack()
    → Unit.take_damage() on defender
      → health_changed signal → UnitSprite updates health bar
      → destroyed signal (if HP <= 0) → UnitManager.remove_unit()
    → Retaliation damage to attacker (if any)
    → Counter attack (if eligible)
      → Unit.take_damage() on attacker
```
