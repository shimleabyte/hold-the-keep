extends RefCounted
## Owns shipment order identity, escrow ledger records and bounded history.
## SupplyNetwork remains responsible for routing, carriers and resource settlement.

const MAX_HISTORY := 16
const ACTIVE_STATUSES: Array[String] = ["queued", "in_transit", "blocked"]

var orders: Array[Dictionary] = []
var next_id := 1


func allocate_id() -> int:
    var order_id := next_id
    next_id += 1
    return order_id


func append_order(order: Dictionary) -> void:
    orders.append(order.duplicate(true))
    trim_history()


func snapshot() -> Array[Dictionary]:
    return orders.duplicate(true)


func order_index(order_id: int) -> int:
    for index in orders.size():
        if int(orders[index].get("id", -1)) == order_id:
            return index
    return -1


func is_active_order(order: Dictionary) -> bool:
    return ACTIVE_STATUSES.has(String(order.get("status", ""))) and int(order.get("cargo", 0)) > 0


func active_count() -> int:
    var count := 0
    for order in orders:
        if is_active_order(order):
            count += 1
    return count


func reserved_capacity(destination_cell: Vector2i) -> int:
    var reserved := 0
    for order in orders:
        if not is_active_order(order):
            continue
        if int(order.get("destination_x", -1)) == destination_cell.x and int(order.get("destination_y", -1)) == destination_cell.y:
            reserved += int(order.get("cargo", 0))
    return reserved


func trim_history() -> void:
    while orders.size() > MAX_HISTORY:
        var removable := -1
        for index in orders.size():
            if not is_active_order(orders[index]):
                removable = index
                break
        if removable < 0:
            return
        orders.remove_at(removable)


func clear() -> void:
    orders.clear()
    next_id = 1


func restore(saved_orders: Array, saved_next_id: int) -> void:
    clear()
    for saved_order in saved_orders:
        if not (saved_order is Dictionary):
            continue
        var restored: Dictionary = saved_order.duplicate(true)
        if String(restored.get("status", "")) == "in_transit":
            restored["status"] = "blocked"
        orders.append(restored)
        next_id = maxi(next_id, int(restored.get("id", 0)) + 1)
    next_id = maxi(next_id, saved_next_id)
    trim_history()
