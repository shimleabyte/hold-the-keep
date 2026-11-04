extends RefCounted
## Owns scout target selection, reservation spacing, survey and return-to-post behavior.
## Villager retains movement, state, navigation and workplace ownership.

var _villager: Variant


func configure(villager: Variant) -> void:
    _villager = villager


func find_work() -> void:
    if not _villager.has_valid_workplace():
        _villager._release_workplace()
        if not _villager._claim_workplace("scout"):
            return
    if _villager._facility_sabotaged(_villager.workplace):
        return

    var fog = _villager.get_tree().get_first_node_in_group("fog_of_war")
    if fog == null:
        return
    var origin: Vector2i = _villager.nav.cell_of(_villager.workplace.position)
    var best_cell := Vector2i(-1, -1)
    var best_path := PackedVector2Array()
    var best_score: float = -INF
    var best_direction: int = _villager.scout_behavior_cursor()
    var work_radius: float = float(_villager.workplace.data.get("work_radius", _villager.DEFAULT_WORK_RADIUS)) * WorldConfig.tile_size

    for radius in _villager.SCOUT_SEARCH_RADII:
        for offset in _villager.SCOUT_DIRECTIONS.size():
            var direction_index: int = (_villager._scout_cursor + offset) % _villager.SCOUT_DIRECTIONS.size()
            var direction: Vector2i = _villager.SCOUT_DIRECTIONS[direction_index]
            var candidate: Vector2i = origin + direction * radius
            if _villager.workplace.position.distance_squared_to(_villager.nav.center_of(candidate)) > work_radius * work_radius:
                continue
            if not _villager.nav.is_walkable(candidate) or target_reserved(candidate):
                continue
            var path: PackedVector2Array = _villager.nav.path_to(_villager.position, candidate)
            if path.is_empty() or path.size() > _villager.SCOUT_MAX_PATH_CELLS:
                continue
            var unexplored := 0
            for y in range(candidate.y - 5, candidate.y + 6):
                for x in range(candidate.x - 5, candidate.x + 6):
                    if x < 0 or y < 0 or x >= WorldConfig.map_size or y >= WorldConfig.map_size:
                        continue
                    if not fog.is_revealed_cell(Vector2i(x, y)):
                        unexplored += 1
            if unexplored <= 0:
                continue
            var score: float = float(unexplored) * 8.0 - float(path.size()) * 1.5 + float(radius)
            if score > best_score:
                best_score = score
                best_cell = candidate
                best_path = path
                best_direction = direction_index

    if best_cell.x < 0:
        return_to_post()
        return

    _villager._scout_target_cell = best_cell
    _villager._scout_cursor = (best_direction + 1) % _villager.SCOUT_DIRECTIONS.size()
    _villager._scout_survey_t = 0.0
    _villager._scout_revealed_at_target = false
    var goal_cells: Array[Vector2i] = [best_cell]
    _villager._goal_cells = goal_cells
    _villager._set_path(best_path)
    _villager.state = _villager.State.SCOUTING


func target_reserved(cell: Vector2i) -> bool:
    for other in _villager.get_tree().get_nodes_in_group("villagers"):
        if other == _villager or not is_instance_valid(other):
            continue
        if String(other.job) != "scout":
            continue
        var reserved_cell: Vector2i = other.scout_behavior_reserved_cell()
        if reserved_cell.x < 0:
            continue
        if Vector2(reserved_cell).distance_to(Vector2(cell)) < 8.0:
            return true
    return false


func tick(delta: float) -> void:
    if not _villager.has_valid_workplace() or _villager._facility_sabotaged(_villager.workplace):
        _villager.scout_behavior_reset_survey()
        _villager.scout_behavior_wait_for_scout()
        return
    if not _villager.scout_behavior_repath_if_needed():
        return
    if not _villager.scout_behavior_has_arrived():
        _villager.scout_behavior_move(delta)
        return
    if not _villager.scout_behavior_is_revealed():
        var fog = _villager.get_tree().get_first_node_in_group("fog_of_war")
        if fog != null:
            fog.reveal_position(_villager.global_position, _villager.SCOUT_REVEAL_RADIUS)
        _villager.scout_behavior_mark_revealed()
    if _villager.scout_behavior_advance_survey(delta):
        _villager.scout_behavior_finish_survey()


func return_to_post() -> void:
    if not _villager.has_valid_workplace():
        _villager.scout_behavior_reset_survey()
        _villager.scout_behavior_wait_for_scout()
        return
    _villager.scout_behavior_reset_survey()
    var cells: Array[Vector2i] = _villager.workplace.cells()
    if _villager.position.distance_to(_villager.workplace.position) <= _villager.OUTPOST_GUARD_ARRIVAL_RADIUS:
        _villager.scout_behavior_wait_for_scout()
        return
    var path: PackedVector2Array = _villager.nav.path_adjacent(_villager.position, cells)
    if path.is_empty():
        _villager.scout_behavior_wait_for_scout()
        return
    _villager.scout_behavior_set_return_path(cells, path)
