# Hold the Keep — Session Recovery

**Recovery date:** 2026-11-07  
**Repository:** `shimleabyte/hold-the-keep`  
**Engine target:** Godot 4.7 only  
**Recovery branch:** `recovery/session-resumption-2026-11-07`  
**Baseline branch / SHA:** `main` / `92f169606b5f73555df8052e2c7701f6f68492ec`  
**Save schema:** v17  
**Renderer:** GL Compatibility

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
- Latest main commit: merge PR #185, `feat(art): add restrained Frontier ground dressing and landmark motion`.
- Immediately preceding integration: PR #184, `feat(animation): integrate the 46-frame player animation system`, merge `e7a53d7279d5eeba5e3704ece7f2b7ea087ffead`.
- PR #182, the authored civilian role atlas package, is merged at `7dea98194e308ebb380115c873d395e64fffada0`.
- Branch inventory: **157** remote branches (100 on page 1, 57 on page 2).
- PR inventory: **185** total; **132 merged**, **50 closed unmerged**, **3 open**.
- Open PRs:
  - #181 `animation/player-motion-timing` — open, not mergeable; old player-animation proposal. The later 46-frame system is already integrated by #184. Keep under supersession audit; do not merge as-is.
  - #152 `feat/android-armv7-touch-controls-current-main` — Android touch controls; explicitly deferred.
  - #150 `docs/android-armv7-device-qa` — physical Android QA checklist; explicitly deferred.
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

The runtime code in `scripts/entities/frontier_decoration.gd` calls `set_process(_ambient_enabled)` from `setup_batch()`; `scripts/world/world_map.gd` calls `setup_batch()` before adding the node to the scene tree. The next change must make the processing state deterministic after scene-tree entry. Do not weaken the assertion or enable ambient animation on ordinary decoration.

## 3. Recovery matrix

Status values use the requested classifications: **COMPLETE AND VERIFIED**, **IMPLEMENTED BUT UNVERIFIED**, **IN PROGRESS**, **NOT STARTED**, **BLOCKED**, **SUPERSEDED**.

### Gameplay

| Workstream | Task | Checkpoint status | Actual status | Last known commit | Remaining work | Dependencies | Verification | Next action |
|---|---|---|---|---|---|---|---|---|
| Gameplay | Direct knight control, movement, attack, Dash, Cleave, Rally and harvesting | Implemented | COMPLETE AND VERIFIED | `92f1696` | No replacement of the direct-action layer; retain it while expanding strategy | Player/combat flow | `player_combat`, `combat_visual_feedback`, campaign simulation passed on exact HEAD | Preserve current player control contract |
| Gameplay | P0 melee aim lock and directional hit sectors | Pending in older P0 branch | COMPLETE AND VERIFIED | `92f1696` | No production re-merge needed; current implementation captures `_attack_direction` / `_cleave_direction` and regression checks turning during wind-up plus rear/flank misses | Player combat flow and attack profile | `player_combat` passed on exact HEAD; source and assertions verified | Treat old P0 implementation as superseded; retain current tests |
| Gameplay | One-time dusk warning and day rollover reset | Pending in older P0 branch | COMPLETE AND VERIFIED | `92f1696` | None identified in current behavior | GameClock / Events | Current main contains nine-second warning and reset; campaign balance job passed | Do not cherry-pick old clock code |
| Gameplay | Phase 11.2 faction doctrine investment order | Implemented | COMPLETE AND VERIFIED | Phase 11 commits; current `92f1696` | Strategic effects still need playtesting; the seven-building order itself is implemented | Faction doctrine data, rival ledger, construction | `army_command_and_rival_civilization` and campaign matrix passed | Keep as the foundation; do not rebuild |
| Gameplay | Phase 11.3 rival bounded workforce and staffed production | Implemented | COMPLETE AND VERIFIED | Phase 11.3 mainline integration | Workforce remains abstract rather than visible; see separate row below | Rival building state, food upkeep, recruitment | Rival civilization regression passed on exact HEAD | Preserve the current eight-citizen/two-worker-per-site constraints |
| Gameplay | Phase 11.4 finite rival stockpiles | Implemented | COMPLETE AND VERIFIED | Phase 11.4 mainline integration | No save migration; retain over-cap v17 balances | Rival workforce and Storage building | Rival civilization regression passed on exact HEAD | Preserve 240 base / 600 Storage capacities |
| Gameplay | Phase 11.5 doctrine-aware paid rival composition | Implemented | COMPLETE AND VERIFIED | Phase 11.5 mainline integration | Battlefield pacing needs human acceptance | Faction roster, ledger and spawn validity | Rival civilization and campaign tests passed | Preserve paid recruitment and deterministic composition tie-breaks |
| Gameplay | Phase 11.6 military research gates | Implemented | COMPLETE AND VERIFIED | Phase 11.6 mainline integration | Human review of research pacing and specialist impact | Research tier and paid recruitment | Rival civilization regression passed on exact HEAD | Preserve Tier II / Tier III gates |
| Gameplay | Rival visible labor, node depletion, travel, local depots and shipments | In progress in design; not present in rival simulation | NOT STARTED | `92f1696` | Rival production is still abstract; add visible labor only after resource reservation, pathing, local storage and save semantics are coherent | Rival workforce, supply graph, nav, resource nodes, persistence | Add focused lifecycle/economy tests, stress tests and rendered settlement capture | Design and implement the smallest rival labor/logistics vertical slice |
| Gameplay | Rival outposts, secondary settlements and two-sided territory | Documented gap | NOT STARTED | `92f1696` | No rival settlement network or independent territorial economy | Rival logistics and ownership model | Territory/supply regression, persistence, campaign simulation and rendered frontier capture | Build after rival local logistics is stable |
| Gameplay | Coordinated rival offensive planner, reinforcement routes, sieges and retreats | Documented gap | NOT STARTED | `92f1696` | Current periodic garrison recruitment and faction camp raids are not a civilization-level offensive planner | Rival territory, supply, scouting, army composition | Faction warfare stress, campaign simulation and playthrough observation | Connect doctrine, scouting, supply and military planning without free units |
| Gameplay | P0 rendered playability, ten-minute opening and middle-game acceptance | Worklist says required | BLOCKED | `92f1696` | No interactive desktop session is exposed in this execution environment; automated simulation is not a substitute for human play | Runnable desktop build and human input | Record actual play session, idle workers, decisions/minute, path stalls, combat outcomes, pacing and frame-time percentiles | Run on the target desktop; do not mark complete from CI |
| Gameplay | Save/load and legacy world-size compatibility | Schema v17 and migration tests recorded complete | IMPLEMENTED BUT UNVERIFIED | `92f1696` | Exact automated save pipeline passes; old-save continuation across Classic, Frontier and Expedition still needs manual acceptance | SaveSystem, validator, migration pipeline and all profile state | `save_validator`, `save_file_store_recovery`, `campaign_reload_hardening`, `legacy_world_dimensions` passed | Keep schema v17; perform desktop continuation with representative old saves |
| Gameplay | Performance backlog: FlowField/NavGrid, village assignment, specialist scans, wildlife selection | Several old branches retained | IN PROGRESS | `92f1696`; candidate branch tips listed below | Review each unique patch against current profiling data; some work is already in main and must not be duplicated | Current navigation/supply topology and performance probes | Main Frontier and Expedition diagnostics passed; construction spike diagnostic passed | Recover only measurable wins, one subsystem at a time |

### Animation

| Workstream | Task | Checkpoint status | Actual status | Last known commit | Remaining work | Dependencies | Verification | Next action |
|---|---|---|---|---|---|---|---|---|
| Animation | Player 46-frame atlas, three facing rows and dedicated action clips | PR #181 was reported active | IMPLEMENTED BUT UNVERIFIED | PR #184 merge `e7a53d7` | Human review of the captured contact sheet and looping preview at native gameplay zoom; locomotion still reuses a limited number of poses | Player SVG, SpriteAnim clip map, combat/ability event ownership | Godot 4.7 import, `animation_motion`, `player_attack_sprite_pose` and player playblast job passed on `92f1696` | Inspect the actual player playblast artifact; fix silhouette/foot/cape issues without changing damage timing |
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
| Art | Frontier environmental decoration, tree-root and rock dressing, landmark motion | Recent PR #185 | IMPLEMENTED BUT UNVERIFIED | PR #185 merge `92f1696` | Mainline Frontier test currently fails on processing-state assertion; inspect final rendered outputs after the regression is fixed | Frontier decoration batching and WorldMap draw ordering | Rendered World QA passed; Godot `frontier_world` failed | Fix processing state, rerun exact-head CI and inspect rendered capture |
| Art | Enemy/faction-specific silhouettes and visual identity | Remains open in art direction | NOT STARTED | `92f1696` | Replace generic faction presentation with distinct grounded material, armor, weapons and iconography | Faction roster/design contracts | Asset identity test plus in-world captures | Define faction-specific visual sheets before implementation |
| Art | Buildings, construction stages, damage states and biome-specific structure variants | Remains open | NOT STARTED | `92f1696` | Production buildings need readable silhouettes and live construction/damage states | Building gameplay function and tile footprint contract | Building visual identity tests and rendered world capture | Produce one building family at a time, preserving footprint/collision |
| Art | Resource nodes, wildlife, regional props and combat effects | Partial older assets and frontier dressing exist | IN PROGRESS | `92f1696` | Audit quality/coverage at native zoom; complete missing region-specific resource/wildlife and combat feedback | Harvesting lifecycle, collision/occupancy, faction/biome identity | Rendered world QA and role/combat tests | Audit actual asset inventory; avoid replacing working resource lifecycle |
| Art | HUD iconography, map symbols and multi-resolution full-world acceptance | Worklist identifies remaining polish | NOT STARTED | `92f1696` | Complete coherent icon set and inspect HUD/map at desktop aspect ratios | HUD layout and visual language | Responsive layout tests plus rendered screenshots at multiple sizes | Define a compact icon family and capture supported desktop sizes |

## 4. Branch and PR recovery dispositions

Comparisons were performed against baseline `92f1696`. The branch heads below are not merge candidates by name alone; their unique patches are old and must be revalidated against the current source.

| Candidate | Remote head | Ahead / behind main | Classification | Recovery decision |
|---|---|---:|---|---|
| `fix/p0-gameplay-fairness-current-main` | `4e2ecc4` | 6 / 233 | SUPERSEDED | Directional attack lock/arc and dusk warning are already implemented in current main; current `player_combat` verifies lock direction after turning. Do not merge old player/clock implementation. |
| `perf/priority-performance-pass` | `a8cb132` | 14 / 139 | IN PROGRESS | Changes span `enemy.gd`, specialist behaviors, FlowField/NavGrid, Village and WorldMap. Review per subsystem against current main; no wholesale cherry-pick. |
| `perf/p1-skip-road-pathfield-rebuilds` | `4b346f4` | 3 / 144 | IN PROGRESS | Reconcile its FlowField/NavGrid delta and test against the current road/supply invalidation rules. |
| `perf/p1-specialist-interceptor-scans` | `874d080` | 8 / 156 | IN PROGRESS | Review specialist scan changes against present siege/saboteur behaviors and faction warfare stress; retain only measured improvements. |
| `perf/p1-village-job-assignment-counters` | `976bcc3` | 3 / 143 | IN PROGRESS | Compare counters against current bounded village scheduling and use performance evidence before adoption. |
| `perf/p2-bounded-wildlife-selection` | `6ddeacd` | 3 / 144 | SUPERSEDED PENDING DIFF AUDIT | Current Frontier tests already verify deterministic bounded wildlife placement; check for unique performance improvement before closing out. |
| `work/worker-resource-awareness` | `c19b20f` | 5 / 138 | IN PROGRESS | Contains connected-depot stock accounting, local reachable iron selection and diagnostics. Main already has connected-depot delivery and reachable work areas, but equivalent miner demand selection has not yet been confirmed. Inspect current `_find_work`/resource policy before selectively reconstructing. |
| `work/dev-f-villager-role-architecture` | `bd7d519` | 1 / 263 | IN PROGRESS | The branch extracts nine role components but removes 466 lines from the old Villager host. It is too stale and invasive for a direct merge. Compare current role-owned behavior and extract only still-monolithic roles in small tested slices. |
| `feat/low-cost-profession-sprite-art` family | `72661f2`, `6323215`, `7faa718` | 20–29 ahead / 137–205 behind | SUPERSEDED | PR #182 now supplies ten individually authored role atlases and protects generator ownership. Do not restore these older sprite-sheet variants; inspect any non-art script delta separately only if a defect is identified. |
| `feat/phase-08.3-resource-cluster-dressing` | `9a897a1` | 8 / 220 | IN PROGRESS | Overlaps later #185 decoration/tree/rock work. Compare its unique artwork against current integrated assets; no wholesale merge. |
| `work/dev-e-save-validator-extraction` | `ecb06b3` | 6 / 308 | SUPERSEDED | Main already contains a later 975-line SaveValidator and a 283-line SaveSystem integration with dedicated CI tests; older 747-line branch validator is not a safe replacement. |
| `animation/player-motion-timing` / PR #181 | `e63c1ec` | 28 / 16 | SUPERSEDED PENDING UNIQUE-DIFF AUDIT | Current main has the later 46-frame atlas and expanded clips through #184. PR #181 is stale and unmergeable; inspect unique test/workflow/docs changes, then close only when no useful delta remains. |
| Android PR #150 / #152 | Existing open heads | N/A | BLOCKED / DEFERRED | Do not mix Android controls or physical-device QA into the desktop-first recovery. |

No ref deletion, force update or branch reset is authorized by this recovery. The branch list is a retention inventory, not a request to delete historical sources.

## 5. Immediate execution sequence

1. Fix the Frontier decoration processing-state defect without changing which assets animate.
2. Run the focused `frontier_world` test on Godot 4.7, then the complete Godot CI matrix and campaign/rendered workflows on the exact proposed head.
3. Inspect the uploaded player-animation playblast and current rendered Frontier/role QA outputs; record human visual status separately from automation.
4. Audit the current miner resource-selection path against `work/worker-resource-awareness`; selectively port only missing behavior and tests if current main lacks the equivalent.
5. Continue the rival visible workforce/logistics vertical slice, then territory/outposts and coordinated offensive planning.
6. Audit residual animation/art tasks and branch patches without merging stale branch snapshots.
7. Update `CONTEXT.md`, `worklist.md`, `ROADMAP_NEXT_LEVEL.md` and `docs/BRANCH_REGISTRY.md` after the verified implementation stages.

## 6. Execution log

### Recovery start — 2026-11-07

- Main baseline inspected: `92f169606b5f73555df8052e2c7701f6f68492ec`.
- Recovery branch created from that exact SHA: `recovery/session-resumption-2026-11-07`.
- No code modifications made before this matrix was written.
- Baseline tests: Godot CI 64/65; failing job `frontier_world` as described above. Campaign Simulation QA and Rendered World QA passed.
- Rendered QA artifacts and player animation playblast still require visual inspection.
- Current local working tree: unavailable in this environment; no cleanliness claim.
- **Next action:** apply the minimal scene-tree processing-state fix in `scripts/entities/frontier_decoration.gd`, then execute focused and full Godot 4.7 validation.
