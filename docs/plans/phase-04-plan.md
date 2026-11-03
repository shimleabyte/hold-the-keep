# Phase 04 — Specialist Jobs and Workplace Completion

**Status:** Builder and first workplace/repair slice merged into `main`. Hunter is implemented in open PR #64; Scout is implemented in open stacked PR #65. Both require final Godot 4.7 CI and in-game acceptance before integration. Healer and Blacksmith remain unimplemented.
**Dependency:** Phase 02 connected depots; Phase 05 worksites and construction foundations.
**Engine target:** Godot 4.7 only.

## Goal

Expand labor roles only when they create a distinct economic or tactical output. Every job must have explicit assignment rules, workplace capacity/radius, pathfinding limits, costs/yields, UI controls and save behavior.

## Specialist slices

### Hunter
- Hunt designated wildlife/resource nodes within an assigned work radius; do not add an unbounded animal population simulation.
- Deliver food to a reachable depot and respect local storage capacity once Phase 02 local stockpiles are enabled.
- Use bounded spawn/respawn rules and clear depletion/return behavior.

### Scout
- Reveal fog within a bounded observation radius and optionally mark discovered hostile sites/camps.
- Avoid granting global enemy tracking; visibility must remain observation-based.
- Support a distinct exploration assignment and return/idle behavior when no unexplored reachable cells remain.

### Healer
- Prioritize damaged friendly soldiers/guards within a workplace or Outpost service radius.
- Consume a defined medical resource only once such a resource has a real source/consumer chain; otherwise use a documented cooldown/limited charge model.
- Respect combat safety, path reachability and target reservation to prevent multiple healers wasting work on the same target.

### Blacksmith
- Operate from a Forge/Blacksmith workplace and consume Iron plus a defined secondary resource for a concrete output.
- Begin with a small equipment/repair output that has an observable effect on soldier or structure stats.
- Do not introduce gold, leather, coal or additional resources until a gameplay system consumes them.

## Shared requirements
- Keep labor occupation separate from military specialization; soldier assignment must not be overwritten by a labor job change.
- Preserve job priority, Alt hotkeys and panel controls. Add readable capacity and assignment feedback.
- Limit each job's search radius and scan cadence; avoid whole-map per-frame scans.
- Handle blocked paths, destroyed workplaces, full storage, depleted resources and save/load recovery.
- Persist occupation, workplace identity, job-specific progress and assignments with migration defaults.

## Regression and acceptance
- Each job has a focused assertion test plus one integration scenario.
- Test priority/reassignment, capacity, work radius, unreachable targets, target reservation, output delivery and save/load.
- Classic existing jobs and save compatibility remain unchanged.
- Mark a specialist complete only after a player-facing UI path and rendered review exist, not merely after the class/enum is registered.