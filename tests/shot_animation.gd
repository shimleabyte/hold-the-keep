extends SceneTree

var crops: Array = []


func ticks(count: int) -> void:
    for _index in count:
        await physics_frame


func capture(label: String, center: Vector2, width := 144, height := 96) -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    if image == null:
        push_error("Player animation playblast could not read the rendered viewport")
        return
    var viewport_size := root.get_visible_rect().size
    var x := clampi(int(center.x - width / 2.0), 0, maxi(0, int(viewport_size.x) - width))
    var y := clampi(int(center.y - height / 2.0), 0, maxi(0, int(viewport_size.y) - height))
    var frame := image.get_region(Rect2i(x, y, width, height))
    frame.resize(width * 3, height * 3, Image.INTERPOLATE_NEAREST)
    crops.append([label, frame])
    print("PLAYER_PLAYBLAST_FRAME ", label, " atlas=", main_player.anim.frame_index())


var main_player: Player


func _initialize() -> void:
    var main := load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(5)

    var clock := root.get_node("GameClock")
    clock.set_process(false)
    main.build.player = null
    main_player = main.player as Player
    main_player.camera.position_smoothing_enabled = false
    main_player.global_position = Vector2(520, 580)
    main_player.velocity = Vector2.ZERO
    main_player.facing = Vector2.DOWN
    main_player.anim.face(Vector2.DOWN)
    await ticks(5)

    var center := root.get_visible_rect().size * 0.5

    main_player.anim.play_player_clip("idle", true)
    await ticks(12)
    await capture("Player · idle", center)

    Input.action_press("move_right")
    await ticks(12)
    await capture("Player · walk right", center)
    Input.action_press("sprint")
    await ticks(12)
    await capture("Player · run right", center)
    Input.action_release("move_right")
    Input.action_release("sprint")
    await ticks(4)

    main_player.facing = Vector2.RIGHT
    main_player.anim.face(Vector2.RIGHT)
    main_player._atk_cd = 0.0
    main_player._attack()
    await ticks(2)
    await capture("Player · attack anticipation", center)
    await ticks(4)
    await capture("Player · attack commitment", center)
    await ticks(1)
    await capture("Player · attack impact", center)
    await ticks(3)
    await capture("Player · attack follow-through", center)
    await ticks(5)
    await capture("Player · attack recovery", center)

    # Cleave currently shares the six-frame attack vocabulary. The label makes
    # that limitation visible instead of presenting it as a unique heavy swing.
    main_player.level = 2
    main_player._cleave_cd = 0.0
    main_player._use_cleave()
    await ticks(5)
    await capture("Player · Cleave (shared attack poses)", center)
    await ticks(10)

    # Dash currently reuses the run clip; keep the preview explicit about it.
    main_player._dash_cd = 0.0
    main_player._use_dash()
    await ticks(4)
    await capture("Player · dash (run clip)", center)
    await ticks(14)

    main_player.anim.play_player_clip("work", true, 14.0)
    await ticks(3)
    await capture("Player · harvest preparation", center)
    await ticks(5)
    await capture("Player · harvest contact", center)
    await ticks(5)
    await capture("Player · harvest recovery", center)

    main_player._invuln = 0.0
    main_player.take_damage(1)
    await ticks(1)
    await capture("Player · hurt recoil", center)

    # The actual _die() gameplay path immediately respawns at spawn_pos. To
    # inspect the currently authored death clip without altering gameplay,
    # pause only this preview actor and advance the presentation timeline.
    main_player.set_physics_process(false)
    main_player.anim.play_player_clip("death", true)
    await capture("Player · death fall 1", center)
    main_player.anim.update(1.0 / 6.0)
    main_player.queue_redraw()
    await capture("Player · death fall 2", center)
    main_player.anim.update(1.0 / 6.0)
    main_player.queue_redraw()
    await capture("Player · death settled", center)

    if crops.is_empty():
        push_error("Player animation playblast produced no frames")
        quit(1)
        return

    var output_root := ProjectSettings.globalize_path("res://build/diagnostics/player-animation")
    var frames_dir := output_root.path_join("frames")
    DirAccess.make_dir_recursive_absolute(output_root)
    DirAccess.make_dir_recursive_absolute(frames_dir)

    var cols := 3
    var frame_width: int = crops[0][1].get_width()
    var frame_height: int = crops[0][1].get_height()
    var rows := int(ceil(crops.size() / float(cols)))
    var contact := Image.create(cols * (frame_width + 8), rows * (frame_height + 8), false, Image.FORMAT_RGBA8)
    contact.fill(Color("#222222"))

    var legend := FileAccess.open(output_root.path_join("frames.txt"), FileAccess.WRITE)
    for index in crops.size():
        var frame: Image = crops[index][1]
        var x := (index % cols) * (frame_width + 8) + 4
        var y := int(index / cols) * (frame_height + 8) + 4
        contact.blit_rect(frame, Rect2i(0, 0, frame_width, frame_height), Vector2i(x, y))
        frame.save_png(frames_dir.path_join("%02d.png" % index))
        legend.store_line("%02d  %s" % [index, crops[index][0]])
    legend.close()
    contact.save_png(output_root.path_join("player-animation-contact.png"))
    print("PLAYER_ANIMATION_PLAYBLAST_COMPLETE frames=", crops.size(), " output=", output_root)
    quit(0)
