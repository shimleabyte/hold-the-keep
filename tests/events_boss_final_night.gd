extends SceneTree
var clock
func ticks(n: int) -> void:
    for i in n:
        await physics_frame

func boot() -> Node:
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    await ticks(3)
    clock = root.get_node("GameClock")
    clock.reset()
    clock.set_process(false)
    root.get_node("Inventory").reset()
    root.get_node("Events").connect("game_won", func(_d): pass)
    return main

func night() -> void:
    clock.set_process(true)
    clock.time_of_day = 0.65
    await ticks(2)
    clock.set_process(false)

func defend(main, soldiers: int, towers: int) -> void:
    var inv = root.get_node("Inventory")
    inv.add("wood", 300); inv.add("stone", 200)
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

func _initialize() -> void:
    var inv = root.get_node("Inventory")
    var main = await boot()
    var em = main.events
    var vil = main.village

    # ---- E1: efek event ----
    inv.items["wood"] = 30; inv.items["food"] = 20; inv.items["stone"] = 0
    em.trigger("trader")
    print("E1 trader: wood ", 30, "->", inv.get_amount("wood"), " food 20->", inv.get_amount("food"), " (expect 20, 35)")
    em.trigger("harvest")
    print("E1 harvest: food ->", inv.get_amount("food"), " (expect 47)")
    em.trigger("stone_find")
    print("E1 stone_find: stone ->", inv.get_amount("stone"), " (expect 8)")
    em.trigger("famine")
    print("E1 famine: food ->", inv.get_amount("food"), " (expect 24)")
    var pop0 = vil.population()
    em.trigger("plague")
    await ticks(2)
    print("E1 plague: pop ", pop0, "->", vil.population(), " (expect 1)")
    em.trigger("plague")
    print("E1 plague eligible at pop 1? ", em._eligible({"from_day": 1, "effects": {"villagers": -1}}, 9), " (expect false)")

    # ---- E2: seleksi event ----
    var seen = {}
    for i in 300:
        var ev = em.pick(2)
        if not ev.is_empty(): seen[ev["id"]] = seen.get(ev["id"], 0) + 1
    print("E2 day-2 picks: ", seen, " (only trader/harvest expected)")
    var seen9 = {}
    inv.items["food"] = 50; inv.items["wood"] = 50
    for i in 600:
        var ev = em.pick(9)
        if not ev.is_empty(): seen9[ev["id"]] = seen9.get(ev["id"], 0) + 1
    print("E2 day-9 picks (pop 1/cap 2): ", seen9, " (plague must be absent, refugees present)")

    # ---- E3: hari terakhir tidak ada event acak ----
    var banner = [0]
    root.get_node("Events").event_triggered.connect(func(_t, _x): banner[0] += 1)
    for i in 40: em._on_day_changed(15)
    print("E3 events on final day x40: ", banner[0], " (expect 0)")
    var b2 = 0
    for i in 200: em._on_day_changed(5)
    print("E3 events on day 5 x200: ", banner[0], " (expect ~120)")
    main.queue_free()
    await ticks(3)

    # ---- B1: boss muncul, tidak mundur, menang ----
    main = await boot()
    clock.day = 15
    await night()
    await ticks(60 * 6)
    var bosses = []
    for e in get_nodes_in_group("enemies"):
        if e.is_boss: bosses.append(e)
    print("B1 final night: enemies=", get_nodes_in_group("enemies").size(), " bosses=", bosses.size(), " boss hp=", bosses[0].hp if bosses.size() > 0 else "-")
    main.spawner.end_wave()
    await ticks(2)
    var still = 0
    for e in get_nodes_in_group("enemies"):
        if e.is_boss: still += 1
    print("B1 after dawn: bosses left=", still, " others left=", get_nodes_in_group("enemies").size() - still, " (expect 1, 0)")
    var won = [false]
    root.get_node("Events").game_won.connect(func(_d): won[0] = true)
    bosses[0].take_damage(99999)
    await ticks(3)
    var hud = null
    for c in main.get_children():
        if c is CanvasLayer and c.get_script().resource_path.ends_with("hud.gd"): hud = c
    print("B1 boss killed -> won=", won[0], " paused=", paused, " overlay=", hud._over.visible, " text=", hud._over_label.text.replace("\n", " | "))
    paused = false
    main.queue_free()
    await ticks(3)

    # ---- B2: malam terakhir, dua tingkat pertahanan ----
    for cfg in [[0, 0, "tanpa pertahanan"], [4, 2, "4 prajurit + 2 menara"], [8, 4, "8 prajurit + 4 menara"]]:
        main = await boot()
        clock.day = 15
        await defend(main, cfg[0], cfg[1])
        await ticks(10)
        var keep = null
        for n in get_nodes_in_group("buildings"):
            if n.id == "keep": keep = n
        var won2 = [false]
        var cb = func(_d): won2[0] = true
        root.get_node("Events").game_won.connect(cb)
        await night()
        var t = 0
        while t < 60 * 150 and not won2[0] and is_instance_valid(keep) and keep.hp > 0:
            await ticks(60)
            t += 60
        var alive = get_nodes_in_group("defenders").size()
        print("B2 ", cfg[2], ": ", "MENANG" if won2[0] else ("KALAH" if (not is_instance_valid(keep) or keep.hp <= 0) else "belum selesai"), " dalam ", t / 60, "s, keep hp=", keep.hp if is_instance_valid(keep) else 0, " prajurit hidup=", alive, "/", cfg[0], " musuh tersisa=", get_nodes_in_group("enemies").size())
        root.get_node("Events").game_won.disconnect(cb)
        paused = false
        main.queue_free()
        await ticks(3)
    quit()
