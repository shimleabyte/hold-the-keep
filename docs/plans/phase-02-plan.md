# Phase 02 — Local Logistics and Outpost Support

**Status:** Partial implementation. Regional ownership, roads/bridges, Keep-rooted connectivity, local Storage/Outpost stockpiles, Frontier deposits and bounded automatic shipments to Keep are implemented on the audit branch with save v12. Stock inspection/withdrawal UI, player-directed shipment orders, Outpost garrisons and Outpost-local visibility remain open.
**Dependency:** The existing Keep-connected supply graph and save v12.
**Engine targets:** Godot 4.3 and 4.7.

## Goal

Turn road connectivity into an actual logistics system without changing Classic economy rules. A connected road graph is not itself a supply simulation: each depot must own stock, deliveries must change that stock, and transfers must move real quantities between depots.

## Workstreams

### 02.2 — Local depot inventories

**Delivered logistics slice (audit branch):** Storage and Outposts have bounded local stockpile capacity (180 and 120 units). Frontier workers deposit carried resources into connected remote depots; full/unsupported stockpiles reject deposits and workers retain cargo while rerouting. Every 3 seconds, each connected remote depot transfers at most 6 units to Keep Inventory, rotating resource-kind priority. Disconnected depots retain their local goods. These transfers are atomic on a bounded tick rather than physical carrier trips, so there is no in-flight cargo state. Save v12 persists per-building balances and validates resource kinds, non-negative quantities and capacity. Classic deposits remain on central Inventory.

**Still open in 02.2:** player-facing local stock inspection/withdrawal, explicit source-depot spending/reservation, and player-directed shipment orders.
- [x] Give Storage and Outposts a persisted resource ledger with explicit capacity and accepted resource types.
- Keep the Keep as the initial central depot. Storage and Outposts hold local stock rather than silently crediting a global shared balance.
- [x] Frontier worker deposits atomically remove carried cargo and add exactly that amount to one connected depot. Disconnected depots are ineligible.
- Define overflow behavior: workers retain unaccepted cargo or select another eligible depot; never silently destroy or duplicate resources.
- Keep existing build/research spending compatible by introducing an explicit source-depot selection/reservation rule. Local Outpost/Storage stock is not globally spendable until an actual transfer or documented local-consumption rule exists.
- Render local stock in a depot inspection UI before adding management complexity to the global HUD.

### 02.3 — Inter-depot transfers
- [x] Add a bounded automatic shipment service that moves local stock from connected Storage/Outposts into Keep Inventory on a periodic tick.
- [x] Atomically remove the exact quantity from the source stockpile and credit Keep Inventory in the same simulation tick.
- [x] Use deterministic depot ordering, a 3-second cadence, a six-unit per-depot budget and rotating resource-kind priority; no per-frame global cargo scan.
- [x] Leave disconnected depot stock in place until its route is restored.
- Add player-directed transfer orders, physical carrier trips, route interruption/recovery and an in-transit cargo state as a later increment. Do not imply those features exist in the automatic atomic-transfer slice.

### 02.4 — Outpost defense and visibility
- Add configurable guard slots to Outposts and an assignment UI using existing soldier specialization.
- Assigned guards remain attached to their Outpost, defend a local radius, and return after enemies leave or are defeated.
- Outposts reveal a bounded local radius independent of ownership and road supply.
- Strategic map markers must reveal enemy locations only while observed; unseen hostile units must not leak through stored territory data.
- Persist assigned guards and validate release/reassignment when an Outpost is removed or captured.

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
- Outpost guard assignment, death/reassignment, removal and local visibility bounds.
- Classic economy remains unchanged.

## Acceptance gate
- Local stockpiles are authoritative for remote Frontier depot deposits; central construction/research spending must not consume remote stock before explicit transfer or source-depot rules exist.
- [x] Automatic Keep-bound transfers are bounded, deterministic and atomic; local balances persist through save/load.
- Player-directed physical shipments remain a future feature.
- Outposts provide working guard assignment and local visibility.
- Godot 4.3/4.7 import, parse and regression matrices pass.