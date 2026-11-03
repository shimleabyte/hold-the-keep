extends SceneTree
## Phase 02.5: isolated contested depots warn, spawn targeted saboteurs and persist pressure.

func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func require(condition: bool, message: String) -> void:
    if not condition:
        push_error("FAIL: " + message)
        quit(1)
    assert(condition, message)


func find_outpost_cell(main, keep) -> Vector2i:
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
                        if not main.world.is_buildable(cell) or main.world.occupied.has(cell):
                            valid = false
                            break
                        cells.append(cell)
                    if not valid:
                        break
                if valid and not main.nav.path_adjacent(main.player.position, cells).is_empty():
                    return anchor
    return Vector2i(-1, -1)


func saved_raider_for(enemies: Array) -> Dictionary:
    for enemy_state in enemies:
        if enemy_state is Dictionary and bool(enemy_state.get("supply_raid", false)):
            return enemy_state
    return {}


func _road_cell_passable(main, cell: Vector2i) -> bool:
    if not main.world.is_buildable(cell):
        return false
    var occupant = main.world.occupied.get(cell)
    return occupant == null or (is_instance_valid(occupant) and occupant.is_in_group("roads"))


func find_road_path(main, keep, depot) -> Array[Vector2i]:
    var directions: Array[Vector2i] = [
        Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
    ]
    var queue: Array[Vector2i] = []
    var parents: Dictionary = {}
    for keep_cell in keep.cells():
        for direction in directions:
            var start: Vector2i = keep_cell + direction
            if _road_cell_passable(main, start) and not parents.has(start):
                parents[start] = Vector2i(-1, -1)
                queue.append(start)
    var destination_cells: Array[Vector2i] = depot.cells()
    var cursor := 0
    var endpoint := Vector2i(-1, -1)
    while cursor < queue.size():
        var current: Vector2i = queue[cursor]
        cursor += 1
        for direction in directions:
            if destination_cells.has(current + direction):
                endpoint = current
                break
        if endpoint.x >= 0:
            break
        for direction in directions:
            var next: Vector2i = current + direction
            if parents.has(next) or not _road_cell_passable(main, next):
                continue
            parents[next] = current
            queue.append(next)
    if endpoint.x < 0:
        return []
    var path: Array[Vector2i] = []
    var current := endpoint
    while current.x >= 0:
        path.append(current)
        current = parents[current]
    path.reverse()
    return path


func _initialize() -> void:
    var config = root.get_node("WorldConfig")
    var clock = root.get_node("GameClock")
    var save_system = root.get_node("SaveSystem")
    var events = root.get_node("Events")
    var tech = root.get_node("Tech")
    config.apply_profile("frontier")
    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(10)
    clock.set_process(false)
    tech.set_process(false)
    main.supply.set_process(false)
    main.spawner.set_process(false)
    main.spawner.set_physics_process(false)
    main.village.set_process(false)

    var keep = null
    for building in get_nodes_in_group("buildings"):
        if String(building.id) == "keep":
            keep = building
            break
    require(keep != null, "Frontier campaign must provide a Keep")

    var outpost_cell := find_outpost_cell(main, keep)
    require(outpost_cell.x >= 0, "Test must find a walkable Outpost location")
    var outpost = main.build.place_raw("outpost", outpost_cell)
    await ticks(4)
    main.nav.rebuild()
    main.supply.rebuild()
    require(not main.supply.is_depot_connected(outpost),
        "A remote Outpost with no road connection must begin isolated")
    require(outpost.store_resource("food", 2) and outpost.store_resource("wood", 12),
        "The isolated Outpost must hold local stock for raid tests")

    main.territory.rebuild()
    main.territory.enemy_claimed_cells[outpost.cell] = true
    for radius in range(4, 10):
        for y in range(-radius, radius + 1):
            for x in range(-radius, radius + 1):
                if maxi(absi(x), absi(y)) != radius:
                    continue
                var contested_cell: Vector2i = outpost.cell + Vector2i(x, y)
                if main.world.is_buildable(contested_cell):
                    main.territory.enemy_claimed_cells[contested_cell] = true
    main.territory._dirty = false
    require(main.territory.owner_at(outpost.cell) == "contested",
        "The Outpost must be in a genuinely contested supply area")

    var warnings: Array[String] = []
    var warning_hook := func(title: String, _detail: String) -> void:
        warnings.append(title)
    events.event_triggered.connect(warning_hook)

    main.supply.advance_supply_pressure(30.0)
    var warning_state: Dictionary = main.supply.depot_pressure_state(outpost)
    require(warning_state["status"] == "vulnerable" and warnings.has("JALUR LOGISTIK TERANCAM"),
        "Thirty seconds of isolation in contested territory must produce a visible warning before a raid")
    require(get_nodes_in_group("supply_raiders").is_empty(),
        "No raider may spawn before the full warning window elapses")

    main.supply.advance_supply_pressure(30.0)
    var raiders := get_nodes_in_group("supply_raiders")
    require(raiders.size() == 1,
        "After the 60-second contested isolation window, one targeted saboteur must be dispatched")
    var raider = raiders[0]
    require(raider.is_supply_raider and raider.raid_target_cell == outpost_cell,
        "The saboteur must retain an explicit target depot rather than follow the Keep flow field")
    require(raider.raid_nav == main.nav,
        "The saboteur must use the navigation grid to path toward the depot")

    var hud = get_first_node_in_group("hud")
    require(hud != null and hud._outpost_list != null,
        "The depot panel must expose pressure warnings")
    hud._refresh_outpost_panel()
    var threat_text_found := false
    for row in hud._outpost_list.get_children():
        for details in row.get_children():
            if details is VBoxContainer:
                for label in details.get_children():
                    if label is Label and ("DIGEMPUR" in label.text or "ANCAMAN RAID" in label.text):
                        threat_text_found = true
    require(threat_text_found,
        "JOBS → POS must identify a vulnerable or actively raided depot")

    main.player.position = Vector2(-1000, -1000)
    raider.position = outpost.position + Vector2(0, -18)
    raider._atk_cd = 0.0
    raider._tick_supply_raid(0.1)
    require(raider._pending == outpost,
        "The saboteur must attack its marked depot when it reaches attack range")
    raider._resolve_pending(0.5)
    var hp_after_first_hit: int = outpost.hp
    require(hp_after_first_hit < outpost.max_hp and outpost.stockpile_amount("food") == 2,
        "The first attack must damage the depot without prematurely stealing stock")
    raider._atk_cd = 0.0
    raider._tick_supply_raid(0.1)
    raider._resolve_pending(0.5)
    require(outpost.stockpile_amount("food") == 1,
        "Every second successful raid hit must deterministically steal one unit in fixed resource priority")
    require(outpost.hp < hp_after_first_hit,
        "Each successful saboteur strike must also damage depot structure integrity")

    raider.take_damage(999)
    await ticks(1)
    require(get_nodes_in_group("supply_raiders").is_empty(),
        "Killing the first saboteur must clear the active raid slot")
    main.supply.advance_supply_pressure(149.0)
    require(get_nodes_in_group("supply_raiders").is_empty(),
        "A second saboteur must not spawn before the full 150-second repeat interval")
    main.supply.advance_supply_pressure(1.0)
    var second_wave := get_nodes_in_group("supply_raiders")
    require(second_wave.size() == 1 and second_wave[0].raid_target_cell == outpost_cell,
        "A second targeted saboteur may spawn at 210 seconds, with no unbounded escalation")
    require(main.supply.depot_pressure_state(outpost)["status"] == "raiding",
        "The depot panel state must remain accurate for the repeat wave")

    var snapshot: Dictionary = save_system.collect(main)
    require(snapshot["version"] == 17,
        "Supply pressure and Hunter state must use save schema v17")
    require(snapshot["supply"]["pressure"].size() == 1,
        "The isolated Outpost pressure timer must be persisted")
    var saved_raider := saved_raider_for(snapshot["enemies"])
    require(not saved_raider.is_empty()
        and saved_raider["raid_target"] == {"cx": outpost_cell.x, "cy": outpost_cell.y},
        "An active targeted saboteur must persist its target cell and raid progress")
    require(save_system._valid_save(snapshot),
        "A valid snapshot with active supply pressure and a targeted raider must pass validation")

    var legacy_v13: Dictionary = snapshot.duplicate(true)
    legacy_v13["version"] = 13
    legacy_v13["quota"].erase("hunter")
    legacy_v13["job_priority"].erase("hunter")
    legacy_v13["quota"].erase("scout")
    legacy_v13["job_priority"].erase("scout")
    legacy_v13["quota"].erase("healer")
    legacy_v13["job_priority"].erase("healer")
    legacy_v13["quota"].erase("blacksmith")
    legacy_v13["job_priority"].erase("blacksmith")
    for saved_villager in legacy_v13["villagers"]:
        saved_villager.erase("weapon_equipped")
        saved_villager.erase("armor_equipped")
        if String(saved_villager.get("occupation", "")) == "scout":
            saved_villager["occupation"] = ""
            saved_villager["job"] = ""
        if String(saved_villager.get("occupation", "")) in ["hunter", "scout", "healer", "blacksmith"]:
            saved_villager["occupation"] = ""
            saved_villager["job"] = ""
        elif String(saved_villager.get("job", "")) in ["hunter", "scout", "healer", "blacksmith"]:
            saved_villager["job"] = ""
    for legacy_building_index in range(legacy_v13["buildings"].size() - 1, -1, -1):
        if String(legacy_v13["buildings"][legacy_building_index].get("id", "")) in ["hunting_lodge", "scout_post", "infirmary", "forge"]:
            legacy_v13["buildings"].remove_at(legacy_building_index)
    var legacy_resources: Array = []
    for resource in legacy_v13["resources"]:
        if String(resource.get("kind", "")) != "food":
            legacy_resources.append(resource)
    legacy_v13["resources"] = legacy_resources
    legacy_v13["supply"].erase("pressure")
    for enemy_state in legacy_v13["enemies"]:
        if bool(enemy_state.get("supply_raid", false)):
            enemy_state.erase("supply_raid")
            enemy_state.erase("raid_target")
            enemy_state.erase("raid_hits")
    require(save_system._valid_save(legacy_v13),
        "Previous v13 saves without pressure records or raider fields must remain loadable")

    var invalid_pressure: Dictionary = snapshot.duplicate(true)
    invalid_pressure["supply"]["pressure"][0]["cx"] = 999
    require(not save_system._valid_save(invalid_pressure),
        "Save validation must reject out-of-bounds pressure records")
    var invalid_target: Dictionary = snapshot.duplicate(true)
    var invalid_enemy := saved_raider_for(invalid_target["enemies"])
    invalid_enemy["raid_target"]["cx"] = 999
    require(not save_system._valid_save(invalid_target),
        "Save validation must reject a raider whose depot target is outside the map")

    require(save_system.save_current(true),
        "A campaign under active supply pressure must save")
    require(save_system.request_load(),
        "A campaign with an active targeted saboteur must reload")
    await ticks(12)
    var restored_main = get_first_node_in_group("main")
    require(restored_main != null,
        "Loading must recreate the Frontier campaign")
    var restored_outpost = null
    for depot in get_nodes_in_group("depots"):
        if depot.cell == outpost_cell:
            restored_outpost = depot
            break
    require(restored_outpost != null,
        "The raided Outpost must survive save/load with its remaining stock and damage")
    var restored_raiders := get_nodes_in_group("supply_raiders")
    require(restored_raiders.size() == 1
        and restored_raiders[0].raid_target_cell == outpost_cell,
        "Save/load must restore the same saboteur target and raid state")

    restored_main.supply.set_process(false)
    var restored_keep = null
    for building in get_nodes_in_group("buildings"):
        if String(building.id) == "keep":
            restored_keep = building
            break
    require(restored_keep != null, "Reload must retain the Keep for road reconnection")
    var road_path := find_road_path(restored_main, restored_keep, restored_outpost)
    require(not road_path.is_empty(), "A cardinal, buildable road route must exist between Keep and Outpost")
    for road_cell in road_path:
        if not restored_main.world.occupied.has(road_cell):
            restored_main.build.place_raw("road", road_cell)
    restored_main.supply.rebuild()
    require(restored_main.supply.is_depot_connected(restored_outpost),
        "The actual road graph must reconnect the remote Outpost to Keep")
    restored_main.supply.advance_supply_pressure(1.0)
    require(restored_main.supply.depot_pressure_state(restored_outpost)["status"] == "connected",
        "Reconnecting the depot to Keep must clear its vulnerability state")
    require(restored_raiders[0].is_queued_for_deletion()
        or not restored_raiders[0].is_in_group("supply_raiders"),
        "Restoring the road connection must recall the active saboteur")

    events.event_triggered.disconnect(warning_hook)
    print("PASS: contested isolation warning, targeted saboteur path/attack, deterministic depot stock attrition, HUD status, v17 persistence, v13 legacy compatibility and recovery by reconnecting roads")
    quit(0)
