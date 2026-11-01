# Hold the Keep — Next-Level Kingdom Expansion Roadmap

**Status:** Phase 00 merged and verified; Phase 01 implemented and verified on Godot 4.3 and 4.7. PR #10 remains open for review.  
**Implementation branches:** `main` (Phase 00, merged PR #7) → `feat/frontier-world-generation-mainline` (Phase 01, PR #10)  
**Baseline:** Godot 4.x / GDScript, Classic world 64×64, save format v7

## 1. Product direction

Evolve Hold the Keep from a compact village-defense/action-combat game into a **frontier kingdom strategy game**. Preserve direct player control and the existing defensive loop, but add meaningful exploration, regional ownership, settlements, supply networks, faction warfare and multi-stage conquest.

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
**Status:** Merged into `main`; verified on Godot 4.3 and 4.7 (CI run `41287974528`)

- [x] Add this roadmap and link it from project documentation.
- [x] Add Godot CI on Godot 4.3 and 4.7.
- [x] Add parse-only validation for every GDScript file.
- [x] Add one headless regression runner with deterministic 60 FPS.
- [x] Centralize world profiles, dimensions, tile size, seed, starting Keep position and profile-level resource density.
- [x] Migrate all spatial systems away from duplicated 64×64 constants while keeping Classic active.
- [x] Bump save format to v7 and persist world identity.
- [ ] Prove v1–v6 saves remain valid in Classic and are rejected for non-Classic profiles on both engine versions.

**Acceptance gate — passed**
- Both CI engine versions import the project, parse every script and complete all assertion-based regression jobs.
- Classic remains 64×64 with its existing generation path, seed, Keep placement, spawn placement and territory radius.
- Save v7 round-trips world metadata; v1–v6 legacy saves validate in Classic and are rejected for Frontier loading.
- Frontier remains an explicit new-campaign choice; Classic stays the shipped default.

### Phase 01 — Expanded deterministic world
**Status:** Implemented and verified on Godot 4.3 and 4.7; draft PR #10 open for review

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
**Status:** Initial implementation slice verified on Godot 4.3 and 4.7; stacked draft PR #11. Broader phase remains in progress.

- [x] Aggregate land claims into neutral/player/enemy/contested regional control records.
- [x] Emit regional control changes independently from fog-of-war exploration.
- [x] Add road and bridge construction definitions, pixel assets and HUD icons.
- [x] Allow bridge placement on valid water cells inside player claims.
- [x] Keep roads and bridges walkable in villager A* and enemy flow-field routing.
- [x] Build a cardinal road graph rooted at the Keep and expose connected road/depot state.
- [x] Treat Keep, Storage and Outposts as depots; Outposts are forward depots.
- [x] Restrict worker deposits to Keep-connected depots and retain cargo when a route disconnects.
- [x] Show explored roads and regional control state on the strategic map.
- [x] Cover ownership states, road/bridge traversal, depot connectivity/disconnection, isolated Outposts and road save persistence.
- [x] Pass the Godot 4.3/4.7 CI matrix, including the regional integration test (run `41289421611`, 24/24 jobs).
- [ ] Add Outpost guard assignment, garrison support and local visibility.
- [ ] Add local stockpile accounting and actual inter-depot transfers. Current delivery still credits shared inventory at a connected depot.
- [ ] Add supply attrition and raid vulnerability after local logistics are reliable.

**Initial slice acceptance gate — passed:** regional ownership is independent of fog and supply; road/bridge routes remain navigable; depot connectivity updates when roads are built or removed; disconnected depots cannot receive inventory deposits; infrastructure persists in saves.

### Phase 03 — Multi-stronghold campaign
- Replace the single enemy stronghold reference with a campaign objective/stronghold registry.
- Support multiple enemy settlements, garrisons, reinforcement sources and regional conquest rewards.
- Make regional capture unlock new objectives rather than immediately ending the campaign.
- Preserve the existing single-stronghold flow in Classic Mode.

**Acceptance gate:** multiple strongholds can be found, attacked, destroyed, restored from saves and completed in a deterministic objective sequence.

### Phase 04 — Jobs and workplaces
- Introduce Builder, Hunter, Scout, Healer and Blacksmith incrementally.
- Add workplace capacity, work radius, local storage selection, job priorities and reassignment.
- Separate labor occupations from military unit specializations.
- Add worker behavior and workplace tests before exposing new jobs in HUD.

**Acceptance gate:** workers select valid tasks, avoid cross-map wandering, recover from blocked paths, deposit at reachable storage and retain their state through saves.

### Phase 05 — Buildings and production chains
- Add buildings according to dependency: Lumber Camp, Watchtower, Granary, Barracks, Quarry, Archery Range, Hunting Lodge, Infirmary, Bridge/Gate, Market, Siege Workshop, Stables, Fortress and Signal Beacon.
- Introduce leather and gold only when a building or campaign system consumes them.
- Add construction/repair work, military training, trade and siege production as separate validated slices.

**Acceptance gate:** every building has a distinct function, valid footprint, data definition, art asset, UI representation, unlock rule and save/load coverage.

### Phase 06 — Factions, enemy archetypes and territorial AI
- Introduce four factions with distinct rosters, visual identity and regional behavior.
- Add six initial archetypes: scout, shieldbearer, saboteur, war shaman, siege engine and beast rider.
- Refactor target selection, movement, attack patterns, abilities and faction tactics into composable behavior modules.
- Add camps, patrols, raids and counterattacks against vulnerable outposts and supply routes.

**Acceptance gate:** each archetype creates a distinct tactical response; AI remains bounded under stress tests; factions obey territory and campaign state.

### Phase 07 — Technology and campaign objectives
- Expand the 17-node technology tree without invalidating existing unlocks.
- Add regional discovery rewards, rescue, escort, ruin-clearing, camp-clearing and defense objectives.
- Introduce the 20-day / 4-act Conquest Campaign while preserving 15-day Classic Mode.

**Acceptance gate:** all objectives resolve, rewards persist, act transitions are tested and campaign completion cannot occur before the required objectives are met.

### Phase 08 — Visual and audio identity
- Create distinct biome tiles, environmental props, landmarks and faction assets.
- Give new units unique silhouettes, weapons, animations and hit feedback.
- Add building art for each new structure rather than reusing generic placeholders.
- Improve strategic-map overlays for terrain, ownership, resources, roads, supply, enemy settlements and objectives.
- Add environmental and combat audio after gameplay triggers stabilize.

**Acceptance gate:** screenshot passes at target desktop resolutions; visual readability under day/night, fog and combat load; no placeholder-only faction identity in release content.

### Phase 09 — Balance, performance and release hardening
- Profile 128×128 worlds with larger populations, multiple factions, projectiles and effects.
- Optimize only measured hotspots. Consider chunk streaming only if full-map loading causes real problems.
- Simulate campaign difficulty and perform human playtests across all acts.
- Test save migration, interrupted saves, campaign reload and export builds.

**Acceptance gate:** full CI green, no known blocker bugs, performance budget documented, fresh and migrated saves tested, and release builds verified on target desktop platforms.

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
