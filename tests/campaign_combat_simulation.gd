extends SceneTree
## Phase 09.2: deterministic scripted combat-budget probes for Frontier act boundaries.
##
## This is deliberately not a full AI/pathfinding or full-wave simulation. It uses a
## small curated roster from each act, real player/enemy damage transactions, actual
## armor and structure multipliers, a fixed time step, and a scripted target schedule.
## The JSON report is diagnostic evidence; human playtesting remains mandatory.

const STEP_SECONDS := 0.1
const MAX_SIM_SECONDS := 120.0
const PLAYER_ATTACK_INTERVAL := 0.45
const PLAYER_CLEAVE_INTERVAL := 8.0
const ENEMY_SCRIPT := preload("res://scripts/entities/enemy.gd")

const CASES: Array[Dictionary] = [
    {
        "label": "Act I — Greenwood",
        "day": 5,
        "level": 1,
        "faction": "greenwood_raiders",
        "roster": ["bandit", "wolf", "soldier"]
    },
    {
        "label": "Act II — Iron Legion",
        "day": 10,
        "level": 2,
        "faction": "iron_legion",
        "roster": ["enemy_scout", "enemy_shieldbearer", "soldier"]
    },
    {
        "label": "Act III — Fen Cult",
        "day": 15,
        "level": 3,
        "faction": "fen_cult",
        "roster": ["enemy_saboteur", "brute", "soldier"]
    },
    {
        "label": "Act IV — Ashen Host",
        "day": 20,
        "level": 4,
        "faction": "ashen_host",
        "roster": ["enemy_siege_engine", "enemy_beast_rider", "brute", "enemy_scout"]
    },
    {
        "label": "Day 20 — King assault",
        "day": 20,
        "level": 5,
        "faction": "ashen_host",
        "roster": ["king", "enemy_siege_engine", "enemy_beast_rider"]
    }
]

var _player_downs := 0
var _villager_deaths := 0


func ticks(count: int) -> void:
    for _index in range(count):
        await physics_frame


func _on_build_feedback(message: String) -> void:
    if message.begins_with("Kamu tumbang!"):
        _player_downs += 1


func _on_villager_died() -> void:
    _villager_deaths += 1


func _find_keep():
    for building in get_nodes_in_group("buildings"):
        if String(building.id) == "keep":
            return building
    return null


func _run_case(case_data: Dictionary) -> Dictionary:
    WorldConfig.apply_profile("frontier")
    GameClock.day = int(case_data["day"])
    Tech.reset()
    seed(int(case_data["day"]) * 7919 + int(case_data["level"]) * 104729)

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(10)

    GameClock.set_process(false)
    GameClock.set_physics_process(false)
    Tech.set_process(false)
    main.spawner.set_process(false)
    main.spawner.set_physics_process(false)
    main.village.set_process(false)
    main.village.set_physics_process(false)
    main.supply.set_process(false)
    main.supply.set_physics_process(false)
    main.fog.set_process(false)
    main.fog.set_physics_process(false)
    main.territory.set_physics_process(false)
    main.nav.set_physics_process(false)
    main.player.set_process(false)
    main.player.set_physics_process(false)

    # Remove campaign garrisons so only the curated encounter roster contributes.
    for existing_enemy in get_nodes_in_group("enemies"):
        existing_enemy.remove_from_group("enemies")
        existing_enemy.remove_from_group("enemy_garrison")
        existing_enemy.remove_from_group("enemy_patrols")
        existing_enemy.remove_from_group("ranged_enemies")
        existing_enemy.remove_from_group("supply_raiders")
        existing_enemy.remove_from_group("faction_raiders")
        existing_enemy.queue_free()
    await ticks(1)

    var keep = _find_keep()
    assert(keep != null and is_instance_valid(keep), "Every combat case requires a live Keep")
    var player = main.player
    player.global_position = keep.global_position + Vector2(0.0, 16.0)
    player.spawn_pos = player.global_position
    player.hp = player.MAX_HP
    player.level = int(case_data["level"])
    player.experience = 0
    player._invuln = 0.0
    player._atk_cd = 0.0
    player._cleave_cd = 0.0
    player._rally_cd = 0.0
    player._rally_t = 0.0

    var villagers := get_nodes_in_group("villagers")
    var population_start := villagers.size()
    var soldier = null
    for villager in villagers:
        villager.set_process(false)
        villager.set_physics_process(false)
        if soldier == null:
            soldier = villager
            assert(soldier.set_job("soldier"), "The sample defender must accept the Soldier role")
    assert(soldier != null, "The sample encounter requires one starting villager")
    soldier.global_position = player.global_position + Vector2(0.0, 8.0)

    if player.level >= 3:
        assert(player._use_rally(), "Rally must be available at level 3 and above")

    var roster: Array = case_data["roster"]
    var enemies: Array = []
    var offsets: Array[Vector2] = [
        Vector2(-8.0, -8.0),
        Vector2(0.0, -8.0),
        Vector2(8.0, -8.0),
        Vector2(-8.0, 0.0),
        Vector2(0.0, 0.0),
        Vector2(8.0, 0.0)
    ]
    for index in range(roster.size()):
        var enemy_id := String(roster[index])
        assert(DataDB.enemies.has(enemy_id), "Missing combat simulation enemy data: " + enemy_id)
        var enemy = ENEMY_SCRIPT.new()
        enemy.setup(DataDB.enemies[enemy_id], main.world, main.flow, player, String(case_data["faction"]))
        enemy.position = player.global_position + offsets[index % offsets.size()]
        main.world.entities.add_child(enemy)
        enemy.set_process(false)
        enemy.set_physics_process(false)
        enemies.append(enemy)

    var wave_budget := main.spawner.wave_size(int(case_data["day"]))
    var keep_start := int(keep.hp)
    var elapsed := 0.0
    var player_attack_timer := 0.0
    var cleave_timer := PLAYER_CLEAVE_INTERVAL

    while elapsed < MAX_SIM_SECONDS and keep.hp > 0 and not get_nodes_in_group("enemies").is_empty():
        if player_attack_timer <= 0.0:
            player._apply_attack()
            player_attack_timer = PLAYER_ATTACK_INTERVAL
        else:
            player_attack_timer = maxf(0.0, player_attack_timer - STEP_SECONDS)

        if player.level >= 2:
            cleave_timer -= STEP_SECONDS
            if cleave_timer <= 0.0:
                player._apply_cleave()
                cleave_timer = PLAYER_CLEAVE_INTERVAL

        for index in range(enemies.size()):
            var enemy = enemies[index]
            if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or int(enemy.hp) <= 0:
                continue

            enemy._atk_cd = maxf(0.0, float(enemy._atk_cd) - STEP_SECONDS)
            if enemy._pending == null and enemy._atk_cd <= 0.0:
                var target = keep
                match index % 3:
                    0:
                        target = player
                    1:
                        if is_instance_valid(soldier) and int(soldier.hp) > 0:
                            target = soldier
                    _:
                        target = keep
                enemy._begin_attack(target, target.global_position - enemy.global_position)
            enemy._resolve_pending(STEP_SECONDS)

        player._invuln = maxf(0.0, float(player._invuln) - STEP_SECONDS)
        player._rally_t = maxf(0.0, float(player._rally_t) - STEP_SECONDS)
        elapsed += STEP_SECONDS

    await ticks(2)

    var enemies_remaining := get_nodes_in_group("enemies").size()
    var keep_hp := maxi(0, int(keep.hp)) if is_instance_valid(keep) else 0
    var population_lost := mini(population_start, _villager_deaths)
    var population_remaining := maxi(0, population_start - population_lost)
    var failure_modes: Array[String] = []
    if keep_hp <= 0:
        failure_modes.append("keep_breached")
    if population_lost > 0:
        failure_modes.append("population_loss")
    if _player_downs > 0:
        failure_modes.append("player_down")
    if enemies_remaining > 0 and keep_hp > 0:
        failure_modes.append("enemies_remaining_at_time_limit")

    var outcome := "keep_breached" if keep_hp <= 0 else (
        "cleared" if enemies_remaining == 0 else "time_limit"
    )
    var report := {
        "case": String(case_data["label"]),
        "day": int(case_data["day"]),
        "faction": String(case_data["faction"]),
        "player_level": player.level,
        "wave_budget": wave_budget,
        "sample_roster": roster.duplicate(),
        "sample_count": roster.size(),
        "simulated_seconds": snappedf(elapsed, 0.1),
        "keep_hp_start": keep_start,
        "keep_hp_end": keep_hp,
        "keep_damage": keep_start - keep_hp,
        "population_start": population_start,
        "population_remaining": population_remaining,
        "population_lost": population_lost,
        "player_downs": _player_downs,
        "enemies_defeated": roster.size() - enemies_remaining,
        "enemies_remaining": enemies_remaining,
        "outcome": outcome,
        "failure_modes": failure_modes
    }

    assert(report["wave_budget"] >= report["sample_count"],
        "The curated roster must not exceed the campaign's configured wave budget")
    assert(report["keep_damage"] >= 0 and report["enemies_remaining"] >= 0,
        "Combat metrics must remain non-negative")
    assert(report["population_remaining"] <= report["population_start"],
        "Population reporting must not invent surviving villagers")

    main.queue_free()
    await ticks(3)
    return report


func _run() -> void:
    Events.build_feedback.connect(_on_build_feedback)
    Events.villager_died.connect(_on_villager_died)

    var reports: Array[Dictionary] = []
    for case_data in CASES:
        _player_downs = 0
        _villager_deaths = 0
        var report := await _run_case(case_data)
        reports.append(report)
        print("COMBAT_CASE " + JSON.stringify(report))

    Events.build_feedback.disconnect(_on_build_feedback)
    Events.villager_died.disconnect(_on_villager_died)
    print("COMBAT_SIMULATION_REPORT " + JSON.stringify({
        "profile": "frontier",
        "step_seconds": STEP_SECONDS,
        "max_case_seconds": MAX_SIM_SECONDS,
        "simulation_scope": "curated roster; real damage transactions and cooldowns; scripted target schedule; no pathfinding, autonomous AI, economy or full-wave execution",
        "cases": reports
    }))
    print("PASS: deterministic scripted combat-budget probes for Frontier Acts I–IV and the day-20 King assault")
    quit(0)


func _initialize() -> void:
    call_deferred("_run")
