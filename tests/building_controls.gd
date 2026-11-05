extends SceneTree
## Verifies building selection flow: wheel cycling, hotbar-wheel access, wrapping and cancel behavior.

func _initialize() -> void:
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    for _frame in 5:
        await physics_frame

    var build = main.build
    var hud = get_first_node_in_group("hud")
    var available: Array = Tech.available_buildings()
    assert(available.size() >= 2, "The test profile must expose at least two buildings")
    assert(hud != null, "HUD must exist before testing build mode")

    build._set_active(String(available[0]))
    assert(hud._selected == String(available[0]), "Selecting a building must update HUD selection")
    assert(hud._build_mode_hint.visible, "Active build mode must show contextual controls")
    assert(hud._build_mode_hint.text.contains("SCROLL GANTI"), "Build-mode hint must explain wheel selection")

    var wheel_down := InputEventMouseButton.new()
    wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
    wheel_down.pressed = true
    wheel_down.position = Vector2(240, 150)
    build._unhandled_input(wheel_down)
    assert(build.active == String(available[1]), "Wheel down must select the next unlocked building")
    assert(hud._selected == build.active, "Wheel selection must update the selected HUD slot")

    var wheel_up := InputEventMouseButton.new()
    wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
    wheel_up.pressed = true
    wheel_up.position = Vector2(240, 150)
    build._unhandled_input(wheel_up)
    assert(build.active == String(available[0]), "Wheel up must select the previous unlocked building")

    build._set_active(String(available[available.size() - 1]))
    wheel_down.position = Vector2(240, 150)
    build._unhandled_input(wheel_down)
    assert(build.active == String(available[0]), "Wheel down from the last building must wrap to the first")

    build._set_active(String(available[0]))
    wheel_up.position = hud._top_bar.position + Vector2(12, 4)
    build._unhandled_input(wheel_up)
    assert(build.active == String(available[0]), "Scrolling over unrelated HUD panels must not change the building")

    var slot_position: Vector2 = hud._slot_nodes[0].position + hud._slot_nodes[0].size * 0.5
    wheel_down.position = slot_position
    build._unhandled_input(wheel_down)
    assert(build.active == String(available[1]), "Scrolling over the building hotbar must cycle selection")

    build._set_active("")
    assert(not hud._build_mode_hint.visible, "Leaving build mode must hide contextual building controls")
    build._unhandled_input(wheel_down)
    assert(build.active == "", "The wheel must not select a building outside build mode")

    print("PASS: building hotbar selection, wheel cycling, HUD context, UI scroll isolation and cancel")
    quit()
