# Hold the Keep — Session Recovery

**Recovery date:** 2026-11-07  
**Repository:** `shimleabyte/hold-the-keep`  
**Engine target:** Godot 4.7 only  
**Recovery PR:** [#186](https://github.com/shimleabyte/hold-the-keep/pull/186), merged 2026-11-07  
**Baseline branch / SHA:** `main` / `92f169606b5f73555df8052e2c7701f6f68492ec`  
**Latest verified production-code integration:** `198c31f5f0c7241158e8e56024e1bc69aacf8b17` (PR #186). Documentation-only commits were subsequently added to `main`; the latest pre-checkpoint docs tip was `6fbc63454ae288a5537ea206c575cf6ad2bcc8f9`.  
**Save schema:** v17  
**Renderer:** GL Compatibility  
**Active follow-up branch:** `feat/rival-physical-workforce-hauling` (initial implementation; verification pending)

## 1. Checkpoint discovery and authority

No dedicated `CHECKPOINT.md`, `SESSION_CHECKPOINT.md`, `EXECUTION_LOG.md` or equivalent checkpoint file exists on the inspected `main` tree. The latest recoverable state is distributed across these records:

| Record | Use in this recovery |
|---|---|
| `worklist.md` | Phase status, merged systems, outstanding work and acceptance requirements |
| `CONTEXT.md` | Current project contract, visual work and session handoff history |
| `docs/BRANCH_REGISTRY.md` | Prior branch/PR audit; its inventory counts and open-PR list are now stale |
| `docs/GAMEPLAY_AUDIT.md` | Gameplay P0/P1/P2 gaps, implemented rival phases and manual acceptance boundaries |
| `docs/RTS_AND_RIVAL_CIVILIZATIONS.md` | Rival economy, recruitment, research, territory and save contract |
| `docs/ANIMATION_DIRECTION.md` | Player animation atlas, clip timing, event ownership and QA contract |
| `docs/ART_DIRECTION.md` and `docs/ART_REFERENCE_BOARD.md` | Grim Medieval Folklore Fantasy direction and art-production constraints |
| `ROADMAP_NEXT_LEVEL.md` and `docs/plans/phase-08-plan.md` | Visual/gameplay sequencing and remaining production |
| Phase 11 plan documents | Rival doctrine, workforce, stockpile, recruitment and military research implementation record |
| Session artifacts `Pasted text(6).txt`–`Pasted text(10).txt` | Gameplay overhaul, branch recovery, art overhaul and animation directives from the prior sessions |

The latest session directives used were the gameplay overhaul directive (`Pasted text(6)`), branch recovery/integration directive (`Pasted text(9)`), art overhaul directive (`Pasted text(8)`) and animation overhaul directive (`Pasted text(10)`). The prior branch audit (`Pasted text(7)`) was used as historical evidence only.

**Authority rule:** checkpoint prose and branch names are leads, not proof. The remote files, commit graph, PR state and exact-head Actions results below are the verified baseline. Historical counts in the registry/worklist are not current facts.

## 2. Repository state at recovery

### Remote Git state

- `main` HEAD before recovery: `92f169606b5f73555df8052e2c7701f6f68492ec`.
- Production code integration on `main`: `198c31f5f0c7241158e8e56024e1bc69aacf8b17` (squash merge PR #186, `fix: disable inactive frontier decoration processing`). The docs-only status reconciliation reached `6fbc63454ae288a5537ea206c575cf6ad2bcc8f9` before this follow-up update.
- Latest main commit: merge PR #185, `feat(art): add restrained Frontier ground dressing and landmark motion`.
- Immediately preceding integration: PR #184, `feat(animation): integrate the 46-frame player animation system`, merge `e7a53d7279d5eeba5e3704ece7f2b7ea087ffead`.
- PR #182, the authored civilian role atlas package, is merged at `7dea98194e308ebb380115c873d395e64fffada0`.
- Branch inventory: **157** remote branches (100 on page 1, 57 on page 2). The temporary recovery head branch is no longer listed after PR merge; no explicit branch-delete action was issued.
- PR inventory after PR #181 was closed as superseded: **186** total; **133 merged**, **51 closed unmerged**, **2 open**.
- Open PRs:
  - #152 `feat/android-armv7-touch-controls-current-main` — Android touch controls; explicitly deferred.
  - #150 `docs/android-armv7-device-qa` — physical Android QA checklist; explicitly deferred.
- PR #181 was closed unmerged as superseded after source-level reconciliation; see the branch disposition below.
- No branch was reset, force-pushed or deleted during recovery.
- The remote GitHub API is the only repository workspace available in this session. No local checkout or local working tree is mounted, so uncommitted local modifications cannot be inspected and the local working tree cannot be certified clean.

### Exact-head CI and rendered workflows

At baseline `92f1696`:

| Workflow | Run | Result | What it establishes |
|---|---:|---|---|
| Godot CI | [42381270247](https://github.com/shimleabyte/hold-the-keep/actions/runs/42381270247) | **FAILURE — 64/65 jobs passed** | Import/parse, animation playblast, diagnostics, save, combat, campaign and faction tests passed; only `frontier_world` failed |
| Rendered World QA | 42381270275 | SUCCESS | Automated rendered world capture completed |
| Campaign Simulation QA | 42381270382 | SUCCESS | Automated campaign simulation completed |

The failed Godot job is `Godot 4.7 · frontier_world` (job `128429327158`). Its log records this failed assertion at `tests/frontier_world.gd:656`:

- Expected: non-landmark decoration batch not processing.
- Actual: `batch.is_processing() == true`, while `_ambient_enabled == false`.
- The failing batch entries are ordinary fern/dead-pine/standing-stone dressing, not the Fenlands reed or Hearthland shrine landmarks.
- The test process then timed out at 180 seconds because the assertion stopped the asynchronous test path before normal teardown.
- All other 64 jobs passed, including `animation_motion`, `player_combat`, `resource_save_state`, `save_validator`, `save_file_store_recovery`, `frontier_expedition`, `campaign_combat_simulation`, `faction_raids` and `faction_warfare_stress`.

The runtime code in `scripts/entities/frontier_decoration.gd` calls `set_process(_ambient_enabled)` from `setup_batch()`; `scripts/world/world_map.gd` calls `setup_batch()` before adding the node to the scene tree. PR #186 fixes the scene-entry state in `_ready()` by reapplying the stored ambient flag after tree entry. The original assertion remains unchanged; ordinary decoration is still expected to stay idle.

## 3. Recovery matrix

Status values use the requested classifications: **COMPLETE AND VERIFIED**, **IMPLEMENTED BUT UNVERIFIED**, **IN PROGRESS**, **NOT STARTED**, **BLOCKED**, **SUPERSEDED**.

### Gameplay

| Workstream | Task | Checkpoint status | Actual status | Last known commit | Remaining work | Dependencies | Verification | Next action |
|---|---|---|---|---|---|---|---|---|
| Gameplay | Direct knight control, movement, attack, Dash, Cleave, Rally and harvesting | Implemented | COMPLETE AND VERIFIED | `92f1696` | No replacement of the direct-action layer; retain it while expanding strategy | Player/combat flow | `player_combat`, `combat_visual_feedback`, campaign simulation passed on exact HEAD | Preserve current player control contract |
| Gameplay | P0 melee aim lock and directional hit sectors | Pending in older P0 branch | COMPLETE AND VERIFIED | `92f1696` | No production re-merge needed; current implementation captures `_attack_direction` / `_cleave_direction` and regression checks turning during wind-up plus rear/flank misses | Player combat flow and attack profile | `player_combat` passed on exact HEAD; source and assertions verified | Treat old P0 implementation as superseded; retain current tests |
| Gameplay | One-time dusk warning and day rollover reset | Pending in older P0 branch | COMPLETE AND VERIFIED | `92f1696` | None identified in current behavior | GameClock / Events | Current main contains nine-second warning and reset; campaign balance job passed | Do not cherry-pick old clock code |
| Gameplay | Phase 11.2 faction doctrine investment order | Implemented | COMPLETE AND VERIFIED | Phase 11 commits; current `92f1696` | Strategic effects still need playtesting; the seven-building order itself is implemented | Faction doctrine data, rival ledger, construction | `army_command_and_rival_civilization` and campaign matrix passed | Keep as the foundation; do not rebuild |
| Gameplay | Phase 11.3 rival bounded workforce and staffed production | Implemented on main | COMPLETE AND VERIFIED | Phase 11.3 mainline integration | Finite eight-citizen pool, doctrine priorities, construction reservation, upkeep and stockpile caps remain the foundation | Rival building state, food upkeep, recruitment | Existing rival civilization and persistence regressions passed on main | Preserve the eight-citizen/two-worker-per-site constraints |
| Gameplay | Phase 11.4 finite rival stockpiles | Implemented | COMPLETE AND VERIFIED | Phase 11.4 mainline integration | No save migration; retain over-cap v17 balances | Rival workforce and Storage building | Rival civilization regression passed on exact HEAD | Preserve 240 base / 600 Storage capacities |
| Gameplay | Phase 11.5 doctrine-aware paid rival composition | Implemented | COMPLETE AND VERIFIED | Phase 11.5 mainline integration | Battlefield pacing needs human acceptance | Faction roster, ledger and spawn validity | Rival civilization and campaign tests passed | Preserve paid recruitment and deterministic composition tie-breaks |
| Gameplay | Phase 11.6 military research gates | Implemented | COMPLETE AND VERIFIED | Phase 11.6 mainline integration | Human review of research pacing and specialist impact | Research tier and paid recruitment | Rival civilization regression passed on exact HEAD | Preserve Tier II / Tier III gates |
| Gameplay | Visible rival labor, resource-node harvesting and stronghold hauling | Implemented on follow-up branch | IMPLEMENTED BUT UNVERIFIED | `feat/rival-physical-workforce-hauling` | Worker entities now reserve reachable nodes, harvest wood/stone/iron, farm food, haul to their owner keep and reconcile cargo into v17 saves; local storage/road shipments remain absent | Rival workforce, resource nodes, NavGrid, territory, storage capacity, save export | New `rival_physical_workforce` test plus expanded `army_command_and_rival_civilization`; exact-head Godot CI pending | Run focused tests and regressions; inspect rendered Frontier/Classic behavior before merging |
| Gameplay | Rival outposts, secondary settlements and two-sided territory | Documented gap | NOT STARTED | `92f1696` | No rival settlement network or independent territorial economy | Physical workforce, local storage, supply graph and ownership model | Territory/supply regression, persistence, campaign simulation and rendered Frontier capture | Build only after local depot/road logistics are verified |
| Gameplay | Coordinated rival offensive planner, reinforcement routes, sieges and retreats | Documented gap | NOT STARTED | `92f1696` | Current periodic garrison recruitment and faction camp raids are not a civilization-level offensive planner | Rival territory, supply, scouting, army composition | Faction warfare stress, campaign simulation and playthrough observation | Connect doctrine, scouting, supply and military planning without free units |
| Gameplay | P0 rendered playability, ten-minute opening and middle-game acceptance | Worklist says required | BLOCKED | `92f1696` | No interactive desktop session is exposed in this execution environment; automated simulation is not a substitute for human play | Runnable desktop build and human input | Record actual play session, idle workers, decisions/minute, path stalls, combat outcomes, pacing and frame-time percentiles | Run on the target desktop; do not mark complete from CI |
| Gameplay | Save/load and legacy world-size compatibility | Schema v17 and migration tests recorded complete | IMPLEMENTED BUT UNVERIFIED | `92f1696` | Exact automated save pipeline passes; old-save continuation across Classic, Frontier and Expedition still needs manual acceptance | SaveSystem, validator, migration pipeline and all profile state | `save_validator`, `save_file_store_recovery`, `campaign_reload_hardening`, `legacy_world_dimensions` passed | Keep schema v17; perform desktop continuation with representative old saves |
| Gameplay | Performance backlog: FlowField/NavGrid, village assignment, specialist scans, wildlife selection | Several old branches retained | IN PROGRESS | `92f1696`; candidate branch tips listed below | Review each unique patch against current profiling data; some work is already in main and must not be duplicated | Current navigation/supply topology and performance probes | Main Frontier and Expedition diagnostics passed; construction spike diagnostic passed | Recover only measurable wins, one subsystem at a time |

### Animation

| Workstream | Task | Checkpoint status | Actual status | Last known commit | Remaining work | Dependencies | Verification | Next action |
|---|---|---|---|---|---|---|---|---|
| Animation | Player 46-frame atlas, three facing rows and dedicated action clips | PR #181 was reported active | IMPLEMENTED BUT UNVERIFIED | PR #184 merge `e7a53d7` | Sprite-only preview was inspected; action poses move modestly and walk/run reuse few poses. No live gameplay zoom/interaction review yet. | Player SVG, SpriteAnim clip map, combat/ability event ownership | Godot 4.7 import, `animation_motion`, `player_attack_sprite_pose` and 37-frame playblast passed on `92f1696` | Improve authored foot, cape and weapon follow-through; capture an in-game scene rather than another sprite-only sheet |
| Animation | Attack, Cleave, harvest, Dash, Rally and hurt timing | Partly open in PR #181 | COMPLETE AND VERIFIED (automated) | PR #184 merge `e7a53d7` | Human readability review remains | Existing gameplay event timers and player clip state | `animation_motion`, `player_combat`, `combat_visual_feedback` passed | Preserve gameplay-owned damage and cooldowns |
| Animation | Full player idle/walk/run cycles and layered cape/weapon motion | Known outstanding item | IN PROGRESS | `e7a53d7` | Walk/run reuse limited poses; cape/weapon overlap and foot contact need authored refinement | Player atlas and SpriteAnim | Automated pose/playblast capture exists; rendered acceptance has not been signed off | Improve actual silhouette/contact poses, then inspect the new playblast |
| Animation | Ten civilian role atlases and profession identities | PR #182 open in older registry | COMPLETE AND VERIFIED (asset contract and automated capture) | PR #182 merge `7dea981` | Verify each work cycle is meaningfully distinct in actual gameplay; role atlas coverage alone is not proof of profession animation acceptance | Villager role mapping, SpriteAnim and job state | Role Sprite Visual QA, role identity and animation motion jobs passed before #185; current Godot matrix passed all related tests | Inspect all job loops in game; align pick/axe/hammer/heal/survey frames to actual work states |
| Animation | Enemy, specialist and rival military animation families | Documented future production | NOT STARTED | `92f1696` | Directional idle/move/attack/hurt/death sets and faction-specific motion remain open | Faction identity and combat role design | Add clip identity tests and real-gameplay playblasts per faction/role | Design enemy/faction animation contracts before asset generation |

### Art

| Workstream | Task | Checkpoint status | Actual status | Last known commit | Remaining work | Dependencies | Verification | Next action |
|---|---|---|---|---|---|---|---|---|
| Art | Grim Medieval Folklore Fantasy art direction and reference board | Phase 08.8 locked | COMPLETE AND VERIFIED (documentation) | PR #179 merge `27740a7` | Enforce the existing direction; do not restart or substitute generic fantasy art | Art direction and reference board | Documents present on main | Use the current art bible as production contract |
| Art | Player visual identity | Player redesign reported integrated | IMPLEMENTED BUT UNVERIFIED | `e7a53d7` | Human native-zoom inspection of player atlas/playblast remains | Player atlas and animation pipeline | 46-frame atlas imports; player playblast succeeded | Review playblast and adjust only actual visual defects |
| Art | Ten authored civilian profession identities | Phase 08.9 reported in progress | COMPLETE AND VERIFIED (asset contract and automated visual capture) | PR #182 merge `7dea981` | Human review of visual hierarchy at game zoom and role-readability in crowded settlements | Role mapping and art bible | Reproducibility check, role identity test and in-game visual QA succeeded on PR head | Keep the authored atlases; do not restore generic generated sprites |
| Art | Frontier environmental decoration, tree-root and rock dressing, landmark motion | Recent PR #185 | IMPLEMENTED BUT UNVERIFIED | PR #185 `92f1696`; fix #186 `198c31f` | Rendered captures were inspected and are deterministic, but the screenshots do not prove landmark motion during play; inspect ambient motion in a live Frontier scene | Frontier decoration batching and WorldMap draw ordering | Godot CI 65/65, Campaign Simulation QA and Rendered World QA passed on #186 head; seed-1337 first/repeat screenshots were visually identical | Capture a live landmark animation preview and approve biome dressing at gameplay zoom |
| Art | Enemy/faction-specific silhouettes and visual identity | Remains open in art direction | NOT STARTED | `92f1696` | Replace generic faction presentation with distinct grounded material, armor, weapons and iconography | Faction roster/design contracts | Asset identity test plus in-world captures | Define faction-specific visual sheets before implementation |
| Art | Buildings, construction stages, damage states and biome-specific structure variants | Remains open | NOT STARTED | `92f1696` | Production buildings need readable silhouettes and live construction/damage states | Building gameplay function and tile footprint contract | Building visual identity tests and rendered world capture | Produce one building family at a time, preserving footprint/collision |
| Art | Resource nodes, wildlife, regional props and combat effects | Partial older assets and Frontier dressing exist | IN PROGRESS | `92f1696` plus later resource lifecycle commits | Complete missing biome wildlife/props and combat feedback; native-zoom approval remains open | Harvesting lifecycle, collision/occupancy, faction/biome identity | `resource_save_state` verifies depleted-stump clearing, collision/occupancy release and save recovery; Rendered World QA passes for Frontier composition | Continue only with missing biome assets/effects; do not re-port Phase 08.3 tree/rock dressing |
| Art | HUD iconography, map symbols and multi-resolution full-world acceptance | Worklist identifies remaining polish | NOT STARTED | `92f1696` | Complete coherent icon set and inspect HUD/map at desktop aspect ratios | HUD layout and visual language | Responsive layout tests plus rendered screenshots at multiple sizes | Define a compact icon family and capture supported desktop sizes |

## 4. Branch and PR recovery dispositions

Comparisons were performed against baseline `92f1696`. The branch heads below are not merge candidates by name alone; their unique patches are old and must be revalidated against the current source.

| Candidate | Remote head | Ahead / behind main | Classification | Recovery decision |
|---|---|---:|---|---|
| `fix/p0-gameplay-fairness-current-main` | `4e2ecc4` | 6 / 233 | SUPERSEDED | Directional attack lock/arc and dusk warning are already implemented in current main; current `player_combat` verifies lock direction after turning. Do not merge old player/clock implementation. |
| `perf/priority-performance-pass` | `a8cb132` | 14 / 145 | SUPERSEDED | Its component changes are now represented by later mainline implementations: time-sliced FlowField, road-only supply invalidation, coalesced Village scheduling, bounded wildlife selection and 120 ms specialist scans. `Enemy` target-cache validation also has stricter player/defender identity checks in main. No wholesale cherry-pick. |
| `perf/p1-skip-road-pathfield-rebuilds` | `4b346f4` | 3 / 150 | SUPERSEDED | Current main has time-sliced FlowField work and regression assertions that road placement/removal invalidates logistics but not navigation/FlowField. The old branch adds no missing required behavior. |
| `perf/p1-specialist-interceptor-scans` | `874d080` | 8 / 162 | SUPERSEDED | Current Saboteur/Siege controllers already throttle defender/interceptor scans to 120 ms and cache the nearest candidate; `faction_warfare_stress` verifies the throttle. The branch is an older equivalent. |
| `perf/p1-village-job-assignment-counters` | `976bcc3` | 3 / 149 | SUPERSEDED | Current `Village` coalesces dirty assignment requests, waits for the settle window, counts occupations in one population pass and updates local counters during assignment. The old branch predates this implementation. |
| `perf/p2-bounded-wildlife-selection` | `6ddeacd` | 3 / 150 | SUPERSEDED | Current `WorldMap` already uses a bounded top-K heap selector and registers accepted wildlife into occupancy; `frontier_world` compares its output with a full-sort reference and verifies deterministic seeds. The old branch lacks later occupancy integration. |
| `work/worker-resource-awareness` | `c19b20f` | 5 / 138 | SUPERSEDED | Current `scripts/entities/villager_resource_behavior.gd` implements connected-depot stock counting and local, unclaimed iron selection; `tests/frontier_worker_ai.gd` verifies remote ore, local ore, reserved ore, connected storage and sabotage. Do not re-port duplicate behavior. |
| `work/dev-f-villager-role-architecture` | `bd7d519` | 1 / 263 | IN PROGRESS | The branch extracts nine role components but removes 466 lines from the old Villager host. It is too stale and invasive for a direct merge. Compare current role-owned behavior and extract only still-monolithic roles in small tested slices. |
| `feat/low-cost-profession-sprite-art` family | `72661f2`, `6323215`, `7faa718` | 20–29 ahead / 137–205 behind | SUPERSEDED | PR #182 now supplies ten individually authored role atlases and protects generator ownership. Do not restore these older sprite-sheet variants; inspect any non-art script delta separately only if a defect is identified. |
| `feat/phase-08.3-resource-cluster-dressing` | `9a897a1` | 8 / 231 | SUPERSEDED | Its regional root/rock detailing is present in current `resource_tree.gd` and `rock.gd`; #185 supersedes its per-prop decoration with row/z-layer batching. Main additionally preserves the complete `cleared` residue state, collision removal, occupancy release and save/restore lifecycle. No unique required asset or code remains. |
| `work/dev-e-save-validator-extraction` | `ecb06b3` | 6 / 308 | SUPERSEDED | Main already contains a later 975-line SaveValidator and a 283-line SaveSystem integration with dedicated CI tests; older 747-line branch validator is not a safe replacement. |
| `animation/player-motion-timing` / PR #181 | `e63c1ec` | 28 / 16 | SUPERSEDED / CLOSED UNMERGED | Source-level comparison found the player SVG, Player integration, animation direction doc, CI workflow and major pose tests byte-identical to main. The remaining Hurt test expected frame 20 and busy-state locking; main intentionally tests Hurt from frame 42 without locking the action state. PR #181 was closed 2026-11-07; historical branch retained. |
| Android PR #150 / #152 | Existing open heads | N/A | BLOCKED / DEFERRED | Do not mix Android controls or physical-device QA into the desktop-first recovery. |

No ref deletion, force update or branch reset is authorized by this recovery. The branch list is a retention inventory, not a request to delete historical sources.

## 5. Immediate execution sequence

1. Perform an interactive desktop opening/middle-game playtest; this remains the highest-priority acceptance gap and cannot be replaced by automated simulation.
2. Verify the physical rival worker/harvesting/stronghold-hauling slice on the follow-up branch; then add local storage and road-connected shipments before outposts or secondary settlements.
3. PR #181 residual-diff reconciliation is complete; it was closed unmerged as superseded. Retain the historical branch for reference.
4. Inspect civilian profession work loops and enemy/faction animation families in actual gameplay; extend animation architecture without moving combat/work timing out of gameplay systems.
5. Produce faction silhouettes, buildings/construction/damage states, biome resources/wildlife/props, combat effects and HUD/map icons in the existing Grim Medieval Folklore Fantasy direction.
6. Profile old performance branches against current diagnostic baselines; cherry-pick only changes with a demonstrated improvement.
7. Keep v17 save compatibility and legacy world dimensions; use Godot 4.7 exact-head tests before each integration.

## 6. Execution log

### Recovery start — 2026-11-07

- Main baseline inspected: `92f169606b5f73555df8052e2c7701f6f68492ec`.
- Recovery branch created from that exact SHA: `recovery/session-resumption-2026-11-07`.
- No code modifications made before this matrix was written.
- Baseline tests: Godot CI 64/65; failing job `frontier_world` as described above. Campaign Simulation QA and Rendered World QA passed.
- Rendered QA artifacts and player animation playblast still require visual inspection.
- Current local working tree: unavailable in this environment; no cleanliness claim.
- **Next action:** apply the minimal scene-tree processing-state fix in `scripts/entities/frontier_decoration.gd`, then execute focused and full Godot 4.7 validation.


### Recovery execution — 2026-11-07

- Recovery matrix was created before implementation; it was merged with PR #186.
- Recovery PR #186 code commit: `40bc8a29e86c3cd10e2adc6c4b8fd721794b71e9`; squash merge to `main`: `198c31f5f0c7241158e8e56024e1bc69aacf8b17`.
- Changed file: `scripts/entities/frontier_decoration.gd`; `_ready()` reapplies `set_process(_ambient_enabled)` after scene entry. The assertion in `tests/frontier_world.gd` was not weakened or changed.
- Exact PR-head Godot 4.7 CI: [run #42387251192](https://github.com/shimleabyte/hold-the-keep/actions/runs/42387251192), **65/65 jobs passed**, including `Godot 4.7 · frontier_world`.
- Exact PR-head Campaign Simulation QA: [run #42387251211](https://github.com/shimleabyte/hold-the-keep/actions/runs/42387251211), success. Rendered World QA: [run #42387251238](https://github.com/shimleabyte/hold-the-keep/actions/runs/42387251238), success.
- Main push after merge: Godot CI [run #42387559533](https://github.com/shimleabyte/hold-the-keep/actions/runs/42387559533) passed; Campaign Simulation QA [run #42387559467](https://github.com/shimleabyte/hold-the-keep/actions/runs/42387559467) and Rendered World QA [run #42387559524](https://github.com/shimleabyte/hold-the-keep/actions/runs/42387559524) passed. Later main docs-tip Godot CI [run #42388208398](https://github.com/shimleabyte/hold-the-keep/actions/runs/42388208398) also passed **65/65**.
- Inspected the 37-frame player sprite playblast and 1024×1024 Frontier seed-1337 first/repeat captures. The two map screenshots were pixel-identical. Player clips render, but the sprite-only preview shows modest silhouette changes and does not establish live gameplay acceptance. Landmark animation still needs a live scene preview.
- Miner resource-awareness branch `c19b20f` is superseded by `scripts/entities/villager_resource_behavior.gd`; current `tests/frontier_worker_ai.gd` covers inaccessible ore, local ore, reserved ore, connected stockpiles and sabotage.
- Phase 08.3 resource-cluster branch `9a897a1` is superseded by current batched Frontier decoration plus the newer regional root/rock drawing methods and resource residue lifecycle. `tests/resource_save_state.gd` verifies a cleared stump remains invisible, non-blocking, unoccupied and buildable after backup recovery.
- PR #181 was closed unmerged as superseded after its residual source diff was reconciled against #184; the historical branch remains. Android PRs #150/#152 remain the only open PRs and are deferred. The temporary recovery head is no longer listed after merge; no explicit branch-delete command was issued.
- No local checkout, local working tree, interactive desktop session or target hardware was available. Do not claim human gameplay or target-PC performance acceptance.
- Focused source audit of the old P1/P2 performance branches found their behavior already superseded in current main (details in the branch matrix above). The next feature dependency remains rival visible workforce/logistics; first define resource reservations, pathing, local storage, node depletion and save semantics as one testable vertical slice. Human desktop gameplay acceptance remains blocked by the missing interactive desktop runtime.


## Follow-up execution — rival physical workforce (2026-11-08)

**Branch:** `feat/rival-physical-workforce-hauling`  
**Baseline main:** `14f045198bcbd6d50b3b9909bce30a1f1f2c36d1`  
**Implementation status:** implemented, automated verification pending  
**Save schema:** v17 unchanged

The follow-up adds `scripts/entities/enemy_economic_worker.gd` and integrates it with `EnemyCivilization`. Each completed Lumber Camp, Farm, Quarry or Forge receives visible worker entities according to the existing bounded labor allocation. Lumber Camp workers reserve and harvest real wood nodes; Quarry workers harvest real stone nodes; Forge workers harvest iron after the rival reaches Military Tier II; Farm workers work at the farm and deliver food. Workers path with the existing NavGrid, stay inside their stronghold's local region/claim, avoid player and contested territory, and haul cargo to the owning stronghold ledger. They are not in player civilian or military groups and cannot be selected by army commands.

Already-harvested cargo is transferred into the existing civilization resource dictionary during export and cleared from the live workers, preventing save/load cargo loss or duplicate delivery. The save schema and validator contract remain v17. This is a first physical-workforce slice, not a complete logistics network: local depots, road-connected shipments, rival outposts, secondary settlements and offensive planning remain unimplemented.

New tests: `tests/rival_physical_workforce.gd`; expanded `tests/army_command_and_rival_civilization.gd`; added to the Godot CI matrix and `tools/run_tests.sh`. No exact-head CI result or rendered acceptance is claimed until the branch run completes. Manual desktop playtesting remains unavailable in this execution environment.

**Next:** run the new focused test, rival civilization/persistence tests, then the full Godot 4.7 matrix; fix actual failures, inspect rendered captures and only then integrate.



### Follow-up execution checkpoint — 2026-11-08

- Active branch: `feat/rival-physical-workforce-hauling`.
- Current HEAD: `48af993e544b5cbe55ab33dd2ee39127fbcd6d96`.
- Base branch: `main` at `14f045198bcbd6d50b3b9909bce30a1f1f2c36d1`.
- PR #187 remains open against `main`; it has not been merged.
- Implementation remains a first-slice physical rival workforce: visible workers for completed Lumber Camp/Farm/Quarry/Forge workplaces; node reservation, harvesting and hauling; v17-compatible cargo reconciliation at export.
- Runtime ownership corrections: workers are ticked only by their owning `EnemyCivilization.advance(delta)`; temporary civilization instances used by doctrine tests cannot spawn live workers; destroyed workplaces recall their own workers; saved cargo setup and courier return state have explicit support.
- Test ownership was aligned to runtime ownership: tests no longer call worker ticks independently. The long campaign regression yields physics frames so NavGrid can consume building occupancy changes between strategic seconds.
- Godot 4.7 exact-head import/parse passed on `48af993e544b5cbe55ab33dd2ee39127fbcd6d96` in run [#42424606533](https://github.com/shimleabyte/hold-the-keep/actions/runs/42424606533).
- The focused `rival_physical_workforce` test passed on the immediately preceding test head `03a0460d29bded09ef096d3349e3bbcf808b0adc`; `archery_range` also passed on that head. Campaign Simulation QA passed on that head.
- The integrated `army_command_and_rival_civilization` test remains pending on the current head. A previous run exposed that rival production was stalling because the test called workers outside the live stronghold update; the simulation now owns worker ticking. The next run adds candidate-scan diagnostics to distinguish region/claim filtering, territory ownership, path reachability and resource availability.
- An intermediate diagnostic compile error was caught by exact-head CI (`WorldConfig` was referenced directly in a `SceneTree` test); it is corrected to read `WorldMap.tile_size`. Do not mistake that test-only diagnostic error for a runtime worker compile failure.
- Save schema remains v17. No change to the validator contract or save version.
- CI is not green yet. Do not merge PR #187 until the exact current head passes the integrated rival campaign, focused workforce, persistence and full Godot 4.7 matrix. Rendered/desktop playtesting has not been performed in this execution environment.
- **Next action:** inspect the exact-head result of `army_command_and_rival_civilization`; use its `RIVAL_TARGET_SCAN` output to fix the first rejected stage, rerun focused tests, then the full matrix.
