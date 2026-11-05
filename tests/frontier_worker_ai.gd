extends SceneTree
## Regression: Frontier resource clearing must not strand gatherers beyond
## the Keep's classic work radius; Keep builders must reach initial frontier blueprints.

const TREE_SCRIPT := preload("res://scripts/entities/resource_tree.gd")
const ROCK_SCRIPT := preload("res://scripts/entities/rock.gd")
const IRON_ORE_SCRIPT := preload("res://scripts/entities/iron_ore.gd")


func ticks(count: int) -> void:
    for _index in range(count):
        await physics_frame


func _find_reachable_cell(main: Node, start_position: Vector2, distance_origin: Vector2,
        min_radius: float, max_radius: float, reserved: Dictionary) -> Vector2i:
    var start := main.nav.cell_of(start_position)
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
        var distance := distance_origin.distance_to(foot) / float(WorldConfig.tile_size)
        if distance <= min_radius or distance >= max_radius or distance >= best_distance:
            continue
        best = cell
        best_distance = distance
    return best


func _find_empty_box(main: Node, min_x: int, max_x: int, min_y: int, max_y: int) -> Vector2i:
    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            var cell := Vector2i(x, y)
            if main.world.is_buildable(cell) and not main.world.occupied.has(cell):
                return cell
    return Vector2i(-1, -1)


func _find_reachable_box(main: Node, origin: Vector2, min_x: int, max_x: int,
        min_y: int, max_y: int) -> Vector2i:
    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            var cell := Vector2i(x, y)
            if not main.world.is_buildable(cell) or main.world.occupied.has(cell):
                continue
            var target_cells: Array[Vector2i] = [cell]
            if not main.nav.path_adjacent(origin, target_cells).is_empty():
                return cell
    return Vector2i(-1, -1)


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
        main, worker_origin, keep.position, clearing_radius + 0.5, gather_radius - 0.5, reserved
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
        main, worker_origin, keep.position, clearing_radius + 0.5, gather_radius - 0.5, reserved
    )
    assert(stone_cell.x >= 0, profile_id + " must have a second reachable gathering tile")
    reserved[stone_cell] = true
    var rock = _spawn_resource(main, ROCK_SCRIPT, stone_cell)

    var miner = main.village.spawn_villager(worker_origin + Vector2(5.0, 0.0))
    assert(miner.set_job("miner"), "Miner must be assignable in " + profile_id)
    miner._find_work()
    assert(miner.target == rock and not miner._path.is_empty(),
        profile_id + " miner must acquire and path to stone beyond 14 tiles")
    var initial_miner_diagnostics: Dictionary = miner.worker_ai_diagnostics()
    assert(String(initial_miner_diagnostics.get("desired_resource", "")) == "stone",
        profile_id + " miner diagnostics must expose its current resource decision")

    # Mining policy must use the connected economy and the miner's own work area.
    var previous_inventory: Dictionary = Inventory.items.duplicate(true)
    var previous_tech: Dictionary = Tech.export_state()
    Tech.import_state({"done": ["iron_mining"], "current": "", "progress": 0.0})
    for existing_ore in get_nodes_in_group("harvestable"):
        if String(existing_ore.yield_kind) == "iron":
            existing_ore.remove_from_group("harvestable")

    var stockpile_cell: Vector2i = keep.cell + Vector2i(3, 0)
    var stockpile = main.build.place_raw("storage", stockpile_cell)
    assert(stockpile != null, profile_id + " must create a connected storage for resource-demand coverage")
    await ticks(2)
    main.supply.rebuild()
    assert(main.supply.is_depot_connected(stockpile),
        profile_id + " test storage must be connected to the Keep")
    Inventory.items["stone"] = 0
    Inventory.items["iron"] = 0
    assert(stockpile.store_resource("stone", 40),
        profile_id + " connected storage must accept the stone reserve")

    var remote_iron_cell := _find_reachable_cell(
        main, worker_origin, keep.position, gather_radius + 1.0, gather_radius + 14.0, reserved
    )
    assert(remote_iron_cell.x >= 0, profile_id + " must expose reachable iron outside the miner's work radius")
    reserved[remote_iron_cell] = true
    var remote_ore = _spawn_resource(main, IRON_ORE_SCRIPT, remote_iron_cell)
    assert(remote_ore.is_available(miner), profile_id + " remote iron must be unlocked and available")
    assert(miner._resource_stock_amount("stone") == 40,
        profile_id + " miner must include connected local depot stock in resource totals")
    assert(miner._mine_kind() == "stone",
        profile_id + " remote iron must not pull a miner away from stone inside its actual work area")

    miner._release()
    rock.remove_from_group("harvestable")
    miner._find_work()
    var idle_miner_diagnostics: Dictionary = miner.worker_ai_diagnostics()
    assert(miner.target == null
        and String(idle_miner_diagnostics.get("status", "")) == "NO_RESOURCE_IN_WORK_AREA"
        and String(idle_miner_diagnostics.get("desired_resource", "")) == "stone",
        profile_id + " miner diagnostics must explain when no desired resource exists in the assigned work area")
    rock.add_to_group("harvestable")

    var local_iron_cell := _find_reachable_cell(
        main, worker_origin, keep.position, clearing_radius + 0.5, gather_radius - 0.5, reserved
    )
    assert(local_iron_cell.x >= 0, profile_id + " must expose a local iron node cell")
    reserved[local_iron_cell] = true
    var local_ore = _spawn_resource(main, IRON_ORE_SCRIPT, local_iron_cell)
    assert(local_ore.is_available(miner), profile_id + " local iron must be available to the miner")
    assert(miner._mine_kind() == "iron",
        profile_id + " miner must prioritize local iron while the connected network has a stone surplus")
    miner._release()
    miner._find_work()
    var iron_diagnostics: Dictionary = miner.worker_ai_diagnostics()
    assert(miner.target == local_ore
        and String(iron_diagnostics.get("desired_resource", "")) == "iron"
        and int(iron_diagnostics.get("desired_resource_stock", -1)) == 0,
        profile_id + " miner must dispatch to local iron and expose the connected iron stock total")
    assert(stockpile.store_resource("iron", 25),
        profile_id + " connected storage must accept the iron reserve")
    assert(miner._mine_kind() == "stone",
        profile_id + " miner must return to stone once connected iron stock is no longer scarce")
    miner._release()
    miner._find_work()
    var stone_diagnostics: Dictionary = miner.worker_ai_diagnostics()
    assert(miner.target == rock
        and String(stone_diagnostics.get("desired_resource", "")) == "stone"
        and int(stone_diagnostics.get("desired_resource_stock", -1)) == 40,
        profile_id + " miner must return to stone and report the stockpile-aware resource decision")

    # The first frontier outpost can be placed at the edge of Keep territory.
    # Keep builders must be dispatched to that blueprint without extending
    # their ordinary building-repair radius.
    var builder = main.village.spawn_villager(worker_origin + Vector2(-5.0, 0.0))
    assert(builder.set_job("builder"), "Builder must claim a Keep workplace in " + profile_id)
    var site_cell := _find_reachable_cell(main, builder.position, keep.position, 14.5, 16.5, reserved)
    assert(site_cell.x >= 0, profile_id + " must expose a reachable initial-claim edge cell")
    var site = main.build.create_construction_site("wall", site_cell, keep.cell)
    main.nav.rebuild()
    assert(keep.position.distance_to(site.position) > 14.0 * WorldConfig.tile_size,
        "Builder fixture must sit outside the original Keep work radius")
    builder._find_work()
    assert(builder.target == site and not builder._path.is_empty(),
        profile_id + " Keep builder must acquire a blueprint at the starting frontier edge")

    # A nearer tree is reachable only through a long detour; the worker must
    # compare real A* costs and choose a farther, directly reachable tree.
    var route_worker = main.village.spawn_villager(worker_origin + Vector2(-3.0, 0.0))
    assert(route_worker.set_job("woodcutter"), "Route-scoring worker must be assignable")
    var route_start: Vector2i = main.nav.cell_of(route_worker.position)
    var barrier_x := route_start.x + 2
    var gap_y := -1
    for candidate_y in range(route_start.y + 5, route_start.y + 15):
        var gap_cell := Vector2i(barrier_x, candidate_y)
        var gap_has_clear_approach := true
        for offset_x in range(-1, 2):
            var approach := Vector2i(barrier_x + offset_x, candidate_y)
            if not main.world.is_buildable(approach) or main.world.occupied.has(approach):
                gap_has_clear_approach = false
                break
        if gap_has_clear_approach:
            gap_y = candidate_y
            break
    assert(gap_y >= 0, profile_id + " must expose a traversable route-test barrier gap")
    for barrier_y in range(maxi(1, route_start.y - 10), mini(WorldConfig.map_size - 1, gap_y + 11)):
        if barrier_y == gap_y:
            continue
        main.world._layer.set_cell(Vector2i(barrier_x, barrier_y), 0, Vector2i(2, 0))

    var blocked_cell := _find_empty_box(
        main, route_start.x - 4, route_start.x - 2,
        route_start.y - 1, route_start.y + 1
    )
    main.nav.rebuild()
    var detour_cell := _find_reachable_box(
        main, route_worker.position, route_start.x + 4, route_start.x + 7,
        route_start.y - 2, route_start.y + 2
    )
    var direct_cell := _find_reachable_box(
        main, route_worker.position, route_start.x - 2, route_start.x,
        gap_y + 1, gap_y + 4
    )
    assert(blocked_cell.x >= 0 and detour_cell.x >= 0 and direct_cell.x >= 0,
        profile_id + " must expose three free route-test resource cells")

    for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
        main.world._layer.set_cell(blocked_cell + direction, 0, Vector2i(2, 0))
    main.nav.rebuild()
    var blocked_tree = _spawn_resource(main, TREE_SCRIPT, blocked_cell)
    var detour_tree = _spawn_resource(main, TREE_SCRIPT, detour_cell)
    var direct_tree = _spawn_resource(main, TREE_SCRIPT, direct_cell)

    var detour_cells: Array[Vector2i] = [detour_cell]
    var direct_cells: Array[Vector2i] = [direct_cell]
    var detour_path: PackedVector2Array = main.nav.path_adjacent(route_worker.position, detour_cells)
    var direct_path: PackedVector2Array = main.nav.path_adjacent(route_worker.position, direct_cells)
    assert(detour_path.size() > direct_path.size() and not direct_path.is_empty(),
        profile_id + " fixture must make the geometrically nearer tree require a longer path")

    route_worker._find_work()
    assert(route_worker.target == direct_tree,
        profile_id + " worker must choose the target with the shorter reachable route, not the nearest straight-line target")
    assert(route_worker._is_target_blocked(blocked_tree),
        profile_id + " worker must remember an unreachable target during its retry cooldown")
    var route_diagnostics: Dictionary = route_worker.worker_ai_diagnostics()
    assert(String(route_diagnostics.get("status", "")) == "MOVING_TO_WORK"
        and int(route_diagnostics.get("temporarily_blocked_targets", 0)) >= 1
        and String(route_diagnostics.get("target", "")) == String(direct_tree.name),
        profile_id + " diagnostics must expose the selected target and failed-path recovery state")

    Tech.import_state(previous_tech)
    Inventory.items = previous_inventory

    print("PASS: Frontier worker dispatch — " + profile_id)
    main.queue_free()
    await ticks(2)


func _initialize() -> void:
    await process_frame
    await _run_profile("frontier")
    await _run_profile("frontier_expedition")
    print("PASS: Frontier and Frontier Expedition gatherer, miner, builder dispatch and navigation regression")
    quit(0)
