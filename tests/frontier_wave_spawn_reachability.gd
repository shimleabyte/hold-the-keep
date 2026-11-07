extends SceneTree
## Diagnostic for Frontier's runtime wave spawn contract.
## Waits for the asynchronous enemy FlowField, then asks the real WaveSpawner
## to place an enemy and reports which edge bands are actually reachable.

const PROFILE := "frontier"
const SEED := 70127
const TEST_DAY := 6
const FLOW_WAIT_LIMIT := 600
const SPAWN_ATTEMPTS := 20
const MAX_EDGE_INSET := 24


func _initialize() -> void:
    await process_frame
    var world_config = root.get_node("WorldConfig")
    var inventory = root.get_node("Inventory")
    var tech = root.get_node("Tech")
    var clock = root.get_node("GameClock")
    assert(world_config.apply_profile(PROFILE), "Frontier profile must apply")
    world_config.world_seed = SEED
    ProjectSettings.set_setting("world/seed", SEED)
    seed(SEED)
    inventory.reset()
    tech.reset()
    clock.reset()
    clock.set_process(false)
    clock.set_physics_process(false)

    var main_scene := load("res://scenes/main.tscn") as PackedScene
    assert(main_scene != null, "Main gameplay scene must load")
    var main = main_scene.instantiate()
    root.add_child(main)
    current_scene = main
    await _ticks(12)

    assert(main.world != null and main.flow != null and main.spawner != null,
        "Frontier gameplay must initialize WorldMap, FlowField and WaveSpawner")

    var wait_frames := 0
    while not main.flow.is_current() and wait_frames < FLOW_WAIT_LIMIT:
        await process_frame
        wait_frames += 1
    var flow_report := {
        "profile": PROFILE,
        "seed": SEED,
        "flow_ready": main.flow.is_current(),
        "flow_wait_frames": wait_frames,
        "flow_version": main.flow.version,
        "flow_cost_size": main.flow._cost.size(),
        "flow_build_active": main.flow._build_active,
        "flow_dirty": main.flow._dirty
    }
    print("FRONTIER_WAVE_FLOW " + JSON.stringify(flow_report))
    if not main.flow.is_current():
        push_error("Frontier FlowField did not publish within %d frames" % FLOW_WAIT_LIMIT)
        quit(1)
        return

    var map_size: int = world_config.map_size
    var band_counts: Array[int] = []
    var all_reachable := 0
    for inset in range(1, MAX_EDGE_INSET + 1):
        var count := 0
        for t in range(1, map_size - 1):
            var cells: Array[Vector2i] = [
                Vector2i(t, inset),
                Vector2i(t, map_size - 1 - inset),
                Vector2i(inset, t),
                Vector2i(map_size - 1 - inset, t)
            ]
            for cell in cells:
                if main.world.is_buildable(cell) \
                        and not main.world.occupied.has(cell) \
                        and main.flow.is_reachable(cell):
                    count += 1
        band_counts.append(count)
        all_reachable += count

    var baseline_enemies := get_nodes_in_group("enemies").size()
    main.spawner.start_wave(TEST_DAY)
    var spawned := false
    var attempts_used := 0
    for attempt in range(SPAWN_ATTEMPTS):
        attempts_used = attempt + 1
        if main.spawner.spawn_one():
            spawned = true
            break

    var edge_report := {
        "inset_counts": band_counts,
        "reachable_edge_candidates": all_reachable,
        "spawn_succeeded": spawned,
        "spawn_attempts": attempts_used,
        "baseline_enemies": baseline_enemies,
        "enemy_count_after": get_nodes_in_group("enemies").size()
    }
    print("FRONTIER_WAVE_EDGE " + JSON.stringify(edge_report))
    if not spawned:
        push_error("Frontier WaveSpawner could not place an enemy after %d attempts" % SPAWN_ATTEMPTS)
        quit(1)
        return

    print("PASS: Frontier WaveSpawner selects a reachable edge cell after FlowField publication")
    main.queue_free()
    quit(0)


func _ticks(count: int) -> void:
    for _index in count:
        await process_frame
