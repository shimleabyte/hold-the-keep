# Hold the Keep — Parallel Developer Worklist

**Audit baseline:** `main` at `a2fb9c3378ad58f60b431e20e0dd92e2ff386e88` (2026-11-04)  
**Engine target:** Godot 4.7 only  
**Project:** Native desktop, Godot / GDScript  
**Purpose:** Assign independent implementation work to Developer A, B, C, etc. without creating avoidable merge conflicts or duplicating work already in progress.

This is an execution worklist, not a claim that every item is already implemented. Re-check the live branch/PR state before starting each assignment.

## Live execution status — 2026-11-04 (post PR #87 Archery Range integration)

**Current main:** `a2fb9c3378ad58f60b431e20e0dd92e2ff386e88` — includes PR #87 Archery Range, PR #89 canonical save migration/file-store extraction, PR #91 VillagerArcherCombat extraction, PR #94 SupplyShipmentLedger and PR #86 deterministic Frontier decoration/landmarks; save schema remains v17.  
**Current save schema:** v17.  
**Open pull requests observed in the latest repository search:** #96 DEV-D shipment dispatch extraction. Re-check live state before taking action.

| Workstream | Current disposition |
|---|---|
| INT-0 specialist integration | Complete: Hunter, Scout, Healer and Blacksmith integrations are on main. |
| DEV-A data contract validation | Complete through PR #71 replacement. |
| DEV-B faction camp architecture | Integrated through PR #70. Preserve public camp/patrol/raid interfaces. |
| DEV-C campaign simulation QA | Integrated through PR #73. This is deterministic campaign simulation/diagnostics, not a substitute for human playtesting. |
| DEV-D supply network decomposition | Partial: PR #75 extracted cost-source transactions; PR #94 added `SupplyShipmentLedger` for order IDs, active-order accounting, destination reservations, bounded history and save restoration. PR #96 proposes extracting route availability, carrier dispatch and blocked-carrier callbacks. Mainline `supply_network.gd` remains 766 lines until #96 merges. Depot graph and supply-pressure ownership remain. |
| DEV-E save/migration architecture | Complete through #89: canonical v17 conversion for supported Classic v1–v17 / Frontier v7–v17 saves and `SaveFileStore` parsing, temp verification, backup rotation and rollback are integrated. Schema remains v17; #84 and #88 were closed as superseded duplicates. |
| DEV-F villager role architecture | First slice integrated through #91: `VillagerArcherCombat` owns ranged attack policy while the villager retains state/cooldown/animation/world ownership. Host reduced from 1530 to 1509 lines. Further role-specific extraction remains; preserve movement, workplace, carrying and save contracts. |
| DEV-G HUD modularization | Not started. Decision-based event panel is already integrated through #72; extract it through its existing interface. |
| DEV-H world generation | Generator decomposition integrated through #86: deterministic region, terrain, resource, decoration and landmark selection are isolated. Godot 4.7 regression and Campaign Simulation QA passed; manual same-seed rendered comparison remains part of visual acceptance. |
| DEV-I enemy controller | Partial. Patrol movement is already extracted through #74 as `EnemyPatrolMovement`; other shared host responsibilities remain. |
| DEV-J decision-based events | Integrated through PR #72. |
| DEV-K input command registry | Integrated through PR #76. |
| DEV-L Barracks | Integrated through PR #78. |
| Archery Range / ranged soldiers | Integrated through PR #87. Preserve soldier-role, garrison, expedition and v17 save compatibility. |
| DEV-M visual identity / rendered QA | Partial. Distinct silhouettes, rendered gameplay review, audio listening and visual readability checks remain. |

### Current open-PR disposition

- **#96 — DEV-D shipment dispatch extraction:** open against current main. Extracts route availability, carrier dispatch/re-dispatch and blocked-carrier callbacks; Godot 4.7 import/parse and full regression matrix plus Campaign Simulation QA must pass before merge.
- **#86 — deterministic Frontier decoration/landmarks:** merged into main at `a2fb9c3`. Godot 4.7 import/parse, all 53 CI jobs and Campaign Simulation QA passed after tests were changed to compare against the exact generation-time eligibility snapshot. Manual identical-seed rendered comparison remains a separate visual acceptance task.
- **#94 — DEV-D shipment ledger extraction:** merged into main at `96cfe01`; Godot 4.7 import/parse, all 53 CI jobs and Campaign Simulation QA passed on the final head.
- **#91 — DEV-F archer combat extraction:** merged into main at `11176db`; Godot 4.7 import/parse, all 29 regression/performance jobs and Campaign Simulation QA passed on the final head.
- **#89 — canonical save migration/file store:** merged into main at `bad437f`; Godot 4.7 regression jobs and Campaign Simulation QA passed. #84 and #88 were closed as superseded duplicates.
- **#87 — Archery Range:** merged into main before the current baseline.

### Recommended execution order

1. Stabilize integration: validate and merge #96 after its full Godot 4.7 and Campaign Simulation checks pass; keep rendered parity review for #86 on the visual QA list.
2. DEV-D: continue with depot graph and supply-pressure responsibilities as separate slices after #96. Preserve v17 save compatibility.
3. DEV-F: continue villager decomposition in small, independently testable slices, next isolating one non-archer role behavior without changing shared contracts. Avoid broad rewrites.
4. DEV-G: modularize HUD components without changing layout contracts or gameplay rules.
5. DEV-H and DEV-I: finish generation and enemy-host decomposition after checking current file ownership and API dependencies.
6. DEV-M: replace remaining unrelated placeholder textures and perform rendered gameplay/audio QA.
7. Only then expand facilities or rebalance campaign pacing based on observed playtest evidence.

### Validation and release boundaries

- Development CI targets **Godot 4.7 only**. Do not add Godot 4.3 or Windows export jobs to feature CI.
- Automated campaign simulation is useful diagnostic coverage, but it does not prove full-wave balance, player-facing readability or campaign fun.
- Remaining acceptance work includes full-wave autonomous-AI balance tests, human playthrough across all Frontier acts, target-hardware profiling, rendered resolution/fullscreen review, audio listening, and later Windows runtime/clean-machine release checks.
- Do not claim a feature is complete solely because headless tests pass. Record rendered/manual QA separately.

This snapshot supersedes the previous live-status block. Re-check PR heads, workflow runs and main before each merge or assignment; repository state can change after this commit.

---

## 0. Ground rules and current baseline

### Current mainline foundation

The audited `main` already contains:

- Classic 64×64, Frontier 128×128 and optional Frontier Expedition 192×192 world profiles.
- Deterministic world generation, five Frontier biomes, regional control, fog of war and progressive Expedition gates.
- Multi-stronghold Frontier campaign, four acts and regional objectives.
- Player combat progression with Dash, Cleave and Rally.
- Four factions and six enemy archetype behavior modules.
- Faction camps, patrols, reinforcements and raids.
- Villager workplaces, Builder, construction sites and construction queue.
- Roads, depots, local stockpiles, physical shipments, cost-source selection and supply pressure.
- Twenty technology nodes across three eras.
- Adaptive logical viewport and modular visual/audio systems.
- Save schema v17 on current mainline (the original audit snapshot was v13).
- Current Godot 4.7 regression matrix, project import/parse and Frontier performance diagnostics; exact suite lists live in `.github/workflows/godot-ci.yml` and `tools/run_tests.sh`.

### Engine and CI policy

- All development and regression work targets **Godot 4.7**.
- Do not add Godot 4.3 jobs or compatibility changes as part of these assignments.
- Windows/Linux release exports are deferred to the release phase. Do not add export jobs to feature CI.
- Keep the current headless SceneTree assertion-test approach unless a separate, evidence-backed test-framework proposal is approved.
- CI passing does not replace rendered gameplay review or human balance testing.

### Rules for every developer

1. Work on a dedicated branch created from the latest appropriate base.
2. Keep each PR limited to one workstream and its directly required tests.
3. Preserve existing public APIs and gameplay behavior during refactors.
4. Do not change save schema versions unless the task explicitly requires it and migration coverage is included.
5. Do not edit the shared CI test manifest, `tools/run_tests.sh`, `.github/workflows/godot-ci.yml`, or `tests/README.md` unless you are the designated integration owner. Add the test file and tell the integrator how to register it.
6. Never create a second implementation of a feature already present on an open branch or PR.
7. Do not make unrelated formatting, naming or cleanup changes to shared files.
8. Run Godot 4.7 import, complete GDScript parsing, the focused regression tests and the full existing regression suite before requesting merge.
9. Record any manual/rendered QA that remains outstanding. Do not claim headless tests prove visual readability or balance.
10. If a task encounters an API or schema dependency outside its assigned ownership, stop at the interface boundary and report the dependency. Do not silently modify another developer's module.

### Branch and PR conventions

Suggested branches:

- `work/dev-a-data-validation`
- `work/dev-b-faction-camp-architecture`
- `work/dev-c-campaign-simulation`
- `work/dev-d-supply-decomposition`
- `work/dev-e-save-architecture`
- `work/dev-f-villager-architecture`
- `work/dev-g-hud-modules`
- `work/dev-h-world-generation`
- `work/dev-i-enemy-controller`

Use one branch per assignment. PRs should target `main` unless a specific stacked dependency is explicitly approved.

---

## 1. Priority 0 — Integration owner

<Status>Blocking baseline work</Status>

### INT-0 — Integrate and clean up the specialist stack

**Owner:** Integration lead (not one of Developers A–I)  
**Status at audit:** Specialist PR stack was open and stacked. Verify live status before acting.

Expected order at audit:

1. PR #64 — Hunter / Hunting Lodge.
2. PR #65 — Scout / Scout Post, stacked on #64.
3. PR #67 — Healer / Infirmary, stacked on #65.
4. PR #68 — Blacksmith / Forge equipment, stacked on #67.

**Instructions:**

- Inspect each PR's latest head, base, commits, changed files and Godot 4.7 CI before merging.
- Integrate in dependency order. Retarget dependent PRs as predecessors enter `main`.
- Keep only one authoritative Scout implementation. PR #66 was a duplicate PR using the Scout head already used by #65; do not merge both.
- Re-check PR #37 (old depot cost-source work) against the functionality already present on main. The audit found it heavily diverged and touching shared supply, save, HUD and test files. Reconcile unique value before closing or superseding it; do not reintroduce duplicate cost-source logic.
- Re-check PR #49 (documentation-only Phase 06 status update) and retain only documentation that remains correct for current main.
- Reconcile stale/superseded branches only after inspecting their unique commits. Do not force-push or delete branches merely because they are old.
- Verify Classic and Frontier migration compatibility through the final integrated save version.
- Refresh README, CONTEXT, roadmap and test documentation after integration.

**Acceptance criteria:**

- One implementation per specialist role.
- No duplicate job registration, hotkey, building definition or sprite registration.
- Save migration tests cover all supported historical versions and the resulting current version.
- Godot 4.7 import, parse, full regression and both Frontier performance diagnostics pass.
- Mainline docs describe actual mainline state, not work that only exists on branches.

**Dependency:** Complete this baseline integration before Developers E–I begin modifying the shared host files listed below.

---

## 2. Priority 1 — Parallel workstreams

These assignments have the clearest ownership boundaries. Developers A and B can begin independently of the specialist integration. Developer C should build against the stabilized post-integration gameplay API. Developer D must first have the stale PR #37 disposition decided.

### DEV-A — Data contract validation

**Priority:** High  
**Start:** Immediately  
**Primary owner files:**

- `scripts/autoload/data_db.gd`
- New `tests/data_db_validation.gd`
- Optional isolated validation helper under `scripts/autoload/`

**Problem:** DataDB loads JSON files and populates dictionaries, but does not comprehensively validate structures, identifiers, ranges or cross-file references. Invalid data can fail later inside unrelated gameplay code.

**Scope:**

- Validate JSON root types and required fields for buildings, enemies, archetypes, waves, events, technologies, campaigns, factions and Frontier objectives.
- Reject duplicate IDs within each registry.
- Validate cross-references: faction rosters, enemy archetypes, technology prerequisites, building unlocks, campaign definitions and objective references.
- Validate resource keys, costs, capacities, time values, ranges, weights and other bounded numeric fields.
- Produce actionable errors that identify the source file, record ID, field and invalid value.
- Separate validation from data loading so tests can provide fixtures without mutating the live game database.
- Fail early in development rather than allowing malformed records to propagate.

**Out of scope:** Rebalancing the actual JSON values or changing gameplay formulas.

**Acceptance criteria:**

- All current mainline JSON files validate.
- Tests reject duplicate IDs, malformed records, invalid references and out-of-range values.
- Tests accept valid optional fields and backward-compatible data.
- A bad record produces a useful diagnostic rather than an unrelated runtime crash.
- Existing gameplay and save behavior remains unchanged.

**Isolation:** Do not change the CI manifests. Add the test script and ask the integration lead to register it.

### DEV-B — Faction camp architecture

**Priority:** High  
**Start:** Immediately  
**Primary owner files:**

- `scripts/systems/faction_camps.gd`
- New focused modules under `scripts/systems/`
- New focused regression test if necessary

**Problem:** The current 465-line manager combines deterministic camp placement, patrol generation, reinforcement lifecycle, target discovery, faction raids, timers and persistence-facing state.

**Scope:** Split internal responsibilities while preserving the manager's existing public interface.

Suggested modules:

| Module | Responsibility |
|---|---|
| Camp placement | Deterministic, region-valid site selection |
| Patrol director | Patrol route selection, leash and return behavior |
| Reinforcement controller | Initial patrols, finite budgets and cooldowns |
| Faction raid director | Exposed-target selection, dispatch and retreat |
| Camp manager | Coordinates components and preserves the existing external API |

- Give each component explicit inputs and outputs.
- Keep per-camp state owned in one place; do not duplicate timers, budgets or target state.
- Preserve territory, fog, region and reachability restrictions.
- Preserve active-enemy and path-check budgets.
- Retain deterministic initialization and save/reload behavior.
- Keep enemy entities responsible for their own movement and combat; camp directors should issue orders rather than duplicate enemy AI.

**Out of scope:** New factions, new enemy archetypes, new raid mechanics or balance changes.

**Acceptance criteria:**

- Existing camp placement remains deterministic.
- Patrols respect region and leash constraints.
- Reinforcements remain finite and bounded.
- Raid targets are revalidated and invalid targets cause safe withdrawal.
- Destruction and reload cleanup work without orphaned enemies or reservations.
- Existing `faction_camps_patrols`, `faction_raids` and `faction_warfare_stress` tests pass.

**Isolation:** Do not edit shared CI manifests. Avoid changing `enemy.gd` unless a documented interface defect makes it unavoidable; request the integrator to coordinate any such change with Developer I.

### DEV-C — Full campaign simulation QA

**Status:** Complete through PR #73; deterministic Classic/Frontier simulations are integrated and CI-registered.

**Priority:** High  
**Start:** After INT-0 integration  
**Primary owner files:**

- New `tests/frontier_campaign_simulation.gd`
- Optional isolated simulation fixtures/helpers under `tests/`

**Problem:** The existing `campaign_combat_simulation.gd` runs selected encounters using damage/cooldown transactions. It does not simulate complete waves, autonomous AI or pathfinding. Current benchmark results therefore cannot establish full campaign survivability.

**Scope:**

Build a deterministic, bounded, headless campaign simulation that exercises:

- Day/night and wave progression.
- Worker assignment, production and population upkeep.
- Construction and repairs.
- Enemy movement, pathfinding and autonomous targeting.
- Faction patrols, reinforcements and raids.
- Depot connectivity, shipments and supply pressure.
- Regional objectives and stronghold progression.
- Save/load at selected checkpoints.
- Final campaign conditions and game-over conditions.

Produce structured diagnostic metrics, including:

- Day, act and wave reached.
- Keep/player health.
- Population and deaths.
- Resource balances and shortages.
- Buildings lost/damaged.
- Objective and stronghold progression.
- Enemy survivors and raid outcomes.
- Save/reload checkpoint results.
- Total simulated ticks and runtime.

Use explicit seeds and bounded workloads. Do not turn an excessively long or unstable full-campaign run into a blocking CI test without measuring its runtime first. Separate a fast deterministic regression from a longer diagnostic profile when necessary.

**Out of scope:** Changing balance values to make the simulation pass. Report failures first; balancing is a separate review.

**Acceptance criteria:**

- Repeatable results from the same seed and engine version.
- Classic and Frontier remain separate test profiles.
- The simulation uses real gameplay systems, not a second copy of their rules.
- Failures identify the day, system and relevant state.
- Runtime and resource use are bounded and documented.
- Existing assertion suites remain unaffected.

**Dependency:** Build after specialist integration so the simulation includes the final job roster and current public APIs.

### DEV-D — Supply network decomposition

**Status:** Partially complete through PR #75; cost transactions have been extracted. Continue only with distinct shipment, graph or pressure responsibilities.

**Priority:** High  
**Start:** After INT-0 and after PR #37 is reconciled  
**Primary owner files:**

- `scripts/systems/supply_network.gd`
- New focused modules under `scripts/systems/`
- Focused logistics regression tests

**Problem:** The current 805-line `SupplyNetwork` façade still coordinates depot connectivity, stockpile transfers, shipment orders, cargo recovery and supply pressure. Cost-source selection, affordability, payment and refunds have already been extracted into `SupplyCostTransactions` by PR #75.

**Scope:** Retain `SupplyNetwork` as a stable façade while moving responsibilities into explicit services.

Suggested modules:

| Module | Responsibility |
|---|---|
| SupplyGraph | Road/depot connectivity and route-derived state |
| DepotLedger | Stock balances, accepted resource types and capacities |
| CostTransactionService | Atomic payment, refunds and selected cost source |
| ShipmentManager | Orders, reserved cargo/capacity, carriers and recovery |
| SupplyPressureDirector | Isolation timers, warning state, sabotage dispatch and recovery |

- Keep all inventory mutations centralized.
- Ensure an order reserves cargo and destination capacity exactly once.
- Preserve cancellation, path interruption, invalidation and recovery semantics.
- Preserve the rule that disconnected depots cannot participate in connected logistics or remote spending where prohibited.
- Preserve deterministic pressure timers, bounded raids and theft rules.
- Preserve save-v13 compatibility on the audited baseline; if the specialist stack has already advanced the schema, use the integrated current schema instead.
- Avoid making the HUD responsible for ledger or transaction rules.

**Out of scope:** New trade economy, markets, additional resource types or balance changes.

**Acceptance criteria:**

- No double spending, duplicated cargo or negative stock.
- Shipment interruption and cancellation recover reserved cargo correctly.
- Destination capacity reservations cannot be overbooked.
- Disconnected depot behavior remains correct.
- Supply warning/raid behavior remains deterministic and bounded.
- Existing logistics tests pass: local depots, physical shipments, depot cost sources, supply pressure and faction raids.

**Hard dependency:** Decide whether PR #37 contains any unique work worth recovering. Do not develop a second implementation of its cost-source functionality.

---

## 3. Priority 2 — Core architecture decomposition

**Start condition for all tasks below:** INT-0 is integrated and the current mainline API/save schema is stable. These tasks are deliberately separate because they touch high-conflict host files.

### DEV-E — Save and migration architecture

**Status:** Phase 1 complete through PR #77: snapshot validation is extracted to `scripts/persistence/save_validator.gd`; `SaveSystem._valid_save()` remains the compatibility façade. Phase 2 complete through PR #81: `scripts/persistence/save_migration_pipeline.gd` builds an in-memory scene-restore plan and owns the restore-time version gates. This is not an on-disk rewrite of historical saves; save-file I/O/recovery decomposition and canonical v17 conversion remain later slices.

**Priority:** Critical  
**Primary owner files:**

- `scripts/autoload/save_system.gd`
- New persistence/migration modules under `scripts/autoload/` or `scripts/persistence/`
- New migration-focused tests

**Problem:** `scripts/autoload/save_system.gd` is now 248 lines after PR #77 and the Barracks garrison save-field addition on PR #78. Snapshot validation is in `scripts/persistence/save_validator.gd` (773 lines); restore-time version branching was still embedded in `scripts/main.gd` before this phase.

**Scope:**

- Separate save collection from save-file I/O.
- Separate top-level validation from campaign, world, entity, inventory and specialist-state validation.
- Introduce explicit sequential migration functions for supported historical versions.
- Keep current-version validation separate from migration.
- Preserve temporary-write and backup-recovery behavior.
- Keep Classic and Frontier profile compatibility rules explicit.
- Preserve optional/additive fields without invalidating older supported saves.
- Document the current schema and each migration boundary.

**Out of scope:** Replacing the save format with a new serialization framework or dropping historical versions.

**Acceptance criteria:**

- Every supported historical Classic and Frontier fixture loads or is rejected for the documented reason.
- Each migration is independently testable.
- Interrupted writes and backup recovery remain covered.
- Current saves round-trip without data loss.
- No entity-specific state silently disappears.
- Full regression suite passes.

**Conflict warning:** Specialist PRs modify `save_system.gd`. Do not start before their integration is complete.

### DEV-F — Villager role architecture

**Priority:** Critical  
**Primary owner files:**

- `scripts/entities/villager.gd`
- New role behavior modules under `scripts/behaviors/villagers/` or another agreed directory
- Focused role regression tests

**Problem:** `villager.gd` is 1,530 lines and combines movement, pathing, work selection, gathering, construction, combat, guarding, expeditions, carrying and delivery.

**Scope:**

Extract shared lifecycle and independent role behavior without duplicating common movement or reservation rules.

Expected role behaviors after specialist integration:

- Woodcutter.
- Miner.
- Farmer.
- Builder.
- Soldier.
- Hunter.
- Scout.
- Healer.
- Blacksmith.

Shared responsibilities should remain centralized:

- Path calculation and movement.
- Workplace capacity/reservations.
- Work radius and reachable-target validation.
- Carrying and depot delivery.
- Night behavior and survival lifecycle.
- Job changes and reservation cleanup.
- Save-state export/restore.

Role components should define task selection, work action and role-specific state. They must not independently implement a second pathfinder or inventory system.

**Out of scope:** Adding new professions or changing yields, treatment rates, equipment stats or economy balance.

**Acceptance criteria:**

- Every current role preserves its existing behavior.
- Switching jobs releases old reservations and claims the new workplace correctly.
- Destroyed workplaces, targets and depots do not leave stale assignments.
- Path invalidation and save/reload remain correct.
- Existing workplace, production, construction, specialist and combat tests pass.

**Conflict warning:** Do not start while PRs #64–#68 are still being integrated. They modify `villager.gd`, job definitions, UI and save state.

### DEV-G — HUD modularization

**Priority:** High  
**Primary owner files:**

- `scripts/ui/hud.gd`
- New components under `scripts/ui/components/` or an agreed directory
- Focused UI regression tests

**Problem:** `hud.gd` is approximately 1,900 lines and builds/coordinates nearly every UI feature.

**Scope:**

Separate the HUD into independently maintained components:

- Resource/status bar.
- Player/Keep vitals and combat skills.
- Job drawer and specialist controls.
- Depot management and shipment controls.
- Construction queue.
- Strategic map integration.
- Objective tracker.
- Technology integration.
- Pause/help/notification surfaces.
- Shared viewport and layout coordinator.

The root HUD should coordinate component lifecycle, global layout and event wiring. UI components may issue commands but must not implement gameplay rules or directly own economic transactions.

Preserve the existing controls and mouse-blocking behavior.

**Out of scope:** A new visual redesign or changing the game's HUD density/layout contract.

**Acceptance criteria:**

- All existing buttons, keyboard controls and panels work.
- Panels open/close without conflicting overlays.
- Resolution changes keep the HUD within the safe area.
- Job, depot, shipment, construction and objective state refresh correctly.
- No duplicate event subscriptions or leaked controls.
- Existing HUD click, responsive layout, input and map tests pass.

**Conflict warning:** Specialist PRs add job rows and controls to `hud.gd`. Wait for INT-0.

### DEV-H — World generation architecture

**Priority:** Medium  
**Primary owner files:**

- `scripts/world/world_map.gd`
- New modules under `scripts/world/generation/`
- Focused world-generation regression tests

**Problem:** `world_map.gd` is 822 lines and contains Classic and Frontier terrain, resource placement, biome decoration, landmarks, iron veins and Expedition barrier logic.

**Scope:**

Separate generation into explicit stages:

1. Profile and deterministic RNG setup.
2. Terrain/biome generation.
3. Resource placement.
4. Decoration and landmark placement.
5. Expedition barriers and reachable landings.
6. Final world validation.

Keep the Classic generator behavior isolated and stable. Use independent RNG streams for optional decorations and content that must not alter the resource-generation sequence.

Preserve the fully generated/loaded world model. Do not introduce runtime chunk streaming.

**Out of scope:** New world dimensions, new biomes or a new map-generation algorithm.

**Acceptance criteria:**

- Identical profile/seed produces identical terrain, resource and gate state.
- Classic generation remains unchanged.
- Frontier and Expedition reachability invariants hold.
- Resources, decorations and structures do not overlap illegally.
- Save/reload reconstructs Expedition gates from persisted discovery state.
- Existing world_config, frontier_world and frontier_expedition tests pass.

**Conflict warning:** Scout and Hunter work adds exploration/resource integration to world generation. Wait for INT-0.

### DEV-I — Enemy controller decomposition

**Status:** Patrol movement is complete through PR #74. Further work must not reimplement `EnemyPatrolMovement`.

**Priority:** Medium  
**Primary owner files:**

- `scripts/entities/enemy.gd`
- New modules under `scripts/behaviors/enemies/` or the existing `scripts/behaviors/`
- Focused enemy lifecycle regression tests

**Problem:** `enemy.gd` is approximately 975 lines. The project already has six archetype behavior modules; the next step is to reduce host responsibilities without reimplementing those behaviors.

**Scope:**

Separate shared host responsibilities into focused components:

- Combat lifecycle and attack resolution.
- Movement/path following.
- Target selection and target validation.
- Patrol/garrison movement.
- Faction/supply raid movement.
- Shared animation and visual feedback coordination.

Keep archetype-specific policy in the existing behavior components:

- Beast Rider.
- Shieldbearer.
- Scout.
- Saboteur.
- Siege Engine.
- War Shaman support.

Do not move behavior into a second duplicate controller. Define narrow interfaces and preserve current telegraphs, attack timing, stagger rules, target priorities and save behavior.

**Out of scope:** New archetypes, new attacks or balance changes.

**Acceptance criteria:**

- Existing enemy roles preserve their combat behavior.
- Target invalidation and stagger cancellation work.
- Patrols, garrisons and raid units retain their restrictions.
- Attack/impact timing and visual feedback remain synchronized.
- Existing archetype, faction raid, campaign and stress tests pass.

---

## 4. Priority 3 — Gameplay and product expansion

These are feature assignments, not prerequisites for the architecture work. They should start only when the assigned owner can implement them without modifying an active architectural refactor.

### DEV-J — Decision-based event system

**Status:** Complete through PR #72, including decision UI, resource-gated choices, delayed consequences and v17 persistence.

**Priority:** Medium  
**Suggested files:** New event/decision modules, `scripts/systems/event_manager.gd`, new event definitions and focused tests.

**Scope:**

- Extend random notifications into actual player decisions.
- Support choices with resource costs, eligibility requirements and delayed consequences.
- Persist unresolved/selected event state where needed.
- Allow consequences to affect population, buildings, trade, factions and campaign state through defined interfaces.
- Keep event definitions data-driven.
- Provide clear UI presentation and prevent invalid choices.

**Acceptance:** Tests cover eligibility, cost payment, cancellation, choice resolution, delayed outcomes, save/reload and Classic/Frontier applicability.

**Live status:** Implementation is in `work/dev-k-input-command-registry`: 39 rebindable actions cover movement/combat, jobs, building slots and system/strategy commands. Gamepad defaults and keyboard restore-defaults are included; Godot 4.7 CI remains the acceptance gate.

### DEV-K — Complete input command registry

**Priority:** Medium  
**Suggested files:** `scripts/autoload/input_setup.gd`, settings/input modules, pause-menu controls and focused tests.

**Scope:**

- Define one registry for movement, interaction, combat, jobs, construction, panels and strategic commands.
- Support keyboard and gamepad bindings.
- Make all player-facing shortcuts rebindable where technically appropriate.
- Detect duplicate/conflicting bindings and reserved keys.
- Persist bindings and restore defaults.
- Keep mouse placement and UI click behavior separate where rebinding would be inappropriate.

**Acceptance:** All documented shortcuts are discoverable, rebindable where supported, conflict-checked and persist correctly.

### DEV-L — Economy and facilities design/implementation

**Priority:** Later / feature-gated  
**Suggested files:** Data definitions, focused production/workplace modules, building UI integration and tests.

**Candidate facilities:**

- Barracks.
- Archery Range.
- Market.
- Siege Workshop.
- Stables.
- Fortress.
- Signal Beacon.
- Bridge/Gate improvements.

**Rules:**

- Do not implement a building merely to increase the building count.
- Each facility needs a distinct gameplay function, input/resource cost, output or tactical effect, unlock rule and clear counterplay.
- Introduce leather, gold or any new resource only when at least one real gameplay loop consumes and produces it.
- Keep each facility as a separate vertical slice with data, implementation, visual identity, UI, save behavior and regression coverage.

**Acceptance:** Each accepted building has a demonstrable gameplay purpose and a tested end-to-end interaction. This task must begin with a design proposal for each facility, not a bulk JSON dump.

### DEV-M — Visual identity and rendered gameplay QA

**Priority:** Medium  
**Suggested files:** Relevant SVG assets, `tools/gen_assets.py`, isolated visual components and rendered QA artifacts.

**Known presentation shortcuts from the audited mainline:**

- Archer currently reuses the Bandit texture.
- Brute currently reuses the Soldier texture.
- Builder currently reuses the Miner texture.

**Scope:**

- Replace role/archetype texture reuse with distinct silhouettes and equipment.
- Verify animation readability at normal gameplay zoom.
- Verify buildings and faction identity are distinguishable under day/night, fog and combat.
- Review objective markers, construction stages, damage feedback and HUD overlap.
- Capture rendered screenshots at supported desktop aspect ratios and fullscreen.
- Record subjective issues separately from automated failures.

**Acceptance:** No shipped specialist/archetype relies on an unrelated placeholder texture; rendered evidence is attached to the PR; no collision, anchor or animation timing regressions.

---

## 5. Parallel execution schedule

| Stage | Assignments | Parallelism |
|---|---|---|
| 0 — Baseline | INT-0 specialist integration | Sequential |
| 1 — Independent work | DEV-A, DEV-B | Parallel immediately |
| 1b — Stable gameplay APIs | DEV-C | Starts after INT-0 |
| 1c — Logistics baseline | DEV-D | Starts after INT-0 and PR #37 disposition |
| 2 — Host decomposition | DEV-E, DEV-F, DEV-G, DEV-H, DEV-I | Separate branches after INT-0; coordinate interfaces before edits |
| 3 — Product features | DEV-J, DEV-K, DEV-L, DEV-M | Parallel only where file ownership does not overlap |

### Important concurrency restrictions

- DEV-A owns `data_db.gd`; other developers should consume its interface, not modify it.
- DEV-B owns `faction_camps.gd` and its new camp/patrol/raid modules; DEV-I must coordinate before changing enemy-facing interfaces.
- DEV-C owns its simulation scripts and fixtures; the integration lead alone updates shared CI manifests.
- DEV-D owns the supply façade and logistics modules; do not let DEV-E or DEV-G reimplement supply validation or transactions.
- DEV-E owns persistence and migrations; no other developer changes schema/version handling without coordination.
- DEV-F owns the villager host and role behaviors; no other developer changes job lifecycle code during that refactor.
- DEV-G owns HUD composition and UI components; gameplay systems expose state/commands rather than adding UI logic.
- DEV-H owns world generation; DEV-F/DEV-C consume world APIs instead of adding new generation logic.
- DEV-I owns enemy host/controller boundaries; DEV-B uses the agreed enemy interface.
- DEV-J owns event decisions; event effects must use the public economy/campaign interfaces.
- DEV-K owns input command registration and binding settings; feature developers request commands rather than registering shortcuts ad hoc.
- DEV-L must not start bulk facility work while DEV-D, DEV-F or DEV-G is changing the related economy/job/UI contracts.
- DEV-M should coordinate asset identifiers with gameplay owners. Visual-only changes must not alter gameplay values.

**Do not run two developers against the same production file just because they have different task names.** If overlap is unavoidable, agree on an interface or merge one prerequisite PR before the dependent task starts.

---

## 6. Definition of done for every developer

A task is complete only when all applicable requirements are met:

- [ ] Scope matches this worklist; unrelated changes are excluded.
- [ ] Branch is based on the correct current mainline or approved dependency branch.
- [ ] New modules have one clear responsibility and documented public interfaces.
- [ ] Existing gameplay behavior is preserved unless a behavior change was explicitly requested.
- [ ] New/changed logic has focused Godot 4.7 regression coverage.
- [ ] Save/load and migration behavior are covered when persistent state changes.
- [ ] Godot 4.7 project import succeeds.
- [ ] All GDScript files parse successfully.
- [ ] Focused regression tests pass.
- [ ] Full current mainline regression suite passes.
- [ ] Frontier performance diagnostics are checked for material regressions when AI, world or simulation work changes.
- [ ] Rendered/manual QA limitations are explicitly recorded.
- [ ] PR description identifies changed files, behavior, tests, risks, dependencies and remaining work.
- [ ] Shared CI/test documentation updates are left to the integration owner unless specifically assigned.

---

## 7. Recommended assignment commands

Use these as direct work orders:

- **"Dev A: implement data contract validation from worklist.md. Work only in the assigned ownership boundary and open a PR."**
- **"Dev B: decompose faction camp management according to worklist.md. Preserve behavior and public APIs."**
- **"Dev C: implement deterministic full-campaign simulation QA from worklist.md after the specialist stack is integrated."**
- **"Dev D: decompose the supply network according to worklist.md after PR #37 is reconciled."**
- **"Dev E: implement save/migration architecture from worklist.md after specialist integration."**
- **"Dev F: decompose villager role behavior from worklist.md after specialist integration."**
- **"Dev G: modularize the HUD according to worklist.md after specialist integration."**
- **"Dev H: decompose world generation according to worklist.md after specialist integration."**
- **"Dev I: decompose the enemy controller according to worklist.md after specialist integration."**
- **"Dev J: implement the decision-based event system from worklist.md."**
- **"Dev K: complete the input command registry from worklist.md."**
- **"Dev L: propose and implement one facility vertical slice from worklist.md; do not bulk-add buildings."**
- **"Dev M: perform the visual identity and rendered gameplay QA pass from worklist.md."**

When starting any assignment, first inspect current `main`, open PRs and remote branches. This document records the audit baseline, not a permanent substitute for live repository state.

---

## 8. Audit notes

The audited mainline did not show obvious literal TODO/FIXME/stub markers in the initial code-search pass. The worklist therefore prioritizes verified responsibility concentration, missing validation boundaries, insufficient end-to-end simulation coverage and documented product gaps rather than inventing placeholder files.

The highest-risk structural areas are:

1. `save_system.gd` — large validation/migration surface and expanding persistent state.
2. `villager.gd` — growing profession count and shared task lifecycle.
3. `supply_network.gd` — inventory, payment, shipment and pressure responsibilities.
4. `hud.gd` — UI composition and gameplay-adjacent behavior in one large script.
5. `enemy.gd` / `faction_camps.gd` — growing autonomous AI and faction lifecycle.
6. `world_map.gd` — multiple deterministic generation stages in one script.

**Primary objective:** make future gameplay development genuinely parallel by giving each subsystem a stable owner, narrow interface, independent tests and predictable integration boundary.
