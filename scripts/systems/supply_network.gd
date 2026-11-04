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
const PRESSURE_MANAGER_SCRIPT := preload("res://scripts/systems/supply_pressure_manager.gd")

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
var _pressure_manager = PRESSURE_MANAGER_SCRIPT.new()
var _pressure_records: Dictionary:
    get:
        return _pressure_manager.pressure_records
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
    _pressure_manager.process(self, delta)


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


func depot_pressure_state(depot: Node) -> Dictionary:
    return _pressure_manager.depot_pressure_state(self, depot)


func advance_supply_pressure(delta: float) -> void:
    _pressure_manager.advance(self, delta)


func raid_steal_from(depot: Node) -> String:
    return _pressure_manager.raid_steal_from(depot)


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
    var pressure: Array[Dictionary] = _pressure_manager.export_records()
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
    _pressure_manager.clear_records()
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
    _pressure_manager.restore_records(self, value.get("pressure", []))
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
