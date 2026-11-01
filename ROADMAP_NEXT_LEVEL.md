# Hold the Keep — Next-Level Kingdom Expansion Roadmap

**Status (2026-11-02):** Phase 00, 01, 03 and the initial slices of 02, 04, 05, 06, 07, 09 and 10 are merged into `main`. Phase 02, 04, 05 and 06 remain partially implemented; Phase 08 has not been implemented as a distinct delivery. PR #35 merged Phase 02.5 supply pressure; PR #36 merged Shieldbearer brace; PR #39 merged Scout marking; PR #40 merged Saboteur disruption. PR #41 merged Siege Engine siege cycle (`58da7be`); workflow #41356689758 passed 62/62 jobs on Godot 4.3/4.7, including 29 regression suites per engine, import/parse, Frontier performance and Windows/Linux export. Manual rendered gameplay gates remain open.
**Phase 02 merge commits:** PR #31 (`6dcea7921f8f40eba17a1d2ca466a5f3e5b18fe8`) delivered local depot storage/transfers; PR #32 (`2f94959b497677eae49d4303f72322650fb591c2`) delivered garrisons/inspection; PR #33 (`5d7db56b3a51a25541f541bb46c19b26996d22be`) delivered player-directed physical shipments and save v13. PR #33 validation: [workflow #41323062111](https://github.com/shimleabyte/hold-the-keep/actions/runs/41323062111), 50/50 jobs successful on Godot 4.3/4.7, including 23 regressions per engine, Frontier diagnostic and Windows/Linux export.  
**Baseline:** Godot 4.3+ / GDScript, Classic world 64×64 / 15 days, Frontier world 128×128 / 20 days / 4 acts, mainline save format v13 with backward compatibility for save versions v1–v12.

## 1. Product direction

Evolve Hold the Keep from a compact village-defense/action-combat game into a **frontier kingdom strategy game**. Preserve direct player control and the existing defensive loop, but add meaningful exploration, regional ownership, settlements, supply networks, faction warfare and multi-stage conquest.

**World identity:** Grim Medieval Folklore Fantasy. Grounded hardship—food, labor, disease, weather, trade and human conflict—is the foundation. Folklore shapes regional culture and player interpretation. Confirmed supernatural threats are rare, telegraphed, consequential and counterable; they must not turn the game into a constant monster-clearing loop. The binding design reference is [docs/WORLD_AND_GAMEPLAY_BIBLE.md](docs/WORLD_AND_GAMEPLAY_BIBLE.md).

The product must retain its hybrid identity: the player directly fights and explores while managing a settlement and its supply network. Classic remains the approachable entry point; Frontier carries the broader conquest and regional campaign. Complexity is layered through onboarding and sensible defaults rather than exposed all at once.

The central loop becomes:

1. **Establish** a defensible homeland and a functioning settlement economy.
2. **Explore** surrounding biomes, resource deposits, ruins, camps and enemy territory.
3. **Expand** through connected outposts, roads, local storage and supply routes.
4. **Conquer** hostile camps and strongholds to secure regional objectives.
5. **Fortify** the growing kingdom against raids, counterattacks and increasingly dangerous sieges.

Classic Mode remains available. The expanded campaign must not silently reinterpret existing saves.

## 2. Target scope

| Area | Target |
|---|---|
| Frontier world | 128×128 tiles (4× current tile count) |
| Logical generation sectors | 32×32 tiles; initially keep the full map loaded |
| Tile size | 16×16 pixels |
| Initial terrain biomes | 5: Hearthland, Greenwood, Highlands, Fenlands, Ashen March |
| Special subregion | Old Frontier: ruin-dense exploration zone, not a sixth base biome |
| Starting Keep claim | 15-tile radius in Frontier profile |
| Starting economy | Preserve existing jobs/resources first; rebalance only with test evidence |
| Factions | 4: Greenwood Raiders, Iron Legion, Fen Cult, Ashen Host |
| New enemy archetypes | 6 initial designs: scout, shieldbearer, saboteur, war shaman, siege engine, beast rider |
| Added villager roles | Builder, hunter, scout, healer, blacksmith |
| New building concepts | Lumber Camp, Watchtower, Granary, Barracks, Quarry, Archery Range, Hunting Lodge, Infirmary, Bridge/Gate, Market, Siege Workshop, Stables, Fortress, Signal Beacon |
| Conquest campaign | 20 days, 4 acts, multiple regional strongholds |
| Classic Mode | Preserve the current 64×64 / 15-day experience |

Building concepts are candidates, not a commitment to ship all of them at once. Each must introduce a useful gameplay interaction or production dependency.

## 3. Architectural rules

### World model
- Replace duplicated map-size/tile-size constants with one `WorldConfig` source.
- Use named world profiles. `classic` remains the shipped default until the Frontier profile passes the migration gates.
- Derive terrain, occupancy, territory, fog, pathfinding, spawn bounds, camera limits and map UI dimensions from the active profile.
- Keep generation deterministic from a saved world seed.
- Treat 32×32 sectors as logical generation/ownership units first. Do not add runtime streaming before profiling proves it is needed.

### Save compatibility
- Existing save versions 1–6 belong to the original 64×64 Classic world.
- Save v7 records profile ID, map dimensions, tile size and world seed.
- Legacy saves remain loadable in Classic. They must be rejected with a clear explanation in Frontier rather than being projected onto a different world.
- Before Frontier becomes selectable, add migration tests for fog, resources, buildings, units, strongholds and campaign state.

### Systems design
- Territory must become region-aware and support neutral, player, enemy and contested states.
- Claims, supply connectivity and fog-of-war are separate concepts. Owning a tile does not automatically make it supplied or currently visible.
- Enemies must be driven by faction/archetype data and modular behavior, not an expanding chain of special cases in one controller.
- Jobs must use workplaces, local work areas, storage access and explicit assignment rules.
- Strongholds must be represented as multiple campaign objectives, not one singleton `enemy_keep`.
- Keep data-driven definitions for buildings, enemies, waves, technologies and campaign objectives.

## 4. Phased implementation

### Phase 00 — Foundation and verification
**Status:** Complete and merged into `main`; legacy profile migration covered by `world_config` and `release_hardening` on Godot 4.3/4.7.

- [x] Add this roadmap and link it from project documentation.
- [x] Add Godot CI on Godot 4.3 and 4.7.
- [x] Add parse-only validation for every GDScript file.
- [x] Add one headless regression runner with deterministic 60 FPS.
- [x] Centralize world profiles, dimensions, tile size, seed, starting Keep position and profile-level resource density.
- [x] Migrate all spatial systems away from duplicated 64×64 constants while keeping Classic active.
- [x] Bump save format to v7 and persist world identity.
- [x] Prove v1–v6 saves remain valid in Classic and are rejected for non-Classic profiles on both engine versions.

**Acceptance gate — passed**
- Both CI engine versions import the project, parse every script and complete all assertion-based regression jobs.
- Classic remains 64×64 with its existing generation path, seed, Keep placement, spawn placement and territory radius.
- Save v7 round-trips world metadata; v1–v6 legacy saves validate in Classic and are rejected for Frontier loading.
- Frontier remains an explicit new-campaign choice; Classic stays the shipped default.

### Phase 01 — Expanded deterministic world
**Status:** Complete and merged into `main`; five deterministic Frontier biomes and Classic preservation are covered by CI.

- [x] Add explicit Classic/Frontier selection to the new-campaign panel and persist the selected profile.
- [x] Generate five warped regions: Hearthland, Greenwood, Highlands, Fenlands and Ashen March.
- [x] Add biome-specific tree/rock density, patch noise and profile-scaled iron-vein clusters.
- [x] Give Ashen March its own terrain atlas tile.
- [x] Apply the 15-tile Keep claim and keep resource nodes outside the enlarged home clearing.
- [x] Preserve the original Classic terrain and resource-generation paths.
- [x] Verify resource density, path reachability, deterministic output, selector behavior and map bounds in Godot 4.3/4.7.
- [x] Verify the 128×128 fog/save index round-trip and cross-profile save backup behavior.

**Acceptance gate — passed:** deterministic generation, valid walkability, resource distribution, safe Keep footprint, reachable stronghold approach, valid map bounds, viewport fit and 128×128 fog/index round-trip.

### Phase 02 — Territory, roads and supply
**Status:** Regional control/road/connected-depot foundation merged into `main`. PR #31 adds bounded local stockpiles and automatic Keep-bound shipments under save v12. PR #32 is merged and adds read-only Storage/Outpost stock inspection and local Outpost garrisons (two slots, assignment UI, 128-pixel defense leash, lifecycle/save integration); its 48/48 Godot CI gate passed. Local Outpost vision and observed-only enemy markers already exist on `main`. PR #33 merged player-directed physical orders, escrowed cargo, route recovery and save v13; Godot 4.3/4.7 CI passed 50/50. PR #34 merged direct source-depot spending for construction/research/repair. Payments are isolated to one selected connected depot, never pooled, and the optional source preference is persisted additively in save v13. Workflow #41325205416 passed 52/52 jobs. Phase 02.5 supply pressure is implemented on `feat/phase-02-supply-pressure`; warning/raid/attrition and persistence regression is added, PR/CI pending.

- [x] Aggregate land claims into neutral/player/enemy/contested regional control records.
- [x] Emit regional control changes independently from fog-of-war exploration.
- [x] Add road and bridge construction definitions, pixel assets and HUD icons.
- [x] Allow bridge placement on valid water cells inside player claims.
- [x] Keep roads and bridges walkable in villager A* and enemy flow-field routing.
- [x] Build a cardinal road graph rooted at the Keep and expose connected road/depot state.
- [x] Treat Keep, Storage and Outposts as depots; Outposts are forward depots.
- [x] Restrict worker deposits to Keep-connected depots and retain cargo when a route disconnects.
- [x] Add Storage (180 units) and Outpost (120 units) local stockpile capacities; Frontier workers credit the chosen depot rather than silently increasing central Keep inventory.
- [x] Persist local depot balances in save v12 with resource-kind, non-negative quantity and capacity validation; preserve v1–v11 migration defaults.
- [x] Show explored roads and regional control state on the strategic map.
- [x] Cover ownership states, road/bridge traversal, depot connectivity/disconnection, isolated Outposts and road save persistence.
- [x] Pass the Godot 4.3/4.7 CI matrix, including the regional integration test (run `41289421611`, 24/24 jobs).
- [x] Implement Outpost guard assignment/garrison support (PR #32 merged; Godot 4.3/4.7 CI passed); local vision and observed-only map markers were already implemented on `main`.
- [x] Add bounded periodic transfer of up to 6 local units per connected depot to Keep Inventory every 3 seconds, with rotating resource-kind priority; disconnected depot stock stays local.
- [x] Add read-only local stock inspection for Storage/Outposts through `JOBS → POS` (PR #32 merged; CI passed).
- [x] Implement player-directed shipment orders between Keep/Storage/Outposts with visible carriers, immediate cargo reservation, Keep-bound withdrawals, cancellation/refund and interruption recovery (PR #33 merged; Godot 4.3/4.7 CI passed 50/50).
- [x] Add explicit Keep/Storage/Outpost cost-source selection for construction, research and repairs; debit only the selected depot, reject disconnected sources, and do not pool partial balances across depots. Persist the preference as an optional additive field in save v13 (PR #34 merged; Godot 4.3/4.7 workflow #41325205416 passed 52/52).
- [ ] Phase 02.5 implementation: remote Storage/Outpost depots that are disconnected and lie in enemy/contested control receive a 30s warning; targeted saboteurs dispatch after 60s and at most one repeat wave 150s later (max 2 per isolation). Saboteurs attack depot integrity and steal one unit every second successful depot hit in deterministic resource priority. Reconnect roads or reclaim territory to recall raiders. Branch `feat/phase-02-supply-pressure`; CI pending.

**Initial slice acceptance gate — passed:** regional ownership is independent of fog and supply; road/bridge routes remain navigable; depot connectivity updates when roads are built or removed; disconnected depots cannot receive inventory deposits; infrastructure persists in saves.

### Phase 03 — Multi-stronghold campaign
**Status:** Implemented and merged into `main`; multi-stronghold regression CI passed on Godot 4.3 and 4.7.

- [x] Replace the single enemy stronghold reference with an ordered campaign objective/stronghold registry.
- [x] Support four region-specific Frontier strongholds with independent local garrisons and reinforcement caps.
- [x] Make objective order deterministic; each conquered region unlocks the next objective and grants a regional resource reward.
- [x] Persist the full objective registry, stronghold health and conquest state in save format v8; retain v1–v7 single-stronghold compatibility.
- [x] Preserve the existing one-stronghold Classic campaign.
- [x] Complete the Godot 4.3 / 4.7 regression matrix; objective/map presentation still needs a human gameplay review.

**Acceptance gate:** multiple strongholds can be found, attacked, destroyed, restored from saves and completed in a deterministic objective sequence.

### Phase 04 — Jobs and workplaces
**Status:** First Builder/workplace slice is merged into `main`; workplace regression CI passed on Godot 4.3 and 4.7.

- [x] Introduce Builder as a real labor occupation; soldier is stored separately as a military specialization, with a compatibility `job` alias.
- [x] Add Builder workplace capacity on Keeps and Outposts, plus data-driven work radii.
- [x] Add resource-backed repairs for damaged player buildings; one Builder claims a repair target at a time.
- [x] Limit resource/farm task selection to the work radius of a connected depot.
- [x] Select the nearest reachable connected depot rather than stopping at an unreachable nearest depot.
- [x] Add configurable job priority order, reassignment, Alt+job hotkeys and right-click controls in the job panel.
- [x] Persist occupation, military specialization and priority order in save format v9; older saves still load through the compatibility job field.
- [ ] Add Hunter, Scout, Healer and Blacksmith in subsequent incremental slices.
- [x] Complete Godot 4.3 / 4.7 CI regression matrix; real gameplay pathing still needs a manual playtest.

**Acceptance gate:** workers select valid tasks, avoid cross-map wandering, recover from blocked paths, deposit at reachable storage and retain their state through saves.

### Phase 05 — Buildings and production chains
**Status:** Initial resource-worksite slice merged through PR #19; the full buildings/production phase remains in progress. Latest main CI passes; construction queue and manual economy/pathing review remain.

- [x] Add a Lumber Camp with two woodcutter workplace slots and an 18-tile resource work radius.
- [x] Add a Quarry with two miner workplace slots and a 16-tile resource work radius.
- [x] Bind woodcutters/miners to matching worksites; retain connected-depot fallback only when no matching specialty site exists.
- [x] Release worksite claims when workers leave or a worksite is removed; worksite buildings use the generic save payload and remain compatible with save v12.
- [x] Add separate pixel-art buildings/icons, hotbar entries, numeric hotkeys, controls documentation and headless regression coverage.
- [ ] Add construction work queues and staged building completion with Builder labor.
- [ ] Add remaining facilities according to dependency: Watchtower, Granary, Barracks, Archery Range, Hunting Lodge, Infirmary, Bridge/Gate, Market, Siege Workshop, Stables, Fortress and Signal Beacon.
- Introduce leather and gold only when a building or campaign system consumes them.
- Add construction/repair work, military training, trade and siege production as separate validated slices.

**Acceptance gate:** every building has a distinct function, valid footprint, data definition, art asset, UI representation, unlock rule and save/load coverage.

### Phase 06 — Factions, enemy archetypes and territorial AI
**Status:** First faction/archetype runtime slice merged into `main` through PR #21; Phase 06 remains partially implemented.

- [x] Add four data-driven factions mapped to Frontier regions, with stable IDs, faction colors, rosters and signature garrison units.
- [x] Add six archetype definitions: scout, shieldbearer, saboteur, war shaman, siege engine and beast rider.
- [x] Spawn stronghold garrisons from faction rosters and tag regional wave enemies with faction identity.
- [x] Add faction tint, War Shaman ally healing, shared target-selection/support modules and enemy faction save persistence; current save schema is v13.
- [x] Add faction registry validation and regression coverage for region mapping, rosters, garrisons, support and save validation.
- [ ] Extract movement, attack-pattern and ability policies into composable modules; give each archetype its own counterable behavior.
- [x] Siege Engine siege cycle merged via PR #41 (`58da7be`); workflow #41356689758 passed 62/62 jobs on Godot 4.3/4.7.
- [x] Saboteur building disruption merged via PR #40 (`8f1a914`); workflow #41355982522 passed 60/60 jobs on Godot 4.3/4.7.
- [x] Scout scouting/marking merged via PR #39 (`11f3f13`); workflow #41354720293 passed 58/58 jobs on Godot 4.3/4.7.
- [x] Shieldbearer directional brace merged via PR #36 (`b02aa60`); the available first results page for workflow #41329202804 showed 30/30 successful jobs; full matrix not independently verified.
- [ ] Add deterministic faction camps, bounded patrol routes and camp reinforcement budgets.
- [ ] Expand raids/counterattacks against exposed Outposts, roads and depots only after Phase 02.5 acceptance; current slice targets remote depots, uses nav reachability, and caps at two saboteurs per isolation.
- [ ] Persist camps, patrol assignments and raid state; validate Classic v1–v13 and Frontier v7–v13 migration/round-trip.
- [x] Merged through PR #21; Godot 4.3 / 4.7 CI passed (30/30 jobs).
- [ ] Manual Frontier gameplay review.

**Acceptance gate:** each archetype creates a distinct tactical response; AI remains bounded under stress tests; factions obey territory and campaign state; save/load and both engine CI versions pass.

### Phase 07 — Technology and campaign objectives
**Status:** Implementation merged through PR #28. Current mainline workflow #41314731305 passed 46/46 jobs; rendered/manual difficulty and campaign review remain open.

- [x] Expand the technology tree from 17 to 20 nodes without changing existing technology IDs or prerequisites.
- [x] Add a Frontier 20-day / 4-act ruleset while preserving Classic's 15-day / 3-stage rules.
- [x] Add eleven ordered regional objectives: four biome discoveries, camp/ruin clearing, rescue, escort and night defense.
- [x] Persist objective state, site health/location, escort progress and final-boss state in save v12; retain v1-v11 compatibility.
- [x] Gate Frontier victory behind all required regional objectives, all four strongholds and the day-20 King; preserve Classic victory rules.
- [x] Add the objective tracker (O), E interaction help, discovered objective markers on the TAB strategic map, and subdued visuals for locked acts.
- [x] Fix escort reload path reconstruction; make Cartography improve Outpost reveal and Siegecraft improve player damage against active strongholds/sites across profiles.
- [x] Add regression checks for objective locks, escort save/reload, Cartography, Siegecraft and the real day-20 King death path.
- [x] Complete Godot 4.3 / 4.7 import/parse and regression matrix (30/30 jobs passed).
- [ ] Perform rendered gameplay review at target desktop resolutions and tune difficulty from an actual playthrough.

**Acceptance gate:** every objective type resolves, rewards/state survive save/load, act transitions follow the Frontier schedule, Classic remains unchanged, player-facing objective/map state is readable, and Frontier victory cannot occur before required objectives and the final encounter.

### Phase 08 — Visual and audio identity
**Status:** Planned; no separate Phase 08 implementation was merged. The old `feat/phase-08-visual-audio-identity` ref was a stale ancestor of Phase 07, not a unique Phase 08 delivery.

- Create distinct biome tiles, environmental props, landmarks and faction assets.
- Give new units unique silhouettes, weapons, animations and hit feedback.
- Add building art for each new structure rather than reusing generic placeholders.
- Improve strategic-map overlays for terrain, ownership, resources, roads, supply, enemy settlements and objectives.
- Add environmental and combat audio after gameplay triggers stabilize.

**Acceptance gate:** screenshot passes at target desktop resolutions; visual readability under day/night, fog and combat load; no placeholder-only faction identity in release content.

### Phase 09 — Balance, performance and release hardening
**Status:** Automated hardening and Godot 4.3/4.7 export CI merged through PR #29. Current mainline workflow #41314731305 passed 46/46 jobs. Target-hardware profiling, complete campaign playtest, Windows runtime and clean-machine verification remain open.

- [x] Add configurable Classic/Frontier profiling for p50/p95/p99 process, physics and wall-frame timing, static memory, node count, projectiles and particles.
- [x] Add bounded Frontier stress coverage for four factions, mixed rosters, villagers, ranged projectiles and the 500-particle ceiling.
- [x] Add deterministic Classic/Frontier campaign balance matrix for stage/act transitions, wave budgets and final-boss gates.
- [x] Add Frontier campaign reload coverage for completed objectives, unlocked acts, escort path progress and damaged strongholds.
- [x] Add save migration/recovery tests for Classic v1–v12 and Frontier v7–v12, interrupted temporary writes, backup rotation and profile isolation.
- [x] Run the Godot 4.3/4.7 import, parse and regression matrix on the original stacked branch.
- [x] Export Windows/Linux in CI using Godot 4.3 templates; validate Windows PE output and smoke-test Linux.
- [ ] Measure the reference workload on actual target desktop hardware before making performance optimization claims.
- [ ] Add combat outcome simulations at the end of all four Frontier acts and on day 20.
- [ ] Extend reload tests to later acts, conquered strongholds and the final-boss gate.
- [ ] Complete human playtesting across all campaign acts.
- [ ] Verify Windows runtime and clean-machine save/settings migration.

**CI diagnostic (not target hardware):** Frontier 128×128, 119 active enemies, 82 villagers, six peak projectiles and 500 peak particles; wall-frame p50 4.27 ms / p95 10.45 ms / p99 13.55 ms. A process-monitor p95 outlier of 102.24 ms was also recorded; these figures are runner-specific, not an accepted target-hardware budget.

**Remaining acceptance work:** measured target-hardware performance, later-act/day-20 combat outcome simulations, full multi-act human playtest, Windows runtime on a real Windows machine, and clean-machine save/settings migration.
### Phase 10 — Resolution-matched viewport and HUD safe area
**Status:** Adaptive viewport implementation merged through PR #30. Current mainline workflow #41314731305 passed 46/46 jobs, including responsive layout tests. Physical-display screenshots and manual fullscreen review remain open.

- [x] Derive logical viewport dimensions from actual client-window size at exact 2× pixel scale, with a 480×270 minimum.
- [x] Use 640×360 at 1280×720 and cover 960×540, 1280×800, 1366×768, 1600×900 and 1920×1080.
- [x] Detect native window resizing and emit an explicit viewport event for HUD/technology UI.
- [x] Keep camera zoom, 16×16 tiles, movement/combat ranges, world profiles and save schema unchanged.
- [x] Add six-resolution mapping, live synchronization, camera zoom, HUD safe-area, map and hotbar regression checks.
- [x] Run fresh Godot 4.3/4.7 import, parse and all assertion suites on the mainline branch (workflow #292, 30/30 jobs).
- [ ] Inspect rendered screenshots and play at physical desktop resolutions plus fullscreen.

**Remaining acceptance work:** inspect rendered screenshots and play at physical desktop resolutions plus fullscreen; confirm HUD readability on the target laptop/display.

## 5. First implementation priorities

1. **Phase 00 is mandatory.** Do not add content on top of duplicated spatial constants and unverified scripts.
2. Build the Frontier world before adding all new enemies/jobs/buildings.
3. Add roads and supply before introducing remote settlements that depend on logistics.
4. Add workplace infrastructure before expanding the job list.
5. Add faction-specific AI before scaling the wave count.
6. Keep each phase in a reviewable branch/PR and do not merge a phase with failing parse or regression checks.

## 6. Explicit non-goals for the first expansion

- No 256×256 map before 128×128 is profiled and stable.
- No runtime chunk streaming before evidence requires it.
- No multiplayer or online services.
- No large content dump of units/buildings without distinct mechanics and tests.
- No removal of Classic Mode or silent conversion of old saves.
- No wholesale rewrite of the game loop unless a measured architectural constraint requires it.

## 7. Decision log

- The expansion is a strategy-layer evolution, not a replacement of the existing action-combat identity.
- Frontier target size is 128×128; Classic remains 64×64.
- The larger starting territory is a 15-tile Keep radius, not an unrestricted starting half-map.
- Five terrain biomes are the initial target; Old Frontier is a ruin-rich subregion theme.
- Phase 00 was merged into `main` through PR #7. Phase 01 is based directly on `main` in `feat/frontier-world-generation-mainline` (PR #10).
