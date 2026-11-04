extends SceneTree
## SaveMigrationPipeline: versioned restore adapters for historical Classic/Frontier saves.

const SAVE_MIGRATION_SCRIPT := preload("res://scripts/persistence/save_migration_pipeline.gd")

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var world_config = root.get_node("WorldConfig")
    var game_clock = root.get_node("GameClock")
    var save_system = root.get_node("SaveSystem")
    world_config.apply_profile("classic")

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await _ticks(6)
    game_clock.set_process(false)

    var snapshot: Dictionary = save_system.collect(main)
    var pipeline = SAVE_MIGRATION_SCRIPT.new()

    var legacy_v4 := snapshot.duplicate(true)
    legacy_v4["version"] = 4
    legacy_v4.erase("world")
    legacy_v4.erase("campaign")
    legacy_v4.erase("frontier_campaign")
    legacy_v4.erase("supply")
    legacy_v4.erase("events")
    legacy_v4["stronghold"] = {"cx": -1, "cy": -1, "destroyed": true}
    legacy_v4["player"].erase("combat")
    legacy_v4["enemies"] = [{"id": "raider", "x": 32.0, "y": 48.0, "hp": 40}]
    for building in legacy_v4["buildings"]:
        building.erase("stockpile")
    for villager in legacy_v4["villagers"]:
        villager["job"] = "soldier"
        villager.erase("expedition")
        villager.erase("recalling")
        villager.erase("occupation")
        villager.erase("military_specialization")
        villager.erase("weapon_equipped")
        villager.erase("armor_equipped")

    var legacy_before := JSON.stringify(legacy_v4)
    var legacy_plan: Dictionary = pipeline.build_restore_plan(legacy_v4, main.world, save_system.VERSION)
    _require(int(legacy_plan["source_version"]) == 4 and int(legacy_plan["target_version"]) == 17,
        "A legacy import plan must retain its source version and declare the current restore target")
    _require(String(legacy_plan["campaign_mode"]) == "legacy",
        "Pre-v8 saves must retain the legacy stronghold restoration path")
    _require(String(legacy_plan["legacy_stronghold"].get("region", "")) == "HEARTHLAND",
        "Legacy strongholds without a usable cell must receive the historical HEARTHLAND fallback")
    _require(String(legacy_plan["legacy_stronghold"].get("faction", "")) == "legacy_raiders",
        "Legacy strongholds without faction identity must receive the historical faction fallback")
    _require(legacy_plan["player_combat_state"].is_empty(),
        "Pre-v6 saves must restore with an empty player-combat state")
    _require(not bool(legacy_plan["restore_building_stockpiles"]) and legacy_plan["building_stockpiles"].is_empty(),
        "Pre-v12 saves must not import building stockpile state")
    _require(legacy_plan["supply_state"].is_empty() and legacy_plan["frontier_campaign_state"].is_empty(),
        "Pre-v13 supply and pre-v11 Frontier campaign state must use empty defaults")
    _require(legacy_plan["events_state"].is_empty(),
        "Older saves without additive decision-event state must receive an empty event state")
    _require(not bool(legacy_plan["villagers"][0]["expedition"]) and not bool(legacy_plan["villagers"][0]["recalling"]),
        "Pre-v5 villagers must default to neither expeditioning nor recalling")
    _require(String(legacy_plan["villagers"][0]["job"]) == "soldier",
        "Pre-v9 villager roles must preserve the legacy job field")
    _require(not bool(legacy_plan["villagers"][0]["weapon_equipped"]) and not bool(legacy_plan["villagers"][0]["armor_equipped"]),
        "Pre-v17 soldiers must default to unequipped")
    _require(String(legacy_plan["enemies"][0].get("faction", "missing")) == "",
        "Pre-v10 enemies must receive the loader's legacy empty-faction default")
    _require(JSON.stringify(legacy_v4) == legacy_before,
        "Building a legacy restore plan must not mutate the caller's persisted snapshot")

    var v5 := legacy_v4.duplicate(true)
    v5["version"] = 5
    v5["villagers"][0]["expedition"] = true
    v5["villagers"][0]["recalling"] = false
    var v5_plan: Dictionary = pipeline.build_restore_plan(v5, main.world, save_system.VERSION)
    _require(bool(v5_plan["villagers"][0]["expedition"]),
        "The v5 migration boundary must preserve saved expedition state")

    var v6 := legacy_v4.duplicate(true)
    v6["version"] = 6
    v6["player"]["combat"] = {"level": 3, "xp": 17}
    var v6_plan: Dictionary = pipeline.build_restore_plan(v6, main.world, save_system.VERSION)
    _require(v6_plan["player_combat_state"] == {"level": 3, "xp": 17},
        "The v6 migration boundary must preserve player combat progression")

    var v8 := snapshot.duplicate(true)
    v8["version"] = 8
    v8.erase("frontier_campaign")
    v8.erase("supply")
    var v8_plan: Dictionary = pipeline.build_restore_plan(v8, main.world, save_system.VERSION)
    _require(String(v8_plan["campaign_mode"]) == "campaign" and v8_plan["campaign_state"] == v8["campaign"],
        "The v8 migration boundary must select the campaign snapshot path")

    var v9 := snapshot.duplicate(true)
    v9["version"] = 9
    v9["villagers"][0]["job"] = "woodcutter"
    v9["villagers"][0]["occupation"] = "builder"
    v9["villagers"][0]["military_specialization"] = ""
    var v9_plan: Dictionary = pipeline.build_restore_plan(v9, main.world, save_system.VERSION)
    _require(String(v9_plan["villagers"][0]["job"]) == "builder",
        "The v9 migration boundary must restore occupation-based villager roles")

    var v10 := snapshot.duplicate(true)
    v10["version"] = 10
    v10["enemies"] = [{"id": "raider", "faction": "wolves"}]
    var v10_plan: Dictionary = pipeline.build_restore_plan(v10, main.world, save_system.VERSION)
    _require(String(v10_plan["enemies"][0]["faction"]) == "wolves",
        "The v10 migration boundary must preserve saved enemy faction identity")

    var v11 := snapshot.duplicate(true)
    v11["version"] = 11
    v11.erase("supply")
    var v11_plan: Dictionary = pipeline.build_restore_plan(v11, main.world, save_system.VERSION)
    _require(v11_plan["frontier_campaign_state"] == v11["frontier_campaign"],
        "The v11 migration boundary must preserve Frontier objective state")

    var v12 := snapshot.duplicate(true)
    v12["version"] = 12
    v12["buildings"][0]["stockpile"] = {"wood": 4}
    var v12_plan: Dictionary = pipeline.build_restore_plan(v12, main.world, save_system.VERSION)
    _require(bool(v12_plan["restore_building_stockpiles"]) and v12_plan["building_stockpiles"][0] == {"wood": 4},
        "The v12 migration boundary must preserve saved building stockpiles")

    var v13 := snapshot.duplicate(true)
    v13["version"] = 13
    v13["supply"] = {"next_id": 3, "orders": []}
    var v13_plan: Dictionary = pipeline.build_restore_plan(v13, main.world, save_system.VERSION)
    _require(v13_plan["supply_state"] == v13["supply"],
        "The v13 migration boundary must preserve logistics state")

    var current := snapshot.duplicate(true)
    current["villagers"][0]["job"] = "soldier"
    current["villagers"][0]["occupation"] = ""
    current["villagers"][0]["military_specialization"] = "soldier"
    current["villagers"][0]["weapon_equipped"] = true
    current["villagers"][0]["armor_equipped"] = true
    current["buildings"][0]["stockpile"] = {"wood": 2}
    var current_before := JSON.stringify(current)
    var current_plan: Dictionary = pipeline.build_restore_plan(current, main.world, save_system.VERSION)
    _require(String(current_plan["villagers"][0]["job"]) == "soldier",
        "The v9+ migration must prefer a saved military specialization")
    _require(bool(current_plan["villagers"][0]["weapon_equipped"]) and bool(current_plan["villagers"][0]["armor_equipped"]),
        "The v17 migration boundary must preserve soldier equipment flags")
    _require(bool(current_plan["restore_building_stockpiles"]),
        "The current schema must enable building stockpile restoration")
    _require(current_plan["events_state"] == current.get("events", {}),
        "The current schema must retain optional decision-event state")
    _require(current_plan["campaign_state"] == current["campaign"],
        "Current campaign state must pass through without transformation")
    _require(JSON.stringify(current) == current_before,
        "Building a current restore plan must not mutate the caller's persisted snapshot")

    main.queue_free()
    await _ticks(2)
    if failures.is_empty():
        print("PASS: SaveMigrationPipeline version boundaries v4-v17, legacy defaults, restore state and source immutability")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)


func _ticks(count: int) -> void:
    for _index in count:
        await physics_frame


func _require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
