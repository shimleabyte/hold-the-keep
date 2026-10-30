extends Node
## Sumber daya pemain. Nanti dipindah ke gudang/bangunan.

const START_ITEMS := {"wood": 25, "stone": 0, "food": 12, "iron": 0}

var items: Dictionary = START_ITEMS.duplicate()


func reset() -> void:
    items = START_ITEMS.duplicate()


func add(kind: String, amount: int = 1) -> void:
    items[kind] = get_amount(kind) + amount
    Events.resource_changed.emit(kind, items[kind])


func get_amount(kind: String) -> int:
    return items.get(kind, 0)


func spend(kind: String, amount: int) -> bool:
    if get_amount(kind) < amount:
        return false
    items[kind] -= amount
    Events.resource_changed.emit(kind, items[kind])
    return true


func can_afford(cost: Dictionary) -> bool:
    for k in cost:
        if get_amount(k) < int(cost[k]):
            return false
    return true


func spend_all(cost: Dictionary) -> bool:
    if not can_afford(cost):
        return false
    for k in cost:
        spend(k, int(cost[k]))
    return true
