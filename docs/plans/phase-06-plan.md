# Phase 06 — Factions, Enemy Archetypes and Territorial AI

**Status:** Partially implemented and merged into `main` through PR #21. Faction data, rosters, identity, Shaman support and faction persistence are present; distinct archetype policies, camps, patrols, raids, raid persistence and manual playtesting remain open.
**Mainline:** `main` (merged); use a fresh `feat/phase-06-completion-*` branch for the next implementation slice.
**Current save schema:** v12. Preserve Classic compatibility and validate migration from v1–v11 plus v12 round-trip.
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
- Save format v11 persists enemy faction identity alongside campaign/objective state; migration coverage must preserve Classic v1–v10 and Frontier v7–v10, with v12 round-trip.
- Regression test covers faction/region mapping, roster membership, garrison identity, tint, Shaman healing and save validation.

## Remaining implementation sequence

### 06.2 — Composable combat behaviors
- Extract movement, attack-pattern and ability policies from the enemy controller.
- Give Scout a scouting/marking behavior instead of treating it as a faster melee unit.
- Give Shieldbearer a directional guard/brace window with readable counterplay.
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
- Validate save migration from v1–v11 and round-trip v12 in Classic and Frontier.
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
