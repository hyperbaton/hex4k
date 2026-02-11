# Turn Processing

The turn system processes all cities sequentially through a strict multi-phase cycle. Each phase handles a specific aspect of the city economy, and the order matters — later phases depend on results from earlier ones.

## Turn Cycle Overview

When a turn ends, the `TurnManager` processes each city through these phases in order:

1. **Caps** — Calculate capacity resources and production efficiency
2. **Production** — Active buildings produce resources
3. **Modifier Consumption** — Buildings consume nearby tile modifiers
4. **Consumption** — Buildings consume resources (two-pass priority)
5. **Construction** — Advance building construction projects
6. **Upgrades** — Advance building upgrades
7. **Training** — Complete unit training and spawn units
8. **Population** — Update population counts
9. **Decay** — Apply spoilage to stored resources

After all cities are processed, the system checks for abandoned cities and defeated players.

## Phase Details

### Phase 1: Caps

Calculates generic cap resources (e.g., `admin_capacity`) for the city.

- Sums up all cap resource production from active buildings
- Sums up all cap resource consumption (including tile costs from the settlement type)
- Computes available/used/ratio for each cap resource
- Disabled buildings still consume a reduced cap cost (`disabled_admin_cost`)
- The **worst cap efficiency** (lowest ratio) becomes the production modifier for the entire turn — if a city is over capacity, all production is penalized

### Phase 2: Production

Active buildings produce resources.

- Only buildings with `is_active()` status produce
- Production is multiplied by the cap efficiency from Phase 1
- **Terrain bonuses**, **modifier bonuses**, and **adjacency bonuses** are added
- `knowledge` resources are routed to tech branches:
  - If the production entry has a `branch` field, points go to that specific branch
  - Otherwise, points go to the player's chosen focus branch
- `flow` resources are tracked in the ledger but not stored
- `storable` resources are stored in building pools; excess is tracked as spillage

### Phase 2b: Modifier Consumption

Active buildings consume nearby tile modifiers based on configuration.

- Checks modifiers within a configurable radius
- Consumption happens based on a random chance per modifier
- Can transform consumed modifiers into different types

### Phase 3: Consumption

Buildings consume resources. Uses a **two-pass priority system**:

1. **First pass**: Active buildings consume first (they have priority)
2. **Second pass**: Buildings in `EXPECTING_RESOURCES` state try to consume

For each building:
- Resources can be consumed by **resource ID** or by **tag** (e.g., consume any `storable` resource)
- If all consumption is satisfied → building becomes active
- If consumption fails → building enters `EXPECTING_RESOURCES` state and penalties from `per_turn_penalty` are applied

### Phase 4: Construction

Advances building construction projects.

- Limited by **building capacity** — only one construction can advance per capacity point per turn
- Checks if the per-turn construction cost can be paid
- If costs are met, advances the construction timer
- If costs cannot be met, construction is paused
- Excess constructions are queued for later turns
- On completion, triggers `on_construction_complete` rewards (e.g., research points)

### Phase 4b: Upgrades

Advances building upgrades.

- Buildings **continue operating** while upgrading (unlike construction)
- Per-turn upgrade costs are checked and deducted
- If costs cannot be met, the upgrade is paused
- On completion, the building transforms into its `upgrades_to` target
- Checks for **settlement transitions** when an upgrade completes (e.g., upgrading a longhouse to a tribal camp can evolve an encampment into a village)

### Phase 4c: Training

Completes unit training and spawns units.

- Advances training timers for each building with active training
- On completion, spawns the trained unit at the building's tile
- If the building tile is occupied, finds a nearby valid spawn location

### Phase 5: Population

Updates population totals.

- Population is derived from resources tagged with `population` in storage
- Tracks population change from production, consumption, and penalties
- Checks against housing capacity

### Phase 6: Decay

Applies spoilage to stored resources.

- Only affects resources tagged with `decaying`
- Decay rate comes from the resource definition (`decay.rate_per_turn`)
- **Storage pools** can reduce decay for specific resources (`decay_reduction`)
- **Adjacency decay bonuses** from nearby buildings (e.g., smoke house reducing food decay in a granary) are applied

## Post-Processing

### Abandoned Cities

After all phases complete, the system checks:
- If a city's population reaches 0, the city is **abandoned**
- Abandoned cities: all buildings are disabled, perishable resources cleared, city is disowned
- If a player has no cities remaining, they are **defeated**

### Settlement Transitions

Triggered by building upgrades during Phase 4b:
- If the upgraded building matches a settlement transition's `trigger_building` → `target_building`
- The city's settlement type changes (e.g., encampment → village)
- City stats are recalculated with the new settlement's tile costs and bonuses

## Building States

Buildings cycle through states during turn processing:

| State | Description |
|-------|-------------|
| `active` | Producing and consuming normally |
| `expecting_resources` | Consumption failed; waiting for resources |
| `under_construction` | Being built; not yet operational |
| `upgrading` | Being upgraded; still operational |
| `disabled` | Manually disabled by the player; reduced cap cost only |

## Turn Report

Each turn generates a `TurnReport` containing per-city breakdowns:

- **Cap reports**: Available, used, ratio, and efficiency for each cap resource
- **Production/consumption**: Per-resource totals with building-level detail
- **Spillage**: Resources produced but with no storage space
- **Penalties**: Resources lost from `per_turn_penalty` on buildings that failed consumption
- **Building status changes**: Which buildings were activated, paused, or lost resources
- **Construction/upgrade progress**: Completion, pausing, and queuing status
- **Modifier consumption**: What modifiers were consumed and transformed
- **Decay**: Per-resource decay amounts
- **Research**: Knowledge produced (branch-specific and generic)
- **Population**: Change, total, and capacity
- **Resource totals**: End-of-turn resource state
- **Critical alerts**: Warnings about starvation, over-capacity, etc.

## Signals

The turn system emits these signals:

| Signal | Description |
|--------|-------------|
| `turn_started(turn_number)` | Emitted when the turn begins processing |
| `turn_completed(report)` | Emitted when all cities are processed |
| `city_processed(city_id, city_report)` | Emitted after each individual city |
| `city_abandoned(city, previous_owner)` | Emitted when a city is abandoned |
| `player_defeated(player)` | Emitted when a player loses all cities |

## Key Design Decisions

- **Cap efficiency affects all production** — exceeding admin capacity penalizes the entire city, not just individual buildings
- **Two-pass consumption** gives active buildings priority over struggling ones
- **Buildings operate during upgrades** — no downtime when upgrading
- **Building capacity limits construction throughput** — players need civic buildings to build faster
- **Tag-based consumption** allows flexible resource systems without hardcoding
- **Generic cap system** — not hardcoded to admin_capacity; any `cap`-tagged resource works the same way
