# Armor Classes

Armor classes define how units absorb damage from different attack types. Each armor class is a JSON file under `data/armor_classes/`.

## File Location

```
data/armor_classes/<armor_class_id>.json
```

## Schema

```json
{
  "defenses": [
    {
      "attack_types": ["blunt", "piercing", "slashing"],
      "damage_reduction": 0.15,
      "min_damage": 1,
      "min_damage_reduction": 0,
      "retaliation": 0.0,
      "counter_attack": 0.6,
      "counter_range": 1
    }
  ]
}
```

## Fields

### `defenses` (Array, required)

Array of defense entries. Each entry defines how the unit responds to specific attack types.

#### Defense Entry Fields

| Field | Type | Description |
|-------|------|-------------|
| `attack_types` | Array[string] | Which attack types this defense applies to |
| `damage_reduction` | float (0.0-1.0) | Fraction of attack strength absorbed. Multiplied by 1.25 when fortified |
| `min_damage` | int | Minimum damage always dealt regardless of reduction |
| `min_damage_reduction` | int | Floor for damage reduction (absolute value) |
| `retaliation` | float (0.0-1.0) | Fraction of damage dealt reflected back to attacker immediately |
| `counter_attack` | float (0.0-1.0) | Fraction of defender's own attack strength used in counter attack |
| `counter_range` | int | Maximum hex distance for counter attack eligibility |

## How Defenses Are Selected

When a unit takes damage from an attack:

1. All armor classes on the defender are checked
2. Within each armor class, defenses whose `attack_types` include the incoming attack type are considered
3. The defense producing the **least damage** (best protection) is selected
4. If no defense matches, full damage is applied

## Damage Calculation

For a given `strength` and matching defense:

```
effective_reduction = damage_reduction * (1.25 if fortified, else 1.0)
reduction = strength * effective_reduction
if reduction < min_damage_reduction: reduction = min_damage_reduction
damage = strength - reduction
if damage < min_damage: damage = min_damage
```

## Current Armor Classes

### `civilian`

No meaningful armor. Takes full damage from all attack types. No counter attack capability.

### `light_melee`

Basic melee protection: 15% damage reduction, can counter attack at 60% strength against adjacent enemies.

## Registry

`ArmorClassRegistry` (`src/registry/ArmorClassRegistry.gd`) provides:

- `get_armor_class(id) -> Dictionary` — full armor class data
- `get_defenses(id) -> Array` — defenses array
- `get_matching_defenses(id, attack_type) -> Array` — defenses matching an attack type
- `armor_class_exists(id) -> bool`
