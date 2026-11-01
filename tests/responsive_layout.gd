extends SceneTree
## Responsive viewport and HUD layout regression checks across common desktop aspect ratios.

func _initialize() -> void:
    DirAccess.remove_absolute("user://save.json")
    DirAccess.remove_absolute("user://save.tmp")
    DirAccess.remove_absolute("user://save.bak")

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await process_frame
    await process_frame
    GameClock.set_process(false)

    assert(String(ProjectSettings.get_setting("display/window/stretch/aspect")) == "expand",
        "The project must expand the viewport instead of cropping or distorting the game")
    assert(String(ProjectSettings.get_setting("display/window/stretch/mode")) == "viewport",
        "Pixel-art world rendering must remain viewport-based")
    assert(String(ProjectSettings.get_setting("display/window/stretch/scale_mode")) == "integer",
        "Pixel-art scaling must remain integer-based")
    assert(int(ProjectSettings.get_setting("display/window/size/min_width")) >= 960,
        "Window minimum width must remain laptop-friendly")
    assert(int(ProjectSettings.get_setting("display/window/size/min_height")) >= 540,
        "Window minimum height must remain laptop-friendly")
    assert(int(ProjectSettings.get_setting("display/window/size/initial_position_type")) == 1,
        "The initial window must be centered on the primary screen")
    assert(Settings.windowed_size.x >= 960 and Settings.windowed_size.y >= 540,
        "Saved windowed size must satisfy the minimum display dimensions")

    var hud = get_first_node_in_group("hud")
    assert(hud != null, "The main scene must create the HUD")
    var layouts := [
        Vector2(480, 270),
        Vector2(640, 360),
        Vector2(640, 400),
        Vector2(683, 384),
        Vector2(960, 540)
    ]

    for viewport_size in layouts:
        hud._layout_viewport(viewport_size)
        await process_frame

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
    assert(pause._resolution_values.has(Settings.windowed_size),
        "The currently saved window size must remain selectable")

    print("PASS: expanded integer-scaled viewport and responsive HUD/map layout at five resolutions")
    quit()
