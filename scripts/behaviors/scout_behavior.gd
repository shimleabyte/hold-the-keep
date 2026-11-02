extends RefCounted
## Scout target acquisition, telegraphed marking, faction-only sharing and expiry policy.

const ENEMY_TARGETING := preload("res://scripts/systems/enemy_targeting.gd")

var actor

var mark_range := 142.0
var preferred_range := 96.0
var windup_duration := 0.68
var mark_duration := 5.4
var mark_cooldown_duration := 8.4
var share_radius := 190.0

var windup_timer := 0.0
var windup_target: Node2D
var mark_target: Node2D
var mark_timer := 0.0
var mark_cooldown := 0.0


func configure(owner, data: Dictionary) -> void:
    actor = owner
    mark_range = clampf(float(data.get("scout_mark_range", 142.0)), 80.0, 190.0)
    preferred_range = clampf(float(data.get("scout_preferred_range", 96.0)), 56.0, 140.0)
    windup_duration = clampf(float(data.get("scout_windup", 0.68)), 0.25, 1.5)
    mark_duration = clampf(float(data.get("scout_mark_duration", 5.4)), 2.5, 10.0)
    mark_cooldown_duration = clampf(float(data.get("scout_mark_cooldown", 8.4)), 4.0, 18.0)
    share_radius = clampf(float(data.get("scout_share_radius", 190.0)), 80.0, 280.0)
    reset()


func reset() -> void:
    windup_timer = 0.0
    windup_target = null
    mark_target = null
    mark_timer = 0.0
    mark_cooldown = 0.0


func advance_timers(delta: float) -> void:
    mark_timer = maxf(0.0, mark_timer - delta)
    mark_cooldown = maxf(0.0, mark_cooldown - delta)
    if mark_timer <= 0.0 or not is_instance_valid(mark_target):
        mark_timer = 0.0
        mark_target = null


func nearest_target() -> Node2D:
    var candidates: Array = actor.get_tree().get_nodes_in_group("defenders")
    if actor.player != null and is_instance_valid(actor.player):
        candidates.append(actor.player)
    var leash_center: Vector2 = actor.guard_origin if actor.is_garrison else Vector2.ZERO
    var leash_radius := 175.0 if actor.is_garrison else 0.0
    return ENEMY_TARGETING.nearest(actor, candidates, mark_range, leash_center, leash_radius)


func tick(delta: float) -> void:
    if windup_timer > 0.0:
        var pending_target: Node2D = windup_target
        if pending_target == null or not is_instance_valid(pending_target) or not pending_target.visible or actor.position.distance_to(pending_target.position) > mark_range + 24.0:
            windup_timer = 0.0
            windup_target = null
            mark_cooldown = minf(mark_cooldown, 0.8)
            actor.queue_redraw()
        else:
            var windup_direction: Vector2 = pending_target.position - actor.position
            if windup_direction.length_squared() > 0.01:
                actor.anim.face(windup_direction)
            actor._moving = false
            windup_timer = maxf(0.0, windup_timer - delta)
            if windup_timer <= 0.0:
                _release_mark(pending_target)
            actor.queue_redraw()
            return

    var target: Node2D = null
    if mark_timer > 0.0 and is_instance_valid(mark_target):
        target = mark_target
    else:
        target = nearest_target()

    if target == null:
        if actor.is_garrison:
            if actor.position.distance_to(actor.guard_origin) > 16.0:
                actor._move_toward(actor.guard_origin, delta)
        else:
            actor._tick_flow(delta)
        return

    var to_target: Vector2 = target.position - actor.position
    var distance: float = to_target.length()
    var direction: Vector2 = to_target.normalized() if distance > 0.01 else Vector2.DOWN

    if mark_timer <= 0.0 and mark_cooldown <= 0.0 and distance <= mark_range:
        windup_target = target
        windup_timer = windup_duration
        actor.anim.face(direction)
        Events.fx_burst.emit("dust", actor.position + Vector2(0, -3), -direction, 0.65)
        actor.queue_redraw()
        return

    if distance < preferred_range - 14.0:
        actor._move_toward(actor.position - direction * 36.0, delta)
    elif distance > preferred_range + 18.0:
        actor._move_toward(target.position - direction * preferred_range, delta)
    else:
        actor._moving = false


func _release_mark(target: Node2D) -> void:
    if target == null or not is_instance_valid(target) or not target.visible:
        windup_timer = 0.0
        windup_target = null
        return
    windup_timer = 0.0
    windup_target = null
    mark_target = target
    mark_timer = mark_duration
    mark_cooldown = mark_cooldown_duration
    var rally_position: Vector2 = target.global_position + Vector2(0, -8)
    Events.fx_burst.emit("rally", rally_position, Vector2.ZERO, 1.0)

    for ally in actor.get_tree().get_nodes_in_group("enemies"):
        if ally == actor or not is_instance_valid(ally) or not (ally is Node2D):
            continue
        var enemy_ally := ally as Node2D
        if String(enemy_ally.get("faction_id")) != String(actor.faction_id):
            continue
        if actor.global_position.distance_to(enemy_ally.global_position) > share_radius:
            continue
        if enemy_ally.has_method("apply_scout_mark"):
            enemy_ally.apply_scout_mark(target, mark_duration)
    actor.queue_redraw()


func apply_mark(target: Node2D, duration: float) -> void:
    if target == null or not is_instance_valid(target) or not target.visible or duration <= 0.0:
        return
    if mark_timer > 0.0 and is_instance_valid(mark_target) and mark_target != target:
        return
    mark_target = target
    mark_timer = maxf(mark_timer, minf(duration, 10.0))
    actor.queue_redraw()


func valid_mark(max_distance: float) -> Node2D:
    if mark_timer <= 0.0 or mark_target == null or not is_instance_valid(mark_target):
        return null
    if not mark_target.visible:
        return null
    if actor.position.distance_to(mark_target.position) > max_distance:
        return null
    if actor.is_garrison and mark_target.position.distance_to(actor.guard_origin) > 175.0:
        return null
    return mark_target


func interrupt() -> void:
    if windup_timer <= 0.0:
        return
    windup_timer = 0.0
    windup_target = null
    mark_cooldown = maxf(mark_cooldown, 1.2)
    actor.queue_redraw()


func draw_telegraph(canvas: CanvasItem, frame_height: int, scout_color: Color) -> void:
    canvas.draw_line(Vector2(-4, -15), Vector2(0, -19), scout_color, 1.5)
    canvas.draw_line(Vector2(0, -19), Vector2(4, -15), scout_color, 1.5)
    var marker_target: Node2D = windup_target if windup_timer > 0.0 else mark_target
    if marker_target == null or not is_instance_valid(marker_target):
        return
    var marker_center: Vector2 = marker_target.global_position - actor.global_position + Vector2(0, -8)
    var marker_color := Color("#efca78") if windup_timer > 0.0 else Color("#d99b45")
    canvas.draw_line(Vector2(0, -frame_height - 5), marker_center, marker_color, 1.0)
    canvas.draw_arc(marker_center, 10.0, 0.0, TAU, 12, marker_color, 1.5)
    if windup_timer > 0.0:
        canvas.draw_arc(Vector2(0, -frame_height - 8), 5.0, 0.0, TAU, 8, Color("#efca78"), 1.5)
