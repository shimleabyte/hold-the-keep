extends Node
## Road-connected logistics. Automatic transfers remain bounded; player orders
## reserve cargo immediately and move it with visible, recoverable couriers.

const DIRS4: Array[Vector2i] = [
    Vector2i(1, 0), Vector2i(-1, 0),
    Vector2i(0, 1), Vector2i(0, -1)
]
const TRANSFER_INTERVAL := 3.0
const TRANSFER_BUDGET_PER_DEPOT := 6
const TRANSFER_KINDS: Array[String] = ["wood", "stone", "food", "iron"]
const MAX_SHIPMENT_AMOUNT := 60
const MAX_SHIPMENT_HISTORY := 16
const MAX_ACTIVE_SHIPMENTS := 8
const SHIPMENT_TICK := 0.2
const CARRIER_SCRIPT := preload("res://scripts/entities/supply_carrier.gd")
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
var connected_road_cells: Dictionary = {}
var _depot_connections: Dictionary = {}
var _dirty := true
var _transfer_timer := 0.0
var _transfer_cursor := 0
var _shipment_timer := 0.0
var _pressure_timer := 0.0
var _pressure_records: Dictionary = {}
var _next_shipment_id := 1
var _cost_source_cell := Vector2i(-1, -1)
var shipment_orders: Array[Dictionary] = []
var _carriers: Dictionary = {}


func _ready() -> void:
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
    var source = _selected_cost_depot()
    return source.cell if source != null else Vector2i(-1, -1)


func _selected_cost_depot():
    _ensure_current()
    if _cost_source_cell != Vector2i(-1, -1):
        var selected = _find_depot(_cost_source_cell)
        if selected != null:
            return selected
    return _find_keep()


func set_cost_source(cell: Vector2i) -> bool:
    if not WorldConfig.is_frontier_profile():
        return cell == get_cost_source_cell()
    _ensure_current()
    var depot = _find_depot(cell)
    if depot == null or not ["keep", "storage", "outpost"].has(String(depot.id)):
        return false
    if not is_depot_connected(depot):
        return false
    if _cost_source_cell == cell:
        return true
    _cost_source_cell = cell
    Events.supply_cost_source_changed.emit()
    return true


func cost_source_label() -> String:
    var source = _selected_cost_depot()
    if source == null:
        return "KEEP"
    var label := "KEEP" if String(source.id) == "keep" else (
        "POS %d,%d" % [source.cell.x, source.cell.y] if String(source.id) == "outpost"
        else "GUDANG %d,%d" % [source.cell.x, source.cell.y]
    )
    if WorldConfig.is_frontier_profile() and not is_depot_connected(source):
        label += " · JALUR PUTUS"
    return label


func cost_source_amount(kind: String) -> int:
    if not WorldConfig.is_frontier_profile():
        return Inventory.get_amount(kind)
    var source = _selected_cost_depot()
    if source == null or not is_depot_connected(source):
        return 0
    return Inventory.get_amount(kind) if String(source.id) == "keep" else source.stockpile_amount(kind)


func cost_reason(cost: Dictionary) -> String:
    if not WorldConfig.is_frontier_profile():
        return "" if Inventory.can_afford(cost) else "Bahan kurang di KEEP"
    var source = _selected_cost_depot()
    if source == null:
        return "Depot sumber biaya tidak tersedia"
    if not is_depot_connected(source):
        return "Jalur ke sumber biaya terputus"
    for kind in cost:
        var amount := int(cost[kind])
        if amount < 0:
            return "Biaya bahan tidak valid"
        if amount == 0:
            continue
        if String(source.id) != "keep" and not TRANSFER_KINDS.has(String(kind)):
            return "Jenis bahan tidak tersedia di depot lokal"
        var available: int = Inventory.get_amount(String(kind)) if String(source.id) == "keep" else int(source.stockpile_amount(String(kind)))
        if available < amount:
            return "Bahan kurang di " + cost_source_label()
    return ""


## Return unfinished construction materials to their original depot when possible.
## A missing or full remote depot falls back to the central Keep inventory.
func refund_cost_to_source(source_cell: Vector2i, refund: Dictionary) -> void:
    var source = _find_depot(source_cell)
    if source == null or not ["keep", "storage", "outpost"].has(String(source.id)):
        source = _find_keep()
    for kind in refund:
        var amount := int(refund[kind])
        if amount <= 0:
            continue
        if source != null and String(source.id) != "keep":
            if source.store_resource(String(kind), amount):
                continue
        Inventory.add(String(kind), amount)
    Events.supply_stock_changed.emit()


func can_pay_cost(cost: Dictionary) -> bool:
    return cost_reason(cost) == ""


func pay_cost(cost: Dictionary) -> bool:
    if cost_reason(cost) != "":
        return false
    var source = _selected_cost_depot()
    if not WorldConfig.is_frontier_profile() or source == null or String(source.id) == "keep":
        return Inventory.spend_all(cost)
    var paid: Dictionary = {}
    for kind in cost:
        var resource := String(kind)
        var amount := int(cost[kind])
        if amount <= 0:
            continue
        if not source.take_resource(resource, amount):
            for paid_kind in paid:
                source.store_resource(String(paid_kind), int(paid[paid_kind]))
            return false
        paid[resource] = amount
    Events.supply_stock_changed.emit()
    return true


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
    var active_orders := 0
    for order in shipment_orders:
        if _is_active_order(order):
            active_orders += 1
    if active_orders >= MAX_ACTIVE_SHIPMENTS:
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

    var order_id := _next_shipment_id
    _next_shipment_id += 1
    shipment_orders.append({
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
    var index := _order_index(order_id)
    if index < 0:
        return false
    var order: Dictionary = shipment_orders[index]
    if not _is_active_order(order):
        return false
    _remove_carrier(order_id)
    _recover_cargo(order, "cancelled")
    return true


func get_shipment_orders() -> Array[Dictionary]:
    return shipment_orders.duplicate(true)


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
    if not WorldConfig.is_frontier_profile():
        return
    _ensure_current()
    for index in range(shipment_orders.size()):
        var order: Dictionary = shipment_orders[index]
        if not _is_active_order(order):
            continue
        var destination = _find_depot(Vector2i(int(order["destination_x"]), int(order["destination_y"])))
        if destination == null:
            _remove_carrier(int(order["id"]))
            order = shipment_orders[index]
            _recover_cargo(order, "recovered")
            continue
        if not shipment_route_available(int(order["id"])):
            if String(order["status"]) == "in_transit":
                _remove_carrier(int(order["id"]))
                order = shipment_orders[index]
            order["status"] = "blocked"
            shipment_orders[index] = order
            continue
        var carrier = _carriers.get(int(order["id"]), null)
        if is_instance_valid(carrier):
            continue
        var start := Vector2(float(order["x"]), float(order["y"]))
        var courier = CARRIER_SCRIPT.new()
        if not courier.configure(self, nav, int(order["id"]), destination, start):
            order["status"] = "blocked"
            shipment_orders[index] = order
            continue
        world.entities.add_child(courier)
        _carriers[int(order["id"])] = courier
        order["status"] = "in_transit"
        shipment_orders[index] = order


func shipment_route_available(order_id: int) -> bool:
    var index := _order_index(order_id)
    if index < 0:
        return false
    var order: Dictionary = shipment_orders[index]
    var destination = _find_depot(Vector2i(int(order["destination_x"]), int(order["destination_y"])))
    if destination == null or not is_depot_connected(destination):
        return false
    # Source stock was already withdrawn. A destroyed source no longer blocks delivery.
    var source = _find_depot(Vector2i(int(order["source_x"]), int(order["source_y"])))
    return source == null or is_depot_connected(source)


func carrier_blocked(order_id: int, carrier_position: Vector2) -> void:
    var index := _order_index(order_id)
    if index < 0:
        return
    var order: Dictionary = shipment_orders[index]
    if not _is_active_order(order):
        return
    order["status"] = "blocked"
    order["x"] = carrier_position.x
    order["y"] = carrier_position.y
    shipment_orders[index] = order
    _carriers.erase(order_id)


func carrier_completed(order_id: int, carrier_position: Vector2) -> void:
    var index := _order_index(order_id)
    if index < 0:
        return
    var order: Dictionary = shipment_orders[index]
    if not _is_active_order(order):
        return
    if not shipment_route_available(order_id):
        carrier_blocked(order_id, carrier_position)
        return
    var destination = _find_depot(Vector2i(int(order["destination_x"]), int(order["destination_y"])))
    if destination == null:
        _recover_cargo(order, "recovered")
        shipment_orders[index] = order
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
    shipment_orders[index] = order
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
    var index := _order_index(int(order.get("id", -1)))
    if index >= 0:
        shipment_orders[index] = order
    _trim_shipment_history()


func _reserved_capacity(destination_cell: Vector2i) -> int:
    var reserved := 0
    for order in shipment_orders:
        if not _is_active_order(order):
            continue
        if int(order["destination_x"]) == destination_cell.x and int(order["destination_y"]) == destination_cell.y:
            reserved += int(order["cargo"])
    return reserved


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


func _order_index(order_id: int) -> int:
    for index in shipment_orders.size():
        if int(shipment_orders[index].get("id", -1)) == order_id:
            return index
    return -1


func _is_active_order(order: Dictionary) -> bool:
    return ["queued", "in_transit", "blocked"].has(String(order.get("status", ""))) and int(order.get("cargo", 0)) > 0


func _remove_carrier(order_id: int) -> void:
    var carrier = _carriers.get(order_id, null)
    if is_instance_valid(carrier):
        var index := _order_index(order_id)
        if index >= 0:
            var order: Dictionary = shipment_orders[index]
            order["x"] = carrier.position.x
            order["y"] = carrier.position.y
            shipment_orders[index] = order
        carrier.queue_free()
    _carriers.erase(order_id)


func _trim_shipment_history() -> void:
    while shipment_orders.size() > MAX_SHIPMENT_HISTORY:
        var removable := -1
        for index in shipment_orders.size():
            if not _is_active_order(shipment_orders[index]):
                removable = index
                break
        if removable < 0:
            return
        shipment_orders.remove_at(removable)


func export_state() -> Dictionary:
    var orders := shipment_orders.duplicate(true)
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
        "next_id": _next_shipment_id,
        "orders": orders,
        "cost_source": {"cx": source_cell.x, "cy": source_cell.y}
            if source_cell != Vector2i(-1, -1) else null,
        "pressure": pressure
    }


func import_state(value: Variant) -> void:
    shipment_orders.clear()
    _carriers.clear()
    _pressure_records.clear()
    _next_shipment_id = 1
    if not (value is Dictionary):
        return
    var orders: Variant = value.get("orders", [])
    if not (orders is Array):
        return
    for order in orders:
        if not (order is Dictionary):
            continue
        var restored: Dictionary = order.duplicate(true)
        if String(restored.get("status", "")) == "in_transit":
            restored["status"] = "blocked"
        shipment_orders.append(restored)
        _next_shipment_id = maxi(_next_shipment_id, int(restored.get("id", 0)) + 1)
    _next_shipment_id = maxi(_next_shipment_id, int(value.get("next_id", 1)))
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
    _dirty = false
    var roads: Dictionary = {}
    var keep_cells: Dictionary = {}

    for road in get_tree().get_nodes_in_group("roads"):
        if not is_instance_valid(road):
            continue
        for cell in road.cells():
            roads[cell] = road

    for building in get_tree().get_nodes_in_group("buildings"):
        if not is_instance_valid(building) or building.id != "keep":
            continue
        for cell in building.cells():
            keep_cells[cell] = true

    var connected: Dictionary = {}
    var queue: Array[Vector2i] = []
    for road_cell in roads:
        var cell: Vector2i = road_cell
        if _touches_any(cell, keep_cells):
            connected[cell] = true
            queue.append(cell)

    var cursor := 0
    while cursor < queue.size():
        var current := queue[cursor]
        cursor += 1
        for direction in DIRS4:
            var next := current + direction
            if not roads.has(next) or connected.has(next):
                continue
            connected[next] = true
            queue.append(next)

    connected_road_cells = connected
    _depot_connections.clear()
    for depot in get_tree().get_nodes_in_group("depots"):
        if not is_instance_valid(depot):
            continue
        var is_connected: bool = depot.id == "keep"
        if not is_connected:
            for cell in depot.cells():
                if _touches_any(cell, keep_cells) or _touches_any(cell, connected):
                    is_connected = true
                    break
        _depot_connections[depot.get_instance_id()] = is_connected


func _touches_any(cell: Vector2i, cells: Dictionary) -> bool:
    for direction in DIRS4:
        if cells.has(cell + direction):
            return true
    return false


func _ensure_current() -> void:
    if _dirty:
        rebuild()


func is_road_connected(cell: Vector2i) -> bool:
    _ensure_current()
    return connected_road_cells.has(cell)


func is_depot_connected(depot: Node) -> bool:
    _ensure_current()
    if depot == null or not is_instance_valid(depot):
        return false
    return bool(_depot_connections.get(depot.get_instance_id(), false))


func connected_road_count() -> int:
    _ensure_current()
    return connected_road_cells.size()


func connected_depot_count() -> int:
    _ensure_current()
    var count := 0
    for is_connected in _depot_connections.values():
        if bool(is_connected):
            count += 1
    return count
