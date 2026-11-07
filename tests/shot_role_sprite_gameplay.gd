extends SceneTree
## Captures the ten civilian professions together in the real game viewport.
## Run with HTK_AUTO_START_GAME=1 under desktop GL or Xvfb + Mesa.

const SpriteAnim := preload("res://scripts/entities/sprite_anim.gd")
const OUTPUT_DIR := "/tmp/hold-the-keep-role-visual-qa"
const CAPTURE_SIZE := Vector2i(640, 360)


func _fail(message: String) -> void:
    push_error("ROLE_VISUAL_QA_FAIL: " + message)
    quit(1)


func _initialize() -> void:
    var dir_error := DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
    if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
        _fail("Could not create role visual QA output directory")
        return

    var main_scene := load("res://scenes/main.tscn") as PackedScene
    if main_scene == null:
        _fail("Could not load the gameplay main scene")
        return
    var main := main_scene.instantiate()
    root.add_child(main)
    current_scene = main

    for _frame in 6:
        await process_frame
    if main.player == null or main.world == null or main.village == null or main.spawner == null:
        _fail("Gameplay did not finish initializing; ensure HTK_AUTO_START_GAME=1")
        return

    var clock = root.get_node_or_null("GameClock")
    if clock != null:
        clock.set_process(false)
        clock.time_of_day = 0.22

    var keep_center: Vector2 = main.world.keep_center_position()
    main.player.global_position = keep_center + Vector2(0, 50)
    main.player.camera.position_smoothing_enabled = false
    main.player.camera.zoom = Vector2.ONE

    var roles: Array[String] = [
        "woodcutter", "miner", "farmer", "builder", "blacksmith",
        "hunter", "scout", "healer", "soldier", ""
    ]
    var work_roles := ["woodcutter", "miner", "farmer", "builder", "blacksmith"]
    var spawned := 0
    for index in roles.size():
        var column := index % 5
        var row := int(index / 5)
        var offset := Vector2((column - 2) * 58.0, -76.0 + row * 42.0)
        var villager = main.village.spawn_villager(main.player.global_position + offset)
        if villager == null:
            _fail("Could not spawn civilian role: " + roles[index])
            return
        villager.job = roles[index]
        villager.set_process(false)
        villager.set_physics_process(false)
        villager.anim.view = index % 3
        villager.anim.flip = (index % 2) == 1
        villager.anim.work_style = roles[index]
        if work_roles.has(roles[index]):
            villager.anim.play("work", true)
            villager.anim.manual_progress = 0.5
        elif roles[index] == "soldier":
            villager.anim.play("attack", true)
            villager.anim.manual_progress = 0.5
        else:
            villager.anim.play("idle", true)
            villager.anim.manual_progress = 0.5
        villager.queue_redraw()
        spawned += 1

    if spawned != roles.size():
        _fail("Not all ten civilian professions were spawned")
        return

    # spawn_villager() schedules a quota-based auto-assignment pass. Freeze that
    # scheduler for this visual-only fixture so it cannot overwrite the ten roles.
    main.village.set_process(false)

    for _frame in 4:
        await process_frame
    await RenderingServer.frame_post_draw

    var image := root.get_texture().get_image()
    if image == null or image.is_empty():
        _fail("Gameplay viewport returned an empty capture")
        return
    if image.get_width() < CAPTURE_SIZE.x or image.get_height() < CAPTURE_SIZE.y:
        _fail("Gameplay capture is smaller than the configured logical viewport")

    var output := image.get_region(Rect2i(
        (image.get_width() - CAPTURE_SIZE.x) / 2,
        (image.get_height() - CAPTURE_SIZE.y) / 2,
        CAPTURE_SIZE.x,
        CAPTURE_SIZE.y
    ))
    var base_path := "%s/all-civilian-roles-gameplay.png" % OUTPUT_DIR
    var save_error := output.save_png(base_path)
    if save_error != OK:
        _fail("Could not save gameplay screenshot")
        return

    var enlarged := output.duplicate()
    enlarged.resize(CAPTURE_SIZE.x * 3, CAPTURE_SIZE.y * 3, Image.INTERPOLATE_NEAREST)
    var enlarged_error: Error = enlarged.save_png("%s/all-civilian-roles-gameplay-3x.png" % OUTPUT_DIR)
    if enlarged_error != OK:
        _fail("Could not save enlarged gameplay screenshot")
        return

    print("ROLE_VISUAL_QA_CAPTURE ", base_path)
    print("ROLE_VISUAL_QA_CAPTURE_3X ", "%s/all-civilian-roles-gameplay-3x.png" % OUTPUT_DIR)
    print("ROLE_VISUAL_QA_ROLES civilian_professions=10")
    print("PASS: all ten civilian professions rendered in the real gameplay viewport")
    quit(0)
