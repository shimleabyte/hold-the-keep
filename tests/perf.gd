extends SceneTree

const MAX_PARTICLES := 500

var world_config
var data_db
var faction_registry
var game_clock
var events

## Configurable diagnostic benchmark; timing output is informative, not a CI threshold.
## Example:
## PROFILE=frontier ENEMIES=96 VILLAGERS=80 FRAMES=360 godot --headless --path . --script res://tests/perf.gd

const DEFAULTS := {
    "profile": "frontier",
    "enemies": 96,
    "villagers": 80,
    "frames": 360,
    "warmup": 90
}
const FACTION_IDS := [
    "greenwood_raiders",
    "iron_legion",
    "fen_cult",
    "ashen_host"
]


func ticks(count: int) -> void:
    for i in range(count):
        await process_frame


func env_int(key: String, fallback: int, minimum: int, maximum: int) -> int:
    var value := OS.get_environment(key)
    if value.is_valid_int():
        return clampi(value.to_int(), minimum, maximum)
    return fallback


func percentile(values: Array[float], ratio: float) -> float:
    if values.is_empty():
        return 0.0
    var ordered := values.duplicate()
    ordered.sort()
    var index := clampi(ceili(float(ordered.size()) * ratio) - 1, 0, ordered.size() - 1)
    return ordered[index]


func region_cells(main: Node, region_id: String, limit: int) -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    var reachable: Dictionary = main.nav.reachable_cells(
        main.nav.cell_of(main.player.global_position)
    )
    for value in reachable.keys():
        var cell: Vector2i = value
        if String(main.world.region_id(cell)) != region_id:
            continue
        if main.world.occupied.has(cell):
            continue
        cells.append(cell)
        if cells.size() >= limit:
            break
    return cells


func spawn_enemy(main: Node, enemy_id: String, faction_id: String, cell: Vector2i) -> void:
    if not data_db.enemies.has(enemy_id):
        return
    var enemy = load("res://scripts/entities/enemy.gd").new()
    enemy.setup(data_db.enemies[enemy_id], main.world, main.flow, main.player, faction_id)
    enemy.position = Vector2(cell) * world_config.tile_size + Vector2(8.0, 8.0)
    main.world.entities.add_child(enemy)


func spawn_workload(main: Node, profile: String, enemy_count: int, villager_count: int) -> void:
    var per_faction := maxi(0, floori(float(enemy_count) / float(FACTION_IDS.size())))
    if world_config.is_frontier_profile(profile):
        for faction_id in FACTION_IDS:
            var faction: Dictionary = faction_registry.factions.get(faction_id, {})
            var region_id := String(faction.get("region", ""))
            var roster: Array[String] = faction_registry.roster_for(faction_id)
            var cells := region_cells(main, region_id, per_faction)
            for i in mini(per_faction, cells.size()):
                spawn_enemy(main, roster[i % roster.size()], faction_id, cells[i])
    else:
        main.spawner._pool = data_db.waves.get("types", []).duplicate(true)
        for i in enemy_count:
            main.spawner.spawn_one()

    var keep_position: Vector2 = main.world.keep_center_position()
    for i in villager_count:
        var column := (i % 12) - 6
        var row := floori(float(i) / 12.0) - 3
        main.village.spawn_villager(
            keep_position + Vector2(float(column * 5), float(row * 5))
        )
    var labor_quota := mini(20, floori(float(villager_count) / 4.0))
    main.village.quota = main.village.quota.duplicate(true)
    main.village.quota.merge({
        "woodcutter": labor_quota,
        "miner": labor_quota,
        "farmer": labor_quota,
        "builder": 0,
        "hunter": 0,
        "scout": 0,
        "healer": 0,
        "blacksmith": 0,
        "soldier": mini(20, villager_count - 3 * labor_quota)
    }, true)
    main.village.assign_jobs()

    # Keep at least one ranged unit/projectile in the sampled workload.
    if data_db.enemies.has("archer"):
        var archer = load("res://scripts/entities/enemy.gd").new()
        archer.setup(
            data_db.enemies["archer"],
            main.world,
            main.flow,
            main.player,
            "iron_legion" if world_config.is_frontier_profile(profile) else ""
        )
        archer.position = main.player.position + Vector2(128.0, 0.0)
        main.world.entities.add_child(archer)
        archer._begin_ranged_attack(main.player)


func _find_fx(main: Node) -> Node:
    for child in main.world.get_children():
        if child.has_method("count") and child.has_method("spawn"):
            return child
    return null


func _run() -> void:
    var profile := OS.get_environment("PROFILE")
    if profile.is_empty():
        profile = DEFAULTS["profile"]
    if not ["classic", "frontier", "frontier_expedition"].has(profile):
        push_error("PROFILE must be classic, frontier or frontier_expedition")
        quit(2)
        return

    var enemy_count := env_int("ENEMIES", DEFAULTS["enemies"], 0, 240)
    var villager_count := env_int("VILLAGERS", DEFAULTS["villagers"], 0, 160)
    var sample_frames := env_int("FRAMES", DEFAULTS["frames"], 60, 3600)
    var warmup_frames := env_int("WARMUP", DEFAULTS["warmup"], 0, 600)

    world_config.apply_profile(profile)
    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(8)
    game_clock.set_process(false)
    main.nav.rebuild()
    spawn_workload(main, profile, enemy_count, villager_count)

    var fx = _find_fx(main)
    if fx == null:
        push_error("Shared FX layer was not created")
        quit(1)
        return

    # Prime the shared store to its hard ceiling before the measurement begins.
    for burst_index in range(70):
        events.fx_burst.emit("impact", main.player.position, Vector2.RIGHT, 2.0)
    for burst_index in range(10):
        events.fx_burst.emit("debris", main.player.position, Vector2.LEFT, 1.0)
    assert(fx.count() == MAX_PARTICLES,
        "The profiling workload must begin with the configured 500-particle ceiling")

    await ticks(warmup_frames)
    var process_ms: Array[float] = []
    var physics_ms: Array[float] = []
    var wall_ms: Array[float] = []
    var peak_projectiles := 0
    var peak_particles := 0
    var peak_nodes := 0
    var memory_bytes := 0

    for frame_index in sample_frames:
        if frame_index % 8 == 0:
            # Sustain the 500-particle ceiling while exercising bounded replacement.
            for burst_index in range(24):
                events.fx_burst.emit("impact", main.player.position, Vector2.RIGHT, 2.5)
        assert(fx.count() <= MAX_PARTICLES,
            "Transient FX storage must remain within its configured ceiling")

        var started := Time.get_ticks_usec()
        await process_frame
        wall_ms.append(float(Time.get_ticks_usec() - started) / 1000.0)

        process_ms.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
        physics_ms.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
        peak_projectiles = maxi(peak_projectiles, get_nodes_in_group("enemy_projectiles").size())
        peak_particles = maxi(peak_particles, fx.count())
        peak_nodes = maxi(peak_nodes, get_nodes_in_group("enemies").size()
            + get_nodes_in_group("villagers").size()
            + get_nodes_in_group("buildings").size())
        memory_bytes = maxi(memory_bytes, int(Performance.get_monitor(Performance.MEMORY_STATIC)))

    var result := {
        "profile": profile,
        "map_size": world_config.map_size,
        "sample_frames": sample_frames,
        "warmup_frames": warmup_frames,
        "enemy_count": get_nodes_in_group("enemies").size(),
        "villager_count": get_nodes_in_group("villagers").size(),
        "peak_projectiles": peak_projectiles,
        "peak_particles": peak_particles,
        "peak_world_nodes": peak_nodes,
        "peak_static_memory_bytes": memory_bytes,
        "wall_frame_ms": {
            "p50": percentile(wall_ms, 0.50),
            "p95": percentile(wall_ms, 0.95),
            "p99": percentile(wall_ms, 0.99)
        },
        "godot_process_ms": {
            "p50": percentile(process_ms, 0.50),
            "p95": percentile(process_ms, 0.95),
            "p99": percentile(process_ms, 0.99)
        },
        "godot_physics_ms": {
            "p50": percentile(physics_ms, 0.50),
            "p95": percentile(physics_ms, 0.95),
            "p99": percentile(physics_ms, 0.99)
        }
    }
    assert(peak_particles == MAX_PARTICLES,
        "The reference workload must reach the 500-particle ceiling during sampling")
    print("PERF_REPORT " + JSON.stringify(result))
    quit(0)


func _initialize() -> void:
    world_config = root.get_node("WorldConfig")
    data_db = root.get_node("DataDB")
    faction_registry = root.get_node("FactionRegistry")
    game_clock = root.get_node("GameClock")
    events = root.get_node("Events")
    call_deferred("_run")
