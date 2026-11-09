extends RefCounted
## Deterministic, draw-only combat cues shared by the player and enemy actors.
## Does not apply damage, movement, cooldowns, status effects or gameplay state.

const HIT_DURATION := 0.16
const CLEAVE_HALF_ANGLE := 1.2

var windup_remaining := 0.0
var windup_total := 0.0
var windup_direction := Vector2.DOWN
var windup_projectile := false

var impact_remaining := 0.0
var impact_direction := Vector2.ZERO
var impact_strength := 1.0

var stagger_remaining := 0.0
var stagger_total := 0.0

var ability_remaining := 0.0
var ability_total := 0.0
var ability_kind := ""
var ability_direction := Vector2.DOWN

var swing_remaining := 0.0
var swing_total := 0.0
var swing_direction := Vector2.RIGHT
var swing_weight := 1.0


func register_swing(direction: Vector2, duration: float = 0.28, weight: float = 1.0) -> void:
    swing_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector2.DOWN
    swing_total = maxf(0.08, duration)
    swing_remaining = swing_total
    swing_weight = clampf(weight, 0.75, 1.8)


func end_swing() -> void:
    swing_remaining = 0.0
    swing_total = 0.0


func begin_windup(direction: Vector2, duration: float, projectile: bool = false) -> void:
    windup_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector2.DOWN
    windup_total = maxf(0.06, duration)
    windup_remaining = windup_total
    windup_projectile = projectile


func end_windup() -> void:
    windup_remaining = 0.0
    windup_total = 0.0
    windup_projectile = false


func register_hit(source_position: Vector2, actor_position: Vector2, strength: float = 1.0) -> void:
    impact_direction = (source_position - actor_position).normalized() if source_position != Vector2.ZERO else Vector2.ZERO
    impact_strength = clampf(strength, 0.5, 2.5)
    impact_remaining = HIT_DURATION


func register_stagger(duration: float) -> void:
    stagger_total = maxf(stagger_total, maxf(0.0, duration))
    stagger_remaining = maxf(stagger_remaining, maxf(0.0, duration))


func register_ability(kind: String, direction: Vector2, duration: float = 0.32) -> void:
    ability_kind = kind
    ability_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector2.DOWN
    ability_total = maxf(0.06, duration)
    ability_remaining = ability_total


func advance(delta: float) -> bool:
    var was_active := is_active()
    windup_remaining = maxf(0.0, windup_remaining - delta)
    impact_remaining = maxf(0.0, impact_remaining - delta)
    stagger_remaining = maxf(0.0, stagger_remaining - delta)
    ability_remaining = maxf(0.0, ability_remaining - delta)
    swing_remaining = maxf(0.0, swing_remaining - delta)
    if windup_remaining <= 0.0:
        windup_total = 0.0
        windup_projectile = false
    if stagger_remaining <= 0.0:
        stagger_total = 0.0
    if ability_remaining <= 0.0:
        ability_total = 0.0
        ability_kind = ""
    if swing_remaining <= 0.0:
        swing_total = 0.0
    return was_active or is_active()


func is_active() -> bool:
    return windup_remaining > 0.0 or impact_remaining > 0.0 or stagger_remaining > 0.0 or ability_remaining > 0.0 or swing_remaining > 0.0


func draw(canvas: CanvasItem, frame_height: int, faction_tint: Color = Color.WHITE) -> void:
    var center := Vector2(0.0, -float(frame_height) * 0.55)

    if windup_remaining > 0.0:
        var progress := 1.0 - windup_remaining / maxf(0.001, windup_total)
        var direction := windup_direction
        var angle := direction.angle()
        var amber := Color("#f0c36c")
        var reach := 10.0 + progress * 4.0
        canvas.draw_line(center + direction * 4.0, center + direction * reach, amber, 1.5)
        canvas.draw_arc(center, 7.0 + progress * 2.0, angle - 0.38, angle + 0.38, 8, amber, 1.5)
        if windup_projectile:
            var tip := center + direction * (reach + 2.0)
            var wing := direction.rotated(PI * 0.78) * 3.0
            canvas.draw_line(tip - wing, tip, Color("#fff0c5"), 1.0)
            canvas.draw_line(tip + wing, tip, Color("#fff0c5"), 1.0)
        else:
            canvas.draw_line(center + direction.rotated(-0.55) * 6.0, center + direction * reach, Color("#fff0c5"), 1.0)

    if swing_remaining > 0.0:
        var progress := 1.0 - swing_remaining / maxf(0.001, swing_total)
        var eased := smoothstep(0.0, 1.0, progress)
        var contact_angle := swing_direction.angle() + lerpf(-0.76, 0.58, eased)
        var arc_length := lerpf(0.3, 0.68, swing_weight / 1.8)
        var radius := 12.0 + swing_weight * 2.0
        var fade := 1.0 - smoothstep(0.76, 1.0, progress)
        var slash := Color(0.93, 0.86, 0.68, fade * 0.88)
        var edge := Color(0.98, 0.95, 0.84, fade)
        canvas.draw_arc(center, radius, contact_angle - arc_length, contact_angle,
            8, slash, 1.0 + swing_weight * 0.65)
        var tip := center + Vector2.RIGHT.rotated(contact_angle) * (radius + 1.0)
        var tail := center + Vector2.RIGHT.rotated(contact_angle - arc_length) * (radius - 1.0)
        canvas.draw_line(tail, tip, edge, 1.0 + swing_weight * 0.45)
        if swing_weight > 1.25:
            var inner := center + Vector2.RIGHT.rotated(contact_angle - arc_length * 0.7) * (radius - 4.0)
            var inner_tip := center + Vector2.RIGHT.rotated(contact_angle) * (radius - 3.0)
            canvas.draw_line(inner, inner_tip, Color(1.0, 0.88, 0.66, fade * 0.72), 1.0)

    if impact_remaining > 0.0:
        var progress := 1.0 - impact_remaining / HIT_DURATION
        var alpha := 1.0 - progress
        var radius := 3.0 + progress * 7.0
        var impact_color := Color(1.0, 0.91, 0.69, alpha)
        canvas.draw_arc(center, radius, 0.0, TAU, 12, impact_color, 1.25)
        for spoke in 4:
            var angle := float(spoke) * PI * 0.5
            var direction := Vector2.RIGHT.rotated(angle)
            var inner := center + direction * (radius + 1.0)
            var outer := center + direction * (radius + 2.0 + impact_strength * 1.5)
            canvas.draw_line(inner, outer, impact_color, 1.0)
        if impact_direction != Vector2.ZERO:
            var edge := center + impact_direction * (radius + 2.0)
            var tangent := impact_direction.rotated(PI * 0.5) * 2.5
            canvas.draw_line(edge - tangent, edge + impact_direction * 3.0, Color("#cf8256", alpha), 1.5)
            canvas.draw_line(edge + tangent, edge + impact_direction * 3.0, Color("#cf8256", alpha), 1.5)

    if stagger_remaining > 0.0:
        var ratio := clampf(stagger_remaining / maxf(0.001, stagger_total), 0.0, 1.0)
        var alpha := 0.45 + ratio * 0.55
        var daze_color := Color(0.88, 0.69, 0.43, alpha)
        var head_y := -float(frame_height) - 3.0
        canvas.draw_arc(Vector2(0.0, head_y), 6.0, PI * 1.12, PI * 1.88, 8, daze_color, 1.0)
        for marker in 3:
            var x := float(marker - 1) * 5.0
            var y := head_y - 4.0 - (1.0 if marker == 1 else 0.0)
            canvas.draw_line(Vector2(x - 1.5, y + 1.5), Vector2(x, y - 1.5), daze_color, 1.2)
            canvas.draw_line(Vector2(x, y - 1.5), Vector2(x + 1.5, y + 1.5), daze_color, 1.2)

    if ability_remaining > 0.0:
        var progress := 1.0 - ability_remaining / maxf(0.001, ability_total)
        var alpha := 1.0 - progress
        match ability_kind:
            "dash":
                var direction := ability_direction
                var side := direction.rotated(PI * 0.5)
                for trail in 3:
                    var offset := -direction * (5.0 + float(trail) * 4.0)
                    var p := center + offset
                    var tint := Color(0.73, 0.86, 0.78, alpha * (1.0 - float(trail) * 0.2))
                    canvas.draw_line(p - side * 3.0, p + direction * 3.0, tint, 1.2)
                    canvas.draw_line(p + direction * 3.0, p + side * 3.0, tint, 1.2)
            "cleave":
                var angle := ability_direction.angle()
                canvas.draw_arc(center, 13.0 + progress * 9.0, angle - CLEAVE_HALF_ANGLE, angle + CLEAVE_HALF_ANGLE,
                    12, Color(1.0, 0.82, 0.42, alpha), 1.5)
            "cleave_empowered":
                var angle := ability_direction.angle()
                var radius := 16.0 + progress * 18.0
                canvas.draw_arc(center, radius, angle - CLEAVE_HALF_ANGLE, angle + CLEAVE_HALF_ANGLE,
                    16, Color(1.0, 0.88, 0.56, alpha), 2.0)
                canvas.draw_arc(center, radius * 0.72, angle - 0.86, angle + 0.86,
                    12, Color(1.0, 0.62, 0.27, alpha * 0.82), 1.0)
                for marker in 5:
                    var spoke := angle + lerpf(-CLEAVE_HALF_ANGLE, CLEAVE_HALF_ANGLE, float(marker) / 4.0)
                    var direction := Vector2.RIGHT.rotated(spoke)
                    canvas.draw_line(center + direction * (radius - 2.0),
                        center + direction * (radius + 3.0), Color(1.0, 0.93, 0.69, alpha), 1.0)
            "riposte":
                var radius := 8.0 + progress * 15.0
                canvas.draw_arc(center, radius, 0.0, TAU, 16, Color("#f4e7ae", alpha), 1.5)
                for marker in 6:
                    var direction := Vector2.RIGHT.rotated(float(marker) * TAU / 6.0)
                    canvas.draw_line(center + direction * (radius + 1.0),
                        center + direction * (radius + 4.0), Color("#fff5ca", alpha), 1.25)
            "rally":
                canvas.draw_arc(center, 9.0 + progress * 10.0, 0.0, TAU, 16,
                    Color(0.79, 0.84, 0.58, alpha), 1.0)
                canvas.draw_arc(center, 15.0 + progress * 12.0, 0.0, TAU, 16,
                    Color(faction_tint.r, faction_tint.g, faction_tint.b, alpha * 0.8), 1.0)
