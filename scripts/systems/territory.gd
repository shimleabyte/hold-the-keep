extends Node2D
## Territory claims projected from the Keep and Outposts onto the world grid.

var world
var claimed_cells: Dictionary = {}
var enemy_claimed_cells: Dictionary = {}
var _dirty := true


func _ready() -> void:
    z_index = 1
    Events.building_placed.connect(_mark_dirty)
    Events.building_removed.connect(_mark_dirty)
    Events.building_destroyed.connect(_mark_dirty)
    Events.enemy_stronghold_placed.connect(_mark_enemy_dirty)
    Events.enemy_stronghold_destroyed.connect(_mark_enemy_dirty)


func _mark_dirty(_id: String, _cell: Vector2i) -> void:
    _dirty = true


func _mark_enemy_dirty(_cell: Vector2i) -> void:
    _dirty = true


func _physics_process(_delta: float) -> void:
    if _dirty:
        rebuild()


func rebuild() -> void:
    _dirty = false
    var next: Dictionary = {}
    var enemy_next: Dictionary = {}
    for building in get_tree().get_nodes_in_group("buildings"):
        if not is_instance_valid(building):
            continue
        var fallback := WorldConfig.starting_claim_radius if building.id == "keep" else 0.0
        var radius := float(building.data.get("claim_radius", fallback))
        if radius <= 0.0:
            continue
        var center := Vector2(building.cell) + Vector2(building.size) / 2.0
        var min_x := maxi(0, floori(center.x - radius))
        var max_x := mini(WorldConfig.map_size - 1, ceili(center.x + radius))
        var min_y := maxi(0, floori(center.y - radius))
        var max_y := mini(WorldConfig.map_size - 1, ceili(center.y + radius))
        for y in range(min_y, max_y + 1):
            for x in range(min_x, max_x + 1):
                var tile_center := Vector2(x + 0.5, y + 0.5)
                if tile_center.distance_squared_to(center) <= radius * radius:
                    next[Vector2i(x, y)] = true
    for stronghold in get_tree().get_nodes_in_group("enemy_strongholds"):
        if not is_instance_valid(stronghold):
            continue
        var center := Vector2(stronghold.cell) + Vector2(stronghold.size) / 2.0
        var radius := float(stronghold.claim_radius)
        var min_x := maxi(0, floori(center.x - radius))
        var max_x := mini(WorldConfig.map_size - 1, ceili(center.x + radius))
        var min_y := maxi(0, floori(center.y - radius))
        var max_y := mini(WorldConfig.map_size - 1, ceili(center.y + radius))
        for y in range(min_y, max_y + 1):
            for x in range(min_x, max_x + 1):
                var tile_center := Vector2(x + 0.5, y + 0.5)
                if tile_center.distance_squared_to(center) <= radius * radius:
                    enemy_next[Vector2i(x, y)] = true
    claimed_cells = next
    enemy_claimed_cells = enemy_next
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
        var touches_frontier := false
        for y in range(size.y):
            for x in range(size.x):
                var cell := anchor + Vector2i(x, y)
                if enemy_claimed_cells.has(cell):
                    return false
                if _is_frontier_cell(cell):
                    touches_frontier = true
        return touches_frontier
    for y in range(size.y):
        for x in range(size.x):
            var cell := anchor + Vector2i(x, y)
            if not claimed_cells.has(cell) or enemy_claimed_cells.has(cell):
                return false
    return true


func _is_frontier_cell(cell: Vector2i) -> bool:
    return not claimed_cells.has(cell) and not enemy_claimed_cells.has(cell) and _touches_claim(cell)


func owner_at(cell: Vector2i) -> String:
    _ensure_current()
    var player_owns := claimed_cells.has(cell)
    var enemy_owns := enemy_claimed_cells.has(cell)
    if player_owns and enemy_owns:
        return "contested"
    if player_owns:
        return "player"
    if enemy_owns:
        return "enemy"
    return "neutral"


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
        var left := float(cell.x * WorldConfig.tile_size)
        var top := float(cell.y * WorldConfig.tile_size)
        var right := left + WorldConfig.tile_size
        var bottom := top + WorldConfig.tile_size
        if not claimed_cells.has(cell + Vector2i(0, -1)):
            draw_line(Vector2(left, top), Vector2(right, top), border, 1.0)
        if not claimed_cells.has(cell + Vector2i(0, 1)):
            draw_line(Vector2(left, bottom), Vector2(right, bottom), border, 1.0)
        if not claimed_cells.has(cell + Vector2i(-1, 0)):
            draw_line(Vector2(left, top), Vector2(left, bottom), border, 1.0)
        if not claimed_cells.has(cell + Vector2i(1, 0)):
            draw_line(Vector2(right, top), Vector2(right, bottom), border, 1.0)
    var enemy_border := Color("#b84b43", 0.48)
    for cell in enemy_claimed_cells:
        var left := float(cell.x * WorldConfig.tile_size)
        var top := float(cell.y * WorldConfig.tile_size)
        var right := left + WorldConfig.tile_size
        var bottom := top + WorldConfig.tile_size
        if not enemy_claimed_cells.has(cell + Vector2i(0, -1)):
            draw_line(Vector2(left, top), Vector2(right, top), enemy_border, 1.0)
        if not enemy_claimed_cells.has(cell + Vector2i(0, 1)):
            draw_line(Vector2(left, bottom), Vector2(right, bottom), enemy_border, 1.0)
        if not enemy_claimed_cells.has(cell + Vector2i(-1, 0)):
            draw_line(Vector2(left, top), Vector2(left, bottom), enemy_border, 1.0)
        if not enemy_claimed_cells.has(cell + Vector2i(1, 0)):
            draw_line(Vector2(right, top), Vector2(right, bottom), enemy_border, 1.0)
