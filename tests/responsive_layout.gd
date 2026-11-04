extends SceneTree
## Resolution-derived viewport and HUD safe-area regression coverage.

const RESOLUTION_CASES := [
    {"window": Vector2i(960, 540), "viewport": Vector2i(480, 270)},
    {"window": Vector2i(1280, 720), "viewport": Vector2i(640, 360)},
    {"window": Vector2i(1280, 800), "viewport": Vector2i(640, 400)},
    {"window": Vector2i(1366, 768), "viewport": Vector2i(683, 384)},
    {"window": Vector2i(1600, 900), "viewport": Vector2i(800, 450)},
    {"window": Vector2i(1920, 1080), "viewport": Vector2i(960, 540)}
]


func _initialize() -> void:
    var game_clock = root.get_node("GameClock")
    var settings = root.get_node("Settings")
    DirAccess.remove_absolute("user://save.json")
    DirAccess.remove_absolute("user://save.tmp")
    DirAccess.remove_absolute("user://save.bak")

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await process_frame
    await process_frame
    game_clock.set_process(false)

    assert(String(ProjectSettings.get_setting("display/window/stretch/aspect")) == "expand",
        "The project must expand the viewport instead of cropping or distorting the game")
    assert(String(ProjectSettings.get_setting("display/window/stretch/mode")) == "viewport",
        "Pixel-art world rendering must remain viewport-based")
    assert(String(ProjectSettings.get_setting("display/window/stretch/scale_mode")) == "integer",
        "Pixel-art scaling must remain integer-based")
    assert(int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 640
        and int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 360,
        "The design viewport must match the default 1280x720 window at 2x scale")
    assert(root.min_size.x >= 960 and root.min_size.y >= 540,
        "Runtime window minimum size must remain laptop-friendly")
    assert(int(ProjectSettings.get_setting("display/window/size/initial_position_type")) == 1,
        "The initial window must be centered on the primary screen")
    assert(settings.windowed_size.x >= 960 and settings.windowed_size.y >= 540,
        "Saved windowed size must satisfy the minimum display dimensions")

    for size_case in RESOLUTION_CASES:
        var window_size: Vector2i = size_case["window"]
        var expected: Vector2i = size_case["viewport"]
        assert(settings.viewport_size_for_window(window_size) == expected,
            "Viewport must be derived from the matching physical window resolution")

    var live_window_size: Vector2i = DisplayServer.window_get_size()
    if live_window_size.x <= 0 or live_window_size.y <= 0:
        live_window_size = settings.windowed_size
    settings._sync_content_viewport(live_window_size)
    await process_frame
    assert(root.content_scale_size == settings.viewport_size_for_window(live_window_size),
        "The live content viewport must match half the actual client-window size")

    var hud = get_first_node_in_group("hud")
    assert(hud != null, "The main scene must create the HUD")
    assert(hud._msg_bubble is Panel and hud._msg.get_parent() == hud._msg_bubble,
        "Transient gameplay feedback must use a compact bubble, not full-width floating text")
    assert(hud._msg_bubble.mouse_filter == Control.MOUSE_FILTER_IGNORE,
        "The feedback bubble must never block world interaction")
    assert(not hud._stage_label.visible and not hud._boss_title.visible,
        "Stage and boss names must remain contextual rather than permanent text")
    for job_id in hud._jobs:
        var job_row = hud._jobs[job_id]
        assert(job_row.icon != null and not job_row.tooltip_text.is_empty(),
            "Icon-first job rows must retain an accessible text description")
    for slot in hud._slot_nodes:
        assert(not slot.tooltip_text.is_empty(),
            "Icon-only building slots must expose names, costs and hotkeys on demand")
    hud._show_message("HUD bubble accessibility check")
    assert(hud._msg_bubble.visible and hud._msg.text == "HUD bubble accessibility check",
        "Gameplay feedback must appear in the contextual bubble")
    assert(is_equal_approx(hud._message_duration("HUD bubble accessibility check"), 2.0),
        "Ordinary feedback must retain its compact two-second lifetime")
    assert(is_equal_approx(hud._message_duration("Raja lawan mendekat! Bersiap."), 4.0),
        "The final boss warning must remain visible for its full four-second telegraph")

    assert(hud._clock_widget.size.y == 18,
        "The clock must reserve a second line for the next phase countdown")
    game_clock.time_of_day = 0.5
    assert(hud._clock_widget.countdown_text() == "MALAM 00:18",
        "The clock must display the exact time remaining until night")
    game_clock.time_of_day = 0.75
    assert(hud._clock_widget.countdown_text() == "FAJAR 00:27",
        "The clock must display the exact time remaining until dawn")
    main.spawner.start_wave(1)
    hud._process(0.2)
    assert(hud._foes.text == "0+6" and hud._foes.visible,
        "The hostile counter must expose queued wave enemies before the first spawn")
    assert(hud._foes.tooltip_text.find("6 remaining") >= 0,
        "The hostile counter must explain active versus queued enemies")
    main.spawner.end_wave()

    game_clock.time_of_day = 0.75
    game_clock.is_night = true
    hud._scan_t = 0.0
    hud._process(0.2)
    assert(hud._jobs["woodcutter"].sheltering and not hud._jobs["soldier"].sheltering,
        "Non-soldier job rows must visibly indicate night shelter while soldiers remain active")
    assert(hud._jobs["woodcutter"].tooltip_text.find("produksi berhenti") >= 0,
        "The job tooltip must explain that non-soldier production pauses during night")
    game_clock.time_of_day = 0.95
    game_clock.is_night = false
    hud._scan_t = 0.0
    hud._process(0.2)
    assert(not hud._jobs["woodcutter"].sheltering,
        "Job rows must return to their normal state at dawn")
    var player = get_first_node_in_group("player")
    assert(player != null and player.camera.zoom == Vector2.ONE,
        "The wider field of view must come from viewport dimensions, not gameplay camera zoom")

    for size_case in RESOLUTION_CASES:
        var viewport_size: Vector2i = size_case["viewport"]
        root.content_scale_size = viewport_size
        settings.content_viewport_resized.emit(viewport_size)
        await process_frame

        assert(hud._viewport_size == Vector2(viewport_size),
            "HUD must reflow when the logical viewport changes")
        assert(is_equal_approx(hud._top_bar.size.x, viewport_size.x),
            "The top bar must span the viewport width")
        assert(hud._stage_panel.position.x >= 0.0
            and hud._stage_panel.position.x + hud._stage_panel.size.x <= viewport_size.x,
            "The stage panel must stay within the viewport")
        assert(hud._jobs_panel.position.x >= 0.0
            and hud._jobs_panel.position.x + hud._jobs_panel.size.x <= viewport_size.x,
            "The job drawer must stay within the viewport")
        assert(hud._combat_bar.position.y + hud._combat_bar.size.y < viewport_size.y,
            "The combat strip must stay above the bottom edge")

        # Static HUD belongs to the top/bottom bands, leaving a clear central playfield.
        var top_hud_edge := maxf(
            hud._vitals_panel.position.y + hud._vitals_panel.size.y,
            hud._stage_panel.position.y + hud._stage_panel.size.y
        )
        if hud._jobs_panel.visible:
            top_hud_edge = maxf(top_hud_edge, hud._jobs_panel.position.y + hud._jobs_panel.size.y)
        if hud._boss_panel.visible:
            top_hud_edge = maxf(top_hud_edge, hud._boss_panel.position.y + hud._boss_panel.size.y)
        var bottom_hud_edge: float = float(hud._combat_bar.position.y)
        var clear_playfield_height: float = bottom_hud_edge - top_hud_edge
        assert(clear_playfield_height >= viewport_size.y * 0.30,
            "At least 30% of the viewport height must remain clear between HUD bands")

        var map_panel = hud._map_panel
        assert(map_panel.position.x >= 0.0 and map_panel.position.y >= 0.0,
            "The map panel must not start outside the viewport")
        assert(map_panel.position.x + map_panel.size.x <= viewport_size.x + 0.1,
            "The map panel must fit the viewport width")
        assert(map_panel.position.y + map_panel.size.y <= viewport_size.y + 0.1,
            "The map panel must fit the viewport height")

        for slot in hud._slot_nodes:
            assert(slot.position.x >= 0.0
                and slot.position.x + slot.size.x <= viewport_size.x + 0.1,
                "Every building slot must fit horizontally")
            assert(slot.position.y + slot.size.y <= viewport_size.y + 0.1,
                "Every building slot must fit vertically")

    var tech = get_first_node_in_group("tech_panel")
    var pause = get_first_node_in_group("pause_menu")
    assert(tech != null and tech._root.anchor_right == 1.0 and tech._root.anchor_bottom == 1.0,
        "Technology overlay root must fill the viewport")
    assert(pause != null and pause._root.anchor_right == 1.0 and pause._root.anchor_bottom == 1.0,
        "Pause overlay root must fill the viewport")
    assert(pause._resolution_values.size() > 0,
        "The pause menu must expose at least one monitor-compatible window preset")
    assert(pause._resolution_values.has(settings.windowed_size),
        "The currently saved window size must remain selectable")

    print("PASS: resolution-matched 2x viewport and HUD safe playfield at six desktop resolutions")
    quit()
