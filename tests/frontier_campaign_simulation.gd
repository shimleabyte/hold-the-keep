extends SceneTree
## Deterministic integration simulation for the actual Classic and Frontier runtime systems.

const PROFILE_SEEDS := {"classic": 41027, "frontier": 41039}
const WAVE_DAY := 2
const REPAIR_TICKS := 300
const ENEMY_MOVEMENT_TICKS := 90
const RELOAD_TICKS := 18

var failures: Array[String] = []
var _world_config
var _clock
var _inventory
var _save_system
var _tech


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    _world_config = root.get_node("WorldConfig")
    _clock = root.get_node("GameClock")
    _inventory = root.get_node("Inventory")
    _save_system = root.get_node("SaveSystem")
    _tech = root.get_node("Tech")

    var reports: Dictionary = {}
    reports["classic"] = await _simulate_profile("classic")
    reports["frontier"] = await _simulate_profile("frontier")

    if failures.is_empty():
        print("CAMPAIGN_SIMULATION_REPORT " + JSON.stringify({
            "engine_target": "Godot 4.7",
            "profiles": reports,
            "result": "passed"
        }))
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    print("CAMPAIGN_SIMULATION_REPORT " + JSON.stringify({
        "profiles": reports,
        "failures": failures,
        "result": "failed"
    }))
    quit(1)


func _simulate_profile(profile_id: String) -> Dictionary:
    _clear_save_files()
    _world_config.apply_profile(profile_id)
    var seed_value := int(PROFILE_SEEDS[profile_id])
    _world_config.world_seed = seed_value
    ProjectSettings.set_setting("world/seed", seed_value)
    seed(seed_value)
    _inventory.reset()
    _tech.reset()
    _clock.reset()

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await _ticks(12)
    _stop_autonomous_managers(main)

    _require(profile_id, is_instance_valid(main.world), "The main scene must construct a world")
    _require(profile_id, int(main.world.map_seed) == seed_value, "World generation must use the deterministic profile seed")
    _require(profile_id, int(main.world.map_size) == int(_world_config.map_size), "World dimensions must match the selected profile")

    var keep = _find_keep()
    _require(profile_id, keep != null, "A live Keep must exist before simulation begins")
    if keep == null:
        await _discard_main(main)
        return {}

    # Exercise the actual daily upkeep calculation with a non-starvation reserve.
    _inventory.items["food"] = 500
    var population_before: int = int(main.village.population())
    var upkeep_per_villager: int = int(main.village.UPKEEP)
    var food_before: int = int(_inventory.get_amount("food"))
    main.village._on_day_changed(WAVE_DAY)
    var expected_food: int = food_before - population_before * upkeep_per_villager
    _require(profile_id, int(_inventory.get_amount("food")) == expected_food,
        "Daily upkeep must debit the configured amount per living villager")

    # Exercise autonomous builder repair on the central Keep.
    _inventory.items["wood"] = 500
    var damaged_hp: int = int(keep.hp) - 12
    keep.take_damage(12)
    var builder = _assign_builder(main)
    _require(profile_id, builder != null, "A villager must claim a valid Keep builder workplace")
    if builder != null:
        _require(profile_id, builder.workplace == keep, "The Keep must be the builder's assigned workplace")
        await _ticks(REPAIR_TICKS)
        _require(profile_id, int(keep.hp) > damaged_hp,
            "A builder assigned to the Keep must autonomously complete at least one repair")

    var camp_report: Dictionary = {}
    if profile_id == "frontier":
        camp_report = await _activate_frontier_camp(main, profile_id)

    # The expanded Frontier map requires more bounded FlowField slices than Classic.
    # Do not fast-forward the night wave while its first complete path snapshot is pending.
    var flow_ready_wait_frames: int = await _wait_for_flow_current(main, profile_id)

    # Cross dusk through the production clock, spawn a real wave, and let enemy AI move.
    _clock.day = WAVE_DAY
    _clock.time_of_day = 0.59
    _clock.is_night = false
    var enemies_before: int = _count_enemies()
    _clock._process(2.0)
    var expected_wave: int = int(main.spawner.wave_size(WAVE_DAY))
    _require(profile_id, bool(_clock.is_night), "Crossing NIGHT_START must enter the night phase")
    _require(profile_id, int(main.spawner._to_spawn) == expected_wave,
        "Night transition must schedule the profile's configured wave budget")

    var interval: float = float(main.spawner._interval)
    for _index in range(expected_wave * 4):
        if int(main.spawner._to_spawn) <= 0:
            break
        main.spawner._process(interval + 0.02)

    var wave_spawned: int = _count_enemies() - enemies_before
    _require(profile_id, wave_spawned > 0, "The night spawner must place at least one reachable enemy")

    var moving_enemy = _find_new_enemy(main)
    var movement_pixels := 0.0
    if moving_enemy != null:
        var spawn_position: Vector2 = moving_enemy.global_position
        var spawn_cell: Vector2i = main.nav.cell_of(spawn_position)
        _require(profile_id, bool(main.flow.is_reachable(spawn_cell)),
            "A spawned wave enemy must be connected to the Keep's flow field")
        await _ticks(ENEMY_MOVEMENT_TICKS)
        if is_instance_valid(moving_enemy):
            movement_pixels = spawn_position.distance_to(moving_enemy.global_position)
        _require(profile_id, movement_pixels > 0.1,
            "A reachable wave enemy must advance through its autonomous movement controller")
    else:
        _require(profile_id, false, "A newly spawned wave enemy must be available for movement validation")

    # Force the production clock across dawn and then the next day boundary.
    _clock.time_of_day = 0.899
    _clock.is_night = true
    _clock._process(0.6)
    _require(profile_id, not bool(_clock.is_night), "Crossing NIGHT_END must end the wave")
    _require(profile_id, int(main.spawner._to_spawn) == 0, "Dawn must cancel all unspawned wave units")

    var day_before_rollover: int = int(_clock.day)
    _clock.time_of_day = 0.999
    _clock.is_night = false
    _clock._process(0.5)
    _require(profile_id, int(_clock.day) == day_before_rollover + 1,
        "Crossing the day boundary must increment the campaign day exactly once")

    var snapshot: Dictionary = _save_system.collect(main)
    _require(profile_id, bool(_save_system._valid_save(snapshot)),
        "The complete simulation checkpoint must satisfy save validation")
    var saved_population: int = int(main.village.population())
    var saved_food: int = int(_inventory.get_amount("food"))
    var saved_keep_hp: int = int(keep.hp)
    var saved_enemy_count: int = _count_enemies()
    var saved_day: int = int(_clock.day)
    _require(profile_id, bool(_save_system.save_current(true)),
        "A completed simulation checkpoint must be writable")

    _save_system.request_load()
    await _ticks(RELOAD_TICKS)
    var restored_main = current_scene
    _require(profile_id, restored_main != null and is_instance_valid(restored_main),
        "Loading the checkpoint must restore the main scene")
    if restored_main == null or not is_instance_valid(restored_main):
        _clear_save_files()
        return {}

    _stop_autonomous_managers(restored_main)
    var restored_keep = _find_keep()
    _require(profile_id, int(_clock.day) == saved_day,
        "The campaign day must survive a complete scene reload")
    _require(profile_id, int(restored_main.village.population()) == saved_population,
        "The living population must survive a complete scene reload")
    _require(profile_id, int(_inventory.get_amount("food")) == saved_food,
        "Resource balances must survive a complete scene reload")
    _require(profile_id, restored_keep != null and int(restored_keep.hp) == saved_keep_hp,
        "Repaired Keep health must survive a complete scene reload")
    _require(profile_id, _count_enemies() == saved_enemy_count,
        "Active and retreating enemy actors must survive the checkpoint")

    if profile_id == "frontier":
        var restored_camps = restored_main.frontier_campaign.faction_camps
        var camp_id := String(camp_report.get("camp_id", ""))
        _require(profile_id, restored_camps.camps.has(camp_id),
            "The activated faction camp must remain registered after reload")
        if restored_camps.camps.has(camp_id):
            _require(profile_id, bool(restored_camps.camps[camp_id].get("activated", false)),
                "Faction camp activation must persist across a reload")

    var report := {
        "profile": profile_id,
        "seed": seed_value,
        "map_size": int(_world_config.map_size),
        "day_after_simulation": saved_day,
        "population": saved_population,
        "food_after_upkeep": saved_food,
        "keep_hp_after_repair": saved_keep_hp,
        "wave_budget": expected_wave,
        "flow_ready_wait_frames": flow_ready_wait_frames,
        "wave_enemies_spawned": wave_spawned,
        "sample_enemy_moved_pixels": snappedf(movement_pixels, 0.1),
        "restored_enemy_count": _count_enemies(),
        "restored_day": int(_clock.day)
    }
    if not camp_report.is_empty():
        report["faction_camp"] = camp_report

    await _discard_main(restored_main)
    _clear_save_files()
    return report


func _activate_frontier_camp(main, profile_id: String) -> Dictionary:
    var camp_manager = main.frontier_campaign.faction_camps
    _require(profile_id, camp_manager != null and camp_manager.camps.size() == 4,
        "Frontier must initialize one deterministic faction camp per faction")
    if camp_manager == null or camp_manager.camps.is_empty():
        return {}

    var camp_ids: Array = camp_manager.camps.keys()
    camp_ids.sort()
    var camp_id := String(camp_ids[0])
    var camp: Dictionary = camp_manager.camps[camp_id]
    var camp_cell: Vector2i = camp["cell"]
    main.fog.reveal_position(main.nav.center_of(camp_cell), 1.0)
    _require(profile_id, bool(main.fog.is_revealed_cell(camp_cell)),
        "The camp's exact cell must be revealed before its activation scan")
    camp_manager._process(0.5)

    var activated: Dictionary = camp_manager.camps[camp_id]
    _require(profile_id, bool(activated.get("activated", false)),
        "Revealing an enemy-controlled camp must activate its patrol system")

    var patrol_count := 0
    for patrol in get_nodes_in_group("enemy_patrols"):
        if is_instance_valid(patrol) and String(patrol.patrol_camp_id) == camp_id:
            patrol_count += 1
    _require(profile_id, patrol_count > 0,
        "Activating a faction camp must spawn its initial patrol force")
    _require(profile_id, patrol_count <= int(activated.get("patrol_cap", 0)),
        "Initial patrol spawning must respect the camp's active patrol cap")
    return {"camp_id": camp_id, "activated": bool(activated.get("activated", false)), "patrols": patrol_count}


func _assign_builder(main):
    var villagers: Array = main.village.villagers()
    for villager in villagers:
        if not is_instance_valid(villager):
            continue
        if villager.set_job("builder") and villager.has_valid_workplace():
            return villager
    return null


func _find_new_enemy(main):
    for enemy in get_nodes_in_group("enemies"):
        if not is_instance_valid(enemy) or enemy.is_garrison or enemy.is_patrol:
            continue
        if enemy.faction_raid_target_kind != "" or enemy.is_supply_raider or enemy.is_faction_raider:
            continue
        var cell: Vector2i = main.nav.cell_of(enemy.global_position)
        if main.flow.is_reachable(cell):
            return enemy
    return null


func _find_keep():
    for building in get_nodes_in_group("buildings"):
        if is_instance_valid(building) and String(building.id) == "keep":
            return building
    return null


func _count_enemies() -> int:
    var count := 0
    for enemy in get_nodes_in_group("enemies"):
        if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
            count += 1
    return count


func _stop_autonomous_managers(main) -> void:
    _clock.set_process(false)
    _clock.set_physics_process(false)
    for node in [
        main.spawner, main.village, main.supply, main.fog, main.territory,
        main.frontier_campaign
    ]:
        if node != null and is_instance_valid(node):
            node.set_process(false)
            node.set_physics_process(false)
    if main.frontier_campaign != null and main.frontier_campaign.faction_camps != null:
        main.frontier_campaign.faction_camps.set_process(false)
        main.frontier_campaign.faction_camps.set_physics_process(false)


func _discard_main(main) -> void:
    if main != null and is_instance_valid(main):
        main.queue_free()
    current_scene = null
    await _ticks(3)


func _clear_save_files() -> void:
    for path in [_save_system.PATH, _save_system.TMP, _save_system.BACKUP]:
        DirAccess.remove_absolute(path)


func _ticks(count: int) -> void:
    for _index in range(count):
        await physics_frame


func _wait_for_flow_current(main: Node, profile_id: String, maximum_frames: int = 600) -> int:
    var waited := 0
    while not main.flow.is_current() and waited < maximum_frames:
        await physics_frame
        waited += 1
    _require(profile_id, main.flow.is_current(),
        "FlowField must publish a complete reachable snapshot within %d frames (waited %d)" % [maximum_frames, waited])
    return waited


func _require(profile_id: String, condition: bool, message: String) -> void:
    if not condition:
        failures.append("%s: %s" % [profile_id, message])
