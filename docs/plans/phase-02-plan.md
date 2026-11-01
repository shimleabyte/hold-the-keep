# Phase 02 — Local Logistics and Outpost Support

**Status:** Partial implementation. Regional ownership, roads/bridges, Keep-rooted connectivity, local Storage/Outpost stockpiles, Frontier deposits and bounded automatic shipments to Keep are merged into `main` through PR #31 with save v12. PR #32 is merged into `main` and adds read-only depot inspection, Outpost guard slots/assignment, local defense leash, lifecycle handling and save/load persistence. Its Godot 4.3/4.7 CI passed 48/48 jobs. Outpost-local visibility and currently-observed enemy map markers already exist in `main` and are not new work. PR #33 is merged into `main` and delivers manual Keep/Storage/Outpost shipments with physical carriers, escrowed cargo and interruption recovery. Godot 4.3/4.7 CI passed 50/50 jobs. PR #34 merged explicit Keep/Storage/Outpost cost-source spending for build/research/repair; Godot 4.3/4.7 workflow #41325205416 passed 52/52 jobs. Phase 02.5 is implemented on `feat/phase-02-supply-pressure`; PR and CI pending.
**Dependency:** Keep-connected supply graph and local stockpiles in save v12; mainline now uses save v13 for physical shipment records, with v1–v12 migration compatibility.
**Engine targets:** Godot 4.3 and 4.7.

## Goal

Turn road connectivity into an actual logistics system without changing Classic economy rules. A connected road graph is not itself a supply simulation: each depot must own stock, deliveries must change that stock, and transfers must move real quantities between depots.

## Workstreams

### 02.2 — Local depot inventories

**Delivered logistics slice (PR #31, merged):** Storage and Outposts have bounded local stockpile capacity (180 and 120 units). Frontier workers deposit carried resources into connected remote depots; full/unsupported stockpiles reject deposits and workers retain cargo while rerouting. Every 3 seconds, each connected remote depot transfers at most 6 units to Keep Inventory, rotating resource-kind priority. Disconnected depots retain their local goods. These transfers are atomic on a bounded tick rather than physical carrier trips, so there is no in-flight cargo state. Save v12 persists per-building balances and validates resource kinds, non-negative quantities and capacity. Classic deposits remain on central Inventory.

**Cost-source implementation (PR #34 merged; Godot 4.3/4.7 workflow #41325205416 passed 52/52):** `JOBS → POS` selects one source depot for construction, research and repairs. Payments debit only that source, reject disconnected remote depots, and never pool balances. The selected cell is stored as an optional field in save v13 so previous v13 saves remain valid.
- [x] Give Storage and Outposts a persisted resource ledger with explicit capacity and accepted resource types.
- Keep the Keep as the initial central depot. Storage and Outposts hold local stock rather than silently crediting a global shared balance.
- [x] Frontier worker deposits atomically remove carried cargo and add exactly that amount to one connected depot. Disconnected depots are ineligible.
- Define overflow behavior: workers retain unaccepted cargo or select another eligible depot; never silently destroy or duplicate resources.
- [x] Expose a shared Keep/Storage/Outpost source selector for build, research and repair costs; debit only the selected depot and reject disconnected sources (PR #34 merged; Godot 4.3/4.7 workflow #41325205416 passed 52/52).
- [x] Render local stock inspection and cost-source selection for Storage and Outposts in the `JOBS → POS` panel; direct cost spending remains separate from shipment withdrawal and no remote stock is silently transferred.

### 02.3 — Inter-depot transfers
- [x] Add a bounded automatic shipment service that moves local stock from connected Storage/Outposts into Keep Inventory on a periodic tick.
- [x] Atomically remove the exact quantity from the source stockpile and credit Keep Inventory in the same simulation tick.
- [x] Use deterministic depot ordering, a 3-second cadence, a six-unit per-depot budget and rotating resource-kind priority; no per-frame global cargo scan.
- [x] Leave disconnected depot stock in place until its route is restored.
- [x] Add player-directed shipment orders between Keep/Storage/Outposts with explicit source reservation and destination-capacity reservation (PR #33 merged; Godot 4.3/4.7 CI passed 50/50).
- [x] Spawn visible physical couriers on nav paths and deliver exact cargo into destination stockpiles or Keep Inventory (PR #33 merged; Godot 4.3/4.7 CI passed 50/50).
- [x] Preserve the carrier's last position and escrowed cargo when a route is interrupted; resume when the destination route is reconnected (PR #33 merged; Godot 4.3/4.7 CI passed 50/50).
- [x] Support cancellation/refund and capacity-safe recovery when a destination disappears; source destruction falls back to central Inventory on recovery (PR #33 merged; Godot 4.3/4.7 CI passed 50/50).
- Keep automatic 3-second atomic Keep transfers distinct from player-directed carrier trips; they are separate services and budgets.

### 02.4 — Outpost defense and visibility
- [x] Add two configurable guard slots to Outposts and assignment/release controls using existing soldier specialization (PR #32 merged; CI passed 48/48).
- [x] Assigned guards remain attached to their Outpost, engage enemies only inside a 128-pixel local defense radius, and return to the post after combat (PR #32 merged; CI passed).
- [x] Outposts reveal a bounded local radius independent of ownership and road supply; this was already implemented in `scripts/systems/fog_of_war.gd` on `main`.
- [x] Strategic map enemy markers are restricted to currently observed positions; this was already implemented in the existing fog/map visibility path.
- [x] Persist guard-to-Outpost cell links in optional save-v12 fields; validate references/capacity and release guards on death or Outpost removal (PR #32 merged; CI passed).

### 02.5 — Supply pressure (implementation branch; CI pending)
- Only Frontier Storage/Outpost depots are exposed. A depot must be disconnected from the Keep and located in enemy/contested territory; a disconnected depot in neutral/player-controlled territory does not accrue raid pressure.
- Exposure produces a visible warning after 30 seconds. A targeted saboteur spawns after 60 seconds, with one repeat at 210 seconds; maximum two saboteurs per continuous isolation. No random timer rolls or random stock loss.
- Saboteurs path to their exact depot target using the navigation grid, fight the player/local defenders first, then damage depot integrity. Every second successful hit against the depot steals exactly one unit, in deterministic priority `food → iron → wood → stone`.
- Restoring Keep connectivity or reclaiming the territory immediately ends pressure and recalls active saboteurs. Outpost guards and regular soldiers can intercept; Builder repair uses the active cost source. Keep/Classic economy remains unchanged.
- Pressure timers and active saboteur target/hit progress are optional additive fields in save v13; earlier v13 snapshots without them remain valid.
- The implementation is on `feat/phase-02-supply-pressure`; CI pending. Manual render/gameplay acceptance remains required.

## Persistence and compatibility
- [x] Save v12 persists local stockpiles; save v13 additionally persists shipment order history, escrowed in-transit cargo and now optional cost-source selection. v1–v12 remain loadable; previous v13 saves without the optional source field remain valid.
- Preserve Classic's current shared-resource behavior unless a separate Classic design decision explicitly changes it.
- [x] Test Classic v1–v13 and Frontier v7–v13 migrations plus v12 local-stockpile and v13 physical-shipment save/restore, capacity reservation, backup recovery and interrupted writes.
- Removing a depot must deterministically resolve its stock and in-transit cargo; no silent resource duplication.

## Required regression coverage
- Two depots with different balances; deposit to one must not alter the other.
- Disconnected depot refuses deposit and retains villager cargo.
- Full depot handles overflow without loss.
- [x] Automatic transfer moves exact quantities once and stays within the configured per-depot budget.
- [x] Physical carrier shipment interruption preserves escrowed cargo and last position; reconnection resumes the courier (PR #33 merged; Godot 4.3/4.7 CI passed 50/50).
- [x] Save/load preserves each depot local balance after automatic transfer.
- [x] Physical carrier order history and pending cargo survive v13 save/load; v12 saves migrate with no active shipment orders (PR #33 merged; Godot 4.3/4.7 CI passed 50/50).
- [x] Outpost guard assignment, death/reassignment, removal, local combat radius, local visibility and v12 save compatibility (PR #32; regression passed on Godot 4.3/4.7).
- Classic economy remains unchanged.
- [ ] Contested disconnected-depot warning precedes attrition; no raid can spawn before the warning threshold.
- [ ] Targeted saboteurs must have a reachable path and never target Keep or a connected depot.
- [ ] Every raid strike is deterministic, visibly reported and bounded to two waves per continuous isolation.
- [ ] A road reconnection or territory recovery clears the pressure state and recalls the raider.
- [ ] Pressure state and active raider targets survive save/load; pre-pressure save v13 files remain valid.

## Acceptance gate
- Local stockpiles are authoritative for remote Frontier deposits. Build/research/repair charges must be paid fully by the explicitly selected source depot; do not pool balances across depots. Classic continues using the Keep Inventory.
- [x] Automatic Keep-bound transfers are bounded, deterministic and atomic; local balances persist through save/load.
- [x] Player-directed physical shipments, cancellation/refund, destination-capacity reservation and recoverable route interruption are merged through PR #33 (Godot 4.3/4.7 CI passed 50/50).
- [x] Outposts provide working guard assignment and local visibility (PR #32 merged; Godot CI passed 48/48).
- Godot 4.3/4.7 import, parse and regression matrices pass.
- Phase 02.5 branch regression: `tests/supply_pressure.gd` (warning lead time, targeted reachability, damage/theft order, repeat cap/cooldown, HUD exposure, save compatibility and route recovery); CI pending.