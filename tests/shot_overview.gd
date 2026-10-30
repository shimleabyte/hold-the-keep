extends SceneTree

func ticks(n: int) -> void:
    for i in n:
        await physics_frame

func shot(name: String) -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    var img := root.get_texture().get_image()
    print("shot ", name, " ", img.get_width(), "x", img.get_height())
    img.save_png("/tmp/shots/%s_1x.png" % name)
    img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
    img.save_png("/tmp/shots/%s.png" % name)

func _initialize() -> void:
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(5)
    var clock = root.get_node("GameClock")
    var inv = root.get_node("Inventory")
    clock.set_process(false)
    inv.add("wood", 300); inv.add("stone", 120); inv.add("food", 40)
    main.build.player = null
    main.player.camera.position_smoothing_enabled = false
    main.player.global_position = Vector2(520, 575)
    main.build.place("house", Vector2i(36, 29))
    main.build.place("tower", Vector2i(35, 33))
    main.build.place("tower", Vector2i(27, 33))
    main.build.place("farm", Vector2i(37, 34))
    main.build.place("storage", Vector2i(26, 28))
    for x in range(29, 35): main.build.place("wall", Vector2i(x, 36))
    main.village.quota = {"woodcutter": 2, "miner": 1, "farmer": 1, "soldier": 2}
    for i in 5: main.village.spawn_villager(Vector2(500 + i * 8, 522))
    main.village.assign_jobs()
    await ticks(60 * 9)
    var fr = {}
    for v in get_nodes_in_group("villagers"): fr[v.state] = fr.get(v.state, 0) + 1
    print("villager states: ", fr, " frames: ", get_nodes_in_group("villagers").map(func(v): return v.anim.frame_index()))
    print("player frame: ", main.player.anim.frame_index())
    await shot("day")
    var hud = null
    for c in main.get_children():
        if c is CanvasLayer and c.get_script().resource_path.ends_with("hud.gd"): hud = c
    hud._help.visible = true
    await ticks(3)
    await shot("help")
    hud._help.visible = false

    # ---- malam + musuh ----
    clock.set_process(true); clock.time_of_day = 0.66
    await ticks(2); clock.set_process(false)
    main.spawner.restore_enemy({"id": "bandit", "x": 600, "y": 540, "hp": 12})
    main.spawner.restore_enemy({"id": "bandit", "x": 610, "y": 560, "hp": 20})
    main.spawner.restore_enemy({"id": "wolf", "x": 640, "y": 525, "hp": 6})
    main.spawner.restore_enemy({"id": "soldier", "x": 430, "y": 560, "hp": 40})
    main.spawner.restore_enemy({"id": "wolf", "x": 420, "y": 540, "hp": 12})
    main.player._swing = 0.15
    await ticks(40)
    print("enemy frames: ", get_nodes_in_group("enemies").map(func(e): return [e.id, e.anim.frame_index(), e._moving]))
    await shot("night")

    # ---- boss ----
    for e in get_nodes_in_group("enemies"): e.retreat()
    main.spawner.restore_enemy({"id": "king", "x": 590, "y": 575, "hp": 420})
    main.spawner.restore_enemy({"id": "soldier", "x": 560, "y": 590, "hp": 60})
    main.spawner.restore_enemy({"id": "bandit", "x": 625, "y": 592, "hp": 20})
    for n in get_nodes_in_group("buildings"):
        if n.id == "keep": n.take_damage(380)
    await ticks(20)
    await shot("boss")

    # ---- mode bangun: ghost ----
    clock.set_process(true); clock.time_of_day = 0.2
    await ticks(2); clock.set_process(false)
    for e in get_nodes_in_group("enemies"): e.retreat()
    main.build._set_active("tower")
    root.warp_mouse(Vector2(230, 150))
    await ticks(10)
    print("mouse over hud @(240,5): ", hud.blocks_mouse(Vector2(240, 5)), " @(240,120): ", hud.blocks_mouse(Vector2(240, 120)), " @(200,255): ", hud.blocks_mouse(Vector2(200, 255)))
    await shot("build")
    quit()
