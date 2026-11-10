extends RefCounted
## Shieldbearer directional brace policy: target response, telegraph, mitigation and interruption.

var actor
var target_chase_range := 96.0

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


func configure(owner, data: Dictionary, chase_range: float = 96.0) -> void:
    actor = owner
    target_chase_range = maxf(1.0, chase_range)
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
        Audio.play("shield_raise", 1.0, -7.0)
        actor.queue_redraw()
        return

    if actor.is_garrison:
        if actor.position.distance_to(actor.guard_origin) <= 150.0:
            actor._move_toward(target.position, delta)
        else:
            actor._move_toward(actor.guard_origin, delta)
    elif distance <= target_chase_range:
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
    var incoming_direction: Vector2 = (source_position - actor.global_position).normalized()
    return incoming_direction.dot(brace_direction) >= front_dot_threshold


func draw_telegraph(canvas: CanvasItem, frame_height: int) -> void:
    if windup_timer <= 0.0 and active_timer <= 0.0:
        return

    var direction := brace_direction.normalized() if brace_direction.length_squared() > 0.001 else Vector2.DOWN
    var side := direction.rotated(PI * 0.5)
    var center := Vector2(0.0, -float(frame_height) * 0.55)
    var progress := 1.0
    var active := active_timer > 0.0
    if not active:
        progress = clampf(1.0 - windup_timer / maxf(0.001, windup_duration), 0.0, 1.0)

    # Present the shield on the incoming side, rather than floating a ring over
    # the unit. The same locked brace direction still controls the real block.
    var reach := 7.0 + progress * 2.0
    var shield_center := center + direction * reach
    var upper := shield_center - direction * 4.0 - side * 6.0
    var lower := shield_center + direction * 3.0 - side * 5.0
    var lower_tip := shield_center + direction * 7.0
    var lower_far := shield_center + direction * 3.0 + side * 5.0
    var upper_far := shield_center - direction * 4.0 + side * 6.0
    var silhouette := PackedVector2Array([upper, lower, lower_tip, lower_far, upper_far])
    var fill := PackedVector2Array([
        upper + direction * 1.5 + side * 1.0,
        lower + direction * 1.0 + side * 0.8,
        lower_tip - direction * 1.0,
        lower_far + direction * 1.0 - side * 0.8,
        upper_far + direction * 1.5 - side * 1.0
    ])
    var alpha := 0.78 if active else lerpf(0.48, 0.82, progress)
    var rim := Color(0.13, 0.16, 0.17, alpha)
    var metal := Color(0.55, 0.60, 0.59, alpha)
    var edge := Color(0.82, 0.74, 0.56, alpha)
    canvas.draw_colored_polygon(silhouette, rim)
    canvas.draw_colored_polygon(fill, metal)
    canvas.draw_line(upper + direction * 2.0, lower_tip - direction * 2.0, edge, 1.2)
    canvas.draw_line(lower + side * 1.0, lower_far - side * 1.0, rim, 1.0)
    var boss := shield_center + direction * 1.0
    canvas.draw_circle(boss, 1.8, edge)
    canvas.draw_line(boss - side * 2.0, boss + side * 2.0, rim, 1.0)

    # A compressed footprint is visible only while the unit is committed to its brace.
    var foot := Vector2(0.0, -1.5)
    canvas.draw_line(foot - side * 4.0, foot + side * 4.0, Color(0.12, 0.14, 0.13, alpha * 0.75), 1.0)
    if not active:
        canvas.draw_line(center, center + direction * 17.0,
            Color(0.82, 0.69, 0.46, 0.55 + progress * 0.25), 1.0)
