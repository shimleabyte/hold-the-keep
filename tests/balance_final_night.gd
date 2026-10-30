extends SceneTree
var clock
func ticks(n: int) -> void:
    for i in n:
        await physics_frame

func night() -> void:
    clock.set_process(true)
    clock.time_of_day = 0.65
    await ticks(2)
    clock.set_process(false)

func ring(main, x0, x1, y0, y1) -> int:
    var placed = 0
    for x in range(x0, x1 + 1):
        for y in [y0, y1]:
            if main.build.place("wall", Vector2i(x, y)) == "": placed += 1
    for y in range(y0 + 1, y1):
        for x in [x0, x1]:
            if main.build.place("wall", Vector2i(x, y)) == "": placed += 1
    return placed

func run_case(label: String, soldiers: int, towers: int, walls: bool, per_day: int, tower_dmg: int, keep_hp: int) -> void:
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    await ticks(3)
    clock = root.get_node("GameClock")
    clock.reset(); clock.set_process(false)
    var inv = root.get_node("Inventory")
    inv.reset()
    # TECH=era2 -> semua teknologi era Kayu+Batu (tanpa besi); TECH=all -> semua (butuh Tempa di keep)
    var tmode = OS.get_environment("TECH")
    var T = root.get_node("Tech")
    T.reset()
    if tmode != "":
        for id in root.get_node("DataDB").tech_order:
            var era = int(root.get_node("DataDB").techs[id]["era"])
            var is_iron = id == "iron_mining" or era == 3
            if tmode == "all" or (tmode == "era2" and not is_iron):
                T.researched.append(id)
        T._recompute()
        T.era = 3 if tmode == "all" else 2
        root.get_node("Events").tech_researched.emit("")
    var db = root.get_node("DataDB")
    db.waves["per_day"] = per_day
    db.buildings["tower"]["damage"] = tower_dmg
    db.buildings["keep"]["hp"] = keep_hp
    for n in get_nodes_in_group("buildings"):
        if n.id == "keep":
            n.max_hp = keep_hp; n.hp = keep_hp
    inv.add("wood", 500); inv.add("stone", 200)
    main.player.global_position = Vector2(100, 100)
    main.build.player = null
    var vil = main.village
    vil.quota = {"woodcutter": 0, "miner": 0, "farmer": 0, "soldier": soldiers}
    for v in vil.villagers(): v.leave()
    for i in soldiers: vil.spawn_villager(Vector2(520 + i * 5, 522))
    vil.assign_jobs()
    var spots = [Vector2i(35, 33), Vector2i(28, 33), Vector2i(35, 27), Vector2i(28, 27)]
    for i in towers:
        main.build.place("tower", spots[i])
    var wcount = 0
    if walls: wcount = ring(main, 25, 38, 23, 39)
    clock.day = 15
    await ticks(10)
    var keep = null
    for n in get_nodes_in_group("buildings"):
        if n.id == "keep": keep = n
    var won = [false]
    var cb = func(_d): won[0] = true
    root.get_node("Events").game_won.connect(cb)
    await night()
    var t = 0
    while t < 60 * 170 and not won[0] and is_instance_valid(keep) and keep.hp > 0:
        await ticks(60)
        t += 60
    var res = "MENANG" if won[0] else ("KALAH" if (not is_instance_valid(keep) or keep.hp <= 0) else "belum selesai")
    print(label, " | ", res, " ", t / 60, "s keep=", keep.hp if is_instance_valid(keep) else 0, " prajurit=", get_nodes_in_group("defenders").size(), "/", soldiers, " walls=", wcount, " sisa musuh=", get_nodes_in_group("enemies").size())
    root.get_node("Events").game_won.disconnect(cb)
    paused = false
    main.queue_free()
    await ticks(3)

func _initialize() -> void:
    var which = OS.get_environment("CASES")
    var cases = []
    for part in which.split(";"):
        var a = part.split(",")
        cases.append([int(a[0]), int(a[1])])
    for c in cases:
        await run_case("soldiers=%d towers=%d" % [c[0], c[1]], c[0], c[1], false, 2, 12, 1000)
    quit()
