extends Node
## Register input actions (keyboard + gamepad). Settings can replace the primary keyboard binding.


func _ready() -> void:
    _add("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
    _add("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
    _add("move_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
    _add("move_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])
    _add("interact", [KEY_E, KEY_SPACE], [JOY_BUTTON_A], [])
    _add("attack", [KEY_F], [JOY_BUTTON_X], [])
    _add("sprint", [KEY_SHIFT], [JOY_BUTTON_LEFT_SHOULDER], [])
    _add("ability_dash", [KEY_Q], [JOY_BUTTON_B], [])
    _add("ability_cleave", [KEY_C], [JOY_BUTTON_Y], [])
    _add("ability_rally", [KEY_V], [JOY_BUTTON_RIGHT_SHOULDER], [])
    var click := InputEventMouseButton.new()
    click.button_index = MOUSE_BUTTON_LEFT
    InputMap.action_add_event("attack", click)


func _add(action: String, keys: Array, buttons: Array, axes: Array) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action, 0.3)
    for k in keys:
        var e := InputEventKey.new()
        e.physical_keycode = k as Key
        InputMap.action_add_event(action, e)
    for b in buttons:
        var e := InputEventJoypadButton.new()
        e.button_index = b as JoyButton
        InputMap.action_add_event(action, e)
    for a in axes:
        var e := InputEventJoypadMotion.new()
        e.axis = a[0] as JoyAxis
        e.axis_value = a[1]
        InputMap.action_add_event(action, e)
