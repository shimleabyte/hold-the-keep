extends SceneTree
## Phase 06.2 regression: Beast Rider target policy, charge path, miss window and interruption.

func ticks(count: int) -> void:
    for i in count:
        await physics_frame


func require(condition: bool, message: String) -> void:
    if not condition:
        push_error("FAIL: " + message)
        quit(1)
    assert(condition, message)


func spawn_rider(main, data: Dictionary, at: Vector2):
    var script = load("res://scripts/entities/enemy.gd")
    var rider = script.new()
    rider.setup(data, main.world, main.flow, main.player, "greenwood_raiders")
    rider.global_position = at
    main.world.entities.add_child(rider)
    rider.set_physics_process(false)
    return rider


func spawn_soldier(main, at: Vector2):
    var soldier = main.village.spawn_villager(at)
    require(soldier != null, "Test soldier must spawn")
    require(soldier.set_job("soldier"), "Test defender must become a soldier")
    soldier.set_physics_process(false)
    return soldier


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    root.get_node("WorldConfig").apply_profile("frontier")
    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(8)
    root.get_node("GameClock").set_process(false)
    main.supply.set_process(false)
    main.spawner.set_process(false)
    main.spawner.set_physics_process(false)
    main.village.set_process(false)

    var data_db = root.get_node("DataDB")
    var player = main.player
    player.global_position = Vector2(180, 180)

    # The bounded scan favors an isolated defender over a slightly closer defended cluster.
    var clustered = spawn_soldier(main, Vector2(820, 820))
    var clustered_guard = spawn_soldier(main, Vector2(842, 820))
    var isolated = spawn_soldier(main, Vector2(920, 820))
    var selector = spawn_rider(main, data_db.enemies["enemy_beast_rider"], Vector2(720, 820))
    require(selector.beast_nav == main.nav, "Beast Rider must bind the shared navigation grid")
    selector._beast_target = selector._select_beast_target()
    assert(selector._beast_target == isolated,
        "Beast Rider must prefer an isolated defender over a nearby supported defender")
    assert(clustered_guard.global_position.distance_to(clustered.global_position) < 76.0,
        "Target-priority fixture must contain a supported defender pair")

    # A building blocks the straight line. The charge must follow only walkable A* cells.
    var blocker_cell := main.nav.cell_of(Vector2(820, 860))
    var blocker = main.build.place_raw("stone_wall", blocker_cell)
    require(blocker != null, "Test obstacle must be placed")
    main.nav.rebuild()

    var rider = spawn_rider(main, data_db.enemies["enemy_beast_rider"], Vector2(720, 900))
    var target = spawn_soldier(main, Vector2(840, 900))
    # Keep unrelated defenders outside this rider's target scan and isolation radius.
    clustered.global_position = Vector2(180, 180)
    clustered_guard.global_position = Vector2(180, 180)
    isolated.global_position = Vector2(180, 180)

    rider._beast_target = target
    var target_hp_before: int = target.hp
    rider._tick_beast_rider(0.016)
    require(rider._beast_windup_t > 0.0, "Rider must expose a wind-up before charging")
    assert(target.hp == target_hp_before, "Wind-up must not damage its target")
    assert(not rider._beast_charge_path.is_empty(), "Wind-up must cache a route to the locked target")
    for path_index in rider._beast_charge_path.size():
        var route_cell: Vector2i = main.nav.cell_of(rider._beast_charge_path[path_index])
        assert(main.nav.is_walkable(route_cell), "Charge route must contain walkable cells only")
    assert(rider._beast_charge_path_version == main.nav.version,
        "Charge route must record the navigation version it was planned against")

    rider._tick_beast_rider(rider.beast_charge_windup_duration + 0.02)
    assert(rider._beast_charge_t > 0.0, "Completed telegraph must enter a finite charge")
    assert(target.hp == target_hp_before, "Charge start must not apply impact damage")
    rider._tick_beast_rider(1.2)
    assert(target.hp < target_hp_before, "A charge crossing its locked target must deal impact damage")
    assert(rider._beast_cd > 0.0, "A completed charge must enter its recovery cooldown")

    # A target that sidesteps the locked route during the tell should be missed, not chased mid-charge.
    var bait_rider = spawn_rider(main, data_db.enemies["enemy_beast_rider"], Vector2(720, 980))
    var bait_target = spawn_soldier(main, Vector2(840, 980))
    bait_rider._beast_target = bait_target
    bait_rider._tick_beast_rider(0.016)
    require(bait_rider._beast_windup_t > 0.0, "Sidestep fixture must enter wind-up")
    bait_rider._tick_beast_rider(bait_rider.beast_charge_windup_duration + 0.02)
    var bait_hp_before: int = bait_target.hp
    bait_target.global_position += Vector2(0, 64)
    bait_rider._tick_beast_rider(1.2)
    assert(bait_target.hp == bait_hp_before,
        "A defender sidestepping outside the locked charge lane must avoid the impact")
    assert(bait_rider._beast_charge_t == 0.0,
        "A missed charge must end instead of tracking its target")

    # Stagger cancels both the tell and the active charge.
    var interrupted = spawn_rider(main, data_db.enemies["enemy_beast_rider"], Vector2(720, 1060))
    var interrupted_target = spawn_soldier(main, Vector2(840, 1060))
    interrupted._beast_target = interrupted_target
    interrupted._tick_beast_rider(0.016)
    require(interrupted._beast_windup_t > 0.0, "Interrupt fixture must enter wind-up")
    interrupted.apply_stagger(0.8)
    assert(interrupted._beast_windup_t == 0.0 and interrupted._beast_charge_t == 0.0,
        "Stagger must cancel the Beast Rider tell")
    assert(interrupted._beast_cd > 0.0, "Interrupted Beast Rider must receive a recovery window")

    var active_interrupt = spawn_rider(main, data_db.enemies["enemy_beast_rider"], Vector2(720, 1140))
    var active_target = spawn_soldier(main, Vector2(840, 1140))
    active_interrupt._beast_target = active_target
    active_interrupt._tick_beast_rider(0.016)
    active_interrupt._tick_beast_rider(active_interrupt.beast_charge_windup_duration + 0.02)
    require(active_interrupt._beast_charge_t > 0.0, "Active-interrupt fixture must start charging")
    active_interrupt.apply_stagger(0.8)
    assert(active_interrupt._beast_charge_t == 0.0 and active_interrupt._beast_charge_path.is_empty(),
        "Stagger must stop an active charge before it can connect")

    print("PASS: Beast Rider isolated target priority, walkable locked route, telegraphed impact, sidestep miss and stagger interruption")
    main.queue_free()
    quit(0)
