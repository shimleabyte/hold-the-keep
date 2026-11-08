extends SceneTree
## Real-window rendered acceptance for the rival physical workforce.
## This is intentionally launched without --headless under Xvfb + Mesa.

const OUTPUT_DIR := "res://build/diagnostics/rival-workforce-headed"
const STEP := 0.25
const WORKPLACES: Array[String] = ["lumber_camp", "farm", "quarry", "forge"]
const RESOURCES: Array[String] = ["wood", "stone", "iron", "food"]
const TREE_SCRIPT := preload("res://scripts/entities/resource_tree.gd")
const ROCK_SCRIPT := preload("res://scripts/entities/rock.gd")
const ORE_SCRIPT := preload("res://scripts/entities/iron_ore.gd")

var failed := false
var output_dir := ""


func check(condition: bool, message: String) -> void:
    if condition:
        print("RIVAL_HEADED_PASS ", message)
    else:
        failed = true
        push_error("RIVAL_HEADED_FAIL " + message)


func frames(count: int) -> void:
    for _i in count:
        await process_frame


func advance_civilization(civilization: Variant, seconds: float) -> void:
    var steps := ceili(maxf(0.0, seconds) / STEP)
    for i in steps:
        civilization.advance(STEP)
        if i % 4 == 3:
            await process_frame


func workers_for(civilization: Variant, workplace_id: String = "") -> Array[Node]:
    var result: Array[Node] = []
    for worker: Node in get_nodes_in_group("enemy_economic_workers"):
        if not is_instance_valid(worker) or worker.get("civilization") != civilization:
            continue
        if not workplace_id.is_empty() and String(worker.get("workplace_id")) != workplace_id:
            continue
        result.append(worker)
    return result


func seed_owner_region_resources(main: Node, keep: Node2D) -> Dictionary:
    var world: Node = main.get("world")
    var territory: Node = main.get("territory")
    var nav: Node = main.get("nav")
    territory.call("_ensure_current")
    var owner_region := String(keep.get("region_id"))
    var anchor: Vector2i = keep.get("cell")
    var cells: Array[Vector2i] = []

    for radius in range(16, 34):
        for y in range(-radius, radius + 1):
            for x in range(-radius, radius + 1):
                if maxi(absi(x), absi(y)) != radius:
                    continue
                var cell := anchor + Vector2i(x, y)
                if not WorldConfig.is_valid_cell(cell):
                    continue
                if not bool(world.call("is_buildable", cell)) or world.get("occupied").has(cell):
                    continue
                if String(world.call("region_id", cell)) != owner_region:
                    continue
                var owner := String(territory.call("owner_at", cell))
                if owner == "player" or owner == "contested":
                    continue
                var foot := Vector2(
                    (float(cell.x) + 0.5) * float(WorldConfig.tile_size),
                    (float(cell.y) + 1.0) * float(WorldConfig.tile_size)
                )
                if keep.global_position.distance_to(foot) <= 35.0 * float(WorldConfig.tile_size):
                    cells.append(cell)

    var cursor := 0
    var counts := {"wood": 0, "stone": 0, "iron": 0}
    for _i in 40:
        if cursor >= cells.size():
            break
        var node: Node2D = TREE_SCRIPT.new() as Node2D
        var cell: Vector2i = cells[cursor]
        cursor += 1
        node.position = Vector2(
            (float(cell.x) + 0.5) * float(WorldConfig.tile_size),
            (float(cell.y) + 1.0) * float(WorldConfig.tile_size)
        )
        world.call("_register_resource_node", node, cell)
        counts["wood"] = int(counts["wood"]) + 1

    for _i in 18:
        if cursor >= cells.size():
            break
        var node: Node2D = ROCK_SCRIPT.new() as Node2D
        var cell: Vector2i = cells[cursor]
        cursor += 1
        node.position = Vector2(
            (float(cell.x) + 0.5) * float(WorldConfig.tile_size),
            (float(cell.y) + 1.0) * float(WorldConfig.tile_size)
        )
        world.call("_register_resource_node", node, cell)
        counts["stone"] = int(counts["stone"]) + 1

    for _i in 12:
        if cursor >= cells.size():
            break
        var node: Node2D = ORE_SCRIPT.new() as Node2D
        var cell: Vector2i = cells[cursor]
        cursor += 1
        node.position = Vector2(
            (float(cell.x) + 0.5) * float(WorldConfig.tile_size),
            (float(cell.y) + 1.0) * float(WorldConfig.tile_size)
        )
        world.call("_register_resource_node", node, cell)
        counts["iron"] = int(counts["iron"]) + 1

    nav.call("rebuild")
    print("RIVAL_HEADED_FIXTURE ", JSON.stringify(counts), " owner_region=", owner_region)
    return counts


func all_workplaces_ready(civilization: Variant) -> bool:
    for id in ["lumber_camp", "farm", "quarry", "barracks", "tower", "forge", "storage"]:
        if not bool(civilization.call("_has_active_structure", id)):
            return false
    return int(civilization.get("technology_tier")) >= 1 \
        and civilization.get("construction").is_empty()


func log_workers(civilization: Variant, stage: String) -> void:
    for worker: Node in workers_for(civilization):
        print("RIVAL_HEADED_WORKER ", stage, " ", JSON.stringify(worker.call("debug_snapshot")))


func capture(main: Node, label: String, center: Vector2, zoom: float, file_name: String) -> void:
    var player: Node2D = main.get("player") as Node2D
    var camera: Camera2D = player.get("camera") as Camera2D
    check(camera != null, "Camera exists for capture " + label)
    if camera == null:
        return
    player.global_position = center
    camera.position = Vector2.ZERO
    camera.zoom = Vector2(zoom, zoom)
    camera.make_current()
    await process_frame
    await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    check(image != null and not image.is_empty(), "Non-empty headed window frame: " + label)
    if image == null or image.is_empty():
        return
    var path := output_dir.path_join(file_name)
    check(image.save_png(path) == OK, "Saved rendered image " + file_name)
    print("RIVAL_HEADED_CAPTURE ", label, " ", path)


func find_free_tree(main: Node, worker: Node2D) -> Node2D:
    var world: Node = main.get("world")
    var nav: Node = main.get("nav")
    var best: Node2D
    var best_distance := INF
    for cell_value in world.get("resource_nodes_by_cell").keys():
        var cell := Vector2i(cell_value)
        var node: Node2D = world.call("resource_node_at", cell) as Node2D
        if node == null or not is_instance_valid(node):
            continue
        if String(node.get("yield_kind")) != "wood" or int(node.get("_hp")) <= 0:
            continue
        if not bool(worker.call("_resource_cell_is_available", cell, node)):
            continue
        var path: PackedVector2Array = nav.call("path_adjacent", worker.global_position, [cell])
        if path.is_empty() or not bool(worker.call("_path_avoids_player_territory", path)):
            continue
        var distance := worker.global_position.distance_squared_to(node.global_position)
        if distance < best_distance:
            best_distance = distance
            best = node
    return best


func tick_worker(worker: Node, seconds: float) -> void:
    var steps := ceili(seconds / STEP)
    for i in steps:
        if not is_instance_valid(worker) or worker.is_queued_for_deletion():
            return
        worker.call("tick", STEP)
        if i % 4 == 3:
            await process_frame


func capture_worker_movement(main: Node, civilization: Variant, keep: Node2D, worker: Node2D) -> void:
    var tree := find_free_tree(main, worker)
    check(tree != null, "Woodcutter has an accessible real tree resource node")
    if tree == null:
        return
    worker.call("_release_target")
    tree.set("worker", worker)
    worker.set("_target", tree)
    var hits := 0
    while int(worker.get("carry")) < 5 and int(tree.get("_hp")) > 0 and hits < 3:
        tree.call("hit", worker)
        hits += 1
    check(int(worker.get("carry")) == 5, "Actual tree harvesting fills the worker's five-unit wood yield")
    worker.call("_begin_return_to_keep")
    check(not worker.get("_path").is_empty(), "Worker has a real NavGrid path back to its owner keep")
    log_workers(civilization, "heading_home")

    await capture(main, "settlement overview", keep.global_position, 0.78, "settlement-overview.png")
    await capture(main, "worker close-up", worker.global_position, 1.7, "worker-close-up.png")

    var movement_dir := output_dir.path_join("movement")
    DirAccess.make_dir_recursive_absolute(movement_dir)
    var starting_position := worker.global_position
    for i in 12:
        if is_instance_valid(worker) and not worker.is_queued_for_deletion():
            worker.call("tick", 0.5)
        await process_frame
        await RenderingServer.frame_post_draw
        var image := root.get_texture().get_image()
        if image != null and not image.is_empty():
            check(image.save_png(movement_dir.path_join("%02d.png" % i)) == OK,
                "Movement frame %02d saved" % i)
    check(worker.global_position.distance_to(starting_position) > 2.0,
        "Rival worker visibly changes position in the headed movement sequence")
    log_workers(civilization, "after_movement_capture")


func test_capacity_and_retry(main: Node, civilization: Variant, worker: Node2D) -> void:
    var nav: Node = main.get("nav")
    var cap := int(civilization.call("resource_capacity", "wood"))
    if int(worker.get("carry")) == 0:
        var tree := find_free_tree(main, worker)
        if tree != null:
            worker.call("_release_target")
            tree.set("worker", worker)
            worker.set("_target", tree)
            for _i in 3:
                if int(worker.get("carry")) >= 5 or int(tree.get("_hp")) <= 0:
                    break
                tree.call("hit", worker)
    var cargo := int(worker.get("carry"))
    check(cargo >= 2, "Storage interruption test has real harvested cargo")
    if cargo < 2:
        return

    worker.call("_begin_return_to_keep")
    civilization.get("resources")["wood"] = float(cap - 1)
    var ticks := 0
    while ticks < 800 and String(worker.call("debug_snapshot").get("task")) != "waiting_storage":
        worker.call("tick", STEP)
        if ticks % 4 == 3:
            await process_frame
        ticks += 1
    check(String(worker.call("debug_snapshot").get("task")) == "waiting_storage",
        "Worker reaches keep and waits when only one unit of storage remains")
    check(int(worker.get("carry")) == cargo - 1,
        "Partial deposit retains exactly the cargo that did not fit")
    check(int(worker.get("last_delivery_amount")) == 1,
        "Partial deposit reports exactly one delivered unit")

    var retained := int(worker.get("carry"))
    for _i in 8:
        worker.call("tick", STEP)
    check(int(worker.get("carry")) == retained, "Full stockpile retains cargo without loss")
    civilization.get("resources")["wood"] = float(cap - retained)
    for _i in 12:
        worker.call("tick", STEP)
        if int(worker.get("carry")) == 0:
            break
    check(int(worker.get("carry")) == 0, "Worker delivers retained cargo after capacity is freed")
    check(is_equal_approx(float(civilization.get("resources")["wood"]), float(cap)),
        "Partial and final delivery conserve exact stock")

    civilization.get("resources")["wood"] = 40.0
    worker.call("receive", "wood", 3)
    var blocked_cell: Vector2i = nav.call("cell_of", worker.global_position)
    for y in range(-4, 5):
        for x in range(-4, 5):
            var cell := blocked_cell + Vector2i(x, y)
            if WorldConfig.is_valid_cell(cell):
                nav.get("astar").set_point_solid(cell, true)
    nav.set("version", int(nav.get("version")) + 1)
    worker.call("_begin_return_to_keep")
    var count_after_failure := int(worker.get("path_request_count"))
    check(String(worker.call("debug_snapshot").get("route_status")) == "retry_wait",
        "Unavailable destination route enters retry cooldown")
    for _i in 8:
        worker.call("tick", 0.1)
    check(int(worker.get("path_request_count")) == count_after_failure,
        "Unchanged blocked route does not repeat A* requests each frame")
    nav.call("rebuild")
    worker.call("tick", STEP)
    check(not worker.get("_path").is_empty(), "Worker replans after navigation topology recovers")
    await tick_worker(worker, 100.0)
    check(int(worker.get("carry")) == 0, "Recovered route delivers retained cargo exactly once")


func test_workplace_retirement(civilization: Variant) -> void:
    var keep: Node2D = civilization.get("owner_keep") as Node2D
    var camp: Node2D
    for structure: Node2D in civilization.get("structures"):
        if String(structure.get("structure_id")) == "lumber_camp":
            camp = structure
            break
    check(camp != null, "Lumber Camp exists for retirement test")
    if camp == null:
        return
    var retiring := workers_for(civilization, "lumber_camp")
    var ids: Dictionary = {}
    for worker: Node in retiring:
        ids[worker.get_instance_id()] = true
    camp.call("take_damage", 999999)
    for worker: Node in retiring:
        if is_instance_valid(worker):
            check(bool(worker.get("retiring")), "Destroyed workplace marks worker for retirement")
            check(worker.get("_target") == null, "Destroyed workplace releases resource reservation")
    for tick in 800:
        var remaining := 0
        for worker: Node in retiring:
            if is_instance_valid(worker) and not worker.is_queued_for_deletion():
                remaining += 1
                worker.call("tick", STEP)
        if tick % 4 == 3:
            await process_frame
        if remaining == 0:
            break
    var survivors := 0
    for worker: Node in workers_for(civilization):
        if ids.has(worker.get_instance_id()):
            survivors += 1
    check(survivors == 0, "Retired workplace leaves no orphan economic workers")
    print("RIVAL_HEADED_WORKPLACE_RETIRED ", keep.get("stronghold_id"), " lumber_camp")


func test_stronghold_retirement(civilization: Variant, keep: Node2D) -> void:
    var old_workers := workers_for(civilization)
    keep.call("take_damage", 999999)
    await frames(3)
    check(not bool(civilization.get("active")), "Stronghold destruction deactivates civilization")
    check(workers_for(civilization).is_empty(), "Stronghold destruction removes all physical workers")


func _initialize() -> void:
    print("RIVAL_HEADED_TEST_START mode=window renderer=opengl3 seed=1337 profile=classic")
    OS.set_environment("HTK_AUTO_START_GAME", "1")
    OS.set_environment("HTK_AUTO_RESOLVE_EVENTS", "1")
    await frames(1)
    WorldConfig.apply_profile("classic")
    WorldConfig.world_seed = 1337
    output_dir = ProjectSettings.globalize_path(OUTPUT_DIR)
    var dir_error := DirAccess.make_dir_recursive_absolute(output_dir)
    if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
        check(false, "Rendered diagnostic directory can be created")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(output_dir.path_join("movement"))

    var packed := load("res://scenes/main.tscn") as PackedScene
    check(packed != null, "Main gameplay scene loads")
    if packed == null:
        quit(1)
        return
    var main: Variant = packed.instantiate()
    var nav: Node = main.get("nav")
    root.add_child(main)
    current_scene = main
    await frames(8)

    var keep: Node2D = main.campaign.call("current_target_node") as Node2D
    check(keep != null, "Campaign exposes its active rival stronghold")
    if keep == null:
        quit(1)
        return
    keep.set_process(false)
    var civilization: Variant = keep.get("civilization")
    check(civilization != null, "Active stronghold owns its EnemyCivilization")
    if civilization == null:
        quit(1)
        return
    var clock: Node = root.get_node_or_null("GameClock")
    if clock != null:
        clock.set_process(false)

    for guard: Node in keep.call("_local_garrison"):
        guard.queue_free()
    await frames(2)
    check(int(keep.call("local_garrison_count")) == 0, "Controlled test removes opening garrison")

    var fixture := seed_owner_region_resources(main, keep)
    check(int(fixture["wood"]) >= 30 and int(fixture["stone"]) >= 12 and int(fixture["iron"]) >= 8,
        "Owner-region real resource-node fixtures exist for all workforce gather roles")

    civilization.set("resources", {
        "wood": 900.0, "stone": 900.0, "food": 900.0, "iron": 900.0
    })
    var build_steps := 0
    while build_steps < 4800 and not all_workplaces_ready(civilization):
        civilization.advance(STEP)
        if build_steps % 4 == 3:
            await process_frame
        build_steps += 1
    check(all_workplaces_ready(civilization),
        "Real rival construction completes production sites and research Tier II")
    if not all_workplaces_ready(civilization):
        log_workers(civilization, "construction_timeout")
        quit(1)
        return

    civilization.set("resources", {
        "wood": 40.0, "stone": 40.0, "food": 40.0, "iron": 40.0
    })
    civilization.advance(1.0)
    await frames(3)
    var labor: Dictionary = civilization.call("labor_allocation")
    for workplace_id: String in WORKPLACES:
        var assigned := int(labor.get(workplace_id, 0))
        check(assigned == 2 and workers_for(civilization, workplace_id).size() == assigned,
            "Finite workforce assigns two visible actors to " + workplace_id)
    check(workers_for(civilization).size() == 8,
        "Rival stronghold has exactly eight visible economic workers")

    await advance_civilization(civilization, 8.0)
    for workplace_id: String in ["lumber_camp", "quarry", "forge"]:
        var distinct_targets: Dictionary = {}
        for worker: Node in workers_for(civilization, workplace_id):
            var target: Variant = worker.get("_target")
            if target != null and is_instance_valid(target):
                distinct_targets[target.get_instance_id()] = true
                check(target.get("worker") == worker,
                    "Resource node is reserved by exactly its assigned " + workplace_id + " worker")
                var cell: Vector2i = target.get("resource_cell")
                var owner := String(main.territory.call("owner_at", cell))
                check(owner != "player" and owner != "contested",
                    "Rival harvest target is outside player and contested territory")
                for point in worker.get("_path"):
                    var route_cell: Vector2i = nav.call("cell_of", point)
                    var route_owner := String(main.territory.call("owner_at", route_cell))
                    check(route_owner != "player" and route_owner != "contested",
                        "Rival worker route avoids player and contested territory")
        check(distinct_targets.size() == 2,
            "Both " + workplace_id + " workers reserve different available resource nodes")
    for worker: Node in workers_for(civilization, "farm"):
        check(String(worker.call("debug_snapshot").get("task")) == "farming",
            "Farm worker enters its real farming work cycle")
    for worker: Node in workers_for(civilization):
        check(not worker.is_in_group("villagers") and not worker.is_in_group("enemy_garrison"),
            "Rival economic actor is isolated from player and military groups")
        check(not bool(main.army_command.call("is_selectable", worker as Villager)),
            "Rival economic actor cannot be selected by player army command")
    log_workers(civilization, "all_workplaces_staffed")

    await capture(main, "rival settlement", keep.global_position, 0.78, "settlement-overview.png")
    var wood_worker: Node2D = workers_for(civilization, "lumber_camp")[0] as Node2D
    await capture_worker_movement(main, civilization, keep, wood_worker)
    await tick_worker(wood_worker, 100.0)

    var resources_before: Dictionary = civilization.get("resources").duplicate(true)
    await advance_civilization(civilization, 180.0)
    var after: Dictionary = civilization.get("resources")
    for kind: String in RESOURCES:
        check(float(after.get(kind, 0.0)) > float(resources_before.get(kind, 0.0)),
            "Physical harvesting/production and delivery raises rival " + kind)
    log_workers(civilization, "after_180_seconds")
    await test_capacity_and_retry(main, civilization, wood_worker)
    await test_workplace_retirement(civilization)
    await test_stronghold_retirement(civilization, keep)

    print("RIVAL_HEADED_RESULT failures=", int(failed),
        " evidence=", output_dir,
        " classification=automated_headed_render human_desktop_playtest_not_run")
    if failed:
        quit(1)
        return
    print("PASS: actual headed rival workforce rendering, gathering, delivery, capacity, recovery and cleanup")
    quit(0)
