# Phase 04 — Specialist Jobs and Workplace Completion

**Status:** Builder is merged into `main`; Hunter + Hunting Lodge is on `feat/hunter-hunting-lodge` pending final CI/PR acceptance. Villager Scout + Scout Post is in progress on the stacked branch `feat/scout-specialist`; Healer and Blacksmith remain open.
**Dependency:** Phase 02 connected depots; Phase 05 worksites and construction foundations.
**Engine target:** Godot 4.7 only.

## Goal

Expand labor roles only when they create a distinct economic or tactical output. Every job must have explicit assignment rules, workplace capacity/radius, pathfinding limits, costs/yields, UI controls and save behavior.

## Specialist slices

### Hunter — implemented on `feat/hunter-hunting-lodge`
- [x] Require a free Hunter slot in a Hunting Lodge; reject assignment when no matching workplace is available.
- [x] Generate finite, deterministic wildlife nodes outside the protected clearing; Frontier herds favour Greenwood and Fenlands.
- [x] Enforce the Lodge work radius and reserve each wildlife target to one worker.
- [x] Deliver food through connected depot rules, with Granary priority and local stockpile validation preserved.
- [x] Harvest three strikes per animal for five food, then regrow the node after 105 seconds.
- [x] Persist Hunter occupation and wildlife HP/regrowth in additive save v14; retain v1–v13 validation.
- [x] Add a sixth job row, J hotkey, priority control, job icon, Hunter sprite and Hunting Lodge art.
- [x] Add focused workplace/food/save tests and deterministic Frontier wildlife placement coverage.
- [ ] Review rendered art, pathing and hunting/farming balance in a real playthrough.

### Enemy Scout archetype — already implemented separately
- The enemy Scout/marking archetype is a combat AI behavior on `main`; it is not the villager Scout occupation described below.
- Its existing mark publication is faction-bounded and observation-based. The new villager role must not inherit global enemy tracking.

### Villager Scout — in progress on `feat/scout-specialist`
- Add a two-slot Scout Post as the explicit workplace; Scouts cannot be assigned without a reachable free slot.
- Use a bounded A* survey loop around the assigned post. Select only reachable walkable destinations with unexplored cells nearby; rotate sectors and avoid duplicating another Scout's active destination.
- Reveal terrain through the existing permanent fog system with a 144px Scout sight radius. Do not add global enemy tracking or reveal enemies outside existing observation rules.
- Return to the Scout Post when no unexplored reachable survey cells remain; periodically re-check so newly opened routes can be explored later.
- Add Scout as a distinct occupation, U hotkey, quota/priority row, role sprite, Scout Post art/icon and player-facing controls.
- Bump save schema to v15 for the Scout quota/priority/occupation and new building ID; preserve Classic v1–v14 and Frontier v7–v14 migration.
- Add focused tests for workplace requirement/capacity, reachable target selection, fog reveal radius, bounded behavior, survey completion/return, two-Scout target separation and save migration.
- [ ] Rendered pathing, discovery pace and actual map-scale playtest.

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

### Healer + Infirmary implementation branch (2026-11-03)
- Branch: `feat/healer-infirmary`, stacked after `feat/scout-specialist`.
- Era II `field_medicine` unlocks a two-slot Infirmary (16-tile service radius) and a player Healer occupation assigned with I.
- Healers prioritize the most wounded reachable friendly soldier. A patient is reserved by one Healer at a time. Treatment restores 10 HP per 3.2 seconds and stops at full health; invalid patients and lost workplaces release reservations.
- Save schema increments to v16. v1–v15 migration compatibility remains required.
- `tests/healer_infirmary.gd` covers workplace requirement/capacity, patient selection, target uniqueness, healing, demolition cleanup and v15 migration. Full Godot 4.7 CI and rendered gameplay review remain pending.
