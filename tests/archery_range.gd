extends SceneTree
## Archery Range: Fletching unlock, two archer slots, ranged combat, v17 persistence and role fallback.

func require(condition: bool, message: String) -> void:
    if not condition:
        push_error("FAIL: " + message)
        quit(1)
    assert(condition, message)


func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func find_build_site(main, origin: Vector2i, footprint: Vector2i) -> Vector2i:
    var map_size := int(root.get_node("WorldConfig").map_size)
    for radius in range(4, 14):
        for y in range(-radius, radius + 1):
            for x in range(-radius, radius + 1):
                if maxi(absi(x), absi(y)) != radius:
                    continue
                var anchor := origin + Vector2i(x, y)
                if anchor.x < 1 or anchor.y < 1 or anchor.x + footprint.x >= map_size - 1 or anchor.y + footprint.y >= map_size - 1:
                    continue
                var cells: Array[Vector2i] = []
                var clear := true
                for dy in footprint.y:
                    for dx in footprint.x:
                        var cell := anchor + Vector2i(dx, dy)
                        cells.append(cell)
                        if not main.world.is_buildable(cell) or main.world.occupied.has(cell):
                            clear = false
                if not clear or main.nav.path_adjacent(main.player.position, cells).is_empty():
                    continue
                return anchor
    return Vector2i(-1, -1)


func _spawn_test_enemy(main, position_world: Vector2, data_db):
    var script = load("res://scripts/entities/enemy.gd")
    var enemy = script.new()
    enemy.setup(data_db.enemies["bandit"], main.world, main.flow, main.player)
    enemy.position = position_world
    main.world.entities.add_child(enemy)
    return enemy


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var config = root.get_node("WorldConfig")
    var clock = root.get_node("GameClock")
    var tech = root.get_node("Tech")
    var inventory = root.get_node("Inventory")
    var save_system = root.get_node("SaveSystem")
    var data_db = root.get_node("DataDB")
    config.apply_profile("classic")
    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(8)
    clock.set_process(false)
    main.village.set_process(false)
    main.spawner.set_process(false)
    main.spawner.set_physics_process(false)
    for existing in main.village.villagers():
        existing.leave()
    await ticks(2)

    require(not tech.building_unlocked("archery_range"),
        "Archery Range must remain locked before Fletching")
    tech.import_state({"done": ["fletching"]})
    require(tech.building_unlocked("archery_range") and tech.available_buildings().has("archery_range"),
        "Fletching must unlock Archery Range placement")

    var keep = null
    for depot in get_nodes_in_group("depots"):
        if depot.id == "keep":
            keep = depot
            break
    require(keep != null, "Classic campaign must retain its Keep")
    inventory.items = {"wood": 500, "stone": 500, "food": 100}
    var range_cell := find_build_site(main, keep.cell, Vector2i(2, 2))
    require(range_cell.x >= 0, "A reachable Archery Range footprint must exist")
    var archery_range = main.build.place_raw("archery_range", range_cell)
    await ticks(3)
    main.nav.rebuild()
    require(archery_range.is_in_group("archery_ranges"), "Archery Range must register with the training UI group")
    require(archery_range.free_slots("archer") == 2, "Archery Range must expose exactly two archer training slots")
    require(archery_range.free_slots("soldier") == 0, "Archery Range must not claim ordinary soldier workplace slots")

    main.village.quota["soldier"] = 3
    var soldiers: Array = []
    for index in 3:
        var soldier = main.village.spawn_villager(archery_range.position + Vector2((index - 1) * 22.0, 34.0))
        require(soldier.set_job("soldier"), "Three regular soldiers must be available for archery training")
        soldier.set_physics_process(false)
        soldiers.append(soldier)
    require(main.village.assign_nearest_archer(archery_range), "The first soldier must take an Archery Range training slot")
    require(main.village.assign_nearest_archer(archery_range), "The second soldier must take the final Archery Range training slot")
    require(not main.village.assign_nearest_archer(archery_range), "A third soldier must be rejected when both archer slots are full")
    require(archery_range.free_slots("archer") == 0 and archery_range.workers.size() == 2,
        "Training assignments must occupy both physical Archery Range workplace slots")
    var archers: Array = []
    for soldier in soldiers:
        if soldier.is_archer():
            archers.append(soldier)
            require(soldier.job == "soldier" and soldier.military_specialization == "archer",
                "An archer must remain a soldier in the population and military role model")
            require(soldier.is_in_group("defenders") and soldier.workplace == archery_range and soldier.workplace_job == "archer",
                "An archer must remain a defender while claiming an archer training slot")
    require(archers.size() == 2, "Exactly two soldiers must become archers")
    require(main.village.release_archer(archery_range), "The logistics release action must return one archer to regular soldier duty")
    require(archers[0].job == "soldier" and not archers[0].is_archer(), "Released archer must keep soldier status and lose the archer specialization")
    require(archery_range.free_slots("archer") == 1, "Releasing an archer must return one training slot")
    require(main.village.assign_nearest_archer(archery_range), "A released training slot must accept a soldier again")
    archers.clear()
    for soldier in soldiers:
        if soldier.is_archer():
            archers.append(soldier)
    require(archers.size() == 2, "Archery Range must return to exactly two trained soldiers after reassignment")

    var archer = archers[0]
    var enemy = _spawn_test_enemy(main, archer.position + Vector2(112, 0), data_db)
    enemy.set_physics_process(false)
    var enemy_hp_before: int = enemy.hp
    enemy.position = archer.position + Vector2(40, 0)
    archer._atk_cd = 10.0
    archer._scan_t = 0.0
    archer._tick_fight(0.1)
    require(archer.position.distance_to(enemy.position) > 40.0,
        "An archer inside minimum range must retreat before attempting another shot")
    enemy.position = archer.position + Vector2(112, 0)
    archer._atk_cd = 0.0
    archer._scan_t = 0.0
    archer._tick_fight(0.016)
    require(archer._pending_foe == null, "Archer attacks must not schedule melee hit windows")
    require(is_equal_approx(archer._atk_cd, 1.15),
        "Archer firing cadence must retain its 1.15-second base cooldown")
    await ticks(45)
    require(enemy.hp < enemy_hp_before, "An archer inside its 150-pixel combat range must damage enemies with an arrow projectile")
    enemy.queue_free()
    await ticks(2)

    var snapshot: Dictionary = save_system.collect(main)
    require(snapshot["version"] == 17, "Archer specialization must not require a save schema version bump")
    var saved_archer_count := 0
    for saved_villager in snapshot["villagers"]:
        if String(saved_villager.get("military_specialization", "")) == "archer":
            saved_archer_count += 1
            require(String(saved_villager.get("job", "")) == "soldier" and String(saved_villager.get("occupation", "")) == "",
                "Save data must encode archers as the soldier role with an archer specialization")
    require(saved_archer_count == 2, "Save collection must preserve both archer specializations")
    if not save_system._valid_save(snapshot):
        var validator = load("res://scripts/persistence/save_validator.gd").new()
        validator.configure(save_system.VERSION)
        var world_data: Dictionary = snapshot.get("world", {})
        var campaign_data: Dictionary = snapshot.get("campaign", {})
        print("ARCHERY_SAVE_DIAGNOSTIC ", {
            "version": snapshot.get("version"),
            "profile": world_data.get("profile"),
            "map_size": world_data.get("map_size"),
            "valid_campaign": validator.call("_valid_campaign_state", campaign_data, String(world_data.get("profile", "")), int(world_data.get("map_size", 0))),
            "valid_frontier": validator.call("_valid_frontier_campaign", snapshot.get("frontier_campaign", {}), String(world_data.get("profile", "")), int(world_data.get("map_size", 0))),
            "supply": snapshot.get("supply"),
            "resource_count": snapshot.get("resources", []).size(),
            "buildings": snapshot.get("buildings", []).map(func(b): return [b.get("id"), b.get("cx"), b.get("cy")]),
            "campaign": campaign_data
        })
        for objective: Dictionary in campaign_data.get("objectives", []):
            if objective.has("civilization"):
                print("ARCHERY_RIVAL_DIAGNOSTIC ", {
                    "objective": objective.get("id"),
                    "civilization": objective.get("civilization"),
                    "valid": validator.call("_valid_rival_civilization", objective.get("civilization"), int(world_data.get("map_size", 0)), Vector2i(int(objective.get("cx", -1)), int(objective.get("cy", -1))))
                })
    require(save_system._valid_save(snapshot), "SaveValidator must accept an archer roster within Archery Range capacity")

    var invalid_capacity := snapshot.duplicate(true)
    for building_index in range(invalid_capacity["buildings"].size() - 1, -1, -1):
        if String(invalid_capacity["buildings"][building_index].get("id", "")) == "archery_range":
            invalid_capacity["buildings"].remove_at(building_index)
    require(not save_system._valid_save(invalid_capacity),
        "SaveValidator must reject archer specializations when no Archery Range capacity is saved")

    var invalid_legacy_archers := snapshot.duplicate(true)
    invalid_legacy_archers["version"] = 16
    require(not save_system._valid_save(invalid_legacy_archers),
        "Archery specialization must not appear in historical saves before schema v17")

    require(save_system.save_current(true), "Campaign with trained archers must save")
    require(save_system.request_load(), "Campaign with trained archers must reload")
    await ticks(12)
    var restored_main = get_first_node_in_group("main")
    require(restored_main != null, "Reload must restore the main campaign scene")
    restored_main.village.set_process(false)
    var restored_range = null
    for candidate in get_nodes_in_group("archery_ranges"):
        if candidate.id == "archery_range":
            restored_range = candidate
            break
    require(restored_range != null, "Save/load must restore the Archery Range")
    require(restored_range.free_slots("archer") == 0 and restored_range.workers.size() == 2,
        "Save/load must reassign both archer specialists to the restored Archery Range")
    var restored_archers: Array = []
    for soldier in get_nodes_in_group("villagers"):
        if soldier.is_archer():
            restored_archers.append(soldier)
            require(soldier.job == "soldier" and soldier.workplace == restored_range and soldier.workplace_job == "archer",
                "Restored archer must retain soldier status and its training workplace")
    require(restored_archers.size() == 2, "Save/load must restore exactly two archer specializations")

    restored_range.demolish()
    for soldier in restored_archers:
        require(not soldier.is_archer() and soldier.job == "soldier" and soldier.military_specialization == "soldier",
            "Destroying the training range must return its archers to ordinary soldiers")
        require(soldier.workplace == null and soldier.is_in_group("defenders"),
            "Former archers must retain military defense membership without a destroyed workplace")

    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)
    print("PASS: Fletching unlock, archer capacity, ranged projectile combat, soldier-role compatibility, v17 save/load and workplace-loss fallback")
    quit(0)