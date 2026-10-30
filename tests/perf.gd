extends SceneTree
func ticks(n: int) -> void:
    for i in n:
        await physics_frame
func _initialize() -> void:
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    await ticks(5)
    root.get_node("GameClock").set_process(false)
    main.player.global_position = Vector2(100, 100)
    var sp = main.spawner
    sp._pool = root.get_node("DataDB").waves["types"].duplicate()
    for i in 150: sp.spawn_one()
    for i in 40: main.village.spawn_villager(Vector2(520 + randf_range(-30, 30), 522))
    main.village.quota = {"woodcutter": 10, "miner": 8, "farmer": 2, "soldier": 6}
    main.village.assign_jobs()
    await ticks(120)
    var t0 = Time.get_ticks_usec()
    await ticks(300)
    var dt = (Time.get_ticks_usec() - t0) / 300.0 / 1000.0
    print("PERF enemies=", get_nodes_in_group("enemies").size(), " villagers=", get_nodes_in_group("villagers").size(), " avg ms/frame=", snappedf(dt, 0.01))
    quit()
