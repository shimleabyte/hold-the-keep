extends SceneTree
## Regression coverage for night-wave spawns while Expedition's four outer marches are sealed.

const SEED := 70141
const TEST_DAY := 6
const FLOW_WAIT_LIMIT := 900
const SPAWN_CHECKS := 12
const REGIONS := ["GREENWOOD", "HIGHLANDS", "FENLANDS", "ASHEN_MARCH"]


func _initialize() -> void:
    await process_frame
    var config = root.get_node("WorldConfig")
    var clock = root.get_node("GameClock")
    config.apply_profile("frontier_expedition")
    config.world_seed = SEED
    ProjectSettings.set_setting("world/seed", SEED)
    seed(SEED)
    root.get_node("Inventory").reset()
    root.get_node("Tech").reset()
    clock.reset()
    clock.set_process(false)
    clock.set_physics_process(false)

    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)

    var main_scene := load("res://scenes/main.tscn") as PackedScene
    if main_scene == null:
        push_error("Main gameplay scene must load")
        quit(1)
        return
    var main = main_scene.instantiate()
    root.add_child(main)
    current_scene = main
    await _ticks(12)

    if main.world == null or main.flow == null or main.spawner == null:
        push_error("HTK_AUTO_START_GAME=1 must initialize WorldMap, FlowField and WaveSpawner")
        quit(1)
        return

    var wait_frames := 0
    while not main.flow.is_current() and wait_frames < FLOW_WAIT_LIMIT:
        await process_frame
        wait_frames += 1
    if not main.flow.is_current():
        push_error("Expedition FlowField did not publish within %d frames" % FLOW_WAIT_LIMIT)
        quit(1)
        return

    var profile: Dictionary = config.profile_definition(config.profile_id)
    var core_size := int(profile.get("expedition_core_size", 160))
    var core_min := int((config.map_size - core_size) / 2)
    var core_max := core_min + core_size
    for region in REGIONS:
        var landing: Vector2i = main.world.expedition_outer_landing_cell(region)
        assert(not main.world.is_expedition_gate_open(region),
            "Expedition discovery gate must remain sealed before its objective: " + region)
        assert(not main.flow.is_reachable(landing),
            "The outer march must remain unreachable before discovery: " + region)

    main.spawner.start_wave(TEST_DAY)
    var spawned_cells: Array[Vector2i] = []
    for index in SPAWN_CHECKS:
        var did_spawn: bool = main.spawner.spawn_one()
        assert(did_spawn, "Expedition must spawn night attackers from the accessible heartland edge (attempt %d)" % index)
        var enemies := get_nodes_in_group("enemies")
        assert(not enemies.is_empty(), "A successful spawn must create an enemy node")
        var enemy = enemies.back()
        var cell: Vector2i = main.nav.cell_of(enemy.global_position)
        var inside_core := cell.x >= core_min and cell.y >= core_min and cell.x < core_max and cell.y < core_max
        var on_core_edge := cell.x == core_min or cell.y == core_min or cell.x == core_max - 1 or cell.y == core_max - 1
        assert(inside_core and on_core_edge,
            "Night attackers must enter from the accessible 160x160 heartland perimeter: %s" % str(cell))
        assert(not main.world.is_expedition_reserved_cell(cell),
            "A night attacker must not occupy a reserved discovery crossing approach: %s" % str(cell))
        assert(main.flow.is_reachable(cell),
            "A night attacker must spawn on the Keep-connected FlowField: %s" % str(cell))
        spawned_cells.append(cell)

    print("EXPEDITION_WAVE_SPAWN_REPORT " + JSON.stringify({
        "profile": config.profile_id,
        "seed": SEED,
        "world_size": config.map_size,
        "heartland_size": core_size,
        "flow_wait_frames": wait_frames,
        "sealed_outer_gates": REGIONS.size(),
        "successful_spawns": spawned_cells.size(),
        "spawns_on_reachable_heartland_edge": true,
        "result": "passed"
    }))
    main.queue_free()
    quit(0)


func _ticks(count: int) -> void:
    for _index in count:
        await process_frame
