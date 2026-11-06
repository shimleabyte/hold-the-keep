class_name FogOfWar
extends Node2D
## Permanent exploration fog rendered as independently invalidated chunks.

const CHUNK_CELLS := 16


class FogChunk extends Node2D:
    const COVER_COLOR := Color(0.012, 0.016, 0.024, 0.96)

    var fog_owner: Node
    var chunk_origin := Vector2i.ZERO
    var chunk_cells := 16
    var map_size := 64
    var tile_size := 16

    func _draw() -> void:
        if not is_instance_valid(fog_owner):
            return
        var explored: PackedByteArray = fog_owner.get("discovered")
        var end_x := mini(chunk_origin.x + chunk_cells, map_size)
        var end_y := mini(chunk_origin.y + chunk_cells, map_size)
        for y in range(chunk_origin.y, end_y):
            var run_start := -1
            for x in range(chunk_origin.x, end_x + 1):
                var hidden := false
                if x < end_x:
                    hidden = explored[y * map_size + x] == 0
                if hidden:
                    if run_start < 0:
                        run_start = x
                elif run_start >= 0:
                    var rect := Rect2(
                        Vector2(
                            (run_start - chunk_origin.x) * tile_size,
                            (y - chunk_origin.y) * tile_size
                        ),
                        Vector2((x - run_start) * tile_size, tile_size)
                    )
                    draw_rect(rect, COVER_COLOR)
                    run_start = -1


var world
var player
var discovered := PackedByteArray()
var _scan_timer := 0.0
var _chunk_columns := 0
var _fog_chunks: Array[Node2D] = []
var _dirty_chunk_indices: Dictionary = {}


func _ready() -> void:
    add_to_group("fog_of_war")
    z_index = 100
    discovered.resize(WorldConfig.map_cells)
    discovered.fill(0)
    _create_fog_chunks()
    _scan_sources()


func _create_fog_chunks() -> void:
    _fog_chunks.clear()
    _chunk_columns = ceili(float(WorldConfig.map_size) / float(CHUNK_CELLS))
    var chunk_rows := _chunk_columns
    for chunk_y in chunk_rows:
        for chunk_x in _chunk_columns:
            var chunk := FogChunk.new()
            chunk.fog_owner = self
            chunk.chunk_origin = Vector2i(chunk_x * CHUNK_CELLS, chunk_y * CHUNK_CELLS)
            chunk.chunk_cells = CHUNK_CELLS
            chunk.map_size = WorldConfig.map_size
            chunk.tile_size = WorldConfig.tile_size
            chunk.position = Vector2(chunk.chunk_origin) * float(WorldConfig.tile_size)
            add_child(chunk)
            _fog_chunks.append(chunk)
            chunk.queue_redraw()


func export_state() -> Dictionary:
    var cells: Array[int] = []
    for index in WorldConfig.map_cells:
        if discovered[index] != 0:
            cells.append(index)
    return {"cells": cells}


func import_state(data: Dictionary) -> void:
    discovered.fill(0)
    var cells = data.get("cells", [])
    if cells is Array:
        for value in cells:
            var index := int(value)
            if index >= 0 and index < WorldConfig.map_cells:
                discovered[index] = 1
    _dirty_chunk_indices.clear()
    for chunk in _fog_chunks:
        chunk.queue_redraw()


func _process(delta: float) -> void:
    _scan_timer -= delta
    if _scan_timer > 0.0:
        return
    _scan_timer = 0.25
    _scan_sources()


func is_revealed_cell(cell: Vector2i) -> bool:
    if cell.x < 0 or cell.y < 0 or cell.x >= WorldConfig.map_size or cell.y >= WorldConfig.map_size:
        return false
    return discovered[cell.y * WorldConfig.map_size + cell.x] != 0


func reveal_position(position_world: Vector2, radius: float) -> bool:
    var center := Vector2i((position_world / WorldConfig.tile_size).floor())
    var radius_tiles := ceili(radius / WorldConfig.tile_size)
    var changed := false
    for y in range(maxi(0, center.y - radius_tiles), mini(WorldConfig.map_size - 1, center.y + radius_tiles) + 1):
        for x in range(maxi(0, center.x - radius_tiles), mini(WorldConfig.map_size - 1, center.x + radius_tiles) + 1):
            var offset := Vector2(x + 0.5, y + 0.5) - Vector2(center) - Vector2(0.5, 0.5)
            if offset.length_squared() * WorldConfig.tile_size * WorldConfig.tile_size > radius * radius:
                continue
            var index := y * WorldConfig.map_size + x
            if discovered[index] == 0:
                discovered[index] = 1
                changed = true
                var chunk_y := floori(float(y) / float(CHUNK_CELLS))
                var chunk_x := floori(float(x) / float(CHUNK_CELLS))
                var chunk_index := chunk_y * _chunk_columns + chunk_x
                _dirty_chunk_indices[chunk_index] = true
    return changed


func _flush_dirty_chunks() -> void:
    for chunk_index in _dirty_chunk_indices:
        var index := int(chunk_index)
        if index >= 0 and index < _fog_chunks.size():
            _fog_chunks[index].queue_redraw()
    _dirty_chunk_indices.clear()


func _scan_sources() -> void:
    if player != null and is_instance_valid(player):
        var player_reveal_radius := 144.0 if Tech.has_flag("frontier_surveying") else 112.0
        reveal_position(player.global_position, player_reveal_radius)
    for building in get_tree().get_nodes_in_group("buildings"):
        if building.id == "keep":
            reveal_position(building.global_position, 160.0)
        elif building.id == "outpost":
            var outpost_reveal_radius := 144.0 * Tech.stat("map.outpost_reveal", 1.0)
            reveal_position(building.global_position, outpost_reveal_radius)
        elif building.id == "tower":
            var tower_reveal_radius: float = float(building.data.get("vision_radius", 128.0)) * Tech.stat("map.tower_reveal", 1.0)
            reveal_position(building.global_position, tower_reveal_radius)
    for villager in get_tree().get_nodes_in_group("villagers"):
        if villager.visible:
            var villager_reveal_radius := 144.0 if String(villager.job) == "scout" else 64.0
            reveal_position(villager.global_position, villager_reveal_radius)
    _flush_dirty_chunks()
