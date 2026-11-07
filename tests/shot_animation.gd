extends SceneTree
var crops: Array = []
func ticks(n: int) -> void:
    for i in n:
        await physics_frame
func crop(label: String, center: Vector2, w := 112, h := 72) -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    var img := root.get_texture().get_image()
    var x := clampi(int(center.x - w / 2.0), 0, 480 - w)
    var y := clampi(int(center.y - h / 2.0), 0, 270 - h)
    var c := img.get_region(Rect2i(x, y, w, h))
    c.resize(w * 4, h * 4, Image.INTERPOLATE_NEAREST)
    crops.append([label, c])
func _initialize() -> void:
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(5)
    var clock = root.get_node("GameClock"); clock.set_process(false)
    var inv = root.get_node("Inventory"); inv.add("wood", 100)
    main.build.player = null
    var p = main.player
    p.camera.position_smoothing_enabled = false
    p.global_position = Vector2(520, 580)
    await ticks(5)
    var sp = main.spawner
    # --- 1. serang: bandit di kanan pemain
    sp.restore_enemy({"id": "bandit", "x": 538, "y": 580, "hp": 60})
    for e in get_nodes_in_group("enemies"): e.set_physics_process(false)
    await ticks(3)
    p.facing = Vector2.RIGHT
    p.anim.face(Vector2.RIGHT)
    p._atk_cd = 0.0
    p._attack()
    # Capture at the authored event times: anticipation, impact, follow-through, recovery.
    await ticks(2); await crop("attack: anticipation", Vector2(240, 135))
    await ticks(4); await crop("attack: commitment", Vector2(240, 135))
    await ticks(1); await crop("attack: impact", Vector2(240, 135))
    await ticks(3); await crop("attack: follow-through", Vector2(240, 135))
    await ticks(5); await crop("attack: recovery", Vector2(240, 135))
    for e in get_nodes_in_group("enemies"): e.retreat()
    # --- 2. lari (tahan Shift + kanan)
    Input.action_press("sprint"); Input.action_press("move_right")
    await ticks(14); await crop("lari (kanan)", Vector2(240, 135))
    await ticks(3); await crop("lari (kanan) 2", Vector2(240, 135))
    Input.action_release("move_right"); Input.action_press("move_down")
    await ticks(14); await crop("lari (turun)", Vector2(240, 135))
    Input.action_release("move_down"); Input.action_press("move_up")
    await ticks(14); await crop("lari (naik)", Vector2(240, 135))
    Input.action_release("move_up"); Input.action_release("sprint")
    await ticks(10)
    # --- 3. jalan kiri
    Input.action_press("move_left")
    await ticks(14); await crop("jalan (kiri)", Vector2(240, 135))
    Input.action_release("move_left")
    await ticks(6)
    # --- 4. mayat: bunuh bandit & serigala
    sp.restore_enemy({"id": "bandit", "x": p.position.x + 22, "y": p.position.y, "hp": 5})
    sp.restore_enemy({"id": "wolf", "x": p.position.x - 24, "y": p.position.y + 2, "hp": 5})
    for e in get_nodes_in_group("enemies"): e.set_physics_process(false); e.take_damage(99)
    await ticks(4); await crop("mati: jatuh", Vector2(240, 135), 144, 72)
    await ticks(12); await crop("mati: terbaring", Vector2(240, 135), 144, 72)
    # --- 5. musuh menyerang bangunan & pemain
    main.build.place("wall", Vector2i(35, 36))
    sp.restore_enemy({"id": "soldier", "x": 575, "y": 590, "hp": 60})
    sp.restore_enemy({"id": "wolf", "x": 520, "y": 560, "hp": 12})
    p.global_position = Vector2(530, 580)
    await ticks(30); await crop("musuh menyerang", Vector2(240, 135), 144, 72)
    # susun lembar kontak
    var cols := 3
    var cw: int = crops[0][1].get_width(); var ch: int = crops[0][1].get_height()
    var rows := int(ceil(crops.size() / float(cols)))
    var sheet := Image.create(cols * (cw + 6), rows * (ch + 6), false, Image.FORMAT_RGBA8)
    sheet.fill(Color("#222"))
    for i in crops.size():
        var c: Image = crops[i][1]
        sheet.blit_rect(c, Rect2i(0, 0, c.get_width(), c.get_height()), Vector2i((i % cols) * (cw + 6), (i / cols) * (ch + 6)))
        print("crop ", i, " ", crops[i][0])
    var output_root := ProjectSettings.globalize_path("res://build/diagnostics/player-animation")
    var frames_dir := output_root.path_join("frames")
    DirAccess.make_dir_recursive_absolute(output_root)
    DirAccess.make_dir_recursive_absolute(frames_dir)
    sheet.save_png(output_root.path_join("player-animation-contact.png"))

    var legend := FileAccess.open(output_root.path_join("frames.txt"), FileAccess.WRITE)
    for i in crops.size():
        var frame_image: Image = crops[i][1]
        frame_image.save_png(frames_dir.path_join("%02d.png" % i))
        legend.store_line("%02d  %s" % [i, crops[i][0]])
    legend.close()
    print("PLAYER_ANIMATION_PLAYBLAST ", output_root)
    quit()
