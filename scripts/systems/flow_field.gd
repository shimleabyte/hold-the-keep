extends Node
## Satu flow field untuk semua musuh: Dijkstra dari tile keep ke seluruh peta.
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

var _cost := PackedInt32Array()
var _next := PackedInt32Array()
var _dirty := true
var _heap_c := PackedInt32Array()
var _heap_i := PackedInt32Array()


func _ready() -> void:
    Events.building_placed.connect(_on_building_event)
    Events.building_removed.connect(_on_building_event)
    Events.building_destroyed.connect(_on_building_event)


func _on_building_event(_id: String, _cell: Vector2i) -> void:
    _dirty = true


func _physics_process(_delta: float) -> void:
    if _dirty:
        rebuild()


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
    if not world.is_buildable(c):
        return false
    var occ = world.occupied.get(c)
    return occ == null or _is_building(occ)


func _solid(c: Vector2i) -> bool:
    var occupant = world.occupied.get(c)
    var blocks_path: bool = occupant != null and not (is_instance_valid(occupant) and occupant.is_in_group("roads"))
    return not world.is_buildable(c) or blocks_path


func _penalty(c: Vector2i) -> int:
    var occ = world.occupied.get(c)
    if _is_building(occ) and occ.id != "keep" and occ.id != "road":
        return BUILD_PENALTY
    return 0


@warning_ignore("integer_division")
func rebuild() -> void:
    _dirty = false
    var n := WorldConfig.map_size * WorldConfig.map_size
    _cost.resize(n)
    _cost.fill(INF_COST)
    _next.resize(n)
    _next.fill(-1)
    _heap_c.clear()
    _heap_i.clear()

    for b in get_tree().get_nodes_in_group("buildings"):
        if b.id != "keep":
            continue
        target_pos = b.position + Vector2(0, -b.size.y * WorldConfig.tile_size / 2.0)
        for c in b.cells():
            var i := _idx(c)
            _cost[i] = 0
            _push(0, i)

    while _heap_c.size() > 0:
        var top := _pop()
        var c := top.x
        var i := top.y
        if c > _cost[i]:
            continue
        var here := Vector2i(i % WorldConfig.map_size, i / WorldConfig.map_size)
        var pen := _penalty(here)
        for d in DIRS:
            var nb := here + d
            if not _passable(nb):
                continue
            var diag := d.x != 0 and d.y != 0
            if diag and (_solid(here + Vector2i(d.x, 0)) or _solid(here + Vector2i(0, d.y))):
                continue
            var ni := _idx(nb)
            var nc := c + (DIAG if diag else STEP) + pen
            if nc < _cost[ni]:
                _cost[ni] = nc
                _next[ni] = i
                _push(nc, ni)


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
