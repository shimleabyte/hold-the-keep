# Hold the Keep — Rival Civilizations & Army Command

**Direction:** A hybrid kingdom strategy game. The player remains a directly controlled combatant and settlement steward. Civilian workers retain autonomous job behavior. Military units can be selected and commanded with the mouse. Rival factions must develop as competing settlements rather than passive strongholds.

## Non-negotiable boundaries

- Army selection and orders apply only to military units with job equal to soldier, including the existing archer specialization.
- Civilian workers are not directly selectable. Their existing job, construction, gathering, carrying and delivery loops remain autonomous.
- The player avatar, direct movement, combat abilities, camera and existing build-placement rules remain in place.
- Basic commands are select, box-select, move and attack. Advanced formation controls, control groups, attack-move and command queues are separate later work.
- Rival economy and construction are distinct from player buildings. Rival structures must not be assigned to player workers, depots or supply routes.
- Rival resource production is bounded and paid for. Recruitment, construction and research spend stored resources.
- World dimensions remain unchanged until multi-settlement gameplay and performance measurements justify a new profile.
- New save state is additive. Existing v17 saves without civilization data must load with a valid initial rival economy.

## Current implementation slice

### Army command foundation
- Left click selects one military unit.
- Drag selects multiple military units.
- Shift adds/removes units from the current selection.
- Right click ground issues a move order.
- Right click a visible hostile unit, enemy stronghold or hostile settlement structure issues an attack order.
- Soldiers keep their combat execution, pathfinding and attack animation logic. The command layer does not take over every attack frame.

### Rival civilization foundation
- Each enemy stronghold owns an independent resource ledger and scheduled development simulation.
- Rival construction produces visible, destructible structures using existing art.
- Initial development order: lumber camp, farm, quarry, barracks, tower, forge and storage.
- Buildings generate resources; upkeep and construction/recruitment costs consume resources.
- Barracks increase garrison capacity. Recruitment consumes food and wood, with an iron cost at higher technology.
- Technology progresses through three military tiers using prerequisites, time and stored resources.
- Rival structures and economy state are persisted as additive stronghold state.

**Important limitation:** the first slice uses an abstracted workforce for the rival economy. It establishes resource production, construction, recruitment and research without yet simulating visible enemy laborers, multiple outposts, road logistics, territorial expansion or coordinated offensive campaigns.

## Delivery sequence

| Stage | Scope | Acceptance |
|---|---|---|
| 1 — Army orders | Military-only select, box select, move and attack | Workers remain autonomous; soldiers obey commands; player avatar and build mode remain unchanged |
| 2 — Rival settlement | Resources, visible construction, recruitment, research, save/load | Classic rival builds and develops without free resources or units; structure destruction and reload are safe |
| 3 — Faction strategy | Faction-specific economic priorities, defensive plans, patrols and raids | Four Frontier factions produce distinct strategic problems and respect their available resources |
| 4 — Expansion and warfare | Secondary settlements, outposts, logistics, siege plans and larger maps | Territory and supply matter; both sides can attack/defend; map dimensions are justified by actual strategic distance |
| 5 — Campaign rebalance | Classic/Frontier pacing, objectives and victory conditions | Human playthroughs establish challenge, recovery windows and campaign length |

## Performance and persistence constraints

- Strategic decisions run on bounded simulation ticks, not every rendered frame.
- Construction placement checks only a bounded local search around the owning stronghold.
- World occupancy and navigation updates use the existing dirty-cell/event mechanisms.
- Do not rebuild the full NavGrid or FlowField synchronously during each placement.
- Save resource balances, technology, completed structures, their HP and any active construction timer.
- Reconstruct paths and transient caches after load rather than serializing navigation internals.

