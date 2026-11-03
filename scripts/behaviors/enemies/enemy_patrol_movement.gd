extends RefCounted
## Region-safe patrol route state machine and path following for Enemy actors.
## Enemy remains the source of serialized patrol state and combat policy.

var actor


func configure(enemy) -> void:
    actor = enemy


func tick_route() -> void:
    if actor == null or not is_instance_valid(actor):
        return
    if actor.patrol_points.is_empty():
        actor.guard_origin = actor.patrol_origin
        return
    if actor.position.distance_to(actor.patrol_origin) > actor.patrol_radius:
        actor.patrol_returning = true
    if actor.patrol_returning:
        actor.guard_origin = actor.patrol_origin
        if actor.position.distance_to(actor.patrol_origin) <= 14.0:
            actor.patrol_returning = false
            actor.patrol_waypoint_index = posmod(actor.patrol_waypoint_index, actor.patrol_points.size())
            actor.guard_origin = actor.patrol_points[actor.patrol_waypoint_index]
        return
    var waypoint: Vector2 = actor.patrol_points[actor.patrol_waypoint_index]
    actor.guard_origin = waypoint
    if actor.position.distance_to(waypoint) <= 12.0:
        actor.patrol_waypoint_index = (actor.patrol_waypoint_index + 1) % actor.patrol_points.size()
        actor.guard_origin = actor.patrol_points[actor.patrol_waypoint_index]


func cell_in_enemy_region(cell: Vector2i) -> bool:
    if actor == null or not is_instance_valid(actor):
        return false
    if actor.patrol_nav == null or not actor.patrol_nav.is_walkable(cell):
        return false
    if String(actor.world.region_id(cell)) != actor.patrol_region_id:
        return false
    if actor.patrol_territory != null and actor.patrol_territory.owner_at(cell) != "enemy":
        return false
    return true


func cell_allowed(cell: Vector2i) -> bool:
    if not cell_in_enemy_region(cell):
        return false
    var origin_cell: Vector2i = actor.patrol_nav.cell_of(actor.patrol_origin)
    return Vector2(origin_cell - cell).length() * WorldConfig.tile_size <= actor.patrol_radius + WorldConfig.tile_size


func move_toward(target: Vector2, delta: float) -> void:
    if actor == null or not is_instance_valid(actor) or actor.patrol_nav == null:
        return
    var navigation = actor.patrol_nav
    var goal_cell: Vector2i = navigation.cell_of(target)
    if not WorldConfig.is_valid_cell(goal_cell) or not cell_allowed(goal_cell):
        return
    actor._patrol_repath_timer = maxf(0.0, actor._patrol_repath_timer - delta)
    if actor._patrol_path_version != navigation.version or actor._patrol_goal_cell != goal_cell or actor._patrol_path.is_empty() or actor._patrol_repath_timer <= 0.0:
        var candidate_path: PackedVector2Array = navigation.path_to(actor.global_position, goal_cell)
        var valid_path := not candidate_path.is_empty()
        if valid_path:
            for path_point in candidate_path:
                var path_cell: Vector2i = navigation.cell_of(path_point)
                var cell_is_allowed := cell_in_enemy_region(path_cell)
                if not actor.patrol_returning:
                    cell_is_allowed = cell_allowed(path_cell)
                if not cell_is_allowed:
                    valid_path = false
                    break
        if not valid_path:
            actor._patrol_path = PackedVector2Array()
            return
        actor._patrol_path = candidate_path
        actor._patrol_path_index = 1 if candidate_path.size() > 1 else 0
        actor._patrol_path_version = navigation.version
        actor._patrol_goal_cell = goal_cell
        actor._patrol_repath_timer = 0.55
    while actor._patrol_path_index < actor._patrol_path.size() and actor.global_position.distance_to(actor._patrol_path[actor._patrol_path_index]) <= 3.0:
        actor._patrol_path_index += 1
    if actor._patrol_path_index < actor._patrol_path.size():
        actor._move_toward_direct(actor._patrol_path[actor._patrol_path_index], delta)
    elif actor.global_position.distance_to(target) <= float(WorldConfig.tile_size):
        actor._move_toward_direct(target, delta)
