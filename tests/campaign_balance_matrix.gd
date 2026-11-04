extends SceneTree

var world_config
var game_clock
var data_db
var _night_warning_count := 0

## Deterministic campaign difficulty matrix: schedule, wave growth and act rosters.


func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func _on_build_feedback(message: String) -> void:
    if message.begins_with("Senja mendekat."):
        _night_warning_count += 1


func verify_night_warning() -> void:
    game_clock.set_process(false)
    game_clock.reset()
    game_clock.time_of_day = GameClock.NIGHT_START - GameClock.NIGHT_WARNING_LEAD - 0.001
    game_clock._process(0.5)
    assert(_night_warning_count == 1,
        "The player must receive a preparation warning before the night phase")
    game_clock._process(0.5)
    assert(_night_warning_count == 1,
        "The same night warning must not repeat every frame")

    game_clock.time_of_day = 0.999
    game_clock._process(0.5)
    game_clock.time_of_day = GameClock.NIGHT_START - GameClock.NIGHT_WARNING_LEAD - 0.001
    game_clock._process(0.5)
    assert(_night_warning_count == 2,
        "The warning must become available again on the next day")


func pool_has(pool: Array, enemy_id: String) -> bool:
    for value in pool:
        if String(value.get("id", "")) == enemy_id:
            return true
    return false


func pool_weight(pool: Array, enemy_id: String) -> int:
    for value in pool:
        if String(value.get("id", "")) == enemy_id:
            return int(value.get("weight", 0))
    return -1


func run_profile(profile: String, expected: Dictionary) -> void:
    world_config.apply_profile(profile)
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(8)
    game_clock.set_process(false)

    var rules: Dictionary = data_db.campaign_modes[profile]
    assert(int(rules["final_day"]) == int(expected["final_day"]),
        profile + " final day must remain stable")

    var expected_days: Dictionary = expected["days"]
    for day_value in expected_days:
        var day := int(day_value)
        var expected_entry: Dictionary = expected_days[day_value]
        var stage: Dictionary = main.spawner.stage_info(day)
        assert(String(stage.get("id", "")) == String(expected_entry["stage"]),
            "%s day %d must map to the expected campaign stage" % [profile, day])
        assert(main.spawner.wave_size(day) == int(expected_entry["wave"]),
            "%s day %d wave size changed unexpectedly" % [profile, day])

    if profile == "classic":
        var black_march: Array = main.spawner._pool_for(6)
        var final_siege: Array = main.spawner._pool_for(11)
        assert(pool_weight(black_march, "archer") == 3,
            "Classic Black March must preserve the archer pressure increase")
        assert(pool_weight(final_siege, "archer") == 3,
            "Classic Final Siege must preserve the archer pressure increase")
        assert(pool_weight(final_siege, "brute") == 3,
            "Classic Final Siege must preserve the brute pressure increase")
        assert(not pool_has(black_march, "enemy_scout"),
            "Classic mode must not inherit Frontier faction wave archetypes")
    else:
        var act_2: Array = main.spawner._pool_for(6)
        var act_3: Array = main.spawner._pool_for(11)
        var act_4: Array = main.spawner._pool_for(16)
        assert(pool_has(act_2, "enemy_scout") and pool_has(act_2, "enemy_shieldbearer"),
            "Frontier Act II must add Scout and Shieldbearer to its wave pool")
        assert(pool_has(act_3, "enemy_saboteur") and pool_has(act_3, "enemy_war_shaman"),
            "Frontier Act III must add Saboteur and War Shaman to its wave pool")
        assert(pool_has(act_4, "enemy_siege_engine") and pool_has(act_4, "enemy_beast_rider"),
            "Frontier Act IV must add Siege Engine and Beast Rider to its wave pool")
        assert(main.spawner.wave_size(20) == 65,
            "The final Frontier night must retain the day-20 wave budget")

    var final_day := int(rules["final_day"])
    main.spawner.start_wave(final_day - 1)
    assert(not main.spawner._boss_pending,
        "%s must not queue its final boss one day early" % profile)
    main.spawner.end_wave()
    main.spawner.start_wave(final_day)
    assert(main.spawner._boss_pending,
        "%s must queue the final boss on its configured final day" % profile)
    assert(main.spawner._boss_t < 0.0,
        "%s final boss must wait behind the regular wave instead of appearing immediately" % profile)
    var final_wave_count: int = main.spawner.wave_size(final_day)
    var reveal_remaining := floori(float(final_wave_count) * 0.25)
    main.spawner._to_spawn = reveal_remaining + 1
    main.spawner._process(0.1)
    assert(main.spawner._boss_t < 0.0,
        "%s boss warning must not start before at least 75%% of regular enemies are deployed" % profile)
    main.spawner._to_spawn = reveal_remaining
    main.spawner._process(0.1)
    assert(is_equal_approx(main.spawner._boss_t, 4.0),
        "%s boss must announce itself with a four-second warning after the wave reaches its reveal threshold" % profile)

    print("PASS: %s schedule, wave and final-boss pacing matrix (final day %d)" % [profile, final_day])
    main.queue_free()
    await ticks(3)


func _run() -> void:
    var events = root.get_node("Events")
    events.build_feedback.connect(_on_build_feedback)
    await run_profile("classic", {
        "final_day": 15,
        "days": {
            1: {"stage":"frontier", "wave":6},
            6: {"stage":"black_march", "wave":21},
            11: {"stage":"last_siege", "wave":36},
            15: {"stage":"last_siege", "wave":48}
        }
    })
    await run_profile("frontier", {
        "final_day": 20,
        "days": {
            1: {"stage":"act_1", "wave":8},
            6: {"stage":"act_2", "wave":23},
            11: {"stage":"act_3", "wave":38},
            16: {"stage":"act_4", "wave":53},
            20: {"stage":"act_4", "wave":65}
        }
    })
    verify_night_warning()
    events.build_feedback.disconnect(_on_build_feedback)
    print("PASS: once-per-night preparation warning and next-day reset")
    quit(0)


func _initialize() -> void:
    world_config = root.get_node("WorldConfig")
    game_clock = root.get_node("GameClock")
    data_db = root.get_node("DataDB")
    call_deferred("_run")
