extends SceneTree
## Regression checks for pixel-snapped secondary motion across character clips.

const SpriteAnim := preload("res://scripts/entities/sprite_anim.gd")


func _initialize() -> void:
    var anim = SpriteAnim.new()
    anim.face(Vector2.RIGHT)
    anim.play("idle", true)

    var idle_motion_seen := false
    for frame in 120:
        anim.update(1.0 / 60.0)
        if anim.motion_offset().y != 0.0:
            idle_motion_seen = true
    assert(idle_motion_seen, "Idle breathing must produce subtle motion over time")

    anim.play("walk", true)
    anim.update(0.08)
    assert(anim.motion_offset().y < 0.0, "Walk cycle must lift the body between steps")

    anim.play("run", true)
    anim.update(0.083)
    assert(anim.motion_offset().y <= -2.0, "Run cycle must have a stronger lift than walking")

    anim.face(Vector2.RIGHT)
    anim.play("attack", true)
    anim.update(0.15)
    assert(anim.motion_offset().x > 0.0, "Attack must lunge toward the facing direction")

    anim.face(Vector2.LEFT)
    anim.play("attack", true)
    anim.update(0.15)
    assert(anim.motion_offset().x < 0.0, "Mirrored attack must lunge left, not right")

    anim.play("work", true)
    anim.manual_progress = 0.5
    assert(anim.motion_offset().x < 0.0, "Work lean must follow left-facing direction")
    anim.manual_progress = -1.0

    anim.play("hurt", true)
    assert(anim.motion_offset().x > 0.0, "Hurt recoil must push opposite the facing direction")

    anim.play("death", true)
    assert(anim.motion_offset() == Vector2.ZERO, "Death pose must remain stable without idle bob")

    print("PASS: idle, walk, run, attack, work, hurt, and death secondary motion")
    quit()
