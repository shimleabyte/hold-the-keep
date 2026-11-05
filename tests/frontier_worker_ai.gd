extends SceneTree
## Regression: Frontier resource clearing must not strand gatherers beyond
## the Keep's classic work radius; Keep builders must reach initial frontier blueprints.

const TREE_SCRIPT := preload("res://scripts/entities/resource_tree.gd")
const ROCK_SCRIPT := preload("res://scripts/entities/rock.gd")


func ticks(count: int) -> void:
    for _index in range(count):
        await physics_frame


func _find_reachable_cell(main: Node, origin: Vector2, min_radius: float,
        max_radius: float, reserved: Dictionary) -> Vector2i:
    var start := main.nav.cell_of(origin)
    var reachable: Dictionary = main.nav.reachable_cells(start)
    var best := Vector2i(-1, -1)
    var best_distance := INF
    for value in reachable:
        var cell: Vector2i = value
        if reserved.has(cell) or not main.world.is_buildable(cell) or main.world.occupied.has(cell):
            continue
        var foot := Vector2(
            float(cell.x * WorldConfig.tile_size) + WorldConfig.tile_size / 2.0,
            float((cell.y + 1) * WorldConfig.tile_size)
        )
        var distance := origin.distance_to(foot) / float(WorldConfig.tile_size)
        if distance <= min_radius or distance >= max_radius or distance >= best_distance:
            continue
        best = cell
        best_distance = distance
    return best


func _spawn_resource(main: Node, script: Script, cell: Vector2i) -> Node:
    var resource = script.new()
    resource.position = Vector2(
        float(cell.x * WorldConfig.tile_size) + WorldConfig.tile_size / 2.0,
        float((cell.y + 1) * WorldConfig.tile_size)
    )
    main.world.entities.add_child(resource)
    main.world.occupied[cell] = resource
    main.nav.rebuild()
    return resource


func _run_profile(profile_id: String) -> void:
    assert(WorldConfig.apply_profile(profile_id), "Profile must be selectable: " + profile_id)
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(8)
    GameClock.set_process(false)
    main.village.set_process(false)
    main.nav.rebuild()

    for job_name in main.village.quota:
        main.village.quota[job_name] = 0
    main.village.quota["woodcutter"] = 1
    main.village.quota["miner"] = 1
    main.village.quota["builder"] = 1

    var keep = null
    for building in get_nodes_in_group("buildings"):
        if String(building.id) == "keep":
            keep = building
            break
    assert(keep != null, profile_id + " must create the starting Keep")

    # Generated resource nodes remain physical blockers but are hidden from the
    # worker query so this test has a deterministic, isolated target.
    for existing in get_nodes_in_group("harvestable"):
        existing.remove_from_group("harvestable")

    var worker_origin: Vector2 = keep.position + Vector2(0.0, 24.0)
    var clearing_radius := maxf(
        WorldConfig.safe_radius + 7.0,
        float(WorldConfig.map_size) * 0.15
    )
    var gather_radius := clearing_radius + 4.0
    var reserved: Dictionary = {}

    var wood_cell := _find_reachable_cell(
        main, worker_origin, clearing_radius + 0.5, gather_radius - 0.5, reserved
    )
    assert(wood_cell.x >= 0, profile_id + " must have reachable terrain beyond the old Keep gather radius")
    reserved[wood_cell] = true
    var tree = _spawn_resource(main, TREE_SCRIPT, wood_cell)

    var woodcutter = main.village.spawn_villager(worker_origin)
    assert(woodcutter.set_job("woodcutter"), "Woodcutter must be assignable in " + profile_id)
    woodcutter._find_work()
    assert(woodcutter.target == tree and not woodcutter._path.is_empty(),
        profile_id + " woodcutter must acquire and path to a resource beyond 14 tiles")

    var stone_cell := _find_reachable_cell(
        main, worker_origin, clearing_radius + 0.5, gather_radius - 0.5, reserved
    )
    assert(stone_cell.x >= 0, profile_id + " must have a second reachable gathering tile")
    reserved[stone_cell] = true
    var rock = _spawn_resource(main, ROCK_SCRIPT, stone_cell)

    var miner = main.village.spawn_villager(worker_origin + Vector2(5.0, 0.0))
    assert(miner.set_job("miner"), "Miner must be assignable in " + profile_id)
    miner._find_work()
    assert(miner.target == rock and not miner._path.is_empty(),
        profile_id + " miner must acquire and path to stone beyond 14 tiles")

    # The first frontier outpost can be placed at the edge of Keep territory.
    # Keep builders must be dispatched to that blueprint without extending
    # their ordinary building-repair radius.
    var builder = main.village.spawn_villager(worker_origin + Vector2(-5.0, 0.0))
    assert(builder.set_job("builder"), "Builder must claim a Keep workplace in " + profile_id)
    var site_cell := _find_reachable_cell(main, builder.position, 14.5, 16.5, reserved)
    assert(site_cell.x >= 0, profile_id + " must expose a reachable initial-claim edge cell")
    var site = main.build.create_construction_site("wall", site_cell, keep.cell)
    main.nav.rebuild()
    assert(keep.position.distance_to(site.position) > 14.0 * WorldConfig.tile_size,
        "Builder fixture must sit outside the original Keep work radius")
    builder._find_work()
    assert(builder.target == site and not builder._path.is_empty(),
        profile_id + " Keep builder must acquire a blueprint at the starting frontier edge")

    print("PASS: Frontier worker dispatch — " + profile_id)
    main.queue_free()
    await ticks(2)


func _initialize() -> void:
    await process_frame
    await _run_profile("frontier")
    await _run_profile("frontier_expedition")
    print("PASS: Frontier and Frontier Expedition gatherer, miner, builder dispatch and navigation regression")
    quit(0)
