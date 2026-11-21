# Repository Cleanup Checkpoint

**Checkpoint date:** 2026-11-21  
**Default branch:** `main`  
**Verified main SHA:** `5c846c91557c6e2a6a3604c67bb9679fb0559baa`  
**Previous main commit date:** 2026-11-20 01:48:48 UTC  
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

**Deletion remains blocked.** The connected GitHub tool inventory still exposes no genuine branch-delete operation. \`update_ref\` only moves a ref and is not deletion; it was not used. The reference checks above cover PR history for the new batch, the current open-PR inventory, branch-specific Actions activity, and duplicate branch tips. They do not prove the absence of every possible external deployment or consumer reference. No branch was deleted. Twenty-seven of the 43 recorded candidates remain to be revalidated.

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

- A: revalidate the remaining 27 recorded behind-only candidates against a freshly read main; repeat PR/workflow/reference checks; retain branches until genuine deletion is available.
- B: continue bounded, complete dispositions for the remaining diverged branches. Do not convert provisional superseded candidates into final dispositions without unique-commit and patch-equivalence evidence.
- C: keep #212 first, #213 second, #210 third; resolve only after review, exact-head Godot 4.7 checks, rendered acceptance, and conflict reconciliation. Keep #214 and Android PRs parked.
- D: establish actual branch protection/rulesets through a capability that has the required administration permission. Do not mark protection enabled based on repository admin metadata alone.

A–D remain incomplete. Stage E has not started.
