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

func assert_multi_cell_approach_fallback(main) -> void:
    var nav = main.nav
    nav.rebuild()

    # Sealed navigation fixture: a 3x3 target has twelve walkable perimeter
    # cells, but the four nearest approaches are isolated from the start.
    var target_origin := Vector2i(30, 30)
    var target_cells: Array[Vector2i] = []
    for y in 3:
        for x in 3:
            target_cells.append(target_origin + Vector2i(x, y))

    for y in range(26, 43):
        for x in range(20, 37):
            nav.astar.set_point_solid(Vector2i(x, y), true)

    var approach_cells: Array[Vector2i] = []
    for offset in 3:
        approach_cells.append(target_origin + Vector2i(-1, offset))
        approach_cells.append(target_origin + Vector2i(3, offset))
        approach_cells.append(target_origin + Vector2i(offset, -1))
        approach_cells.append(target_origin + Vector2i(offset, 3))
    for approach in approach_cells:
        nav.astar.set_point_solid(approach, false)

    var start_cell := Vector2i(22, 31)
    nav.astar.set_point_solid(start_cell, false)
    for y in range(start_cell.y, 40):
        nav.astar.set_point_solid(Vector2i(start_cell.x, y), false)
    for x in range(start_cell.x, 35):
        nav.astar.set_point_solid(Vector2i(x, 39), false)
    for y in range(31, 40):
        nav.astar.set_point_solid(Vector2i(34, y), false)

    approach_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
        var distance_a := Vector2(a - start_cell).length_squared()
        var distance_b := Vector2(b - start_cell).length_squared()
        if not is_equal_approx(distance_a, distance_b):
            return distance_a < distance_b
        if a.y != b.y:
            return a.y < b.y
        return a.x < b.x
    )
    for i in 4:
        assert(nav.astar.get_point_path(start_cell, approach_cells[i]).is_empty(),
            "The four closest approach cells must be unreachable in the regression fixture")

    var path: PackedVector2Array = nav.path_adjacent(nav.center_of(start_cell), target_cells)
    assert(not path.is_empty(),
        "A 3x3 target must remain reachable through a farther perimeter cell when the nearest four are blocked")
    var endpoint: Vector2i = nav.cell_of(path[path.size() - 1])
    assert(endpoint.x == target_origin.x + 3
        and endpoint.y >= target_origin.y and endpoint.y <= target_origin.y + 2,
        "Path selection must use the only connected right-side approach")

    nav.rebuild()


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
    var initial_flow_wait := 0
    while not main.flow.is_current():
        await ticks(1)
        initial_flow_wait += 1
        assert(initial_flow_wait < 600,
            "Initial enemy flow field must publish before construction profiling")
    assert_multi_cell_approach_fallback(main)
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
    assert(main.flow._dirty or main.flow._build_active,
        "A newly placed construction site must invalidate the published enemy flow field")

    # FlowField publishes only complete snapshots and spreads Dijkstra work over frames.
    var flow_version_before: int = main.flow.version
    main.flow.rebuild_pops_per_frame = main.flow.DEFAULT_REBUILD_POPS_PER_FRAME
    main.flow.rebuild_budget_usec = 1
    await ticks(2)
    assert(main.flow._build_active and main.flow.version == flow_version_before,
        "A tiny elapsed-time budget must keep the previous complete field published across frames")
    main.flow.rebuild_budget_usec = main.flow.DEFAULT_REBUILD_BUDGET_USEC
    var flow_wait_frames := 0
    while main.flow._dirty or main.flow._build_active:
        await ticks(1)
        flow_wait_frames += 1
        assert(flow_wait_frames < 600,
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
    var nav_version_before_completion: int = main.nav.version
    site.work_required = 1.0
    site.queue_redraw()
    await ticks(180)
    var completed = main.world.occupied.get(house_cell)
    assert(completed != null and completed.id == "house" and completed.is_in_group("buildings"),
        "A site must become a real building after an arrived Builder completes its work")
    assert(not completed.is_in_group("construction_sites") and builder.target == null,
        "Completion must remove blueprint state and release its Builder")
    var completion_flow_wait := 0
    while main.flow._dirty or main.flow._build_active:
        await ticks(1)
        completion_flow_wait += 1
        assert(completion_flow_wait < 600,
            "Construction completion must eventually publish its refreshed enemy flow field")
    assert(not main.flow._dirty and not main.flow._build_active,
        "Construction completion must settle its refreshed enemy flow field without a blocking rebuild")
    assert(main.nav.version == nav_version_before_completion,
        "Replacing a solid construction site with a solid building must not invalidate every villager route")
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
