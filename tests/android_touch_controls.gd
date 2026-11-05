extends SceneTree
## Touch-input regression. Runs on desktop/headless and does not require a touchscreen.

const MOBILE_CONTROLS := preload("res://scripts/ui/mobile_controls.gd")


class TouchHudHost extends CanvasLayer:
    var _jobs_panel: Control


class FakePauseMenu extends Node:
    var opened := false

    func is_open() -> bool:
        return opened

    func _toggle() -> void:
        opened = not opened


func verify_button_hit_geometry(controls: Control, viewport_size: Vector2) -> void:
    var buttons: Array = controls._button_layout
    for i in range(buttons.size()):
        var first: Dictionary = buttons[i]
        var first_center: Vector2 = first["center"]
        var first_radius: float = float(first["radius"]) + MOBILE_CONTROLS.BUTTON_HIT_PADDING
        assert(first_center.x - first_radius >= -0.01
            and first_center.y - first_radius >= -0.01
            and first_center.x + first_radius <= viewport_size.x + 0.01
            and first_center.y + first_radius <= viewport_size.y + 0.01,
            "Every action hit target must remain inside the viewport")
        for j in range(i + 1, buttons.size()):
            var second: Dictionary = buttons[j]
            var second_center: Vector2 = second["center"]
            var second_radius: float = float(second["radius"]) + MOBILE_CONTROLS.BUTTON_HIT_PADDING
            assert(first_center.distance_to(second_center) >= first_radius + second_radius,
                "Action hit targets must not overlap and steal neighboring taps")


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    for action in ["move_left", "move_right", "move_up", "move_down", "sprint", "attack", "interact", "ability_dash", "ability_cleave", "ability_rally"]:
        assert(InputMap.has_action(action), "Touch controls must reuse the existing InputMap action: " + action)

    var controls = MOBILE_CONTROLS.new()
    controls.force_enabled = true
    root.add_child(controls)
    await process_frame
    controls.configure_viewport(Vector2(800.0, 450.0))
    assert(controls.visible, "Touch controls must be available when a touchscreen is forced for QA")

    var joystick_center: Vector2 = controls.joystick_center()
    assert(controls.handle_touch_press(1, joystick_center),
        "A touch inside the left movement pad must capture the joystick finger")
    controls.handle_touch_move(1, joystick_center + Vector2(100.0, 0.0))
    assert(Input.get_action_strength("move_right") > 0.95,
        "Dragging right must produce a full-strength move_right InputMap action")
    assert(Input.is_action_pressed("sprint"),
        "Pushing the joystick to its outer threshold must enable sprint")

    var attack_center: Vector2 = controls.button_center("attack")
    assert(controls.handle_touch_press(2, attack_center),
        "A second finger must be able to press attack while movement remains held")
    assert(controls.handle_touch_press(3, attack_center),
        "Two fingers may hold the same action without corrupting its state")
    assert(Input.is_action_pressed("attack"),
        "Attack touch must press the existing attack action")
    assert(controls.handle_touch_release(2),
        "Releasing the first attack finger must be consumed")
    assert(Input.is_action_pressed("attack"),
        "Attack must stay pressed while another finger still holds the same button")
    assert(controls.handle_touch_release(3),
        "Releasing the final attack finger must be consumed")
    assert(not Input.is_action_pressed("attack"),
        "Releasing the final attack finger must release attack without cancelling movement")
    assert(Input.get_action_strength("move_right") > 0.95,
        "Releasing an action button must not release another finger's movement")

    var action_index := 0
    for action in ["interact", "ability_dash", "ability_cleave", "ability_rally"]:
        var touch_id := 10 + action_index
        var center: Vector2 = controls.button_center(action)
        assert(center.x >= 0.0 and center.y >= 0.0,
            "Every gameplay action must have a visible touch target: " + action)
        assert(controls.handle_touch_press(touch_id, center),
            "Touch target must capture " + action)
        assert(Input.is_action_pressed(action),
            "Touch target must press the existing action " + action)
        assert(controls.handle_touch_release(touch_id),
            "Touch target must release " + action)
        assert(not Input.is_action_pressed(action),
            "Touch release must not leave the action stuck: " + action)
        action_index += 1

    assert(controls.handle_touch_release(1),
        "Releasing the movement finger must be consumed")
    for action in ["move_left", "move_right", "move_up", "move_down", "sprint"]:
        assert(not Input.is_action_pressed(action),
            "Movement and sprint must be released when the joystick finger lifts: " + action)

    controls.configure_viewport(Vector2(480.0, 270.0))
    var compact_joystick: Vector2 = controls.joystick_center()
    assert(compact_joystick.x - MOBILE_CONTROLS.JOYSTICK_RADIUS >= 0.0
        and compact_joystick.y + MOBILE_CONTROLS.JOYSTICK_RADIUS <= 270.0,
        "The movement pad must remain inside a minimum 480x270 viewport")
    assert(compact_joystick.distance_to(Vector2(
        MOBILE_CONTROLS.JOYSTICK_HIT_RADIUS,
        270.0 - MOBILE_CONTROLS.JOYSTICK_HIT_RADIUS
    )) < 0.01,
        "The full joystick hit circle must remain inside the compact viewport safe bounds")
    verify_button_hit_geometry(controls, Vector2(480.0, 270.0))
    for action in ["attack", "interact", "ability_dash", "ability_cleave", "ability_rally"]:
        var center: Vector2 = controls.button_center(action)
        assert(center.x >= 0.0 and center.y >= 0.0
            and center.x <= 480.0 and center.y <= 270.0,
            "Touch buttons must stay inside the minimum viewport: " + action)

    controls.configure_viewport(Vector2(800.0, 450.0))
    verify_button_hit_geometry(controls, Vector2(800.0, 450.0))
    var safe := MOBILE_CONTROLS.safe_bounds_for_viewport(
        Vector2(800.0, 450.0),
        Rect2i(32, 12, 736, 426),
        Vector2i(800, 450)
    )
    assert(safe.position == Vector2(32.0, 12.0),
        "Safe-area origin must be mapped into the game viewport")
    assert(safe.size == Vector2(736.0, 426.0),
        "Safe-area dimensions must be preserved in viewport coordinates")

    var full_screen := MOBILE_CONTROLS.safe_bounds_for_viewport(
        Vector2(640.0, 360.0),
        Rect2i(),
        Vector2i(640, 360)
    )
    assert(full_screen == Rect2(Vector2.ZERO, Vector2(640.0, 360.0)),
        "Devices without a cutout must retain the full game viewport")

    controls.queue_free()
    await process_frame

    var overlay_host := TouchHudHost.new()
    root.add_child(overlay_host)
    var jobs_panel := Control.new()
    overlay_host._jobs_panel = jobs_panel
    overlay_host.add_child(jobs_panel)
    var overlay_controls = MOBILE_CONTROLS.new()
    overlay_controls.force_enabled = true
    overlay_host.add_child(overlay_controls)
    await process_frame
    assert(overlay_controls.visible,
        "Touch controls must be available before the jobs drawer opens")
    assert(overlay_controls.handle_touch_press(40, overlay_controls.button_center("attack")),
        "A gameplay button must be capturable before an overlay opens")
    assert(Input.is_action_pressed("attack"),
        "The captured touch must press the gameplay action")
    jobs_panel.visible = true
    overlay_controls._process(0.0)
    assert(not overlay_controls.visible,
        "The touch layer must hide while the jobs drawer is visible")
    assert(not Input.is_action_pressed("attack"),
        "Opening an overlay must release any gameplay action still held by touch")

    var fake_pause := FakePauseMenu.new()
    fake_pause.add_to_group("pause_menu")
    root.add_child(fake_pause)
    var pause_controls = MOBILE_CONTROLS.new()
    pause_controls.force_enabled = true
    root.add_child(pause_controls)
    await process_frame
    assert(pause_controls.visible,
        "Touch controls must be visible while the pause menu is closed")
    assert(pause_controls.handle_touch_press(41, pause_controls._pause_center),
        "The pause hit target must capture a dedicated touch")
    assert(fake_pause.is_open(),
        "The mobile pause target must toggle the pause menu")
    pause_controls._process(0.0)
    assert(not pause_controls.visible and pause_controls._pause_touch_id == -1,
        "Opening pause must hide the touch layer and clear its captured pointer")

    overlay_controls.queue_free()
    pause_controls.queue_free()
    overlay_host.queue_free()
    fake_pause.queue_free()
    await process_frame
    print("PASS: Android touch hit geometry, multi-touch, overlay/pause release, sprint and safe area")
    quit(0)
