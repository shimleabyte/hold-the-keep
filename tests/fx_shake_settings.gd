extends SceneTree
func ticks(n: int) -> void:
    for i in n:
        await physics_frame
func _initialize() -> void:
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    await ticks(5)
    var ev = root.get_node("Events"); var st = root.get_node("Settings")
    var fx = null
    for c in main.world.get_children():
        if c.get_script() != null and c.get_script().resource_path.ends_with("fx_layer.gd"): fx = c
    # 1. batas partikel
    for i in 400: ev.fx_burst.emit("spark", Vector2(500, 500), Vector2.ZERO, 3.0)
    print("FX1 setelah 400 ledakan x15: partikel=", fx.count(), " (batas 500)")
    await ticks(90)
    print("FX1 setelah 1.5 detik: partikel=", fx.count(), " (harus 0)")
    ev.fx_burst.emit("tidak_ada", Vector2.ZERO, Vector2.ZERO, 1.0)
    print("FX1 jenis tak dikenal tidak error")
    # 2. guncangan layar + toggle
    var p = main.player
    st.set_screen_shake(true)
    ev.screen_shake.emit(3.0, 0.4)
    await ticks(3)
    var off_on = p.camera.offset
    await ticks(40)
    print("FX2 shake ON: offset saat guncangan=", off_on, " lalu=", p.camera.offset, " (harus (0,0))")
    st.set_screen_shake(false)
    ev.screen_shake.emit(3.0, 0.4)
    await ticks(3)
    print("FX2 shake OFF: offset=", p.camera.offset, " (harus (0,0))")
    var cf = ConfigFile.new(); cf.load("user://settings.cfg")
    print("FX2 tersimpan di settings.cfg: screen_shake=", cf.get_value("display", "screen_shake"))
    st.set_screen_shake(true)
    # 3. tombol menu
    var menu = null
    for c in main.get_children():
        if c.get_script() != null and c.get_script().resource_path.ends_with("pause_menu.gd"): menu = c
    ev.menu_requested.emit()
    await ticks(2)
    var before = st.screen_shake
    menu._sh_btn.pressed.emit()
    print("FX3 tombol menu: ", before, " -> ", st.screen_shake, " teks='", menu._sh_btn.text, "'")
    menu._sh_btn.pressed.emit()
    var esc = InputEventKey.new(); esc.keycode = KEY_ESCAPE; esc.pressed = true
    menu._unhandled_input(esc)
    await ticks(2)
    # 4. performa: 150 musuh bertarung + efek
    root.get_node("GameClock").set_process(false)
    p.global_position = Vector2(100, 100)
    var sp = main.spawner
    sp._pool = root.get_node("DataDB").waves["types"].duplicate()
    for i in 150: sp.spawn_one()
    for i in 40: main.village.spawn_villager(Vector2(520 + randf_range(-30, 30), 522))
    main.village.quota = {"woodcutter": 10, "miner": 8, "farmer": 2, "soldier": 6}
    main.village.assign_jobs()
    await ticks(120)
    var t0 = Time.get_ticks_usec()
    await ticks(300)
    print("FX4 150 musuh + 42 villager + efek: ", snappedf((Time.get_ticks_usec() - t0) / 300.0 / 1000.0, 0.01), " ms/frame, partikel=", fx.count())
    st.set_screen_shake(true); st.set_volume(0.8)
    quit()
