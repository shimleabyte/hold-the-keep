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

    # Shared role sheets keep the actor pivot fixed; their own atlas poses carry locomotion.
    anim.play("walk", true)
    anim.update(0.08)
    assert(anim.motion_offset() == Vector2.ZERO,
        "Shared walk poses must not add global bob that detaches planted feet")
    anim.play("run", true)
    anim.update(0.083)
    assert(anim.motion_offset() == Vector2.ZERO,
        "Shared run poses must not add global bob that detaches planted feet")

    # The protagonist uses four authored contact/transfer/opposite-contact/recovery frames.
    anim.play_player_clip("walk", true)
    assert(anim.frame_index() == 2, "Player walk must begin on its first authored contact pose")
    for phase in range(1, 4):
        anim.update(0.125)
        assert(anim.frame_index() == 2 + phase,
            "Player walk must advance through all four authored locomotion phases")
        assert(anim.motion_offset() == Vector2.ZERO,
            "Player walk must keep the ground pivot fixed while the torso transfers weight")
    anim.update(0.125)
    assert(anim.frame_index() == 2, "Player walk must loop cleanly after recovery")

    anim.play_player_clip("run", true)
    assert(anim.frame_index() == 6, "Player run must begin on its first authored contact pose")
    for phase in range(1, 4):
        anim.update(1.0 / 12.0)
        assert(anim.frame_index() == 6 + phase,
            "Player run must advance through all four authored locomotion phases")
        assert(anim.motion_offset() == Vector2.ZERO,
            "Player run must keep the ground pivot fixed while the torso transfers weight")
    anim.update(1.0 / 12.0)
    assert(anim.frame_index() == 6, "Player run must loop cleanly after recovery")

    var player_atlas := FileAccess.get_file_as_string("res://assets/sprites/player.svg")
    assert(not player_atlas.is_empty(), "Player locomotion atlas must be readable in regression tests")
    for direction in ["front", "back", "side"]:
        for pose in [
            ["walk", 2, [0, 1, 0, -1]],
            ["run", 6, [0, 2, 0, -1]],
        ]:
            var clip_name: String = pose[0]
            var first_frame: int = pose[1]
            var transfer: Array = pose[2]
            for phase in range(4):
                var frame_id := 'id="frame_%s_%d"' % [direction, first_frame + phase]
                var frame_start := player_atlas.find(frame_id)
                var frame_end := player_atlas.find("</g>", frame_start)
                assert(frame_start >= 0 and frame_end > frame_start,
                    "%s %s phase %d must exist in the authored atlas" % [direction, clip_name, phase])
                var frame_markup := player_atlas.substr(frame_start, frame_end - frame_start)
                var expected_upper := 'href="#%s_upper" transform="translate(' % direction
                var upper_start := frame_markup.find(expected_upper)
                assert(upper_start >= 0,
                    "%s %s phase %d must contain a separately weighted torso" % [direction, clip_name, phase])
                var expected_y := int(transfer[phase])
                var expected_transform := " %d)"/expected_y
                assert(frame_markup.find(expected_transform, upper_start) >= 0,
                    "%s %s phase %d must apply its authored vertical weight transfer" % [direction, clip_name, phase])

    anim.face(Vector2.RIGHT)
    anim.play("attack", true)
    anim.update(0.15)
    assert(anim.motion_offset() == Vector2.ZERO, "Attack must keep the sprite pivot planted; sword and upper-body frames carry the motion")

    anim.face(Vector2.LEFT)
    anim.play("attack", true)
    anim.update(0.15)
    assert(anim.motion_offset() == Vector2.ZERO, "Mirrored attack must also keep the sprite pivot planted")

    assert(SpriteAnim.PLAYER_FRAMES == 46,
        "The protagonist's authored atlas must remain independent from shared 22-frame role sheets")

    var player_attack_timings: Array[Vector2] = [
        Vector2(0.11, 0.24),
        Vector2(0.13, 0.29),
        Vector2(0.19, 0.42),
        Vector2(0.22, 0.46),
    ]
    for timing in player_attack_timings:
        anim.play_player_attack(timing.x, timing.y)
        assert(anim.frame_index() == 10, "Player attack must begin in its authored anticipation pose")
        var elapsed := 0.0
        var impact_seen := false
        for tick in range(60):
            if anim.finished:
                break
            elapsed += 1.0 / 60.0
            anim.update(1.0 / 60.0)
            if not impact_seen and elapsed + 0.0001 >= timing.x:
                assert(anim.frame_index() == 12,
                    "Player attack must show its impact pose on the existing %.2fs damage marker" % timing.x)
                impact_seen = true
        assert(impact_seen, "Every player attack profile must expose its impact marker")
        assert(anim.finished and anim.frame_index() == 15,
            "Player attack must complete its authored follow-through and recovery sequence")

    anim.play("idle", true)
    assert(anim.frame_index() == 0,
        "Switching out of a timed player attack must clear its frame timeline")

    anim.play_player_cleave(0.22, 0.46)
    assert(anim.frame_index() == 24 and anim.is_busy(),
        "Cleave must start from the dedicated heavy anticipation pose")
    var cleave_elapsed := 0.0
    var cleave_impact_seen := false
    for tick in range(60):
        if anim.finished:
            break
        cleave_elapsed += 1.0 / 60.0
        anim.update(1.0 / 60.0)
        if not cleave_impact_seen and cleave_elapsed + 0.0001 >= 0.22:
            assert(anim.frame_index() == 26,
                "Cleave must show its heavy impact pose on the existing 0.22s hit event")
            cleave_impact_seen = true
    assert(cleave_impact_seen and anim.finished and anim.frame_index() == 29,
        "Cleave must complete its dedicated follow-through and recovery sequence")

    anim.play_player_clip("dash", true)
    assert(anim.frame_index() == 30 and anim.is_busy(),
        "Dash must start on its dedicated forward-lean pose")
    anim.update(0.038)
    assert(anim.frame_index() == 31, "Dash must advance through its authored acceleration pose")
    anim.update(0.183)
    assert(anim.finished and anim.frame_index() == 35,
        "Dash must complete its six-pose cycle within the existing 0.22-second window")

    anim.play_player_clip("rally", true)
    assert(anim.frame_index() == 36 and anim.is_busy(),
        "Rally must start on its dedicated raised-arm call pose")
    anim.update(0.084)
    assert(anim.frame_index() == 37, "Rally must advance through its arm-raise sequence")
    anim.update(0.416)
    assert(anim.finished and anim.frame_index() == 41,
        "Rally must complete its six-pose call without changing the gameplay buff duration")

    anim.play_player_clip("hurt", true)
    assert(anim.frame_index() == 42 and not anim.is_busy(),
        "Hurt must begin from its first authored recoil pose without locking the action state")
    anim.update(0.051)
    assert(anim.frame_index() == 43, "Hurt must progress to its raised guard pose")
    anim.update(0.05)
    assert(anim.frame_index() == 44, "Hurt must progress through its stagger pose")
    anim.update(0.05)
    assert(anim.frame_index() == 45, "Hurt must enter its recovery pose")
    anim.update(0.049)
    assert(anim.finished and anim.frame_index() == 45,
        "Hurt must complete within the existing 0.20-second reaction window")

    anim.play_player_clip("death", true)
    assert(anim.frame_index() == 20, "Death preview must begin at the collapse pose")
    anim.update(0.126)
    assert(anim.frame_index() == 21, "Death preview must continue through the fall")
    anim.update(0.125)
    assert(anim.frame_index() == 22, "Death preview must continue through the lower fall")
    anim.update(0.125)
    assert(anim.frame_index() == 23, "Death preview must reach the prone settled pose")
    anim.update(0.124)
    assert(anim.finished and anim.frame_index() == 23,
        "Death preview must complete its authored fall sequence")

    anim.play_player_clip("work", true, 14.0)
    assert(anim.frame_index() == 16, "Player harvest must begin from its own neutral tool pose")
    var harvest_elapsed := 0.0
    for tick in 9:
        harvest_elapsed += 1.0 / 60.0
        anim.update(1.0 / 60.0)
    assert(harvest_elapsed >= 0.14 and anim.frame_index() == 18,
        "Player harvest's tool-contact pose must coincide with its existing 0.14s gameplay event")
    anim.play_player_clip("hurt", true)
    assert(anim.frame_index() == 42, "Player hurt must begin at its first frame in the 46-frame atlas")
    anim.play_player_clip("death", true)
    assert(anim.frame_index() == 20, "Player death preview must begin at its first collapse frame")

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
    player.anim.play_player_attack(0.11, 0.24)
    assert(player.anim.is_busy(), "Player attack must enter its busy animation state")
    player._hurt_t = 0.1
    player._update_anim(0.0)
    assert(player.anim.clip == "hurt" and player.anim.frame_index() == 42,
        "A damage reaction must interrupt an active player attack into the dedicated hurt pose")
    assert(not player.anim.is_busy(), "Hurt presentation must take priority over attack busy state")
    player._hurt_t = 0.0

    player.anim.play_player_clip("work", true)
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
