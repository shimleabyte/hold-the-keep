# Hold the Keep — Parallel Developer Worklist

**Current implementation baseline:** Phase 11.1 production code is integrated at `10747392ecdaebc6b7490b43fb82cf2cfa389468` (2026-11-07); current main's pre-audit tip was docs-only `f9a6a443db0f2bb8593f77a8ac93f1d3b834f95d`. See [docs/BRANCH_REGISTRY.md](docs/BRANCH_REGISTRY.md) for the current 158-branch / 182-PR inventory, deferred work and retained candidates.  
## Gameplay-overhaul status — 2026-11-07

The audit baseline was remote `main` SHA `931cca8e065976da89a33d40ef42c5f70bd6b308`. Read [docs/GAMEPLAY_AUDIT.md](docs/GAMEPLAY_AUDIT.md) before assigning new gameplay work. The first implementation slice (Phase 11.2) makes the `ambush`, `fortress`, `attrition` and `siege` doctrines choose different rival building priorities, while retaining identical costs, finite ledgers and save v17. Regression coverage is in `army_command_and_rival_civilization`.

The rival production loop now uses a bounded eight-citizen workforce with doctrine-prioritized jobs, builder labor, worker/soldier upkeep and finite stockpiles. Storage expands capacity from 240 to 600 per resource; full stockpiles release workers to other jobs. Regression coverage checks staffing, upkeep, output, stockpile saturation and v17 over-cap preservation. Phase 11.5 now gives periodic rival reinforcements doctrine-specific target compositions and distinct paid unit costs; no recruitment occurs when no roster role is affordable. Next priorities are rendered opening/middle-game acceptance, physical resource extraction/logistics, rival territory/outposts and coordinated military planning. CI is not a fun/UX acceptance claim.


**Current implementation baseline:** the gameplay audit started from `931cca8e065976da89a33d40ef42c5f70bd6b308`. Phase 11.2 differentiated rival investment order; Phase 11.3 adds doctrine-prioritized labor, staffed production, worker/soldier food upkeep and labor-consuming construction. Historical branch/PR inventories below are snapshots, not live status. See [docs/GAMEPLAY_AUDIT.md](docs/GAMEPLAY_AUDIT.md) for current gaps.  
**Engine target:** Godot 4.7 only  
**Release target:** Desktop-first — Windows x86_64 and Linux x86_64. Android remains deferred.  
**Current save schema:** v17.

## Current integration status — 2026-11-07

Phase 11's initial rival-civilization and army-command implementation is integrated. The performance reconciliation and Phase 11.1 persistence hardening are also merged:

- **PR #175** — expanded Classic/Frontier/Expedition maps, rival civilization state and soldier-only army commands; merged at `fb3b167`.
- **PR #177** — bounded FlowField rebuild slices and cached regional land/control accounting; merged at `d5c2fe3`.
- **PR #178** — blocked rival-structure restoration now relocates deterministically or persists a pending record for retry; merged at `1074739`.
- Save schema remains **v17**. Pending rival structures are additive optional state. Existing v17 saves without a civilization snapshot remain valid.
- New campaigns use Classic 128×128, Frontier 192×192 and Frontier Expedition 256×256 (160×160 starting heartland). Existing 64×64 / 128×128 / 192×192 saves retain their saved profile dimensions.
- Player direct control remains active. Only living soldiers, including Archer-specialized soldiers, are selectable for army commands; civilian workers retain autonomous jobs.
- **PR #166/#167** are closed as superseded by #177. **PR #169** is closed without merge because it conflicts with the player-control/civilian-autonomy contract.
- PR #178's exact-head validation passed **63/63 Godot 4.7 CI jobs** (run #42316264733) and Campaign Simulation QA (run #42316264766). Post-merge Campaign Simulation QA passed on production code HEAD (run #42316677164). The next mainline Godot run on docs-only HEAD `f9a6a443` passed (run #42316888270); later registry/status documentation commits must be checked against their own push run.

## Active visual overhaul — Phase 08.9

**Foundation:** PR #179 merged to `main` at `27740a72`.  
**Active package:** PR #182 — [`art/phase-08.9-villager-character-family`](https://github.com/shimleabyte/hold-the-keep/tree/art/phase-08.9-villager-character-family).  
**Validated code head:** `8dc9b8e2a25f`.

Completed in PR #179:
- `docs/ART_DIRECTION.md` — authoritative visual bible covering material palettes, silhouettes, animation, architecture, biomes, effects, icons, lighting and acceptance gates.
- `docs/ART_REFERENCE_BOARD.md` — historical construction/clothing/armor and pixel-art references.
- Legacy generator protection for the hand-authored 24×28 blue-mantled player atlas.

Implemented in PR #182:
- Replaced the ten civilian role atlases with authored 440×60 SVG sheets (20×20 frames, 22 frames × 3 directional rows).
- Profession-specific silhouettes, clothing mass, headwear, belts/gear, work tools and seven animation states.
- Removed the civilian atlases from the generic humanoid generator and registered all ten as protected hand-authored sources.
- SVG/XML/grid validation, generator-ownership checks, animation-frame identity regression and byte-reproducibility checks for the remaining generator-owned Archer/Brute sheets.
- Godot-native 10-role sprite contact sheet and gameplay review captures at 1280×720, 1600×900 and 1920×1080.

**Exact-head validation:** Godot 4.7 CI passed 63/63 jobs (run #42323335962); Role Sprite Visual QA passed (run #42323335969); deterministic Frontier Rendered World QA passed (run #42323335991). The gameplay capture was visually inspected after correcting the test fixture's auto-job-assignment interference.

**Still open:** faction-specific enemy/military art, buildings and construction/damage states, biome terrain/resource/wildlife/props, VFX, HUD/map icons, whole-world multi-resolution screenshots and target-desktop performance review. Existing gameplay/AI/economy/collision/save behavior remains unchanged. Do not mark the full visual overhaul complete until those packages and the final human review exist.

Execution order: enemy/faction identity → architecture → terrain/biomes/resources/props → combat/UI art → full rendered review. Keep workstreams isolated and merge only after exact-head Godot 4.7 validation.

### Player animation and protagonist motion — PR #181 (active)

**Branch:** `animation/player-motion-timing`  
**PR:** [#181](https://github.com/shimleabyte/hold-the-keep/pull/181)  
**Specification:** `docs/ANIMATION_DIRECTION.md`

- [x] Separate the player's 30-frame atlas from shared 22-frame civilian/enemy sheets.
- [x] Add dedicated pick/axe harvest and heavy Cleave pose ranges.
- [x] Synchronize light/heavy impact frames to existing gameplay event markers.
- [x] Preserve harvest timing/yield, combat damage/range/cooldowns and player-control behavior.
- [x] Add animation timing, frame identity, foot-contact and attack-to-hurt interruption regressions.
- [x] Add dedicated six-pose Dash/Rally and four-pose Hurt/Death-preview ranges without changing ability timers or respawn gameplay.
- [x] Produce a Godot-rendered playblast artifact with exact light/heavy impact samples.
- [ ] Pass exact-head 46-frame CI and inspect the sprite-only Dash/Rally/Hurt/Death contact sheet.
- [ ] Refine locomotion/cape/weapon overlap and review all three facing rows before broad enemy/faction animation production.

This is a presentation package. Do not alter economy, enemy AI, save schema, harvest yields, combat balance, civilian autonomy or the civilian art contract. Three facing rows are not eight-direction animation.

### Phase 11 acceptance still open

- Human rendered/playable review of a Classic rival settlement and expanded Frontier/Expedition campaigns.
- Old-save continuation and save/reload review across all three profiles on a desktop build.
- Target-PC p50/p95/p99 and worst-frame profiling during rival construction, garrison recruitment and active waves.
- Distinct faction strategy, rival military training queues, secondary settlements and rival supply/territory are follow-on phases, not part of the current implementation.

The remainder of this file retains the earlier parallel worklist as a historical architecture and task record. Its old audit SHAs, branch states and CI counts are not the current repository status.

## Historical execution snapshot — 2026-11-05 (superseded by the current integration status above)

**Historical main at this feature audit:** `a76077eb13de8489d706eca7e98c6063fad56aa6`. The software-side P0–P2 implementation is merged. Current-main changes include time-sliced enemy FlowField rebuilds, complete-snapshot publication, coalesced worker reassignment, worker animation redraw fixes, low-cost baked profession feedback, Builder reachability recovery, multi-cell navigation fallback, desktop resolution coverage, Godot 4.7 export guards, save-file recovery regression coverage, worker lifecycle regression coverage, and partial-quota HUD guards. Save schema remains v17.

### P0 — gameplay blockers

| Symptom | Merged implementation | Evidence | Remaining acceptance |
|---|---|---|---|
| Building placement/completion causes a frame hitch | **PR #146:** FlowField Dijkstra is time-sliced (2,048 heap pops/frame default); incomplete paths are not published; Village reassignment is coalesced across construction transitions. | Construction-transition diagnostic and Frontier performance diagnostic passed on the tested PR head. PR #162 and #163 add no production FlowField changes. | Capture frame-time p50/p95/p99 and worst frame on the actual desktop target during place, completion, demolition, destruction and active night waves. CI runner timing is not target-PC proof. |
| Workers remain visually stuck while doing manual work animation | **PR #148:** SpriteAnim compares the last rendered clip/frame/offset/facing and requests redraw when the manual work frame changes. **PR #158:** adds baked per-profession contact marks without extra runtime textures or draw calls. | Godot 4.7 animation regression and role-sprite visual QA passed on the tested PR head. | Inspect full Woodcutter, Miner, Farmer, Builder and Blacksmith cycles in all three directions in a windowed desktop run. |
| Builder ignores distant blueprints despite a valid route | **PR #155:** removes the arbitrary workplace-radius rejection for construction-site targets; bounded A* reachability determines whether a blueprint can be reached. | Builder Reachability QA passed on the current-main worker-feedback PR head. Lifecycle regression also passes workplace-loss/recovery behavior. | Retest distant reachable and genuinely unreachable blueprints in Frontier and Expedition during a live session. |

### P1 — correctness and reliability

| Area | Merged change | Evidence | Remaining acceptance |
|---|---|---|---|
| Multi-cell target approach selection | **PR #157:** `NavGrid.path_adjacent()` tests the full sorted walkable perimeter rather than only the nearest four cells; tie-breaking is deterministic. Regression fixture blocks the nearest four and leaves a farther route open. | PR #157 Godot CI passed 55/55. Its corrected `frontier_world` suite waits for the asynchronous FlowField snapshot before measuring road invalidation. | Validate real multi-cell workplace access in a long Frontier/Expedition playthrough. |
| Autonomous worker lifecycle recovery | **PR #159:** regression for job reassignment, destroyed workplace recovery, depleted resource replacement, night recall and valid v17 save state. | Godot 4.7 CI passed 56/56, including `villager_lifecycle_recovery`. | Keep this suite in the blocking regression matrix; verify no long-session stalls in a manual playthrough. |
| Profession contact feedback and low-cost AI effects | **PR #158:** baked work contact accents for five professions; AI resource-hit particles/tweens and repeated Builder/Blacksmith/Farmer bursts removed; direct player harvesting retains immediate hit feedback. | Godot CI passed 55/55; Campaign Simulation, Rendered World, Role Sprite Visual and Builder Reachability QA passed on the tested head. | Review profession-cycle readability and contact timing in the actual desktop renderer. |
| Save-file replacement and rollback | **PR #162:** test-only contract coverage for valid primary replacement, backup promotion, corrupt-primary recovery, unsupported schema rejection, failed temp writes and preservation of durable copies. JSON-decoded snapshots are checked by persisted invariants rather than in-memory container equality. | Godot 4.7 CI passed 57/57, including `save_file_store_recovery`. No production storage behavior or schema changed. | Keep this suite in the blocking regression matrix; destructive failure modes are simulated by the test, not by power-cut testing on a physical disk. |
| Partial job-quota HUD state | **PR #163:** HUD job rows default absent assigned/quota keys to zero; `workplace_assignments` exercises partial quota reassignment. | Focused `workplace_assignments` passed. PR matrix completed 55/56 successful jobs with no failures; the final `frontier_stress` job remained stuck in checkout and never reached Godot. The post-merge mainline Godot run is the final integration check. | Confirm the post-merge mainline CI result and retain the partial-quota regression. |
| Autonomous night-wave simulation | **PR #135:** full-runtime Classic/Frontier night-wave diagnostic is integrated. | Autonomous Wave Diagnostic run #42047709997 passed; Campaign Simulation QA passed on the tested current-mainline heads. | A deterministic simulation does not establish campaign balance. Complete a human Classic and Frontier session. |

### P2 — desktop release readiness

| Area | Merged implementation | Evidence | Remaining acceptance |
|---|---|---|---|
| Resolution coverage | **PR #157:** responsive layout regression includes 960×540 through 2560×1440, including a 1280×720 logical viewport at 2× scale. | Godot 4.7 `responsive_layout` passed in the PR #157 55/55 matrix. | Windowed/fullscreen visual inspection at 1280×720, 1920×1080 and 2560×1440 on a real desktop. |
| Desktop export scripts | **PR #157:** `tools/build.sh` and `tools/build.ps1` require Godot 4.7, run Windows/Linux release exports and check that both output files are non-empty. | Static review and Godot CI; export templates are not installed in the development runner. | Install matching Godot 4.7 export templates and run both scripts on real Windows/Linux environments. Verify the binaries launch on clean machines. No release artifact is claimed yet. |
| Desktop documentation | **PR #157:** README documents required templates, commands, artifact paths and QA targets. | README is merged on main. | Confirm the commands and actual artifact names against the target machines after exports run. |
| Input, save/load, audio and sustained play | Existing system suites cover input rebinding, player combat, save/migration, audio identity and campaign systems. | These are represented in the 56/57-job Godot matrices. | Manual keyboard/mouse and gamepad review, windowed/fullscreen transition, save/load, audio listening, and 10-minute Classic plus Frontier playthrough. |
| Android | Deferred by the desktop-first scope. | No ARMv7 physical-device acceptance is claimed. | Do not treat Android as part of this desktop pass. |

### Performance measurement policy

Run `godot --path . --script res://tools/performance_probe.gd` in a **windowed** session at a fixed resolution on the target PC. The probe records world creation, navigation/FlowField/territory/job-assignment/fog timings, scene/resource/physics counts, and idle versus active-wave frame samples. Compare before/after on the same PC/settings.

Use 16.67 ms as the 60 FPS frame budget. Report p50/p95/p99 and worst-frame spikes separately; averages alone can hide construction hitches. The CI performance diagnostics are useful regression signals, but headless/GitHub runner values do not certify target desktop performance.

### Current integration state

- Main baseline before the partial-quota merge, `849cdec891108683d4ed6f08f7977500ea9bc213`, passed the full Godot 4.7 matrix 56/56 (run #42052385169).
- PR #162 passed 57/57 Godot 4.7 jobs on current main, including the save-file recovery test.
- PR #159 passed 56/56 Godot 4.7 jobs, including worker lifecycle recovery.
- PR #158 passed 55/55 Godot 4.7 jobs plus Campaign Simulation, Rendered World, Role Sprite Visual and Builder Reachability QA.
- PR #163's HUD partial-quota regression passed; its matrix had 55 successful jobs and one `frontier_stress` job stalled during checkout. It reported no test failures. The post-merge mainline run is the final integration check.
- PRs #148, #146, #155, #157, #158, #159, #162 and #163 are merged. Old overlapping branches/PRs #149, #151, #153, #156, #160 and #161 are closed or superseded.
- No real windowed target-PC acceptance, physical export, clean-machine startup, audio listening or human campaign-balance sign-off is claimed complete.

| Workstream | Current disposition |
|---|---|
| INT-0 specialist integration | Complete: Hunter, Scout, Healer and Blacksmith integrations are on main. |
| DEV-A data contract validation | Complete through PR #71 replacement. |
| DEV-B faction camp architecture | Integrated through PR #70. Preserve public camp/patrol/raid interfaces. |
| DEV-C campaign and runtime simulation QA | Deterministic campaign simulation is integrated through PR #73. PR #135 adds a full-runtime Classic/Frontier night-wave diagnostic. Execution remains unverified; a successful Godot 4.7 full-night artifact is still required. |
| DEV-D supply network decomposition | **Priority 1 complete.** PR #75 extracted cost transactions; #94 shipment ledger; #96 dispatch/recovery; #97 road graph; #99 supply pressure controller. Keep the stable façade unless a new cohesive responsibility is demonstrated. |
| DEV-E save/migration architecture | Complete through #89: canonical v17 conversion and file-store recovery are integrated. Schema remains v17. |
| DEV-F villager role architecture | Five role slices integrated: Archer, Scout, Healer, Blacksmith and Builder. Shared movement, navigation, workplace claims, carrying, animation and persistence remain host-owned. |
| DEV-G HUD modularization | Main widget, construction queue and outpost/logistics boundaries are integrated. `hud.gd` remains the root composition/layout coordinator. |
| DEV-H world generation / rendered QA | Generator decomposition and deterministic Frontier render harness are on main. PR #138 adds the repeatable Godot 4.7 + Xvfb/Mesa same-seed render workflow. The original workflow passed on PR #133. The rendered workflow passed on its tested PR head; verify current-main captures whenever the mainline render workflow runs. Do not change generation behavior merely to reduce file size. |
| DEV-I enemy controller | Patrol movement, raid behavior and shared combat lifecycle are integrated. Archetype behavior modules remain separate. |
| DEV-J decision-based events | Integrated through PR #72. |
| DEV-K input command registry | Integrated through PR #76. |
| DEV-L Barracks | Integrated through PR #78. |
| Archery Range / ranged soldiers | Integrated through PR #87. |
| DEV-M visual identity / rendered QA | PR #129 is merged. Builder, Archer and Brute have dedicated animated sprite sheets; the generator reproduces the committed assets; Brute visual scale is data-driven. The tested head passed 54/54 regression checks, Campaign Simulation QA and rendered gameplay-zoom QA. Continue auditing other role/faction art and audio separately; do not reopen these assets without evidence. |
| Android ARMv7 / touch controls | PR #136 ports the Android ARMv7-only debug export, safe-area-aware virtual controls and multi-touch regression onto current main while retaining role-sprite CI checks. CI validation must be checked on the current PR head; physical Android acceptance remains deferred by the desktop-first release policy. Godot parse, APK export, ABI verification and physical-device behavior are **not validated**. PR #128 is closed as superseded. |

### Recent integrations

- **#138 — DEV-H rendered Frontier QA workflow:** merged at `6f1886c`. Adds a Godot 4.7 + Xvfb/Mesa same-seed render workflow only. The same workflow passed on the original PR #133 head with a real runner. Current-main verification is deferred until GitHub Actions minutes are available.
- **#129 — DEV-M visual identity:** merged at `9e3d626`. Dedicated Builder, Archer and Brute sprite sheets, reproducible generator output, role identity tests and Brute visual scaling. Godot 4.7 regression 54/54, Campaign Simulation QA and Role Sprite Visual QA passed on the PR head before merge.
- **#139 — worklist refresh:** merged at `5cc1b39`; records PR #138's render-workflow integration and the Android/full-wave runner blocker.
- **#137 — worklist refresh:** merged at `6e7609c`; superseded by this live snapshot.
- Earlier architecture foundations remain integrated: #109/#108/#107/#106/#105, #101/#102/#103/#100, #99/#97/#96/#94, #91 and #89. All preserve save schema v17.

### Active execution order

1. **PR #136 — Android ARMv7:** do not merge until GitHub Actions actually starts jobs. Required: Godot 4.7 import/parse, full regression, Android debug APK export, and APK ABI inspection proving `armeabi-v7a` only. Then install on the 32-bit Android target and test launch, touch, safe-area behavior, pause/resume, overlays and a sustained gameplay session. No APK or device pass is currently claimed.
2. **PR #135 — full-night diagnostic:** keep isolated until its Godot 4.7 workflow gets a real runner and produces a diagnostic artifact. The deterministic bot is diagnostic coverage, not human balance testing.
3. **Merged #138 — rendered Frontier QA:** execute the workflow on current main and review its images/log when runner allocation resumes. The original PR #133 implementation passed, but current-main verification has not run.
4. **Icon-first HUD countdown branch:** implementation is committed on `feat/icon-first-night-wave-awareness`. The queue includes a pending final boss and dawn cancels any unrevealed boss; the compact clock redraws only when its displayed second or day/night icon state changes. Static source review only; no Godot execution is claimed. When Actions minutes return, run Godot 4.7 import/parse, the campaign balance matrix, responsive-layout assertions and the full regression suite. PR #127 is closed as superseded; keep this replacement isolated until it passes validation.
5. Run extended human Classic and Frontier playthroughs; record pacing, recovery, difficulty spikes and confusing interactions before tuning values or adding facilities.

### CI and validation note

The repository now has active Godot 4.7 validation for the current performance branch. Historical PR #135/#136 validation notes still need a live-head check before those tasks are resumed. Existing successful runs on earlier PR heads remain historical evidence only and do not replace validation on current main.

### Validation and release boundaries

- Development CI targets **Godot 4.7 only**. Do not add Godot 4.3 jobs or Windows export jobs to feature CI.
- Campaign Simulation QA and the autonomous player bot are diagnostic coverage, not proof of campaign balance or player experience.
- Remaining acceptance work includes a successful full-wave runtime diagnostic, Android ARMv7 build plus physical-device testing, human playthroughs across Classic/Frontier acts, target-hardware profiling, rendered resolution/fullscreen review and audio listening.
- Do not claim a feature complete solely because headless tests pass. Record rendered/manual QA separately.

This snapshot records `main` at `ef9dd51281551ff98013505614eb99d0f1d61004`, with the icon-first HUD countdown work isolated on `feat/icon-first-night-wave-awareness`. GitHub Actions validation is deferred until the minute budget is available. Re-check PR heads, workflow runs and `main` before each merge or assignment; repository state can change after this commit.
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

**Status:** Priority 1 decomposition complete through PRs #75, #94, #96, #97 and #99. Keep the stable `SupplyNetwork` façade; do not split the stock-theft hook into a separate module merely to reduce line count.

**Priority:** High  
**Start:** After INT-0 and after PR #37 is reconciled  
**Primary owner files:**

- `scripts/systems/supply_network.gd`
- New focused modules under `scripts/systems/`
- Focused logistics regression tests

**Problem (historical):** The original 805-line façade has been reduced to approximately 458 lines. Connectivity, cost transactions, shipment ledger/dispatch and supply pressure are now owned by focused modules.

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
- Role behavior modules under `scripts/entities/villager_*_behavior.gd` and `scripts/entities/villager_archer_combat.gd`
- Focused role regression tests

**Problem (historical):** `villager.gd` was approximately 1,530 lines. Archer, Scout, Healer, Blacksmith and Builder role behaviors are now separate; the host still owns shared movement, pathing, workplace lifecycle, farming/gathering, guarding, expeditions, carrying and delivery. Current size is approximately 1,470 lines.

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

**Conflict warning:** Avoid parallel edits to `villager.gd`. Add one role component at a time, preserve host-owned movement/workplace/persistence state and validate the corresponding role test.

### DEV-G — HUD modularization

**Priority:** High  
**Primary owner files:**

- `scripts/ui/hud.gd`
- Components under `scripts/ui/` such as `hud_widgets.gd`, `construction_queue_panel.gd` and `outpost_panel.gd`
- Focused UI regression tests

**Problem (historical):** `hud.gd` was approximately 1,900 lines. Reusable widgets, construction queue and outpost/logistics panels are now separate; world map and event-decision panels were already separate. The remaining 1,031-line HUD is primarily the root layout/composition coordinator plus smaller panels.

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

**Conflict warning:** Avoid multiple simultaneous edits to `hud.gd`; extract a complete panel on a dedicated branch, preserve the public HUD callbacks, and validate click/resize behavior.

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

**Status:** Complete for Priority 1 through PR #74 `EnemyPatrolMovement`, #102 `EnemyRaidBehavior` and #108 `EnemyCombatLifecycle`.

**Priority:** Medium  
**Primary owner files:**

- `scripts/entities/enemy.gd`
- New modules under `scripts/behaviors/enemies/` or the existing `scripts/behaviors/`
- Focused enemy lifecycle regression tests

**Problem (historical):** `enemy.gd` was approximately 975 lines; it is now approximately 741 lines after patrol, raid and combat lifecycle extraction. The host retains identity, archetype state, navigation, animation and orchestration; archetype-specific policy remains in dedicated behavior modules.

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
