extends RefCounted
## Shieldbearer directional brace policy: target response, telegraph, mitigation and interruption.

var actor

var trigger_range := 64.0
var windup_duration := 0.55
var active_duration := 1.05
var cooldown_duration := 4.2
var block_damage_multiplier := 0.45
var front_dot_threshold := 0.5

var windup_timer := 0.0
var active_timer := 0.0
var cooldown := 0.0
var brace_direction := Vector2.ZERO


func configure(owner, data: Dictionary) -> void:
    actor = owner
    trigger_range = clampf(float(data.get("brace_trigger_range", 64.0)), 24.0, 110.0)
    windup_duration = clampf(float(data.get("brace_windup", 0.55)), 0.2, 1.5)
    active_duration = clampf(float(data.get("brace_duration", 1.05)), 0.3, 2.0)
    cooldown_duration = clampf(float(data.get("brace_cooldown", 4.2)), 1.0, 12.0)
    block_damage_multiplier = clampf(float(data.get("brace_damage_multiplier", 0.45)), 0.1, 1.0)
    front_dot_threshold = clampf(float(data.get("brace_front_dot", 0.5)), 0.1, 0.95)
    reset()


func reset() -> void:
    windup_timer = 0.0
    active_timer = 0.0
    cooldown = 0.0
    brace_direction = Vector2.ZERO


func advance_timers(delta: float) -> void:
    cooldown = maxf(0.0, cooldown - delta)


func tick(delta: float) -> void:
    if active_timer > 0.0:
        active_timer = maxf(0.0, active_timer - delta)
        actor._moving = false
        if active_timer <= 0.0:
            brace_direction = Vector2.ZERO
        actor.queue_redraw()
        return

    var target: Node2D = actor._nearest_shield_target()
    if windup_timer > 0.0:
        if target == null or actor.position.distance_to(target.position) > trigger_range + 24.0:
            windup_timer = 0.0
            cooldown = minf(cooldown, 0.8)
            brace_direction = Vector2.ZERO
        else:
            var windup_direction: Vector2 = target.position - actor.position
            if windup_direction.length_squared() > 0.01:
                brace_direction = windup_direction.normalized()
                actor.anim.face(brace_direction)
            windup_timer = maxf(0.0, windup_timer - delta)
            if windup_timer <= 0.0:
                active_timer = active_duration
                Events.fx_burst.emit("stone", actor.position + Vector2(0, -6), -brace_direction, 0.55)
            actor.queue_redraw()
            return

    if target == null:
        if actor.is_garrison:
            if actor.position.distance_to(actor.guard_origin) > 16.0:
                actor._move_toward(actor.guard_origin, delta)
        else:
            actor._tick_flow(delta)
        return

    var to_target: Vector2 = target.position - actor.position
    var distance: float = to_target.length()
    if distance <= actor._attack_reach():
        actor._begin_attack(target, to_target)
        return

    if distance <= trigger_range and cooldown <= 0.0:
        brace_direction = to_target.normalized() if distance > 0.01 else Vector2.DOWN
        actor.anim.face(brace_direction)
        windup_timer = windup_duration
        cooldown = cooldown_duration
        Events.fx_burst.emit("dust", actor.position + Vector2(0, -3), -brace_direction, 0.55)
        actor.queue_redraw()
        return

    if actor.is_garrison:
        if actor.position.distance_to(actor.guard_origin) <= 150.0:
            actor._move_toward(target.position, delta)
        else:
            actor._move_toward(actor.guard_origin, delta)
    elif distance <= actor.SHIELD_TARGET_RANGE:
        actor._move_toward(target.position, delta)
    else:
        actor._tick_flow(delta)


func interrupt() -> void:
    windup_timer = 0.0
    active_timer = 0.0
    cooldown = maxf(cooldown, 1.1)
    brace_direction = Vector2.ZERO
    actor.queue_redraw()


func blocks_hit_from(source_position: Vector2) -> bool:
    if active_timer <= 0.0 or source_position == Vector2.ZERO:
        return false
    var incoming_direction := (source_position - actor.global_position).normalized()
    return incoming_direction.dot(brace_direction) >= front_dot_threshold


func draw_telegraph(canvas: CanvasItem, frame_height: int) -> void:
    if windup_timer <= 0.0 and active_timer <= 0.0:
        return
    var brace_center := Vector2(0, -frame_height * 0.55)
    var brace_angle := brace_direction.angle()
    if windup_timer > 0.0:
        canvas.draw_arc(brace_center, 17.0, brace_angle - 0.82, brace_angle + 0.82,
            12, Color("#d8bd87"), 1.5)
        canvas.draw_line(brace_center, brace_center + brace_direction * 20.0,
            Color("#f0d7a5"), 2.0)
    else:
        canvas.draw_arc(brace_center, 18.0, brace_angle - 0.92, brace_angle + 0.92,
            12, Color("#d8bd87"), 2.0)
        canvas.draw_arc(brace_center, 22.0, brace_angle - 0.72, brace_angle + 0.72,
            12, Color("#8795a5"), 1.0)
