# Repository Cleanup Checkpoint

**Checkpoint date:** 2026-11-25  
**Default branch:** `main`  
**Audit comparison main SHA:** `6025fabec7be8551e8a689cc0c4b2399f6049b59` (subsequent main commits recorded in the 2026-11-25 append are documentation-only)  
**Previous main commit date:** 2026-11-23 01:21:46 UTC  
**Engine target:** Godot 4.7 only  
**Release priority:** Desktop first; Android remains deferred.

This document supersedes older branch counts and branch-state snapshots in `worklist.md`. Historical worklist sections remain useful as context but must not be treated as current repository state.

## Audit inventory

The 2026-11-19 remote branch comparison found 170 branches including `main`:

| Classification against main | Count | Meaning |
|---|---:|---|
| Behind, no unique commits | 43 | Commit tips are already contained in main; deletion candidates after reference checks |
| Ahead only | 4 | Unique work based on current main; preserve for review |
| Diverged | 122 | Unique commits on an older base; require content-level review |
| Main | 1 | Current baseline |

The 43 behind-only branch names and the 122 diverged branch names are recorded in the audit conversation. Do not infer that all diverged branches are valuable; do not delete them without comparing their unique commits, open PRs, and equivalent work on other branches.

Two exact duplicate-tip pairs were identified:
- `feat/phase-09.3-late-act-reload-hardening` and `feat/phase-09.3-reload-acceptance`
- `work/dev-h-frontier-rendered-repeatability` and `work/dev-h-frontier-rendered-repeatability-final`

Duplicate tips are candidates for consolidation, not automatic deletion, until open PR and branch references are checked.

## Preserve and integrate

Four branches are ahead-only relative to main:
- `feat/battlefield-combat-readability` — 27 commits; PR #212
- `feat/civilian-work-action-pass` — 5 commits; PR #210
- `feat/deterministic-directed-fx` — 43 commits; PR #213
- `perf/acer-a0756-live-acceptance-probe` — 3 commits; PR #214

Six open PRs were verified:
- [#212 Battlefield combat readability](https://github.com/shimleabyte/hold-the-keep/pull/212) — review/integrate first, subject to exact-head Godot 4.7 checks.
- [#213 Deterministic directional FX](https://github.com/shimleabyte/hold-the-keep/pull/213) — reconcile after #212 because the production files overlap.
- [#210 Civilian work-action animations](https://github.com/shimleabyte/hold-the-keep/pull/210) — reconcile shared villager logic after combat/animation overlap is understood.
- [#214 Low-end hardware acceptance probe](https://github.com/shimleabyte/hold-the-keep/pull/214) — keep draft until actual Acer Aspire One A0756 measurements are attached; CI is not hardware acceptance.
- [#152 Android ARMv7 controls](https://github.com/shimleabyte/hold-the-keep/pull/152) — park; Android is a later milestone.
- [#150 Android device QA checklist](https://github.com/shimleabyte/hold-the-keep/pull/150) — park with #152.

Do not merge #212, #213, or #210 blindly. Confirm changed-file overlap, current mergeability, exact-head Godot 4.7 CI, and any rendered visual tests before each merge. Keep Android work out of the desktop cleanup path.

## Ordered cleanup plan

### A. Remove fully integrated branches
Delete only the 43 branches proven to have no unique commits, after confirming no open PR head, active automation, or other live reference depends on them. Do not delete the default branch or any branch with unique commits.

**Blocked:** the currently connected GitHub actions expose branch listing and ref updates but no branch-delete operation. Do not emulate deletion with a forced ref update. Retry only when a genuine branch-delete capability is available.

### B. Consolidate diverged branches
For all 122 diverged branches:
1. Compare unique commits and changed-file sets against main.
2. Group branches by identical tip, equivalent patch, feature, or superseded implementation.
3. Map each group to open/closed PRs and existing mainline implementation.
4. Select one canonical implementation per surviving feature.
5. Cherry-pick or rebase only after exact patch review and Godot 4.7 validation.
6. Mark the rest as superseded only when the replacement is proven equivalent.

Do not mass-merge or mass-delete.

### C. Resolve open PRs
Use the integration order above. Resolve conflicts and validate one production concern at a time. Keep #214 pending real hardware measurements and #150/#152 deferred.

### D. Establish a clean baseline
- Keep `main` as the only integration target.
- Require pull requests and successful Godot 4.7 CI before merge.
- Enable branch protection or a ruleset for `main`; at minimum require PR review and the Godot CI check, disallow force pushes and deletion.
- Keep one authoritative worklist and update it only with verified state.
- Record a clean checkpoint SHA after the branch/PR backlog is resolved.

**Protection status at audit:** `main` was unprotected and no repository rulesets were returned. The connected GitHub interface is read-only for protection/ruleset endpoints, so enabling protection remains pending an authorized GitHub settings action.

## Verification baseline

The latest mainline Actions runs previously checked for this checkpoint showed Godot CI, Campaign Simulation QA, and Building Visual QA successful on main SHA `d6a54036f7d7587c6e4cbd7188a620a6f9bc9d19`. Recheck current runs before relying on this as a release gate. A passing CI run is not a substitute for desktop gameplay acceptance.

## Exit criteria

A-D are complete only when:
- The 43 behind-only branches are deleted or explicitly documented as retained with a concrete reason.
- Every diverged branch has a recorded disposition: integrate, retain, superseded, or delete.
- Every open PR has a clear merged/closed/parked disposition with evidence.
- `main` has protection and required checks enabled.
- The new checkpoint SHA is recorded and the worklist no longer presents stale branch counts as current.

Only then move to the next product stage: desktop campaign acceptance, rival civilization/logistics validation, and performance profiling.


## Behind-only branch deletion candidates

The following 43 branch tips were confirmed contained in the audited main SHA. Delete only after checking live PR/workflow references and only when branch-delete capability is available:

```text
art/faction-equipment-silhouette-pass
combat/player-skills-enemy-ai
docs/update-phase-11-integration-status
feat/blacksmith-forge
feat/character-animation-pass
feat/frontier-world-generation-mainline
feat/healer-infirmary
feat/hunter-hunting-lodge
feat/multi-stronghold-campaign
feat/phase-05-resource-worksites
feat/phase-06-factions-territorial-ai-rebased
feat/phase-06-shieldbearer-brace
feat/phase-06.4-faction-raids
feat/phase-06.5-faction-warfare-stress
feat/phase-07-conquest-objectives-mainline
feat/phase-09-balance-performance-release-mainline
feat/phase-10-adaptive-viewport-mainline
feat/regional-control-roads-mainline
feat/responsive-resolution-visual-pass
feat/rival-local-depots-road-delivery
feat/scout-specialist
feat/strategic-map-stage-hud
feat/workplaces-and-specialist-jobs
fix/ci-regression-test-timeouts
fix/hud-discovered-type
fix/rival-worker-cargo-conservation
integrate/data-db-validation-mainline
overhaul/territory-expansion
qa/desktop-export-acceptance
qa/headed-mode-source-export
work/dev-b-faction-ai-components
work/dev-c-autonomous-wave-diagnostic-integrated
work/dev-c-campaign-simulation
work/dev-d-supply-network-decomposition
work/dev-e-save-validator-mainline
work/dev-e-sequential-migration-pipeline-current-main
work/dev-g-hud-widget-modules
work/dev-h-world-generation
work/dev-i-enemy-patrol-controller
work/dev-j-decision-events
work/dev-k-input-command-registry
work/dev-l-archery-range-ranged-training
work/dev-l-barracks-garrison
```


## Work resumed — 2026-11-19

**Main SHA at this update:** `d46a35807aea1218874aa5f9c110d970eaaccd23`

### PR #212 — reviewed, not approved
- Exact head: `6d0ce0f69c4775412f0c9dcbe55fc80bbc1a9d1c`.
- Godot CI, Battlefield Combat Visual QA, Building Visual QA, Campaign Simulation QA, Builder Reachability QA, Autonomous Wave Diagnostic and Role Sprite Visual QA all passed on that exact head.
- Downloaded and inspected the three 1280×720 combat captures.
- Submitted COMMENT review (review ID `5969321353`). The main concern is visual legibility: melee sweep and shield cues are small at gameplay zoom, and the directional building fracture is obscured by the existing damage flash. The evidence proves the hooks execute, not that players can read them quickly.
- Merge remains blocked pending stronger presentation evidence and normal desktop gameplay acceptance.

### PR #213 — CI cancellation diagnosed and corrected
- Previous head: `193270f9d8ba05f1c4cba1269e5bcd10c22b03c7`.
- The previous Godot CI run was cancelled during the player-animation preview's FFmpeg installation step. Import/parse, the regression matrix, Frontier performance diagnostic and construction spike diagnostic had succeeded. The cancellation occurred during apt dependency installation, not during a Godot test.
- Updated `.github/workflows/godot-ci.yml` on the PR branch in commit `50dfdbcdea239e16713d70d5763dff356520b3b4`: raised the playblast job timeout from 10 to 15 minutes and used `--no-install-recommends` for FFmpeg.
- New exact-head validation was triggered on `50dfdbcdea239e16713d70d5763dff356520b3b4`; at the time of this update the Godot matrix was still running/queued. Recheck before disposition.
- The PR remains draft and must be reconciled with #212. Shared production paths include `building.gd`, `combat_visual_feedback.gd`, `enemy_combat_lifecycle.gd`, and `siege_engine_behavior.gd`.

### PR #210 — reviewed, not approved
- Exact head: `c1c87dbb6b01dcfb9e3d7aae5c19d70db5ccd541`.
- Godot CI, Campaign Simulation QA, Builder Reachability QA and Role Sprite Visual QA passed on that exact head.
- Inspected the 1280×720 civilian-role gameplay capture. It holds each role at a single work-animation progress value, so it demonstrates pose differences but not a complete live work cycle.
- Submitted COMMENT review (review ID `5969356029`) requesting a multi-frame live work-cycle capture, particularly for Hunter and Healer.
- Keep draft until #212's `villager.gd` changes are reconciled and dynamic work-cycle evidence exists.

### Diverged-branch sample audit — dispositions are provisional
The following groups were compared against the current mainline and inspected at representative source-file level. These are **superseded candidates**, not deletion approvals:

- `feat/army-command-rival-civilization` and `feat/rival-civilization-expanded-worlds`: both contain older, divergent implementations of ArmyCommand and EnemyCivilization. The old EnemyCivilization uses abstract resource income; current main has visible economic workers, bounded storage, doctrine-specific build/recruitment plans, and persistence. Current main's ArmyCommand is also more strongly typed. Treat these two branches as superseded by main unless a unique feature is found in a complete patch review.
- `feat/title-screen-mode-select`: current main's title screen includes the campaign selector plus landscape, settings, and scroll/responsive handling. The branch is an older, narrower implementation; superseded candidate.
- `feat/final-boss-wave-pacing`: current main has later `wave_spawner.gd` and `campaign_balance_matrix.gd` implementations. Superseded candidate pending a final unique-patch check.
- `feat/frontier-expedition-192x192`: current main already contains 192×192 Expedition support and a newer, broader Frontier implementation. Treat as superseded candidate pending final unique-patch check.
- `feat/low-cost-profession-sprite-art`, `feat/low-cost-profession-sprite-art-mainline`, and `feat/low-cost-profession-sprite-art-mainline-v2`: same 16-path feature family, but current main has different sprite SVG blobs and a newer animation implementation. Do not cherry-pick these branches wholesale; compare any unique art/animation value before marking superseded.
- `feat/phase-09-balance-performance-release` and its `-rebased`, `-v2`, `-v3`, `-v4`, `-v5` variants: overlapping historical release/balance snapshots. Main now has later versions of the balance and release tests. Treat the family as consolidation candidates; identify any unique, unmerged fixes before superseding the whole group.

The sample audit is not a substitute for the required disposition of all 122 branches. Continue with other branch families, especially active PR heads and any unique features not represented in main. No branch was deleted or merged during this audit pass.


### Diverged-branch sample audit — second batch

Compared another 20 branches against current `main`. These are **superseded candidates** because main contains later versions of the same feature/test areas. They still require a final unique-commit check before any deletion:

- Supply/economy family: `feat/phase-02-depot-cost-sources`, `feat/phase-02-outpost-garrisons`, `feat/phase-02-physical-shipments`, `feat/phase-02-supply-pressure`. Main has current tests for depot cost sources, outpost garrisons, physical shipments, local stockpiles, and supply pressure, plus later shipment ledger/dispatch and supply transaction systems.
- Construction family: `feat/phase-05-builder-construction-sites`, `feat/phase-05-construction-queue-ui`, `feat/phase-05.2b-construction-queue`. Main contains the current construction-site system, queue UI and construction regression suite.
- Frontier infrastructure: `feat/phase-05.3a-watchtower-vision`, `feat/phase-05.3b-granary-food-storage`. Main includes watchtower vision, granary storage and building visual progression, with later implementations and tests.
- Enemy/faction behavior family: `feat/phase-06-beast-rider-charge`, `feat/phase-06-faction-camps-patrols`, `feat/phase-06-factions-territorial-ai`, `feat/phase-06-saboteur-disruption`, `feat/phase-06-scout-marking`, `feat/phase-06-scout-marking-mainline`, `feat/phase-06-siege-engine-cycle`, `feat/phase-06.2-composable-behaviors`. Main includes these behavior systems and regression tests; its behavior modules are later/current versions.
- Conquest objective family: `feat/phase-07-conquest-objectives`. Main contains the later campaign objective, faction registry, frontier campaign and multi-stronghold test coverage.

Two branches in this batch were confirmed fully behind main, with no unique commits: `feat/phase-06-factions-territorial-ai-rebased` and `feat/phase-07-conquest-objectives-mainline`. They remain in the 43 deletion candidates and are not deleted because branch deletion is unavailable.

### Current validation snapshot
- Main `d46a35807aea1218874aa5f9c110d970eaaccd23` had a successful Godot CI run (`44454267413`). The documentation update that recorded the latest review/audit state created main `caac028e14d3470cb3bde60bc5bab045e7e12115`; its Godot CI run `44459260701` was queued when checked.
- PR #213 exact-head `50dfdbcdea239e16713d70d5763dff356520b3b4` had 72 checks registered; 24 completed successfully, 4 were in progress, and 2 queued at the last poll. No failures were present in the returned completed checks. Recheck all checks before deciding.
- Exact duplicate-tip scan of all 170 branches found only the two pairs already recorded above. No additional duplicate tips were found.


### Diverged-branch sample audit — third batch

Compared 20 additional branch tips with current main. Main contains the later implementation/test surface for these feature families. Treat the diverged versions as **superseded candidates**, pending a final unique-commit review:

- Biome/resource presentation: `feat/phase-08-biome-prop-identity`, `feat/phase-08.3-frontier-biome-props`, `feat/phase-08.3-resource-cluster-dressing`. Main has Frontier decoration generation and current resource-node rendering.
- Faction/building/combat/audio presentation: `feat/phase-08.4-faction-visual-identity`, `feat/phase-08.5-building-visual-identity`, `feat/phase-08.6-combat-visual-feedback`, `feat/phase-08.7-regional-audio-identity`. Main contains the current faction, building, combat-feedback and audio modules with matching regression coverage.
- Adaptive viewport: `feat/phase-10-adaptive-viewport`. Main has current responsive layout behavior and regression coverage; `feat/phase-10-adaptive-viewport-mainline` and `feat/responsive-resolution-visual-pass` are fully behind main and remain in the 43 deletion candidates.
- Regional control roads: `feat/regional-control-roads`. Main contains the current road/bridge, territory, navigation, shipment and regional-control implementation plus `regional_control_roads` coverage. `feat/regional-control-roads-mainline` is fully behind main and remains in the 43 deletion candidates.

The following branches in this batch were confirmed fully behind main with zero unique commits and are already part of the 43 deletion candidates: `feat/workplaces-and-specialist-jobs`, `feat/multi-stronghold-campaign`, `feat/rival-local-depots-road-delivery`, `feat/scout-specialist`, `feat/strategic-map-stage-hud`, and `feat/character-animation-pass`.

PR #213 follow-up:
- Latest head after the FX visibility correction: `fa617d6d2d02001e7140844cb40b47f1c2ce939c`.
- Increased structural debris to 12 fragments per base burst, larger 3–4 px chunks, brighter contrasting materials, and longer lifetime.
- Strengthened `shot_fx_readability.gd` to assert exactly one `structure_debris` event rather than relying only on total FX particle count.
- Exact-head validation was running at the time of this update: 72 checks registered, 5 completed successfully, 8 in progress and 59 queued. Recheck before disposition.


### Diverged-branch sample audit — workstream and QA branches

The following workstream families have later implementations in main and are **superseded candidates**, subject to final unique-commit review:

- Data validation and simulation diagnostics: `work/dev-a-data-validation`, `work/dev-c-autonomous-wave-diagnostic`, `work/dev-c-campaign-simulation`. Main has the current schema validator, campaign simulation suite and autonomous-wave diagnostic workflow.
- Supply/logistics decomposition: `work/dev-d-shipment-dispatch`, `work/dev-d-shipment-ledger`, `work/dev-d-supply-network-decomposition`, `work/dev-d-supply-pressure`, `work/dev-d-supply-pressure-manager`. Main has current shipment dispatch/ledger, supply pressure and road/logistics systems.
- Save migration/validation: `work/dev-e-canonical-save-migration`, `work/dev-e-canonical-save-migration-final`, `work/dev-e-canonical-save-migration-latest`, `work/dev-e-canonical-save-migration-mainline`, `work/dev-e-save-validator-extraction`, `work/dev-e-save-validator-mainline`, `work/dev-e-sequential-migration-pipeline`. Main has current save migration pipeline, validator and recovery contract.
- Villager role behaviors: `work/dev-f-blacksmith-behavior`, `work/dev-f-builder-behavior`, `work/dev-f-healer-behavior`, `work/dev-f-scout-behavior`, `work/dev-f-villager-archer-combat`, `work/worker-resource-awareness`. Main has dedicated role behavior modules and bounded reachable-work assignment. `work/dev-f-villager-role-architecture` is a separate registry-based architecture proposal; keep for final semantic review rather than deleting automatically.
- UI/world generation: `work/dev-g-construction-queue-panel`, `work/dev-g-outpost-panel`, `work/dev-h-frontier-decoration`, `work/dev-h-frontier-resources`, `work/dev-h-frontier-terrain`, `work/dev-h-rendered-ci-clean`. Main has later panels, batched decoration/resource generation and rendered-world QA.
- Enemy systems: `work/dev-i-enemy-combat-lifecycle`, `work/dev-i-enemy-raid-behavior`, `work/dev-j-decision-events`, `work/dev-k-input-command-registry`, `work/dev-l-archery-range-ranged-training`, `work/dev-l-barracks-garrison`. Main has current lifecycle, decision event, input, ranged training and garrison modules.
- Documentation snapshots: `work/integration-live-status-2026-11-05`, `work/roadmap-audit-implementation`. Main's worklist now points to this current checkpoint.

Additional QA candidates:
- `fix/title-menu-small-viewport`: current main has newer responsive title-screen handling and tests.
- `fix/phase-06.5-stress-parse`: main has the current faction warfare stress suite.
- `test/phase-09-campaign-combat-simulation`: main has current campaign combat simulation coverage.
- `test/save-file-store-recovery-contract`, `test/save-file-store-recovery-mainline`, `test/villager-lifecycle-recovery`: main has later save and villager recovery tests.
- `qa/rival-workforce-headed-acceptance`, `qa/rival-workforce-rendered-acceptance`: main has physical rival workforce and rendered QA coverage.
- `fix/p0-gameplay-ux-combined` has 20 unique commits but is 367 commits behind main and overlaps current player/HUD/combat/wave systems. Keep as a patch-review candidate until every unique fix is compared; do not merge wholesale.

### Performance branches — preserve selected candidates

Main already contains the core changes from several old performance branches:
- `perf/flowfield-time-budget-mainline`: superseded by main's incremental 2,500 µs FlowField rebuild budget and resource-occupancy invalidation.
- `perf/p1-skip-road-pathfield-rebuilds`: main already skips road-only path invalidations.
- `perf/p1-specialist-interceptor-scans`: main already has bounded interceptor/target caches.
- `perf/p2-bounded-wildlife-selection`: main already uses bounded wildlife candidate selection.
- `perf/territory-region-count-cache-mainline`: main already uses per-region land counts.
- `perf/priority-performance-pass`: old overlapping 11-file package; main already has incremental navigation/flow rebuilds, target caches, bounded wildlife selection and debounced villager job assignment. Review unique patches only.

Preserve for targeted performance review:
- `perf/reduce-raid-simulation-scans`: 8 commits ahead / 24 behind main, 4 changed files. It adds a 0.4 s faction-raid validation cadence, cached return targets, timestamp-based blocked-target expiry and squared-distance checks. Current main does not contain all of these optimizations. Candidate for a focused performance PR after the active combat/FX PRs are settled.
- `perf/territory-region-index-mainline`: 1 commit ahead / 228 behind main, 3 changed files. It builds a per-region land-cell index and updates it from buildable-cell changes; main still scans all map cells when applying conquered-region claims. Candidate for targeted review and rebase.
- `perf/p1-village-job-assignment-counters`: retain only if the unique counters reveal a real assignment hotspot; main already debounces job assignment.
- `perf/acer-a0756-live-acceptance-probe` remains PR #214 and requires actual target-device data.

### Performance evidence from main CI

The main SHA `d46a35807aea1218874aa5f9c110d970eaaccd23` produced a successful synthetic performance/transition run on GitHub's generic Linux runner:

| Profile | Map | World creation | Navigation rebuild avg | Territory rebuild avg | Flow rebuild settle | Flow peak frame |
|---|---:|---:|---:|---:|---:|---:|
| Classic | 128 | 718 ms | 12.0 ms | 1.77 ms | 168 ms / 64 frames | 5.50 ms |
| Frontier | 192 | 1,306 ms | 29.6 ms | 3.66 ms | 528 ms / 183 frames | 3.65 ms |
| Expedition | 256 | 2,142 ms | 51.2 ms | 3.62 ms | 367 ms / 134 frames | 3.14 ms |

Construction-completion synchronous transition calls were only 0.34–0.40 ms; the flow-field work was spread across frames. This benchmark does not reproduce a long construction freeze on the CI device. Full navigation rebuild is a startup cost and should not be confused with the incremental dirty-cell update used for normal building changes.

A separate 180-frame performance sample reported:
- Frontier (192): 119 enemies, 82 villagers; wall-frame p50 7.11 ms, p95 9.20 ms, p99 15.39 ms.
- Expedition (256): 108 enemies, 82 villagers; wall-frame p50 7.67 ms, p95 9.91 ms, p99 39.11 ms.

These are short synthetic samples on a generic CI runner, not target-hardware results and not a five-minute soak. The Godot `TIME_PROCESS` monitor reported values much larger than wall-frame time in the same run; do not interpret those as frame latency until the monitor semantics are reconciled. The reported five-minute gameplay slowdown remains unverified and requires a dedicated long-session soak plus the real low-end laptop probe.


## Latest actions — 2026-11-19

**Main SHA at this update:** `09517a54ddea9aa21c4c4f8bf0b5a96da5827f83`

### PR state normalization
All six open PRs are now drafts. This prevents the parked or unaccepted work from being merged accidentally:
- #212 returned to draft after visual review found melee/shield/fracture cues too subtle at gameplay scale. Review comment ID `5969321353`; PR body records the acceptance gap.
- #213 remains draft pending exact-head Godot CI and overlap reconciliation with #212.
- #210 remains draft pending a multi-frame live work-cycle capture and reconciliation of shared `villager.gd` changes. Review comment ID `5969356029`.
- #214 remains draft pending actual Acer Aspire One A0756 measurements.
- #150 and #152 remain draft because Android is deferred. #152 was converted from ready to draft and has a dirty merge state.

### PR #213 implementation follow-up
Latest branch head: `c336f7923e9b522898bd778f311c0382bf68d4d2`.
- Fixed the earlier FFmpeg-install timeout by raising the playblast timeout to 15 minutes and using `--no-install-recommends`.
- Structural debris now spawns just outside the struck face, uses larger 5–6 px material fragments, and renders at high world z-index so it is not hidden by actors.
- The FX unit test asserts the actual structure-debris burst and its bounded particle count. Assertion failures now exit the test instead of hanging until timeout.
- The desktop-scale still is captured at frame 6; the artifact retains the full sequence, including later spread/fade frames.
- Pixel FX Readability QA, Building Visual QA and Campaign Simulation QA passed on exact head `c336f7923e9b522898bd778f311c0382bf68d4d2`. At the latest poll, the full Godot 4.7 run had 19/72 checks completed successfully, 6 in progress, 47 queued, and no failures. Recheck the final result before any merge.
- Submitted follow-up COMMENT review `5969591218`: the debris-visibility concern is resolved by the latest 1280×720 artifact, but full CI and #212 overlap remain.

### A–D status after this work
- A: the 43 behind-only branch candidates remain documented; deletion is still blocked because the GitHub connection exposes no branch-delete operation.
- B: sample disposition has been expanded across supply, construction, faction behavior, presentation, responsive UI, workstream, QA and performance families. Two performance candidates are preserved for targeted integration review. Full disposition of all 122 diverged branches remains incomplete.
- C: all six open PRs are draft; no PR has been merged or closed. This is deliberate because visual acceptance, exact-head checks, hardware evidence, or overlap reconciliation remains outstanding.
- D: the authoritative checkpoint and worklist pointer are in main. Branch protection is still disabled; the connected GitHub tools expose no ruleset/branch-protection write operation.

### Autonomous schedule
The five previous schedules were disabled. The replacement daily `Autonomous repository cleanup` task starts 2026-11-20 at 08:00 Asia/Jakarta and continues A–D from this checkpoint. It must not start Stage E until every A–D exit criterion is verified. Once complete, it disables itself and creates the Stage E task.


## Autonomous continuation — 2026-11-20

**Live main observed before this documentation update:** `e93618fb107e4cb6a1393a25019125014a58e980`  
**Exact-main validation:** Godot CI run [#44462637803](https://github.com/shimleabyte/hold-the-keep/actions/runs/44462637803) completed successfully on that SHA.  
**Live branch inventory:** 170 branches including `main` (100 on page 1, 70 on page 2). This is a refreshed inventory, not a reuse of the 2026-11-19 count.  
**Live open PR inventory:** six PRs, all still open and draft:
- #212 `feat/battlefield-combat-readability` at `6d0ce0f69c4775412f0c9dcbe55fc80bbc1a9d1c`
- #213 `feat/deterministic-directed-fx` at `c336f7923e9b522898bd778f311c0382bf68d4d2`
- #210 `feat/civilian-work-action-pass` at `c1c87dbb6b01dcfb9e3d7aae5c19d70db5ccd541`
- #214 `perf/acer-a0756-live-acceptance-probe` at `23f53abd0698e0ce482def8d9b8ce9c8e1913a8f`
- #150 `docs/android-armv7-device-qa` at `1d2e29063881f6060f08e3ca3e98202196e55531`
- #152 `feat/android-armv7-touch-controls-current-main` at `a405e8f92f1d9df5ebbea0b18a582ab4a073be15`

### A — first live revalidation batch (8 of 43)

Compared each candidate against live `main` SHA `e93618fb107e4cb6a1393a25019125014a58e980`. All eight have `ahead_by = 0`; the branch tips are fully contained in main. The branch-specific Actions queries returned no queued, in-progress, waiting, requested or pending runs. None is an open PR head.

| Branch | Current tip | Behind main |
|---|---|---:|
| `art/faction-equipment-silhouette-pass` | `cf4d6933bb79bdafdf4a6788ddc95b8bd6ed25d1` | 26 |
| `combat/player-skills-enemy-ai` | `ec2a41bd450c58cec2d75b7e3c00f7f02e6717e0` | 1,099 |
| `docs/update-phase-11-integration-status` | `d5c2fe32d5604a9e5c79dccf5257c4150f6f70fe` | 176 |
| `feat/blacksmith-forge` | `e74a90a8df059a37927251c6c3c1ae32bb4ddb18` | 496 |
| `feat/character-animation-pass` | `4b5699018593dc61a1ebf46f8d34ae65535d04db` | 1,007 |
| `feat/frontier-world-generation-mainline` | `ba33b833139fde02be641183755be9aa509cb63e` | 913 |
| `feat/healer-infirmary` | `7dc6ebf32ed7a8162ddcef5e82019d151643c3db` | 513 |
| `feat/hunter-hunting-lodge` | `5ee139f0d4e44d268b1e0667b9d43bcd9ee3f557` | 646 |

The branch-specific Actions queries returned 2, 0, 0, 9, 0, 11, 8 and 26 historical runs respectively; all returned runs were completed. This confirms no active workflow for this batch, not that every historical run passed. The six current open PR heads are listed above and do not reference these eight branches.

**No branch was deleted.** The connected GitHub tool inventory still has no branch-delete operation. `update_ref` only moves a ref and is not deletion; it was not used. The open-PR and active-Actions reference checks above do not constitute an exhaustive scan of every possible Git reference/deployment consumer, so this batch is not marked deletion-complete.

### B — targeted performance branch disposition

**Branch:** `perf/reduce-raid-simulation-scans`  
**Tip:** `9317f225bfe3ed33312a7ec7a7375e4812845ab9`  
**Comparison to live main:** diverged, 8 commits ahead / 26 behind; merge base `8bf589d75c38e8040275def123d118432552bf7b`.  
**Changed files:** 
- `scripts/behaviors/enemies/enemy_raid_behavior.gd` (+30 / -16)
- `scripts/entities/villager.gd` (+37 / -13)
- `scripts/systems/enemy_targeting.gd` (+6 / -5)
- `tests/faction_raids.gd` (+3 / -0)

The eight unique commits introduce cached faction-raid and retreat targets with a 0.4-second validation cadence, immediate invalid/queued-for-deletion target handling, throttled blocked-target expiry cleanup, and squared-distance comparisons in villager/enemy targeting. Current main still performs the corresponding raid target/return-target scans and blocked-target cleanup on the per-tick path, and still uses distance comparisons in those inspected methods. These changes are not already present as an equivalent patch in the inspected main files.

**Disposition: retain.** This is a coherent performance candidate, not a safe wholesale integration: it changes live raid retreat/target invalidation and villager target selection on four production/test paths, and its base is 26 commits behind current main. Exact-head runs on the branch tip passed: Godot CI #42582406421, Builder Reachability QA #42582406443, Role Sprite Visual QA #42582406454 and Campaign Simulation QA #42582406481. Those runs validate the old branch head, not a rebase onto current main. Rebase/patch extraction and exact-head Godot 4.7 regression plus long-session raid/worker soak are still required. No PR was created and no code was merged.

### C — refreshed PR gates

All six PRs remain open and draft. #152 is currently reported non-mergeable; the other five are reported mergeable, which does not satisfy their acceptance gates.

PR #213's current exact head `c336f7923e9b522898bd778f311c0382bf68d4d2` has four completed successful runs: Godot CI #44462439033, Campaign Simulation QA #44462438998, Pixel FX Readability QA #44462439056 and Building Visual QA #44462439075. The 2026-11-20 review records the required shared siege/building damage-path reconciliation with #212: preserve one damage application, derive direction once in `take_damage_from()`, feed it to directional debris, and retain both visual regression assertions. Do not merge until #212's gameplay-readability gate is accepted and the combined head is retested.

#212 remains blocked on normal-speed desktop gameplay readability: the prior 1280×720 capture did not make the melee sweep, shield cue and directional fracture consistently legible. #210 remains blocked on a multi-frame live civilian work-cycle capture and reconciliation of shared `villager.gd` changes. #214 remains draft pending actual Acer Aspire One A0756 measurements; no measurements are claimed. #150 and #152 remain parked because Android is deferred.

No PR was merged or closed during this pass.

### D — current protection capability check

The refreshed branch inventory reports `protected: false` for `main`. The rulesets endpoint returned an empty array. Reading `/branches/main/protection` returned HTTP 403, `Resource not accessible by integration`. The connected GitHub toolset exposes no branch-protection/ruleset write operation. Therefore protection is **not enabled**; do not treat repository admin metadata as proof that the integration can configure it.

### Remaining work

- A: revalidate the remaining 35 behind-only candidates, complete reference checks, and retain all branches until a genuine branch-delete capability exists.
- B: continue bounded, evidence-backed dispositions for the remaining diverged branches; preserve targeted unique work until patch equivalence and current-main validation are established.
- C: keep #212 first, #213 second, and #210 after their shared villager/combat changes are understood; retain the hardware and Android gates.
- D: branch protection remains blocked by the integration's 403/read-write capability gap. Do not mark A–D complete.


## Autonomous continuation — 2026-11-21

**Live main SHA before this checkpoint-only update:** \`5c846c91557c6e2a6a3604c67bb9679fb0559baa\`  
**Main Godot CI:** run [#44656319186](https://github.com/shimleabyte/hold-the-keep/actions/runs/44656319186), run number 1479, completed successfully on that exact SHA.  
**Live branch inventory:** 170 branches (100 on page 1, 70 on page 2). A complete tip scan found exactly the two duplicate-tip groups recorded in section B below.  
**Important count qualification:** the 43/4/122 classification table above is the 2026-11-19 comparison snapshot. The live inventory count was refreshed, but a complete 170-branch ahead/behind reclassification has not been rerun. Do not treat the old 43/4/122 split as current.

### A — second revalidation batch (16 of 43 recorded candidates)

The first eight candidates were re-compared against the current main SHA above, not merely carried forward from the 2026-11-20 comparison. Eight additional unique candidates were also checked. All 16 have \`ahead_by = 0\` and are fully contained in current main.

| Branch | Current tip | Behind current main | Historical workflow runs | Latest exact-tip run |
|---|---|---:|---:|---|
| \`art/faction-equipment-silhouette-pass\` | \`cf4d6933bb79bdafdf4a6788ddc95b8bd6ed25d1\` | 27 | 2 | success |
| \`combat/player-skills-enemy-ai\` | \`ec2a41bd450c58cec2d75b7e3c00f7f02e6717e0\` | 1,100 | 0 | none |
| \`docs/update-phase-11-integration-status\` | \`d5c2fe32d5604a9e5c79dccf5257c4150f6f70fe\` | 177 | 0 | none |
| \`feat/blacksmith-forge\` | \`e74a90a8df059a37927251c6c3c1ae32bb4ddb18\` | 497 | 9 | success |
| \`feat/character-animation-pass\` | \`4b5699018593dc61a1ebf46f8d34ae65535d04db\` | 1,008 | 0 | none |
| \`feat/frontier-world-generation-mainline\` | \`ba33b833139fde02be641183755be9aa509cb63e\` | 914 | 11 | success |
| \`feat/healer-infirmary\` | \`7dc6ebf32ed7a8162ddcef5e82019d151643c3db\` | 514 | 8 | success |
| \`feat/hunter-hunting-lodge\` | \`5ee139f0d4e44d268b1e0667b9d43bcd9ee3f557\` | 647 | 26 | success |
| \`feat/multi-stronghold-campaign\` | \`aa52e91a72412a65aa99b8e75914af1cee678d45\` | 907 | 3 | success |
| \`feat/phase-05-resource-worksites\` | \`8590955dc13b1de62a0480970df6cc4d9b13ab0d\` | 880 | 6 | success |
| \`feat/phase-06-factions-territorial-ai-rebased\` | \`38f6d19dcad0fdb91b206924a75f746f3eccf138\` | 848 | 13 | success |
| \`feat/phase-06-shieldbearer-brace\` | \`639996f9bfa1ae939891bc44afd5266148a9ef07\` | 795 | 2 | success |
| \`feat/phase-06.4-faction-raids\` | \`323fe74969a6c202cf84a0117de62369e19620f9\` | 741 | 7 | success |
| \`feat/phase-06.5-faction-warfare-stress\` | \`a1bf45b85498acb1b74b3857d7753d25fb6fc3a0\` | 729 | 3 | failure |
| \`feat/phase-07-conquest-objectives-mainline\` | \`131e116a3330e0e01af26298ff8529157e335391\` | 845 | 1 | success |
| \`feat/phase-09-balance-performance-release-mainline\` | \`cb7d07a31d3a78b06f46b584bfd9b5d2019683e7\` | 842 | 1 | success |

For all 16, branch-specific Actions queries found no queued, in-progress, waiting, requested, or pending runs. The workflow counts above are historical totals, not active work. The current six open PR heads do not include any of these branches. Branch-qualified all-state PR searches for the eight newly checked candidates returned no PR records. None of the 16 belongs to either duplicate-tip group found in the live 170-branch scan.

The latest exact-tip workflow for \`feat/phase-06.5-faction-warfare-stress\` failed (run #41384326890); this does not affect containment, but it is recorded rather than hidden. The other exact-tip runs listed as successful are historical and do not constitute current-main validation.

**Deletion remains blocked.** The connected GitHub tool inventory still exposes no genuine branch-delete operation. \`update_ref\` only moves a ref and is not deletion; it was not used. The reference checks above cover PR history for the new batch, the current open-PR inventory, branch-specific Actions activity, and duplicate branch tips. They do not prove the absence of every possible external deployment or consumer reference. No branch was deleted. Nineteen of the 43 recorded candidates remain to be revalidated.

### B — exact duplicate-tip groups and dispositions

The refreshed scan of all 170 branch tips found exactly two duplicate-tip groups. Identical tip SHA means the two names point to the same commit graph and tree; the compare file sets below therefore apply identically to both names.

**Reload acceptance group**
- Shared tip: \`c8719082f95d362e62b8a04f5c3d9ca2959da2c4\`.
- Compared with current main: 6 unique commits ahead / 718 behind.
- Changed files: \`tests/README.md\`, \`tests/campaign_reload_hardening.gd\`.
- Branch-qualified PR searches found no PRs for either name. Both branch workflow histories are completed only (6 runs and 1 run); no active run exists.
- \`feat/phase-09.3-reload-acceptance\`: **retain** as canonical name because the unique changed surface is acceptance-test documentation and coverage.
- \`feat/phase-09.3-late-act-reload-hardening\`: **delete-candidate** because its tip is exactly identical to the retained branch. Do not delete until the genuine delete capability exists and reference checks are repeated immediately before deletion.

**Frontier rendered-repeatability group**
- Shared tip: \`65f852d6d923066ad38d2eb360e7299b949f20ff\`.
- Compared with current main: 7 unique commits ahead / 367 behind.
- Changed files: \`.github/workflows/rendered-world-qa.yml\`, \`tests/shot_frontier_seed_compare.gd\`.
- Branch-qualified PR searches found no PRs for either name. The non-final branch has 7 completed historical workflow runs; the final branch has none. Neither has an active run.
- \`work/dev-h-frontier-rendered-repeatability-final\`: **retain** as canonical name.
- \`work/dev-h-frontier-rendered-repeatability\`: **delete-candidate** because its tip is exactly identical to the retained branch. Do not delete until the genuine delete capability exists and reference checks are repeated immediately before deletion.

These four branch dispositions are current and evidence-backed. They do not complete the full diverged-branch audit; the remaining historical diverged set still requires bounded review. The two duplicate groups are not grounds for merging or deleting any unrelated branches.

### C — refreshed PR state and ordered gates

All six PRs remain open and draft. No PR was merged or closed.

| PR | Current head | Current comparison to main | Current disposition |
|---|---|---|---|
| [#212](https://github.com/shimleabyte/hold-the-keep/pull/212) | \`6d0ce0f69c4775412f0c9dcbe55fc80bbc1a9d1c\` | 27 ahead / 9 behind; 14 files | Review first; hold for normal-speed desktop combat readability |
| [#213](https://github.com/shimleabyte/hold-the-keep/pull/213) | \`c336f7923e9b522898bd778f311c0382bf68d4d2\` | 57 ahead / 9 behind; 12 files | Reconcile after #212; shared building/siege damage path |
| [#210](https://github.com/shimleabyte/hold-the-keep/pull/210) | \`c1c87dbb6b01dcfb9e3d7aae5c19d70db5ccd541\` | 5 ahead / 9 behind; 4 files | Wait until shared villager changes are understood and live work-cycle evidence exists |
| [#214](https://github.com/shimleabyte/hold-the-keep/pull/214) | \`23f53abd0698e0ce482def8d9b8ce9c8e1913a8f\` | 3 commits; 1 file | Keep draft; no actual Acer Aspire One A0756 measurements are attached |
| [#150](https://github.com/shimleabyte/hold-the-keep/pull/150) | \`1d2e29063881f6060f08e3ca3e98202196e55531\` | 10 commits; 1 file | Park; Android deferred |
| [#152](https://github.com/shimleabyte/hold-the-keep/pull/152) | \`a405e8f92f1d9df5ebbea0b18a582ab4a073be15\` | 15 commits; 11 files | Park; Android deferred; latest metadata reports non-mergeable |

**#212 first:** exact-head Godot CI #42742842633, Battlefield Combat Visual QA #42742842502, Building Visual QA #42742842653, Campaign Simulation QA #42742842817, Builder Reachability QA #42742842505, Autonomous Wave Diagnostic #42742842641, and Role Sprite Visual QA #42742842469 all completed successfully on its exact head. The only recorded review is COMMENTED, not approval. The prior 1280×720 captures still do not establish rapid normal-speed readability of the melee sweep, shield cue, and directional fracture mark. Do not merge.

The #212 metadata reads disagreed on mergeability: \`get_pr_info\` reported true while the separate PR fetch snapshot reported false. Treat mergeability as requiring a fresh consistent read before any future merge attempt. This disagreement does not change the acceptance hold.

**#213 second:** exact-head Godot CI #44462439033, Campaign Simulation QA #44462438998, Pixel FX Readability QA #44462439056, and Building Visual QA #44462439075 all completed successfully on \`c336f7923e9b522898bd778f311c0382bf68d4d2\`. The latest COMMENTED review resolves the debris-visibility concern but documents a concrete overlap with #212 in \`building.gd\`, \`siege_engine_behavior.gd\`, and \`tests/siege_engine_behavior.gd\`. Preserve one damage application, derive direction once in \`take_damage_from()\`, pass that direction into directional debris, and retain both visual assertions. Reconcile and rerun exact-head Godot 4.7 plus both rendered QA workflows after #212 is accepted.

**#210 after shared changes:** exact-head Godot CI #42745235410, Campaign Simulation QA #42745235375, Builder Reachability QA #42745235349, and Role Sprite Visual QA #42745235471 all completed successfully on its exact head. Its only recorded review is COMMENTED. The current evidence remains a fixed-pose comparison rather than a multi-frame live work cycle; keep draft until Hunter/Healer work-cycle evidence exists and #212's \`villager.gd\` changes are reconciled.

#214 remains gated on real hardware measurements, not CI. #150 and #152 remain parked. No merge or closure is authorized by this evidence.

### D — protection and worklist baseline

- The live branch inventory reports \`main.protected = false\`.
- The rulesets endpoint returns an empty array.
- Reading \`/branches/main/protection\` returned HTTP 403: \`Resource not accessible by integration\`.
- The connected GitHub tool inventory exposes no branch-protection/ruleset write operation and no branch-delete operation. Protection is **not enabled**.
- \`worklist.md\` was fetched from current main and still contains the pointer to \`docs/REPOSITORY_CLEANUP_CHECKPOINT.md\`; no worklist edit was needed.
- The current code baseline SHA and successful Godot CI run are recorded at the top of this section. They are not the final A–D SHA because branch dispositions, PR gates, deletion capability, and branch protection remain unresolved.

### Remaining work after 2026-11-21

- A: revalidate the remaining 19 recorded behind-only candidates against a freshly read main; repeat PR/workflow/reference checks; retain branches until genuine deletion is available.
- B: continue bounded, complete dispositions for the remaining diverged branches. Do not convert provisional superseded candidates into final dispositions without unique-commit and patch-equivalence evidence.
- C: keep #212 first, #213 second, #210 third; resolve only after review, exact-head Godot 4.7 checks, rendered acceptance, and conflict reconciliation. Keep #214 and Android PRs parked.
- D: establish actual branch protection/rulesets through a capability that has the required administration permission. Do not mark protection enabled based on repository admin metadata alone.

A–D remain incomplete. Stage E has not started.


### A — third revalidation batch (24 of 43 recorded candidates)

Eight more recorded candidates were compared against live main SHA \`cd84c309965a73a85795cf5fa5d83072ca2200ad\`. All eight have \`ahead_by = 0\` and are fully contained in that mainline snapshot.

| Branch | Current tip | Behind current main | Historical workflow runs | Latest exact-tip run |
|---|---|---:|---:|---|
| \`feat/phase-10-adaptive-viewport-mainline\` | \`c315002c01ace530a85948e86183d180cf560755\` | 840 | 1 | success |
| \`feat/regional-control-roads-mainline\` | \`1cda66041cfd9efc81ce26efcbe2448f7d5d1b21\` | 916 | 11 | success |
| \`feat/responsive-resolution-visual-pass\` | \`efa34eb0dd61d7b1b50647a96996ed9a4179b3bb\` | 1,020 | 0 | none |
| \`feat/rival-local-depots-road-delivery\` | \`04c76d6c8bd4a881c8139a1de6c5c798a383ed8e\` | 41 | 0 | none |
| \`feat/scout-specialist\` | \`6d92bb21e5ca4dcffe8db292bfe17f84020cd6ce\` | 576 | 11 | success |
| \`feat/strategic-map-stage-hud\` | \`656b049f5cb38137e5edefd8895bfc4bb6823025\` | 1,058 | 0 | none |
| \`feat/workplaces-and-specialist-jobs\` | \`8252ffec6289fd925819603aa98f3a2f80fce691\` | 909 | 9 | success |
| \`fix/ci-regression-test-timeouts\` | \`bf92f2acbcd051cac5aae4bc28d1701de2c88d08\` | 960 | 3 | failure |

All eight branch-specific Actions queries returned no active runs. The current six open PR heads do not reference these branches, and the refreshed duplicate-tip scan found no duplicate alias among them. The exact-tip runs for \`fix/ci-regression-test-timeouts\` failed (runs #41289742362 and #41289685804); record this as historical branch evidence, not as a passing validation claim. No branch was deleted.

A now has 24 of the 43 recorded candidates revalidated against a recent live main snapshot. Nineteen remain. This does not waive the repeated reference checks required immediately before any future deletion.

**Latest-main CI after the prior checkpoint update:** Godot CI run #44850521099 is queued on main SHA \`cd84c309965a73a85795cf5fa5d83072ca2200ad\`. The previously successful run #44656319186 applies to the prior main SHA \`5c846c91557c6e2a6a3604c67bb9679fb0559baa\`; do not describe the queued run as passed.

## Autonomous continuation - 2026-11-22

**Live main SHA before this checkpoint-only update:** 66c7c12b5d4a4e37a31602831af2599541385bb7. Its verified parent is cd84c309965a73a85795cf5fa5d83072ca2200ad. The previous 24 candidate checks were made against that parent, so their containment remains transitive on this main head.  
**Main Godot CI:** run [#44850630034](https://github.com/shimleabyte/hold-the-keep/actions/runs/44850630034), run number 1481, completed successfully on exact SHA 66c7c12b5d4a4e37a31602831af2599541385bb7.  
**Live branch inventory:** 170 branches (100 on page one, 70 on page two).  
**Live open PR inventory:** six: #212, #213, #210, #214, #150, and #152.

### A - final recorded-candidate containment batch (43 of 43)

The final 19 names from the recorded 43-candidate list were fetched by exact Git ref and compared against current main SHA 66c7c12b5d4a4e37a31602831af2599541385bb7. Every comparison returned ahead_by = 0 and zero unique commits. Each branch-qualified all-state PR search returned no PR records. Each branch Actions query returned no queued, in-progress, waiting, requested, or pending runs.

| Branch | Exact tip | Behind current main | Historical Actions runs | Latest exact-tip evidence |
|---|---|---:|---:|---|
| fix/hud-discovered-type | 8620a2de038bf6db5857e7f313377eae727edff7 | 1,100 | 0 | none |
| fix/rival-worker-cargo-conservation | a9c5319f3a4249dd27fb908960094aec530cac68 | 119 | 0 | none |
| integrate/data-db-validation-mainline | 1c3cbde5c4ea81003953ea3e88196e910c1168f9 | 469 | 1 | success on exact tip |
| overhaul/territory-expansion | 56cf47d0a5811c70b670d2fd68dce1f0ae01a3c0 | 1,130 | 0 | none |
| qa/desktop-export-acceptance | 1bf731378f95748579a0fc5c119724eb06bbbd8e | 233 | 0 | none |
| qa/headed-mode-source-export | 185888507a0197ef50711672948f118844daf122 | 36 | 1 | latest success was on older SHA aff8f602cea72c35bb3888c17a82044a81ae6ab5, not this tip |
| work/dev-b-faction-ai-components | e8a7dfa240a634947d884489e69271cfc6b8eacb | 475 | 2 | latest success on exact tip; older run cancelled |
| work/dev-c-autonomous-wave-diagnostic-integrated | 6bce640a5708aa342bdf43d80f4924f47fdcbc6e | 366 | 0 | none |
| work/dev-c-campaign-simulation | cec36b62ce376c96d88f665be2295d072e696227 | 474 | 2 | latest two runs successful on exact tip |
| work/dev-d-supply-network-decomposition | 9615e818ace3f785e902fd44200a14736848e80c | 456 | 2 | latest two runs successful on exact tip |
| work/dev-e-save-validator-mainline | b1b8cd952c99643aa22c31ae946c0300ad5fa5e4 | 436 | 4 | latest two runs successful on exact tip |
| work/dev-e-sequential-migration-pipeline-current-main | 0c390ee35b9929ac8d68766decbd9e31f9998e65 | 421 | 2 | latest two runs successful on exact tip |
| work/dev-g-hud-widget-modules | b834eff1cfd579561705519a318dc1a013af6c37 | 390 | 2 | latest two runs successful on exact tip |
| work/dev-h-world-generation | f695f940346be2146a281b8fa83772326e8d7ffc | 431 | 2 | latest two runs successful on exact tip |
| work/dev-i-enemy-patrol-controller | 3c1f50b24775de1312feef1c7c6acfd7b2c07d13 | 464 | 2 | latest success on exact tip; one older success |
| work/dev-j-decision-events | 84b43d311021cf2a719341189007eb82581d37ef | 459 | 15 | latest two runs successful on exact tip |
| work/dev-k-input-command-registry | 28675b868552f158ff107350ad93b25f6e079ca0 | 444 | 2 | latest two runs successful on exact tip |
| work/dev-l-archery-range-ranged-training | f95a89791dcffb14dd09e53fdbc47dcddc771a5a | 403 | 4 | latest two runs successful on exact tip |
| work/dev-l-barracks-garrison | 4c9203c61854a683f8c5dd76eca0ea3bdc81f845 | 430 | 8 | latest two runs successful on exact tip |

The prior 24 candidates are documented in the 2026-11-20 and 2026-11-21 sections above. Their checks covered containment, current PR-head exclusion, branch-specific Actions activity, and the duplicate-tip inventory. Because current main is a direct child of the SHA used for those comparisons, their contained tips remain contained on this current main.

**A containment result:** all 43 recorded candidates are now proven to have zero unique commits relative to current main. For the final 19, branch-specific PR searches found no records and no active Actions runs. Historical workflow totals are not interpreted as current activity. No candidate was deleted.

**A remains blocked, not complete.** The connected GitHub tool inventory exposes no genuine branch-delete operation. The available update_ref action only moves a ref, optionally with force; it is not deletion and was not used. The integration also exposes no supported deployment/reference enumeration action, so absence of every possible external deployment or consumer reference cannot be proven. Retain all 43 branches. Do not attempt ref updates as deletion.

### B - diverged-branch audit status

No new diverged-branch disposition was finalized in this run. The two exact duplicate-tip groups and their retain/delete-candidate dispositions remain as recorded in the 2026-11-21 section. The performance branch perf/reduce-raid-simulation-scans remains retain pending rebase/patch extraction and fresh Godot 4.7 validation. Other sample superseded candidates remain provisional until their unique commits and patch equivalence are reviewed. The full diverged-branch inventory still lacks a final disposition for every branch. No integration, merge, or branch deletion was performed.

### C - refreshed ordered PR review

**PR #212 - first review**

- Current state: open, draft, mergeable = false; head 6d0ce0f69c4775412f0c9dcbe55fc80bbc1a9d1c; base SHA d6a54036f7d7587c6e4cbd7188a620a6f9bc9d19.
- Current comparison to main: 27 commits ahead / 11 behind; 14 changed files.
- Changed files: .github/workflows/combat-visual-qa.yml; scripts/behaviors/enemies/enemy_combat_lifecycle.gd; scripts/behaviors/shieldbearer_behavior.gd; scripts/behaviors/siege_engine_behavior.gd; scripts/entities/arrow.gd; scripts/entities/building.gd; scripts/entities/combat_visual_feedback.gd; scripts/entities/enemy.gd; scripts/entities/enemy_bolt.gd; scripts/entities/player.gd; scripts/entities/villager.gd; tests/combat_visual_feedback.gd; tests/shot_combat_engagement.gd; tests/siege_engine_behavior.gd.
- Review state: one COMMENTED review, no approval. The review says the melee sweep and shield cue remain difficult to read at gameplay zoom and the building fracture is obscured by the hit flash. No normal-speed desktop gameplay acceptance has been attached.
- Exact-head successful runs: [Godot CI #42742842633](https://github.com/shimleabyte/hold-the-keep/actions/runs/42742842633), [Battlefield Combat Visual QA #42742842502](https://github.com/shimleabyte/hold-the-keep/actions/runs/42742842502), [Building Visual QA #42742842653](https://github.com/shimleabyte/hold-the-keep/actions/runs/42742842653), [Campaign Simulation QA #42742842817](https://github.com/shimleabyte/hold-the-keep/actions/runs/42742842817), [Builder Reachability QA #42742842505](https://github.com/shimleabyte/hold-the-keep/actions/runs/42742842505), [Autonomous Wave Diagnostic #42742842641](https://github.com/shimleabyte/hold-the-keep/actions/runs/42742842641), and [Role Sprite Visual QA #42742842469](https://github.com/shimleabyte/hold-the-keep/actions/runs/42742842469). All are successful on the exact head.
- Decision: do not merge. The visual/gameplay acceptance gate remains unresolved; mergeability is currently false.

**PR #213 - second review and overlap reconciliation**

- Current state: open, draft, mergeable = false; head c336f7923e9b522898bd778f311c0382bf68d4d2; base SHA d6a54036f7d7587c6e4cbd7188a620a6f9bc9d19.
- Current comparison to main: 57 commits ahead / 11 behind; 12 changed files.
- Exact-head successful runs: [Godot CI #44462439033](https://github.com/shimleabyte/hold-the-keep/actions/runs/44462439033), [Campaign Simulation QA #44462438998](https://github.com/shimleabyte/hold-the-keep/actions/runs/44462438998), [Pixel FX Readability QA #44462439056](https://github.com/shimleabyte/hold-the-keep/actions/runs/44462439056), and [Building Visual QA #44462439075](https://github.com/shimleabyte/hold-the-keep/actions/runs/44462439075).
- Three COMMENTED reviews are recorded; no approval. The latest review identifies the exact shared patch in scripts/behaviors/siege_engine_behavior.gd, scripts/entities/building.gd, and tests/siege_engine_behavior.gd.
- Reconciliation requirement: keep one damage application. In the combined building path, take_damage_from() must derive the source-side direction once, set the directional fracture state, and forward that same direction into the directional-debris take_damage() overload. Both normal siege and faction-assault impact paths should prefer take_damage_from() when supported, with a one-argument fallback for other target types. Keep both the directional-fracture assertion and the single structure_debris-burst assertion. Do not independently apply damage or emit duplicate debris.
- Decision: do not merge or rebase into main yet. #212's gameplay-readability gate remains unresolved; after that gate is accepted, reconcile the shared path and rerun exact-head Godot 4.7 plus both rendered workflows on the combined head.

**PR #210 - third, after shared villager changes**

- Current state: open, draft, mergeable = false; head c1c87dbb6b01dcfb9e3d7aae5c19d70db5ccd541; base SHA d6a54036f7d7587c6e4cbd7188a620a6f9bc9d19.
- Current comparison to main: 5 commits ahead / 11 behind; 4 changed files: scripts/entities/sprite_anim.gd, scripts/entities/villager.gd, tests/animation_motion.gd, tests/shot_role_sprite_gameplay.gd.
- Review state: one COMMENTED review, no approval. It says the current capture fixes each role at manual_progress = 0.30, proving pose differences but not a live multi-frame work cycle. Hunter/Healer cycle evidence and reconciliation of shared villager.gd changes remain outstanding.
- Exact-head successful runs: [Godot CI #42745235410](https://github.com/shimleabyte/hold-the-keep/actions/runs/42745235410), [Campaign Simulation QA #42745235375](https://github.com/shimleabyte/hold-the-keep/actions/runs/42745235375), [Builder Reachability QA #42745235349](https://github.com/shimleabyte/hold-the-keep/actions/runs/42745235349), and [Role Sprite Visual QA #42745235471](https://github.com/shimleabyte/hold-the-keep/actions/runs/42745235471).
- Decision: keep draft. Do not integrate until #212 and the shared villager path are understood and live work-cycle evidence exists.

**Other PRs**

- #214 remains open and draft at 23f53abd0698e0ce482def8d9b8ce9c8e1913a8f. No actual Acer Aspire One A0756 measurements are attached; CI is not hardware acceptance.
- #150 remains open and draft at 1d2e29063881f6060f08e3ca3e98202196e55531. Android remains deferred.
- #152 remains open and draft at a405e8f92f1d9df5ebbea0b18a582ab4a073be15. Android remains deferred; current metadata reports mergeable = false.
- No PR was merged or closed.

### D - protection and worklist

- Current main branch metadata reports protected = false.
- The rulesets endpoint returns an empty array.
- Reading /branches/main/protection returns HTTP 403: Resource not accessible by integration.
- No branch-protection or ruleset write operation is exposed by the connected GitHub tools. Protection is not enabled.
- worklist.md was fetched and still points to docs/REPOSITORY_CLEANUP_CHECKPOINT.md. No worklist edit was needed.
- The successful main Godot CI run recorded above applies to pre-checkpoint-update SHA 66c7c12b5d4a4e37a31602831af2599541385bb7. The commit created by this checkpoint update must be checked separately; it is not the final A-D baseline.

### Remaining work after 2026-11-22

- A: all 43 recorded candidates are confirmed behind-only, but deletion is blocked by the missing genuine delete operation and reference enumeration is not exhaustive. Retain them. Recheck references immediately before any future deletion.
- B: finish evidence-backed disposition for the full diverged inventory. Existing provisional superseded candidates are not final; continue bounded batches and prioritize unique patch review.
- C: #212 remains first and blocked on normal-speed gameplay readability; #213 remains second and must use the documented one-damage shared path; #210 remains third and needs live work-cycle evidence. Keep #214 and Android PRs parked.
- D: establish branch protection through a connection with branch-administration write capability. Keep the worklist pointer unchanged.
- A-D remain incomplete. Stage E has not started.


## Work resumed — 2026-11-23

**Live main:** `726d968b2189fcf455f8fe9b711c52e247daf13c`  
**Live branch inventory:** 170 branches (100 on page one, 70 on page two).  
**Current main Godot 4.7 CI:** [run #44970532321](https://github.com/shimleabyte/hold-the-keep/actions/runs/44970532321) — completed successfully on exact main SHA `726d968b2189fcf455f8fe9b711c52e247daf13c`.

### A — containment continuity and blockers

- The current main is exactly one commit ahead of the last 43-candidate verification SHA `66c7c12b5d4a4e37a31602831af2599541385bb7`; the intervening commit changes only this checkpoint document. Therefore the previously verified 43 tips remain ancestors of current main.
- The live branch listing still contains 170 branches. The two exact duplicate-tip pairs remain the only duplicate groups found in the full live branch listing.
- No branch was deleted. The connected GitHub tool inventory still has no genuine branch-delete operation; `update_ref` is not deletion and remains prohibited. The available integration also has no supported exhaustive deployment/external-consumer reference enumeration. Keep all 43 candidates intact.

### B — active Android PR-head batch

Two diverged branches with active PRs were compared against current main and retained because Android remains deferred. Their changed-file sets do not overlap, and their tips are not duplicates.

**`docs/android-armv7-device-qa` — retain**
- Exact tip: `1d2e29063881f6060f08e3ca3e98202196e55531`.
- Current comparison: 10 unique commits ahead, 247 commits behind; one changed file, `docs/ANDROID_DEVICE_QA.md`.
- PR history by exact head: PR #150 only; open and draft. No reviews are recorded.
- Exact-tip workflow: [Godot CI #42052408684](https://github.com/shimleabyte/hold-the-keep/actions/runs/42052408684) — cancelled. Other branch runs belong to older tips; no active run was returned.
- Disposition: retain with PR #150 parked. Documentation does not establish physical Android-device acceptance, and Android is deferred.

**`feat/android-armv7-touch-controls-current-main` — retain**
- Exact tip: `a405e8f92f1d9df5ebbea0b18a582ab4a073be15`.
- Current comparison: 15 unique commits ahead, 246 commits behind; 11 changed files: `.github/workflows/godot-ci.yml`, `.gitignore`, `README.md`, `export_presets.cfg`, `project.godot`, `scripts/ui/hud.gd`, `scripts/ui/mobile_controls.gd`, `tests/README.md`, `tests/android_touch_controls.gd`, `tools/export_android_armv7.sh`, and `tools/run_tests.sh`.
- PR history by exact head: PR #152 only; open and draft, mergeable=false. No reviews are recorded.
- Exact-tip workflows: [Godot CI #42053035559](https://github.com/shimleabyte/hold-the-keep/actions/runs/42053035559) and [Campaign Simulation QA #42053035136](https://github.com/shimleabyte/hold-the-keep/actions/runs/42053035136) — both successful. No active run was returned.
- Disposition: retain with PR #152 parked. Green CI does not override the explicit Android deferral or substitute for physical ARMv7 acceptance.

### C — ordered PR #212 refresh

- PR #212 remains open and draft at exact head `6d0ce0f69c4775412f0c9dcbe55fc80bbc1a9d1c`; current metadata reports mergeable=true.
- Current comparison to main: 27 unique commits ahead, 12 behind; 14 changed files. The changed-file set is unchanged from the prior review.
- Exact-head Godot 4.7 and all six associated rendered/diagnostic workflows remain successful: Godot CI #42742842633, Battlefield Combat Visual QA #42742842502, Building Visual QA #42742842653, Campaign Simulation QA #42742842817, Builder Reachability QA #42742842505, Autonomous Wave Diagnostic #42742842641, and Role Sprite Visual QA #42742842469.
- The only review remains COMMENTED, not APPROVED. Its readability findings remain unresolved: melee sweep and shield cue are difficult to distinguish at gameplay zoom, and the building fracture is obscured by the damage flash. No normal-speed desktop gameplay acceptance evidence has been attached.
- Decision: do not merge #212. Mergeability=true is not a substitute for the outstanding visual/gameplay acceptance gate. Continue to #213 reconciliation only after the #212 gate is resolved.

### D — current baseline check

- Current main is unprotected in the live branch listing.
- Rulesets GET still returns an empty array. Branch-protection GET still returns HTTP 403 `Resource not accessible by integration`; no branch-protection/ruleset write operation is exposed. Protection is not enabled.
- `worklist.md` was re-fetched; its first section still points to this authoritative checkpoint. No edit was needed.
- Current main SHA and exact-head Godot CI are recorded above. This is not the final A–D baseline because branch dispositions, PR dispositions, and protection remain unresolved.

**A–D remain incomplete. Stage E has not started.**


### B — diverged-branch audit, bounded batch (2026-11-23)

All comparisons below used current `main` SHA `3a100374021ce3e488cf5bf3c88bd5cc25f9d5d5`. The batch was limited to three branches; no integration or deletion was performed.

**`animation/player-motion-timing` — superseded**
- Exact tip: `e63c1ecf5b70ad3b9ca37054a8b7c5bdd7c3f022`; 28 unique commits ahead / 157 behind; 13 changed paths.
- PR #181 is closed unmerged. Its closure body records a source-level reconciliation against main: `.github/workflows/godot-ci.yml`, `assets/sprites/player.svg`, `docs/ANIMATION_DIRECTION.md`, `scripts/entities/player.gd`, `tests/player_attack_sprite_pose.gd`, `tests/role_sprite_identity.gd`, and `tests/shot_animation.gd` match the PR head byte-for-byte.
- `scripts/entities/sprite_anim.gd` differs only in documentation/comment text and the obsolete Hurt busy-state behavior. Main intentionally keeps Hurt presentation from locking the action state. The branch's `tests/animation_motion.gd` expects the old Hurt pose at frame 20 and busy state; main tests the authored Hurt range beginning at frame 42 and non-locking presentation. Phase 08 plan/context/worklist entries on the branch are stale.
- Exact-tip workflows: Role Sprite Visual QA, Campaign Simulation QA, Autonomous Wave Diagnostic and Rendered World QA passed; Godot CI [#42348957431](https://github.com/shimleabyte/hold-the-keep/actions/runs/42348957431) failed. No active workflow run or remaining PR reference was found.
- Disposition: superseded. PR #181 explicitly records no unique required production change; retain as historical reference only if needed. Do not integrate its obsolete Hurt behavior.

**`baseline/frontier-expedition-perf-8bf589d` — delete-candidate**
- Exact tip: `2972b816b2f5ee931a6ad896fb2411b04e0420ec`; 1 unique commit ahead / 31 behind; one changed path, `README.md`.
- The entire unique patch is a temporary HTML comment marker used to trigger the pre-optimization Frontier performance workload. PR #209 is closed unmerged; its body says the measurement-only baseline completed, the branch was never intended for merge, and the PR was closed after baseline artifacts were collected.
- Exact-tip Godot CI [#42589126427](https://github.com/shimleabyte/hold-the-keep/actions/runs/42589126427) passed. No active workflow or other PR reference was found.
- Disposition: delete-candidate, not integrate. The unique marker has served its measurement purpose and carries no production code. Keep the branch until a genuine branch-delete capability and final live-reference check are available.

**`docs/phase-06-mainline-acceptance` — superseded**
- Exact tip: `728cc0a24952ffb3c2c54a32e0f3721fd048f4a0`; 1 unique commit ahead / 731 behind; four changed paths: `CONTEXT.md`, `ROADMAP_NEXT_LEVEL.md`, `docs/plans/phase-06-plan.md`, and `tests/README.md`.
- PR #49 is closed unmerged. Its closure comment explicitly says the Phase 06 correction was reconciled into current main documentation and that merging this historical snapshot would reintroduce outdated roadmap/context content.
- Exact-tip Godot CI [#41395857009](https://github.com/shimleabyte/hold-the-keep/actions/runs/41395857009) passed. No active workflow or other PR reference was found.
- Disposition: superseded. No production code is present in the unique patch; do not merge the stale documentation snapshot.

**Batch result:** 2 superseded, 1 delete-candidate, 0 integrate, 0 retain. No duplicate tips within this batch. The only exact duplicate-tip groups in the full 170-branch inventory remain the two pairs already listed above.

**Main CI note:** before this checkpoint append, Godot CI run [#45093388907](https://github.com/shimleabyte/hold-the-keep/actions/runs/45093388907) for SHA `3a100374021ce3e488cf5bf3c88bd5cc25f9d5d5` was queued, not green. Do not treat it as a verified pass. The append itself is documentation-only and creates a new main commit; verify its own run separately.


### B/C — live PR-head reclassification and ordered reconciliation (2026-11-23)

All comparisons in this section use exact current-main snapshot `b730a047815085b2b35dbc49b7a0ccf341658f37`. The live inventory is still 170 branches, but the historical `43 behind / 4 ahead / 122 diverged` classification is stale and is not reused. The four previously ahead-only PR heads are now diverged because current main has advanced 14 commits beyond their recorded base.

**Active PR branch dispositions**
- `feat/battlefield-combat-readability` — retain; PR #212; 27 unique commits ahead / 14 behind; 14 changed files.
- `feat/deterministic-directed-fx` — retain; PR #213; 57 unique commits ahead / 14 behind; 12 changed files.
- `feat/civilian-work-action-pass` — retain; PR #210; 5 unique commits ahead / 14 behind; 4 changed files.
- `perf/acer-a0756-live-acceptance-probe` — retain; PR #214; 3 unique commits ahead / 14 behind; one changed file.
- `docs/android-armv7-device-qa` — retain; PR #150; 10 unique commits ahead / 249 behind; one changed file.
- `feat/android-armv7-touch-controls-current-main` — retain; PR #152; 15 unique commits ahead / 248 behind; 11 changed files.

These six branches remain retained because their open PRs have explicit acceptance/deferral gates. None is integrated or deleted. The remaining live diverged-branch inventory still requires bounded review; do not infer a completed disposition count from this sample.

**PR #212 — first, acceptance still blocked**
- Open/draft, exact head `6d0ce0f69c4775412f0c9dcbe55fc80bbc1a9d1c`, mergeable=true; 27 ahead / 14 behind on the exact `b730a...` comparison; 14 changed files.
- Seven exact-head Godot 4.7/rendered/diagnostic workflows remain successful: Godot CI #42742842633, Battlefield Combat Visual QA #42742842502, Building Visual QA #42742842653, Campaign Simulation QA #42742842817, Builder Reachability QA #42742842505, Autonomous Wave Diagnostic #42742842641, and Role Sprite Visual QA #42742842469.
- One COMMENTED review, no approval. The normal-speed desktop readability acceptance remains absent; the review's melee sweep, shield cue and building-fracture legibility findings remain unresolved.
- Decision: retain and do not merge. Current mergeability=true does not satisfy the human visual acceptance gate.

**PR #213 — second, overlap reconciled at patch level**
- Open/draft, exact head `c336f7923e9b522898bd778f311c0382bf68d4d2`, mergeable=false; 57 ahead / 14 behind on the exact `b730a...` comparison; 12 changed files.
- Exact-head Godot 4.7 CI #44462439033, Pixel FX Readability QA #44462439056, Building Visual QA #44462439075 and Campaign Simulation QA #44462438998 all passed.
- Three COMMENTED reviews, no approval. The latest review identifies six shared changed paths with #212: `scripts/behaviors/enemies/enemy_combat_lifecycle.gd`, `scripts/behaviors/siege_engine_behavior.gd`, `scripts/entities/building.gd`, `scripts/entities/combat_visual_feedback.gd`, `tests/combat_visual_feedback.gd`, and `tests/siege_engine_behavior.gd`.
- The concrete non-composable hunk is the building/siege damage path. #212 routes siege impacts through `take_damage_from(amount, actor.global_position)`; #213 currently calls `take_damage(amount, -aim.normalized())` in both normal siege and faction-assault paths. #212 adds the source-aware fracture hook; #213 adds the optional directional-debris overload.
- Required combined implementation: one damage application only. `take_damage_from()` must derive source-side direction once, set the fracture state, and forward that direction into the directional-debris `take_damage()` overload. Both siege impact paths should prefer `take_damage_from()` when available and preserve a one-argument fallback for other target types. Keep both the directional-fracture and exactly-one-`structure_debris` regression assertions. The remaining shared-file changes are separate function/hunk edits and appear composable from the current patches.
- The later FX review confirms the larger debris is visible in the 1280×720 frame-6 capture, resolving that specific debris-visibility concern. The PR still lacks #212 acceptance and is not mergeable.
- Decision: retain, do not merge or rebase into main until #212's visual gate is accepted. Then make the one-path reconciliation and rerun exact-head Godot 4.7, Pixel FX Readability QA and Building Visual QA on the combined head.

**PR #210 — third, shared villager path understood**
- Open/draft, exact head `c1c87dbb6b01dcfb9e3d7aae5c19d70db5ccd541`, mergeable=false; 5 ahead / 14 behind on the exact `b730a...` comparison; four changed files: `scripts/entities/sprite_anim.gd`, `scripts/entities/villager.gd`, `tests/animation_motion.gd`, and `tests/shot_role_sprite_gameplay.gd`.
- Exact-head Godot CI #42745235410, Campaign Simulation QA #42745235375, Builder Reachability QA #42745235349 and Role Sprite Visual QA #42745235471 all passed.
- One COMMENTED review, no approval. The gameplay capture pins all roles at `manual_progress = 0.30`; it demonstrates pose differences, not a live multi-frame work cycle. Hunter/Healer work-cycle evidence is still required.
- #210 and #212 both change `villager.gd`, but the reviewed hunks are separate: #210 changes `_update_anim()` work-role selection/healer visual timing; #212 changes combat-feedback lifecycle, attack events and archer string presentation. Preserve both sets of changes when eventually reconciling; do not discard either file wholesale.
- Decision: retain and keep draft. After #212's acceptance/reconciliation, obtain a multi-frame live work-cycle capture for Hunter and Healer (Builder/Farmer as controls), then rebase/reconcile and rerun exact-head checks.

**PR #214 and Android PRs**
- #214 remains open/draft, mergeable=false, exact head `23f53abd0698e0ce482def8d9b8ce9c8e1913a8f`, 3 ahead / 14 behind, one changed file `tools/hardware_acceptance_probe.gd`. Godot CI #43168403680 passed. No review or actual Acer Aspire One A0756 measurement is attached. Keep parked; the script is a measurement tool, not measurement evidence.
- #150 remains open/draft, mergeable=false, exact head `1d2e29063881f6060f08e3ca3e98202196e55531`; its only changed file is `docs/ANDROID_DEVICE_QA.md`. Exact-tip Godot CI #42052408684 was cancelled; no review. Keep parked.
- #152 remains open/draft, mergeable=false, exact head `a405e8f92f1d9df5ebbea0b18a582ab4a073be15`; 11 changed files. Exact-head Godot CI #42053035559 and Campaign Simulation QA #42053035136 passed; no review. Keep parked.
- Android remains deferred. CI does not substitute for physical ARMv7 device acceptance. No PR was merged or closed.

**Mainline validation at the comparison snapshot:** Godot CI run [#45093688435](https://github.com/shimleabyte/hold-the-keep/actions/runs/45093688435) for `b730a047815085b2b35dbc49b7a0ccf341658f37` was queued at the last poll, not green. This append is documentation-only and creates a new main commit; check its exact-head workflow separately.


### B — diverged-branch audit, documentation-only batch (2026-11-23)

Comparisons used exact `main` SHA `6e2507237c1e28b9d984c19f843d3808ae64a04d`. All three branches contain only historical `worklist.md` edits; their associated PRs were merged, and current main's worklist has later baselines and architecture status. None has an active workflow or open PR reference.

- **`docs/priority-1-architecture-complete` — superseded.** Tip `0791a142a99988ae9372ae863c4bc5284d7b9b72`; 1 unique commit ahead / 383 behind; only `worklist.md` changed. PR #110 merged on 2026-11-04; exact-tip Godot CI [#41833145701](https://github.com/shimleabyte/hold-the-keep/actions/runs/41833145701) passed. Its Priority 1 architecture snapshot is older than current main's worklist/checkpoint state.
- **`docs/reconcile-live-worklist-2026-11-04` — superseded.** Tip `9075dd401446dcab5e970268db721cfd42e5f81b`; 2 unique commits ahead / 406 behind; only `worklist.md` changed. PR #90 merged on 2026-11-04; exact-tip Godot CI [#41773665989](https://github.com/shimleabyte/hold-the-keep/actions/runs/41773665989) passed. The branch's baseline/line-count snapshot is obsolete.
- **`docs/reconcile-worklist-after-scout` — superseded.** Tip `ab27ec9f5ba27a0fe356078f560176a6ab1e35ef`; 3 unique commits ahead / 390 behind; only `worklist.md` changed. PR #104 merged on 2026-11-04; exact-tip Godot CI [#41830780277](https://github.com/shimleabyte/hold-the-keep/actions/runs/41830780277) passed. The branch's Priority 1 status and baseline are replaced by later merged worklist revisions.
- These are not integration candidates: their PR changes already landed and the branch snapshots are superseded by later mainline documentation. No branch deletion was attempted.

**Cumulative bounded B sample recorded so far:** 5 superseded, 1 delete-candidate, 6 retain, 0 integrate across 12 individually reviewed diverged branches/active PR heads. This is a sample only; the rest of the live diverged inventory still needs disposition.

**Main CI note:** Godot CI [#45094026940](https://github.com/shimleabyte/hold-the-keep/actions/runs/45094026940) for comparison SHA `6e2507237c1e28b9d984c19f843d3808ae64a04d` remained queued at the last poll. Do not report it as passed. This append is documentation-only and creates a new main commit; verify its own exact-head run separately.


### Live repository refresh and bounded cleanup progress (2026-11-24)

**Live snapshot before this documentation append**
- Main: 94e52409d9fba405bf03878d6af0b6e335970707 (commit date 2026-11-23 01:21:46 UTC).
- Branch inventory: 170 refs total, including main (100 on page 1, 70 on page 2).
- Open PR inventory: six — #214, #213, #212, #210, #152, #150. Their current head branches remain the six documented retained PR heads.
- Exact-main Godot CI: run #45094144796 completed successfully on exact SHA 94e52409d9fba405bf03878d6af0b6e335970707.
- The 2026-11-19 classification table is historical only. Do not treat its 43/4/122 counts as a current classification.

#### A — current-main revalidation, batch 1 of 43

The following eight recorded behind-only candidates were looked up in the current 170-branch inventory and compared to exact current main SHA 94e52409d9fba405bf03878d6af0b6e335970707. Each has ahead_by = 0, so its current tip is contained in main. None is a head of the six currently open PRs. Branch-scoped Actions queries found no active runs.

| Candidate | Current tip | Behind | Exact-tip workflow result |
|---|---|---:|---|
| art/faction-equipment-silhouette-pass | cf4d6933bb79bdafdf4a6788ddc95b8bd6ed25d1 | 34 | Godot CI and Campaign Simulation QA succeeded |
| combat/player-skills-enemy-ai | ec2a41bd450c58cec2d75b7e3c00f7f02e6717e0 | 1107 | No run found |
| docs/update-phase-11-integration-status | d5c2fe32d5604a9e5c79dccf5257c4150f6f70fe | 184 | No run found |
| feat/blacksmith-forge | e74a90a8df059a37927251c6c3c1ae32bb4ddb18 | 504 | Godot CI succeeded |
| feat/character-animation-pass | 4b5699018593dc61a1ebf46f8d34ae65535d04db | 1015 | No run found |
| feat/frontier-world-generation-mainline | ba33b833139fde02be641183755be9aa509cb63e | 921 | Godot CI succeeded |
| feat/healer-infirmary | 7dc6ebf32ed7a8162ddcef5e82019d151643c3db | 521 | Godot CI succeeded |
| feat/hunter-hunting-lodge | 5ee139f0d4e44d268b1e0667b9d43bcd9ee3f557 | 654 | Godot CI succeeded |

These eight are revalidated as contained at this snapshot; 35 of the recorded 43 candidates still require a current-main refresh. The branch-scoped workflow checks and current open-PR inventory do not enumerate every possible external deployment or consumer reference, so this is not a deletion authorization.

**Deletion blocker remains:** the connected GitHub action set exposes ref updates but no genuine branch-delete or delete-ref operation. No deletion was attempted and update_ref was not used to imitate deletion. An authenticated GitHub browser session could not be verified in this non-interactive run, so no alternate UI deletion path was established. Keep all candidates intact.

#### B — diverged-branch audit, bounded profession-art batch

All three branch comparisons below use exact main SHA 94e52409d9fba405bf03878d6af0b6e335970707.

| Branch | Tip | Unique commits ahead | Behind | Changed paths | Disposition |
|---|---|---:|---:|---:|---|
| feat/low-cost-profession-sprite-art | 72661f22e6442784b0d838bfd6e4256f878fd43c | 26 | 349 | 16 | **superseded** |
| feat/low-cost-profession-sprite-art-mainline | 6323215c15af9384ac8a9b4a346adc3e3d51daf5 | 20 | 282 | 16 | **superseded** |
| feat/low-cost-profession-sprite-art-mainline-v2 | 7faa718d50c09491e841b0d04851683dbb35a581 | 29 | 281 | 21 | **superseded** |

Changed-file sets:
- First branch: five profession SVG sheets; scripts/entities/{iron_ore,resource_tree,rock,sprite_anim,villager,villager_builder_behavior,wildlife_node}.gd; tests/animation_motion.gd; tools/check_role_sprite_reproducibility.py; tools/gen_assets.py; worklist.md.
- Second branch: the same 16-path set.
- V2 branch: .github/workflows/godot-ci.yml; the same five SVG sheets and seven entity scripts; scripts/systems/village.gd; scripts/ui/hud.gd; tests/{animation_motion,perf,workplace_assignments}.gd; both reproducibility/generator tools; worklist.md.

Patch-equivalence findings:
- Whole branch tips are not patch-equivalent. Pairwise compare results: first vs second = 87 ahead / 26 behind with 39 changed paths; first vs V2 = 97 ahead / 26 behind with 45 paths; second vs V2 = 30 ahead / 20 behind with 27 paths.
- The five profession SVG blobs and scripts/entities/sprite_anim.gd are byte-identical across all three branch tips. The second and V2 branches also have byte-identical scripts/entities/villager.gd; the first branch's villager file differs.
- The current main tools/gen_assets.py WORK_ART block is byte-identical to V2's block. Current main scripts/entities/villager_builder_behavior.gd is byte-identical to V2's. Current main's villager implementation is later and larger (60,768 bytes vs 58,439 bytes on V2); the old branch implementation lacks current ResourceWorkBehavior and manual-movement/path-recovery behavior.
- PR #153 for V2 was closed unmerged on 2026-11-05. Its closure comment explicitly says it was superseded by PR #158. PR #158 is merged at 535a7048bcc0971e8c70d2056b4e7c7a672c41fa; comparing that merge commit against current main gives ahead_by = 0, confirming it is an ancestor of main. PR #158's 18 changed paths include the profession SVGs, worker/animation/resource behavior, animation/performance tests, reproducibility tooling and generator. Its merged description documents the same baked contact-art and low-cost worker-feedback feature.
- The V2 exact tip had successful Godot CI (#42006444134), Campaign Simulation QA (#42006444190), Rendered World QA (#42006444209), and Role Sprite Visual QA (#42006444322). No active workflow runs were found for any of the three branch names. Branch-scoped PR history was empty for the first two; V2's only PR was the closed/superseded #153.

Disposition rationale: all three branches represent older variants of the profession-contact/low-cost-worker feature now carried by merged PR #158 and later mainline code. Do not integrate or cherry-pick them. No branch deletion was attempted. This batch adds three superseded dispositions to the previously recorded bounded sample; the rest of the live diverged inventory remains unclassified.

#### C — PR #212 refreshed first

Current PR metadata:
- Open, draft, not merged; head 6d0ce0f69c4775412f0c9dcbe55fc80bbc1a9d1c; base main at the PR's recorded base SHA d6a54036f7d7587c6e4cbd7188a620a6f9bc9d19.
- mergeable = true; 14 changed files: combat visual QA workflow; enemy combat lifecycle; shieldbearer and siege behaviors; arrow, building, combat visual feedback, enemy, enemy bolt, player and villager entities; combat visual feedback, shot engagement and siege behavior tests.
- One submitted review, state COMMENTED; no approval.
- Exact-head workflows all completed successfully: Godot CI #42742842633, Battlefield Combat Visual QA #42742842502, Building Visual QA #42742842653, Campaign Simulation QA #42742842817, Builder Reachability QA #42742842505, Autonomous Wave Diagnostic #42742842641 and Role Sprite Visual QA #42742842469.
- The combined commit-status endpoint returned no legacy statuses; the exact-head Actions runs above are the relevant evidence.

Decision remains **retain / do not merge**. Mergeability and green CI do not satisfy the outstanding normal-speed desktop readability acceptance. The existing review's gameplay-scale concerns about melee sweep, shield cue and directional fracture legibility remain unresolved. Continue to #213 only after #212's acceptance gate is resolved.

#### D — protection and pointer rechecked

- Live branch listing reports main.protected = false.
- Rulesets GET returns an empty array.
- Branch-protection GET returns HTTP 403: Resource not accessible by integration.
- Repository metadata reports admin = true for the connected identity, but the installed GitHub integration cannot access the branch-protection endpoint and exposes no branch-protection/ruleset write operation. Do not claim protection is enabled.
- worklist.md still links to this authoritative checkpoint in its first section; no edit was needed.

This append is a documentation-only update. The exact-main Godot CI pass recorded above applies to pre-append SHA 94e52409d9fba405bf03878d6af0b6e335970707; the new checkpoint commit must be checked separately. A–D remain incomplete; Stage E remains locked.


### Live repository refresh and bounded cleanup pass — 2026-11-25

**Live snapshot and documentation pointer**
- Main at the start of this pass: `6025fabec7be8551e8a689cc0c4b2399f6049b59`.
- Refreshed `worklist.md` so its first line now points to this checkpoint as the current 2026-11-25 authority, without repeating a stale main SHA. That documentation-only commit is `eb31f5815b5a92989ec4f25cb47ddeb0e1ac5952`.
- Compare confirms `6025fabec7be8551e8a689cc0c4b2399f6049b59` is an ancestor of `eb31f5815b5a92989ec4f25cb47ddeb0e1ac5952`; the only intervening path is `worklist.md`. Candidate containment checks below therefore remain valid at the latest main snapshot.
- A fresh empty-query branch search returned 170 refs across two pages (100 + 70), including `main`. The current open PR inventory remains six: #212, #213, #210, #214, #150 and #152.
- For `eb31f5815b5a92989ec4f25cb47ddeb0e1ac5952`, combined legacy commit statuses were empty and the connected workflow-run wrapper returned no PR-triggered runs. That wrapper filters to PR events only; this is not proof that no push/dispatch workflow exists and is not a verified mainline Godot CI pass.

#### A — behind-only candidates, additional batch (12 of 43)

The following 12 candidates were individually compared against exact main snapshot `6025fabec7be8551e8a689cc0c4b2399f6049b59`. Every comparison returned `ahead_by = 0`, no changed files, and no open PR head reference. The 2026-11-24 eight-branch batch was also revalidated transitively: its baseline `94e52409d9fba405bf03878d6af0b6e335970707` is an ancestor of the 6025 snapshot.

| Candidate | Exact tip | Behind | PR-triggered workflow evidence |
|---|---|---:|---|
| `feat/multi-stronghold-campaign` | `aa52e91a72412a65aa99b8e75914af1cee678d45` | 915 | Godot CI #41295675865 passed |
| `feat/phase-05-resource-worksites` | `8590955dc13b1de62a0480970df6cc4d9b13ab0d` | 888 | Godot CI #41298620629 passed |
| `feat/phase-06-factions-territorial-ai-rebased` | `38f6d19dcad0fdb91b206924a75f746f3eccf138` | 856 | Godot CI #41299531170 passed |
| `feat/phase-06-shieldbearer-brace` | `639996f9bfa1ae939891bc44afd5266148a9ef07` | 803 | Godot CI #41329202804 passed |
| `feat/phase-06.4-faction-raids` | `323fe74969a6c202cf84a0117de62369e19620f9` | 749 | Godot CI #41381487306 passed |
| `feat/phase-06.5-faction-warfare-stress` | `a1bf45b85498acb1b74b3857d7753d25fb6fc3a0` | 737 | Godot CI #41384326890 failed |
| `feat/phase-07-conquest-objectives-mainline` | `131e116a3330e0e01af26298ff8529157e335391` | 853 | Godot CI #41308813676 passed |
| `feat/phase-09-balance-performance-release-mainline` | `cb7d07a31d3a78b06f46b584bfd9b5d2019683e7` | 850 | Godot CI #41309193018 passed |
| `feat/phase-10-adaptive-viewport-mainline` | `c315002c01ace530a85948e86183d180cf560755` | 847 | Godot CI #41309501431 passed |
| `feat/regional-control-roads-mainline` | `1cda66041cfd9efc81ce26efcbe2448f7d5d1b21` | 923 | Godot CI #41294474651 passed |
| `feat/responsive-resolution-visual-pass` | `efa34eb0dd61d7b1b50647a96996ed9a4179b3bb` | 1027 | No PR-triggered run returned |
| `feat/rival-local-depots-road-delivery` | `04c76d6c8bd4a881c8139a1de6c5c798a383ed8e` | 48 | No PR-triggered run returned |

The 12 branches have no open PR references in the current branch-head searches. Workflow evidence above is limited to the connector's PR-triggered, first-page run lookup; empty results do not establish absence of push/dispatch runs. The failed historical Godot CI on `feat/phase-06.5-faction-warfare-stress` is recorded, not hidden or treated as a successful validation.

**A progress:** 20/43 candidates have now been revalidated as contained (the prior eight plus these 12); 23 remain. Containment is not deletion authorization: external deployment/consumer references cannot be exhaustively enumerated through the connected integration.

**Deletion blocker unchanged:** the connected GitHub tool catalogue has no genuine branch-delete or delete-ref operation. It exposes ref updates, which must not be used to imitate deletion. No candidate was deleted or modified.

#### B — duplicate-tip groups, fully reconciled

Both known duplicate-tip pairs were refreshed against main snapshot `6025fabec7be8551e8a689cc0c4b2399f6049b59`. Pairwise compare returned `status = identical`, `ahead_by = 0`, `behind_by = 0`, and no changed files within each pair.

**Reload-hardening pair**
- `feat/phase-09.3-late-act-reload-hardening` and `feat/phase-09.3-reload-acceptance` share exact tip `c8719082f95d362e62b8a04f5c3d9ca2959da2c4`.
- Each compares to main as 6 unique commits ahead / 726 behind, with the same two changed paths: `tests/README.md` and `tests/campaign_reload_hardening.gd`.
- PR #56 is closed unmerged; its body explicitly says it was superseded by PR #57. PR #57 is merged, with merge commit `a1ccebed98ac73551f23162a6995e84a0b02c760`. Comparing main against that merge commit returned `ahead_by = 0`, confirming the merge commit is an ancestor of main.
- The duplicate branch patch is therefore represented by merged PR #57; later mainline edits explain why current file blobs are not byte-identical to the old branch tip.
- **Disposition:** both branches superseded. No integration or deletion.

**Rendered Frontier repeatability pair**
- `work/dev-h-frontier-rendered-repeatability` and `work/dev-h-frontier-rendered-repeatability-final` share exact tip `65f852d6d923066ad38d2eb360e7299b949f20ff`.
- Each compares to main as 7 unique commits ahead / 375 behind, with the same two paths: `.github/workflows/rendered-world-qa.yml` and `tests/shot_frontier_seed_compare.gd`.
- PRs #130 and #132 are both closed unmerged and point to that exact same head. The workflow file is byte-identical to current main (blob `016bb6315696d754ba30f9724b24aa2cbc8cd652`). The test harness in main differs only in explanatory comments/formatting, an equivalent map-size expression (`128 * 16` versus `2048`), and a local variable rename; 184 lines are common, with 10 main-only and 5 branch-only lines. PR #138 is merged; its merge commit `6f1886c6918eb7645167db91e8904b60b0accec8` is an ancestor of main, and its body states the SceneTree harness was already present on main and the PR added the workflow only.
- The duplicate branch implementation is therefore superseded by the mainline harness plus merged #138 workflow. No active PR-triggered workflow runs were returned for the duplicate tip.
- **Disposition:** both branches superseded. No integration or deletion.

These four new dispositions extend the previously recorded bounded B sample; the remainder of the diverged inventory still needs review. No duplicate-tip branch was deleted.

#### C — six open PRs refreshed in documented order

All six remain open and draft. No merge or closure occurred.

| PR | Current head | Ahead / behind current main | Changed files | Mergeable | Exact-head workflow evidence |
|---|---|---:|---:|---|---|
| #212 | `6d0ce0f69c4775412f0c9dcbe55fc80bbc1a9d1c` | 27 / 17 | 14 | false | Godot CI #42742842633 and six associated rendered/diagnostic runs passed |
| #213 | `c336f7923e9b522898bd778f311c0382bf68d4d2` | 57 / 17 | 12 | false | Godot CI #44462439033, Pixel FX #44462439056, Building Visual #44462439075, Campaign Simulation #44462438998 passed |
| #210 | `c1c87dbb6b01dcfb9e3d7aae5c19d70db5ccd541` | 5 / 17 | 4 | false | Godot CI #42745235410, Campaign Simulation #42745235375, Builder Reachability #42745235349, Role Sprite Visual #42745235471 passed |
| #214 | `23f53abd0698e0ce482def8d9b8ce9c8e1913a8f` | 3 / 17 | 1 | false | Godot CI #43168403680 passed |
| #150 | `1d2e29063881f6060f08e3ca3e98202196e55531` | 10 / 249 | 1 | false | Godot CI #42052408684 cancelled |
| #152 | `a405e8f92f1d9df5ebbea0b18a582ab4a073be15` | 15 / 248 | 11 | false | Godot CI #42053035559 and Campaign Simulation #42053035136 passed |

**#212 first:** exact changed paths are `.github/workflows/combat-visual-qa.yml`, `scripts/behaviors/enemies/enemy_combat_lifecycle.gd`, `scripts/behaviors/shieldbearer_behavior.gd`, `scripts/behaviors/siege_engine_behavior.gd`, `scripts/entities/arrow.gd`, `scripts/entities/building.gd`, `scripts/entities/combat_visual_feedback.gd`, `scripts/entities/enemy.gd`, `scripts/entities/enemy_bolt.gd`, `scripts/entities/player.gd`, `scripts/entities/villager.gd`, `tests/combat_visual_feedback.gd`, `tests/shot_combat_engagement.gd`, and `tests/siege_engine_behavior.gd`. One COMMENTED review remains; no approval. The normal-speed desktop readability gate is still absent. GitHub now reports mergeable=false and main is 17 commits ahead of the PR base. Do not merge.

**#213 second:** exact changed paths are `.github/workflows/fx-readability-qa.yml`, `.github/workflows/godot-ci.yml`, `scripts/behaviors/enemies/enemy_combat_lifecycle.gd`, `scripts/behaviors/siege_engine_behavior.gd`, `scripts/entities/building.gd`, `scripts/entities/combat_visual_feedback.gd`, `scripts/entities/fx_layer.gd`, `tests/combat_visual_feedback.gd`, `tests/fx_layer.gd`, `tests/shot_fx_readability.gd`, `tests/siege_engine_behavior.gd`, and `tools/run_tests.sh`. Three COMMENTED reviews; no approval. The six shared paths with #212 remain `enemy_combat_lifecycle.gd`, `siege_engine_behavior.gd`, `building.gd`, `combat_visual_feedback.gd`, `tests/combat_visual_feedback.gd`, and `tests/siege_engine_behavior.gd`. Preserve one damage application: source-aware `take_damage_from()` must derive direction once, set fracture state and forward direction into the debris overload; both siege paths must retain the one-argument fallback for other targets. Do not reconcile/merge before #212's visual acceptance.

**#210 third:** exact changed paths remain `scripts/entities/sprite_anim.gd`, `scripts/entities/villager.gd`, `tests/animation_motion.gd`, and `tests/shot_role_sprite_gameplay.gd`. One COMMENTED review; no approval. The multi-frame live Hunter/Healer work-cycle evidence is still missing. Its `villager.gd` hunks are separate from #212's combat-feedback hunks and both sets must be preserved when eventually reconciled. Do not merge.

**Parked PRs:** #214 has no reviews and no Acer Aspire One A0756 measurements; keep draft. #150 and #152 have no reviews and remain parked because Android is deferred. #150's Godot CI is cancelled; #152's recorded exact-head CI and campaign simulation pass do not substitute for physical ARMv7 acceptance.

#### D — baseline, pointer and capability limitations

- `worklist.md` now points to this authoritative checkpoint with a 2026-11-25 date; pointer refresh commit: `eb31f5815b5a92989ec4f25cb47ddeb0e1ac5952`.
- Main protection remains unenabled. The connected GitHub tool catalogue exposes no branch-protection or ruleset write operation. The last verified protection read returned HTTP 403 `Resource not accessible by integration`, and the rulesets read returned an empty array. Do not claim protection is enabled.
- The connected tool catalogue also exposes no genuine branch-delete/delete-ref operation. Ref update is not deletion.
- Current-main CI cannot be certified from this connector response: combined statuses are empty, and the workflow-run wrapper returns PR-triggered runs only. No exact-main Godot CI pass is asserted for `eb31f5815b5a92989ec4f25cb47ddeb0e1ac5952`.

**A–D remain incomplete.** The remaining 23 behind-only candidates, remaining diverged-branch dispositions, six PR dispositions/acceptance gates, genuine branch deletion and main protection are unresolved. Stage E remains locked.


### Live repository refresh and bounded cleanup pass — 2026-11-26

**Live snapshot before this documentation append**
- Current `main`: `3e2e0e4cfc609df5e2c4376b868c6491578e9fbc`.
- Remote branch inventory: 170 branches total (100 + 70), including main.
- Comparing `6025fabec7be8551e8a689cc0c4b2399f6049b59` to current main shows three commits and only two documentation paths changed: `docs/REPOSITORY_CLEANUP_CHECKPOINT.md` and `worklist.md`. No production code changed in that interval.
- Current open PRs: six (#214, #213, #212, #210, #152, #150). Their head branches are `perf/acer-a0756-live-acceptance-probe`, `feat/deterministic-directed-fx`, `feat/battlefield-combat-readability`, `feat/civilian-work-action-pass`, `feat/android-armv7-touch-controls-current-main`, and `docs/android-armv7-device-qa`. None is one of the 43 behind-only candidates.
- Repository-wide Actions query for `status=in_progress` returned zero active workflow runs at this snapshot.
- The open-PR and Actions checks do not enumerate every possible external deployment, webhook, or consumer reference.

#### A — all 43 behind-only candidates revalidated against current main

The previous 20 verified candidates remain contained because the only intervening changes from their comparison baseline to current main were documentation-only and that baseline is an ancestor of current main. The remaining 23 candidates were individually compared against exact main SHA `3e2e0e4cfc609df5e2c4376b868c6491578e9fbc`; every comparison returned `ahead_by = 0`, status `behind`, and no changed files.

| Candidate | Current tip | Behind |
|---|---|---:|
| `feat/scout-specialist` | `6d92bb21e5ca4dcffe8db292bfe17f84020cd6ce` | 586 |
| `feat/strategic-map-stage-hud` | `656b049f5cb38137e5edefd8895bfc4bb6823025` | 1068 |
| `feat/workplaces-and-specialist-jobs` | `8252ffec6289fd925819603aa98f3a2f80fce691` | 919 |
| `fix/ci-regression-test-timeouts` | `bf92f2acbcd051cac5aae4bc28d1701de2c88d08` | 970 |
| `fix/hud-discovered-type` | `8620a2de038bf6db5857e7f313377eae727edff7` | 1109 |
| `fix/rival-worker-cargo-conservation` | `a9c5319f3a4249dd27fb908960094aec530cac68` | 128 |
| `integrate/data-db-validation-mainline` | `1c3cbde5c4ea81003953ea3e88196e910c1168f9` | 478 |
| `overhaul/territory-expansion` | `56cf47d0a5811c70b670d2fd68dce1f0ae01a3c0` | 1139 |
| `qa/desktop-export-acceptance` | `1bf731378f95748579a0fc5c119724eb06bbbd8e` | 242 |
| `qa/headed-mode-source-export` | `185888507a0197ef50711672948f118844daf122` | 45 |
| `work/dev-b-faction-ai-components` | `e8a7dfa240a634947d884489e69271cfc6b8eacb` | 484 |
| `work/dev-c-autonomous-wave-diagnostic-integrated` | `6bce640a5708aa342bdf43d80f4924f47fdcbc6e` | 375 |
| `work/dev-c-campaign-simulation` | `cec36b62ce376c96d88f665be2295d072e696227` | 483 |
| `work/dev-d-supply-network-decomposition` | `9615e818ace3f785e902fd44200a14736848e80c` | 465 |
| `work/dev-e-save-validator-mainline` | `b1b8cd952c99643aa22c31ae946c0300ad5fa5e4` | 445 |
| `work/dev-e-sequential-migration-pipeline-current-main` | `0c390ee35b9929ac8d68766decbd9e31f9998e65` | 430 |
| `work/dev-g-hud-widget-modules` | `b834eff1cfd579561705519a318dc1a013af6c37` | 399 |
| `work/dev-h-world-generation` | `f695f940346be2146a281b8fa83772326e8d7ffc` | 440 |
| `work/dev-i-enemy-patrol-controller` | `3c1f50b24775de1312feef1c7c6acfd7b2c07d13` | 473 |
| `work/dev-j-decision-events` | `84b43d311021cf2a719341189007eb82581d37ef` | 468 |
| `work/dev-k-input-command-registry` | `28675b868552f158ff107350ad93b25f6e079ca0` | 453 |
| `work/dev-l-archery-range-ranged-training` | `f95a89791dcffb14dd09e53fdbc47dcddc771a5a` | 412 |
| `work/dev-l-barracks-garrison` | `4c9203c61854a683f8c5dd76eca0ea3bdc81f845` | 439 |

**A result:** all 43 recorded candidate tips are currently contained in main; none is an open PR head; no repository-wide active Actions run was returned. This is not an exhaustive external-reference audit. No branch was deleted or modified.

**Deletion blocker unchanged:** the connected GitHub tool catalogue exposes no genuine branch-delete/delete-ref operation. `update_ref` only moves a ref and must not be used as a deletion substitute. Branches remain intact until a genuine delete operation and adequate reference checks are available.

#### B — diverged-branch audit, bounded six-branch batch

All comparisons below use exact main SHA `3e2e0e4cfc609df5e2c4376b868c6491578e9fbc`. PR-history searches across all states returned no associated PRs for these six branches. No active workflow runs were returned repository-wide. The six tips are distinct; no exact duplicate-tip group exists within this batch.

| Branch | Tip | Ahead / behind | Changed paths | Disposition |
|---|---|---:|---:|---|
| `feat/kingdom-expansion-foundation` | `ffee0be84d425847a6f93e624a9946e540558594` | 5 / 972 | 5 | **retain** |
| `feat/rts-command-foundation` | `e8415215eb2ce49ab5005c72d48b45a91e6c0662` | 45 / 240 | 21 | **retain** |
| `feat/protagonist-locomotion-pass` | `1f93321f24a53164e0e74940112457c22f771b98` | 8 / 38 | 5 | **retain** |
| `fix/p0-combat-fairness-and-wave-telegraph` | `f85bb15e1df4cb2a1275a270aef49384e6ee0544` | 5 / 383 | 5 | **retain** |
| `fix/enemy-melee-windup-fairness` | `b41cfe23ad4f231708885ca7abcfb0d7106de57c` | 3 / 381 | 3 | **superseded** |
| `fix/enemy-melee-windup-fairness-mainline` | `c84b4530a008612a3a723967e488308bccfbeda8` | 4 / 380 | 3 | **retain** |

Evidence and next actions:
- `feat/kingdom-expansion-foundation`: changed paths are `tests/README.md`, `tests/parse_all_scripts.gd`, `tests/responsive_layout.gd`, `tools/run_diagnostics.sh`, and `tools/run_tests.sh`. The tip commit fixes the `ProjectSettings` singleton spelling in the responsive-layout test. Preserve the unique diagnostics/test tooling; no integration until the full patch and exact-head Godot 4.7 validation are reviewed.
- `feat/rts-command-foundation`: 21 changed paths include a new 387-line `scripts/systems/rts_command.gd` and new `tests/rts_command_foundation.gd`, plus villager, HUD, main, Frontier campaign and CI changes. The unique command subsystem is not represented by an identical path in main. Preserve; the broad overlap and 240-commit base gap make blind integration unsafe.
- `feat/protagonist-locomotion-pass`: five changed paths include `assets/sprites/player.svg`, `scripts/entities/sprite_anim.gd`, animation direction documentation and two animation tests. The tip commit strengthens protagonist stride silhouettes. Preserve pending a full visual/source comparison against current main and Godot 4.7 validation.
- `fix/p0-combat-fairness-and-wave-telegraph`: five changed paths include `scripts/autoload/game_clock.gd`, `scripts/entities/player.gd`, `tests/campaign_balance_matrix.gd`, and `tests/player_combat.gd`. The tip commit clarifies README cycle duration; earlier unique combat changes remain unmerged and overlap current combat work. Preserve pending exact patch review; do not integrate into the #212/#213 reconciliation without a separate comparison.
- `fix/enemy-melee-windup-fairness` and `fix/enemy-melee-windup-fairness-mainline` are not identical tips: pairwise compare is 5 commits ahead / 3 behind. At the two tips, `scripts/entities/enemy.gd` and `tests/campaign_combat_simulation.gd` are byte-identical; the mainline variant's `enemy_combat_lifecycle.gd` extends the earlier version with raid-specific allowed reach (minimum 28 px for supply/faction raiders). Its campaign test includes the earlier branch's dodgeable-wind-up cases. The earlier branch's three-file implementation is therefore superseded by the more complete mainline variant; retain the mainline variant for targeted extraction/review. Current main already has a newer generalized locked-direction wind-up check, so neither branch is approved for direct integration without checking the depot/raider contract and running Godot 4.7 tests.

No branch was integrated or deleted in this batch. The five retained branches are not merge approvals; their source-level patches and exact-head validation remain outstanding.

#### C — PR #212 refreshed first

- PR #212 remains open and draft. Head is `6d0ce0f69c4775412f0c9dcbe55fc80bbc1a9d1c`; base is `main` at recorded PR base `d6a54036f7d7587c6e4cbd7188a620a6f9bc9d19`. GitHub currently reports mergeable=true.
- Exact changed paths (14): `.github/workflows/combat-visual-qa.yml`; `scripts/behaviors/enemies/enemy_combat_lifecycle.gd`; `scripts/behaviors/shieldbearer_behavior.gd`; `scripts/behaviors/siege_engine_behavior.gd`; `scripts/entities/arrow.gd`; `scripts/entities/building.gd`; `scripts/entities/combat_visual_feedback.gd`; `scripts/entities/enemy.gd`; `scripts/entities/enemy_bolt.gd`; `scripts/entities/player.gd`; `scripts/entities/villager.gd`; `tests/combat_visual_feedback.gd`; `tests/shot_combat_engagement.gd`; `tests/siege_engine_behavior.gd`.
- Review state remains one COMMENTED review and no approval. The review's gameplay-scale acceptance remains unresolved: the melee sweep is difficult to distinguish amid actors, the shield cue is small, and directional fracture is obscured by the red damage flash.
- Exact-head workflow runs all succeeded: Godot CI #42742842633; Battlefield Combat Visual QA #42742842502; Building Visual QA #42742842653; Campaign Simulation QA #42742842817; Builder Reachability QA #42742842505; Autonomous Wave Diagnostic #42742842641; Role Sprite Visual QA #42742842469.
- Decision: retain/open; do not merge. Green exact-head CI and mergeable=true do not satisfy the missing normal-speed desktop readability acceptance. #213 remains second in order; #210 remains third after shared villager/combat changes are understood. #214 remains draft pending actual Acer Aspire One A0756 measurements; #150/#152 remain parked because Android is deferred. No PR was merged or closed.

#### D — protection, pointer and mainline CI

- Current main branch listing reports `protected=false`.
- Rulesets GET returns an empty array. Branch-protection GET returns HTTP 403: `Resource not accessible by integration`.
- Repository metadata reports admin=true for the connected identity, but the installed GitHub integration exposes no branch-protection/ruleset write operation. Protection is not enabled.
- `worklist.md` continues to point to this authoritative checkpoint (current fetched blob SHA `610d44c2e6c9422e7f151073a9c04b764e3fd218`); no pointer change was needed.
- Exact-main Godot CI run [#45524260036](https://github.com/shimleabyte/hold-the-keep/actions/runs/45524260036) completed successfully on exact SHA `3e2e0e4cfc609df5e2c4376b868c6491578e9fbc` (push event, 2026-11-25 01:14:32 UTC). This is the verified code baseline before this documentation append; it is not a CI result for the new checkpoint commit.

**A–D remain incomplete.** All 43 behind-only tips are contained, but branch deletion remains unavailable and external references cannot be exhaustively enumerated. The diverged inventory is still only partially classified. PR #212 still lacks visual acceptance; #213 and #210 remain gated; #214 and Android PRs remain parked. Main protection is not enabled. Stage E remains locked.


### Documentation pointer follow-up — 2026-11-26

The earlier D note in this append said the worklist pointer needed no change. That statement is superseded by this follow-up:
- Updated the first-line checkpoint date in `worklist.md` to 2026-11-26; the link still targets `docs/REPOSITORY_CLEANUP_CHECKPOINT.md`.
- Pointer update commit: `700ecfa68b0ce4d886d851e434eee123aae2ab20`; current worklist blob SHA: `06c2fdbc40455d1793773deaa18663677edbf514`.
- Main at the pointer-update snapshot was exactly `700ecfa68b0ce4d886d851e434eee123aae2ab20`.
- Exact-main Godot CI run [#45738587181](https://github.com/shimleabyte/hold-the-keep/actions/runs/45738587181) was in progress when checked. Do not report it as passed until the conclusion is successful.
- The preceding checkpoint append commit was `d7ebb8eed1bcb873082253fa1cfa432a42c4fe52`. This follow-up changes documentation only; no production code changed.



### B — diverged-branch audit, documentation snapshot batch (2026-11-26)

Compared three additional unclassified branches against exact main SHA `a4271279d8cc0751a4b6ebf890dcba2685a128f2`. Each has only `worklist.md` in its changed-file set. Branch-head PR-history searches returned no associated PRs.

| Branch | Tip | Ahead / behind | Changed paths | Disposition |
|---|---|---:|---:|---|
| `docs/update-worklist-after-save-store-merge` | `8ff76c2a21889b8ce5553ac997dbfe3df0713bfc` | 1 / 412 | `worklist.md` | **superseded** |
| `docs/update-worklist-after-shipment-ledger` | `9ee570a2c06db5a4e6a95b9a74c534685e794195` | 5 / 408 | `worklist.md` | **superseded** |
| `docs/update-worklist-after-villager-slice` | `2cec25d9933e84684fc55f75613bbf60d1cee6d1` | 1 / 410 | `worklist.md` | **superseded** |

The branch contents are older worklist snapshots, not production patches. The current main worklist has later architecture status: SaveFileStore (#89), VillagerArcherCombat (#91), shipment ledger (#94), dispatch/recovery (#96), road graph (#97), and supply pressure (#99) are all recorded as integrated. The six implementation merge commits were individually compared against current main; each returned `ahead_by = 0`, `behind_by > 0`, and no changed files, confirming all six merge commits are ancestors of main. Current main also records later villager-role slices and the up-to-date checkpoint pointer. The branch snapshots add no current source implementation or unique current status; retaining them would preserve stale worklist copies.

No production code changed, no branch was deleted, and no PR was merged or closed in this batch.

**B progress:** three additional diverged branches are now classified as superseded. The full diverged inventory remains incomplete; this is a bounded batch, not a completion claim.

**Main/CI note:** main at the start of this batch was `a4271279d8cc0751a4b6ebf890dcba2685a128f2`. Exact-main Godot CI run #45738587181 was still in progress on prior worklist-pointer commit `700ecfa68b0ce4d886d851e434eee123aae2ab20`; no pass is claimed for `a427127` or this new checkpoint commit.


### Autonomous cleanup pass — 2026-11-27

**Live repository snapshot before this documentation update**
- Default branch: `main`, exact SHA `2e11497aa43210cb28ffdf43b16ff6a347613e48`.
- Remote branch inventory: 170 branches (100 on page 1, 70 on page 2), including `main`.
- All 43 named behind-only candidates remain present in the live branch inventory.
- `main` is unprotected. Branch listing reports `protected=false`; the rulesets endpoint returns an empty array. Branch-protection GET returns HTTP 403, `Resource not accessible by integration`.
- Repository-wide Actions queries returned zero `in_progress` and zero `queued` runs.
- Six open PRs remain: #214, #213, #212, #210, #152 and #150. None uses one of the 43 behind-only candidate branches as its current head.
- External deployment, webhook, and other consumer references cannot be exhaustively enumerated through the connected integration.

#### A — all 43 behind-only candidates rechecked against current main

Each current branch ref was compared individually against exact current `main` SHA `2e11497aa43210cb28ffdf43b16ff6a347613e48`. All 43 returned `status=behind`, `ahead_by=0`, and zero changed files. The live refs all exist.

| Candidate branch | Behind |
|---|---:|
| `art/faction-equipment-silhouette-pass` | 42 |
| `combat/player-skills-enemy-ai` | 1115 |
| `docs/update-phase-11-integration-status` | 192 |
| `feat/blacksmith-forge` | 512 |
| `feat/character-animation-pass` | 1023 |
| `feat/frontier-world-generation-mainline` | 929 |
| `feat/healer-infirmary` | 529 |
| `feat/hunter-hunting-lodge` | 662 |
| `feat/multi-stronghold-campaign` | 922 |
| `feat/phase-05-resource-worksites` | 895 |
| `feat/phase-06-factions-territorial-ai-rebased` | 863 |
| `feat/phase-06-shieldbearer-brace` | 810 |
| `feat/phase-06.4-faction-raids` | 756 |
| `feat/phase-06.5-faction-warfare-stress` | 744 |
| `feat/phase-07-conquest-objectives-mainline` | 860 |
| `feat/phase-09-balance-performance-release-mainline` | 857 |
| `feat/phase-10-adaptive-viewport-mainline` | 854 |
| `feat/regional-control-roads-mainline` | 930 |
| `feat/responsive-resolution-visual-pass` | 1034 |
| `feat/rival-local-depots-road-delivery` | 55 |
| `feat/scout-specialist` | 590 |
| `feat/strategic-map-stage-hud` | 1072 |
| `feat/workplaces-and-specialist-jobs` | 923 |
| `fix/ci-regression-test-timeouts` | 974 |
| `fix/hud-discovered-type` | 1113 |
| `fix/rival-worker-cargo-conservation` | 132 |
| `integrate/data-db-validation-mainline` | 482 |
| `overhaul/territory-expansion` | 1143 |
| `qa/desktop-export-acceptance` | 246 |
| `qa/headed-mode-source-export` | 49 |
| `work/dev-b-faction-ai-components` | 488 |
| `work/dev-c-autonomous-wave-diagnostic-integrated` | 379 |
| `work/dev-c-campaign-simulation` | 487 |
| `work/dev-d-supply-network-decomposition` | 469 |
| `work/dev-e-save-validator-mainline` | 449 |
| `work/dev-e-sequential-migration-pipeline-current-main` | 434 |
| `work/dev-g-hud-widget-modules` | 403 |
| `work/dev-h-world-generation` | 444 |
| `work/dev-i-enemy-patrol-controller` | 477 |
| `work/dev-j-decision-events` | 472 |
| `work/dev-k-input-command-registry` | 457 |
| `work/dev-l-archery-range-ranged-training` | 416 |
| `work/dev-l-barracks-garrison` | 443 |

The previous audited main `3e2e0e4cfc609df5e2c4376b868c6491578e9fbc` is an ancestor of current main: compare returned `ahead_by=0`, `behind_by=4`, merge base equal to that SHA, and no changed files. The direct 43-branch comparison above independently confirms all candidate tips remain contained.

**Deletion remains blocked.** The connected GitHub tool catalogue has no branch-delete or delete-ref operation. `update_ref` only moves a ref and was not used. No branch was deleted or modified. The open-PR and active-workflow checks are clean for these candidates, but external consumer references remain unenumerable; deletion is not approved.

#### B — bounded audit of six previously unlisted diverged branches

All six branch tips were compared against exact main SHA `2e11497aa43210cb28ffdf43b16ff6a347613e48`. Branch-qualified PR searches returned #126/#127 for the night-countdown pair and no matching PR records for the other four. The repository-wide active/queued workflow queries returned zero. All six tips are distinct.

| Branch | Tip | Ahead / behind | Changed paths | Disposition |
|---|---|---:|---:|---|
| `feat/night-wave-countdown-hud` | `957f7d5c8ac7f6bd47334aa36d9e1aab8544e11d` | 6 / 384 | 6 | **superseded** |
| `feat/night-wave-countdown-hud-mainline` | `5bcfc3e92501a2a7d5e89ce2b7dc22edeb96342a` | 13 / 382 | 7 | **superseded** |
| `feat/phase-08-visual-audio-identity` | `7fe94c11debbe8113b1c42bf07fc6268cd3a6dd6` | 27 / 897 | 20 | **retain** |
| `feat/phase-08-visual-audio-identity-mainline` | `d7322c33ccf8016ab4433e995936becfda8f741a` | 7 / 742 | 7 | **retain** |
| `feat/phase-09-balance-performance-release-rebased` | `0d1900f8ea4e4ba9c2bc522b5fc8c8b981dab931` | 70 / 897 | 36 | **retain** |
| `feat/phase-09-balance-performance-release-v2` | `85da49ed4f06a21e14a4c0ecf3123a34bf9e941b` | 111 / 897 | 42 | **retain** |

Night-countdown evidence:
- PR #126 is closed and unmerged; its exact head is `957f7d5c8ac7f6bd47334aa36d9e1aab8544e11d`. PR #127 is closed and unmerged; its exact head is `5bcfc3e92501a2a7d5e89ce2b7dc22edeb96342a`.
- The two branches are not duplicate tips. Pairwise compare returned 15 commits ahead / 6 behind and 14 changed paths. Of their six common changed files, only `scripts/autoload/game_clock.gd` has the same blob on both branches; the other five blobs differ. Neither branch is an exact patch duplicate of the other or of main.
- Current main contains the phase countdown through `GameClock.seconds_until_phase_change()`, the `ClockWidget.countdown_text()` and tooltip, the second clock row, queued-wave count, and countdown assertions in `campaign_balance_matrix.gd` and `responsive_layout.gd`. Main's current implementation is later and stronger: it avoids floating-point extra-second display and includes a pending boss in `remaining_wave_spawns()`. Main's Frontier campaign simulation also has additional live-wave safeguards compared with the branch version.
- Current-main file blobs differ from both branch versions, so this is a functional supersession finding, not a claim of byte-for-byte patch identity. Both closed PRs are unmerged; no branch integration is needed.

Phase-08 visual/audio pair:
- Pairwise compare returned 162 commits ahead / 27 behind and 75 changed paths. There is no duplicate tip and no exact patch equivalence established.
- The `-mainline` branch's seven changed paths were blob-compared against main; all seven blobs differ. The broader branch has 27 unique commits and 20 changed paths. These patches include Frontier visual/map, faction/enemy and documentation surfaces. Their complete unique hunks have not been reviewed against current production code.
- Disposition is **retain** for both, not integrate or delete. Godot 4.7 exact-head validation has not been verified for either branch.

Phase-09 release/balance pair:
- Pairwise compare returned 43 commits ahead / 2 behind and 16 changed paths. No duplicate tip and no exact patch equivalence established.
- The rebased branch has 70 unique commits and 36 changed paths; v2 has 111 unique commits and 42 changed paths. Both overlap the old balance/performance/release family and are 897 commits behind current main.
- Disposition is **retain** for both pending complete patch comparison. No integration or Godot 4.7 validation is approved.

No branch was integrated, deleted, or modified in this batch.

#### C — six open PRs refreshed

All six remain open and draft. No PR was merged or closed.

| PR | Head SHA | Mergeable | Reviews | Exact-head workflow snapshot | Decision |
|---|---|---|---|---|---|
| #212 | `6d0ce0f69c4775412f0c9dcbe55fc80bbc1a9d1c` | true | 1 COMMENTED, no approval | Godot CI and all six relevant visual/diagnostic workflows succeeded | Hold for normal-speed desktop combat readability acceptance |
| #213 | `c336f7923e9b522898bd778f311c0382bf68d4d2` | false | 3 COMMENTED, no approval | Godot CI, Campaign Simulation, Building Visual and Pixel FX Readability succeeded | Hold for shared damage-path reconciliation with #212 |
| #210 | `c1c87dbb6b01dcfb9e3d7aae5c19d70db5ccd541` | false | 1 COMMENTED, no approval | Godot CI, Campaign Simulation, Builder Reachability and Role Sprite Visual succeeded | Hold for live multi-frame civilian work-cycle acceptance after shared villager changes are understood |
| #214 | `23f53abd0698e0ce482def8d9b8ce9c8e1913a8f` | false | No new approval | Godot CI succeeded | Park draft until actual Acer Aspire One A0756 measurements are attached |
| #150 | `1d2e29063881f6060f08e3ca3e98202196e55531` | false | No new approval | Godot CI cancelled | Park; Android deferred |
| #152 | `a405e8f92f1d9df5ebbea0b18a582ab4a073be15` | false | No new approval | Godot CI and Campaign Simulation succeeded | Park; Android deferred |

#212's latest metadata now reports `mergeable=true` (an earlier read reported false); this does not remove its draft state, COMMENTED-only review, or missing normal-speed desktop acceptance. #213 and #210 remain non-mergeable. No merge is authorized.

#### D — main protection, pointer, and CI

- Main remains unprotected (`protected=false`).
- Rulesets GET returned `[]`.
- Branch-protection GET returned HTTP 403, `Resource not accessible by integration`.
- The connected GitHub tool catalogue exposes no branch-protection or ruleset write operation. Repository metadata reports admin permission, but that does not grant the integration the missing endpoint capability.
- `worklist.md` still links to `docs/REPOSITORY_CLEANUP_CHECKPOINT.md`. Its date is advanced to 2026-11-27 in the accompanying pointer update.
- Exact-main Godot CI run [#45738796676](https://github.com/shimleabyte/hold-the-keep/actions/runs/45738796676) completed successfully on exact SHA `2e11497aa43210cb28ffdf43b16ff6a347613e48` (2026-11-26 01:53:47 UTC). Combined commit statuses are empty; the successful Actions run is the CI evidence.

**A–D remain incomplete.** All 43 behind-only candidates are contained, but no genuine branch-delete operation exists and external references cannot be exhaustively enumerated. The diverged inventory is still incomplete. #212 lacks desktop acceptance; #213 and #210 remain gated; #214 and Android PRs remain parked. Main protection is not enabled. Stage E remains locked.


### Autonomous cleanup pass — 2026-11-28

**Live repository snapshot before this checkpoint append**
- Default branch: `main`, exact SHA `89a2d04e3b27bd3c9082cc35a1a72ab79352715d`.
- Live branch inventory: 170 branches (100 on page 1, 70 on page 2).
- All 43 recorded behind-only candidates remain present.
- The previous exact comparison of all 43 candidates against `2e11497aa43210cb28ffdf43b16ff6a347613e48` returned `ahead_by=0` and zero changed files for every candidate. A fresh comparison from that SHA to current main returned `ahead_by=2`, `behind_by=0`, with only `docs/REPOSITORY_CLEANUP_CHECKPOINT.md` and `worklist.md` changed. Therefore all 43 candidate tips remain contained in current main.
- Six PRs remain open; none has one of the 43 candidate branches as its head.
- Repository-wide Actions queries returned zero `in_progress` and zero `queued` runs.
- Duplicate-tip scan found only the two previously known groups: `feat/phase-09.3-late-act-reload-hardening` / `feat/phase-09.3-reload-acceptance` at `c8719082f95d362e62b8a04f5c3d9ca2959da2c4`, and `work/dev-h-frontier-rendered-repeatability` / `work/dev-h-frontier-rendered-repeatability-final` at `65f852d6d923066ad38d2eb360e7299b949f20ff`. No new duplicate-tip group was found.
- External deployment, webhook, and other consumer references remain outside the connected integration's exhaustive visibility.

#### A — behind-only candidates

All 43 tips remain fully contained by the ancestry chain above. No current open PR head or active/queued workflow references a candidate. External consumer references cannot be exhaustively enumerated. No branch was deleted or modified.

**Deletion blocker remains exact:** the connected GitHub tool catalogue exposes no genuine branch-delete/delete-ref operation. `update_ref` only moves a ref and was not used to imitate deletion. All 43 branches remain intact.

#### B — diverged-branch audit, bounded batch of ten previously unclassified branches

All comparisons below use current main SHA `89a2d04e3b27bd3c9082cc35a1a72ab79352715d`. Branch-qualified PR-history searches returned no direct PR for these branches. The six currently open PR heads were separately enumerated. No integration or deletion was performed.

| Branch | Tip | Ahead / behind | Changed paths | Disposition |
|---|---|---:|---:|---|
| `feat/android-armv7-touch-controls-mainline` | `84d08dee80b70fd88e4608b8c02d1b68fb12a2f7` | 1 / 375 | 10 | **superseded** |
| `feat/phase-09-balance-performance-release-v3` | `ab05ce93d96cf6dd430e8e74f4b98cba2a74e79d` | 91 / 899 | 46 | **retain** |
| `feat/phase-09-balance-performance-release-v4` | `4acb673da1a2b6ffca58d9982cc0130af1b1e8cc` | 100 / 899 | 49 | **retain** |
| `feat/phase-09-balance-performance-release-v5` | `3bdd7b7e60a75cdb3bd1bfc69a22727b3831be3b` | 110 / 899 | 49 | **retain** |
| `fix/android-touch-controls-safety` | `50c4a9fe505913d08fe24b1e1d1a955132fe7cf9` | 12 / 375 | 10 | **superseded** |
| `fix/android-touch-controls-safety-mainline` | `30b3565ec4fd76a85dfc6fabe54cf01c36a1c2d0` | 1 / 374 | 11 | **retain** |
| `fix/hud-partial-quota-guards` | `5ac5aaf73da4eb1bb35d0505b9b0bd22bf95df71` | 2 / 261 | 2 | **superseded** |
| `fix/nav-grid-multi-cell-access` | `00eca2edf23ecd7daddf581264b252a07b44c176` | 54 / 291 | 19 | **retain** |
| `fix/p0-gameplay-fairness-current-main` | `4e2ecc4d780271887bec58f6ec30bb7d72eccf11` | 6 / 387 | 6 | **retain** |
| `work/dev-d-supply-road-graph` | `aae7859569d5f82768d5832fcd6978d0181cad89` | 2 / 409 | 2 | **superseded** |

Evidence and disposition reasoning:

- Phase-09 v3/v4/v5 are not duplicate tips or exact patch equivalents. Pairwise comparisons returned v3→v4 = 24 ahead / 15 behind, v4→v5 = 30 ahead / 20 behind, and v3→v5 = 34 ahead / 15 behind. They overlap the historical balance/performance/release implementation and test surface, but have distinct unique commits and different file contents. Retain all three pending complete unique-hunk review; no direct integration is approved.
- `feat/android-armv7-touch-controls-mainline` has the same blobs for its ten Android implementation/workflow paths as the Android implementation on PR #152's separate `feat/android-armv7-touch-controls-current-main` head. The PR head has 130 unique commits relative to this branch and is one commit behind it. The older branch adds no distinct Android code beyond the parked PR head; classify this branch as superseded by the #152 head. PR #152 itself remains open/draft and parked because Android is deferred.
- `fix/android-touch-controls-safety` and `fix/android-touch-controls-safety-mainline` have identical blobs across the ten Android implementation/workflow paths. Their pairwise history differs (12 ahead / 2 behind); the mainline variant also carries a worklist snapshot. Treat the older safety branch as superseded by the mainline variant. Retain `fix/android-touch-controls-safety-mainline` as a separate hardened Android candidate: its touch-control implementation is 394 lines and its regression test is 265 lines, covering touch lifecycle, multi-touch and safe-area geometry. Android remains deferred; no exact-head Godot 4.7 validation or merge is approved.
- `fix/hud-partial-quota-guards` changes only `scripts/ui/hud.gd` and `tests/workplace_assignments.gd`. Current main already uses `quota.get(j, 0)` for absent role quotas and includes the same partial-quota setup/restore regression sequence. The branch's remaining difference in the test is explanatory wording; its functional patch is superseded by main.
- `work/dev-d-supply-road-graph` changes `scripts/systems/supply_network.gd` and `scripts/systems/supply_road_graph.gd`. The latter is byte-identical to current main (blob `35e042c0c9cfcbd468c6f44a569da3c8f4d16f4f`); main's supply-network façade delegates the same rebuild, invalidation, connectivity and depot-count operations to that module. Main has since decomposed additional supply responsibilities, so this older two-commit extraction is superseded.
- `fix/nav-grid-multi-cell-access` has 54 unique commits across 19 paths, including NavGrid, FlowField, world-map, faction assault and performance/regression tests. No PR or exact patch-equivalent branch was found. Retain pending full source review and exact-head Godot 4.7 validation; do not integrate a broad 54-commit patch without that review.
- `fix/p0-gameplay-fairness-current-main` has six unique commits across README, GameClock, player combat, campaign and combat tests. It overlaps `fix/p0-combat-fairness-and-wave-telegraph` and `fix/p0-gameplay-ux-combined`, but pairwise comparisons show distinct histories and changed-file sets. Retain pending exact patch review; do not combine it with #212/#213 work.
- No branch in this batch was integrated, deleted, or modified.

#### C — PR #212 refreshed first

- PR #212 remains open and draft. Exact head: `6d0ce0f69c4775412f0c9dcbe55fc80bbc1a9d1c`; recorded base SHA: `d6a54036f7d7587c6e4cbd7188a620a6f9bc9d19`; 14 changed files.
- Current REST metadata reports `mergeable=null` and `mergeable_state=unknown`; do not rely on the earlier `mergeable=true` read as current.
- Review history still contains only the COMMENTED review `5969321353`; no approval exists. No new issue comments were returned.
- All seven exact-head runs remain successful: Godot CI #42742842633; Battlefield Combat Visual QA #42742842502; Building Visual QA #42742842653; Campaign Simulation QA #42742842817; Builder Reachability QA #42742842505; Autonomous Wave Diagnostic #42742842641; Role Sprite Visual QA #42742842469.
- Decision remains **hold**. Normal-speed desktop combat readability acceptance is still missing. Do not merge.
- #213 and #210 remain in the documented second/third order with their previously recorded shared-damage-path and live work-cycle gates. #214 remains parked pending actual Acer Aspire One A0756 measurements. #150 and #152 remain parked because Android is deferred. No PR was merged or closed.

#### D — protection, worklist pointer and exact-main CI

- Current main branch listing reports `protected=false`; rulesets GET returns `[]`. Branch-protection GET remains blocked by HTTP 403, `Resource not accessible by integration`; the connected tool catalogue exposes no protection/ruleset write operation.
- `worklist.md` still points to this authoritative checkpoint. Its pointer date remains 2026-11-27; no pointer change was necessary because the link is correct.
- Exact-main Godot CI run [#45924913426](https://github.com/shimleabyte/hold-the-keep/actions/runs/45924913426) completed successfully on SHA `89a2d04e3b27bd3c9082cc35a1a72ab79352715d` (push event, 2026-11-27 01:51:02 UTC). This is the verified code baseline before this documentation append; it is not a CI result for the new checkpoint commit.

**A–D remain incomplete.** Branch deletion is unavailable and external references cannot be exhaustively enumerated. The full diverged inventory still needs disposition. #212 lacks visual acceptance; #213 and #210 remain gated; #214 and Android PRs remain parked. Main protection is not enabled. Stage E remains locked.
