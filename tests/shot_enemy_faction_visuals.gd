extends SceneTree
## One gameplay-zoom matrix: faction rows, specialist columns, rendered by the live Enemy scene.

const SpriteAnim := preload("res://scripts/entities/sprite_anim.gd")
const FACTIONS: Array[String] = [
    "greenwood_raiders",
    "iron_legion",
    "fen_cult",
    "ashen_host"
]
const ARCHETYPES: Array[String] = [
    "enemy_scout",
    "enemy_shieldbearer",
    "enemy_saboteur",
    "enemy_war_shaman",
    "enemy_siege_engine",
    "enemy_beast_rider"
]
const OUTPUT_DIR := "/tmp/hold-the-keep-faction-visual-qa"
const CAPTURE_SIZE := Vector2i(640, 360)


func _fail(message: String) -> void:
    push_error("FACTION_VISUAL_QA_FAIL: " + message)
    quit(1)


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var dir_error := DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
    if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
        _fail("Could not create faction visual QA output directory")
        return

    var main_scene := load("res://scenes/main.tscn") as PackedScene
    if main_scene == null:
        _fail("Could not load the gameplay main scene")
        return
    var main := main_scene.instantiate()
    root.add_child(main)
    current_scene = main

    for _frame in 8:
        await process_frame
    if main.player == null or main.world == null or main.flow == null:
        _fail("Gameplay did not finish initializing")
        return

    var data_db = root.get_node_or_null("DataDB")
    var enemy_script := load("res://scripts/entities/enemy.gd") as GDScript
    if enemy_script == null or not enemy_script.can_instantiate():
        _fail("Enemy renderer did not compile after autoload initialization")
        return
    if data_db == null:
        _fail("DataDB autoload is unavailable")
        return
    for enemy_id in ARCHETYPES:
        if not data_db.enemies.has(enemy_id):
            _fail("Missing specialist definition: " + enemy_id)
            return

    var clock = root.get_node_or_null("GameClock")
    if clock != null:
        clock.set_process(false)
        clock.time_of_day = 0.22

    main.player.global_position = main.world.keep_center_position() + Vector2(0, 50)
    main.player.camera.position_smoothing_enabled = false
    main.player.camera.zoom = Vector2.ONE
    main.player.hide()

    var center: Vector2 = main.player.global_position
    for faction_index in FACTIONS.size():
        for archetype_index in ARCHETYPES.size():
            var enemy_data: Dictionary = data_db.enemies[ARCHETYPES[archetype_index]]
            var enemy = enemy_script.new()
            enemy.setup(enemy_data, main.world, main.flow, main.player, FACTIONS[faction_index])
            main.world.add_child(enemy)
            enemy.global_position = center + Vector2(
                (float(archetype_index) - 2.5) * 50.0,
                (float(faction_index) - 1.5) * 44.0
            )
            enemy.set_process(false)
            enemy.set_physics_process(false)
            enemy.anim.view = SpriteAnim.SIDE
            enemy.anim.flip = archetype_index % 2 == 1
            enemy.anim.play("idle", true)
            enemy.queue_redraw()

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
    var output_path := "%s/faction-specialist-gameplay.png" % OUTPUT_DIR
    if output.save_png(output_path) != OK:
        _fail("Could not save gameplay screenshot")

    print("FACTION_VISUAL_MATRIX rows=greenwood_raiders,iron_legion,fen_cult,ashen_host")
    print("FACTION_VISUAL_MATRIX columns=scout,shieldbearer,saboteur,war_shaman,siege_engine,beast_rider")
    print("FACTION_VISUAL_CAPTURE ", output_path)
    print("PASS: all 24 faction/specialist combinations rendered at normal gameplay zoom")
    quit(0)
