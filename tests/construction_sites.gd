extends SceneTree
## Phase 05.2a: Builder-driven construction, refunds and v15 persistence.
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

    # Placement/removal signals from one construction transition must be coalesced.
    var assignment_passes_before: int = main.village._assignment_pass_count
    main.village.set_process(true)
    main.village._on_workplace_changed("house", Vector2i.ZERO)
    main.village._on_workplace_changed("house", Vector2i.ZERO)
    await ticks(6)
    main.village.set_process(false)
    assert(main.village._assignment_pass_count == assignment_passes_before + 1,
        "Multiple building notifications in one frame must cause one Village assignment pass")
    inventory.items = {"wood": 500, "stone": 500, "food": 500, "iron": 0}
    var keep = null
    for depot in get_nodes_in_group("depots"):
        if depot.id == "keep":
            keep = depot
            break
    assert(keep != null, "A Keep must exist as the starting construction depot")
    var house_cell := find_house_cell(main, keep.cell)
    assert(house_cell.x >= 0, "The test must find a valid house footprint inside player build range")
    var wood_before: int = inventory.get_amount("wood")
    assert(main.build.place("house", house_cell) == "", "A valid house order must be accepted")
    var site = main.world.occupied.get(house_cell)
    assert(site != null and site.is_in_group("construction_sites"),
        "Placing a building must create a construction site, not a finished building")

    # FlowField publishes only complete snapshots and spreads Dijkstra work over frames.
    var flow_version_before: int = main.flow.version
    assert(not main.flow._dirty and not main.flow._build_active,
        "The initial enemy flow field must finish before construction profiling")
    main.flow.rebuild_pops_per_frame = 1
    await ticks(2)
    assert(main.flow._build_active and main.flow.version == flow_version_before,
        "A construction event must not synchronously replace the published flow field")
    main.flow.rebuild_pops_per_frame = main.flow.DEFAULT_REBUILD_POPS_PER_FRAME
    var flow_wait_frames := 0
    while main.flow._dirty or main.flow._build_active:
        await ticks(1)
        flow_wait_frames += 1
        assert(flow_wait_frames < 100,
            "A bounded flow-field rebuild must eventually publish its completed snapshot")
    assert(main.flow.version == flow_version_before + 1,
        "One blueprint placement must publish exactly one refreshed flow field")
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
    assert(not main.flow._dirty and not main.flow._build_active,
        "Construction completion must settle its refreshed enemy flow field without a blocking rebuild")
    builder.set_physics_process(false)
    var second_cell := find_house_cell(main, keep.cell)
    assert(second_cell.x >= 0 and second_cell != house_cell,
        "A second valid footprint must exist for persistence and cancellation checks")
    assert(main.build.place("house", second_cell) == "", "A second house order must be accepted")
    var second_site = main.world.occupied.get(second_cell)
    assert(second_site != null and second_site.is_in_group("construction_sites"),
        "A second order must enter the construction queue as a funded blueprint")
    var third_cell := find_house_cell(main, keep.cell)
    assert(third_cell.x >= 0 and third_cell != second_cell,
        "A third valid footprint must exist to exercise queue reordering")
    assert(main.build.place("house", third_cell) == "", "A third house order must be accepted")
    var third_site = main.world.occupied.get(third_cell)
    var queue_before: Array = main.build.construction_queue()
    assert(queue_before.size() == 2 and queue_before[0] == second_site and queue_before[1] == third_site,
        "New blueprints must append to the explicit construction order")
    assert(main.build.move_construction_site(third_site, -1),
        "The player must be able to promote a later project")
    var reordered_queue: Array = main.build.construction_queue()
    assert(reordered_queue[0] == third_site and reordered_queue[1] == second_site,
        "Reordering must change the effective Builder project priority")
    assert(not main.build.move_construction_site(third_site, -1),
        "A project at the front cannot move further upward")
    builder._find_work()
    assert(builder.target == third_site,
        "Builder target selection must honor queue priority instead of choosing the nearest blueprint")
    builder._release()
    builder._mark_target_blocked(third_site, "TEST_BLOCKED")
    builder._find_work()
    assert(builder.target == second_site,
        "A blocked or unreachable queued blueprint must not prevent fallback to the next project")
    builder._release()
    builder._blocked_targets.clear()
    var hud = get_first_node_in_group("hud")
    assert(hud != null, "The game HUD must expose construction queue controls")
    hud._toggle_construction_queue()
    assert(hud._queue_panel.visible and hud._queue_list.get_child_count() == 2,
        "The queue panel must list every active blueprint")
    hud._toggle_construction_queue()
    second_site.work_required = 12.0
    second_site.work_done = 3.0
    third_site.work_required = 10.0
    third_site.work_done = 2.0
    var snapshot: Dictionary = save_system.collect(main)
    assert(snapshot.has("construction_sites") and snapshot["construction_sites"].size() == 2,
        "Save v13 must persist every unfinished blueprint in queue order")
    assert(save_system._valid_save(snapshot), "A partially completed construction site must pass save validation")
    var json_round_trip: Variant = JSON.parse_string(JSON.stringify(snapshot))
    assert(json_round_trip is Dictionary and save_system._valid_save(json_round_trip),
        "Queue order and construction state must remain valid after JSON serialization and parsing")
    var non_integer_queue_order: Dictionary = snapshot.duplicate(true)
    non_integer_queue_order["construction_sites"][0]["queue_order"] = 0.5
    assert(not save_system._valid_save(non_integer_queue_order),
        "Save validation must reject fractional queue positions")
    var legacy_queue_snapshot: Dictionary = snapshot.duplicate(true)
    for saved_site in legacy_queue_snapshot["construction_sites"]:
        saved_site.erase("queue_order")
    assert(save_system._valid_save(legacy_queue_snapshot),
        "Legacy v13 blueprints without an explicit queue order must remain valid")
    var duplicate_queue_order: Dictionary = snapshot.duplicate(true)
    duplicate_queue_order["construction_sites"][1]["queue_order"] = duplicate_queue_order["construction_sites"][0]["queue_order"]
    assert(not save_system._valid_save(duplicate_queue_order),
        "Save validation must reject duplicate construction queue positions")
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
    assert(restored_sites.size() == 2, "Loading a v15 save must restore all unfinished construction sites")
    var restored_site = null
    for candidate in restored_sites:
        if candidate.cell == second_cell:
            restored_site = candidate
    assert(restored_site != null and is_equal_approx(restored_site.work_done, 3.0)
        and is_equal_approx(restored_site.work_required, 12.0),
        "Construction progress, work requirement and footprint must survive save/load")
    var restored_queue: Array = reloaded.build.construction_queue()
    assert(restored_queue.size() == 2 and restored_queue[0].cell == third_cell
        and restored_queue[1].cell == second_cell,
        "Explicit project priority must survive v15 save/load")
    var expected_refund: int = int(restored_site.refundable_cost().get("wood", 0))
    var refund_before: int = inventory.get_amount("wood")
    assert(reloaded.build.demolish_at(second_cell), "Right-click demolition must cancel a blueprint")
    assert(inventory.get_amount("wood") == refund_before + expected_refund,
        "Cancellation must refund only the unconsumed portion to its original Keep source")
    assert(not reloaded.world.occupied.has(second_cell), "Cancelled blueprint footprints must be released")
    print("PASS: Builder construction, two-worker cap, funded blueprints, proportional cancellation and v13 reload")
    quit()
