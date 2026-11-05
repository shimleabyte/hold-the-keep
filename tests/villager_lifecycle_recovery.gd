extends SceneTree
## Regression: job reassignment, destroyed workplaces, depleted resources and night recall.


func ticks(count: int) -> void:
    for _index in range(count):
        await physics_frame


func find_build_site(main: Node, origin: Vector2i, footprint: Vector2i, start_position: Vector2 = Vector2.ZERO) -> Vector2i:
    var world_config = root.get_node("WorldConfig")
    var map_size: int = int(world_config.map_size)
    for radius in range(4, 18):
        for y in range(-radius, radius + 1):
            for x in range(-radius, radius + 1):
                if maxi(absi(x), absi(y)) != radius:
                    continue
                var anchor := origin + Vector2i(x, y)
                if anchor.x < 1 or anchor.y < 1:
                    continue
                if anchor.x + footprint.x >= map_size - 1 or anchor.y + footprint.y >= map_size - 1:
                    continue
                var clear := true
                for dy in footprint.y:
                    for dx in footprint.x:
                        var cell := anchor + Vector2i(dx, dy)
                        if not main.world.is_buildable(cell) or main.world.occupied.has(cell):
                            clear = false
                            break
                    if not clear:
                        break
                var target_cells: Array[Vector2i] = [anchor]
                var path_origin: Vector2 = start_position if start_position != Vector2.ZERO else main.player.position
                if clear and not main.nav.path_adjacent(path_origin, target_cells).is_empty():
                    return anchor
    return Vector2i(-1, -1)


func spawn_resource_near(main: Node, script: Script, worker, reserved: Dictionary) -> Node:
    var world_config = root.get_node("WorldConfig")
    var start: Vector2i = main.nav.cell_of(worker.position)
    var reachable: Dictionary = main.nav.reachable_cells(start)
    var candidates: Array[Dictionary] = []
    var radius: float = float(worker.workplace.data.get("work_radius", 12.0)) * float(world_config.tile_size)
    for value in reachable:
        var cell: Vector2i = value
        if reserved.has(cell) or not main.world.is_buildable(cell) or main.world.occupied.has(cell):
            continue
        var foot := Vector2(
            float(cell.x * world_config.tile_size) + float(world_config.tile_size) / 2.0,
            float((cell.y + 1) * world_config.tile_size)
        )
        var distance: float = worker.workplace.position.distance_to(foot)
        if distance > radius * 0.8 or distance < float(world_config.tile_size) * 2.0:
            continue
        candidates.append({"cell": cell, "distance": distance})
    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return float(a.distance) < float(b.distance)
    )
    if candidates.is_empty():
        return null
    var cell: Vector2i = candidates[0].cell
    reserved[cell] = true
    var resource = script.new()
    resource.position = Vector2(
        float(cell.x * world_config.tile_size) + float(world_config.tile_size) / 2.0,
        float((cell.y + 1) * world_config.tile_size)
    )
    main.world.entities.add_child(resource)
    main.world.occupied[cell] = resource
    main.nav.rebuild()
    return resource


func _initialize() -> void:
    var world_config = root.get_node("WorldConfig")
    var game_clock = root.get_node("GameClock")
    var events = root.get_node("Events")
    var RockScript: Script = load("res://scripts/entities/rock.gd")
    assert(world_config.apply_profile("classic"), "Classic profile must be selectable")
    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(8)
    game_clock.set_process(false)
    main.village.set_process(false)
    for existing in main.village.villagers():
        existing.leave()

    var keep = null
    for depot in get_nodes_in_group("depots"):
        if String(depot.id) == "keep":
            keep = depot
            break
    assert(keep != null, "Campaign must create its Keep")

    var camp_cell := find_build_site(main, keep.cell, Vector2i(3, 2))
    assert(camp_cell.x >= 0, "A reachable Lumber Camp site must exist")
    var camp = main.build.place_raw("lumber_camp", camp_cell)
    await ticks(2)

    var worker = main.village.spawn_villager(keep.position + Vector2(0, 24))
    assert(worker.set_job("woodcutter"), "Worker must accept the Woodcutter role")
    worker._find_work()
    assert(worker.workplace == camp and worker.workplace_job == "woodcutter",
        "Woodcutter must claim a Lumber Camp workplace slot")
    assert(camp.free_slots("woodcutter") == 1, "Claim must consume exactly one Lumber Camp slot")

    var quarry_cell_a := find_build_site(main, keep.cell, Vector2i(3, 2), worker.position)
    assert(quarry_cell_a.x >= 0, "A first Quarry must be reachable from the worker")
    var quarry_a = main.build.place_raw("quarry", quarry_cell_a)
    await ticks(2)

    var quarry_cell_b := find_build_site(main, keep.cell, Vector2i(3, 2), worker.position)
    assert(quarry_cell_b.x >= 0, "A second Quarry must be reachable from the worker")
    var quarry_b = main.build.place_raw("quarry", quarry_cell_b)
    await ticks(3)
    assert(quarry_a != quarry_b, "Lifecycle fixture must create two distinct Quarries")
    assert(quarry_a.free_slots("miner") > 0 and quarry_b.free_slots("miner") > 0,
        "Both Quarries must expose free Miner slots")

    # Keep the reassigned role stable when workplace destruction triggers quota reconciliation.
    main.village.quota["woodcutter"] = 0
    main.village.quota["miner"] = 1
    assert(worker.set_job("miner"), "Worker must be able to change to Miner")
    assert(worker.workplace == null and worker.target == null,
        "Changing jobs must release the previous workplace and resource claim")
    assert(camp.free_slots("woodcutter") == 2,
        "Changing jobs must return the old Lumber Camp slot")
    worker._find_work()
    assert(worker.workplace != null and worker.workplace.id == "quarry"
            and worker.workplace_job == "miner",
        "Miner must claim a Quarry rather than retaining the old workplace")

    var claimed_quarry = worker.workplace
    var recovery_quarry = quarry_a if claimed_quarry == quarry_b else quarry_b
    assert(is_instance_valid(recovery_quarry), "The second Quarry must survive the destruction fixture")
    var recovery_path: PackedVector2Array = main.nav.path_adjacent(worker.position, recovery_quarry.cells())
    assert(not recovery_path.is_empty(), "The surviving Quarry must have a route from the worker before destruction")
    claimed_quarry.take_damage(claimed_quarry.hp)
    assert(worker.workplace == null and worker.workplace_job.is_empty(),
        "Destroying a workplace must clear the worker's workplace reference")
    assert(worker.state == worker.State.IDLE,
        "A worker whose workplace is destroyed must leave its stale work state")
    await ticks(2)
    worker._find_work()
    if worker.workplace != recovery_quarry or worker.workplace_job != "miner":
        var debug_state: Dictionary = worker.worker_ai_diagnostics()
        var recovery_slots: int = int(recovery_quarry.free_slots("miner")) if is_instance_valid(recovery_quarry) else -1
        var recovery_path_after: PackedVector2Array = main.nav.path_adjacent(worker.position, recovery_quarry.cells()) if is_instance_valid(recovery_quarry) else PackedVector2Array()
        print("LIFECYCLE_RECOVERY_DEBUG ", {
            "job": worker.job,
            "state": String(worker.State.keys()[worker.state]),
            "status": worker.work_ai_status,
            "detail": worker.work_ai_detail,
            "workplace": String(worker.workplace.id) if worker.workplace != null and is_instance_valid(worker.workplace) else "null",
            "expected_quarry": String(recovery_quarry.id) if is_instance_valid(recovery_quarry) else "freed",
            "slots": recovery_slots,
            "path_points": recovery_path_after.size(),
            "nav_version": main.nav.version,
            "diagnostics": debug_state
        })
        quit(1)
        return

    var reserved: Dictionary = {}
    var depleted = spawn_resource_near(main, RockScript, worker, reserved)
    var alternate = spawn_resource_near(main, RockScript, worker, reserved)
    assert(depleted != null and alternate != null,
        "Quarry must have two reachable resource targets inside its work radius")
    worker._find_work()
    assert(worker.target != null and [depleted, alternate].has(worker.target),
        "Miner must acquire one of the reachable Quarry resources")
    var first_target = worker.target
    for _hit in range(4):
        first_target.hit()
    worker.state = worker.State.WORKING
    worker._tick_working(0.1)
    assert(worker.target == null and worker.state == worker.State.IDLE,
        "A depleted resource must release its worker claim and return it to idle")
    worker._find_work()
    assert(worker.target != null and worker.target != first_target,
        "Miner must select another available resource after depletion")

    var workplace_before_night = worker.workplace
    worker._begin_flee()
    assert(worker.target == null and worker.state == worker.State.FLEEING,
        "Night recall must cancel active work and begin the return-to-Keep transition")
    assert(worker.workplace == workplace_before_night and worker.has_valid_workplace(),
        "Night recall must preserve a valid specialist workplace assignment")

    var snapshot: Dictionary = root.get_node("SaveSystem").collect(main)
    assert(root.get_node("SaveSystem")._valid_save(snapshot),
        "Villager lifecycle transitions must leave a valid v17 save snapshot")

    print("PASS: villager job reassignment, workplace destruction, resource depletion, night recall and save validation")
    quit()
