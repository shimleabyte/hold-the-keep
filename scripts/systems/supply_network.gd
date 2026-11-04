extends Node
## Road-connected logistics. Automatic transfers remain bounded; player orders
## reserve cargo immediately and move it with visible, recoverable couriers.

const TRANSFER_INTERVAL := 3.0
const TRANSFER_BUDGET_PER_DEPOT := 6
const TRANSFER_KINDS: Array[String] = ["wood", "stone", "food", "iron"]
const MAX_SHIPMENT_AMOUNT := 60
const MAX_ACTIVE_SHIPMENTS := 8
const SHIPMENT_TICK := 0.2
const SHIPMENT_DISPATCH_SCRIPT := preload("res://scripts/systems/supply_shipment_dispatch.gd")
const COST_TRANSACTIONS_SCRIPT := preload("res://scripts/systems/supply_cost_transactions.gd")
const SHIPMENT_LEDGER_SCRIPT := preload("res://scripts/systems/supply_shipment_ledger.gd")
const ROAD_GRAPH_SCRIPT := preload("res://scripts/systems/supply_road_graph.gd")
const ENEMY_SCRIPT := preload("res://scripts/entities/enemy.gd")
const PRESSURE_WARNING_SECONDS := 30.0
const PRESSURE_RAID_SECONDS := 60.0
const PRESSURE_REPEAT_SECONDS := 150.0
const MAX_RAIDS_PER_ISOLATION := 2
const MAX_ACTIVE_SUPPLY_RAIDERS := 8
const PRESSURE_TICK := 1.0
const MAX_PRESSURE_RECORDS := 64

var world
var nav
var flow
var player
var territory
var _road_graph = ROAD_GRAPH_SCRIPT.new()
var connected_road_cells: Dictionary:
    get:
        return _road_graph.connected_road_cells
var _depot_connections: Dictionary:
    get:
        return _road_graph.depot_connections
var _dirty: bool:
    get:
        return _road_graph.dirty
    set(value):
        _road_graph.dirty = value
var _transfer_timer := 0.0
var _transfer_cursor := 0
var _shipment_timer := 0.0
var _pressure_timer := 0.0
var _pressure_records: Dictionary = {}
var _shipment_ledger = SHIPMENT_LEDGER_SCRIPT.new()
var _shipment_dispatch = SHIPMENT_DISPATCH_SCRIPT.new()
var _cost_source_cell := Vector2i(-1, -1)
var _cost_transactions = COST_TRANSACTIONS_SCRIPT.new()

var _carriers: Dictionary = {}


func _ready() -> void:
    _cost_transactions.configure(self)
    add_to_group("supply_network")
    Events.building_placed.connect(_on_building_event)
    Events.building_removed.connect(_on_building_event)
    Events.building_destroyed.connect(_on_building_event)


func _on_building_event(id: String, cell: Vector2i) -> void:
    _dirty = true
    if id == "keep" and _cost_source_cell == Vector2i(-1, -1):
        var keep = _find_keep()
        if keep != null:
            _cost_source_cell = keep.cell
            Events.supply_cost_source_changed.emit()
    elif _cost_source_cell == cell and id != "keep":
        var fallback_keep = _find_keep()
        _cost_source_cell = fallback_keep.cell if fallback_keep != null else Vector2i(-1, -1)
        Events.supply_cost_source_changed.emit()


func _physics_process(_delta: float) -> void:
    if _dirty:
        rebuild()


func _process(delta: float) -> void:
    if not WorldConfig.is_frontier_profile():
        return
    _transfer_timer += delta
    if _transfer_timer >= TRANSFER_INTERVAL:
        _transfer_timer = 0.0
        transfer_local_stockpiles()
    _shipment_timer += delta
    if _shipment_timer >= SHIPMENT_TICK:
        _shipment_timer = 0.0
        advance_shipment_orders()
    _pressure_timer += delta
    if _pressure_timer >= PRESSURE_TICK:
        var pressure_delta := _pressure_timer
        _pressure_timer = 0.0
        advance_supply_pressure(pressure_delta)


## Move a bounded amount from each connected remote depot into the Keep inventory.
## This legacy automatic route remains separate from player-directed physical trips.
func transfer_local_stockpiles() -> int:
    if not WorldConfig.is_frontier_profile():
        return 0
    _ensure_current()
    var depots: Array = get_tree().get_nodes_in_group("depots")
    depots.sort_custom(func(a, b) -> bool:
        if a.cell.y == b.cell.y:
            return a.cell.x < b.cell.x
        return a.cell.y < b.cell.y
    )
    var keep = _find_keep()
    if keep == null:
        return 0

    var moved := 0
    for depot in depots:
        if not is_instance_valid(depot) or depot == keep:
            continue
        if not is_depot_connected(depot):
            continue
        var budget := TRANSFER_BUDGET_PER_DEPOT
        for offset in TRANSFER_KINDS.size():
            var index := (_transfer_cursor + offset) % TRANSFER_KINDS.size()
            var kind := TRANSFER_KINDS[index]
            var amount := mini(budget, depot.stockpile_amount(kind))
            if amount <= 0 or not depot.take_resource(kind, amount):
                continue
            Inventory.add(kind, amount)
            moved += amount
            budget -= amount
            if budget <= 0:
                break
    _transfer_cursor = (_transfer_cursor + 1) % TRANSFER_KINDS.size()
    return moved



## Construction and research draw from one explicitly selected depot.
## Remote balances remain separate; nothing is pooled or silently transferred.
func get_cost_source_cell() -> Vector2i:
    return _cost_transactions.get_cost_source_cell()


func set_cost_source(cell: Vector2i) -> bool:
    return _cost_transactions.set_cost_source(cell)


func cost_source_label() -> String:
    return _cost_transactions.cost_source_label()


func cost_source_amount(kind: String) -> int:
    return _cost_transactions.cost_source_amount(kind)


func cost_reason(cost: Dictionary) -> String:
    return _cost_transactions.cost_reason(cost)


func refund_cost_to_source(source_cell: Vector2i, refund: Dictionary) -> void:
    _cost_transactions.refund_cost_to_source(source_cell, refund)


func can_pay_cost(cost: Dictionary) -> bool:
    return _cost_transactions.can_pay_cost(cost)


func pay_cost(cost: Dictionary) -> bool:
    return _cost_transactions.pay_cost(cost)


## Return the raid exposure state used by the depot panel.
func depot_pressure_state(depot: Node) -> Dictionary:
    if not WorldConfig.is_frontier_profile():
        return {"status": "connected", "label": "NONAKTIF"}
    if depot == null or not is_instance_valid(depot) or String(depot.id) == "keep":
        return {"status": "connected", "label": "TERHUBUNG"}
    if is_depot_connected(depot):
        return {"status": "connected", "label": "TERHUBUNG"}
    if not _depot_under_threat(depot):
        return {"status": "isolated", "label": "TERPUTUS"}
    if _active_supply_raiders(depot.cell) > 0:
        return {"status": "raiding", "label": "DIGEMPUR"}
    var record: Dictionary = _pressure_records.get(_pressure_key(depot.cell), {})
    if bool(record.get("warning_sent", false)):
        return {"status": "vulnerable", "label": "ANCAMAN RAID"}
    return {"status": "exposed", "label": "TERPENCIL"}


func _pressure_key(cell: Vector2i) -> String:
    return "%d:%d" % [cell.x, cell.y]


func _depot_under_threat(depot: Node) -> bool:
    if territory == null or not is_instance_valid(territory):
        return false
    var owner: String = territory.owner_at(depot.cell)
    if owner == "enemy" or owner == "contested":
        return true
    var region_id: String = world.region_id(depot.cell)
    var region: Dictionary = territory.get_region_state(region_id)
    var control := String(region.get("control", "neutral"))
    return control == "enemy" or control == "contested"


func _active_supply_raiders(cell: Vector2i) -> int:
    var count := 0
    for enemy in get_tree().get_nodes_in_group("supply_raiders"):
        if is_instance_valid(enemy) and enemy.is_supply_raider and enemy.raid_target_cell == cell:
            count += 1
    return count


func advance_supply_pressure(delta: float) -> void:
    if not WorldConfig.is_frontier_profile() or delta <= 0.0:
        return
    _ensure_current()
    var next_records: Dictionary = {}
    var state_changed := false
    for depot in get_tree().get_nodes_in_group("depots"):
        if not is_instance_valid(depot) or not ["storage", "outpost", "granary"].has(String(depot.id)):
            continue
        var key := _pressure_key(depot.cell)
        var record: Dictionary = _pressure_records.get(key, {
            "cx": depot.cell.x,
            "cy": depot.cell.y,
            "contested_seconds": 0.0,
            "warning_sent": false,
            "raid_count": 0,
            "spawn_retry": 0.0,
            "status": "isolated"
        }).duplicate(true)
        var previous_status := String(record.get("status", "isolated"))

        if is_depot_connected(depot):
            if _pressure_records.has(key):
                _recall_supply_raiders(depot.cell)
                state_changed = true
            continue

        if not _depot_under_threat(depot):
            if float(record.get("contested_seconds", 0.0)) > 0.0 or int(record.get("raid_count", 0)) > 0:
                _recall_supply_raiders(depot.cell)
                state_changed = true
            record["contested_seconds"] = 0.0
            record["warning_sent"] = false
            record["raid_count"] = 0
            record["spawn_retry"] = 0.0
            record["status"] = "isolated"
            next_records[key] = record
            if previous_status != "isolated":
                state_changed = true
            continue

        record["contested_seconds"] = minf(
            PRESSURE_RAID_SECONDS + PRESSURE_REPEAT_SECONDS * MAX_RAIDS_PER_ISOLATION,
            float(record.get("contested_seconds", 0.0)) + delta
        )
        var contested_seconds := float(record["contested_seconds"])
        if contested_seconds >= PRESSURE_WARNING_SECONDS and not bool(record.get("warning_sent", false)):
            record["warning_sent"] = true
            Events.event_triggered.emit(
                "JALUR LOGISTIK TERANCAM",
                "%s di %d,%d terisolasi di wilayah sengketa. Saboteur dapat tiba dalam 30 detik. Sambungkan jalan, rebut kembali wilayah, atau tugaskan penjaga."
                % [String(depot.id).to_upper(), depot.cell.x, depot.cell.y]
            )
            state_changed = true

        var retry_in := maxf(0.0, float(record.get("spawn_retry", 0.0)) - delta)
        record["spawn_retry"] = retry_in
        var raid_count := int(record.get("raid_count", 0))
        var next_raid_at := PRESSURE_RAID_SECONDS + float(raid_count) * PRESSURE_REPEAT_SECONDS
        if raid_count < MAX_RAIDS_PER_ISOLATION and contested_seconds >= next_raid_at and retry_in <= 0.0 and _active_supply_raiders(depot.cell) == 0 and get_tree().get_nodes_in_group("supply_raiders").size() < MAX_ACTIVE_SUPPLY_RAIDERS:
            if _spawn_supply_raid(depot):
                raid_count += 1
                record["raid_count"] = raid_count
                Events.event_triggered.emit(
                    "SABOTEUR MENYERANG",
                    "Saboteur menyerbu %s %d,%d. Penjaga lokal dapat menghadapinya; pulihkan jalan atau perbaiki depot dari Keep."
                    % [String(depot.id).to_upper(), depot.cell.x, depot.cell.y]
                )
                state_changed = true
            else:
                record["spawn_retry"] = 10.0

        var next_status := "exposed"
        if _active_supply_raiders(depot.cell) > 0:
            next_status = "raiding"
        elif bool(record.get("warning_sent", false)):
            next_status = "vulnerable"
        record["status"] = next_status
        if previous_status != next_status:
            state_changed = true
        next_records[key] = record

    for old_key in _pressure_records:
        if next_records.has(old_key):
            continue
        var old_record: Dictionary = _pressure_records[old_key]
        var old_cell := Vector2i(int(old_record.get("cx", -1)), int(old_record.get("cy", -1)))
        if old_cell.x >= 0:
            _recall_supply_raiders(old_cell)
        state_changed = true

    _pressure_records = next_records
    while _pressure_records.size() > MAX_PRESSURE_RECORDS:
        _pressure_records.erase(_pressure_records.keys()[0])
    if state_changed:
        Events.supply_pressure_changed.emit()


func _spawn_supply_raid(depot: Node) -> bool:
    if nav == null or world == null or flow == null or not DataDB.enemies.has("enemy_saboteur"):
        return false
    var spawn_cell := _find_supply_raid_spawn(depot)
    if spawn_cell.x < 0:
        return false
    var enemy = ENEMY_SCRIPT.new()
    var faction_id := FactionRegistry.faction_for_region(world.region_id(spawn_cell))
    enemy.setup(DataDB.enemies["enemy_saboteur"], world, flow, player, faction_id)
    enemy.setup_supply_raid(depot.cell, nav)
    enemy.position = nav.center_of(spawn_cell)
    world.entities.add_child(enemy)
    return true


func _find_supply_raid_spawn(depot: Node) -> Vector2i:
    if nav == null or territory == null:
        return Vector2i(-1, -1)
    var target_cells: Array[Vector2i] = depot.cells()
    for radius in range(4, 10):
        for y in range(-radius, radius + 1):
            for x in range(-radius, radius + 1):
                if maxi(absi(x), absi(y)) != radius:
                    continue
                var candidate: Vector2i = depot.cell + Vector2i(x, y)
                if not world.is_buildable(candidate) or not nav.is_walkable(candidate):
                    continue
                var owner: String = territory.owner_at(candidate)
                var region: Dictionary = territory.get_region_state(world.region_id(candidate))
                var region_control := String(region.get("control", "neutral"))
                var hostile_cell := owner == "enemy" or owner == "contested" or region_control == "enemy" or region_control == "contested"
                if not hostile_cell:
                    continue
                var path: PackedVector2Array = nav.path_adjacent(nav.center_of(candidate), target_cells)
                if path.size() >= 2:
                    return candidate
    return Vector2i(-1, -1)


func _recall_supply_raiders(cell: Vector2i) -> void:
    for enemy in get_tree().get_nodes_in_group("supply_raiders"):
        if is_instance_valid(enemy) and enemy.is_supply_raider and enemy.raid_target_cell == cell:
            enemy.retreat()


## Saboteurs always take one unit in a fixed priority order every second successful hit.
func raid_steal_from(depot: Node) -> String:
    if depot == null or not is_instance_valid(depot) or not ["storage", "outpost", "granary"].has(String(depot.id)):
        return ""
    for kind in ["food", "iron", "wood", "stone"]:
        if depot.stockpile_amount(kind) <= 0:
            continue
        if depot.take_resource(kind, 1):
            Events.build_feedback.emit(
                "Saboteur merampas 1 %s dari %s %d,%d"
                % [kind.to_upper(), String(depot.id).to_upper(), depot.cell.x, depot.cell.y]
            )
            Events.supply_pressure_changed.emit()
            return kind
    return ""


## Create a reserved shipment. Cargo leaves its source immediately and remains
## owned by the order until delivery, cancellation/refund, or explicit recovery.
## Returns the order ID, or -1 when any precondition fails.
func create_shipment(source_cell: Vector2i, destination_cell: Vector2i, kind: String, amount: int) -> int:
    if not WorldConfig.is_frontier_profile() or not TRANSFER_KINDS.has(kind):
        return -1
    if amount <= 0 or amount > MAX_SHIPMENT_AMOUNT or source_cell == destination_cell:
        return -1
    if _shipment_ledger.active_count() >= MAX_ACTIVE_SHIPMENTS:
        return -1
    _ensure_current()
    var source = _find_depot(source_cell)
    var destination = _find_depot(destination_cell)
    if source == null or destination == null or source == destination:
        return -1
    if not is_depot_connected(source) or not is_depot_connected(destination):
        return -1
    if destination.id != "keep":
        if not destination.accepts_resource(kind):
            return -1
        var reserved := _reserved_capacity(destination_cell)
        if destination.stockpile_total() + reserved + amount > destination.stockpile_capacity:
            return -1

    var withdrawn: bool = Inventory.spend(kind, amount) if source.id == "keep" else source.take_resource(kind, amount)
    if not withdrawn:
        return -1

    var order_id: int = _shipment_ledger.allocate_id()
    _shipment_ledger.append_order({
        "id": order_id,
        "source_x": source.cell.x,
        "source_y": source.cell.y,
        "destination_x": destination.cell.x,
        "destination_y": destination.cell.y,
        "kind": kind,
        "amount": amount,
        "cargo": amount,
        "status": "queued",
        "x": source.position.x,
        "y": source.position.y
    })
    _trim_shipment_history()
    advance_shipment_orders()
    return order_id


func cancel_shipment(order_id: int) -> bool:
    var index := _shipment_ledger.order_index(order_id)
    if index < 0:
        return false
    var order: Dictionary = _shipment_ledger.orders[index]
    if not _shipment_ledger.is_active_order(order):
        return false
    _remove_carrier(order_id)
    _recover_cargo(order, "cancelled")
    return true


func get_shipment_orders() -> Array[Dictionary]:
    return _shipment_ledger.snapshot()


func get_shipment_status_label(status: String) -> String:
    match status:
        "queued":
            return "ANTRE"
        "in_transit":
            return "DI JALAN"
        "blocked":
            return "TERPUTUS"
        "delivered":
            return "TIBA"
        "cancelled":
            return "DIBATALKAN"
        "recovered":
            return "DIPULIHKAN"
    return "TIDAK DIKETAHUI"


func advance_shipment_orders() -> void:
    _shipment_dispatch.advance(self)


func shipment_route_available(order_id: int) -> bool:
    return _shipment_dispatch.route_available(self, order_id)


func carrier_blocked(order_id: int, carrier_position: Vector2) -> void:
    _shipment_dispatch.carrier_blocked(self, order_id, carrier_position)


func carrier_completed(order_id: int, carrier_position: Vector2) -> void:
    var index := _shipment_ledger.order_index(order_id)
    if index < 0:
        return
    var order: Dictionary = _shipment_ledger.orders[index]
    if not _shipment_ledger.is_active_order(order):
        return
    if not shipment_route_available(order_id):
        carrier_blocked(order_id, carrier_position)
        return
    var destination = _find_depot(Vector2i(int(order["destination_x"]), int(order["destination_y"])))
    if destination == null:
        _recover_cargo(order, "recovered")
        _shipment_ledger.orders[index] = order
        _carriers.erase(order_id)
        return
    var amount := int(order["cargo"])
    var kind := String(order["kind"])
    var delivered := false
    if destination.id == "keep":
        Inventory.add(kind, amount)
        delivered = true
    else:
        delivered = destination.store_resource(kind, amount)
    if not delivered:
        _recover_cargo(order, "recovered")
    else:
        order["cargo"] = 0
        order["status"] = "delivered"
    order["x"] = carrier_position.x
    order["y"] = carrier_position.y
    _shipment_ledger.orders[index] = order
    _carriers.erase(order_id)
    _trim_shipment_history()


func _recover_cargo(order: Dictionary, final_status: String) -> void:
    var amount := int(order.get("cargo", 0))
    if amount > 0:
        var kind := String(order.get("kind", ""))
        var source = _find_depot(Vector2i(int(order.get("source_x", -1)), int(order.get("source_y", -1))))
        if source == null or source.id == "keep":
            Inventory.add(kind, amount)
        else:
            var room := maxi(0, source.stockpile_capacity - source.stockpile_total())
            var returned := mini(room, amount)
            if returned > 0:
                source.store_resource(kind, returned)
            if returned < amount:
                Inventory.add(kind, amount - returned)
    order["cargo"] = 0
    order["status"] = final_status
    var index := _shipment_ledger.order_index(int(order.get("id", -1)))
    if index >= 0:
        _shipment_ledger.orders[index] = order
    _trim_shipment_history()


func _find_depot(cell: Vector2i):
    for depot in get_tree().get_nodes_in_group("depots"):
        if is_instance_valid(depot) and depot.cell == cell:
            return depot
    return null


func _find_keep():
    for depot in get_tree().get_nodes_in_group("depots"):
        if is_instance_valid(depot) and depot.id == "keep":
            return depot
    return null


func _reserved_capacity(destination_cell: Vector2i) -> int:
    return _shipment_ledger.reserved_capacity(destination_cell)


func _remove_carrier(order_id: int) -> void:
    var carrier = _carriers.get(order_id, null)
    if is_instance_valid(carrier):
        var index := _shipment_ledger.order_index(order_id)
        if index >= 0:
            var order: Dictionary = _shipment_ledger.orders[index]
            order["x"] = carrier.position.x
            order["y"] = carrier.position.y
            _shipment_ledger.orders[index] = order
        carrier.queue_free()
    _carriers.erase(order_id)


func _trim_shipment_history() -> void:
    _shipment_ledger.trim_history()


func export_state() -> Dictionary:
    var orders: Array[Dictionary] = _shipment_ledger.snapshot()
    for index in orders.size():
        var order: Dictionary = orders[index]
        var carrier = _carriers.get(int(order.get("id", -1)), null)
        if is_instance_valid(carrier):
            order["x"] = carrier.position.x
            order["y"] = carrier.position.y
        if String(order.get("status", "")) == "in_transit":
            order["status"] = "blocked"
        orders[index] = order
    var source_cell := get_cost_source_cell()
    var pressure: Array[Dictionary] = []
    for key in _pressure_records:
        var record: Dictionary = _pressure_records[key]
        pressure.append({
            "cx": int(record.get("cx", -1)),
            "cy": int(record.get("cy", -1)),
            "contested_seconds": float(record.get("contested_seconds", 0.0)),
            "warning_sent": bool(record.get("warning_sent", false)),
            "raid_count": int(record.get("raid_count", 0)),
            "spawn_retry": float(record.get("spawn_retry", 0.0)),
            "status": String(record.get("status", "isolated"))
        })
    return {
        "next_id": _shipment_ledger.next_id,
        "orders": orders,
        "cost_source": {"cx": source_cell.x, "cy": source_cell.y}
            if source_cell != Vector2i(-1, -1) else null,
        "pressure": pressure
    }


func import_state(value: Variant) -> void:
    _shipment_ledger.clear()
    _carriers.clear()
    _pressure_records.clear()
    if not (value is Dictionary):
        return
    var orders: Variant = value.get("orders", [])
    if not (orders is Array):
        return
    _shipment_ledger.restore(orders, int(value.get("next_id", 1)))
    var saved_source: Variant = value.get("cost_source", null)
    if saved_source is Dictionary and saved_source.has("cx") and saved_source.has("cy"):
        var candidate := Vector2i(int(saved_source["cx"]), int(saved_source["cy"]))
        var source = _find_depot(candidate)
        if source != null and ["keep", "storage", "outpost"].has(String(source.id)):
            _cost_source_cell = candidate
        else:
            var keep = _find_keep()
            _cost_source_cell = keep.cell if keep != null else Vector2i(-1, -1)
    else:
        var keep = _find_keep()
        _cost_source_cell = keep.cell if keep != null else Vector2i(-1, -1)
    Events.supply_cost_source_changed.emit()
    var saved_pressure: Variant = value.get("pressure", [])
    if saved_pressure is Array:
        for saved_record in saved_pressure:
            if not (saved_record is Dictionary):
                continue
            var saved_cell := Vector2i(int(saved_record.get("cx", -1)), int(saved_record.get("cy", -1)))
            var depot = _find_depot(saved_cell)
            if depot == null or not ["storage", "outpost", "granary"].has(String(depot.id)):
                continue
            _pressure_records[_pressure_key(saved_cell)] = {
                "cx": saved_cell.x,
                "cy": saved_cell.y,
                "contested_seconds": clampf(float(saved_record.get("contested_seconds", 0.0)), 0.0, PRESSURE_RAID_SECONDS + PRESSURE_REPEAT_SECONDS * MAX_RAIDS_PER_ISOLATION),
                "warning_sent": bool(saved_record.get("warning_sent", false)),
                "raid_count": clampi(int(saved_record.get("raid_count", 0)), 0, MAX_RAIDS_PER_ISOLATION),
                "spawn_retry": clampf(float(saved_record.get("spawn_retry", 0.0)), 0.0, 30.0),
                "status": String(saved_record.get("status", "isolated"))
            }
    _trim_shipment_history()
    Events.supply_pressure_changed.emit()


func rebuild() -> void:
    _road_graph.rebuild(self)


func _ensure_current() -> void:
    _road_graph.ensure_current(self)


func is_road_connected(cell: Vector2i) -> bool:
    return _road_graph.is_road_connected(self, cell)


func is_depot_connected(depot: Node) -> bool:
    return _road_graph.is_depot_connected(self, depot)


func connected_road_count() -> int:
    return _road_graph.connected_road_count(self)


func connected_depot_count() -> int:
    return _road_graph.connected_depot_count(self)
