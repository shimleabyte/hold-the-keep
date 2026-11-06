# Hold the Keep — RTS Pivot

**Direction:** Traditional top-down real-time strategy, inspired by the economy, expansion, technology, military command and conquest loop of Age of Empires. This is a product direction, not an implementation-complete claim.

## Player role

The player is the civilization's commander. The primary interface is a detached strategy camera and direct orders to units. A single controllable hero is not the center of the game. The legacy player node remains temporarily for save compatibility and systems that still reference it; it is hidden and its direct input is disabled during the RTS transition.

## Core loop

1. Establish a town center and gather wood, food, stone and iron.
2. Assign villagers to resource gathering, construction and support roles.
3. Build production, defensive and civic structures.
4. Scout terrain, resource deposits and rival settlements.
5. Advance through technologies and military capabilities.
6. Produce, select and command military units.
7. Expand territory, establish forward settlements and conquer rival powers.

Nighttime raids may remain as one pressure source, but they are not the strategic campaign's primary progression loop.

## Design constraints

- Every resource needs meaningful sinks and trade-offs.
- Buildings must unlock production, not only provide passive bonuses.
- Unit roles must have readable tactical strengths and counters.
- Orders must be predictable, cancellable and path-aware.
- Enemy factions need economies, production and strategic goals; spawning larger waves is not a substitute.
- Conquest must change access to territory, resources and campaign options.
- The interface should expose selected units, command state, production and economy without covering the playfield.
- Save compatibility stays additive. Existing v17 saves must remain loadable during the transition.

## Migration sequence

### RTS-0 — Command foundation
- Detached camera with keyboard pan, edge pan, middle-button pan and wheel zoom.
- Single and drag selection of visible villagers.
- Shift-add/remove selection.
- Right-click move orders with simple group spacing.
- Right-click visible enemies, faction camps, campaign targets and strongholds to issue a soldier attack order.
- Right-click a rescue/escort/defend site to send a selected unit to activate it; escort convoys follow their route autonomously and remain vulnerable to enemy attacks.
- Existing worker AI resumes when a move order completes.
- Legacy player camera/control is disabled, but the node remains for save/reference compatibility.
- Build placement no longer depends on a single hero's proximity; territory and resources remain enforced.

### RTS-1 — Contextual orders
- Contextual gathering/building/repair orders for compatible worker roles.
- Attack-move, stop, hold position, patrol and garrison orders.
- Stop, hold position, patrol and garrison orders.
- Command queue and cancellation.

### RTS-2 — Production and military command
- Train units from production buildings.
- Population cap and upkeep decisions.
- Unit selection panels, health, role details and hotkeys.
- Control groups and formation spacing.

### RTS-3 — Strategic opponents
- Rival settlements with resource gathering and building production.
- Strategic scouting, defense, expansion and attack plans.
- Distinct faction economies and military compositions.

### RTS-4 — Campaign and conquest
- Regional goals, sieges, permanent territorial consequences and victory conditions.
- Classic/Frontier profiles rebalanced around RTS pacing rather than hero survival.

## Current limitation

RTS-0 is only the first command layer. Selection currently covers villagers. Direct move, soldier attack, and basic Frontier site interaction orders exist. There is not yet contextual resource gathering, building/repair orders, attack-move, formations, unit production, rival AI economies, or an RTS campaign balance pass.
