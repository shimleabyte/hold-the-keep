extends SceneTree
## Menguji pohon teknologi: syarat, riset, efek, bangunan terkunci, bijih besi, panel, save/load.
func ticks(n: int) -> void:
    for i in n:
        await physics_frame

func _initialize() -> void:
    var T = root.get_node("Tech")
    var inv = root.get_node("Inventory")
    var db = root.get_node("DataDB")
    var ev = root.get_node("Events")
    var ss = root.get_node("SaveSystem")
    DirAccess.remove_absolute("user://save.json")
    T.reset(); inv.reset()
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(5)
    root.get_node("GameClock").set_process(false)
    var b = main.build
    var vil = main.village
    var p = main.player
    var hud = null
    for c in main.get_children():
        if c is CanvasLayer and c.get_script().resource_path.ends_with("hud.gd"): hud = c
    b.player = null
    p.global_position = Vector2(100, 100)

    # ---- 1. data
    var ids = db.tech_order
    var bad = 0
    for id in ids:
        for r in db.techs[id]["requires"]:
            if not db.techs.has(r): bad += 1
    print("TT1 teknologi=", ids.size(), " prasyarat salah=", bad, " era awal=", T.era)

    # ---- 2. alasan penolakan
    inv.items = {"wood": 0, "stone": 0, "food": 0, "iron": 0}
    print("TT2 tanpa bahan: '", T.reason("tools_wood"), "'")
    print("TT2 era terkunci: '", T.reason("tools_stone"), "'")
    inv.items["wood"] = 500; inv.items["stone"] = 500; inv.items["iron"] = 500
    print("TT2 prasyarat: '", T.reason("tools_stone"), "' (era masih 1 -> butuh era)")
    print("TT2 butuh tempa: '", T.reason("iron_weapons"), "'")

    # ---- 3. bangunan terkunci
    var before_n = T.available_buildings().size()
    print("TT3 bangunan tersedia awal=", before_n, " tembok batu: '", b.place("stone_wall", Vector2i(30, 36)), "'")

    # ---- 4. riset berjalan: bayar di awal, satu per satu
    var wood0 = inv.get_amount("wood")
    print("TT4 mulai tools_wood: ", T.start("tools_wood"), " kayu ", wood0, "->", inv.get_amount("wood"), " (expect -15)")
    print("TT4 riset kedua saat sibuk: '", T.reason("farming"), "'")
    T._process(7.5)
    print("TT4 progres setelah 7.5s: ", snappedf(T.progress_ratio(), 0.01), " (expect 0.5)")
    T._process(8.0)
    print("TT4 selesai: ", T.is_done("tools_wood"), " current='", T.current, "'")
    print("TT4 stat carry=", T.stat("villager.carry", 6.0), " (8) gather=", T.stat("villager.gather_speed", 1.0), " (1.2)")

    # ---- 5. efek ke entitas yang sudah ada
    var v = vil.villagers()[0]
    print("TT5 villager: carry_cap=", v._carry_cap(), " (8) interval=", snappedf(v._hit_interval(), 0.001), " (1.0)")
    b.place("tower", Vector2i(35, 34))
    var tower = null
    for n in get_nodes_in_group("buildings"):
        if n.id == "tower": tower = n
    tower.take_damage(50)
    var thp = tower.hp
    var tmax = tower.max_hp
    var research = func(id: String) -> void:
        var d = T.start(id)
        if not d: print("   GAGAL mulai ", id, ": ", T.reason(id))
        T._process(9999.0)
    research.call("fletching")
    research.call("masonry")
    print("TT5 masonry: era=", T.era, " bangunan tersedia=", T.available_buildings().size(), " stone_wall di ujung: ", T.available_buildings()[-1])
    research.call("stone_towers")
    print("TT5 menara hidup: max_hp ", tmax, "->", tower.max_hp, " (300) hp ", thp, "->", tower.hp, " (diskalakan)")
    print("TT5 stat damage menara=", T.stat("tower.damage", 12.0), " (15)  range x", T.stat("tower.range", 1.0), " (1.2)")
    print("TT5 tembok batu kini: '", b.place("stone_wall", Vector2i(30, 36)), "'")

    # ---- 6. rumah, ladang, prajurit
    research.call("longhouse")
    var cap0 = vil.capacity()
    b.place("house", Vector2i(36, 29))
    print("TT6 kapasitas dg rumah panjang: ", cap0, " -> ", vil.capacity(), " (+3 rumah baru = 2+3 per rumah)")
    b.place("farm", Vector2i(27, 34))
    var farm = null
    for n in get_nodes_in_group("farms"): farm = n
    research.call("farming"); research.call("granary")
    print("TT6 slot petani ladang: ", farm.free_slots(), " (3), hasil ladang=", T.stat("farm.yield", 3.0), " (4.5)")
    vil.quota = {"woodcutter": 0, "miner": 0, "farmer": 0, "soldier": 1}
    for x in vil.villagers(): x.leave()
    vil.spawn_villager(Vector2(520, 522))
    vil.assign_jobs()
    var sol = null
    for x in vil.villagers():
        if x.job == "soldier": sol = x
    print("TT6 prajurit awal: hp=", sol.hp, "/", sol.max_hp, " (60)")
    research.call("leather")
    print("TT6 zirah kulit: hp=", sol.hp, "/", sol.max_hp, " (75)")
    research.call("drill")
    print("TT6 damage prajurit=", sol._soldier_damage(), " (10)")

    # ---- 7. besi terkunci lalu terbuka
    var locked_before = get_nodes_in_group("ore_locked").size()
    var harvest_iron_before = 0
    for n in get_nodes_in_group("harvestable"):
        if n.yield_kind == "iron": harvest_iron_before += 1
    print("TT7 bijih terkunci=", locked_before, " (>0) bisa ditambang=", harvest_iron_before, " (0) bendera=", T.has_flag("iron_mining"))
    # coba tambang bijih terkunci: pemain dapat petunjuk
    var ore = get_nodes_in_group("ore_locked")[0]
    var msgs = []
    ev.build_feedback.connect(func(t): msgs.append(t))
    p.global_position = ore.global_position + Vector2(0, 8)
    await ticks(3)
    p._cooldown = 0.0; p._try_interact()
    print("TT7 petunjuk saat menambang bijih terkunci: ", msgs)
    research.call("iron_mining")
    var locked_after = get_nodes_in_group("ore_locked").size()
    var harvest_iron_after = 0
    for n in get_nodes_in_group("harvestable"):
        if n.yield_kind == "iron": harvest_iron_after += 1
    print("TT7 setelah Tambang Besi: terkunci=", locked_after, " bisa ditambang=", harvest_iron_after, " era=", T.era, " tempa tersedia=", T.available_buildings().has("forge"))
    print("TT7 syarat tempa utk Senjata Besi: '", T.reason("iron_weapons"), "'")
    print("TT7 pasang tempa: '", b.place("forge", Vector2i(24, 31)), "'")
    print("TT7 setelah tempa: '", T.reason("iron_weapons"), "' (kosong = boleh)")

    # ---- 8. era 3: efek kumulatif & keep
    var keep = null
    for n in get_nodes_in_group("buildings"):
        if n.id == "keep": keep = n
    research.call("tools_stone")
    research.call("iron_weapons"); research.call("iron_armor"); research.call("iron_towers"); research.call("iron_tools"); research.call("fortress")
    print("TT8 prajurit hp=", sol.max_hp, " (105) damage=", sol._soldier_damage(), " (14) pemain x", T.stat("player.damage", 1.0), " (1.3)")
    print("TT8 keep hp max=", keep.max_hp, " (1500) menara max=", tower.max_hp, " (450) damage menara=", roundi(T.stat("tower.damage", 12.0)), " (22)")
    print("TT8 semua selesai: ", T.researched.size(), "/", ids.size())

    # ---- 9. penambang memilih besi
    inv.items["stone"] = 100; inv.items["iron"] = 0
    var miner = vil.spawn_villager(Vector2(520, 522))
    miner.set_job("miner")
    print("TT9 penambang memilih: ", miner._mine_kind(), " (iron karena stok besi < separuh batu)")
    inv.items["iron"] = 80
    print("TT9 stok besi cukup: ", miner._mine_kind(), " (stone)")

    # ---- 10. HUD
    await ticks(3)
    print("TT10 slot bar bangunan=", hud._slot_nodes.size(), " lebar slot=", hud._slot_nodes[0].size.x, " ikon besi tampak=", hud._iron.visible)
    var xs = []
    for s in hud._slot_nodes: xs.append(int(s.position.x))
    print("TT10 posisi x slot: ", xs, " (dalam 0..480)")

    # ---- 11. save/load
    T.reset(); inv.reset()
    inv.items["wood"] = 300; inv.items["stone"] = 300
    research.call("tools_wood"); research.call("masonry")
    T.start("leather")
    T._process(10.0)
    var done_before = T.researched.duplicate()
    var cur = T.current
    var prog = T.progress
    print("TT11 sebelum save: selesai=", done_before, " berjalan=", cur, " progres=", snappedf(prog, 0.1))
    print("TT11 save: ", ss.save_current(true))
    T.reset()
    print("TT11 setelah reset: selesai=", T.researched.size(), " era=", T.era)
    print("TT11 load: ", ss.request_load())
    await ticks(8)
    print("TT11 sesudah load: selesai=", T.researched, " berjalan=", T.current, " progres=", snappedf(T.progress, 0.1), " era=", T.era, " (leather sedang berjalan ~10s)")

    # ---- 12. panel teknologi
    var main2 = current_scene
    var panel = null
    var menu = null
    for c in main2.get_children():
        if c.get_script() == null: continue
        var path = c.get_script().resource_path
        if path.ends_with("tech_panel.gd"): panel = c
        if path.ends_with("pause_menu.gd"): menu = c
    inv.items["wood"] = 300; inv.items["stone"] = 300
    ev.tech_panel_requested.emit()
    await ticks(3)
    print("TT12 panel terbuka=", panel.is_open(), " paused=", paused, " kotak=", panel._nodes.size(), " (17)")
    var states = {}
    for id in panel._nodes: states[panel._nodes[id].state] = states.get(panel._nodes[id].state, 0) + 1
    print("TT12 status kotak: ", states)
    ev.menu_requested.emit()
    await ticks(2)
    print("TT12 menu tidak terbuka saat panel terbuka: ", not menu.is_open())
    var cur_before = T.current
    panel._on_node_pressed("palisade")
    print("TT12 klik palisade saat riset lain berjalan ('", cur_before, "'): footer='", panel._foot[2].text, "' current='", T.current, "'")
    var esc = InputEventKey.new(); esc.keycode = KEY_ESCAPE; esc.pressed = true
    panel._unhandled_input(esc)
    await ticks(3)
    print("TT12 Esc menutup: terbuka=", panel.is_open(), " paused=", paused)
    T._process(9999.0)
    ev.tech_panel_requested.emit()
    await ticks(3)
    panel._on_node_pressed("palisade")
    print("TT12 klik palisade saat bebas: current='", T.current, "' footer='", panel._foot[2].text, "'")
    var y = InputEventKey.new(); y.keycode = KEY_Y; y.pressed = true
    panel._unhandled_input(y)
    await ticks(2)
    print("TT12 tombol Y menutup: terbuka=", panel.is_open(), " paused=", paused)
    quit()
