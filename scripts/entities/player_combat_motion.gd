extends RefCounted
## Procedural character-body motion for player combat.
## Uses short, deterministic transforms; no Nodes, tweens, particles or runtime textures.

var _kind := ""
var _direction := Vector2.DOWN
var _duration := 0.3
var _elapsed := 0.0
var _active := false


func play(kind: String, direction: Vector2, duration: float) -> void:
    _kind = kind
    _direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.DOWN
    _duration = maxf(0.06, duration)
    _elapsed = 0.0
    _active = true


func clear() -> void:
    _kind = ""
    _elapsed = 0.0
    _active = false


func advance(delta: float) -> bool:
    if not _active:
        return false
    _elapsed = minf(_duration, _elapsed + maxf(0.0, delta))
    if _elapsed >= _duration:
        _active = false
        _kind = ""
    return true


func is_active() -> bool:
    return _active


func progress() -> float:
    return clampf(_elapsed / maxf(0.001, _duration), 0.0, 1.0) if _active else 0.0


func pose() -> Dictionary:
    if not _active:
        return _neutral_pose()

    var p := progress()
    var forward := _direction
    var side := Vector2(-forward.y, forward.x)
    var turn := _turn_sign(forward)
    var offset := Vector2.ZERO
    var rotation := 0.0
    var body_scale := Vector2.ONE

    match _kind:
        "quick":
            if p < 0.20:
                var windup := smoothstep(0.0, 0.20, p)
                offset = -forward * (2.2 * windup) - side * (0.65 * windup)
                rotation = -turn * 0.11 * windup
                body_scale = Vector2(lerpf(1.0, 1.055, windup), lerpf(1.0, 0.90, windup))
            elif p < 0.59:
                var strike := smoothstep(0.20, 0.59, p)
                offset = forward * lerpf(-2.2, 5.2, strike) + side * sin(strike * PI) * 1.15
                rotation = lerpf(-turn * 0.11, turn * 0.13, strike)
                body_scale = Vector2(
                    lerpf(1.055, 0.92, strike),
                    lerpf(0.90, 1.105, strike)
                )
            else:
                var recovery := smoothstep(0.59, 1.0, p)
                offset = forward * lerpf(5.2, 0.0, recovery)
                rotation = lerpf(turn * 0.13, 0.0, recovery)
                body_scale = Vector2(
                    lerpf(0.92, 1.0, recovery),
                    lerpf(1.105, 1.0, recovery)
                )

        "cross":
            if p < 0.22:
                var windup := smoothstep(0.0, 0.22, p)
                offset = -forward * (1.8 * windup) + side * (3.0 * windup)
                rotation = turn * 0.14 * windup
                body_scale = Vector2(lerpf(1.0, 1.07, windup), lerpf(1.0, 0.90, windup))
            elif p < 0.63:
                var strike := smoothstep(0.22, 0.63, p)
                offset = (
                    forward * lerpf(-1.8, 4.2, strike)
                    + side * lerpf(3.0, -3.6, strike)
                )
                rotation = lerpf(turn * 0.14, -turn * 0.16, strike)
                body_scale = Vector2(
                    lerpf(1.07, 0.90, strike),
                    lerpf(0.90, 1.12, strike)
                )
            else:
                var recovery := smoothstep(0.63, 1.0, p)
                offset = (forward * 4.2 - side * 3.6) * (1.0 - recovery)
                rotation = -turn * 0.16 * (1.0 - recovery)
                body_scale = Vector2(
                    lerpf(0.90, 1.0, recovery),
                    lerpf(1.12, 1.0, recovery)
                )

        "finisher":
            if p < 0.31:
                var load := smoothstep(0.0, 0.31, p)
                offset = -forward * (3.4 * load) + side * (0.8 * load)
                rotation = -turn * 0.15 * load
                body_scale = Vector2(lerpf(1.0, 1.13, load), lerpf(1.0, 0.78, load))
            elif p < 0.57:
                var drive := smoothstep(0.31, 0.57, p)
                offset = -forward * 3.4 + forward * (10.2 * drive) + side * lerpf(0.8, -1.4, drive)
                rotation = lerpf(-turn * 0.15, turn * 0.19, drive)
                body_scale = Vector2(lerpf(1.13, 0.86, drive), lerpf(0.78, 1.20, drive))
            elif p < 0.76:
                var impact := smoothstep(0.57, 0.76, p)
                offset = forward * lerpf(6.8, 5.4, impact) - side * 1.4
                rotation = turn * lerpf(0.19, 0.12, impact)
                body_scale = Vector2(lerpf(0.86, 0.94, impact), lerpf(1.20, 1.10, impact))
            else:
                var recovery := smoothstep(0.76, 1.0, p)
                offset = forward * lerpf(5.4, 0.0, recovery) - side * lerpf(1.4, 0.0, recovery)
                rotation = turn * lerpf(0.12, 0.0, recovery)
                body_scale = Vector2(lerpf(0.94, 1.0, recovery), lerpf(1.10, 1.0, recovery))

        "riposte":
            if p < 0.17:
                var load := smoothstep(0.0, 0.17, p)
                offset = -forward * 2.8 * load
                rotation = -turn * 0.13 * load
                body_scale = Vector2(lerpf(1.0, 1.10, load), lerpf(1.0, 0.86, load))
            elif p < 0.54:
                var counter := smoothstep(0.17, 0.54, p)
                offset = forward * lerpf(-2.8, 7.0, counter)
                rotation = lerpf(-turn * 0.13, turn * 0.17, counter)
                body_scale = Vector2(lerpf(1.10, 0.88, counter), lerpf(0.86, 1.16, counter))
            else:
                var recovery := smoothstep(0.54, 1.0, p)
                offset = forward * lerpf(7.0, 0.0, recovery)
                rotation = turn * lerpf(0.17, 0.0, recovery)
                body_scale = Vector2(lerpf(0.88, 1.0, recovery), lerpf(1.16, 1.0, recovery))

        "cleave", "cleave_empowered":
            var strength := 1.0 if _kind == "cleave" else 1.22
            if p < 0.30:
                var load := smoothstep(0.0, 0.30, p)
                offset = -forward * (3.0 * strength * load)
                rotation = -turn * 0.13 * load
                body_scale = Vector2(lerpf(1.0, 1.10, load), lerpf(1.0, 0.82, load))
            elif p < 0.70:
                var drive := smoothstep(0.30, 0.70, p)
                offset = forward * lerpf(-3.0 * strength, 6.0 * strength, drive)
                rotation = lerpf(-turn * 0.13, turn * 0.16, drive)
                body_scale = Vector2(lerpf(1.10, 0.88, drive), lerpf(0.82, 1.16, drive))
            else:
                var recovery := smoothstep(0.70, 1.0, p)
                offset = forward * lerpf(6.0 * strength, 0.0, recovery)
                rotation = turn * lerpf(0.16, 0.0, recovery)
                body_scale = Vector2(lerpf(0.88, 1.0, recovery), lerpf(1.16, 1.0, recovery))

        "dash":
            var launch := 1.0 - smoothstep(0.0, 1.0, p)
            offset = forward * (1.8 * launch)
            rotation = turn * 0.12 * launch
            body_scale = Vector2(1.10, 0.84)

        "rally":
            if p < 0.28:
                var brace := smoothstep(0.0, 0.28, p)
                offset = Vector2(0.0, 1.8 * brace)
                body_scale = Vector2(lerpf(1.0, 1.08, brace), lerpf(1.0, 0.84, brace))
            elif p < 0.66:
                var rise := smoothstep(0.28, 0.66, p)
                offset = Vector2(0.0, lerpf(1.8, -3.0, rise))
                rotation = -0.035 * rise
                body_scale = Vector2(lerpf(1.08, 0.94, rise), lerpf(0.84, 1.14, rise))
            else:
                var settle := smoothstep(0.66, 1.0, p)
                offset = Vector2(0.0, lerpf(-3.0, 0.0, settle))
                rotation = lerpf(-0.035, 0.0, settle)
                body_scale = Vector2(lerpf(0.94, 1.0, settle), lerpf(1.14, 1.0, settle))

        _:
            return _neutral_pose()

    return {
        "offset": offset,
        "rotation": rotation,
        "scale": body_scale
    }


func _turn_sign(direction: Vector2) -> float:
    if absf(direction.x) >= absf(direction.y):
        return 1.0 if direction.x >= 0.0 else -1.0
    return -1.0 if direction.y < 0.0 else 1.0


func _neutral_pose() -> Dictionary:
    return {
        "offset": Vector2.ZERO,
        "rotation": 0.0,
        "scale": Vector2.ONE
    }
