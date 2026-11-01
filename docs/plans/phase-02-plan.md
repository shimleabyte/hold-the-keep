# Phase 02 — Local Logistics and Outpost Support

**Status:** Partial implementation. Regional ownership, roads/bridges, Keep-rooted connectivity, local Storage/Outpost stockpiles, Frontier deposits and bounded automatic shipments to Keep are merged into `main` through PR #31 with save v12. PR #32 is merged into `main` and adds read-only depot inspection, Outpost guard slots/assignment, local defense leash, lifecycle handling and save/load persistence. Its Godot 4.3/4.7 CI passed 48/48 jobs. Outpost-local visibility and currently-observed enemy map markers already exist in `main` and are not new work. Withdrawal, explicit local spending and player-directed shipments remain open.
**Dependency:** The existing Keep-connected supply graph and save v12.
**Engine targets:** Godot 4.3 and 4.7.

## Goal

Turn road connectivity into an actual logistics system without changing Classic economy rules. A connected road graph is not itself a supply simulation: each depot must own stock, deliveries must change that stock, and transfers must move real quantities between depots.

## Workstreams

### 02.2 — Local depot inventories

**Delivered logistics slice (PR #31, merged):** Storage and Outposts have bounded local stockpile capacity (180 and 120 units). Frontier workers deposit carried resources into connected remote depots; full/unsupported stockpiles reject deposits and workers retain cargo while rerouting. Every 3 seconds, each connected remote depot transfers at most 6 units to Keep Inventory, rotating resource-kind priority. Disconnected depots retain their local goods. These transfers are atomic on a bounded tick rather than physical carrier trips, so there is no in-flight cargo state. Save v12 persists per-building balances and validates resource kinds, non-negative quantities and capacity. Classic deposits remain on central Inventory.

**Still open in 02.2:** local stock withdrawal, explicit source-depot spending/reservation, and player-directed shipment orders. Read-only local stock inspection is delivered in PR #32.
- [x] Give Storage and Outposts a persisted resource ledger with explicit capacity and accepted resource types.
- Keep the Keep as the initial central depot. Storage and Outposts hold local stock rather than silently crediting a global shared balance.
- [x] Frontier worker deposits atomically remove carried cargo and add exactly that amount to one connected depot. Disconnected depots are ineligible.
- Define overflow behavior: workers retain unaccepted cargo or select another eligible depot; never silently destroy or duplicate resources.
- Keep existing build/research spending compatible by introducing an explicit source-depot selection/reservation rule. Local Outpost/Storage stock is not globally spendable until an actual transfer or documented local-consumption rule exists.
- [x] Render read-only local stock inspection for Storage and Outposts in the `JOBS → POS` panel; withdrawal and spending controls remain deferred.

### 02.3 — Inter-depot transfers
- [x] Add a bounded automatic shipment service that moves local stock from connected Storage/Outposts into Keep Inventory on a periodic tick.
- [x] Atomically remove the exact quantity from the source stockpile and credit Keep Inventory in the same simulation tick.
- [x] Use deterministic depot ordering, a 3-second cadence, a six-unit per-depot budget and rotating resource-kind priority; no per-frame global cargo scan.
- [x] Leave disconnected depot stock in place until its route is restored.
- Add player-directed transfer orders, physical carrier trips, route interruption/recovery and an in-transit cargo state as a later increment. Do not imply those features exist in the automatic atomic-transfer slice.

### 02.4 — Outpost defense and visibility
- [x] Add two configurable guard slots to Outposts and assignment/release controls using existing soldier specialization (PR #32 merged; CI passed 48/48).
- [x] Assigned guards remain attached to their Outpost, engage enemies only inside a 128-pixel local defense radius, and return to the post after combat (PR #32 merged; CI passed).
- [x] Outposts reveal a bounded local radius independent of ownership and road supply; this was already implemented in `scripts/systems/fog_of_war.gd` on `main`.
- [x] Strategic map enemy markers are restricted to currently observed positions; this was already implemented in the existing fog/map visibility path.
- [x] Persist guard-to-Outpost cell links in optional save-v12 fields; validate references/capacity and release guards on death or Outpost removal (PR #32 merged; CI passed).

### 02.5 — Supply pressure (deferred)
- Only after local stock and transfers are reliable, introduce raid vulnerability and optional supply attrition.
- Attrition must be tied to a concrete disconnected/contested supply condition, have a readable warning and recovery path, and never randomly destroy inventory.
- Do not implement attrition in the local-stockpile slice.

## Persistence and compatibility
- [x] Bump save schema to v12 for persisted stockpiles; v1–v11 saves migrate with empty local stockpiles.
- Preserve Classic's current shared-resource behavior unless a separate Classic design decision explicitly changes it.
- [x] Test Classic v1–v11 and Frontier v7–v11 migration defaults plus v12 local-stockpile/automatic-shipment round-trip, capacity rejection, backup recovery and interrupted writes.
- Removing a depot must deterministically resolve its stock and in-transit cargo; no silent resource duplication.

## Required regression coverage
- Two depots with different balances; deposit to one must not alter the other.
- Disconnected depot refuses deposit and retains villager cargo.
- Full depot handles overflow without loss.
- [x] Automatic transfer moves exact quantities once and stays within the configured per-depot budget.
- Physical carrier transfers (future): interrupted route preserves recoverable in-transit cargo.
- [x] Save/load preserves each depot local balance after automatic transfer.
- Physical carrier transfer state is not applicable until carrier trips are implemented.
- [x] Outpost guard assignment, death/reassignment, removal, local combat radius, local visibility and v12 save compatibility (PR #32; regression passed on Godot 4.3/4.7).
- Classic economy remains unchanged.

## Acceptance gate
- Local stockpiles are authoritative for remote Frontier depot deposits; central construction/research spending must not consume remote stock before explicit transfer or source-depot rules exist.
- [x] Automatic Keep-bound transfers are bounded, deterministic and atomic; local balances persist through save/load.
- Player-directed physical shipments remain a future feature.
- [x] Outposts provide working guard assignment and local visibility (PR #32 merged; Godot CI passed 48/48).
- Godot 4.3/4.7 import, parse and regression matrices pass.