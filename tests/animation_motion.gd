extends SceneTree
## Regression checks for pixel-snapped secondary motion across character clips.

const SpriteAnim := preload("res://scripts/entities/sprite_anim.gd")
const Player := preload("res://scripts/entities/player.gd")
const Villager := preload("res://scripts/entities/villager.gd")


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
    anim.manual_progress = 0.0
    var work_start_frame := anim.frame_index()
    anim.manual_progress = 0.5
    assert(anim.frame_index() != work_start_frame, "Work animation must advance when its work-cycle progress advances")
    assert(anim.motion_offset().x < 0.0, "Work lean must follow left-facing direction")
    anim.manual_progress = -1.0

    var work_styles := ["woodcutter", "miner", "builder", "blacksmith", "farmer"]
    var distinct_offsets: Array[Vector2] = []
    var profile_frames: Dictionary = {}
    for style in work_styles:
        anim.work_style = style
        anim.manual_progress = 0.30
        var offset: Vector2 = anim.motion_offset()
        if not distinct_offsets.has(offset):
            distinct_offsets.append(offset)
        profile_frames[style] = anim.frame_index()
    assert(distinct_offsets.size() == work_styles.size(),
        "Each profession must have a distinct body-weight transfer during its work cycle")
    assert(profile_frames["woodcutter"] != profile_frames["miner"],
        "Woodcutting and mining must not use the same work-frame timing")
    assert(profile_frames["builder"] != profile_frames["blacksmith"],
        "Construction and forging must not use the same hammer timing")
    anim.manual_progress = -1.0

    var builder = Villager.new()
    assert(not builder.builder_behavior_advance_construction(0.79),
        "Builder must remain in wind-up before the midpoint of its work cycle")
    assert(builder.builder_behavior_advance_construction(0.02),
        "Builder construction impact must trigger at the midpoint of its work cycle")
    assert(builder._work_t > 0.8 and builder._work_t < 0.9,
        "Builder work progress must remain continuous through the impact frame")
    anim.work_style = "builder"
    anim.manual_progress = fposmod(builder._work_t, 1.6) / 1.6
    assert(anim.frame_index() == 16,
        "Builder construction impact must be drawn on the low hammer/contact frame")

    builder._work_t = 0.0
    assert(not builder.builder_behavior_advance_work(0.79),
        "Builder repair must wind up before its contact frame")
    assert(builder.builder_behavior_advance_work(0.02),
        "Builder repair must resolve on the contact frame without resetting its animation timer")
    anim.manual_progress = fposmod(builder._work_t, 1.6) / 1.6
    assert(anim.frame_index() == 16,
        "Builder repair contact must align with the low hammer/contact frame")

    builder._work_t = 0.0
    assert(not builder.blacksmith_behavior_advance_work(0.75),
        "Forging must still be active during its first hammer cycle")
    anim.work_style = "blacksmith"
    anim.manual_progress = fposmod(builder._work_t, 1.5) / 1.5
    assert(anim.frame_index() == 16,
        "Blacksmith sparks/contact art must align with the hammer impact frame")
    assert(not builder.blacksmith_behavior_advance_work(0.75),
        "Forging must continue after its first impact")
    assert(not builder.blacksmith_behavior_advance_work(1.5),
        "Forging must continue through its second hammer cycle")
    assert(builder.blacksmith_behavior_advance_work(1.5),
        "Forging must complete after its third hammer cycle")
    builder.free()

    var player = Player.new()
    player.anim.play("work", true)
    player._harvest_anim_active = true
    player._pending_harvest = RefCounted.new()
    player._harvest_t = 0.1
    player._cancel_harvest_animation()
    assert(not player._harvest_anim_active, "Releasing interact must clear the harvest animation state")
    assert(player._pending_harvest == null, "Releasing interact must cancel the pending harvest hit")
    assert(player.anim.clip == "idle" and not player.anim.is_busy(), "Releasing interact must return the player to a non-busy animation")
    player.free()

    anim.play("hurt", true)
    assert(anim.motion_offset().x > 0.0, "Hurt recoil must push opposite the facing direction")

    anim.play("death", true)
    assert(anim.motion_offset() == Vector2.ZERO, "Death pose must remain stable without idle bob")

    print("PASS: idle, walk, run, attack, work, hurt, and death secondary motion")
    quit()
