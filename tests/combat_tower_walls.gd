extends SceneTree

func ticks(n: int) -> void:
    for i in n:
        await physics_frame

func _initialize() -> void:
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    await ticks(3)
    var inv = root.get_node("Inventory")
    var ev = root.get_node("Events")
    var w = main.world
    var b = main.build
    var f = main.flow
    var sp = main.spawner
    var p = main.player
    var keep = null
    for n in get_nodes_in_group("buildings"):
        if n.id == "keep": keep = n
    var kills := [0]
    ev.enemy_killed.connect(func(_id): kills[0] += 1)
    var ENEMY = load("res://scripts/entities/enemy.gd")
    inv.add("wood", 500); inv.add("stone", 100)
    p.global_position = Vector2(100, 100)

    # ---- T1: menara membunuh satu bandit ----
    b.player = null
    print("T1 tower: '", b.place("tower", Vector2i(36, 36)), "'")
    var tower_pos := Vector2(37 * 16, 38 * 16)
    var e = ENEMY.new()
    e.setup(root.get_node("DataDB").enemies["bandit"], w, f, p)
    e.position = tower_pos + Vector2(60, 0)
    w.entities.add_child(e)
    var t := 0
    while is_instance_valid(e) and e.hp > 0 and t < 900:
        await physics_frame
        t += 1
    print("T1 bandit (20hp, tower 7dmg/0.9s) killed after ticks=", t, " (~", snappedf(t / 60.0, 0.1), "s), expected ~2.7-3.5s")
    for n in get_nodes_in_group("buildings"):
        if n.id == "tower": b.demolish_at(n.cell)
    await ticks(2)

    # ---- T2: cincin tembok penuh ----
    var placed := 0
    var skipped := 0
    for x in range(26, 38):
        for y in [24, 38]:
            var r: String = b.place("wall", Vector2i(x, y))
            if r == "": placed += 1
            else: skipped += 1
    for y in range(25, 38):
        for x in [26, 37]:
            var r: String = b.place("wall", Vector2i(x, y))
            if r == "": placed += 1
            else: skipped += 1
    print("T2 walls placed=", placed, " skipped(tree/water)=", skipped)
    await ticks(3)
    # semua sel luar ring harus punya jalur lewat tembok (reachable)
    print("T2 edge (1,62) reachable via walls: ", f.is_reachable(Vector2i(1, 62)))
    var wall_hp_before := 0
    for n in get_nodes_in_group("buildings"):
        if n.id == "wall": wall_hp_before += n.hp
    keep.hp = keep.max_hp
    kills[0] = 0
    sp.start_wave(1)
    await ticks(60 * 50)
    var wall_hp_after := 0
    var walls := 0
    for n in get_nodes_in_group("buildings"):
        if n.id == "wall":
            wall_hp_after += n.hp
            walls += 1
    var inside := 0
    for en in get_nodes_in_group("enemies"):
        var c := Vector2i((en.position / 16).floor())
        if c.x > 26 and c.x < 37 and c.y > 24 and c.y < 38: inside += 1
    print("T2 wave1 (6 bandits) vs ring: wall hp ", wall_hp_before, " -> ", wall_hp_after, " walls=", walls, " enemies inside ring=", inside, " keep hp=", keep.hp)
    sp.end_wave()
    await ticks(2)

    # ---- T3: performa 150 musuh ----
    for en in get_nodes_in_group("enemies"): en.retreat()
    sp._pool = root.get_node("DataDB").waves["types"].duplicate()
    var made := 0
    for i in 150:
        if sp.spawn_one(): made += 1
    await ticks(5)
    var t0 := Time.get_ticks_usec()
    await ticks(180)
    var dt := (Time.get_ticks_usec() - t0) / 180.0 / 1000.0
    print("T3 enemies=", get_nodes_in_group("enemies").size(), " avg ms per frame (physics+process, headless, no rendering): ", snappedf(dt, 0.01))
    for en in get_nodes_in_group("enemies"): en.retreat()

    # ---- T4: game over ----
    keep.take_damage(99999)
    await ticks(3)
    print("T4 paused=", paused, " keep freed=", not is_instance_valid(keep))
    quit()
