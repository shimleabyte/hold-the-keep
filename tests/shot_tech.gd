extends SceneTree
func ticks(n: int) -> void:
    for i in n:
        await physics_frame
func shot(name: String, scale := 3) -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    var img := root.get_texture().get_image()
    img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
    img.save_png("/tmp/shots/%s.png" % name)
    print("shot ", name)
func _initialize() -> void:
    var T = root.get_node("Tech"); var inv = root.get_node("Inventory")
    T.reset(); inv.reset()
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(5)
    root.get_node("GameClock").set_process(false)
    main.build.player = null
    var p = main.player
    p.camera.position_smoothing_enabled = false
    inv.items = {"wood": 180, "stone": 90, "food": 40, "iron": 35}
    var go = func(id: String) -> void:
        T.start(id); T._process(9999.0)
    for id in ["tools_wood", "farming", "fletching", "masonry", "leather", "iron_mining"]:
        go.call(id)
    main.build.place("forge", Vector2i(36, 30))
    main.build.place("tower", Vector2i(35, 34))
    for x in range(29, 35): main.build.place("stone_wall", Vector2i(x, 37))
    T.start("stone_towers")
    T._process(14.0)
    p.global_position = Vector2(520, 585)
    await ticks(10)
    await shot("tech_hud")
    var panel = null
    for c in main.get_children():
        if c.get_script() != null and c.get_script().resource_path.ends_with("tech_panel.gd"): panel = c
    root.get_node("Events").tech_panel_requested.emit()
    await ticks(3)
    panel._on_node_hover("iron_weapons")
    await shot("tech_panel")
    panel._on_node_hover("stone_towers")
    await ticks(2)
    await shot("tech_panel2")
    var esc = InputEventKey.new(); esc.keycode = KEY_ESCAPE; esc.pressed = true
    panel._unhandled_input(esc)
    await ticks(3)
    # bijih besi: teleport ke urat terdekat
    var ore = null; var bd = 1e9
    for n in get_nodes_in_group("harvestable"):
        if n.yield_kind == "iron":
            var d = p.global_position.distance_to(n.global_position)
            if d < bd: bd = d; ore = n
    p.global_position = ore.global_position + Vector2(0, 16)
    await ticks(10)
    await shot("tech_ore")
    quit()
