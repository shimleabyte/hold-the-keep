extends RefCounted
## Siege Engine target policy, siege advance, telegraphed structural impact and defender counterplay.

const TARGET_PRIORITIES := {
    "stone_wall": 9,
    "wall": 8,
    "tower": 6,
    "outpost": 5,
    "keep": 4,
    "storage": 3,
    "forge": 3,
    "lumber_camp": 2,
    "quarry": 2,
    "house": 1,
    "farm": 1
}
const TARGET_SCAN_LIMIT := 32
const DISRUPTOR_REFRESH_INTERVAL := 0.12
const DISRUPTOR_RANGE := 36.0

var actor
var navigation

var scan_range := 400.0
var scan_interval := 1.35
var windup_duration := 1.1
var cooldown_duration := 2.6
var damage_multiplier := 2.4

var target: Node2D
var scan_timer := 0.0
var scan_cursor := 0
var _disruptor_scan_timer := 0.0
var _disruptor_cache: Node2D
var windup_timer := 0.0
var cooldown := 0.0
var path := PackedVector2Array()
var path_index := 0
var path_version := -1
var repath_timer := 0.0


func configure(owner, data: Dictionary) -> void:
    actor = owner
    scan_range = clampf(float(data.get("siege_scan_range", 400.0)), 180.0, 650.0)
    scan_interval = clampf(float(data.get("siege_scan_interval", 1.35)), 0.4, 4.0)
    windup_duration = clampf(float(data.get("siege_windup", 1.1)), 0.45, 2.0)
    cooldown_duration = clampf(float(data.get("siege_cooldown", 2.6)), 1.2, 8.0)
    damage_multiplier = clampf(float(data.get("siege_structure_damage_mult", 2.4)), 1.2, 4.0)
    reset()


func reset() -> void:
    target = null
    scan_timer = 0.0
    scan_cursor = 0
    _disruptor_scan_timer = 0.0
    _disruptor_cache = null
    windup_timer = 0.0
    cooldown = 0.0
    path = PackedVector2Array()
    path_index = 0
    path_version = -1
    repath_timer = 0.0


func set_navigation(nav) -> void:
    navigation = nav


func advance_timers(delta: float) -> void:
    scan_timer = maxf(0.0, scan_timer - delta)
    cooldown = maxf(0.0, cooldown - delta)
    repath_timer = maxf(0.0, repath_timer - delta)
    _disruptor_scan_timer = maxf(0.0, _disruptor_scan_timer - delta)


func target_is_valid(candidate: Node2D) -> bool:
    if candidate == null or not is_instance_valid(candidate) or not candidate.is_in_group("buildings"):
        return false
    if int(candidate.get("hp")) <= 0 or not candidate.has_method("take_damage") or not candidate.has_method("cells"):
        return false
    return TARGET_PRIORITIES.has(String(candidate.get("id")))


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
        var score := float(priority * 160) - float(maxi(0, candidate_path.size() - 1)) * 6.0
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


func _nearest_disruptor() -> Node2D:
    var range_squared := DISRUPTOR_RANGE * DISRUPTOR_RANGE
    if actor.player != null and is_instance_valid(actor.player) and actor.player.visible:
        if actor.position.distance_squared_to(actor.player.position) <= range_squared:
            _disruptor_cache = actor.player
            return _disruptor_cache
    if _disruptor_scan_timer > 0.0 and is_instance_valid(_disruptor_cache):
        if _disruptor_cache.is_in_group("defenders") and _disruptor_cache.visible \
                and actor.position.distance_squared_to(_disruptor_cache.position) <= range_squared:
            return _disruptor_cache
    if _disruptor_scan_timer > 0.0:
        return null
    _disruptor_cache = null
    _disruptor_scan_timer = DISRUPTOR_REFRESH_INTERVAL
    var nearest: Node2D
    var nearest_distance_squared := range_squared
    for defender in actor.get_tree().get_nodes_in_group("defenders"):
        if not is_instance_valid(defender) or not defender.visible:
            continue
        var candidate := defender as Node2D
        var distance_squared: float = actor.position.distance_squared_to(candidate.position)
        if distance_squared <= nearest_distance_squared:
            nearest = candidate
            nearest_distance_squared = distance_squared
    _disruptor_cache = nearest
    return nearest


func _clear_target() -> void:
    target = null
    path = PackedVector2Array()
    path_index = 0
    path_version = -1


func _tick_advance(delta: float) -> void:
    if actor.flow == null:
        return
    var cell := Vector2i((actor.position / WorldConfig.tile_size).floor())
    var next: Vector2i = actor.flow.next_cell(cell)
    if next == cell:
        actor._move_toward(actor.flow.target_pos, delta)
        return
    var occupied = actor.world.occupied.get(next)
    if occupied != null and is_instance_valid(occupied) and occupied.is_in_group("buildings"):
        var structure := occupied as Node2D
        if target_is_valid(structure):
            target = structure
            path = PackedVector2Array()
            path_index = 0
            path_version = -1
            scan_timer = 0.0
            return
    var next_position: Vector2 = Vector2(next) * WorldConfig.tile_size + Vector2(
        WorldConfig.tile_size / 2.0, WorldConfig.tile_size / 2.0
    ) + actor._offset
    actor._move_toward(next_position, delta)


func tick(delta: float) -> void:
    var disruptor := _nearest_disruptor()
    if disruptor != null:
        if windup_timer > 0.0:
            windup_timer = 0.0
            cooldown = maxf(cooldown, 1.1)
            Events.fx_burst.emit("dust", actor.position + Vector2(0, -3), Vector2.ZERO, 0.7)
            actor.queue_redraw()
        actor._moving = false
        var retreat_direction: Vector2 = actor.position - disruptor.position
        if retreat_direction.length_squared() > 0.01:
            actor._move_toward(actor.position + retreat_direction.normalized() * 26.0, delta)
        return

    if windup_timer > 0.0:
        if not target_is_valid(target) or actor.position.distance_to(target.position) > 52.0:
            windup_timer = 0.0
            cooldown = maxf(cooldown, 1.0)
            actor.queue_redraw()
            return
        var aim: Vector2 = target.position - actor.position
        if aim.length_squared() > 0.01:
            actor.anim.face(aim)
        actor._moving = false
        windup_timer = maxf(0.0, windup_timer - delta)
        if windup_timer <= 0.0:
            var impact_target: Node2D = target
            var impact_damage := maxi(1, roundi(float(actor.damage) * damage_multiplier))
            impact_target.call("take_damage", impact_damage)
            Events.fx_burst.emit("debris", impact_target.global_position + Vector2(0, -8), -aim.normalized(), 1.5)
            Audio.play("siege_impact", 1.0, -2.0)
            Events.screen_shake.emit(1.0, 0.16)
            cooldown = cooldown_duration
            actor.queue_redraw()
        return

    if not target_is_valid(target):
        _clear_target()
        scan_timer = 0.0

    if target == null and scan_timer <= 0.0:
        select_target()
        scan_timer = scan_interval

    if target == null:
        if actor.is_garrison:
            if actor.position.distance_to(actor.guard_origin) > 16.0:
                actor._move_toward(actor.guard_origin, delta)
        else:
            _tick_advance(delta)
        return

    var distance: float = actor.position.distance_to(target.position)
    if distance <= maxf(24.0, actor._attack_reach() + 10.0):
        actor._moving = false
        if cooldown <= 0.0:
            windup_timer = windup_duration
            actor.anim.face(target.position - actor.position)
            Events.fx_burst.emit("dust", actor.position + Vector2(0, -4), Vector2.ZERO, 0.9)
            Audio.play("siege_windup", 1.0, -3.0)
            actor.queue_redraw()
        return

    if navigation == null:
        if not actor.is_garrison:
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


## Target the assault's assigned infrastructure rather than selecting a separate local target.
## The normal siege windup, counterplay and structural damage multiplier remain in use.
func tick_faction_assault_target(target_node: Node2D, delta: float) -> void:
    if target_node == null or not is_instance_valid(target_node) \
            or int(target_node.get("hp")) <= 0 \
            or not target_node.has_method("take_damage") \
            or not target_node.has_method("cells"):
        _clear_target()
        return

    target = target_node
    var disruptor := _nearest_disruptor()
    if disruptor != null:
        if windup_timer > 0.0:
            interrupt()
        actor._moving = false
        var retreat_direction: Vector2 = actor.position - disruptor.position
        if retreat_direction.length_squared() > 0.01:
            actor._move_toward(actor.position + retreat_direction.normalized() * 26.0, delta)
        return

    if windup_timer > 0.0:
        if not is_instance_valid(target) or int(target.get("hp")) <= 0 \
                or actor.position.distance_to(target.position) > 58.0:
            interrupt()
            return
        var aim: Vector2 = target.position - actor.position
        if aim.length_squared() > 0.01:
            actor.anim.face(aim)
        actor._moving = false
        windup_timer = maxf(0.0, windup_timer - delta)
        if windup_timer <= 0.0:
            var impact_damage := maxi(1, roundi(float(actor.damage) * damage_multiplier))
            target.call("take_damage", impact_damage)
            Events.fx_burst.emit("debris", target.global_position + Vector2(0, -8), -aim.normalized(), 1.5)
            Audio.play("siege_impact", 1.0, -2.0)
            Events.screen_shake.emit(1.0, 0.16)
            cooldown = cooldown_duration
            actor.queue_redraw()
        return

    var distance: float = actor.position.distance_to(target.position)
    if distance <= maxf(24.0, actor._attack_reach() + 10.0):
        actor._moving = false
        if cooldown <= 0.0:
            windup_timer = windup_duration
            actor.anim.face(target.position - actor.position)
            Events.fx_burst.emit("dust", actor.position + Vector2(0, -4), Vector2.ZERO, 0.9)
            Audio.play("siege_windup", 1.0, -3.0)
            actor.queue_redraw()
        return

    if navigation == null:
        return
    if path_version != navigation.version or path.is_empty() or repath_timer <= 0.0:
        var target_cells: Array[Vector2i] = target.call("cells")
        path = navigation.path_adjacent(actor.position, target_cells)
        path_index = 1 if path.size() > 1 else 0
        path_version = navigation.version
        repath_timer = 0.9
        if path.is_empty():
            return
    while path_index < path.size() and actor.position.distance_to(path[path_index]) <= 3.0:
        path_index += 1
    if path_index < path.size():
        actor._move_toward(path[path_index], delta)


func interrupt() -> void:
    if windup_timer <= 0.0:
        return
    windup_timer = 0.0
    cooldown = maxf(cooldown, 1.1)
    actor.queue_redraw()


func draw_telegraph(canvas: CanvasItem, frame_height: int) -> void:
    if target != null and is_instance_valid(target):
        var target_center: Vector2 = target.global_position - actor.global_position + Vector2(0, -8)
        var target_color := Color("#e1a45d") if windup_timer > 0.0 else Color("#9a6b4c")
        canvas.draw_line(Vector2(0, -frame_height - 5), target_center, target_color, 1.5)
        canvas.draw_arc(target_center, 13.0, 0.0, TAU, 12, target_color, 1.5)
    if windup_timer > 0.0:
        canvas.draw_arc(Vector2(0, -frame_height - 8), 8.0, 0.0, TAU, 12, Color("#f1c67b"), 2.0)
