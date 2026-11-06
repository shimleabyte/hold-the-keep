extends SceneTree
## Regression checks for pixel-snapped secondary motion across character clips.

const SpriteAnim := preload("res://scripts/entities/sprite_anim.gd")


func _initialize() -> void:
    var events = root.get_node("Events")
    assert(SpriteAnim.FRAMES == 22,
        "Profession animation must reuse the existing 22-frame sprite sheet")
    var VillagerScript: Script = load("res://scripts/entities/villager.gd")
    var PlayerScript: Script = load("res://scripts/entities/player.gd")
    var ResourceTreeScript: Script = load("res://scripts/entities/resource_tree.gd")
    var RockScript: Script = load("res://scripts/entities/rock.gd")
    var IronOreScript: Script = load("res://scripts/entities/iron_ore.gd")
    var WildlifeScript: Script = load("res://scripts/entities/wildlife_node.gd")
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
    assert(anim.motion_offset() == Vector2.ZERO, "Attack must keep the sprite pivot planted; sword and upper-body frames carry the motion")

    anim.face(Vector2.LEFT)
    anim.play("attack", true)
    anim.update(0.15)
    assert(anim.motion_offset() == Vector2.ZERO, "Mirrored attack must also keep the sprite pivot planted")

    anim.play("work", true)
    anim.work_style = "builder"
    anim.manual_progress = 0.0
    assert(anim.update(1.0 / 60.0),
        "Entering a manually synchronized work clip must request a redraw")
    var work_start_frame := anim.frame_index()
    anim.manual_progress = 0.5
    assert(anim.frame_index() != work_start_frame, "Work animation must advance when its work-cycle progress advances")
    assert(anim.update(1.0 / 60.0),
        "Changing manual work progress must invalidate the rendered frame")
    assert(anim.motion_offset().x < 0.0, "Work lean must follow left-facing direction")
    anim.manual_progress = -1.0

    var work_styles := ["woodcutter", "miner", "builder", "blacksmith", "farmer"]
    var distinct_offsets: Array[Vector2] = []
    for style in work_styles:
        anim.work_style = style
        anim.manual_progress = 0.30
        var offset: Vector2 = anim.motion_offset()
        if not distinct_offsets.has(offset):
            distinct_offsets.append(offset)
    assert(distinct_offsets.size() == work_styles.size(),
        "Each profession must have a distinct body-weight transfer during its work cycle")

    anim.work_style = "woodcutter"
    anim.manual_progress = 0.23
    var woodcutter_windup_frame := anim.frame_index()
    anim.work_style = "miner"
    var miner_windup_frame := anim.frame_index()
    assert(woodcutter_windup_frame != miner_windup_frame,
        "Woodcutting and mining must not use the same wind-up frame timing")
    anim.work_style = "builder"
    anim.manual_progress = 0.73
    var builder_recovery_frame := anim.frame_index()
    anim.work_style = "blacksmith"
    var smith_recovery_frame := anim.frame_index()
    assert(builder_recovery_frame != smith_recovery_frame,
        "Construction and forging must not use the same recovery frame timing")
    for style in work_styles:
        anim.work_style = style
        anim.manual_progress = 0.50
        assert(anim.frame_index() == 16,
            "%s contact must use the baked work impact frame" % style)
    anim.manual_progress = -1.0

    var builder = VillagerScript.new()
    assert(not builder.builder_behavior_advance_construction(0.79),
        "Builder construction must remain in wind-up before the midpoint")
    assert(builder.builder_behavior_advance_construction(0.02),
        "Builder construction must reach contact at the midpoint of its work cycle")
    assert(builder._work_t > 0.8 and builder._work_t < 0.9,
        "Construction animation progress must remain continuous at contact")
    anim.work_style = "builder"
    anim.manual_progress = fposmod(builder._work_t, 1.6) / 1.6
    assert(anim.frame_index() == 16,
        "Builder construction contact must align with the baked hammer impact")

    builder._work_t = 0.0
    assert(not builder.builder_behavior_advance_work(0.79),
        "Builder repair must wind up before its contact frame")
    assert(builder.builder_behavior_advance_work(0.02),
        "Builder repair must resolve at its contact frame")
    anim.manual_progress = fposmod(builder._work_t, 1.6) / 1.6
    assert(anim.frame_index() == 16,
        "Builder repair contact must align with the baked hammer impact")

    builder._work_t = 0.0
    var forge_fx_count := [0]
    var forge_fx_callback := func(_kind: String, _at: Vector2, _dir: Vector2, _amount: float) -> void:
        forge_fx_count[0] += 1
    events.fx_burst.connect(forge_fx_callback)
    assert(not builder.blacksmith_behavior_advance_work(0.75),
        "Forging must remain active before its first hammer contact")
    anim.work_style = "blacksmith"
    anim.manual_progress = fposmod(builder._work_t, 1.5) / 1.5
    assert(anim.frame_index() == 16,
        "Blacksmith impact must align with the baked spark accent")
    assert(not builder.blacksmith_behavior_advance_work(0.75),
        "Forging must continue after the first strike")
    assert(not builder.blacksmith_behavior_advance_work(1.5),
        "Forging must continue through its second strike")
    assert(builder.blacksmith_behavior_advance_work(1.5),
        "Forging must complete after its final strike")
    events.fx_burst.disconnect(forge_fx_callback)
    assert(forge_fx_count[0] == 0,
        "Blacksmith work must use baked contact accents instead of runtime particle bursts")
    builder.free()
    anim.manual_progress = -1.0

    var gatherer = VillagerScript.new()
    var worker_fx_count := [0]
    var worker_fx_callback := func(_kind: String, _at: Vector2, _dir: Vector2, _amount: float) -> void:
        worker_fx_count[0] += 1
    events.fx_burst.connect(worker_fx_callback)
    var tree_node = ResourceTreeScript.new()
    var rock_node = RockScript.new()
    var ore_node = IronOreScript.new()
    var wildlife_node = WildlifeScript.new()
    tree_node.hit(gatherer)
    assert(gatherer.carry_kind == "wood" and gatherer.carry == 1,
        "Woodcutter output must be preserved without worker hit particles")
    rock_node.hit(gatherer)
    assert(gatherer.carry_kind == "stone" and gatherer.carry == 1,
        "Miner output must be preserved without worker hit particles")
    ore_node.hit(gatherer)
    assert(gatherer.carry_kind == "iron" and gatherer.carry == 1,
        "Iron output must be preserved without worker hit particles")
    wildlife_node.hit(gatherer)
    assert(gatherer.carry_kind == "food" and gatherer.carry == 1,
        "Hunter output must be preserved without worker hit particles")
    assert(worker_fx_count[0] == 0,
        "Autonomous resource harvesting must not spawn per-hit particle bursts")
    tree_node.hit()
    assert(worker_fx_count[0] > 0,
        "Direct player harvesting must retain immediate resource hit feedback")
    events.fx_burst.disconnect(worker_fx_callback)
    tree_node.free()
    rock_node.free()
    ore_node.free()
    wildlife_node.free()
    gatherer.free()

    var player = PlayerScript.new()
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
