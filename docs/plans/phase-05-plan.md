# Phase 05 — Construction System and Building Production Chains

**Status:** Lumber Camp and Quarry resource-worksite slice merged through PR #19. Construction queue, staged completion and additional facilities remain open.
**Dependency:** Phase 04 Builder occupation; Phase 02 depot/logistics rules.
**Engine targets:** Godot 4.3 and 4.7.

## Goal

Make building placement a managed construction process. Builder labor must matter, construction sites must be readable, and each facility must have a distinct production, defense or campaign function.

## 05.2 — Construction queue
- Add a player-facing queue with explicit order, cost, placement validation and cancel/reorder behavior.
- Reserving a project must reserve its materials exactly once from an allowed connected/local depot; failed placement must not consume resources.
- Valid placement creates a construction site/blueprint with incomplete progress rather than an immediately functional finished building.
- Builders claim one active site at a time, work only within their workplace radius and use bounded pathfinding.
- Multiple Builders may accelerate one site only with a documented diminishing-return/cap rule; they must not duplicate progress.
- Construction advances on valid work ticks, not every idle frame, and pauses cleanly when blocked, starved or outside working conditions.
- Completed sites become their final building atomically, receive full collision/occupancy registration and emit the normal building-created events.
- Save/load persists queue order, reserved materials, site footprint, progress, worker claims and completion state.
- Cancellation refunds only unconsumed materials according to a fixed documented rule; destroyed sites resolve reservations without duplication.

## 05.3 — Facility dependency order
1. Watchtower: extends local vision and provides limited defensive coverage.
2. Granary: increases food storage and supports food-preservation/upkeep improvements.
3. Barracks: recruits/trains soldiers through time and resource costs; must respect population and capacity.
4. Hunting Lodge: provides Hunter workplace slots and access to wildlife harvest.
5. Infirmary: provides Healer workplace slots and recovery service.
6. Archery Range: unlocks or trains ranged defenders with explicit ammunition/cost rules.
7. Bridge/Gate upgrades: tactical access control without making road/bridge traversal ambiguous.
8. Market: deterministic conversion/trade between defined resources; no passive resource generation.
9. Siege Workshop: produces capped siege equipment with transport/deployment rules.
10. Stables: enables Beast Rider/cavalry recruitment only when its faction/counter system exists.
11. Fortress and Signal Beacon: late-game regional defense, command/visibility and campaign effects.

## Design constraints
- Every building needs data definition, footprint, valid terrain/claim rules, cost, health, art, UI/hotkey, unlock dependency, save coverage and a distinct gameplay purpose.
- Add new resources only with at least one producer, one consumer and a UI/save path.
- Avoid implementing all candidate buildings in one batch; merge one coherent dependency group at a time.
- Keep Classic building behavior stable unless a separately tested Classic balance change is intentional.

## Acceptance gate
- Construction consumes and refunds resources without duplication.
- Builder pathing/claims remain bounded and recover from invalid sites.
- Incomplete sites are visibly distinct and cannot provide finished-building behavior.
- Queue, site and worker state survive save/load and legacy migration.
- Each shipped facility has an automated regression test and rendered gameplay review.