extends RefCounted
## Saboteur building target policy, bounded A* pursuit, disruption wind-up and recovery.

const TARGET_PRIORITIES := {
    "tower": 6,
    "outpost": 6,
    "storage": 5,
    "lumber_camp": 4,
    "quarry": 4,
    "forge": 4,
    "farm": 3,
    "house": 2
}
const TARGET_SCAN_LIMIT := 32
const INTERCEPTOR_REFRESH_INTERVAL := 0.12

var actor
var navigation

var scan_range := 460.0
var scan_interval := 1.25
var windup_duration := 0.85
var disruption_duration := 5.0
var cooldown_duration := 8.5
var damage_multiplier := 1.5

var target: Node2D
var scan_timer := 0.0
var scan_cursor := 0
var _interceptor_scan_timer := 0.0
var _interceptor_cache: Node2D
var windup_timer := 0.0
var cooldown := 0.0
var path := PackedVector2Array()
var path_index := 0
var path_version := -1
var repath_timer := 0.0


func configure(owner, data: Dictionary) -> void:
    actor = owner
    scan_range = clampf(float(data.get("saboteur_scan_range", 460.0)), 160.0, 720.0)
    scan_interval = clampf(float(data.get("saboteur_scan_interval", 1.25)), 0.4, 4.0)
    windup_duration = clampf(float(data.get("saboteur_windup", 0.85)), 0.35, 1.8)
    disruption_duration = clampf(float(data.get("saboteur_disruption_duration", 5.0)), 2.0, 10.0)
    cooldown_duration = clampf(float(data.get("saboteur_cooldown", 8.5)), 4.0, 18.0)
    damage_multiplier = clampf(float(data.get("saboteur_damage_multiplier", 1.5)), 1.0, 2.5)
    reset()


func reset() -> void:
    target = null
    scan_timer = 0.0
    scan_cursor = 0
    _interceptor_scan_timer = 0.0
    _interceptor_cache = null
    windup_timer = 0.0
    cooldown = 0.0
    path = PackedVector2Array()
    path_index = 0
    path_version = -1
    repath_timer = 0.0


func set_navigation(nav) -> void:
    navigation = nav


func advance_timers(delta: float) -> void:
    cooldown = maxf(0.0, cooldown - delta)
    scan_timer = maxf(0.0, scan_timer - delta)
    repath_timer = maxf(0.0, repath_timer - delta)
    _interceptor_scan_timer = maxf(0.0, _interceptor_scan_timer - delta)


func target_is_valid(candidate: Node2D) -> bool:
    if candidate == null or not is_instance_valid(candidate) or not candidate.is_in_group("buildings"):
        return false
    if int(candidate.get("hp")) <= 0 or not candidate.has_method("apply_sabotage"):
        return false
    return not bool(candidate.call("is_sabotaged"))


func select_target() -> Node2D:
    if navigation == null:
        return null

    var buildings: Array = actor.get_tree().get_nodes_in_group("buildings")
    var building_count := buildings.size()
    if building_count <= 0:
        return null

    var scan_count := mini(TARGET_SCAN_LIMIT, building_count)
    var best_target: Node2D
    var best_path := PackedVector2Array()
    var best_score := -INF
    for offset in scan_count:
        var candidate = buildings[(scan_cursor + offset) % building_count]
        if not (candidate is Node2D):
            continue
        var building := candidate as Node2D
        var priority := int(TARGET_PRIORITIES.get(String(building.get("id")), 0))
        if priority <= 0 or not target_is_valid(building):
            continue
        if actor.position.distance_to(building.position) > scan_range:
            continue
        if actor.is_garrison and building.position.distance_to(actor.guard_origin) > 175.0:
            continue
        var cells: Array[Vector2i] = building.call("cells")
        var candidate_path: PackedVector2Array = navigation.path_adjacent(actor.position, cells)
        if candidate_path.is_empty():
            continue
        var score := float(priority * 120) - float(maxi(0, candidate_path.size() - 1)) * 8.0
        if score > best_score:
            best_score = score
            best_target = building
            best_path = candidate_path

    scan_cursor = (scan_cursor + scan_count) % building_count
    target = best_target
    path = best_path
    path_index = 1 if best_path.size() > 1 else 0
    path_version = navigation.version
    repath_timer = 0.9
    return best_target


func _nearest_interceptor() -> Node2D:
    var reach: float = float(actor._attack_reach()) + 4.0
    # Player interception remains immediate; only the full defender scan is throttled.
    if actor.player != null and is_instance_valid(actor.player) and actor.player.visible:
        if actor.position.distance_squared_to(actor.player.position) <= reach * reach:
            _interceptor_cache = actor.player
            return _interceptor_cache
    if _interceptor_scan_timer > 0.0 and is_instance_valid(_interceptor_cache):
        if _interceptor_cache.is_in_group("defenders") and _interceptor_cache.visible \
                and actor.position.distance_squared_to(_interceptor_cache.position) <= reach * reach:
            return _interceptor_cache
    if _interceptor_scan_timer > 0.0:
        return null
    _interceptor_cache = null
    _interceptor_scan_timer = INTERCEPTOR_REFRESH_INTERVAL
    for defender in actor.get_tree().get_nodes_in_group("defenders"):
        if not is_instance_valid(defender) or not defender.visible:
            continue
        if actor.position.distance_squared_to(defender.position) <= reach * reach:
            _interceptor_cache = defender as Node2D
            return _interceptor_cache
    return null


func _clear_target() -> void:
    target = null
    path = PackedVector2Array()
    path_index = 0
    path_version = -1


func tick(delta: float) -> void:
    if windup_timer > 0.0:
        if not target_is_valid(target) or actor.position.distance_to(target.position) > 48.0:
            windup_timer = 0.0
            _clear_target()
            cooldown = maxf(cooldown, 1.0)
            actor.queue_redraw()
            return

        var windup_direction: Vector2 = target.position - actor.position
        if windup_direction.length_squared() > 0.01:
            actor.anim.face(windup_direction)
        actor._moving = false
        windup_timer = maxf(0.0, windup_timer - delta)
        if windup_timer <= 0.0:
            var sabotaged_target: Node2D = target
            if bool(sabotaged_target.call("apply_sabotage", disruption_duration)):
                var sabotage_damage := maxi(1, roundi(float(actor.damage) * damage_multiplier))
                sabotaged_target.call("take_damage", sabotage_damage)
                Events.fx_burst.emit("debris", sabotaged_target.global_position + Vector2(0, -8), Vector2.ZERO, 1.2)
                cooldown = cooldown_duration
            else:
                cooldown = maxf(cooldown, 1.0)
            _clear_target()
            actor.queue_redraw()
        return

    var interceptor := _nearest_interceptor()
    if interceptor != null:
        _clear_target()
        actor._begin_attack(interceptor, interceptor.position - actor.position)
        return

    if not target_is_valid(target):
        _clear_target()
        scan_timer = 0.0

    if target == null and scan_timer <= 0.0:
        select_target()
        scan_timer = scan_interval

    if target == null:
        actor._tick_flow(delta)
        return

    var distance: float = actor.position.distance_to(target.position)
    if distance <= maxf(22.0, actor._attack_reach() + 8.0):
        actor._moving = false
        if cooldown <= 0.0:
            windup_timer = windup_duration
            actor.anim.face(target.position - actor.position)
            Events.fx_burst.emit("dust", actor.position + Vector2(0, -3), Vector2.ZERO, 0.6)
            actor.queue_redraw()
        return

    if navigation == null:
        actor._tick_flow(delta)
        return
    if path_version != navigation.version or path.is_empty() or repath_timer <= 0.0:
        var target_cells: Array[Vector2i] = target.call("cells")
        path = navigation.path_adjacent(actor.position, target_cells)
        path_index = 1 if path.size() > 1 else 0
        path_version = navigation.version
        repath_timer = 0.9
    while path_index < path.size() and actor.position.distance_to(path[path_index]) <= 3.0:
        path_index += 1
    if path_index < path.size():
        actor._move_toward(path[path_index], delta)
    else:
        _clear_target()
        scan_timer = 0.0


func interrupt() -> void:
    if windup_timer <= 0.0:
        return
    windup_timer = 0.0
    _clear_target()
    cooldown = maxf(cooldown, 1.2)
    actor.queue_redraw()


func draw_telegraph(canvas: CanvasItem, frame_height: int) -> void:
    if target != null and is_instance_valid(target):
        var target_center: Vector2 = target.global_position - actor.global_position + Vector2(0, -8)
        var target_color := Color("#efb45d") if windup_timer > 0.0 else Color("#b85e48")
        canvas.draw_line(Vector2(0, -frame_height - 5), target_center, target_color, 1.2)
        canvas.draw_arc(target_center, 11.0, 0.0, TAU, 12, target_color, 1.5)
    if windup_timer > 0.0:
        canvas.draw_arc(Vector2(0, -frame_height - 8), 6.0, 0.0, TAU, 10, Color("#efb45d"), 1.5)
