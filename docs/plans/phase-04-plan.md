# Phase 04 — Specialist Jobs and Workplace Completion

**Status:** Builder, Hunter (#64), Scout (#65), Healer (#67) and Blacksmith/Forge (#68) are merged into `main` in dependency order. Their Godot 4.7 workflows passed 45/45 (#620), 46/46 (#621), 47/47 (#626) and 48/48 (#635). Rendered gameplay, readability, economic pacing and balance acceptance remain manual.
**Dependency:** Phase 02 connected depots; Phase 05 worksites and construction foundations.
**Engine target:** Godot 4.7 only.

## Goal

Expand labor roles only when they create a distinct economic or tactical output. Every job must have explicit assignment rules, workplace capacity/radius, pathfinding limits, costs/yields, UI controls and save behavior.

## Specialist slices

### Hunter — merged via PR #64
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

### Villager Scout — merged via PR #65
- Add a two-slot Scout Post as the explicit workplace; Scouts cannot be assigned without a reachable free slot.
- Use a bounded A* survey loop around the assigned post. Select only reachable walkable destinations with unexplored cells nearby; rotate sectors and avoid duplicating another Scout's active destination.
- Reveal terrain through the existing permanent fog system with a 144px Scout sight radius. Do not add global enemy tracking or reveal enemies outside existing observation rules.
- Return to the Scout Post when no unexplored reachable survey cells remain; periodically re-check so newly opened routes can be explored later.
- Add Scout as a distinct occupation, U hotkey, quota/priority row, role sprite, Scout Post art/icon and player-facing controls.
- Bump save schema to v15 for the Scout quota/priority/occupation and new building ID; preserve Classic v1–v14 and Frontier v7–v14 migration.
- Add focused tests for workplace requirement/capacity, reachable target selection, fog reveal radius, bounded behavior, survey completion/return, two-Scout target separation and save migration.
- [ ] Rendered pathing, discovery pace and actual map-scale playtest.

### Healer — merged via PR #67
- [x] Prioritize the most damaged reachable friendly soldier within the Infirmary service radius.
- [x] Unlock the two-slot Infirmary through Era II Field Medicine after Leather Armor; do not add a new resource.
- [x] Use a 16-tile service radius, one-Healer-per-patient reservation, 10 HP per 3.2 seconds, and stop at full HP or on patient/workplace loss.

- [x] Add Healer occupation, I quota/priority shortcut, sprite/HUD, Infirmary artwork and save schema v16.
- [x] Add `tests/healer_infirmary.gd` for tech unlock, capacity, targeting, unique reservation, healing clamp, teardown and v15 migration; CI #626 passed 47/47 jobs.

### Blacksmith — merged via PR #68
- [x] Use the existing Era III Forge as the workplace with two Blacksmith slots and an 18-tile service radius; no duplicate building or resource is introduced.
- [x] Require existing Iron Weapons/Iron Armor research before the corresponding recipe becomes available.
- [x] Craft individual Iron Weapons (3 iron + 1 wood, +20% soldier damage) and Iron Armor (4 iron + 2 wood, +20% soldier maximum HP); one of each per soldier.
- [x] Reserve each soldier to one Blacksmith at a time; exclude expeditioning, recalling, hidden, fleeing and fighting soldiers.
- [x] Release target reservations on completion, invalidation, Forge sabotage and Forge demolition.
- [x] Add a Blacksmith job row in JOBS without consuming an existing keyboard shortcut; use the Forge icon and a distinct role sprite.
- [x] Persist equipment flags and Blacksmith occupation in save v17, including restoration of armored soldier HP caps; retain v1–v16 Classic and v7–v16 Frontier migration.
- [x] Add `tests/blacksmith_forge.gd` covering two-slot capacity, unique reservations, recipe costs/effects, save migration and workplace teardown.
- [x] Validate full Godot 4.7 CI: run #635 passed 48/48 jobs, including the dedicated Blacksmith regression and v1–v17/v7–v17 migration coverage.
- [ ] Review rendered equipment visibility, combat balance and economic pacing in an actual playthrough.

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

### Healer + Infirmary integration (2026-11-03)
- Merged into `main` through PR #67 (`bf44703`), after PR #64 Hunter and PR #65 Scout.
- Era II `field_medicine` unlocks a two-slot Infirmary (16-tile service radius) and a player Healer occupation assigned with I.
- Healers prioritize the most wounded reachable friendly soldier. A patient is reserved by one Healer at a time. Treatment restores 10 HP per 3.2 seconds and stops at full health; invalid patients and lost workplaces release reservations.
- Save schema increments to v16. v1–v15 migration compatibility remains required.
- `tests/healer_infirmary.gd` covers workplace requirement/capacity, patient selection, target uniqueness, healing, demolition cleanup and v15 migration. Godot 4.7 CI #626 passed 47/47; rendered treatment feedback and balance review remain manual.


### Blacksmith / Forge integration (2026-11-03)
- Merged into `main` through PR #68 (`1b15f37`) on top of Healer/Infirmary PR #67.
- Healer CI #626 passed 47/47 jobs on Godot 4.7 before this slice started.
- Blacksmith adds no new technology node: existing `iron_weapons` and `iron_armor` gate the respective permanent individual recipes. This behavior is now integrated in `main`.
- Equipment is stored per soldier; reassignment away from soldier removes the equipment state so non-soldier HP is not corrupted. Godot 4.7 CI #635 passed 48/48, including migration and equipment regression coverage.
