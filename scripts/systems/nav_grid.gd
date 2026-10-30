extends Node
## A* grid untuk villager. Pohon, batu, air, dan semua bangunan = solid.
## Dibangun ulang saat bangunan berubah; `version` naik tiap rebuild.

const MAP_SIZE := 64
const TILE := 16
const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var world
var astar := AStarGrid2D.new()
var version := 0

var _dirty := true


func _ready() -> void:
    astar.region = Rect2i(0, 0, MAP_SIZE, MAP_SIZE)
    astar.cell_size = Vector2(TILE, TILE)
    astar.offset = Vector2(TILE / 2.0, TILE / 2.0)
    astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
    astar.update()
    Events.building_placed.connect(_on_building_event)
    Events.building_removed.connect(_on_building_event)
    Events.building_destroyed.connect(_on_building_event)


func _on_building_event(_id: String, _cell: Vector2i) -> void:
    _dirty = true


func _physics_process(_delta: float) -> void:
    if _dirty:
        rebuild()


func rebuild() -> void:
    _dirty = false
    for y in MAP_SIZE:
        for x in MAP_SIZE:
            var c := Vector2i(x, y)
            astar.set_point_solid(c, not world.is_buildable(c) or world.occupied.get(c) != null)
    version += 1


func cell_of(pos: Vector2) -> Vector2i:
    return Vector2i((pos / TILE).floor())


func center_of(c: Vector2i) -> Vector2:
    return Vector2(c) * TILE + Vector2(TILE / 2.0, TILE / 2.0)


func is_walkable(c: Vector2i) -> bool:
    return c.x >= 0 and c.y >= 0 and c.x < MAP_SIZE and c.y < MAP_SIZE and not astar.is_point_solid(c)


func _nearest_free(c: Vector2i) -> Vector2i:
    if is_walkable(c):
        return c
    for r in range(1, 4):
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                var n := c + Vector2i(dx, dy)
                if is_walkable(n):
                    return n
    return Vector2i(-1, -1)


## Jalur ke tile persis (atau tile bebas terdekat).
func path_to(from_pos: Vector2, to_cell: Vector2i) -> PackedVector2Array:
    var s := _nearest_free(cell_of(from_pos))
    var g := _nearest_free(to_cell)
    if s.x < 0 or g.x < 0:
        return PackedVector2Array()
    return astar.get_point_path(s, g)


## Jalur ke tile bebas yang bersebelahan dengan salah satu `cells` (pohon, gudang, ladang).
func path_adjacent(from_pos: Vector2, cells: Array[Vector2i]) -> PackedVector2Array:
    var s := _nearest_free(cell_of(from_pos))
    if s.x < 0:
        return PackedVector2Array()
    var cands: Array[Vector2i] = []
    for c in cells:
        for d in DIRS4:
            var n := c + d
            if is_walkable(n) and not cands.has(n):
                cands.append(n)
    cands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a - s).length_squared() < Vector2(b - s).length_squared())
    for i in mini(3, cands.size()):
        var p := astar.get_point_path(s, cands[i])
        if not p.is_empty():
            return p
    return PackedVector2Array()
