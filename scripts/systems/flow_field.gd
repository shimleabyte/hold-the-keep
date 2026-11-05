extends Node
## Satu flow field untuk semua musuh: Dijkstra dari tile keep ke seluruh peta.

signal rebuilt(version: int)
## Tembok/bangunan boleh "dilewati" dengan biaya tinggi (musuh akan menghancurkannya);
## pohon, batu, dan air tidak bisa dilewati.

const INF_COST := 1000000000
const STEP := 10
const DIAG := 14
const BUILD_PENALTY := 60
const DIRS: Array[Vector2i] = [
    Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
    Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

var world
var target_pos := Vector2.ZERO
var version := 0

var _cost := PackedInt32Array()
var _next := PackedInt32Array()
const DEFAULT_REBUILD_POPS_PER_FRAME := 2048
const DEFAULT_REBUILD_BUDGET_USEC := 2500

var _dirty := true
var _heap_c := PackedInt32Array()
var _heap_i := PackedInt32Array()
var _build_cost := PackedInt32Array()
var _build_next := PackedInt32Array()
var _build_target_pos := Vector2.ZERO
var _build_active := false
var _requested_revision := 0
var _build_revision := -1

# Public for deterministic diagnostics; production uses the defaults.
var rebuild_pops_per_frame := DEFAULT_REBUILD_POPS_PER_FRAME
var rebuild_budget_usec := DEFAULT_REBUILD_BUDGET_USEC


func _ready() -> void:
    Events.building_placed.connect(_on_building_event)
    Events.building_removed.connect(_on_building_event)
    Events.building_destroyed.connect(_on_building_event)


func _on_building_event(id: String, _cell: Vector2i) -> void:
    # A road neither blocks cells nor changes flow-field traversal cost.
    if id == "road":
        return
    _requested_revision += 1
    _dirty = true


func _physics_process(_delta: float) -> void:
    if _dirty:
        _begin_rebuild()
    if _build_active:
        _process_rebuild_budget()


func rebuild() -> void:
    # Keep the public refresh entry point non-blocking.
    _requested_revision += 1
    _dirty = true


func is_current() -> bool:
    return version > 0 and not _dirty and not _build_active


func _begin_rebuild() -> void:
    _dirty = false
    _build_active = true
    _build_revision = _requested_revision
    _build_target_pos = target_pos
    var n := WorldConfig.map_size * WorldConfig.map_size
    _build_cost.resize(n)
    _build_cost.fill(INF_COST)
    _build_next.resize(n)
    _build_next.fill(-1)
    _heap_c.clear()
    _heap_i.clear()

    for building in get_tree().get_nodes_in_group("buildings"):
        if String(building.id) != "keep":
            continue
        _build_target_pos = building.position + Vector2(
            0, -building.size.y * WorldConfig.tile_size / 2.0
        )
        for cell in building.cells():
            var index := _idx(cell)
            if index < 0:
                continue
            _build_cost[index] = 0
            _push(0, index)


func _process_rebuild_budget() -> void:
    var processed := 0
    var pop_limit := maxi(1, rebuild_pops_per_frame)
    var time_budget_usec := maxi(1, rebuild_budget_usec)
    var started_usec := Time.get_ticks_usec()
    while _heap_c.size() > 0 and processed < pop_limit:
        # One heap pop is the smallest indivisible unit. Check the elapsed-time
        # budget between pops so a large map cannot monopolize a physics frame.
        if processed > 0 and Time.get_ticks_usec() - started_usec >= time_budget_usec:
            break
        var top := _pop()
        var cost := top.x
        var index := top.y
        processed += 1
        if cost > _build_cost[index]:
            continue
        var here := Vector2i(index % WorldConfig.map_size, index / WorldConfig.map_size)
        var penalty := _penalty(here)
        for direction in DIRS:
            var neighbor := here + direction
            if not _passable(neighbor):
                continue
            var diagonal := direction.x != 0 and direction.y != 0
            if diagonal and (
                _solid(here + Vector2i(direction.x, 0))
                or _solid(here + Vector2i(0, direction.y))
            ):
                continue
            var neighbor_index := _idx(neighbor)
            if neighbor_index < 0:
                continue
            var next_cost := cost + (DIAG if diagonal else STEP) + penalty
            if next_cost < _build_cost[neighbor_index]:
                _build_cost[neighbor_index] = next_cost
                _build_next[neighbor_index] = index
                _push(next_cost, neighbor_index)

    if not _heap_c.is_empty():
        return

    # Never publish a field computed against an obsolete occupancy snapshot.
    if _dirty or _build_revision != _requested_revision:
        _build_active = false
        _dirty = true
        return

    _cost = _build_cost
    _next = _build_next
    target_pos = _build_target_pos
    _build_cost = PackedInt32Array()
    _build_next = PackedInt32Array()
    _build_active = false
    version += 1
    rebuilt.emit(version)


func is_reachable(cell: Vector2i) -> bool:
    var i := _idx(cell)
    return i >= 0 and i < _cost.size() and _cost[i] < INF_COST


## Tile berikutnya menuju keep. Mengembalikan `cell` sendiri jika tidak ada jalur.
func next_cell(cell: Vector2i) -> Vector2i:
    var i := _idx(cell)
    if i < 0 or i >= _next.size() or _next[i] < 0:
        return cell
    return Vector2i(_next[i] % WorldConfig.map_size, _next[i] / WorldConfig.map_size)


func _idx(c: Vector2i) -> int:
    if c.x < 0 or c.y < 0 or c.x >= WorldConfig.map_size or c.y >= WorldConfig.map_size:
        return -1
    return c.y * WorldConfig.map_size + c.x


func _is_building(n) -> bool:
    return n != null and is_instance_valid(n) and n.is_in_group("buildings")


func _passable(c: Vector2i) -> bool:
    var occ = world.occupied.get(c)
    var is_bridge: bool = _is_building(occ) and String(occ.id) == "bridge"
    if not world.is_buildable(c) and not is_bridge:
        return false
    return occ == null or _is_building(occ)


func _solid(c: Vector2i) -> bool:
    var occupant = world.occupied.get(c)
    var is_bridge: bool = _is_building(occupant) and String(occupant.id) == "bridge"
    var blocks_path: bool = occupant != null and not (is_instance_valid(occupant) and occupant.is_in_group("roads"))
    return (not world.is_buildable(c) and not is_bridge) or blocks_path


func _penalty(c: Vector2i) -> int:
    var occ = world.occupied.get(c)
    if _is_building(occ) and not occ.is_in_group("roads") and occ.id != "keep":
        return BUILD_PENALTY
    return 0


func _swap(a: int, b: int) -> void:
    var tc := _heap_c[a]
    var ti := _heap_i[a]
    _heap_c[a] = _heap_c[b]
    _heap_i[a] = _heap_i[b]
    _heap_c[b] = tc
    _heap_i[b] = ti


func _push(c: int, i: int) -> void:
    _heap_c.append(c)
    _heap_i.append(i)
    var k := _heap_c.size() - 1
    while k > 0:
        var p := (k - 1) >> 1
        if _heap_c[p] <= _heap_c[k]:
            break
        _swap(p, k)
        k = p


func _pop() -> Vector2i:
    var res := Vector2i(_heap_c[0], _heap_i[0])
    var last := _heap_c.size() - 1
    _heap_c[0] = _heap_c[last]
    _heap_i[0] = _heap_i[last]
    _heap_c.resize(last)
    _heap_i.resize(last)
    var k := 0
    while true:
        var l := 2 * k + 1
        var r := l + 1
        var m := k
        if l < last and _heap_c[l] < _heap_c[m]:
            m = l
        if r < last and _heap_c[r] < _heap_c[m]:
            m = r
        if m == k:
            break
        _swap(k, m)
        k = m
    return res
