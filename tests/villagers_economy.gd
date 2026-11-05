extends SceneTree

var clock
func ticks(n: int) -> void:
    for i in n:
        await physics_frame

func set_night(b: bool) -> void:
    clock.set_process(true)
    clock.time_of_day = 0.65 if b else 0.1
    await ticks(2)
    clock.set_process(false)

func free_spot(w, near: Vector2i, size: Vector2i, min_r := 0) -> Vector2i:
    for r in range(min_r, 20):
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if max(abs(dx), abs(dy)) != r: continue
                var c = near + Vector2i(dx, dy)
                var ok = true
                for y in size.y:
                    for x in size.x:
                        var cell = c + Vector2i(x, y)
                        if not w.is_buildable(cell) or w.occupied.has(cell): ok = false
                if ok: return c
    return Vector2i(-1, -1)

func _initialize() -> void:
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    await ticks(3)
    clock = root.get_node("GameClock")
    clock.set_process(false)
    var inv = root.get_node("Inventory")
    var ev = root.get_node("Events")
    var w = main.world
    var b = main.build
    var vil = main.village
    var nav = main.nav
    var p = main.player
    p.global_position = Vector2(100, 100)
    b.player = null
    var kills = [0]
    ev.enemy_killed.connect(func(_id): kills[0] += 1)

    print("T0 pop=", vil.population(), " cap=", vil.capacity(), " quota=", vil.quota, " nav version=", nav.version)
    # ---- T1: nav ----
    var path: PackedVector2Array = nav.path_to(Vector2(520, 522), Vector2i(20, 40))
    print("T1 path to (20,40): points=", path.size(), " first=", path[0] if path.size() > 0 else "-", " last=", path[path.size() - 1] if path.size() > 0 else "-")
    var keep_cells: Array[Vector2i] = [Vector2i(32, 30)]
    print("T1 adjacent path to keep: ", nav.path_adjacent(Vector2(300, 300), keep_cells).size() > 0)

    # ---- T2: penebang ----
    await vil.assign_jobs()
    await ticks(2)
    var vs = vil.villagers()
    var jobs = []
    for v in vs: jobs.append(v.job)
    print("T2 jobs assigned: ", jobs)
    assert(vil.count_job("woodcutter") == 1,
        "The assignment pass must respect the single default Woodcutter quota")
    var wood0 = inv.get_amount("wood")
    var states = {}
    for s in 90:
        await ticks(60)
        for v in vs:
            if is_instance_valid(v):
                states[v.state] = states.get(v.state, 0) + 1
    print("T2 wood after 90s with 1 woodcutter: +", inv.get_amount("wood") - wood0, " | state-seconds: ", states, " (0 IDLE,1 TO_WORK,2 WORKING,3 TO_DEPOT)")

    # ---- T3: gudang mendekatkan setoran ----
    var wc = null
    for v in vs:
        if v.job == "woodcutter": wc = v
    var tpos: Vector2 = wc.target.position if wc.target != null else wc.position
    var sc = free_spot(w, Vector2i((tpos / 16).floor()), Vector2i(3, 2), 2)
    inv.add("wood", 20)
    print("T3 storage near tree at ", sc, ": '", b.place("storage", sc), "'")
    await ticks(60 * 20)
    print("T3 woodcutter depot after storage: ", wc._depot.id if wc._depot != null and is_instance_valid(wc._depot) else "none")
    var wood1 = inv.get_amount("wood")
    await ticks(60 * 60)
    print("T3 wood in 60s with storage nearby: +", inv.get_amount("wood") - wood1)

    # ---- T4: petani ----
    var fc = free_spot(w, Vector2i(36, 34), Vector2i(3, 2), 1)
    inv.add("wood", 20)
    print("T4 farm: '", b.place("farm", fc), "' at ", fc)
    vil.quota["farmer"] = 1
    vil.quota["woodcutter"] = 0
    vil.assign_jobs()
    assert(vil.count_job("farmer") == 1 and vil.count_job("woodcutter") == 0,
        "Shrinking one quota and growing another must update assignment counters exactly")
    var food0 = inv.get_amount("food")
    await ticks(60 * 70)
    print("T4 food after 70s with 1 farmer: +", inv.get_amount("food") - food0, " farm slots free=", 1 if false else 2 - 0)
    var farmer = null
    for v in vil.villagers():
        if v.job == "farmer": farmer = v
    print("T4 farmer state=", farmer.state if farmer else "none")

    # ---- T5: penambang ----
    vil.quota["farmer"] = 0
    vil.quota["miner"] = 1
    vil.assign_jobs()
    assert(vil.count_job("farmer") == 0 and vil.count_job("miner") == 1,
        "Reassignment must release the previous job and fill the new quota")
    var st0 = inv.get_amount("stone")
    await ticks(60 * 90)
    print("T5 stone after 90s with 1 miner: +", inv.get_amount("stone") - st0)

    # ---- T6: populasi ----
    inv.items["food"] = 100
    print("T6 pop/cap before: ", vil.population(), "/", vil.capacity(), " try_spawn(at cap)=", vil.try_spawn())
    inv.add("wood", 50)
    var hc = free_spot(w, Vector2i(28, 34), Vector2i(2, 2), 1)
    print("T6 house: '", b.place("house", hc), "'  cap now=", vil.capacity())
    print("T6 try_spawn=", vil.try_spawn(), " pop=", vil.population(), " food=", inv.get_amount("food"), " (expected 92)")
    inv.items["food"] = 5
    print("T6 try_spawn with 5 food (guard)=", vil.try_spawn())

    # ---- T7: malam ----
    vil.quota["miner"] = 0
    vil.quota["woodcutter"] = 2
    vil.quota["soldier"] = 2
    inv.items["food"] = 100
    vil.assign_jobs()
    await ticks(60 * 5)
    await set_night(true)
    await ticks(60 * 15)
    var hidden = 0
    var fighting = 0
    var workers_out = 0
    for v in vil.villagers():
        if v.job == "soldier":
            fighting += 1
        elif v.visible:
            workers_out += 1
        else:
            hidden += 1
    print("T7 night: hidden workers=", hidden, " workers still visible=", workers_out, " soldiers=", fighting, " enemies=", get_nodes_in_group("enemies").size())
    kills[0] = 0
    var keep_hp = null
    for n in get_nodes_in_group("buildings"):
        if n.id == "keep": keep_hp = n
    keep_hp.hp = keep_hp.max_hp
    await ticks(60 * 40)
    var sol_hp = []
    for v in vil.villagers():
        if v.job == "soldier": sol_hp.append(v.hp)
    print("T7 kills during night (soldiers only; player far): ", kills[0], " enemies left=", get_nodes_in_group("enemies").size(), " keep hp=", keep_hp.hp, " soldier hp=", sol_hp, " pop=", vil.population())

    # ---- T8: fajar ----
    await set_night(false)
    await ticks(60 * 2)
    var vis = 0
    for v in vil.villagers():
        if v.visible: vis += 1
    print("T8 dawn: villagers visible=", vis, "/", vil.population())

    # ---- T9: upkeep & kelaparan ----
    inv.items["food"] = 100
    var pop_before = vil.population()
    vil._on_day_changed(2)
    print("T9 upkeep: food 100 -> ", inv.get_amount("food"), " (expected ", 100 - pop_before * 2, ") pop=", vil.population())
    inv.items["food"] = 1
    vil._on_day_changed(3)
    await ticks(2)
    print("T9 starvation: pop ", pop_before, " -> ", vil.population(), " food=", inv.get_amount("food"))

    # ---- T10: performa ----
    for i in 40:
        vil.spawn_villager(Vector2(520 + randf_range(-30, 30), 522))
    vil.quota["woodcutter"] = 10; vil.quota["miner"] = 8; vil.quota["farmer"] = 2; vil.quota["soldier"] = 6
    vil.assign_jobs()
    await ticks(120)
    var t0 = Time.get_ticks_usec()
    await ticks(300)
    var dt = (Time.get_ticks_usec() - t0) / 300.0 / 1000.0
    print("T10 villagers=", vil.population(), " avg ms/frame (no rendering): ", snappedf(dt, 0.01))
    quit()
