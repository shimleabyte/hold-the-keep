extends RefCounted
## Owns Keep-rooted road connectivity and depot reachability.
## SupplyNetwork remains the compatibility façade for callers and gameplay systems.

const DIRS4: Array[Vector2i] = [
    Vector2i(1, 0), Vector2i(-1, 0),
    Vector2i(0, 1), Vector2i(0, -1)
]

var connected_road_cells: Dictionary = {}
var depot_connections: Dictionary = {}
var dirty := true


func invalidate() -> void:
    dirty = true


func rebuild(network: Variant) -> void:
    dirty = false
    var roads: Dictionary = {}
    var keep_cells: Dictionary = {}

    for road in network.get_tree().get_nodes_in_group("roads"):
        if not is_instance_valid(road):
            continue
        for cell in road.cells():
            roads[cell] = road

    for building in network.get_tree().get_nodes_in_group("buildings"):
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
    depot_connections.clear()
    for depot in network.get_tree().get_nodes_in_group("depots"):
        if not is_instance_valid(depot):
            continue
        var is_connected: bool = depot.id == "keep"
        if not is_connected:
            for cell in depot.cells():
                if _touches_any(cell, keep_cells) or _touches_any(cell, connected):
                    is_connected = true
                    break
        depot_connections[depot.get_instance_id()] = is_connected


func _touches_any(cell: Vector2i, cells: Dictionary) -> bool:
    for direction in DIRS4:
        if cells.has(cell + direction):
            return true
    return false


func ensure_current(network: Variant) -> void:
    if dirty:
        rebuild(network)


func is_road_connected(network: Variant, cell: Vector2i) -> bool:
    ensure_current(network)
    return connected_road_cells.has(cell)


func is_depot_connected(network: Variant, depot: Node) -> bool:
    ensure_current(network)
    if depot == null or not is_instance_valid(depot):
        return false
    return bool(depot_connections.get(depot.get_instance_id(), false))


func connected_road_count(network: Variant) -> int:
    ensure_current(network)
    return connected_road_cells.size()


func connected_depot_count(network: Variant) -> int:
    ensure_current(network)
    var count := 0
    for is_connected in depot_connections.values():
        if bool(is_connected):
            count += 1
    return count
