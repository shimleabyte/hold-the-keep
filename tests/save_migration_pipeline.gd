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
    _require(world_config.apply_saved_profile("classic", 64),
        "Historical Classic migration fixtures must be generated on the original 64x64 world")
    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await _ticks(6)
    game_clock.set_process(false)

    var snapshot: Dictionary = save_system.collect(main)
    var pipeline = SAVE_MIGRATION_SCRIPT.new()
    if pipeline == null:
        push_error("SaveMigrationPipeline failed to instantiate")
        quit(1)
        return

    # A compact, valid snapshot keeps per-version validator checks bounded.
    # Full entity/resource round-trips remain covered by their own integration suites.
    var migration_baseline: Dictionary = snapshot.duplicate(true)
    var saved_keep: Dictionary = {}
    for building_value in migration_baseline.get("buildings", []):
        if String(building_value.get("id", "")) == "keep":
            saved_keep = building_value.duplicate(true)
            break
    _require(not saved_keep.is_empty(), "The canonical migration fixture must retain its Keep")
    migration_baseline["buildings"] = [saved_keep] if not saved_keep.is_empty() else []
    var baseline_villagers: Array = migration_baseline.get("villagers", [])
    migration_baseline["villagers"] = [baseline_villagers[0].duplicate(true)] if not baseline_villagers.is_empty() else []
    migration_baseline["enemies"] = []
    migration_baseline["resources"] = []
    migration_baseline["construction_sites"] = []
    migration_baseline["fog"] = {"cells": []}
    var legacy_v4: Dictionary = migration_baseline.duplicate(true)
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

    var v8: Dictionary = migration_baseline.duplicate(true)
    v8["version"] = 8
    v8.erase("frontier_campaign")
    v8.erase("supply")
    var v8_plan: Dictionary = pipeline.build_restore_plan(v8, main.world, save_system.VERSION)
    _require(String(v8_plan["campaign_mode"]) == "campaign" and v8_plan["campaign_state"] == v8["campaign"],
        "The v8 migration boundary must select the campaign snapshot path")

    var v9: Dictionary = migration_baseline.duplicate(true)
    v9["version"] = 9
    v9["villagers"][0]["job"] = "woodcutter"
    v9["villagers"][0]["occupation"] = "builder"
    v9["villagers"][0]["military_specialization"] = ""
    var v9_plan: Dictionary = pipeline.build_restore_plan(v9, main.world, save_system.VERSION)
    _require(String(v9_plan["villagers"][0]["job"]) == "builder",
        "The v9 migration boundary must restore occupation-based villager roles")

    var v10: Dictionary = migration_baseline.duplicate(true)
    v10["version"] = 10
    v10["enemies"] = [{"id": "raider", "faction": "wolves"}]
    var v10_plan: Dictionary = pipeline.build_restore_plan(v10, main.world, save_system.VERSION)
    _require(String(v10_plan["enemies"][0]["faction"]) == "wolves",
        "The v10 migration boundary must preserve saved enemy faction identity")

    var v11: Dictionary = migration_baseline.duplicate(true)
    v11["version"] = 11
    v11.erase("supply")
    var v11_plan: Dictionary = pipeline.build_restore_plan(v11, main.world, save_system.VERSION)
    _require(v11_plan["frontier_campaign_state"] == v11["frontier_campaign"],
        "The v11 migration boundary must preserve Frontier objective state")

    var v12: Dictionary = migration_baseline.duplicate(true)
    v12["version"] = 12
    v12["buildings"][0]["stockpile"] = {"wood": 4}
    var v12_plan: Dictionary = pipeline.build_restore_plan(v12, main.world, save_system.VERSION)
    _require(bool(v12_plan["restore_building_stockpiles"]) and v12_plan["building_stockpiles"][0] == {"wood": 4},
        "The v12 migration boundary must preserve saved building stockpiles")

    var v13: Dictionary = migration_baseline.duplicate(true)
    v13["version"] = 13
    v13["supply"] = {"next_id": 3, "orders": []}
    var v13_plan: Dictionary = pipeline.build_restore_plan(v13, main.world, save_system.VERSION)
    _require(v13_plan["supply_state"] == v13["supply"],
        "The v13 migration boundary must preserve logistics state")

    var current: Dictionary = migration_baseline.duplicate(true)
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

    # Exercise every officially supported Classic source version through both
    # the restore adapter and the canonical v17 conversion path.
    var classic_v1_for_storage: Dictionary = {}
    for source_version in range(1, 18):
        var classic_fixture: Dictionary = migration_baseline.duplicate(true)
        classic_fixture["version"] = source_version
        if source_version < 5:
            for villager in classic_fixture["villagers"]:
                villager.erase("expedition")
                villager.erase("recalling")
        if source_version < 6:
            classic_fixture["player"].erase("combat")
        if source_version < 7:
            classic_fixture.erase("world")
        if source_version < 8:
            classic_fixture.erase("campaign")
        if source_version < 9:
            classic_fixture.erase("job_priority")
            classic_fixture["quota"].erase("builder")
            for villager in classic_fixture["villagers"]:
                villager.erase("occupation")
                villager.erase("military_specialization")
        if source_version < 14:
            classic_fixture["quota"].erase("hunter")
            for resource_index in range(classic_fixture["resources"].size() - 1, -1, -1):
                if String(classic_fixture["resources"][resource_index].get("kind", "")) == "food":
                    classic_fixture["resources"].remove_at(resource_index)
            for index in range(classic_fixture["buildings"].size() - 1, -1, -1):
                if String(classic_fixture["buildings"][index].get("id", "")) == "hunting_lodge":
                    classic_fixture["buildings"].remove_at(index)
        if source_version < 15:
            classic_fixture["quota"].erase("scout")
            for index in range(classic_fixture["buildings"].size() - 1, -1, -1):
                if String(classic_fixture["buildings"][index].get("id", "")) == "scout_post":
                    classic_fixture["buildings"].remove_at(index)
        if source_version < 16:
            classic_fixture["quota"].erase("healer")
            for index in range(classic_fixture["buildings"].size() - 1, -1, -1):
                if String(classic_fixture["buildings"][index].get("id", "")) == "infirmary":
                    classic_fixture["buildings"].remove_at(index)
        if source_version < 17:
            classic_fixture["quota"].erase("blacksmith")
            for index in range(classic_fixture["buildings"].size() - 1, -1, -1):
                if String(classic_fixture["buildings"][index].get("id", "")) == "forge":
                    classic_fixture["buildings"].remove_at(index)
            for villager in classic_fixture["villagers"]:
                if String(villager.get("job", "")) == "blacksmith":
                    villager["job"] = ""
                if String(villager.get("occupation", "")) == "blacksmith":
                    villager["job"] = ""
                    villager["occupation"] = ""
        if source_version < 10:
            for enemy in classic_fixture["enemies"]:
                enemy.erase("faction")
        if source_version < 11:
            classic_fixture.erase("frontier_campaign")
        if source_version < 12:
            for building in classic_fixture["buildings"]:
                building.erase("stockpile")
        if source_version < 13:
            classic_fixture.erase("supply")
        if source_version < 17:
            for villager in classic_fixture["villagers"]:
                villager.erase("weapon_equipped")
                villager.erase("armor_equipped")
            classic_fixture.erase("events")
        if source_version < 14 and classic_fixture.has("job_priority"):
            classic_fixture["job_priority"].erase("hunter")
        if source_version < 15 and classic_fixture.has("job_priority"):
            classic_fixture["job_priority"].erase("scout")
        if source_version < 16 and classic_fixture.has("job_priority"):
            classic_fixture["job_priority"].erase("healer")
        if source_version < 17 and classic_fixture.has("job_priority"):
            classic_fixture["job_priority"].erase("blacksmith")
        var classic_before_canonical := JSON.stringify(classic_fixture)
        var canonical_classic: Variant = pipeline.migrate_snapshot_to_current(classic_fixture, main, save_system.VERSION)
        _require(canonical_classic is Dictionary,
            "Classic v%d must be eligible for canonical v17 conversion" % source_version)
        if canonical_classic is Dictionary:
            _require(int(canonical_classic.get("version", 0)) == save_system.VERSION,
                "Classic v%d canonical conversion must set schema v17" % source_version)
            _require(save_system._valid_save(canonical_classic, true),
                "Classic v%d canonical output must satisfy the current SaveValidator" % source_version)
        _require(JSON.stringify(classic_fixture) == classic_before_canonical,
            "Classic v%d canonical conversion must not mutate the source fixture" % source_version)
        if source_version == 1:
            classic_v1_for_storage = classic_fixture.duplicate(true)
        var classic_plan: Dictionary = pipeline.build_restore_plan(classic_fixture, main.world, save_system.VERSION)
        _require(int(classic_plan["source_version"]) == source_version,
            "Classic v%d must produce a restore plan tagged with its source version" % source_version)
        _require((String(classic_plan["campaign_mode"]) == "campaign") == (source_version >= 8),
            "Classic v%d must retain the correct legacy/campaign restore mode" % source_version)

    _require(save_system._valid_save(classic_v1_for_storage, true),
        "The v1 on-disk migration fixture must pass its original schema validator")
    var legacy_file := FileAccess.open("user://save.json", FileAccess.WRITE)
    _require(legacy_file != null, "The v1 on-disk migration fixture must be writable")
    if legacy_file != null:
        legacy_file.store_string(JSON.stringify(classic_v1_for_storage))
        legacy_file.flush()
        legacy_file.close()
    var load_requested: bool = save_system.request_load()
    _require(load_requested, "Loading a supported historical save must request scene restoration")
    var installed_snapshot: Variant = save_system._read_valid_save("user://save.json")
    _require(installed_snapshot is Dictionary and int(installed_snapshot.get("version", 0)) == save_system.VERSION,
        "Loading a historical primary must atomically install its canonical v17 replacement")
    var rollback_snapshot: Variant = save_system._read_valid_save("user://save.bak")
    _require(rollback_snapshot is Dictionary and int(rollback_snapshot.get("version", 0)) == 1,
        "Canonical replacement must retain the original v1 primary as a verified rollback backup")
    _require(not FileAccess.file_exists("user://save.tmp"),
        "A successful canonical migration must not leave a temporary file")

    if load_requested:
        await _ticks(8)
        var restored_main: Node = current_scene
        _require(restored_main != null and restored_main.campaign != null and restored_main.campaign.objectives_in_order().size() == 1,
            "The canonical v17 replacement must restore the original legacy stronghold campaign")
        if restored_main != null:
            main = restored_main
    _require(is_instance_valid(main), "The restored Classic scene must remain available as a migration context")
    world_config.apply_profile("frontier")
    # Canonical migration is data-only. Reuse the already-running scene context
    # and convert a validated Classic snapshot into a structurally valid
    # Frontier snapshot instead of generating another 192x192 world here.
    main.world.map_size = 192
    var frontier_snapshot: Dictionary = migration_baseline.duplicate(true)
    frontier_snapshot["world"]["profile"] = "frontier"
    frontier_snapshot["world"]["map_size"] = 192
    frontier_snapshot["world"]["tile_size"] = 16
    frontier_snapshot["world"]["seed"] = world_config.world_seed
    var frontier_campaign_state: Dictionary = frontier_snapshot["campaign"].duplicate(true)
    frontier_campaign_state["profile"] = "frontier"
    frontier_snapshot["campaign"] = frontier_campaign_state
    frontier_snapshot["frontier_campaign"] = pipeline._default_frontier_campaign(
        "frontier", root.get_node("DataDB")
    )
    _require(String(frontier_snapshot["world"]["profile"]) == "frontier",
        "Canonical migration fixtures must use the Frontier profile contract")
    for source_version in range(7, 18):
        var frontier_fixture: Dictionary = frontier_snapshot.duplicate(true)
        frontier_fixture["version"] = source_version
        if source_version < 8:
            frontier_fixture.erase("campaign")
        if source_version < 9:
            frontier_fixture.erase("job_priority")
            frontier_fixture["quota"].erase("builder")
            for villager in frontier_fixture["villagers"]:
                villager.erase("occupation")
                villager.erase("military_specialization")
        if source_version < 11:
            frontier_fixture.erase("frontier_campaign")
        if source_version < 14:
            frontier_fixture["quota"].erase("hunter")
            for resource_index in range(frontier_fixture["resources"].size() - 1, -1, -1):
                if String(frontier_fixture["resources"][resource_index].get("kind", "")) == "food":
                    frontier_fixture["resources"].remove_at(resource_index)
            for index in range(frontier_fixture["buildings"].size() - 1, -1, -1):
                if String(frontier_fixture["buildings"][index].get("id", "")) == "hunting_lodge":
                    frontier_fixture["buildings"].remove_at(index)
        if source_version < 15:
            frontier_fixture["quota"].erase("scout")
            for index in range(frontier_fixture["buildings"].size() - 1, -1, -1):
                if String(frontier_fixture["buildings"][index].get("id", "")) == "scout_post":
                    frontier_fixture["buildings"].remove_at(index)
        if source_version < 16:
            frontier_fixture["quota"].erase("healer")
            for index in range(frontier_fixture["buildings"].size() - 1, -1, -1):
                if String(frontier_fixture["buildings"][index].get("id", "")) == "infirmary":
                    frontier_fixture["buildings"].remove_at(index)
        if source_version < 17:
            frontier_fixture["quota"].erase("blacksmith")
            for index in range(frontier_fixture["buildings"].size() - 1, -1, -1):
                if String(frontier_fixture["buildings"][index].get("id", "")) == "forge":
                    frontier_fixture["buildings"].remove_at(index)
            for villager in frontier_fixture["villagers"]:
                if String(villager.get("job", "")) == "blacksmith":
                    villager["job"] = ""
                if String(villager.get("occupation", "")) == "blacksmith":
                    villager["job"] = ""
                    villager["occupation"] = ""
        if source_version < 12:
            for building in frontier_fixture["buildings"]:
                building.erase("stockpile")
        if source_version < 13:
            frontier_fixture.erase("supply")
        if source_version < 17:
            for villager in frontier_fixture["villagers"]:
                villager.erase("weapon_equipped")
                villager.erase("armor_equipped")
            frontier_fixture.erase("events")
        if source_version < 14 and frontier_fixture.has("job_priority"):
            frontier_fixture["job_priority"].erase("hunter")
        if source_version < 15 and frontier_fixture.has("job_priority"):
            frontier_fixture["job_priority"].erase("scout")
        if source_version < 16 and frontier_fixture.has("job_priority"):
            frontier_fixture["job_priority"].erase("healer")
        if source_version < 17 and frontier_fixture.has("job_priority"):
            frontier_fixture["job_priority"].erase("blacksmith")
        var frontier_before_canonical := JSON.stringify(frontier_fixture)
        var canonical_frontier: Variant = pipeline.migrate_snapshot_to_current(frontier_fixture, main, save_system.VERSION)
        _require(canonical_frontier is Dictionary,
            "Frontier v%d must be eligible for canonical v17 conversion" % source_version)
        if canonical_frontier is Dictionary:
            _require(int(canonical_frontier.get("version", 0)) == save_system.VERSION,
                "Frontier v%d canonical conversion must set schema v17" % source_version)
            _require(save_system._valid_save(canonical_frontier, true),
                "Frontier v%d canonical output must satisfy the current SaveValidator" % source_version)
        _require(JSON.stringify(frontier_fixture) == frontier_before_canonical,
            "Frontier v%d canonical conversion must not mutate the source fixture" % source_version)
        var frontier_plan: Dictionary = pipeline.build_restore_plan(frontier_fixture, main.world, save_system.VERSION)
        _require(int(frontier_plan["source_version"]) == source_version,
            "Frontier v%d must produce a restore plan tagged with its source version" % source_version)
        _require((String(frontier_plan["campaign_mode"]) == "campaign") == (source_version >= 8),
            "Frontier v%d must retain the correct legacy/campaign restore mode" % source_version)
        _require(bool(frontier_plan["restore_building_stockpiles"]) == (source_version >= 12),
            "Frontier v%d must gate stockpile restore at v12" % source_version)
        _require(not frontier_plan["supply_state"].is_empty() or source_version < 13,
            "Frontier v%d must preserve the v13 supply-state boundary" % source_version)

    if is_instance_valid(main):
        main.queue_free()
    await _ticks(2)
    if failures.is_empty():
        print("PASS: Classic v1-v17 and Frontier v7-v17 restore plans, version boundaries, legacy defaults and source immutability")
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
