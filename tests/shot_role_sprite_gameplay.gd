extends SceneTree
## Captures Builder, Archer and Brute together in the real game viewport.
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

    var builder = main.village.spawn_villager(main.player.global_position + Vector2(-32, 0))
    builder.job = "builder"
    builder.set_process(false)
    builder.set_physics_process(false)
    builder.anim.view = SpriteAnim.SIDE
    builder.anim.flip = false
    builder.anim.play("work", true)
    builder.anim.manual_progress = 0.5
    builder.queue_redraw()

    main.spawner.restore_enemy({
        "id": "archer",
        "x": main.player.global_position.x + 16,
        "y": main.player.global_position.y - 4,
        "hp": 28
    })
    main.spawner.restore_enemy({
        "id": "brute",
        "x": main.player.global_position.x + 54,
        "y": main.player.global_position.y + 2,
        "hp": 110
    })

    var found := {"archer": false, "brute": false}
    for enemy in get_nodes_in_group("enemies"):
        if enemy.id != "archer" and enemy.id != "brute":
            continue
        enemy.set_process(false)
        enemy.set_physics_process(false)
        enemy.anim.play("attack", true)
        enemy.anim.manual_progress = 0.55
        enemy.anim.face(Vector2.LEFT)
        enemy.queue_redraw()
        found[String(enemy.id)] = true

    if not bool(found["archer"]) or not bool(found["brute"]):
        _fail("Could not spawn both dedicated enemy roles in the gameplay scene")
        return

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
    var base_path := "%s/role-sprites-gameplay.png" % OUTPUT_DIR
    var save_error := output.save_png(base_path)
    if save_error != OK:
        _fail("Could not save gameplay screenshot")
        return

    var enlarged := output.duplicate()
    enlarged.resize(CAPTURE_SIZE.x * 3, CAPTURE_SIZE.y * 3, Image.INTERPOLATE_NEAREST)
    var enlarged_error: Error = enlarged.save_png("%s/role-sprites-gameplay-3x.png" % OUTPUT_DIR)
    if enlarged_error != OK:
        _fail("Could not save enlarged gameplay screenshot")
        return

    print("ROLE_VISUAL_QA_CAPTURE ", base_path)
    print("ROLE_VISUAL_QA_CAPTURE_3X ", "%s/role-sprites-gameplay-3x.png" % OUTPUT_DIR)
    print("ROLE_VISUAL_QA_ROLES builder=1 archer=1 brute=1")
    print("PASS: role-specific sprites rendered in the real gameplay viewport")
    quit(0)
