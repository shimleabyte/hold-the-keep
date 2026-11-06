extends RefCounted
## Self-contained Beast Rider target selection, telegraph, charge and recovery policy.
## The owning Enemy supplies movement/combat hooks and remains responsible for damage reception.

const TARGET_SCAN_LIMIT := 24
const ISOLATION_RADIUS := 76.0

var actor
var navigation

var target: Node2D
var cooldown := 0.0
var scan_timer := 0.0
var scan_cursor := 0
var windup_timer := 0.0
var charge_timer := 0.0
var charge_distance := 0.0
var hit_done := false
var charge_direction := Vector2.ZERO
var target_position := Vector2.ZERO
var charge_path := PackedVector2Array()
var charge_path_index := 0
var charge_path_version := -1
var approach_path := PackedVector2Array()
var approach_path_index := 0
var approach_path_version := -1
var approach_repath_timer := 0.0

var target_scan_range := 235.0
var charge_min_range := 54.0
var charge_max_range := 162.0
var charge_windup_duration := 0.82
var charge_speed_multiplier := 2.8
var charge_max_distance := 156.0
var charge_hit_radius := 18.0
var charge_cooldown_duration := 6.5
var charge_damage_multiplier := 1.35


func configure(owner: Node, data: Dictionary) -> void:
    actor = owner
    target_scan_range = clampf(float(data.get("beast_target_scan_range", 235.0)), 140.0, 340.0)
    charge_min_range = clampf(float(data.get("beast_charge_min_range", 54.0)), 36.0, 90.0)
    charge_max_range = clampf(float(data.get("beast_charge_max_range", 162.0)), 110.0, 220.0)
    charge_windup_duration = clampf(float(data.get("beast_charge_windup", 0.82)), 0.4, 1.4)
    charge_speed_multiplier = clampf(float(data.get("beast_charge_speed_multiplier", 2.8)), 2.0, 4.0)
    charge_max_distance = clampf(float(data.get("beast_charge_max_distance", 156.0)), 90.0, 210.0)
    charge_hit_radius = clampf(float(data.get("beast_charge_hit_radius", 18.0)), 12.0, 30.0)
    charge_cooldown_duration = clampf(float(data.get("beast_charge_cooldown", 6.5)), 3.5, 12.0)
    charge_damage_multiplier = clampf(float(data.get("beast_charge_damage_multiplier", 1.35)), 1.05, 2.0)
    reset()


func set_navigation(nav) -> void:
    navigation = nav


func reset() -> void:
    target = null
    cooldown = 0.0
    scan_timer = 0.0
    scan_cursor = 0
    windup_timer = 0.0
    charge_timer = 0.0
    charge_distance = 0.0
    hit_done = false
    charge_direction = Vector2.ZERO
    target_position = Vector2.ZERO
    charge_path = PackedVector2Array()
    charge_path_index = 0
    charge_path_version = -1
    approach_path = PackedVector2Array()
    approach_path_index = 0
    approach_path_version = -1
    approach_repath_timer = 0.0


func advance_timers(delta: float) -> void:
    cooldown = maxf(0.0, cooldown - delta)
    scan_timer = maxf(0.0, scan_timer - delta)
    approach_repath_timer = maxf(0.0, approach_repath_timer - delta)


func target_is_valid(candidate: Variant) -> bool:
    # Freed Object references must enter as Variant; a Node2D parameter rejects
    # them before is_instance_valid() can guard the reference.
    if candidate == null or not is_instance_valid(candidate) or not (candidate is Node2D):
        return false
    var target_node := candidate as Node2D
    if not target_node.visible:
        return false
    if target_node != actor.player and not target_node.is_in_group("defenders"):
        return false
    if int(target_node.get("hp")) <= 0:
        return false
    if actor.is_garrison and target_node.global_position.distance_to(actor.guard_origin) > 175.0:
        return false
    return true


func _target_score(candidate: Node2D, defenders: Array) -> float:
    var distance: float = actor.global_position.distance_to(candidate.global_position)
    var score := 180.0 - distance * 0.4
    if candidate == actor.player:
        return score + 16.0

    var nearby_support := 0
    for ally in defenders:
        if ally == candidate or not is_instance_valid(ally) or not (ally is Node2D):
            continue
        var defender := ally as Node2D
        if defender.visible and defender.global_position.distance_to(candidate.global_position) <= ISOLATION_RADIUS:
            nearby_support += 1
    if nearby_support == 0:
        score += 72.0
    elif nearby_support == 1:
        score += 26.0

    var target_job := String(candidate.get("job"))
    if target_job in ["archer", "ranged"]:
        score += 42.0
    return score


func select_target() -> Node2D:
    var defenders: Array = actor.get_tree().get_nodes_in_group("defenders")
    var best_target: Node2D = null
    var best_score := -INF

    var player_target := actor.player as Node2D
    if target_is_valid(player_target):
        var player_distance: float = actor.global_position.distance_to(player_target.global_position)
        if player_distance <= target_scan_range:
            best_target = player_target
            best_score = _target_score(player_target, defenders)

    var defender_count := defenders.size()
    var scan_count := mini(TARGET_SCAN_LIMIT, defender_count)
    for offset in scan_count:
        var candidate = defenders[(scan_cursor + offset) % defender_count]
        if not (candidate is Node2D):
            continue
        var defender := candidate as Node2D
        if not target_is_valid(defender):
            continue
        if actor.global_position.distance_to(defender.global_position) > target_scan_range:
            continue
        var score := _target_score(defender, defenders)
        if score > best_score:
            best_score = score
            best_target = defender

    if defender_count > 0:
        scan_cursor = (scan_cursor + scan_count) % defender_count
    return best_target


func begin_windup(candidate: Node2D) -> bool:
    if navigation == null or not target_is_valid(candidate):
        return false
    var target_cell: Vector2i = navigation.cell_of(candidate.global_position)
    var path: PackedVector2Array = navigation.path_to(actor.global_position, target_cell)
    if path.is_empty():
        return false

    target = candidate
    charge_path = path
    charge_path_index = 0
    charge_path_version = navigation.version
    target_position = candidate.global_position
    var direction: Vector2 = target_position - actor.global_position
    charge_direction = direction.normalized() if direction.length_squared() > 0.01 else Vector2.DOWN
    windup_timer = charge_windup_duration
    actor._moving = false
    actor.anim.face(charge_direction)
    Events.fx_burst.emit("dust", actor.position + Vector2(0, -4), -charge_direction, 0.85)
    Audio.play("charge", 1.0, -4.0)
    actor.queue_redraw()
    return true


func _move_toward_target(candidate: Node2D, delta: float) -> void:
    if navigation == null:
        actor._tick_flow(delta)
        return
    if approach_path_version != navigation.version or approach_path.is_empty() or approach_repath_timer <= 0.0:
        var target_cell: Vector2i = navigation.cell_of(candidate.global_position)
        approach_path = navigation.path_to(actor.global_position, target_cell)
        approach_path_index = 0
        approach_path_version = navigation.version
        approach_repath_timer = 0.7

    while approach_path_index < approach_path.size() and actor.global_position.distance_to(approach_path[approach_path_index]) <= 3.0:
        approach_path_index += 1
    if approach_path_index < approach_path.size():
        actor._move_toward(approach_path[approach_path_index], delta)
    else:
        actor._move_toward(candidate.global_position, delta)


func _cancel_windup(recovery: float, clear_target: bool = false) -> void:
    windup_timer = 0.0
    charge_path = PackedVector2Array()
    charge_path_index = 0
    charge_path_version = -1
    cooldown = maxf(cooldown, recovery)
    if clear_target:
        target = null
    actor.queue_redraw()


func tick(delta: float) -> void:
    if charge_timer > 0.0:
        _tick_charge(delta)
        return

    if windup_timer > 0.0:
        if not target_is_valid(target) or navigation == null or charge_path_version != navigation.version:
            _cancel_windup(1.0, true)
            return
        var windup_distance: float = actor.global_position.distance_to(target.global_position)
        if windup_distance > charge_max_range + 34.0:
            _cancel_windup(1.0, true)
            return
        if windup_distance <= actor._attack_reach():
            var close_target: Node2D = target
            _cancel_windup(0.7)
            actor._begin_attack(close_target, close_target.global_position - actor.global_position)
            return

        actor._moving = false
        actor.anim.face(charge_direction)
        windup_timer = maxf(0.0, windup_timer - delta)
        if windup_timer <= 0.0:
            var charge_speed: float = maxf(1.0, actor.speed * charge_speed_multiplier)
            charge_timer = clampf(charge_max_distance / charge_speed + 0.2, 0.35, 1.8)
            charge_distance = 0.0
            hit_done = false
            cooldown = charge_cooldown_duration
            target_position = target.global_position
            Events.fx_burst.emit("dust", actor.position + Vector2(0, -5), -charge_direction, 1.1)
        actor.queue_redraw()
        return

    if not target_is_valid(target):
        target = null
        approach_path = PackedVector2Array()
        approach_path_index = 0
        approach_path_version = -1
        scan_timer = 0.0

    if target == null and scan_timer <= 0.0:
        target = select_target()
        scan_timer = 0.75

    if target == null:
        if actor.is_garrison:
            if actor.global_position.distance_to(actor.guard_origin) > 16.0:
                actor._move_toward(actor.guard_origin, delta)
        else:
            actor._tick_flow(delta)
        return

    var to_target: Vector2 = target.global_position - actor.global_position
    var distance: float = to_target.length()
    if distance <= actor._attack_reach():
        actor._begin_attack(target, to_target)
        return

    if cooldown <= 0.0 and distance >= charge_min_range and distance <= charge_max_range:
        if begin_windup(target):
            return

    _move_toward_target(target, delta)


func _distance_squared_to_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> float:
    var segment := segment_end - segment_start
    var length_squared := segment.length_squared()
    if length_squared <= 0.001:
        return point.distance_squared_to(segment_start)
    var along := clampf((point - segment_start).dot(segment) / length_squared, 0.0, 1.0)
    var closest := segment_start + segment * along
    return point.distance_squared_to(closest)


func _apply_charge_impact(candidate: Node2D) -> void:
    if candidate == null or not is_instance_valid(candidate) or hit_done:
        return
    hit_done = true
    var impact_damage := maxi(1, roundi(float(actor.damage) * charge_damage_multiplier))
    if candidate.has_method("take_damage"):
        candidate.call("take_damage", impact_damage)

    var pushed_position: Vector2 = candidate.global_position + charge_direction * 10.0
    if navigation != null and navigation.is_walkable(navigation.cell_of(pushed_position)):
        candidate.global_position = pushed_position
    Events.fx_burst.emit("impact", candidate.global_position + Vector2(0, -8), charge_direction, 1.45)
    Events.screen_shake.emit(0.75, 0.1)


func _finish_charge(hit: bool) -> void:
    charge_timer = 0.0
    charge_path = PackedVector2Array()
    charge_path_index = 0
    charge_path_version = -1
    approach_repath_timer = 0.0
    if not hit:
        Events.fx_burst.emit("dust", actor.position + Vector2(0, -3), charge_direction, 0.75)
    actor.queue_redraw()


func _tick_charge(delta: float) -> void:
    if navigation == null or charge_path_version != navigation.version or not target_is_valid(target):
        _finish_charge(false)
        return

    charge_timer = maxf(0.0, charge_timer - delta)
    var distance_remaining: float = maxf(0.0, charge_max_distance - charge_distance)
    var travel_left: float = minf(actor.speed * charge_speed_multiplier * delta, distance_remaining)
    while travel_left > 0.01:
        if charge_path_index >= charge_path.size():
            _finish_charge(false)
            return

        var waypoint: Vector2 = charge_path[charge_path_index]
        var toward_waypoint: Vector2 = waypoint - actor.global_position
        var segment_length: float = toward_waypoint.length()
        if segment_length <= 1.0:
            charge_path_index += 1
            continue

        var travel: float = minf(travel_left, segment_length)
        var next_position: Vector2 = actor.global_position + toward_waypoint / segment_length * travel
        if actor.anim.face(next_position - actor.global_position):
            actor.queue_redraw()
        var next_cell: Vector2i = navigation.cell_of(next_position)
        if not navigation.is_walkable(next_cell):
            _finish_charge(false)
            return

        if not hit_done and target_is_valid(target):
            var hit_distance_squared: float = _distance_squared_to_segment(
                target.global_position, actor.global_position, next_position)
            if hit_distance_squared <= charge_hit_radius * charge_hit_radius:
                actor.global_position = next_position
                _apply_charge_impact(target)
                _finish_charge(true)
                return

        actor.global_position = next_position
        travel_left -= travel
        charge_distance += travel
        if travel >= segment_length - 0.01:
            charge_path_index += 1
        actor._moving = true

    if charge_timer <= 0.0 or charge_distance >= charge_max_distance - 0.01:
        _finish_charge(false)
    else:
        actor.queue_redraw()


func interrupt() -> void:
    if windup_timer > 0.0 or charge_timer > 0.0:
        windup_timer = 0.0
        charge_timer = 0.0
        charge_path = PackedVector2Array()
        charge_path_index = 0
        charge_path_version = -1
        cooldown = maxf(cooldown, 1.4)


func draw_telegraph(canvas: CanvasItem, frame_height: int) -> void:
    if windup_timer <= 0.0 and charge_timer <= 0.0:
        return
    var route_color := Color("#f0c078") if windup_timer > 0.0 else Color("#d77e45")
    var route_start := Vector2(0, -frame_height - 5)
    var route_previous := Vector2.ZERO
    for route_index in range(charge_path_index, charge_path.size()):
        var route_point: Vector2 = charge_path[route_index] - actor.global_position + Vector2(0, -4)
        canvas.draw_line(
            route_previous if route_index > charge_path_index else route_start,
            route_point,
            route_color,
            1.5
        )
        route_previous = route_point
    var aim_center: Vector2 = target_position - actor.global_position + Vector2(0, -8)
    canvas.draw_arc(aim_center, 10.0, 0.0, TAU, 12, route_color, 1.5)
    if windup_timer > 0.0:
        canvas.draw_arc(Vector2(0, -frame_height - 7), 7.0, 0.0, TAU, 10, Color("#f3d39a"), 1.8)
