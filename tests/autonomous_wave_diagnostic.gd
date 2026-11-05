extends SceneTree
## Runs one complete real-time night wave in Classic and Frontier.
## Unlike campaign_combat_simulation.gd, this keeps the game clock, spawner,
## navigation, enemy AI, villager lifecycle and player combat loop active.
## A small deterministic player bot holds attack and moves toward the nearest
## non-garrison enemy. Outcomes are reported, not balanced by hard-coded wins.

const CASES: Array[Dictionary] = [
    {"profile": "classic", "day": 6, "seed": 70113},
    {"profile": "frontier", "day": 6, "seed": 70127}
]
const SIMULATION_TIME_SCALE := 6.0
const MAX_NIGHT_PHYSICS_TICKS := 900
const INPUT_ACTIONS := ["move_left", "move_right", "move_up", "move_down", "sprint", "attack"]

var _active_case: Dictionary = {}
var _baseline_enemy_ids: Dictionary = {}
var _wave_enemy_ids: Dictionary = {}
var _player_downs := 0
var _villager_deaths := 0
var _enemy_kills := 0
var _game_over := false
var _failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var events = root.get_node("Events")
    events.wave_started.connect(_on_wave_started)
    events.build_feedback.connect(_on_build_feedback)
    events.villager_died.connect(_on_villager_died)
    events.enemy_killed.connect(_on_enemy_killed)
    events.game_over.connect(_on_game_over)

    var reports: Array[Dictionary] = []
    for case_data in CASES:
        var report := await _run_case(case_data)
        reports.append(report)
        print("AUTONOMOUS_WAVE_CASE " + JSON.stringify(report))

    events.wave_started.disconnect(_on_wave_started)
    events.build_feedback.disconnect(_on_build_feedback)
    events.villager_died.disconnect(_on_villager_died)
    events.enemy_killed.disconnect(_on_enemy_killed)
    events.game_over.disconnect(_on_game_over)
    _release_bot_input()
    Engine.time_scale = 1.0
    get_tree().paused = false

    if not _failures.is_empty():
        for failure in _failures:
            push_error(failure)

    var report := {
        "engine_target": "Godot 4.7",
        "simulation": "full night wave; runtime spawner, pathfinding, AI and player attack loop enabled",
        "time_scale": SIMULATION_TIME_SCALE,
        "max_physics_ticks_per_case": MAX_NIGHT_PHYSICS_TICKS,
        "cases": reports,
        "failures": _failures,
        "result": "passed" if _failures.is_empty() else "failed"
    }
    print("AUTONOMOUS_WAVE_REPORT " + JSON.stringify(report))
    quit(0 if _failures.is_empty() else 1)


func _run_case(case_data: Dictionary) -> Dictionary:
    _release_bot_input()
    Engine.time_scale = 1.0
    get_tree().paused = false
    _clear_save_files()

    var profile := String(case_data["profile"])
    var day := int(case_data["day"])
    var seed_value := int(case_data["seed"])
    var world_config = root.get_node("WorldConfig")
    var clock = root.get_node("GameClock")
    var inventory = root.get_node("Inventory")
    var tech = root.get_node("Tech")
    var save_system = root.get_node("SaveSystem")

    world_config.apply_profile(profile)
    world_config.world_seed = seed_value
    ProjectSettings.set_setting("world/seed", seed_value)
    seed(seed_value)
    inventory.reset()
    tech.reset()
    clock.reset()
    clock.set_process(false)
    clock.set_physics_process(false)

    var main_scene := load("res://scenes/main.tscn") as PackedScene
    if main_scene == null:
        _require(false, "%s: could not load main gameplay scene" % profile)
        return {}
    var main := main_scene.instantiate()
    root.add_child(main)
    current_scene = main
    await _ticks(12)
    root.warp_mouse(Vector2(320, 180))

    if main.player == null or main.spawner == null or main.world == null:
        _require(false, "%s: HTK_AUTO_START_GAME=1 must initialize the gameplay scene" % profile)
        await _discard_main(main)
        return {}

    var keep = _find_keep()
    if keep == null:
        _require(false, "%s: the campaign must start with a live Keep" % profile)
        await _discard_main(main)
        return {}

    clock.day = day
    clock.time_of_day = GameClock.NIGHT_START - 0.0005
    clock.is_night = false
    clock._night_warning_sent = true

    _baseline_enemy_ids.clear()
    _wave_enemy_ids.clear()
    for enemy in get_nodes_in_group("enemies"):
        if is_instance_valid(enemy):
            _baseline_enemy_ids[enemy.get_instance_id()] = true

    _player_downs = 0
    _villager_deaths = 0
    _enemy_kills = 0
    _game_over = false
    _active_case = {
        "profile": profile,
        "day": day,
        "wave_budget": int(main.spawner.wave_size(day)),
        "wave_started": false
    }

    var keep_hp_start := int(keep.hp)
    var player_hp_start := int(main.player.hp)
    var population_start := int(main.village.population())
    var minimum_keep_hp := keep_hp_start
    var peak_total_enemies := 0
    var peak_wave_enemies := 0
    var dawn_reached := false
    var ticks_run := 0
    var night_start := clock.time_of_day

    Engine.time_scale = SIMULATION_TIME_SCALE
    clock.set_process(true)
    for tick in MAX_NIGHT_PHYSICS_TICKS:
        await physics_frame
        ticks_run = tick + 1

        _record_wave_spawns()
        var total_enemies := get_nodes_in_group("enemies").size()
        var wave_alive := _count_wave_enemies()
        peak_total_enemies = maxi(peak_total_enemies, total_enemies)
        peak_wave_enemies = maxi(peak_wave_enemies, wave_alive)

        if is_instance_valid(keep):
            minimum_keep_hp = mini(minimum_keep_hp, int(keep.hp))

        _drive_player(main.player)
        if _game_over or get_tree().paused:
            break
        if bool(_active_case.get("wave_started", false)) \
                and not bool(clock.is_night) and clock.time_of_day >= GameClock.NIGHT_END:
            dawn_reached = true
            break

    _record_wave_spawns()
    var keep_hp_end := int(keep.hp) if is_instance_valid(keep) else 0
    var player_hp_end := int(main.player.hp) if is_instance_valid(main.player) else 0
    var population_end := int(main.village.population()) if is_instance_valid(main.village) else 0
    var spawned := _wave_enemy_ids.size()
    var wave_budget := int(_active_case.get("wave_budget", 0))
    var remaining := _count_wave_enemies()
    var elapsed_game_seconds := maxf(0.0, (clock.time_of_day - night_start) * GameClock.DAY_LENGTH)
    var outcome := "game_over" if _game_over else ("dawn" if dawn_reached else "time_limit")

    var report := {
        "profile": profile,
        "seed": seed_value,
        "day": day,
        "wave_budget": wave_budget,
        "wave_started": bool(_active_case.get("wave_started", false)),
        "wave_enemies_observed": spawned,
        "wave_spawn_complete": spawned >= wave_budget,
        "peak_wave_enemies_alive": peak_wave_enemies,
        "peak_total_enemies_alive": peak_total_enemies,
        "enemies_killed_event_count": _enemy_kills,
        "wave_enemies_alive_at_end": remaining,
        "keep_hp_start": keep_hp_start,
        "keep_hp_min": minimum_keep_hp,
        "keep_hp_end": keep_hp_end,
        "keep_damage": keep_hp_start - keep_hp_end,
        "player_hp_start": player_hp_start,
        "player_hp_end": player_hp_end,
        "player_downs": _player_downs,
        "population_start": population_start,
        "population_end": population_end,
        "villager_deaths": _villager_deaths,
        "night_simulated_seconds": snappedf(elapsed_game_seconds, 0.1),
        "physics_ticks": ticks_run,
        "dawn_reached": dawn_reached,
        "game_over": _game_over,
        "outcome": outcome
    }

    _require(bool(report["wave_started"]),
        "%s day %d: GameClock did not start the night wave" % [profile, day])
    _require(wave_budget > 0 and spawned > 0,
        "%s day %d: the runtime spawner did not produce wave enemies" % [profile, day])
    _require(spawned <= wave_budget,
        "%s day %d: observed wave spawns exceed the configured budget" % [profile, day])
    _require(dawn_reached or _game_over,
        "%s day %d: simulation reached its time limit without dawn or game over" % [profile, day])
    _require(keep_hp_end >= 0 and player_hp_end >= 0 and population_end >= 0,
        "%s day %d: runtime reported a negative survival metric" % [profile, day])
    _require(wave_budget == int(main.spawner.wave_size(day)),
        "%s day %d: report budget differs from WaveSpawner configuration" % [profile, day])

    _active_case.clear()
    clock.set_process(false)
    Engine.time_scale = 1.0
    await _discard_main(main)
    _clear_save_files()
    return report


func _drive_player(player: Node) -> void:
    if not is_instance_valid(player) or int(player.hp) <= 0:
        _release_movement_input()
        return
    var nearest: Node2D = null
    var nearest_distance := INF
    for enemy in get_nodes_in_group("enemies"):
        if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or int(enemy.hp) <= 0:
            continue
        if bool(enemy.is_garrison) or bool(enemy.is_patrol):
            continue
        var distance := player.global_position.distance_to(enemy.global_position)
        if distance < nearest_distance:
            nearest = enemy
            nearest_distance = distance

    Input.action_press("attack")
    if nearest == null:
        _release_movement_input()
        return

    if nearest_distance <= 18.0:
        _release_movement_input()
        return

    var direction: Vector2 = (nearest.global_position - player.global_position).normalized()
    _set_action("move_left", direction.x < -0.25)
    _set_action("move_right", direction.x > 0.25)
    _set_action("move_up", direction.y < -0.25)
    _set_action("move_down", direction.y > 0.25)
    _set_action("sprint", nearest_distance > 64.0)


func _set_action(action: String, pressed: bool) -> void:
    if pressed:
        Input.action_press(action)
    else:
        Input.action_release(action)


func _release_movement_input() -> void:
    for action in ["move_left", "move_right", "move_up", "move_down", "sprint"]:
        Input.action_release(action)


func _release_bot_input() -> void:
    for action in INPUT_ACTIONS:
        Input.action_release(action)


func _record_wave_spawns() -> void:
    for enemy in get_nodes_in_group("enemies"):
        if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
            continue
        var instance_id := enemy.get_instance_id()
        if not _baseline_enemy_ids.has(instance_id):
            _wave_enemy_ids[instance_id] = true


func _count_wave_enemies() -> int:
    var count := 0
    for enemy in get_nodes_in_group("enemies"):
        if is_instance_valid(enemy) and _wave_enemy_ids.has(enemy.get_instance_id()):
            count += 1
    return count


func _find_keep():
    for building in get_nodes_in_group("buildings"):
        if is_instance_valid(building) and String(building.id) == "keep":
            return building
    return null


func _on_wave_started(day: int, count: int) -> void:
    if not _active_case.is_empty() and day == int(_active_case.get("day", -1)):
        _active_case["wave_started"] = true
        _active_case["wave_budget"] = count


func _on_build_feedback(message: String) -> void:
    if message.begins_with("Kamu tumbang!"):
        _player_downs += 1


func _on_villager_died() -> void:
    _villager_deaths += 1


func _on_enemy_killed(_enemy_id: String) -> void:
    _enemy_kills += 1


func _on_game_over(_day: int) -> void:
    _game_over = true


func _ticks(count: int) -> void:
    for _index in count:
        await physics_frame


func _discard_main(main: Node) -> void:
    _release_bot_input()
    Engine.time_scale = 1.0
    get_tree().paused = false
    if main != null and is_instance_valid(main):
        main.queue_free()
    current_scene = null
    await process_frame


func _clear_save_files() -> void:
    var save_system = root.get_node_or_null("SaveSystem")
    if save_system == null:
        return
    for path in [save_system.PATH, save_system.TMP, save_system.BACKUP]:
        DirAccess.remove_absolute(path)


func _require(condition: bool, message: String) -> void:
    if not condition:
        _failures.append(message)
        push_error("AUTONOMOUS_WAVE_FAIL: " + message)
