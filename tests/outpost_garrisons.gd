extends SceneTree
## Phase 02.4: Outpost guard capacity, local defense leash, lifecycle and save/load.

func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func _find_outpost_cell(main, keep, config) -> Vector2i:
    for radius in range(5, 13):
        for y in range(-radius, radius + 1):
            for x in range(-radius, radius + 1):
                if maxi(absi(x), absi(y)) != radius:
                    continue
                var anchor: Vector2i = keep.cell + Vector2i(x, y)
                var cells: Array[Vector2i] = []
                var valid := true
                for cy in 2:
                    for cx in 2:
                        var cell := anchor + Vector2i(cx, cy)
                        if cell.x < 1 or cell.y < 1 or cell.x >= int(config.map_size) - 1 or cell.y >= int(config.map_size) - 1:
                            valid = false
                            break
                        if not main.world.is_buildable(cell) or main.world.occupied.has(cell):
                            valid = false
                            break
                        cells.append(cell)
                    if not valid:
                        break
                if not valid or main.nav.path_adjacent(main.player.position, cells).is_empty():
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
    var clock = root.get_node("GameClock")
    var config = root.get_node("WorldConfig")
    var save_system = root.get_node("SaveSystem")
    var data_db = root.get_node("DataDB")
    config.apply_profile("frontier")
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

    var keep = null
    for building in get_nodes_in_group("buildings"):
        if building.id == "keep":
            keep = building
            break
    assert(keep != null, "Frontier campaign must have a Keep")

    var outpost_cell := _find_outpost_cell(main, keep, config)
    assert(outpost_cell.x >= 0, "Test must find a reachable 2x2 Outpost site")
    var outpost = main.build.place_raw("outpost", outpost_cell)
    await ticks(5)
    assert(outpost.guard_capacity == 2, "Outpost must expose its configured two guard slots")
    assert(outpost.guard_count() == 0 and outpost.free_guard_slots() == 2,
        "A new Outpost must start with all guard slots free")

    main.village.quota["soldier"] = 2
    var soldier_a = main.village.spawn_villager(keep.position + Vector2(0, 18))
    var soldier_b = main.village.spawn_villager(keep.position + Vector2(10, 18))
    assert(soldier_a.set_job("soldier") and soldier_b.set_job("soldier"),
        "Two villagers must be assignable as soldiers")
    assert(main.village.assign_nearest_outpost_guard(outpost), "First available soldier must be assigned")
    assert(outpost.guard_count() == 1 and outpost.free_guard_slots() == 1,
        "First assignment must consume exactly one guard slot")
    assert(main.village.assign_nearest_outpost_guard(outpost), "Second available soldier must be assigned")
    assert(outpost.guard_count() == 2 and outpost.free_guard_slots() == 0,
        "Second assignment must fill the Outpost capacity")
    assert(not main.village.assign_nearest_outpost_guard(outpost),
        "A full Outpost must reject additional assignments")

    var deceased_guard = outpost.guards.back()
    deceased_guard.take_damage(deceased_guard.hp + 1)
    await ticks(2)
    assert(outpost.guard_count() == 1,
        "A soldier death must release its Outpost guard slot")

    var soldier_c = main.village.spawn_villager(keep.position + Vector2(-10, 18))
    assert(soldier_c.set_job("soldier"), "A replacement soldier must be assignable")
    assert(main.village.assign_nearest_outpost_guard(outpost) and outpost.guard_count() == 2,
        "A freed slot must accept a replacement guard")

    var guards: Array = outpost.guards.duplicate()
    assert(guards.size() == 2, "The Outpost must own both guard references")
    var guard = guards[0]
    assert(guard.is_outpost_guard() and guard.guard_outpost == outpost,
        "Assigned soldier must retain its Outpost reference")
    var target = main.campaign.current_target_node()
    assert(target != null and not guard.start_expedition(target),
        "Outpost guards must not be pulled into a global conquest expedition")

    for enemy in get_nodes_in_group("enemies"):
        enemy.queue_free()
    await ticks(2)
    guard.position = outpost.position + Vector2(0, 32)
    var distant_enemy = _spawn_test_enemy(main, outpost.position + Vector2(170, 0), data_db)
    await ticks(2)
    assert(guard._nearest_enemy() == null,
        "A guard must ignore enemies outside its Outpost defense radius")
    var local_enemy = _spawn_test_enemy(main, outpost.position + Vector2(24, 0), data_db)
    await ticks(2)
    assert(guard._nearest_enemy() == local_enemy,
        "A guard must prioritize an enemy inside its Outpost defense radius")
    guard._tick_outpost_guard(0.31)
    var villager_states: Dictionary = guard.get_script().get_script_constant_map()["State"]
    assert(guard.state == int(villager_states["FIGHT"]),
        "A nearby hostile must pull an idle Outpost guard into combat")
    local_enemy.queue_free()
    await ticks(2)
    guard._tick_fight(0.31)
    assert(guard.state == int(villager_states["IDLE"]) and guard._path.is_empty(),
        "A guard must clear its chase path and return to its local idle state when no in-radius enemies remain")
    distant_enemy.queue_free()
    await ticks(2)

    var fog = get_first_node_in_group("fog_of_war")
    if fog != null:
        fog._scan_sources()
    assert(fog != null and fog.is_revealed_cell(outpost.cell + Vector2i(3, 0)),
        "An Outpost must reveal its bounded local visibility radius")
    var hud = get_first_node_in_group("hud")
    assert(hud != null and hud._outpost_panel != null and hud._outpost_button != null,
        "HUD must expose the Outpost inspection and assignment panel")
    hud._toggle_outposts()
    assert(hud._outpost_panel.visible and hud._outpost_list.get_child_count() > 0,
        "Outpost panel must render local depot information")
    hud._toggle_outposts()

    var snapshot: Dictionary = save_system.collect(main)
    assert(snapshot["version"] == 13, "Guard links and shipment state must use save v13")
    var saved_guard_count := 0
    for saved_villager in snapshot["villagers"]:
        if saved_villager.get("guard_outpost", null) is Dictionary:
            saved_guard_count += 1
    assert(saved_guard_count == 2, "Save snapshot must persist both Outpost guard assignments")
    assert(save_system._valid_save(snapshot), "Save v12 with valid guard links must pass validation")
    var legacy_snapshot := snapshot.duplicate(true)
    legacy_snapshot["version"] = 12
    legacy_snapshot.erase("supply")
    for saved_villager in legacy_snapshot["villagers"]:
        saved_villager.erase("guard_outpost")
    assert(save_system._valid_save(legacy_snapshot),
        "Existing v12 saves without shipment or guard fields must remain valid")
    var invalid_snapshot := snapshot.duplicate(true)
    for saved_villager in invalid_snapshot["villagers"]:
        if saved_villager.get("guard_outpost", null) is Dictionary:
            saved_villager["guard_outpost"] = {"cx": 0, "cy": 0}
            break
    assert(not save_system._valid_save(invalid_snapshot),
        "Save validation must reject a guard link that does not reference a saved Outpost")

    assert(save_system.save_current(true), "Campaign with assigned guards must save")
    assert(save_system.request_load(), "Saved campaign with guard assignments must reload")
    await ticks(12)
    var restored_main = get_first_node_in_group("main")
    assert(restored_main != null, "Reload must restore the main campaign scene")
    restored_main.village.set_process(false)
    var restored_outpost = null
    for building in get_nodes_in_group("buildings"):
        if building.id == "outpost":
            restored_outpost = building
            break
    assert(restored_outpost != null and restored_outpost.guard_count() == 2,
        "Save/load must restore both guard assignments onto the matching Outpost")
    for soldier in get_nodes_in_group("villagers"):
        if soldier.is_outpost_guard():
            assert(soldier.guard_outpost == restored_outpost,
                "Restored soldier must reference the restored Outpost node")

    restored_outpost.demolish()
    assert(restored_outpost.guard_count() == 0,
        "Removing an Outpost must release every assigned guard")
    for soldier in get_nodes_in_group("villagers"):
        assert(not soldier.is_outpost_guard(),
            "A released guard must return to the general defender pool")

    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)
    print("PASS: Outpost guard slots, local combat leash, expedition exclusion, demolition release and save/load")
    quit()
