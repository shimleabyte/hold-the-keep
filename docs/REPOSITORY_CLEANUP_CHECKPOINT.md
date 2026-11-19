# Repository Cleanup Checkpoint

**Checkpoint date:** 2026-11-19  
**Default branch:** `main`  
**Verified main SHA:** `d6a54036f7d7587c6e4cbd7188a620a6f9bc9d19`  
**Previous main commit date:** 2026-11-10 02:22:37 UTC  
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
