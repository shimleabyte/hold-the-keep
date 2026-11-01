extends Node2D
## Permanent exploration fog: unrevealed tiles are covered; discovered tiles remain mapped.

const TILE := 16
const MAP_SIZE := 64
const MAP_CELLS := MAP_SIZE * MAP_SIZE

var world
var player
var discovered := PackedByteArray()
var _scan_timer := 0.0


func _ready() -> void:
    add_to_group("fog_of_war")
    z_index = 100
    discovered.resize(MAP_CELLS)
    discovered.fill(0)
    _scan_sources()


func export_state() -> Dictionary:
    var cells: Array[int] = []
    for index in MAP_CELLS:
        if discovered[index] != 0:
            cells.append(index)
    return {"cells": cells}


func import_state(data: Dictionary) -> void:
    discovered.fill(0)
    var cells = data.get("cells", [])
    if cells is Array:
        for value in cells:
            var index := int(value)
            if index >= 0 and index < MAP_CELLS:
                discovered[index] = 1
    queue_redraw()


func _process(delta: float) -> void:
    _scan_timer -= delta
    if _scan_timer > 0.0:
        return
    _scan_timer = 0.25
    _scan_sources()


func is_revealed_cell(cell: Vector2i) -> bool:
    if cell.x < 0 or cell.y < 0 or cell.x >= MAP_SIZE or cell.y >= MAP_SIZE:
        return false
    return discovered[cell.y * MAP_SIZE + cell.x] != 0


func reveal_position(position_world: Vector2, radius: float) -> bool:
    var center := Vector2i((position_world / TILE).floor())
    var radius_tiles := ceili(radius / TILE)
    var changed := false
    for y in range(maxi(0, center.y - radius_tiles), mini(MAP_SIZE - 1, center.y + radius_tiles) + 1):
        for x in range(maxi(0, center.x - radius_tiles), mini(MAP_SIZE - 1, center.x + radius_tiles) + 1):
            var offset := Vector2(x + 0.5, y + 0.5) - Vector2(center) - Vector2(0.5, 0.5)
            if offset.length_squared() * TILE * TILE > radius * radius:
                continue
            var index := y * MAP_SIZE + x
            if discovered[index] == 0:
                discovered[index] = 1
                changed = true
    return changed


func _scan_sources() -> void:
    var changed := false
    if player != null and is_instance_valid(player):
        changed = reveal_position(player.global_position, 112.0) or changed
    for building in get_tree().get_nodes_in_group("buildings"):
        if building.id == "keep":
            changed = reveal_position(building.global_position, 160.0) or changed
        elif building.id == "outpost":
            changed = reveal_position(building.global_position, 144.0) or changed
    for villager in get_tree().get_nodes_in_group("villagers"):
        if villager.visible:
            changed = reveal_position(villager.global_position, 64.0) or changed
    if changed:
        queue_redraw()


func _draw() -> void:
    var unexplored := Color(0.012, 0.016, 0.024, 0.96)
    for y in MAP_SIZE:
        for x in MAP_SIZE:
            if discovered[y * MAP_SIZE + x] == 0:
                draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), unexplored)
