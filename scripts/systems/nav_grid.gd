extends Node
## A* grid untuk villager. Pohon, batu, air, dan semua bangunan = solid.
## Dibangun ulang saat bangunan berubah; `version` naik tiap rebuild.

const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var world
var astar := AStarGrid2D.new()
var version := 0

var _dirty := true
var _dirty_cells: Dictionary = {}


func _ready() -> void:
    add_to_group("navigation_grid")
    astar.region = Rect2i(0, 0, WorldConfig.map_size, WorldConfig.map_size)
    astar.cell_size = Vector2(WorldConfig.tile_size, WorldConfig.tile_size)
    astar.offset = Vector2(WorldConfig.tile_size / 2.0, WorldConfig.tile_size / 2.0)
    astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
    astar.update()
    Events.building_placed.connect(_on_building_event)
    Events.building_removed.connect(_on_building_event)
    Events.building_destroyed.connect(_on_building_event)


func _on_building_event(id: String, cell: Vector2i) -> void:
    if _dirty:
        return
    var definition: Dictionary = DataDB.buildings.get(id, {})
    var footprint: Variant = definition.get("size", [1, 1])
    var width := 1
    var height := 1
    if footprint is Array and footprint.size() >= 2:
        width = maxi(1, int(footprint[0]))
        height = maxi(1, int(footprint[1]))
    for y in height:
        for x in width:
            _dirty_cells[cell + Vector2i(x, y)] = true


func _physics_process(_delta: float) -> void:
    if _dirty:
        rebuild()
    elif not _dirty_cells.is_empty():
        _rebuild_dirty_cells()


func _set_cell_solid(cell: Vector2i) -> void:
    if cell.x < 0 or cell.y < 0 or cell.x >= WorldConfig.map_size or cell.y >= WorldConfig.map_size:
        return
    var occupant = world.occupied.get(cell)
    var is_bridge: bool = occupant != null and is_instance_valid(occupant) and occupant.is_in_group("buildings") and String(occupant.id) == "bridge"
    var blocks_path: bool = occupant != null and not (is_instance_valid(occupant) and occupant.is_in_group("roads"))
    astar.set_point_solid(cell, (not world.is_buildable(cell) and not is_bridge) or blocks_path)


func rebuild() -> void:
    _dirty = false
    _dirty_cells.clear()
    for y in WorldConfig.map_size:
        for x in WorldConfig.map_size:
            _set_cell_solid(Vector2i(x, y))
    version += 1


func _rebuild_dirty_cells() -> void:
    for cell_value in _dirty_cells:
        _set_cell_solid(cell_value)
    _dirty_cells.clear()
    version += 1


func cell_of(pos: Vector2) -> Vector2i:
    return Vector2i((pos / WorldConfig.tile_size).floor())


func center_of(c: Vector2i) -> Vector2:
    return Vector2(c) * WorldConfig.tile_size + Vector2(WorldConfig.tile_size / 2.0, WorldConfig.tile_size / 2.0)


func is_walkable(c: Vector2i) -> bool:
    return c.x >= 0 and c.y >= 0 and c.x < WorldConfig.map_size and c.y < WorldConfig.map_size and not astar.is_point_solid(c)


## Cardinally connected walkable cells from a start tile. Shared by world placement and logistics.
func reachable_cells(start: Vector2i) -> Dictionary:
    var visited: Dictionary = {}
    if not is_walkable(start):
        return visited

    var queue: Array[Vector2i] = [start]
    visited[start] = true
    var cursor := 0
    while cursor < queue.size():
        var current := queue[cursor]
        cursor += 1
        for direction in DIRS4:
            var next := current + direction
            if visited.has(next) or not is_walkable(next):
                continue
            visited[next] = true
            queue.append(next)
    return visited


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
    # A resource occupies one tile and may be approached from any of its four
    # cardinal sides. Checking only three can reject the sole reachable side.
    for i in mini(4, cands.size()):
        var p := astar.get_point_path(s, cands[i])
        if not p.is_empty():
            return p
    return PackedVector2Array()
