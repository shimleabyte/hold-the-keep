extends Node2D
## Territory claims projected from the Keep and Outposts onto the world grid.

const TILE_SIZE := 16
const MAP_SIZE := 64
const KEEP_RADIUS := 10.0

var world
var claimed_cells: Dictionary = {}
var _dirty := true


func _ready() -> void:
    z_index = 1
    Events.building_placed.connect(_mark_dirty)
    Events.building_removed.connect(_mark_dirty)
    Events.building_destroyed.connect(_mark_dirty)


func _mark_dirty(_id: String, _cell: Vector2i) -> void:
    _dirty = true


func _physics_process(_delta: float) -> void:
    if _dirty:
        rebuild()


func rebuild() -> void:
    _dirty = false
    var next: Dictionary = {}
    for building in get_tree().get_nodes_in_group("buildings"):
        if not is_instance_valid(building):
            continue
        var fallback := KEEP_RADIUS if building.id == "keep" else 0.0
        var radius := float(building.data.get("claim_radius", fallback))
        if radius <= 0.0:
            continue
        var center := Vector2(building.cell) + Vector2(building.size) / 2.0
        var min_x := maxi(0, floori(center.x - radius))
        var max_x := mini(MAP_SIZE - 1, ceili(center.x + radius))
        var min_y := maxi(0, floori(center.y - radius))
        var max_y := mini(MAP_SIZE - 1, ceili(center.y + radius))
        for y in range(min_y, max_y + 1):
            for x in range(min_x, max_x + 1):
                var tile_center := Vector2(x + 0.5, y + 0.5)
                if tile_center.distance_squared_to(center) <= radius * radius:
                    next[Vector2i(x, y)] = true
    claimed_cells = next
    Events.territory_changed.emit(claimed_cells.size())
    queue_redraw()


func _ensure_current() -> void:
    if _dirty:
        rebuild()


func is_claimed(cell: Vector2i) -> bool:
    _ensure_current()
    return claimed_cells.has(cell)


## Outposts must touch the existing frontier. Other buildings must fit entirely inside claims.
func can_place(id: String, anchor: Vector2i, size: Vector2i) -> bool:
    _ensure_current()
    if id == "outpost":
        for y in range(size.y):
            for x in range(size.x):
                if _touches_claim(anchor + Vector2i(x, y)):
                    return true
        return false
    for y in range(size.y):
        for x in range(size.x):
            if not claimed_cells.has(anchor + Vector2i(x, y)):
                return false
    return true


func _touches_claim(cell: Vector2i) -> bool:
    for y in range(-1, 2):
        for x in range(-1, 2):
            if claimed_cells.has(cell + Vector2i(x, y)):
                return true
    return false


func _draw() -> void:
    if _dirty or claimed_cells.is_empty():
        return
    var border := Color("#e3bf75")
    border.a = 0.42
    for cell in claimed_cells:
        var left := float(cell.x * TILE_SIZE)
        var top := float(cell.y * TILE_SIZE)
        var right := left + TILE_SIZE
        var bottom := top + TILE_SIZE
        if not claimed_cells.has(cell + Vector2i(0, -1)):
            draw_line(Vector2(left, top), Vector2(right, top), border, 1.0)
        if not claimed_cells.has(cell + Vector2i(0, 1)):
            draw_line(Vector2(left, bottom), Vector2(right, bottom), border, 1.0)
        if not claimed_cells.has(cell + Vector2i(-1, 0)):
            draw_line(Vector2(left, top), Vector2(left, bottom), border, 1.0)
        if not claimed_cells.has(cell + Vector2i(1, 0)):
            draw_line(Vector2(right, top), Vector2(right, bottom), border, 1.0)
