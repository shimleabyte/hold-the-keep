extends Node2D
## Territory claims projected from the Keep and Outposts onto the world grid.

var world
var claimed_cells: Dictionary = {}
var enemy_claimed_cells: Dictionary = {}
var region_states: Dictionary = {}
var conquered_regions: Dictionary = {}
var _dirty := true
var _region_land_cells: Dictionary = {}
var _land_region_by_cell: Dictionary = {}
var _land_index_ready := false


func _ready() -> void:
    z_index = 1
    _build_region_land_index()
    if world != null and world.has_signal("buildable_cells_changed"):
        world.buildable_cells_changed.connect(_on_buildable_cells_changed)
    Events.building_placed.connect(_mark_dirty)
    Events.building_removed.connect(_mark_dirty)
    Events.building_destroyed.connect(_mark_dirty)
    Events.enemy_stronghold_placed.connect(_mark_enemy_dirty)
    Events.enemy_stronghold_destroyed.connect(_mark_enemy_dirty)
    Events.campaign_objective_completed.connect(_on_campaign_objective_completed)


func _mark_dirty(id: String, _cell: Vector2i) -> void:
    var definition: Dictionary = DataDB.buildings.get(id, {})
    var fallback := WorldConfig.starting_claim_radius if id == "keep" else 0.0
    if float(definition.get("claim_radius", fallback)) > 0.0:
        _dirty = true


func _mark_enemy_dirty(_cell: Vector2i) -> void:
    _dirty = true


func _build_region_land_index() -> void:
    _region_land_cells.clear()
    _land_region_by_cell.clear()
    if world == null:
        _land_index_ready = false
        return

    # Terrain and region labels are static for a campaign except for Expedition
    # survey gates. Cache the land topology once instead of asking TileMapLayer
    # and WorldMap for every cell on every ownership refresh.
    for y in WorldConfig.map_size:
        for x in WorldConfig.map_size:
            var cell := Vector2i(x, y)
            if not world.is_buildable(cell):
                continue
            var region_id: String = world.region_id(cell)
            if not _region_land_cells.has(region_id):
                _region_land_cells[region_id] = []
            var region_cells: Array = _region_land_cells[region_id]
            region_cells.append(cell)
            _region_land_cells[region_id] = region_cells
            _land_region_by_cell[cell] = region_id
    _land_index_ready = true


func _on_buildable_cells_changed(cells: Array[Vector2i]) -> void:
    if not _land_index_ready:
        _build_region_land_index()
    for cell in cells:
        var was_indexed := _land_region_by_cell.has(cell)
        var is_buildable: bool = world.is_buildable(cell)
        if was_indexed == is_buildable:
            continue
        if is_buildable:
            var region_id: String = world.region_id(cell)
            if not _region_land_cells.has(region_id):
                _region_land_cells[region_id] = []
            var region_cells: Array = _region_land_cells[region_id]
            region_cells.append(cell)
            _region_land_cells[region_id] = region_cells
            _land_region_by_cell[cell] = region_id
        else:
            var previous_region: String = String(_land_region_by_cell[cell])
            var previous_cells: Array = _region_land_cells.get(previous_region, [])
            previous_cells.erase(cell)
            _region_land_cells[previous_region] = previous_cells
            _land_region_by_cell.erase(cell)
    _dirty = true


func _on_campaign_objective_completed(_stronghold_id: String, region_id: String) -> void:
    if not region_id.is_empty():
        conquered_regions[region_id] = true
        _dirty = true


func _physics_process(_delta: float) -> void:
    if _dirty:
        rebuild()


func rebuild() -> void:
    if not _land_index_ready:
        _build_region_land_index()
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
    # A conquered region becomes player-controlled land, not merely neutral land
    # after its last stronghold is removed. Reuse the indexed land cells rather
    # than scanning the entire tile map again.
    for region_value in conquered_regions:
        var region_id := String(region_value)
        var region_cells: Array = _region_land_cells.get(region_id, [])
        for cell in region_cells:
            next[cell] = true
            enemy_next.erase(cell)
    claimed_cells = next
    enemy_claimed_cells = enemy_next
    _rebuild_region_states()
    Events.territory_changed.emit(claimed_cells.size())
    queue_redraw()


func _rebuild_region_states() -> void:
    var next_states: Dictionary = {}
    for region_value in _region_land_cells:
        var region_id := String(region_value)
        var region_cells: Array = _region_land_cells[region_id]
        next_states[region_id] = {
            "id": region_id,
            "land_cells": region_cells.size(),
            "player_cells": 0,
            "enemy_cells": 0,
            "contested_cells": 0
        }

    # Only claim cells carry ownership. Count those against the cached land
    # region rather than revisiting every water/land tile on the map.
    for cell_value in claimed_cells:
        var cell: Vector2i = cell_value
        var region_id := String(_land_region_by_cell.get(cell, ""))
        if region_id.is_empty():
            continue
        var region: Dictionary = next_states[region_id]
        region["player_cells"] = int(region["player_cells"]) + 1
        if enemy_claimed_cells.has(cell):
            region["contested_cells"] = int(region["contested_cells"]) + 1
        next_states[region_id] = region

    for cell_value in enemy_claimed_cells:
        var cell: Vector2i = cell_value
        var region_id := String(_land_region_by_cell.get(cell, ""))
        if region_id.is_empty():
            continue
        var region: Dictionary = next_states[region_id]
        region["enemy_cells"] = int(region["enemy_cells"]) + 1
        next_states[region_id] = region

    for region_id in next_states:
        var region: Dictionary = next_states[region_id]
        var land := maxi(1, int(region["land_cells"]))
        var player_share := float(region["player_cells"]) / land
        var enemy_share := float(region["enemy_cells"]) / land
        var contested_share := float(region["contested_cells"]) / land
        var control := "neutral"
        if contested_share >= 0.06 or (player_share >= 0.12 and enemy_share >= 0.12):
            control = "contested"
        elif player_share >= 0.30 and player_share - enemy_share >= 0.12:
            control = "player"
        elif enemy_share >= 0.30 and enemy_share - player_share >= 0.12:
            control = "enemy"

        region["player_ratio"] = player_share
        region["enemy_ratio"] = enemy_share
        region["contested_ratio"] = contested_share
        region["control"] = control
        next_states[region_id] = region

        var previous: Dictionary = region_states.get(region_id, {})
        if String(previous.get("control", "")) != control:
            Events.region_control_changed.emit(region_id, control)

    region_states = next_states


func region_ids() -> Array[String]:
    _ensure_current()
    var ids: Array[String] = []
    for region_id in region_states:
        ids.append(String(region_id))
    ids.sort()
    return ids


func get_region_state(region_id: String) -> Dictionary:
    _ensure_current()
    return region_states.get(region_id, {}).duplicate(true)


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
