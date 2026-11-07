extends SceneTree

var crops: Array = []
var main_player: Variant


func ticks(count: int) -> void:
    for _index in count:
        await process_frame


func advance_animation(seconds: float) -> void:
    # Advance the actual SpriteAnim timeline in exact durations while physics
    # is paused, so capture labels correspond to deterministic atlas markers.
    var remaining := maxf(seconds, 0.0)
    while remaining > 0.000001:
        var step := minf(remaining, 1.0 / 120.0)
        main_player.anim.update(step)
        main_player.queue_redraw()
        remaining -= step
    await process_frame


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


func _initialize() -> void:
    print("PLAYER_PLAYBLAST_BEGIN")
    # Project autoloads must finish their first ready frame before Player._ready connects signals.
    await process_frame
    print("PLAYER_PLAYBLAST_AUTOLOADS_READY")
    var clock := root.get_node_or_null("GameClock")
    if clock != null:
        clock.set_process(false)

    # Lightweight neutral stage: the real Player entity, real sprite atlas,
    # camera and animation code, without booting campaign/world generation.
    var stage := Node2D.new()
    stage.name = "PlayerAnimationPlayblastStage"
    root.add_child(stage)
    current_scene = stage

    var backdrop_layer := CanvasLayer.new()
    backdrop_layer.layer = -1
    root.add_child(backdrop_layer)

    var backdrop := ColorRect.new()
    backdrop.color = Color("#151917")
    backdrop.position = Vector2.ZERO
    backdrop.size = root.get_visible_rect().size
    backdrop_layer.add_child(backdrop)

    var floor := ColorRect.new()
    floor.color = Color("#242825")
    floor.position = Vector2(0, root.get_visible_rect().size.y * 0.68)
    floor.size = Vector2(root.get_visible_rect().size.x, root.get_visible_rect().size.y * 0.32)
    backdrop_layer.add_child(floor)

    var ground_line := ColorRect.new()
    ground_line.color = Color("#555044")
    ground_line.position = Vector2(0, floor.position.y)
    ground_line.size = Vector2(root.get_visible_rect().size.x, 2)
    backdrop_layer.add_child(ground_line)

    print("PLAYER_PLAYBLAST_LOAD_PLAYER_SCRIPT")
    var player_script: GDScript = load("res://scripts/entities/player.gd") as GDScript
    if player_script == null or not player_script.can_instantiate():
        push_error("Player script did not compile after project autoload initialization")
        quit(1)
        return
    print("PLAYER_PLAYBLAST_INSTANTIATE_PLAYER")
    main_player = player_script.new()
    stage.add_child(main_player)
    print("PLAYER_PLAYBLAST_PLAYER_READY")
    main_player.global_position = Vector2.ZERO
    main_player.velocity = Vector2.ZERO
    main_player.facing = Vector2.DOWN
    main_player.anim.face(Vector2.DOWN)
    main_player.camera.position_smoothing_enabled = false
    main_player.camera.make_current()
    await ticks(5)

    var center := root.get_visible_rect().size * 0.5
    print("PLAYER_PLAYBLAST_STAGE_READY size=", root.get_visible_rect().size)

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
    main_player.set_physics_process(false)
    await capture("Player · attack anticipation (frame 10)", center)
    await advance_animation(0.110)
    await capture("Player · attack impact (frame 12 / 0.11s)", center)
    await advance_animation(0.024)
    await capture("Player · attack follow-through (frame 13)", center)
    await advance_animation(0.039)
    await capture("Player · attack recovery (frame 14)", center)
    await advance_animation(0.036)
    await capture("Player · attack finish (frame 15)", center)
    await advance_animation(0.031)
    main_player.set_physics_process(true)

    # Dedicated heavy Cleave sequence. Sample exact authored event/pose markers.
    main_player.level = 2
    main_player._cleave_cd = 0.0
    main_player._use_cleave()
    main_player.set_physics_process(false)
    await capture("Player · Cleave brace (frame 24)", center)
    await advance_animation(0.128)
    await capture("Player · Cleave wind-up (frame 25)", center)
    await advance_animation(0.092)
    await capture("Player · Cleave impact (frame 26 / 0.22s)", center)
    await advance_animation(0.043)
    await capture("Player · Cleave follow-through (frame 27)", center)
    await advance_animation(0.072)
    await capture("Player · Cleave recovery (frame 28)", center)
    await advance_animation(0.067)
    await capture("Player · Cleave final pose (frame 29)", center)
    await advance_animation(0.058)
    main_player.set_physics_process(true)

    # Dash currently reuses the run clip.
    main_player._dash_cd = 0.0
    main_player._use_dash()
    await ticks(4)
    await capture("Player · dash (run clip)", center)
    await ticks(14)

    main_player.anim.play_player_clip("work", true, 14.0)
    await ticks(3)
    await capture("Player · harvest preparation", center)
    await ticks(6)
    await capture("Player · harvest contact", center)
    await ticks(5)
    await capture("Player · harvest recovery", center)

    main_player.anim.play_player_clip("idle", true)
    main_player._invuln = 0.0
    main_player.take_damage(1)
    await ticks(1)
    await capture("Player · hurt recoil", center)

    # Gameplay _die() respawns immediately. Preview the authored death clip
    # independently so the three currently authored frames can be inspected.
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

    var columns := 3
    var frame_width: int = crops[0][1].get_width()
    var frame_height: int = crops[0][1].get_height()
    var rows := int(ceil(crops.size() / float(columns)))
    var contact := Image.create(columns * (frame_width + 8), rows * (frame_height + 8), false, Image.FORMAT_RGBA8)
    contact.fill(Color("#222222"))

    var legend := FileAccess.open(output_root.path_join("frames.txt"), FileAccess.WRITE)
    for index in crops.size():
        var frame: Image = crops[index][1]
        var x := (index % columns) * (frame_width + 8) + 4
        var y := int(index / columns) * (frame_height + 8) + 4
        contact.blit_rect(frame, Rect2i(0, 0, frame_width, frame_height), Vector2i(x, y))
        frame.save_png(frames_dir.path_join("%02d.png" % index))
        legend.store_line("%02d  %s" % [index, crops[index][0]])
    legend.close()

    contact.save_png(output_root.path_join("player-animation-contact.png"))
    print("PLAYER_ANIMATION_PLAYBLAST_COMPLETE frames=", crops.size(), " output=", output_root)
    quit(0)
