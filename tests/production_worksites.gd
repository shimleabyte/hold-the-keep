extends SceneTree
## Phase 05: specialist resource workplaces and legacy fallback behavior.

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


func _initialize() -> void:
    var config = root.get_node("WorldConfig")
    var tile_size := int(config.tile_size)
    var inventory = root.get_node("Inventory")
    var save_system = root.get_node("SaveSystem")
    config.apply_profile("classic")
    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(8)
    root.get_node("GameClock").set_process(false)
    main.village.set_process(false)

    for existing in main.village.villagers():
        existing.leave()

    var keep = null
    for depot in get_nodes_in_group("depots"):
        if depot.id == "keep":
            keep = depot
            break
    assert(keep != null, "Classic campaign must retain its Keep depot")

    inventory.items = {"wood": 500, "stone": 500, "food": 500, "iron": 0}
    var camp_cell := find_build_site(main, keep.cell, Vector2i(3, 2))
    assert(camp_cell.x >= 0, "A reachable Lumber Camp footprint must exist")
    var camp = main.build.place_raw("lumber_camp", camp_cell)
    await ticks(2)  # Let navigation rebuild around the new footprint before choosing the next site.
    var quarry_cell := find_build_site(main, keep.cell, Vector2i(3, 2))
    assert(quarry_cell.x >= 0, "A reachable Quarry footprint must exist")
    var quarry = main.build.place_raw("quarry", quarry_cell)
    await ticks(3)

    assert(camp.free_slots("woodcutter") == 2, "Lumber Camp must expose two woodcutter slots")
    assert(camp.free_slots("miner") == 0, "Lumber Camp must not accept miners")
    assert(quarry.free_slots("miner") == 2, "Quarry must expose two miner slots")
    assert(quarry.free_slots("woodcutter") == 0, "Quarry must not accept woodcutters")

    var woodcutter_a = main.village.spawn_villager(camp.position + Vector2(0, 24))
    var woodcutter_b = main.village.spawn_villager(camp.position + Vector2(8, 24))
    assert(woodcutter_a.set_job("woodcutter") and woodcutter_b.set_job("woodcutter"),
        "Woodcutters must remain valid labor occupations")
    woodcutter_a._find_work()
    woodcutter_b._find_work()
    assert(woodcutter_a.workplace == camp and woodcutter_b.workplace == camp,
        "Woodcutters must claim the Lumber Camp instead of a generic depot")
    assert(camp.free_slots("woodcutter") == 0,
        "Lumber Camp workplace capacity must be enforced")

    var overflow_woodcutter = main.village.spawn_villager(camp.position + Vector2(12, 24))
    assert(overflow_woodcutter.set_job("woodcutter"),
        "Classic woodcutter role assignment must remain available")
    overflow_woodcutter._find_work()
    assert(not overflow_woodcutter.has_valid_workplace(),
        "A third woodcutter must not overbook the two-slot Lumber Camp")
    assert(overflow_woodcutter.target == null and overflow_woodcutter.state == overflow_woodcutter.State.IDLE,
        "Workers must not bypass full specialized workplace capacity via the old depot radius")

    var miner = main.village.spawn_villager(quarry.position + Vector2(0, 24))
    assert(miner.set_job("miner"), "Miner role assignment must remain available")
    miner._find_work()
    assert(miner.workplace == quarry, "Miners must claim the Quarry worksite")
    assert(quarry.free_slots("miner") == 1, "Quarry must track occupied miner slots")

    var radius_probe := Node2D.new()
    main.world.entities.add_child(radius_probe)
    var away_from_keep: Vector2 = (camp.position - keep.position).normalized()
    if away_from_keep == Vector2.ZERO:
        away_from_keep = Vector2.RIGHT
    radius_probe.position = camp.position + away_from_keep * tile_size * 17.0
    assert(woodcutter_a._is_in_workplace_radius(radius_probe),
        "Lumber Camp work radius must include resources 17 tiles from its center")
    assert(not woodcutter_a._is_in_work_radius(radius_probe),
        "The specialty work radius must be distinct from the Keep/depot fallback radius")
    radius_probe.queue_free()

    var quarry_probe := Node2D.new()
    main.world.entities.add_child(quarry_probe)
    quarry_probe.position = quarry.position + Vector2(tile_size * 15.0, 0)
    assert(miner._is_in_workplace_radius(quarry_probe),
        "Quarry work radius must include resources 15 tiles from its center")
    quarry_probe.queue_free()

    woodcutter_a.leave()
    assert(camp.free_slots("woodcutter") == 1,
        "A departing worker must release its workplace slot")
    woodcutter_b._find_work()
    assert(woodcutter_b.workplace == camp,
        "Remaining woodcutters must retain their workplace after another worker leaves")

    var snapshot: Dictionary = save_system.collect(main)
    assert(snapshot["version"] == 11, "Phase 07 campaign state must use save format v11")
    var saved_camp := false
    var saved_quarry := false
    for saved_building in snapshot["buildings"]:
        saved_camp = saved_camp or String(saved_building["id"]) == "lumber_camp"
        saved_quarry = saved_quarry or String(saved_building["id"]) == "quarry"
    assert(saved_camp and saved_quarry, "Both worksites must use the generic building save payload")
    assert(save_system._valid_save(snapshot),
        "Worksite buildings must pass v11 save validation")

    camp.demolish()
    assert(woodcutter_b.workplace == null,
        "Removing a worksite must release workers from its workplace")
    assert(woodcutter_b.state == woodcutter_b.State.IDLE,
        "Workers must return to idle when their worksite is removed")

    var legacy_worker = main.village.spawn_villager(keep.position + Vector2(0, 20))
    assert(legacy_worker.set_job("woodcutter"), "Legacy Classic woodcutters must still be assignable")
    legacy_worker._find_work()
    assert(legacy_worker.workplace == null,
        "Classic fallback must not require a Lumber Camp to assign resource workers")

    print("PASS: Lumber Camp/Quarry workplaces, slot limits, specialized radius, cleanup and v11 save compatibility")
    quit()
