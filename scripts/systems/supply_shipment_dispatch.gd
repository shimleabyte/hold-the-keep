extends RefCounted
## Shipment route/dispatch state machine.
## SupplyNetwork remains the owner of the order ledger, resource settlement and save API.

const CARRIER_SCRIPT := preload("res://scripts/entities/supply_carrier.gd")


func advance(network: Variant) -> void:
    if not WorldConfig.is_frontier_profile():
        return
    network._ensure_current()
    var ledger: Variant = network._shipment_ledger
    for index in range(ledger.orders.size()):
        var order: Dictionary = ledger.orders[index]
        if not ledger.is_active_order(order):
            continue
        var order_id := int(order["id"])
        var destination: Variant = network._find_depot(
            Vector2i(int(order["destination_x"]), int(order["destination_y"]))
        )
        if destination == null:
            network._remove_carrier(order_id)
            order = ledger.orders[index]
            network._recover_cargo(order, "recovered")
            continue
        if not route_available(network, order_id):
            if String(order["status"]) == "in_transit":
                network._remove_carrier(order_id)
                order = ledger.orders[index]
            order["status"] = "blocked"
            ledger.orders[index] = order
            continue

        var carrier: Variant = network._carriers.get(order_id, null)
        if is_instance_valid(carrier):
            continue
        var start := Vector2(float(order["x"]), float(order["y"]))
        var courier = CARRIER_SCRIPT.new()
        if not courier.configure(network, network.nav, order_id, destination, start):
            order["status"] = "blocked"
            ledger.orders[index] = order
            continue
        network.world.entities.add_child(courier)
        network._carriers[order_id] = courier
        order["status"] = "in_transit"
        ledger.orders[index] = order


func route_available(network: Variant, order_id: int) -> bool:
    var ledger = network._shipment_ledger
    var index: int = ledger.order_index(order_id)
    if index < 0:
        return false
    var order: Dictionary = ledger.orders[index]
    var destination = network._find_depot(
        Vector2i(int(order["destination_x"]), int(order["destination_y"]))
    )
    if destination == null or not network.is_depot_connected(destination):
        return false
    # Source and destination connectivity were validated before cargo left
    # the source. From this point onward, escrow belongs to the order; a later
    # origin disconnection must not strand queued, moving or saved cargo.
    return true


func carrier_blocked(network: Variant, order_id: int, carrier_position: Vector2) -> void:
    var ledger = network._shipment_ledger
    var index: int = ledger.order_index(order_id)
    if index < 0:
        return
    var order: Dictionary = ledger.orders[index]
    if not ledger.is_active_order(order):
        return
    order["status"] = "blocked"
    order["x"] = carrier_position.x
    order["y"] = carrier_position.y
    ledger.orders[index] = order
    network._carriers.erase(order_id)
