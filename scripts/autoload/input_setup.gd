extends Node
## Canonical keyboard and gamepad command registry.
## Settings reads DEFAULT_KEY_BINDINGS to restore only keyboard defaults.

const DEFAULT_KEY_BINDINGS := {
    "move_left": [KEY_A, KEY_LEFT],
    "move_right": [KEY_D, KEY_RIGHT],
    "move_up": [KEY_W, KEY_UP],
    "move_down": [KEY_S, KEY_DOWN],
    "interact": [KEY_E, KEY_SPACE],
    "attack": [KEY_F],
    "sprint": [KEY_SHIFT],
    "ability_dash": [KEY_Q],
    "ability_cleave": [KEY_C],
    "ability_rally": [KEY_V],
    "menu_pause": [KEY_P],
    "game_cancel": [KEY_ESCAPE],
    "save_game": [KEY_F5],
    "load_game": [KEY_F9],
    "load_last_save": [KEY_L],
    "restart_game": [KEY_R],
    "toggle_technology": [KEY_Y],
    "toggle_objectives": [KEY_O],
    "toggle_map": [KEY_TAB],
    "toggle_help": [KEY_H, KEY_F1],
    "toggle_fps": [KEY_F3],
    "toggle_construction_queue": [KEY_N],
    "command_expedition": [KEY_G],
    "modifier_alt": [KEY_ALT],
    "modifier_shift": [KEY_SHIFT],
    "job_woodcutter": [KEY_T],
    "job_miner": [KEY_M],
    "job_farmer": [KEY_K],
    "job_builder": [KEY_B],
    "job_hunter": [KEY_J],
    "job_scout": [KEY_U],
    "job_healer": [KEY_I],
    "job_blacksmith": [KEY_X],
    "job_soldier": [KEY_R],
    "build_slot_1": [KEY_1],
    "build_slot_2": [KEY_2],
    "build_slot_3": [KEY_3],
    "build_slot_4": [KEY_4],
    "build_slot_5": [KEY_5],
    "build_slot_6": [KEY_6],
    "build_slot_7": [KEY_7],
    "build_slot_8": [KEY_8],
    "build_slot_9": [KEY_9],
    "build_slot_10": [KEY_0]
}

const DEFAULT_JOYPAD_BUTTON_BINDINGS := {
    "move_left": [JOY_BUTTON_DPAD_LEFT],
    "move_right": [JOY_BUTTON_DPAD_RIGHT],
    "move_up": [JOY_BUTTON_DPAD_UP],
    "move_down": [JOY_BUTTON_DPAD_DOWN],
    "interact": [JOY_BUTTON_A],
    "attack": [JOY_BUTTON_X],
    "sprint": [JOY_BUTTON_LEFT_SHOULDER],
    "ability_dash": [JOY_BUTTON_B],
    "ability_cleave": [JOY_BUTTON_Y],
    "ability_rally": [JOY_BUTTON_RIGHT_SHOULDER],
    "menu_pause": [JOY_BUTTON_START],
    "game_cancel": [JOY_BUTTON_BACK]
}

const DEFAULT_JOYPAD_AXIS_BINDINGS := {
    "move_left": [[JOY_AXIS_LEFT_X, -1.0]],
    "move_right": [[JOY_AXIS_LEFT_X, 1.0]],
    "move_up": [[JOY_AXIS_LEFT_Y, -1.0]],
    "move_down": [[JOY_AXIS_LEFT_Y, 1.0]]
}


func _ready() -> void:
    for action in DEFAULT_KEY_BINDINGS:
        _add(
            String(action),
            DEFAULT_KEY_BINDINGS[action],
            DEFAULT_JOYPAD_BUTTON_BINDINGS.get(action, []),
            DEFAULT_JOYPAD_AXIS_BINDINGS.get(action, [])
        )
    var click := InputEventMouseButton.new()
    click.button_index = MOUSE_BUTTON_LEFT
    InputMap.action_add_event("attack", click)


func _add(action: String, keys: Array, buttons: Array, axes: Array) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action, 0.3)
    for key_code in keys:
        var key_event := InputEventKey.new()
        key_event.physical_keycode = key_code as Key
        InputMap.action_add_event(action, key_event)
    for button_code in buttons:
        var button_event := InputEventJoypadButton.new()
        button_event.button_index = button_code as JoyButton
        InputMap.action_add_event(action, button_event)
    for axis_data in axes:
        var axis_event := InputEventJoypadMotion.new()
        axis_event.axis = axis_data[0] as JoyAxis
        axis_event.axis_value = axis_data[1]
        InputMap.action_add_event(action, axis_event)
