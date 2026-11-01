extends SceneTree
var clock
func ticks(n: int) -> void:
    for i in n:
        await physics_frame

func snap(main) -> Dictionary:
    var blds = {}
    var bhp = 0
    for b in get_nodes_in_group("buildings"):
        blds[b.id] = blds.get(b.id, 0) + 1
        bhp += b.hp
    var jobs = {}
    var vhp = 0
    var carry = 0
    for v in get_nodes_in_group("villagers"):
        jobs[v.job] = jobs.get(v.job, 0) + 1
        vhp += v.hp
        carry += v.carry
    var ehp = 0
    for e in get_nodes_in_group("enemies"): ehp += e.hp
    return {"blds": blds, "bhp": bhp, "jobs": jobs, "vhp": vhp, "carry": carry,
        "enemies": get_nodes_in_group("enemies").size(), "ehp": ehp,
        "inv": root.get_node("Inventory").items.duplicate(),
        "day": clock.day, "night": clock.is_night, "t": snappedf(clock.time_of_day, 0.001),
        "php": main.player.hp, "ppos": main.player.position.snapped(Vector2(0.01, 0.01)),
        "quota": main.village.quota.duplicate()}

func _initialize() -> void:
    var inv = root.get_node("Inventory")
    var ev = root.get_node("Events")
    var ss = root.get_node("SaveSystem")
    DirAccess.remove_absolute("user://save.json")
    DirAccess.remove_absolute("user://save.bak")
    DirAccess.remove_absolute("user://save.tmp")
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(3)
    clock = root.get_node("GameClock")
    clock.reset(); clock.set_process(false)
    print("S0 has_save before: ", ss.has_save())

    # ---- skenario ----
    inv.add("wood", 300); inv.add("stone", 100); inv.add("food", 40)
    main.player.global_position = Vector2(100, 100)
    main.build.player = null
    main.build.place("house", Vector2i(36, 30))
    main.build.place("tower", Vector2i(35, 34))
    main.build.place("farm", Vector2i(27, 34))
    main.build.place("storage", Vector2i(28, 28))
    for i in 3: main.village.spawn_villager(Vector2(520 + i * 5, 522))
    main.village.quota = {"woodcutter": 2, "miner": 1, "farmer": 1, "soldier": 1}
    main.village.assign_jobs()
    await ticks(60 * 10)
    clock.day = 5
    clock.set_process(true); clock.time_of_day = 0.65
    await ticks(2); clock.set_process(false)
    await ticks(60 * 20)
    for n in get_nodes_in_group("buildings"):
        if n.id == "keep": n.take_damage(137)
    main.player.take_damage(23)
    var before = snap(main)
    for v in get_nodes_in_group("villagers"):
        if v.job == "soldier": print("S1 soldier hp before save = ", v.hp)
    print("S1 before save: blds=", before.blds, " villagers=", before.jobs, " enemies=", before.enemies, " keep+bhp=", before.bhp, " php=", before.php, " day=", before.day, " night=", before.night)
    print("S1 save_current -> ", ss.save_current(), " file exists=", ss.has_save())

    # ubah state supaya beda
    for e in get_nodes_in_group("enemies"): e.retreat()
    inv.items["wood"] = 1
    for v in get_nodes_in_group("villagers"): v.leave()
    clock.day = 9
    await ticks(3)

    # ---- load ----
    print("S2 request_load -> ", ss.request_load())
    await ticks(1)
    var main2 = current_scene
    print("S2 scene replaced: ", main2 != main, " is valid new main: ", is_instance_valid(main2) and main2.is_in_group("main"))
    var after = snap(main2)
    var same = true
    for k in before:
        if str(before[k]) != str(after[k]):
            same = false
            print("   DIFF ", k, ": ", before[k], " -> ", after[k])
    print("S2 state identical after load: ", same)
    print("S2 keep hp restored: ", after.bhp == before.bhp, " enemies ", before.enemies, "->", after.enemies)

    # setelah load, simulasi lanjut tanpa error, wave tidak ganda
    await ticks(60 * 8)
    print("S3 after 8s more: enemies=", get_nodes_in_group("enemies").size(), " villagers=", get_nodes_in_group("villagers").size(), " night=", clock.is_night)

    # ---- autosave ----
    DirAccess.remove_absolute("user://save.json")
    DirAccess.remove_absolute("user://save.bak")
    print("S4 has_save after delete: ", ss.has_save())
    ev.day_changed.emit(6)
    await ticks(2)
    print("S4 autosave on day change -> has_save=", ss.has_save())

    # ---- save rusak tanpa rollback copy ----
    DirAccess.remove_absolute("user://save.bak")
    var f = FileAccess.open("user://save.json", FileAccess.WRITE)
    f.store_string("{ini bukan json"); f.close()
    print("S5 corrupt save -> request_load=", ss.request_load(), " (expect false), scene intact=", is_instance_valid(current_scene))
    f = FileAccess.open("user://save.json", FileAccess.WRITE)
    f.store_string('{"version": 99, "buildings": []}'); f.close()
    print("S5 wrong version -> request_load=", ss.request_load(), " (expect false)")
    ss.save_current(true)

    # ---- audio ----
    var au = root.get_node("Audio")
    var ok = true
    for n in ["chop", "mine", "swing", "build", "crash", "kill", "hurt", "horn", "dawn", "win", "lose", "event"]:
        if not au.has_sound(n) or au._sounds[n].data.size() < 100: ok = false; print("   missing ", n)
        au._silent_until = 0
        au._last.clear()
        au.play(n)
    print("A1 all 12 sounds generated & played: ", ok, " horn bytes=", au._sounds["horn"].data.size())

    # ---- menu & settings ----
    var cur = current_scene
    var menu = null
    for c in cur.get_children():
        if c.get_script() != null and c.get_script().resource_path.ends_with("pause_menu.gd"): menu = c
    ev.menu_requested.emit()
    await ticks(2)
    print("M1 menu open: ", menu.is_open(), " paused=", paused)
    menu._fs_btn.pressed.emit()
    menu._vs_btn.pressed.emit()
    menu._vol.value = 0.4
    var st = root.get_node("Settings")
    print("M2 settings: fullscreen=", st.fullscreen, " vsync=", st.vsync, " volume=", st.volume, " (expect true, false, 0.4)")
    var cf = ConfigFile.new()
    cf.load("user://settings.cfg")
    print("M2 settings.cfg: ", cf.get_value("display", "fullscreen"), cf.get_value("display", "vsync"), cf.get_value("audio", "volume"))
    var esc = InputEventKey.new(); esc.keycode = KEY_ESCAPE; esc.pressed = true
    menu._unhandled_input(esc)
    await ticks(2)
    print("M3 closed with Esc: ", not menu.is_open(), " paused=", paused)
    st.set_fullscreen(false); st.set_vsync(true); st.set_volume(0.8)
    quit()
