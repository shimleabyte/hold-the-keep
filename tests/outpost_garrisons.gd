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


func _find_nearby_garrison_cell(main, origin: Vector2i, config) -> Vector2i:
    var offsets: Array[Vector2i] = [
        Vector2i(0, -4), Vector2i(4, 0), Vector2i(0, 4), Vector2i(-4, 0),
        Vector2i(0, -6), Vector2i(6, 0), Vector2i(0, 6), Vector2i(-6, 0),
        Vector2i(4, -4), Vector2i(4, 4), Vector2i(-4, 4), Vector2i(-4, -4)
    ]
    for offset in offsets:
        var anchor := origin + offset
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
        if valid and not main.nav.path_adjacent(main.player.position, cells).is_empty():
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

    var barracks_cell := _find_nearby_garrison_cell(main, outpost_cell, config)
    assert(barracks_cell.x >= 0, "Test must find a second reachable 2x2 site for Barracks")
    var barracks = main.build.place_raw("barracks", barracks_cell)
    await ticks(4)
    assert(barracks.guard_capacity == 4 and barracks.free_guard_slots() == 4,
        "Barracks must provide four central garrison slots")
    assert(barracks.is_in_group("garrisons"), "Barracks must register with the garrison inspection group")

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

    var soldier_d = main.village.spawn_villager(keep.position + Vector2(-18, 18))
    assert(soldier_d.set_job("soldier"), "A third surviving soldier must be available to garrison Barracks")
    assert(main.village.assign_nearest_garrison_guard(barracks), "Barracks must accept an available soldier")
    assert(barracks.guard_count() == 1 and barracks.free_guard_slots() == 3,
        "Barracks assignment must consume one of its four slots")
    var barracks_guard = barracks.guards[0]
    assert(barracks_guard.is_outpost_guard() and barracks_guard.guard_outpost == barracks,
        "The legacy guard reference must point to the assigned Barracks building")

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
    guard.set_physics_process(false)
    barracks_guard.set_physics_process(false)
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

    barracks_guard.position = barracks.position + Vector2(0, 32)
    var barracks_distant_enemy = _spawn_test_enemy(main, barracks.position + Vector2(160, 0), data_db)
    await ticks(2)
    assert(barracks_guard._nearest_enemy() == null,
        "Barracks guards must ignore enemies beyond their configured 144-pixel defense radius")
    var barracks_local_enemy = _spawn_test_enemy(main, barracks.position + Vector2(24, 0), data_db)
    await ticks(2)
    assert(barracks_guard._nearest_enemy() == barracks_local_enemy,
        "Barracks guards must prioritize enemies inside their local defense radius")
    barracks_guard._tick_outpost_guard(0.31)
    assert(barracks_guard.state == int(villager_states["FIGHT"]),
        "A Barracks guard must enter combat when a hostile breaches its local radius")
    barracks_local_enemy.queue_free()
    await ticks(2)
    barracks_guard._tick_fight(0.31)
    assert(barracks_guard.state == int(villager_states["IDLE"]),
        "A Barracks guard must return to its local idle behavior after the threat is gone")
    barracks_distant_enemy.queue_free()
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
    assert(hud._outpost_panel.visible and hud._outpost_list.get_child_count() >= 2,
        "Logistics panel must render both Outpost depots and Barracks garrisons")
    hud._toggle_outposts()

    var snapshot: Dictionary = save_system.collect(main)
    assert(snapshot["version"] == 17, "Barracks garrison links must remain compatible with save schema v17")
    var saved_guard_count := 0
    for saved_villager in snapshot["villagers"]:
        if saved_villager.get("guard_outpost", null) is Dictionary:
            saved_guard_count += 1
    assert(saved_guard_count == 2, "Save snapshot must persist both Outpost guard assignments")
    var saved_barracks_guard_count := 0
    for saved_villager in snapshot["villagers"]:
        var saved_garrison: Variant = saved_villager.get("guard_garrison", null)
        if saved_garrison is Dictionary and String(saved_garrison.get("id", "")) == "barracks":
            saved_barracks_guard_count += 1
    assert(saved_barracks_guard_count == 1, "Save snapshot must persist the Barracks garrison building reference")
    assert(save_system._valid_save(snapshot), "Save v17 with valid Outpost and Barracks garrison links must pass validation")
    var legacy_snapshot := snapshot.duplicate(true)
    legacy_snapshot["version"] = 12
    legacy_snapshot.erase("supply")
    legacy_snapshot["quota"].erase("hunter")
    legacy_snapshot["quota"].erase("scout")
    legacy_snapshot["job_priority"].erase("hunter")
    legacy_snapshot["job_priority"].erase("scout")
    legacy_snapshot["quota"].erase("healer")
    legacy_snapshot["job_priority"].erase("healer")
    legacy_snapshot["quota"].erase("blacksmith")
    legacy_snapshot["job_priority"].erase("blacksmith")
    for saved_villager in legacy_snapshot["villagers"]:
        saved_villager.erase("weapon_equipped")
        saved_villager.erase("armor_equipped")
        if String(saved_villager.get("occupation", "")) in ["hunter", "scout", "healer", "blacksmith"]:
            saved_villager["occupation"] = ""
            saved_villager["job"] = ""
        elif String(saved_villager.get("job", "")) in ["hunter", "scout"]:
            saved_villager["job"] = ""
        saved_villager.erase("guard_outpost")
        saved_villager.erase("guard_garrison")
    var legacy_resources: Array = []
    for resource in legacy_snapshot["resources"]:
        if String(resource.get("kind", "")) != "food":
            legacy_resources.append(resource)
    legacy_snapshot["resources"] = legacy_resources
    for building_index in range(legacy_snapshot["buildings"].size() - 1, -1, -1):
        if String(legacy_snapshot["buildings"][building_index].get("id", "")) in ["hunting_lodge", "scout_post", "infirmary", "forge", "barracks"]:
            legacy_snapshot["buildings"].remove_at(building_index)
    assert(save_system._valid_save(legacy_snapshot),
        "Existing v12 saves without shipment or guard fields must remain valid")
    var invalid_snapshot := snapshot.duplicate(true)
    for saved_villager in invalid_snapshot["villagers"]:
        if saved_villager.get("guard_outpost", null) is Dictionary:
            saved_villager["guard_outpost"] = {"cx": 0, "cy": 0}
            break
    assert(not save_system._valid_save(invalid_snapshot),
        "Save validation must reject a guard link that does not reference a saved Outpost")
    var invalid_garrison_snapshot := snapshot.duplicate(true)
    for saved_villager in invalid_garrison_snapshot["villagers"]:
        var garrison_link: Variant = saved_villager.get("guard_garrison", null)
        if garrison_link is Dictionary:
            garrison_link["id"] = "missing_garrison"
            break
    assert(not save_system._valid_save(invalid_garrison_snapshot),
        "Save validation must reject a garrison reference to a missing building definition")

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
    var restored_barracks = null
    for building in get_nodes_in_group("buildings"):
        if building.id == "barracks":
            restored_barracks = building
            break
    assert(restored_barracks != null and restored_barracks.guard_count() == 1,
        "Save/load must restore the Barracks guard onto the correct garrison building")
    for soldier in get_nodes_in_group("villagers"):
        if soldier.is_outpost_guard():
            assert(soldier.guard_outpost in [restored_outpost, restored_barracks],
                "Restored soldier must reference a restored garrison building")

    restored_outpost.demolish()
    assert(restored_outpost.guard_count() == 0,
        "Removing an Outpost must release every assigned guard")
    assert(restored_barracks.guard_count() == 1,
        "Removing an Outpost must not disturb the separate Barracks garrison")
    restored_barracks.demolish()
    assert(restored_barracks.guard_count() == 0,
        "Demolishing Barracks must release its assigned soldiers")
    for soldier in get_nodes_in_group("villagers"):
        assert(not soldier.is_outpost_guard(),
            "A released guard must return to the general defender pool")

    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)
    print("PASS: Outpost and Barracks garrisons, local combat radii, expedition exclusion, demolition cleanup and v17 save/load")
    quit()
