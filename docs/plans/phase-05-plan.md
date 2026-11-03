# Phase 05 — Construction System and Building Production Chains

**Status:** Lumber Camp/Quarry worksite slice, Phase 05.2a Builder-driven blueprint sites (PR #58), Phase 05.2b queue/Builder priorities (PR #59), Phase 05.3a Watchtower vision (PR #60, `beef7b7`), and Phase 05.3b Granary food reserve (PR #61, `d9b87b1`) are merged. Workflow #41558978053 passed 84/84 jobs on Godot 4.3/4.7, Frontier performance diagnostic and Windows/Linux exports. Rendered building/HUD review, balance and remaining facility chain remain open.
**Dependency:** Phase 04 Builder occupation; Phase 02 depot/logistics rules.
**Engine targets:** Godot 4.3 and 4.7.

## Goal

Make building placement a managed construction process. Builder labor must matter, construction sites must be readable, and each facility must have a distinct production, defense or campaign function.

## 05.2a — Builder-driven blueprint sites (merged via PR #58)
- Clicking a valid building footprint debits the currently selected depot once and creates a non-functional blueprint site.
- Builder workers claim reachable sites within their assigned Keep/Outpost workplace radius, travel to the footprint and contribute active work.
- A maximum of two Builders can work one site; the second worker contributes 65% additional throughput. Idle, travelling, invalid or absent workers do not advance progress.
- Completion atomically replaces the site with the normal building and registers its footprint, collision, groups and existing building events.
- Right-click cancellation refunds the unconsumed cost to the original depot; missing/full remote depots fall back to Keep Inventory.
- Save v13 stores site ID, footprint, progress, required work and funding source as an optional additive field. Older v13 saves without construction-site records remain valid.
- Regression `tests/construction_sites.gd` covers Builder pathing/work, the worker cap, one-time payment, completion, proportional cancellation, save validation and reload. It is registered in both engine matrices.
- This slice does not yet provide a dedicated queue panel, manual reordering or multiple project priority controls.

## 05.2b — Construction queue (merged via PR #59)
- Add a player-facing queue with explicit order, cost, placement validation and cancel/reorder behavior.
- [x] Every accepted project pays its full cost once from the selected allowed depot; invalid placement is rejected before payment and does not reserve materials.
- [x] Queue panel displays up to 64 funded blueprints, current order, paid material costs, live work progress and one-step raise/lower controls.
- [x] Reordering changes actual Builder target priority; reachable projects are considered in queue order before repair work.
- [x] Cancel control and right-click both release the footprint and refund only unconsumed materials to the source depot/Keep fallback.
- [x] Queue order is persisted in save v13; legacy v13 site records without `queue_order` keep their saved array order.
- Builders claim one active site at a time, work only within their workplace radius and use bounded pathfinding.
- Multiple Builders may accelerate one site only with a documented diminishing-return/cap rule; they must not duplicate progress.
- Construction advances on valid work ticks, not every idle frame, and pauses cleanly when blocked, starved or outside working conditions.
- Completed sites become their final building atomically, receive full collision/occupancy registration and emit the normal building-created events.
- [x] Save/load persists queue order alongside footprint, progress and funding source; Builder claims are transient and safely re-discovered after load.
- [x] Cancellation refunds only unconsumed materials according to a fixed documented rule; completed/cancelled sites release their queue slots without duplication.

## 05.3a — Watchtower vision (merged via PR #60)
- The existing `tower` remains the defensive turret; no duplicate building ID or new save field is introduced.
- Data definition adds a 128px `vision_radius`. The fog scanner permanently discovers terrain inside this radius.
- The strategic map uses the same radius for current enemy observation, so enemy markers appear only while the tower remains alive and within sight range.
- Keep and Outpost reveal behavior is preserved. Discovered terrain remains mapped after tower demolition, while live observation immediately ends.
- Regression `tests/watchtower_vision.gd` covers unseen-before/build, inner/outer radius, strategic-map observation, permanent discovery after demolition and unchanged turret stats.

## 05.3b — Granary food reserve (merged via PR #61)
- Existing `granary` research now unlocks the `granary` building while retaining its +1 farmer slot per farm effect.
- Granary is a 3×2, 240-capacity local depot that accepts food only. It cannot be selected as a construction/research cost source.
- Farmers prioritize a reachable Granary for food. In Classic, upkeep and population growth consume central Inventory first and then the Granary reserve; the HUD displays that combined usable amount. In Frontier, connected Granary stock transfers to Keep under the existing per-depot logistics budget and can be shipped by carrier.
- Granaries participate in isolated-depot pressure and both saboteur/faction raids. Demolition returns its food to central Inventory; destruction remains a loss.
- Save v13 persists stockpiles with per-building accepted-resource validation; shipment creation and save validation reject non-food cargo destined for a Granary. Existing v13 saves without Granaries remain compatible.
- Regression `tests/granary_food_storage.gd` covers Classic upkeep and reload, Frontier transfers/shipments/raids, invalid resource payloads, and pressure-state persistence.

## 05.3 — Facility dependency order
1. [x] Watchtower vision: the existing tower gains local vision and retains its defensive coverage; no duplicate structure is shipped.
2. [x] Granary food reserve: 240-capacity food-only depot, Classic reserve/upkeep, Frontier transfers/shipments/raids and v13 save validation (PR #61 merged as `d9b87b1`; workflow #41558978053 passed 84/84).
3. Barracks: recruits/trains soldiers through time and resource costs; must respect population and capacity.
4. Hunting Lodge: provides Hunter workplace slots and access to wildlife harvest.
5. Infirmary: provides Healer workplace slots and recovery service.
6. Archery Range: unlocks or trains ranged defenders with explicit ammunition/cost rules.
7. Bridge/Gate upgrades: tactical access control without making road/bridge traversal ambiguous.
8. Market: deterministic conversion/trade between defined resources; no passive resource generation.
9. Siege Workshop: produces capped siege equipment with transport/deployment rules.
10. Stables: enables Beast Rider/cavalry recruitment only when its faction/counter system exists.
11. Fortress and Signal Beacon: late-game regional defense, command/visibility and campaign effects.

## Design constraints
- Every building needs data definition, footprint, valid terrain/claim rules, cost, health, art, UI/hotkey, unlock dependency, save coverage and a distinct gameplay purpose.
- Add new resources only with at least one producer, one consumer and a UI/save path.
- Avoid implementing all candidate buildings in one batch; merge one coherent dependency group at a time.
- Keep Classic building behavior stable unless a separately tested Classic balance change is intentional.

## Acceptance gate
- Construction consumes and refunds resources without duplication.
- Builder pathing/claims remain bounded and recover from invalid sites.
- Incomplete sites are visibly distinct and cannot provide finished-building behavior.
- Queue, site and worker state survive save/load and legacy migration.
- Each shipped facility has an automated regression test and rendered gameplay review.