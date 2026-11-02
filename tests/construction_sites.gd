extends SceneTree
## Phase 05.2a: Builder-driven construction, refunds and v13 persistence.
func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame

func find_house_cell(main, origin: Vector2i) -> Vector2i:
    for radius in range(3, 10):
        for y in range(-radius, radius + 1):
            for x in range(-radius, radius + 1):
                if maxi(absi(x), absi(y)) != radius:
                    continue
                var anchor := origin + Vector2i(x, y)
                if main.build.check("house", anchor) == "":
                    return anchor
    return Vector2i(-1, -1)

func _initialize() -> void:
    var config = root.get_node("WorldConfig")
    var inventory = root.get_node("Inventory")
    var save_system = root.get_node("SaveSystem")
    config.apply_profile("classic")
    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(10)
    root.get_node("GameClock").set_process(false)
    main.village.set_process(false)
    main.village.quota["builder"] = 0
    inventory.items = {"wood": 500, "stone": 500, "food": 500, "iron": 0}
    var keep = null
    for depot in get_nodes_in_group("depots"):
        if depot.id == "keep":
            keep = depot
            break
    assert(keep != null, "A Keep must exist as the starting construction depot")
    var house_cell := find_house_cell(main, keep.cell)
    assert(house_cell.x >= 0, "The test must find a valid house footprint inside player build range")
    var wood_before := inventory.get_amount("wood")
    assert(main.build.place("house", house_cell) == "", "A valid house order must be accepted")
    var site = main.world.occupied.get(house_cell)
    assert(site != null and site.is_in_group("construction_sites"),
        "Placing a building must create a construction site, not a finished building")
    assert(inventory.get_amount("wood") == wood_before - 12,
        "The selected depot must be charged exactly once when the blueprint is placed")
    assert(not site.is_in_group("buildings") and site.free_slots() == 2,
        "A blueprint must not gain finished-building behavior and must allow at most two Builders")
    await ticks(3)
    main.village.quota["builder"] = 1
    var builder = main.village.spawn_villager(site.position + Vector2(0, 24))
    assert(builder.set_job("builder"), "Builder must claim a valid Keep workplace")
    builder._find_work()
    assert(builder.target == site and builder.state == builder.State.TO_WORK,
        "Builder must discover and claim the nearest reachable construction site")
    site.work_required = 1.0
    site.queue_redraw()
    await ticks(180)
    var completed = main.world.occupied.get(house_cell)
    assert(completed != null and completed.id == "house" and completed.is_in_group("buildings"),
        "A site must become a real building after an arrived Builder completes its work")
    assert(not completed.is_in_group("construction_sites") and builder.target == null,
        "Completion must remove blueprint state and release its Builder")
    builder.set_physics_process(false)
    var second_cell := find_house_cell(main, keep.cell)
    assert(second_cell.x >= 0 and second_cell != house_cell,
        "A second valid footprint must exist for persistence and cancellation checks")
    assert(main.build.place("house", second_cell) == "", "A second house order must be accepted")
    var second_site = main.world.occupied.get(second_cell)
    assert(second_site != null and second_site.is_in_group("construction_sites"),
        "A second order must enter the construction queue as a funded blueprint")
    second_site.work_required = 12.0
    second_site.work_done = 3.0
    var snapshot: Dictionary = save_system.collect(main)
    assert(snapshot.has("construction_sites") and snapshot["construction_sites"].size() == 1,
        "Save v13 must persist unfinished blueprint sites as additive state")
    assert(save_system._valid_save(snapshot), "A partially completed construction site must pass save validation")
    var invalid_progress: Dictionary = snapshot.duplicate(true)
    invalid_progress["construction_sites"][0]["work_done"] = -1.0
    assert(not save_system._valid_save(invalid_progress), "Save validation must reject negative construction progress")
    var invalid_overlap: Dictionary = snapshot.duplicate(true)
    invalid_overlap["construction_sites"][0]["cx"] = house_cell.x
    invalid_overlap["construction_sites"][0]["cy"] = house_cell.y
    assert(not save_system._valid_save(invalid_overlap), "Save validation must reject a blueprint overlapping a building")
    main.queue_free()
    await ticks(3)
    save_system.pending = snapshot
    var reloaded = load("res://scenes/main.tscn").instantiate()
    root.add_child(reloaded)
    current_scene = reloaded
    await ticks(12)
    var restored_sites := get_nodes_in_group("construction_sites")
    assert(restored_sites.size() == 1, "Loading a v13 save must restore unfinished construction sites")
    var restored_site = restored_sites[0]
    assert(restored_site.cell == second_cell and is_equal_approx(restored_site.work_done, 3.0)
        and is_equal_approx(restored_site.work_required, 12.0),
        "Construction progress, work requirement and footprint must survive save/load")
    var expected_refund: int = int(restored_site.refundable_cost().get("wood", 0))
    var refund_before := inventory.get_amount("wood")
    assert(reloaded.build.demolish_at(second_cell), "Right-click demolition must cancel a blueprint")
    assert(inventory.get_amount("wood") == refund_before + expected_refund,
        "Cancellation must refund only the unconsumed portion to its original Keep source")
    assert(not reloaded.world.occupied.has(second_cell), "Cancelled blueprint footprints must be released")
    print("PASS: Builder construction, two-worker cap, funded blueprints, proportional cancellation and v13 reload")
    quit()
