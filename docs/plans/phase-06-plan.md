# Phase 06 — Factions, Enemy Archetypes and Territorial AI

**Status:** Partially implemented. Faction foundations, all delivered combat archetype slices, Phase 06.3 camps/patrols and Phase 06.4 infrastructure raids are merged into `main`. PR #44 (`5cc5084`) merged raids; workflow #41381487306 passed 68/68 jobs on Godot 4.3/4.7.
**Mainline:** `main`. Phase 06.4 is merged; Phase 06.5 combined warfare stress verification is on `feat/phase-06.5-faction-warfare-stress`.
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

### 06.2 — Composable combat behaviors (partial; Shieldbearer, Scout, Saboteur and Siege Engine delivered)
- Extract movement, attack-pattern and ability policies from the enemy controller.
- [x] Scout scouting/marking merged through PR #39 (`11f3f13`): a telegraphed mark is shared only with same-faction enemies in a bounded radius, prioritizes the marked defender until expiry, and can be interrupted by stagger or target disengagement. `tests/scout_marking.gd` passed on Godot 4.3 and 4.7; workflow #41354720293 passed 58/58 jobs.
- [x] Shieldbearer directional brace merged through PR #36 (`b02aa60`): data-defined wind-up, locked facing, finite active window and frontal damage mitigation; side/rear hits bypass the block. Player attacks, Cleave, Dash and tower arrows pass their impact origin. Stagger interrupts the brace; disengaging during wind-up cancels it. `tests/shieldbearer_behavior.gd` appeared in the available successful job list; the complete 4.3/4.7 matrix was not independently verifiable from that snapshot.
- Shieldbearer, Scout and Saboteur behavior state is transient; no save-schema bump is required.
- [x] Saboteur building disruption merged through PR #40 (`8f1a914`): bounded rotating scans prioritize Tower/Outpost, then Storage, production and House, weighted against reachable nav paths. A telegraphed wind-up applies reversible temporary suppression and limited structure damage; interception/stagger can interrupt. Towers stop firing; depots reject transfers; workplaces pause tasks until recovery. `tests/saboteur_disruption.gd` passed on Godot 4.3/4.7; workflow #41355982522 passed 60/60 jobs.
- [x] Siege Engine siege cycle merged through PR #41 (`58da7be`): bounded rotating scans prioritize stone/wood walls, then Tower/Outpost/Keep and Storage, weighted against reachable path length. It advances through flow-field cells, moves to adjacent target cells, telegraphs a heavy structure-only impact and enters recovery. Nearby defenders/player pressure or stagger interrupt the wind-up. `tests/siege_engine_behavior.gd` passed on Godot 4.3/4.7; workflow #41356689758 passed 62/62 jobs.
- [x] Beast Rider telegraphed charge merged via PR #42 (`e6cf221`): bounded scan prefers isolated defenders; A* approach and locked walkable charge route; 0.82s tell; sidestep miss, nav-version/stagger cancellation, one impact and 6.5s recovery. `tests/beast_rider_charge.gd` passed on Godot 4.3/4.7; workflow #41366304675 passed 64/64 jobs.
- Keep War Shaman support separate from its ranged attack loop.

### 06.3 — Camps and patrols
- [x] Four deterministic faction camps placed on reachable, unoccupied enemy-owned cells in their region near regional strongholds; existing campaign `clear_camp` objectives remain separate.
- [x] Camp targets stay hidden before fog reveal, appear on the strategic map after discovery, and can be inspected/destroyed by player melee attacks.
- [x] Faction-specific patrol unit, radius, initial count, active cap, finite reinforcement budget and cooldown are data-driven in `data/factions.json`.
- [x] Patrols use A* routes validated against faction region, enemy ownership and leash; patrols return to camp when the leash is crossed.
- [x] Territorial loss suppresses camps and recalls linked patrols; camp destruction removes patrols and permanently disables reinforcement.
- [x] Camp HP/destruction, activation/suppression, budget/timer/spawn index and patrol assignment are optional save-v13 fields; no schema bump.
- [x] Regression `tests/faction_camps_patrols.gd` passed on Godot 4.3/4.7; PR #43 (`fa3a45a`) merged and workflow #41377840888 passed 66/66 jobs.

### 06.4 — Faction raids and infrastructure counterattacks (merged via PR #44; workflow #41381487306 passed 68/68)
- Frontier faction camps now dispatch finite, faction-native raid squads at exposed infrastructure in their own region: connected Outposts/Storage first, then connected roads/bridges.
- Each camp has a data-driven raid unit, finite budget, cooldown and active cap. A global cap, 48-node candidate scan, rotating road cursor, top-eight A* reachability checks and 760-pixel origin range bound the workload.
- Raids use explicit target identity and nav-adjacent paths. Raiders defend themselves against the player and visible defenders, damage structures through the normal building API, and steal one local depot resource every second successful depot hit.
- Targets are revalidated while moving and attacking. Reconnection, territorial reclamation, region change, destruction, removal or loss of path causes withdrawal. Camp destruction or territorial suppression also recalls that camp's raiders.
- Faction raid unit roles use the faction's native patrol identity (bandit, archer, wolf, brute), so the raid controller does not silently bypass a specialist archetype's signature AI.
- Raid budget/cooldown and active raider target kind, camp, region and hit progress are optional v13 fields; existing disconnected-depot pressure raids remain separate and unchanged.
- Regression `tests/faction_raids.gd` covers connected depot selection, finite dispatch, structure damage, deterministic theft, save validation/restoration, territory reclaim, road targeting and removal cleanup. It passed on Godot 4.3/4.7 in workflow #41381487306; complete workflow passed 68/68.

### 06.5 — Persistence, balance and verification
- [x] Persist camp state, patrol assignments, raid budgets/cooldowns, active raid target and faction identity as additive save-v13 fields.
- [x] Validate Classic save migration fixtures v1–v13 and Frontier fixtures v7–v13 in `tests/release_hardening.gd`; active raid serialization/restoration is covered by `tests/faction_raids.gd`.
- [x] Add combined stress coverage for large simultaneous garrisons, patrols and raids. Regression `tests/faction_warfare_stress.gd` was merged via PR #45 (`83dd633`): 48 garrisons, eight patrols, four concurrent faction raids and 48 villagers, with A* and save-v13 assertions. The first post-merge workflow failed at line 214 due to a literal escaped newline; corrective PR #46 fixes the syntax and is running CI.
- [ ] Run the full assertion suite and parse checks on Godot 4.3 and 4.7 after the combined stress test is merged.
- [ ] Review screenshots and play the Frontier campaign manually before calling Phase 06 complete.

## Invariants

- Classic remains a 64×64, 15-day experience with its existing wave roster and legacy stronghold behavior.
- Frontier factions are assigned by stable region/faction IDs, never inferred from display names.
- Faction and archetype definitions remain data-driven.
- No unbounded enemy spawning, global per-frame full-map scans, or uncapped target searches.
- Existing save versions must not be silently rewritten or rejected solely because faction fields are absent.
- Do not mark Phase 06 complete until all six archetypes have distinct counterable behavior, camps/patrols/raids/counterattacks persist, stress tests pass, both Godot CI versions pass, and manual Frontier playtesting is recorded.


### Beast Rider charge implementation (2026-11-02)
- Branch: `feat/phase-06-beast-rider-charge`, based on main `666b9fc` after PR #41.
- Beast Rider scores visible player/defender candidates in a bounded scan, preferring isolated soldiers over supported clusters. Its approach and charge route use the shared A* navigation grid.
- A 0.82s telegraph locks a walkable route to the target's current tile. The charge does not steer mid-run; sidestepping can cause a miss. A changed nav version or stagger cancels the charge. Successful impact applies one bounded hit and a short push, then enters a 6.5s cooldown.
- Charge tuning is data-driven in `data/enemy_archetypes.json`; ability state is transient and save schema v13 is unchanged.
- Regression `tests/beast_rider_charge.gd` covers isolation priority, wall-aware route, telegraph timing, impact damage, sidestep miss and stagger interruption; it passed on Godot 4.3/4.7 in workflow #41366304675 (64/64 jobs).


### Faction camp and patrol implementation (2026-11-02, review branch)
- Branch: `feat/phase-06-faction-camps-patrols`, based on main `8a5c6e5` after PR #42.
- New `scripts/systems/faction_camps.gd` owns one deterministic camp per Frontier faction. Sites are selected from reachable, unoccupied enemy-owned cells in their faction region near the regional stronghold, with clearance from campaign sites.
- Camps are hidden until fog discovery. Discovery reveals the camp target, deploys its initial patrols and adds an observed-only strategic-map marker. Existing enemy unit markers retain the currently-observed rule.
- Camp structures are destructible with player melee. Destruction recalls linked patrols, exhausts budget and stops future spawns. Losing enemy control suppresses the camp and recalls its patrols.
- Patrols use A* and validate route cells against faction region, enemy ownership and camp leash. They only select targets inside the leash and return to camp when the leash is exceeded.
- Per-faction tuning in `data/factions.json`: patrol archetype, radius, initial count, active cap, reinforcement budget and cooldown.
- Camp health/destruction/activation/suppression and active patrol assignment persist as optional save-v13 data; old v13 saves remain valid without migration.
- Regression `tests/faction_camps_patrols.gd` is registered in `tools/run_tests.sh` and both Godot CI matrices. PR/CI pending.


### Faction camp and patrol implementation (2026-11-02, merged via PR #43)
- Branch: `feat/phase-06-faction-camps-patrols`, based on main `8a5c6e5` after PR #42; squash merge commit: `fa3a45a`.
- One deterministic camp per Frontier faction is placed on reachable, unoccupied enemy-owned cells near its regional stronghold. Camps are hidden until fog discovery, then become destructible player targets and appear on the strategic map.
- Each faction defines patrol archetype, radius, initial patrol count, active cap, finite reinforcement budget and cooldown. Patrols use bounded A* routes constrained by region, enemy territory and leash; after leash breach they stop pursuing and return to camp.
- Territorial loss suppresses camps and recalls patrols. Destroying a camp recalls its patrols, exhausts the budget and permanently prevents new reinforcement.
- Camp health/destruction/discovery/suppression and patrol assignment persist as optional save-v13 fields; no schema bump and old v13 saves remain valid.
- Regression `tests/faction_camps_patrols.gd` passed on both engines. Workflow [#41377840888](https://github.com/shimleabyte/hold-the-keep/actions/runs/41377840888) passed 66/66 jobs: 31 regression suites per engine, import/parse, Frontier performance diagnostic and Windows/Linux export.
