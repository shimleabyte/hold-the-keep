# Phase 02 — Local Logistics and Outpost Support

**Status:** Partial implementation. Regional ownership, roads/bridges, Keep-rooted connectivity and connected-depot eligibility are merged; the audit implementation branch adds local Storage/Outpost stockpiles and v12 persistence. Actual inter-depot transfers, stock inspection UI, Outpost garrisons and Outpost-local visibility remain open.
**Dependency:** The existing Keep-connected supply graph and save v12.
**Engine targets:** Godot 4.3 and 4.7.

## Goal

Turn road connectivity into an actual logistics system without changing Classic economy rules. A connected road graph is not itself a supply simulation: each depot must own stock, deliveries must change that stock, and transfers must move real quantities between depots.

## Workstreams

### 02.2 — Local depot inventories

**First implementation slice (audit branch):** Storage and Outposts now have bounded local stockpile capacity (180 and 120 units respectively). Frontier workers deposit carried resources into the selected remote depot instead of the shared Keep inventory; full/unsupported stockpiles reject deposits, and workers retain cargo while selecting another destination. Save schema v12 persists local balances and validates resource kinds, non-negative quantities and per-building capacity. Classic worker deposits remain on the original central Inventory path.

**Still open in 02.2:** player-facing local stock inspection, explicit source-depot spending/reservation, and all inter-depot transfer behavior described below.
- [x] Give Storage and Outposts a persisted resource ledger with explicit capacity and accepted resource types.
- Keep the Keep as the initial central depot. Storage and Outposts hold local stock rather than silently crediting a global shared balance.
- [x] Frontier worker deposits atomically remove carried cargo and add exactly that amount to one connected depot. Disconnected depots are ineligible.
- Define overflow behavior: workers retain unaccepted cargo or select another eligible depot; never silently destroy or duplicate resources.
- Keep existing build/research spending compatible by introducing an explicit source-depot selection/reservation rule. Local Outpost/Storage stock is not globally spendable until an actual transfer or documented local-consumption rule exists.
- Render local stock in a depot inspection UI before adding management complexity to the global HUD.

### 02.3 — Inter-depot transfers
- Add an explicit transfer order or bounded logistics service that moves resource quantities along Keep-connected road edges.
- A transfer removes stock from its source when a carrier departs and credits the destination only on successful arrival.
- Revalidate road connectivity, destination validity and capacity during the trip; interruption must preserve cargo and support return, reroute or recoverable dropped cargo.
- Use deterministic carrier selection, bounded active transfers and clear cooldowns to avoid per-frame global scans.
- Persist transfer assignments and in-transit cargo. Save/load must not duplicate or erase stock.

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
- [x] Test Classic v1–v11 and Frontier v7–v11 migration defaults plus v12 local-stockpile round-trip, capacity rejection, backup recovery and interrupted writes.
- Removing a depot must deterministically resolve its stock and in-transit cargo; no silent resource duplication.

## Required regression coverage
- Two depots with different balances; deposit to one must not alter the other.
- Disconnected depot refuses deposit and retains villager cargo.
- Full depot handles overflow without loss.
- Transfer moves exact quantities once; interrupted route preserves recoverable cargo.
- Save/load preserves each depot balance and in-flight transfer state.
- Outpost guard assignment, death/reassignment, removal and local visibility bounds.
- Classic economy remains unchanged.

## Acceptance gate
- Local stockpiles are authoritative for remote Frontier depot deposits; central construction/research spending must not consume remote stock before explicit transfer or source-depot rules exist.
- Inter-depot transfers are bounded, deterministic, persistent and lossless except for explicitly documented combat losses.
- Outposts provide working guard assignment and local visibility.
- Godot 4.3/4.7 import, parse and regression matrices pass.