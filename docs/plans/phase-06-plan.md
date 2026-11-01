# Phase 06 — Factions, Enemy Archetypes and Territorial AI

**Status:** Partially implemented. Faction foundations and Shieldbearer directional brace are merged into `main` through PR #36 (`b02aa60`). The connector exposed 30 jobs on the first results page for workflow #41329202804; all 30 reported success, including parse and the visible regressions. The remaining matrix was not independently verified in that snapshot. Scout, Saboteur, Siege Engine and Beast Rider behavior policies, camps, patrols, raid extensions and manual playtesting remain open.
**Mainline:** `main`; current development branch: `feat/phase-06-scout-marking-mainline` (CI pending).
**Current save schema:** v13. Preserve Classic compatibility and validate legacy migrations through v13 plus v13 round-trip.
**Engine target:** Godot 4.3 and 4.7.

## Goal

Replace the single generic enemy identity with four regional powers whose units and battlefield behavior create different tactical problems. Keep Classic Mode's existing enemy roster and save compatibility intact.

## Delivered in the first slice

- Four stable faction IDs mapped to their Frontier regions: Greenwood Raiders, Iron Legion, Fen Cult and Ashen Host.
- Six new archetype definitions: Scout, Shieldbearer, Saboteur, War Shaman, Siege Engine and Beast Rider.
- Data-driven faction rosters and signature garrison units.
- Stronghold garrisons spawn from their faction roster; units carry faction identity and faction tint.
- War Shaman can heal nearby damaged allies with a bounded radius and cooldown.
- Shared enemy target selection and ally-support behavior extracted into reusable modules.
- Save format v13 persisted enemy faction identity; save v13 now also contains physical shipment, cost-source and supply-pressure state. Preserve Classic v1–v13 and Frontier v7–v13 migration/round-trip coverage.
- Regression test covers faction/region mapping, roster membership, garrison identity, tint, Shaman healing and save validation.

## Remaining implementation sequence

### 06.2 — Composable combat behaviors (partial; Shieldbearer delivered)
- Extract movement, attack-pattern and ability policies from the enemy controller.
- [ ] Scout scouting/marking: implemented on `feat/phase-06-scout-marking-mainline`; a telegraphed mark is shared only with same-faction enemies in a bounded radius, prioritizes the marked defender until expiry, and can be interrupted by stagger or target disengagement. CI pending.
- [x] Shieldbearer directional brace merged through PR #36 (`b02aa60`): data-defined wind-up, locked facing, finite active window and frontal damage mitigation; side/rear hits bypass the block. Player attacks, Cleave, Dash and tower arrows pass their impact origin. Stagger interrupts the brace; disengaging during wind-up cancels it. `tests/shieldbearer_behavior.gd` appeared in the available successful job list; the complete 4.3/4.7 matrix was not independently verifiable from that snapshot.
- Shieldbearer and Scout behavior state is transient; no save-schema bump is required.
- Give Saboteur an explicit building-priority target policy and disruption effect.
- Give Siege Engine a distinct siege wind-up/impact cycle and building-only preference.
- Give Beast Rider a telegraphed charge that can be interrupted or baited.
- Keep War Shaman support separate from its ranged attack loop.

### 06.3 — Camps and patrols
- Place deterministic camps in faction-owned territory using reachable, unoccupied cells.
- Camps own a bounded spawn budget, patrol radius and reinforcement cooldown.
- Patrol routes stay inside the faction's territory and return to camp when the leash is exceeded.
- Camps are discoverable through existing fog-of-war; unseen enemies must not leak into the strategic map.

### 06.4 — Raids and counterattacks
- Raid targets are selected from exposed player Outposts, connected roads and depots.
- Use bounded target scans, cooldowns, unit caps and path-reachability checks.
- Abort or retarget when the target is conquered, removed, unreachable or no longer vulnerable.
- Do not add supply attrition until local stockpiles/inter-depot transfers exist.

### 06.5 — Persistence, balance and verification
- Persist camp state, raid cooldowns, patrol assignments and enemy faction identity.
- Validate save migration through v1–v13 and round-trip v13 in Classic and Frontier.
- Add stress tests for large simultaneous garrisons, patrols and raids.
- Run all tests and parse checks on Godot 4.3 and 4.7.
- Review screenshots and play the Frontier campaign manually before calling Phase 06 complete.

## Invariants

- Classic remains a 64×64, 15-day experience with its existing wave roster and legacy stronghold behavior.
- Frontier factions are assigned by stable region/faction IDs, never inferred from display names.
- Faction and archetype definitions remain data-driven.
- No unbounded enemy spawning, global per-frame full-map scans, or uncapped target searches.
- Existing save versions must not be silently rewritten or rejected solely because faction fields are absent.
- Do not mark Phase 06 complete until all six archetypes have distinct counterable behavior, camps/patrols/raids/counterattacks persist, stress tests pass, both Godot CI versions pass, and manual Frontier playtesting is recorded.
