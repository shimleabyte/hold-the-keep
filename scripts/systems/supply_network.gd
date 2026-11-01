extends Node
## Road-connected logistics. Roads are walkable infrastructure, not blockers.
## A depot is connected when its footprint touches the Keep or a road component
## that reaches the Keep footprint.

const DIRS4: Array[Vector2i] = [
    Vector2i(1, 0), Vector2i(-1, 0),
    Vector2i(0, 1), Vector2i(0, -1)
]
const TRANSFER_INTERVAL := 3.0
const TRANSFER_BUDGET_PER_DEPOT := 6
const TRANSFER_KINDS: Array[String] = ["wood", "stone", "food", "iron"]

var world
var connected_road_cells: Dictionary = {}
var _depot_connections: Dictionary = {}
var _dirty := true
var _transfer_timer := 0.0
var _transfer_cursor := 0


func _ready() -> void:
    add_to_group("supply_network")
    Events.building_placed.connect(_on_building_event)
    Events.building_removed.connect(_on_building_event)
    Events.building_destroyed.connect(_on_building_event)


func _on_building_event(_id: String, _cell: Vector2i) -> void:
    _dirty = true


func _physics_process(_delta: float) -> void:
    if _dirty:
        rebuild()


func _process(delta: float) -> void:
    if WorldConfig.profile_id != "frontier":
        return
    _transfer_timer += delta
    if _transfer_timer < TRANSFER_INTERVAL:
        return
    _transfer_timer = 0.0
    transfer_local_stockpiles()


## Move a bounded amount from each connected remote depot into the Keep inventory.
## This is an automatic road-network shipment; disconnected stock remains at its source.
func transfer_local_stockpiles() -> int:
    if WorldConfig.profile_id != "frontier":
        return 0
    _ensure_current()
    var depots: Array = get_tree().get_nodes_in_group("depots")
    depots.sort_custom(func(a, b) -> bool:
        if a.cell.y == b.cell.y:
            return a.cell.x < b.cell.x
        return a.cell.y < b.cell.y
    )
    var keep = null
    for depot in depots:
        if is_instance_valid(depot) and String(depot.id) == "keep":
            keep = depot
            break
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
