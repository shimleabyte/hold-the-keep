extends SceneTree
func ticks(n: int) -> void:
    for i in n:
        await physics_frame

var K := 1.0

func mouse_move(p: Vector2) -> void:
    root.warp_mouse(p)   # posisi viewport seperti mouse sungguhan (koordinat 480x270)
    await ticks(2)
    p = p * K
    var m := InputEventMouseMotion.new()
    m.position = p; m.global_position = p
    Input.parse_input_event(m)
    await ticks(2)

func click(p: Vector2, hold := 3) -> void:
    await mouse_move(p)
    p = p * K
    var d := InputEventMouseButton.new()
    d.position = p; d.global_position = p; d.button_index = MOUSE_BUTTON_LEFT; d.pressed = true
    d.button_mask = MOUSE_BUTTON_MASK_LEFT
    Input.parse_input_event(d)
    await ticks(hold)
    var u := InputEventMouseButton.new()
    u.position = p; u.global_position = p; u.button_index = MOUSE_BUTTON_LEFT; u.pressed = false
    Input.parse_input_event(u)
    await ticks(2)

func count_blds() -> int:
    return get_nodes_in_group("buildings").size()

func _initialize() -> void:
    K = float(DisplayServer.window_get_size().x) / 480.0
    print("faktor skala window/viewport: ", K, " window=", DisplayServer.window_get_size(), " root.size=", root.size)
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(5)
    var clock = root.get_node("GameClock"); clock.set_process(false)
    var inv = root.get_node("Inventory"); inv.add("wood", 200); inv.add("stone", 100)
    main.build.player = null
    var hud = null
    for c in main.get_children():
        if c is CanvasLayer and c.get_script().resource_path.ends_with("hud.gd"): hud = c
    var vil = main.village
    await ticks(70)  # biar village_changed terkirim

    # --- 1. tombol + / - job ---
    var q0 = vil.quota["woodcutter"]
    await click(Vector2(467, 27))
    print("J1 klik + penebang: ", q0, " -> ", vil.quota["woodcutter"], " (expect +1)")
    await click(Vector2(424, 27))
    print("J2 klik - penebang: ->", vil.quota["woodcutter"], " (expect ", q0, ")")
    await click(Vector2(424, 27))
    await click(Vector2(424, 27))
    print("J3 klik - dua kali lagi (di bawah 0): ", vil.quota["woodcutter"], " (expect 0, tidak negatif)")
    vil.quota["woodcutter"] = 1

    # --- 2. slot bangunan ---
    await click(Vector2(240, 256))
    print("B1 klik slot Menara: active=", main.build.active, " (expect tower)")
    var n0 = count_blds()
    await click(Vector2(240, 256))
    print("B2 klik slot lagi: active='", main.build.active, "' (expect kosong, toggle)")
    await click(Vector2(100, 256))  # slot 1 (Rumah): x 59..129
    print("B3 klik slot Rumah: active=", main.build.active, " bangunan tetap ", count_blds(), "/", n0, " (klik HUD tidak memasang)")

    # --- 3. pasang di dunia ---
    main.player.global_position = Vector2(300, 700)
    main.player.camera.position_smoothing_enabled = false
    await ticks(5)
    await click(Vector2(240, 150))
    print("B4 klik dunia dgn mode bangun: bangunan ", n0, " -> ", count_blds(), " (expect +1)")

    # --- 4. klik HUD tidak menyerang ---
    main.build._set_active("")
    main.spawner.restore_enemy({"id": "bandit", "x": main.player.position.x + 4, "y": main.player.position.y, "hp": 20})
    await ticks(2)
    var foe = get_nodes_in_group("enemies")[0]
    foe.set_physics_process(false)
    var hp0 = foe.hp
    await mouse_move(Vector2(424, 27))
    print("DBG mouse viewport pos=", root.get_mouse_position(), " blocks=", hud.blocks_mouse(root.get_mouse_position()), " player._click_on_hud=", main.player._click_on_hud(), " F pressed=", Input.is_physical_key_pressed(KEY_F), " joy X=", Input.is_joy_button_pressed(0, JOY_BUTTON_X))
    await click(Vector2(424, 27), 20)
    print("A1 klik panel HUD: hp musuh ", hp0, " -> ", foe.hp, " (expect tidak berubah)")
    await click(Vector2(240, 120), 10)
    print("A2 klik dunia: hp musuh -> ", foe.hp, " (expect turun)")
    quit()
