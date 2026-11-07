extends SceneTree
## Regression: Frontier resource clearing must not strand gatherers beyond
## the Keep's classic work radius; Keep builders must reach initial frontier blueprints.

const TREE_SCRIPT := preload("res://scripts/entities/resource_tree.gd")
const ROCK_SCRIPT := preload("res://scripts/entities/rock.gd")
const IRON_ORE_SCRIPT := preload("res://scripts/entities/iron_ore.gd")

var world_config
var game_clock


func ticks(count: int) -> void:
    for _index in range(count):
        await physics_frame


func _find_reachable_cell(main: Node, start_position: Vector2, distance_origin: Vector2,
        min_radius: float, max_radius: float, reserved: Dictionary) -> Vector2i:
    var start: Vector2i = main.nav.cell_of(start_position)
    var reachable: Dictionary = main.nav.reachable_cells(start)
    var best := Vector2i(-1, -1)
    var best_distance := INF
    for value in reachable:
        var cell: Vector2i = value
        if reserved.has(cell) or not main.world.is_buildable(cell) or main.world.occupied.has(cell):
            continue
        var foot := Vector2(
            float(cell.x * world_config.tile_size) + world_config.tile_size / 2.0,
            float((cell.y + 1) * world_config.tile_size)
        )
        var distance := distance_origin.distance_to(foot) / float(world_config.tile_size)
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
        float(cell.x * world_config.tile_size) + world_config.tile_size / 2.0,
        float((cell.y + 1) * world_config.tile_size)
    )
    main.world.entities.add_child(resource)
    main.world.occupied[cell] = resource
    main.nav.rebuild()
    return resource


func _run_profile(profile_id: String) -> void:
    assert(world_config.apply_profile(profile_id), "Profile must be selectable: " + profile_id)
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(8)
    game_clock.set_process(false)
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
        world_config.safe_radius + 7.0,
        float(world_config.map_size) * 0.15
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

    var tree_hp_before := int(tree.export_state().get("hp", 0))
    woodcutter.state = woodcutter.State.WORKING
    woodcutter._tick_working(woodcutter._hit_interval() * 0.5 + 0.01)
    assert(woodcutter.carry == 1 and woodcutter.carry_kind == "wood",
        profile_id + " extracted resource behavior must transfer each wood hit into worker cargo")
    assert(int(tree.export_state().get("hp", 0)) == tree_hp_before - 1,
        profile_id + " extracted resource behavior must apply exactly one synchronized tree hit")

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

    var rock_hp_before := int(rock.export_state().get("hp", 0))
    miner.state = miner.State.WORKING
    miner._tick_working(miner._hit_interval() * 0.5 + 0.01)
    assert(miner.carry == 1 and miner.carry_kind == "stone",
        profile_id + " extracted resource behavior must transfer each stone hit into worker cargo")
    assert(int(rock.export_state().get("hp", 0)) == rock_hp_before - 1,
        profile_id + " extracted resource behavior must apply exactly one synchronized rock hit")

    # Iron selection must use actual worker access and live connected stock, not
    # the existence of any ore node anywhere on the map.
    var saved_tech_flags: Dictionary = Tech._flags.duplicate(true)
    var saved_inventory: Dictionary = Inventory.items.duplicate(true)
    Tech._flags["iron_mining"] = true
    Inventory.items["iron"] = 0
    Inventory.items["stone"] = 10

    var remote_iron = IRON_ORE_SCRIPT.new()
    remote_iron.position = miner.position + Vector2(10000.0, 0.0)
    main.world.entities.add_child(remote_iron)
    await ticks(1)
    assert(miner._resource_work_behavior._mine_kind() == "stone",
        profile_id + " miner must not choose an inaccessible iron vein outside its work area")

    var iron_cell := _find_reachable_cell(
        main, worker_origin, keep.position, clearing_radius + 0.5, gather_radius - 0.5, reserved
    )
    assert(iron_cell.x >= 0, profile_id + " must expose a reachable local iron test cell")
    reserved[iron_cell] = true
    var local_iron = _spawn_resource(main, IRON_ORE_SCRIPT, iron_cell)
    await ticks(1)
    assert(miner._resource_work_behavior._mine_kind() == "iron",
        profile_id + " miner must prefer a locally available iron vein when iron stock is low")

    local_iron.worker = woodcutter
    assert(miner._resource_work_behavior._mine_kind() == "stone",
        profile_id + " miner must ignore a local iron vein already reserved by another worker")
    local_iron.worker = null

    var storage_cell: Vector2i = keep.cell + Vector2i(3, 0)
    var storage = main.build.place_raw("storage", storage_cell)
    assert(storage != null, profile_id + " must create the connected depot stock fixture")
    await ticks(2)
    main.supply.rebuild()
    assert(main.supply.is_depot_connected(storage),
        profile_id + " storage touching the Keep must be connected to the supply network")
    assert(storage.store_resource("iron", 8),
        profile_id + " connected storage must accept the local iron stock fixture")
    assert(miner._resource_work_behavior._mine_kind() == "stone",
        profile_id + " miner must count usable connected depot iron when choosing what to mine")

    assert(storage.apply_sabotage(5.0),
        profile_id + " storage fixture must accept sabotage")
    assert(miner._resource_work_behavior._mine_kind() == "iron",
        profile_id + " sabotaged depot stock must not suppress local iron production")

    Tech._flags = saved_tech_flags
    Inventory.items = saved_inventory

    # Builders must be dispatched by actual path reachability, not a circular
    # workplace radius. Keep's Frontier claim edge is 15 tiles (+2 tolerance),
    # so this fixture deliberately places the blueprint beyond that limit.
    var builder = main.village.spawn_villager(worker_origin + Vector2(-5.0, 0.0))
    assert(builder.set_job("builder"), "Builder must claim a Keep workplace in " + profile_id)
    var site_cell := _find_reachable_cell(main, builder.position, keep.position, 18.5, 20.5, reserved)
    assert(site_cell.x >= 0, profile_id + " must expose a reachable construction task beyond the Keep claim radius")
    var site = main.build.create_construction_site("wall", site_cell, keep.cell)
    main.nav.rebuild()
    assert(keep.position.distance_to(site.position) > 14.0 * world_config.tile_size,
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
    for barrier_y in range(maxi(1, route_start.y - 10), mini(world_config.map_size - 1, gap_y + 11)):
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

    print("PASS: Frontier worker dispatch — " + profile_id)
    main.queue_free()
    await ticks(2)


func _initialize() -> void:
    world_config = root.get_node("WorldConfig")
    game_clock = root.get_node("GameClock")
    await process_frame
    await _run_profile("frontier")
    await _run_profile("frontier_expedition")
    print("PASS: Frontier and Frontier Expedition gatherer, miner, builder dispatch and navigation regression")
    quit(0)
