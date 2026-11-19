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
