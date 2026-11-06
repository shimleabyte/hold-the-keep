# Hold the Keep — Next-Level Kingdom Expansion Roadmap

**Status (2026-11-03):** Mainline includes Frontier expansion through Phase 08.7, Phase 09.3, Phase 05 construction/queue management (PRs #58/#59), Watchtower vision (#60), Granary food reserve (#61), and the ordered Phase 04 specialist stack: Hunter #64 (`e59864d`), Scout #65 (`ea9a63c`), Healer #67 (`bf44703`) and Blacksmith/Forge #68 (`1b15f37`). The specialist PRs passed 45/45, 46/46, 47/47 and 48/48 Godot 4.7 jobs respectively (#620, #621, #626, #635). Mainline save schema is now v17. Manual rendered gameplay, equipment visibility, treatment/combat readability, full campaign balance, target-hardware profiling, native Windows runtime and clean-machine acceptance remain open.
**Phase 02 merge commits:** PR #31 (`6dcea7921f8f40eba17a1d2ca466a5f3e5b18fe8`) delivered local depot storage/transfers; PR #32 (`2f94959b497677eae49d4303f72322650fb591c2`) delivered garrisons/inspection; PR #33 (`5d7db56b3a51a25541f541bb46c19b26996d22be`) delivered player-directed physical shipments and save v13. PR #33 validation: [workflow #41323062111](https://github.com/shimleabyte/hold-the-keep/actions/runs/41323062111), 50/50 jobs successful on Godot 4.3/4.7, including 23 regressions per engine, Frontier diagnostic and Windows/Linux export.  
**Baseline:** Godot 4.7 / GDScript, Classic world 128×128 / 15 days, Frontier world 192×192 / 20 days / 4 acts, optional Frontier Expedition world 256×256 / 20 days / 4 acts with a 160×160 starting heartland, `main` save format v17. Historical Classic 64×64, Frontier 128×128 and Expedition 192×192 saves remain loadable at their recorded dimensions.

**Active CI policy:** Godot 4.7 only for import/parse, regressions and Frontier diagnostics. Godot 4.3 compatibility checks and Windows/Linux release exports are excluded from development CI; package builds return during release acceptance.

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
| Frontier world | 128×128 tiles (4× current tile count); optional Frontier Expedition expands to 192×192 (9× Classic) |
| Logical generation sectors | 32×32 tiles; initially keep the full map loaded |
| Tile size | 16×16 pixels |
| Initial terrain biomes | 5: Hearthland, Greenwood, Highlands, Fenlands, Ashen March |
| Special subregion | Old Frontier: ruin-dense exploration zone, not a sixth base biome |
| Starting Keep claim | 15-tile radius in Frontier profile |
| Starting economy | Preserve existing jobs/resources first; rebalance only with test evidence |
| Factions | 4: Greenwood Raiders, Iron Legion, Fen Cult, Ashen Host |
| New enemy archetypes | 6 initial designs: scout, shieldbearer, saboteur, war shaman, siege engine, beast rider |
| Added villager roles | Builder, hunter, scout, healer, blacksmith |
| New building concepts | Lumber Camp, Granary, Barracks, Quarry, Archery Range, Hunting Lodge, Infirmary, Bridge/Gate, Market, Siege Workshop, Stables, Fortress, Signal Beacon; existing Tower fulfils Watchtower role through expanded vision |
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
- [x] Add Godot CI on Godot 4.7.
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

### Phase 01.2 — Progressive Frontier Expedition
**Status:** Merged into `main` through PR #63 (`a594069`). PR workflow [#41580977570](https://github.com/shimleabyte/hold-the-keep/actions/runs/41580977570) passed 88/88 jobs: Godot 4.3/4.7 import/parse, 42 assertion suites per engine, Frontier/Expedition performance diagnostics, and Windows/Linux release export. Mainline push workflow #41581523207 is pending at the time of this update.

- [x] Add an independent 192×192 profile without changing Classic 64×64 or standard Frontier 128×128.
- [x] Keep a 128×128 walkable heartland at the start; generate four sealed outer marches around it.
- [x] Make the four crossings physically impassable until their matching regional discoveries are reached at the survey approach.
- [x] Prevent bridge/build/pathfinding bypasses through sealed barrier cells and reserve a clear tile on both sides of each gate.
- [x] Reuse permanent fog-of-war; reveal the strategic-map survey marker only after its approach is normally explored.
- [x] Persist opened marches through the existing discovery objective records; keep save schema v13 unchanged.
- [x] Add regression coverage and a separate Frontier Expedition performance diagnostic.
- [x] Pass the complete Godot 4.3/4.7 assertion matrix, Frontier Expedition diagnostic, and Windows/Linux exports (PR workflow #41580977570, 88/88).

**Acceptance gate — automated pass:** deterministic 192×192 generation; all four inner approaches and outer landings walkable; closed gates cannot be bridged or pathfinded through; each gate opens only at its survey threshold; fog, map bounds and saved unlocks validate; Classic/Frontier/Expedition assertion suites pass on Godot 4.3/4.7. Manual playthrough, save/load through every march, and real target-hardware profiling remain open.

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
- [x] Phase 02.5 supply pressure merged through PR #35 (`2ba5628`); `tests/supply_pressure.gd` covers the 30s warning, 60s first dispatch, bounded repeat, deterministic depot damage/theft, save-v13 persistence and road/territory recovery. Godot 4.3/4.7 workflow #41328005585 passed 54/54 jobs. Manual rendered UI/gameplay acceptance remains open.

**Initial slice acceptance gate — passed:** regional ownership is independent of fog and supply; road/bridge routes remain navigable; depot connectivity updates when roads are built or removed; disconnected depots cannot receive inventory deposits; infrastructure persists in saves.

### Phase 03 — Multi-stronghold campaign
**Status:** Implemented and merged into `main`; multi-stronghold regression CI passed on Godot 4.3 and 4.7.

- [x] Replace the single enemy stronghold reference with an ordered campaign objective/stronghold registry.
- [x] Support four region-specific Frontier strongholds with independent local garrisons and reinforcement caps.
- [x] Make objective order deterministic; each conquered region unlocks the next objective and grants a regional resource reward.
- [x] Persist the full objective registry, stronghold health and conquest state in save format v8; retain v1–v7 single-stronghold compatibility.
- [x] Preserve the existing one-stronghold Classic campaign.
- [x] Complete the Godot 4.7 regression matrix; objective/map presentation still needs a human gameplay review.

**Acceptance gate:** multiple strongholds can be found, attacked, destroyed, restored from saves and completed in a deterministic objective sequence.

### Phase 04 — Jobs and workplaces
**Status:** Builder, Hunter (#64), Scout (#65), Healer (#67) and Blacksmith/Forge (#68) are merged into `main` in dependency order. Their Godot 4.7 workflows passed 45/45 (#620), 46/46 (#621), 47/47 (#626) and 48/48 (#635). Integration is complete; rendered gameplay and balance acceptance remain manual.

- [x] Introduce Builder as a real labor occupation; soldier is stored separately as a military specialization, with a compatibility `job` alias.
- [x] Add Builder workplace capacity on Keeps and Outposts, plus data-driven work radii.
- [x] Add resource-backed repairs for damaged player buildings; one Builder claims a repair target at a time.
- [x] Limit resource/farm task selection to the work radius of a connected depot.
- [x] Select the nearest reachable connected depot rather than stopping at an unreachable nearest depot.
- [x] Add configurable job priority order, reassignment, Alt+job hotkeys and right-click controls in the job panel.
- [x] Persist occupation, military specialization and priority order in save format v9; older saves still load through the compatibility job field.
- [x] Merge Hunter and the two-slot Hunting Lodge through PR #64 (`e59864d`): deterministic wildlife harvest, food delivery, J hotkey/UI, target reservation, work-radius enforcement and save v14 migration. CI #620 passed 45/45; rendered food-rate/pathing review remains manual.
- [x] Merge Scout and the two-slot Scout Post through PR #65 (`ea9a63c`): bounded A* exploration, local permanent-fog revelation, sector rotation, return-to-post, U hotkey/UI and save v15 migration. CI #621 passed 46/46; rendered discovery-pace/map-scale review remains manual.
- [x] Merge Hunter → Scout → Healer → Blacksmith/Forge in order through PRs #64, #65, #67 and #68; all four specialist workplaces are now part of `main`.
- [x] Merge Blacksmith/Forge through PR #68 (`1b15f37`), including individual soldier weapon/armor upgrades and v17 migration. Godot 4.7 CI #635 passed 48/48 jobs.
- [ ] Review rendered Hunter/Scout/Healer/Blacksmith behavior, equipment visibility, treatment/combat readability, combat balance and economic pacing in an actual playthrough.
- [x] Complete the Godot 4.7 CI regression matrix for all specialist slices; real gameplay pathing and rendered behavior still need a manual playtest.

**Acceptance gate:** workers select valid tasks, avoid cross-map wandering, recover from blocked paths, deposit at reachable storage and retain their state through saves.

### Phase 05 — Buildings and production chains
**Status:** Lumber Camp/Quarry worksite, Phase 05.2a/05.2b construction, Phase 05.3a Watchtower and Phase 05.3b Granary are merged through PRs #58–#61; PR #61 CI passed 84/84. Additional facilities and manual economy/pathing review remain open.

- [x] Add a Lumber Camp with two woodcutter workplace slots and an 18-tile resource work radius.
- [x] Add a Quarry with two miner workplace slots and a 16-tile resource work radius.
- [x] Bind woodcutters/miners to matching worksites; retain connected-depot fallback only when no matching specialty site exists.
- [x] Release worksite claims when workers leave or a worksite is removed; worksite buildings use the generic save payload and remain compatible with save v12.
- [x] Add separate pixel-art buildings/icons, hotbar entries, numeric hotkeys, controls documentation and headless regression coverage.
- [x] Add Builder-driven blueprint sites: pay once at placement, cap at two active Builders per site, advance only while Builders are working, convert atomically to a finished building and refund unconsumed materials on cancellation (PR #58 merged as `d3bba66`; workflow #41484825656 passed).
- [x] Add a dedicated construction queue panel with explicit order, one-step reorder controls, cancellation and visible per-site costs/live progress; Builder selection follows saved queue priority (PR #59 merged as `6147cfc`; workflow #509 passed 80/80).
- [x] Extend the existing defensive tower into the Watchtower role with permanent 128px terrain discovery and live strategic-map enemy observation; keep its existing turret behavior (PR #60 merged as `beef7b7`; workflow #515 passed 82/82).
- [x] Add the Granary food-only depot with population upkeep, food-only Frontier logistics/shipments, raid interaction and v13 save coverage (Phase 05.3b; PR #61 merged as `d9b87b1`, workflow #41558978053 passed 84/84).
- [x] Add and merge Hunting Lodge as the Hunter workplace through PR #64; dedicated Godot 4.7 regression passed.
- [ ] Add remaining facilities according to dependency: Barracks, Archery Range, Infirmary, Bridge/Gate, Market, Siege Workshop, Stables, Fortress and Signal Beacon.
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
- [x] Extract archetype-specific state, targeting and ability policies into composable modules while retaining shared movement/ranged-combat host paths. Beast Rider, Shieldbearer, Scout, Saboteur and Siege Engine now own dedicated behavior components; War Shaman healing is isolated in `war_shaman_support_behavior.gd` and remains separate from its shared ranged attack loop.
- [x] Beast Rider telegraphed charge merged via PR #42 (`e6cf221`); isolated-target scoring, A* approach, locked route, sidestep counterplay, nav/stagger cancellation. Workflow #41366304675 passed 64/64 jobs.
- [x] Extracted Beast Rider target/charge policy into `scripts/behaviors/beast_rider_behavior.gd`: bounded isolation-aware target scan, A* approach, locked-path traversal, damage/knockback, cancellation, recovery and telegraph drawing. `enemy.gd` retains host combat/movement hooks. `tests/beast_rider_charge.gd` passed on both Godot versions; PR #47 workflow [#41386046423](https://github.com/shimleabyte/hold-the-keep/actions/runs/41386046423) passed 70/70 jobs.
- [x] Extracted Shieldbearer brace policy into `scripts/behaviors/shieldbearer_behavior.gd`: data-driven wind-up/active/cooldown, locked facing, target disengage cancellation, stagger interrupt, frontal source-origin damage mitigation and brace telegraph. `enemy.gd` now delegates brace state and mitigation to the component; `tests/shieldbearer_behavior.gd` asserts through the component API. Workflow [#41387134030](https://github.com/shimleabyte/hold-the-keep/actions/runs/41387134030) passed 70/70 jobs.
- [x] Extracted Scout marking into `scripts/behaviors/scout_behavior.gd`: faction-bounded publication, same-faction propagation, target focus, expiry, cancellation and marker rendering. `enemy.gd` retains thin adapters for other archetypes consuming active marks. `tests/scout_marking.gd` passed on Godot 4.3/4.7; latest-head workflow [#41387833455](https://github.com/shimleabyte/hold-the-keep/actions/runs/41387833455) passed 70/70 jobs.
- [x] Extracted Saboteur behavior into `scripts/behaviors/saboteur_behavior.gd`; host no longer stores Saboteur scan tuning, target cursor, path, wind-up or cooldown. Focused test passed on both Godot versions; workflow [#41388532624](https://github.com/shimleabyte/hold-the-keep/actions/runs/41388532624) passed 70/70 jobs.
- [x] Extracted Siege Engine behavior into `scripts/behaviors/siege_engine_behavior.gd`; host no longer stores its target priorities, path, attack timers or wind-up state. Focused test passed on both Godot versions; workflow [#41389136213](https://github.com/shimleabyte/hold-the-keep/actions/runs/41389136213) passed 70/70 jobs.
- [x] Siege Engine siege cycle merged via PR #41 (`58da7be`); workflow #41356689758 passed 62/62 jobs on Godot 4.3/4.7.
- [x] Saboteur building disruption merged via PR #40 (`8f1a914`); workflow #41355982522 passed 60/60 jobs on Godot 4.3/4.7.
- [x] Scout scouting/marking merged via PR #39 (`11f3f13`); workflow #41354720293 passed 58/58 jobs on Godot 4.3/4.7.
- [x] Shieldbearer directional brace merged via PR #36 (`b02aa60`); the available first results page for workflow #41329202804 showed 30/30 successful jobs; full matrix not independently verified.
- [x] Deterministic Frontier faction camps merged through PR #43 (`fa3a45a`): one reachable enemy-owned site per faction; hidden until fog discovery; destructible by player melee.
- [x] Bounded A* patrols, region/territory/leash validation, camp return, active cap and finite per-faction reinforcement budget merged; workflow #41377840888 passed 66/66 jobs.
- [x] Optional camp/patrol state added to save v13 with regression coverage for reload assignment; no schema bump. `faction_camps_patrols` passed on Godot 4.3/4.7.
- [x] Phase 06.4 faction raids merged via PR #44 (`5cc5084`); workflow #41381487306 passed 68/68 jobs. Faction camps dispatch finite native-role raiders against exposed, connected Outposts/Storage and roads/bridges in their own region; bounded scans and A* checks, target revalidation/withdrawal, structure damage, second-hit depot theft and additive save-v13 persistence are covered by `tests/faction_raids.gd`.
- [x] Merged through PR #21; Godot 4.3 / 4.7 CI passed (30/30 jobs).
- [x] Phase 06.5 combined warfare stress was merged via PR #45 and strengthened through PR #47 (`b06c355`): all 48 garrisons tick across six archetype behaviors alongside eight patrols, four simultaneous raids and 48 additional villagers. PR #47 includes the GDScript correction formerly isolated in PR #46; integrated workflow [#41394905158](https://github.com/shimleabyte/hold-the-keep/actions/runs/41394905158) passed 70/70 jobs. PR #46 is superseded.
- [ ] Manual Frontier gameplay review.

**Acceptance gate:** each archetype creates a distinct tactical response; AI remains bounded under stress tests; factions obey territory and campaign state; save/load and Godot 4.7 CI pass. Manual Frontier gameplay review remains open.

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
**Status:** In progress on `feat/phase-08-visual-audio-identity-mainline`. First slice adds a dedicated seven-cell weathered Frontier terrain atlas, preserves the Classic atlas, and extends the Frontier world regression to verify the selected atlas resource. Remaining biome props, landmarks, faction/unit/building art, combat feedback and audio are not yet delivered.

- Create distinct biome tiles, environmental props, landmarks and faction assets.
- Give new units unique silhouettes, weapons, animations and hit feedback.
- Add building art for each new structure rather than reusing generic placeholders.
- Improve strategic-map overlays for terrain, ownership, resources, roads, supply, enemy settlements and objectives.
- Add environmental and combat audio after gameplay triggers stabilize.

**Acceptance gate:** screenshot passes at target desktop resolutions; visual readability under day/night, fog and combat load; no placeholder-only faction identity in release content.

### Phase 09 — Balance, performance and release hardening
**Status:** Phase 09.2 scripted campaign combat-budget probes merged through PR #62 (`4cc0420`); workflow [#41564491766](https://github.com/shimleabyte/hold-the-keep/actions/runs/41564491766) passed 86/86 jobs on Godot 4.3/4.7, including Frontier performance diagnostic and Windows/Linux exports. Phase 09.3 late-act reload coverage remains merged through PR #57 (`a1ccebe`). The new probe covers curated samples at Frontier Acts I–IV and the day-20 King encounter using real damage/cooldown transactions, but it does not simulate full waves or autonomous AI. Save schema v13 is unchanged. Target-hardware profiling, full-wave balance validation, human playtesting, native Windows runtime and clean-machine verification remain open.

- [x] Add configurable Classic/Frontier profiling for p50/p95/p99 process, physics and wall-frame timing, static memory, node count, projectiles and particles.
- [x] Add bounded Frontier stress coverage for four factions, mixed rosters, villagers, ranged projectiles and the 500-particle ceiling.
- [x] Add deterministic Classic/Frontier campaign balance matrix for stage/act transitions, wave budgets and final-boss gates.
- [x] Add Frontier campaign reload coverage for completed objectives, unlocked acts, escort path progress and damaged strongholds.
- [x] Add save migration/recovery tests for Classic v1–v12 and Frontier v7–v12, interrupted temporary writes, backup rotation and profile isolation.
- [x] Run the Godot 4.3/4.7 import, parse and regression matrix on the original stacked branch.
- [x] Export Windows/Linux in CI using Godot 4.3 templates; validate Windows PE output and smoke-test Linux.
- [ ] Measure the reference workload on actual target desktop hardware before making performance optimization claims.
- [x] Add bounded scripted combat-budget probes at the end of Frontier Acts I–IV and the day-20 King encounter (`tests/campaign_combat_simulation.gd`; PR #62, workflow #41564491766 passed 86/86). Curated sample only; full-wave AI balance validation remains open.
- [x] Extend Frontier reload coverage through Acts I–IV, completed regional objectives, conquered strongholds, damaged final stronghold HP, the day-20 King gate and persisted victory reload (PR #57; workflow #490, 78/78).
- [ ] Complete human playtesting across all campaign acts.
- [ ] Verify Windows runtime and clean-machine save/settings migration.

**CI diagnostic (not target hardware):** Frontier 128×128, 119 active enemies, 82 villagers, six peak projectiles and 500 peak particles; wall-frame p50 4.27 ms / p95 10.45 ms / p99 13.55 ms. A process-monitor p95 outlier of 102.24 ms was also recorded; these figures are runner-specific, not an accepted target-hardware budget.

**Remaining acceptance work:** measured target-hardware performance, full-wave/AI-informed balance validation, full multi-act human playtest, Windows runtime on a real Windows machine, and clean-machine save/settings migration. Save/reload persistence through Act IV and final victory is now covered automatically by `campaign_reload_hardening.gd`.
### Phase 10 — Resolution-matched viewport and HUD safe area
**Status:** Adaptive viewport implementation remains merged through PR #30; latest mainline workflow [#490](https://github.com/shimleabyte/hold-the-keep/actions/runs/41432676578) passed 78/78 jobs, including responsive-layout regressions on Godot 4.3/4.7. Physical-display screenshots and manual fullscreen review remain open.

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

- No 256×256 map before the 192×192 Frontier Expedition is profiled and stable.
- No runtime chunk streaming before evidence requires it.
- No multiplayer or online services.
- No large content dump of units/buildings without distinct mechanics and tests.
- No removal of Classic Mode or silent conversion of old saves.
- No wholesale rewrite of the game loop unless a measured architectural constraint requires it.

## 7. Decision log

- The expansion is a strategy-layer evolution, not a replacement of the existing action-combat identity.
- Standard Frontier remains 128×128 and Classic remains 64×64; optional Frontier Expedition expands to 192×192 while preserving a 128×128 walkable starting heartland.
- The larger starting territory is a 15-tile Keep radius, not an unrestricted starting half-map.
- Five terrain biomes are the initial target; Old Frontier is a ruin-rich subregion theme.
- Phase 00 was merged into `main` through PR #7. Phase 01 is based directly on `main` in `feat/frontier-world-generation-mainline` (PR #10).


## 50. Phase 08.3 — Frontier biome dressing (2026-11-02, implementation branch)
- Branch: `feat/phase-08.3-frontier-biome-props`, based on main after PR #48.
- Added native-scale, code-drawn decorative props: Greenwood fern clusters/dead pines, Fenlands reeds, Highlands standing stones, Ashen March pillars and restrained Hearthland markers.
- Added one deterministic landmark per core biome: Hearthland shrine, Greenwood ruin marker, Highlands standing stone, Fenlands reed marker and Ashen pillar.
- Decoration placement uses an independent seeded RNG after resource placement, does not modify tile generation or resource RNG, does not collide, and avoids occupied resource cells and the immediate starting clearing.
- Extended `frontier_world.gd` to verify decoration density, five-region landmark coverage, no overlap with resources and deterministic placement. Classic generation is unchanged. CI and rendered screenshot review are pending.


## 2026-11-02 — Phase 08.3 Frontier biome dressing
- Deterministic non-colliding regional decoration and five biome landmarks are placed after resource generation using an independent RNG. The Hearthland ring now receives sparse dressing outside the Keep's protected core; it remains buildable and free of resource/decoration overlap.
- Resource nodes gain distinct Frontier variants: Greenwood pine, Fenlands willow, Ashen deadwood, Highlands stone and Ashen rock. Classic continues to use its original sprites.
- `frontier_world.gd` checks decoration/landmark coverage, deterministic placement, resource overlap and the expected regional resource sprite variants. CI is pending.


## Phase 08.4 — Faction and archetype visual identity (implementation branch)
- Branch: `feat/phase-08.4-faction-visual-identity`, based on main after PR #50 (`c8eed384`).
- Add four data-driven Frontier visual palettes and unique heraldic motifs: Greenwood thorn, Iron Legion chevron, Fen Cult reed and Ashen Host ember.
- Add one modular visual layer for faction heraldry and specialist equipment signatures across all six archetypes. The layer is draw-only: combat behavior, collision, sprite animation timing and save schema remain unchanged.
- Add `tests/faction_visual_identity.gd` to validate unique faction motifs, profile attachment for every faction/archetype pairing and Classic isolation. CI pending.
- Rendered gameplay screenshot review remains outstanding; do not claim visual acceptance from headless tests alone.


## Phase 08.5 — Frontier building identity and damage states (implementation branch)
- Branch: `feat/phase-08.5-building-visual-identity`, based on main after PR #52 (`ce69391`).
- Add data-driven material palettes and a unique structural detail for all 13 shipped building types, layered over existing dedicated textures.
- Add four deterministic HP-scaled damage states as draw-only, material-aware cracks/chips. Classic rendering remains unchanged; collision, footprints, HP, combat and save v13 are untouched.
- Explicitly defer construction-stage visuals until Phase 05 implements real staged construction state; do not fake build progress with HP or elapsed timers.
- Add `tests/building_visual_identity.gd` to validate full building coverage, unique feature signatures, valid palettes, Frontier-only enablement and damage thresholds. CI pending.
- Rendered screenshot review remains mandatory after CI.


## Phase 08.6 — Combat visual feedback (implementation branch)
- Branch: `feat/phase-08.6-combat-visual-feedback`, based on main after PR #53 (`3aaa37f`).
- Add a shared draw-only feedback component for directional melee/ranged anticipation, impact direction/strength, stagger readability and distinct Dash/Cleave/Rally shapes.
- Integrate into Player and Enemy without changing damage values, attack/projectile timing, AI, status timers, collision, or save schema v13. Existing specialist telegraphs, particle limits, and corpse/death animation are retained.
- Add `tests/combat_visual_feedback.gd` to the runner and Godot 4.3/4.7 matrices. CI pending.
- Manual rendered combat screenshot review remains required.


## Phase 08.7 — Regional ambience, music and combat audio (merged via PR #55)
- Squash merge: `d933bb6` from `feat/phase-08.7-regional-audio-identity`, based on main after PR #54 (`cf41982`). Workflow #41427499533 passed 78/78 jobs on Godot 4.3/4.7.
- Generate ten loop-forward ambience streams for the five Frontier biomes and day/night states using original deterministic synthesis, with crossfades on biome/time transitions.
- Add original low-volume campaign/menu music loops and crossfade when pausing/resuming. All new players use the existing Master bus and persisted volume setting.
- Connect 14 event cues for combat anticipation/projectiles/block/stagger/abilities/charges/siege, wave and camp alarm, objective completion, act unlock and victory.
- `tests/audio_identity.gd` validates loop counts/format/buffers, deterministic synthesis, event-cue availability, Master bus routing and context selection. It passed in both Godot versions.
- Manual audio listening, level-balance and loop-transition QA remain mandatory; CI cannot confirm perceived loudness, speaker translation or subjective mix quality.


## Phase 11 — Rival civilizations and military command

**Status (2026-11-06):** Initial implementation is isolated on `feat/army-command-rival-civilization`. It is not merged. The branch preserves the player avatar, camera, direct combat and autonomous civilian jobs. Following human playtest feedback that the original maps were too small to support an enjoyable strategy loop, new campaigns now use Classic 128×128, Frontier 192×192 and Expedition 256×256 (160×160 starting heartland). Historical map dimensions remain available to saves through the profile-aware loader; save schema remains v17.

### Product contract

- Civilian workers remain autonomous. Existing gathering, construction, delivery, specialist and workplace state machines are not exposed to direct army selection.
- Military units only (`job == "soldier"`, including Archer specialization) may be selected and ordered.
- The player remains directly controllable. Mouse selection clicks must not accidentally trigger player melee; clicking a hostile target remains a valid player attack.
- The first army command slice is deliberately small: single select, drag selection, Shift add/remove, move and attack.
- Rival strongholds own an independent finite resource ledger, construction plan, visible faction structures, paid garrison recruitment and technology tiers.
- Rival buildings use a separate entity type; they must not register as player workplaces, depots, supply sources or player-buildable structures.
- The first rival economy uses abstracted workforce production. Visible enemy workers, multi-settlement logistics, territorial expansion and offensive strategic plans remain later work.
- Larger maps are part of this phase: Classic 128×128, Frontier 192×192 and Expedition 256×256. Keep historical save dimensions loadable and profile-specific; do not migrate old coordinates onto a newly generated map.

### Map expansion from direct playtest feedback

- [x] Increase new Classic campaigns from 64×64 to 128×128 (4× tile area).
- [x] Increase new Frontier campaigns from 128×128 to 192×192.
- [x] Increase new Frontier Expedition campaigns from 192×192 to 256×256 and heartland from 128×128 to 160×160.
- [x] Preserve old 64×64 / 128×128 / 192×192 campaign dimensions when continuing existing saves.
- [ ] Validate old-save loading, all new world generators, stronghold placement, strategic-map/fog behavior and target desktop performance on the expanded profiles.

### Initial implementation on the feature branch

- [x] Add a separate army command controller; select only visible living soldiers.
- [x] Add right-click movement and direct attack orders while retaining the soldier combat state machine.
- [x] Keep player camera, direct movement and player avatar active.
- [x] Add faction-owned settlement structure entities using existing low-cost building art.
- [x] Add bounded rival economy ticks, resource stockpiles, construction costs, visible buildings and production income.
- [x] Add a barracks-dependent garrison capacity, resource-paid periodic recruitment and military technology tiers.
- [x] Add additive stronghold serialization for rival structures, resource balances, research and construction state; preserve schema v17.
- [x] Add a focused regression test and include it in the Godot 4.7 runner/matrix.
- [x] Replace the old “no remote military control” design restriction with autonomous civilians plus commandable armies.
- [ ] Verify Godot 4.7 import and GDScript parse on the complete branch.
- [ ] Pass the focused army/civilization regression and full mainline regression matrix.
- [ ] Verify Classic new-game and existing v17 save/reload, plus Frontier and Expedition multi-stronghold reload.
- [ ] Render and play a Classic rival-settlement session; inspect building overlap, pathing, recruitment pacing and combat challenge.
- [ ] Measure frame-time p50/p95/p99 and worst frame during rival construction, garrison recruitment and active waves on a target desktop.

### Follow-on sequence

1. **11.1 — Acceptance and persistence:** validate the initial branch; harden corrupted/blocked structure restore, rebuild behavior and save migration fixtures without a schema bump where possible.
2. **11.2 — Rival strategy:** add faction-specific priorities and responses, use existing faction doctrine and archetype rosters, and make each faction's attack/defense strategy distinct.
3. **11.3 — Rival military production:** convert barracks/archery facilities into explicit training queues and deploy new unit types only when paid costs and population/upkeep rules allow.
4. **11.4 — Expansion and supply:** add secondary settlements, faction-owned territory, roads and local depots through explicit ownership contracts. Reuse the existing logistics architecture rather than mirroring it.
5. **11.5 — Map and campaign review:** only after multiple settlements work, decide whether any profile needs more tiles. Run human campaign balance reviews and performance diagnostics before changing Classic or Frontier dimensions.

**Known overlap:** PR #169 (`feat/rts-command-foundation`) is a separate open proposal that retires the hero camera and exposes all villagers to direct selection/orders. That implementation conflicts with this phase's product contract. Do not merge it as-is; reconcile or close it before integrating any overlapping files. PRs #166/#167 and the open player-animation work must be rechecked for current branch compatibility before merging.

**Validation boundary:** No engine runtime is available in the implementation environment. CI and rendered/manual acceptance must be reported from actual workflow and playtest results; source inspection alone is not a passing test.
