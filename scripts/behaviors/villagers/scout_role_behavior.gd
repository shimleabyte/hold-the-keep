extends "res://scripts/behaviors/villagers/villager_role_behavior.gd"
## Scout Post target selection and bounded local fog survey. Navigation remains owned by Villager.

const REVEAL_RADIUS := 144.0
const MAX_PATH_CELLS := 64
const SURVEY_SECONDS := 1.4
const RECHECK_SECONDS := 5.0
const SEARCH_RADII: Array[int] = [20, 16, 12, 8]
const DIRECTIONS: Array[Vector2i] = [
    Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
    Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)
]

var target_cell := Vector2i(-1, -1)
var cursor := 0
var survey_time := 0.0
var revealed_at_target := false


func role_id() -> String:
    return "scout"


func get_scout_target_cell() -> Vector2i:
    return target_cell


func set_scout_target_cell(cell: Vector2i) -> void:
    target_cell = cell


func find_scout_work() -> void:
    if not actor.has_valid_workplace():
        actor._release_workplace()
        if not actor._claim_workplace("scout"):
            return
    if actor._facility_sabotaged(actor.workplace):
        return
    var fog = actor.get_tree().get_first_node_in_group("fog_of_war")
    if fog == null:
        return
    var origin: Vector2i = actor.nav.cell_of(actor.workplace.position)
    var best_cell := Vector2i(-1, -1)
    var best_path := PackedVector2Array()
    var best_score := -INF
    var best_direction := cursor
    var work_radius := float(actor.workplace.data.get("work_radius", 12.0)) * WorldConfig.tile_size
    for radius in SEARCH_RADII:
        for offset in DIRECTIONS.size():
            var direction_index := (cursor + offset) % DIRECTIONS.size()
            var direction: Vector2i = DIRECTIONS[direction_index]
            var candidate: Vector2i = origin + direction * radius
            if actor.workplace.position.distance_squared_to(actor.nav.center_of(candidate)) > work_radius * work_radius:
                continue
            if not actor.nav.is_walkable(candidate) or scout_target_reserved(candidate):
                continue
            var path: PackedVector2Array = actor._path_to_scout_cell(candidate)
            if path.is_empty() or path.size() > MAX_PATH_CELLS:
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
            var score := float(unexplored) * 8.0 - float(path.size()) * 1.5 + float(radius)
            if score > best_score:
                best_score = score
                best_cell = candidate
                best_path = path
                best_direction = direction_index
    if best_cell.x < 0:
        return_to_scout_post()
        return
    target_cell = best_cell
    cursor = (best_direction + 1) % DIRECTIONS.size()
    survey_time = 0.0
    revealed_at_target = false
    actor._goal_cells = [best_cell]
    actor._set_path(best_path)
    actor.state = ActorState.SCOUTING


func scout_target_reserved(cell: Vector2i) -> bool:
    for other in actor.get_tree().get_nodes_in_group("villagers"):
        if other == actor or not is_instance_valid(other) or String(other.job) != "scout":
            continue
        var reserved_cell: Vector2i = other._scout_target_cell
        if reserved_cell.x < 0:
            continue
        if Vector2(reserved_cell).distance_to(Vector2(cell)) < 8.0:
            return true
    return false


func tick_scouting(delta: float) -> void:
    if not actor.has_valid_workplace() or actor._facility_sabotaged(actor.workplace):
        target_cell = Vector2i(-1, -1)
        survey_time = 0.0
        revealed_at_target = false
        actor.state = ActorState.IDLE
        actor._decide_t = RECHECK_SECONDS
        return
    if actor.nav.version != actor._path_ver:
        actor._repath()
        if actor.state != ActorState.SCOUTING:
            return
    if actor._pi < actor._path.size():
        actor._move_along(delta)
        return
    if not revealed_at_target:
        var fog = actor.get_tree().get_first_node_in_group("fog_of_war")
        if fog != null:
            fog.reveal_position(actor.global_position, REVEAL_RADIUS)
        revealed_at_target = true
    survey_time += delta
    if survey_time >= SURVEY_SECONDS:
        target_cell = Vector2i(-1, -1)
        survey_time = 0.0
        revealed_at_target = false
        actor.state = ActorState.IDLE
        actor._decide_t = RECHECK_SECONDS


func return_to_scout_post() -> void:
    if not actor.has_valid_workplace():
        target_cell = Vector2i(-1, -1)
        actor.state = ActorState.IDLE
        return
    target_cell = Vector2i(-1, -1)
    revealed_at_target = false
    var cells: Array[Vector2i] = actor.workplace.cells()
    if actor.position.distance_to(actor.workplace.position) <= 45.0:
        actor.state = ActorState.IDLE
        actor._decide_t = RECHECK_SECONDS
        return
    var path: PackedVector2Array = actor._path_adjacent_to_cells(cells)
    if path.is_empty():
        actor.state = ActorState.IDLE
        actor._decide_t = RECHECK_SECONDS
        return
    actor._goal_cells = cells
    actor._set_path(path)
    actor.state = ActorState.SCOUT_RETURNING


func reset_scout_state() -> void:
    target_cell = Vector2i(-1, -1)
    survey_time = 0.0
    revealed_at_target = false
