extends SceneTree
## Checks command registration, gamepad defaults, conflicts, persistence and reset.


func check(condition: bool, message: String) -> bool:
    if condition:
        return true
    push_error("FAIL: " + message)
    quit(1)
    return false


func _initialize() -> void:
    # SceneTree scripts begin before the project's autoload _ready callbacks.
    await process_frame
    var settings = root.get_node("Settings")
    for action in settings.BINDABLE_ACTIONS:
        if not check(InputMap.has_action(action), "InputSetup must register bindable action: " + action):
            return
    if not check(InputMap.has_action("game_cancel") and InputMap.has_action("restart_game"),
        "Context-only system actions must also be registered"):
        return
    if not check(settings.binding_label("move_up").contains("W") and settings.binding_label("move_up").contains("↑"),
        "The controls UI must show both WASD and arrow-key defaults"):
        return
    if not check(settings.binding_label("interact").contains("SPACE") and settings.binding_label("interact").contains("E"),
        "The controls UI must show both interaction defaults"):
        return
    var move_has_gamepad := false
    for event in InputMap.action_get_events("move_up"):
        if event is InputEventJoypadButton or event is InputEventJoypadMotion:
            move_has_gamepad = true
    if not check(move_has_gamepad, "Movement must retain its default gamepad bindings"):
        return
    var ability_has_gamepad := false
    for event in InputMap.action_get_events("ability_dash"):
        if event is InputEventJoypadButton:
            ability_has_gamepad = true
    if not check(ability_has_gamepad, "Combat abilities must retain their default gamepad bindings"):
        return

    var previous_bindings: Dictionary = settings.custom_bindings.duplicate()
    var previous_events: Dictionary = {}
    for action in settings.BINDABLE_ACTIONS:
        previous_events[action] = InputMap.action_get_events(action).duplicate()

    if not check(settings.set_key_binding("move_up", KEY_Z),
        "A free key should be accepted"):
        return
    if not check(settings.get_key_binding("move_up") == KEY_Z,
        "InputMap should apply the new key immediately"):
        return
    if not check(settings.binding_label("move_up") == "Z",
        "The visible binding label must refresh to the active custom key"):
        return
    if not check(not settings.set_key_binding("move_down", KEY_Z),
        "A key already used by another bindable action must be rejected"):
        return
    if not check(not settings.set_key_binding("move_up", KEY_I),
        "A key assigned to the Healer job command must be rejected"):
        return
    if not check(not settings.set_key_binding("move_up", KEY_P),
        "The Menu command must participate in duplicate-key detection"):
        return
    if not check(not settings.set_key_binding("move_up", KEY_ESCAPE),
        "Escape must remain reserved for cancellation"):
        return
    if not check(settings.set_key_binding("ability_dash", KEY_F2),
        "Ability actions must be rebindable"):
        return
    if not check(not settings.set_key_binding("toggle_technology", KEY_F2),
        "Ability and strategic commands must share one conflict registry"):
        return

    var config := ConfigFile.new()
    if not check(config.load("user://settings.cfg") == OK,
        "Settings file should exist after rebinding"):
        return
    if not check(int(config.get_value("input", "move_up", 0)) == KEY_Z,
        "Movement binding should persist in settings.cfg"):
        return
    if not check(int(config.get_value("input", "ability_dash", 0)) == KEY_F2,
        "Ability binding should persist in settings.cfg"):
        return

    settings.restore_default_bindings()
    if not check(settings.get_key_binding("move_up") == KEY_W,
        "Restore defaults must restore the first movement key"):
        return
    if not check(settings.binding_label("move_up").contains("↑"),
        "Restoring defaults must restore and display secondary movement keys"):
        return
    if not check(settings.get_key_binding("ability_dash") == KEY_Q,
        "Restore defaults must restore ability defaults"):
        return
    if not check(settings.custom_bindings.is_empty(),
        "Restore defaults must clear stored overrides"):
        return

    settings.custom_bindings = previous_bindings
    for action in settings.BINDABLE_ACTIONS:
        InputMap.action_erase_events(action)
        for event in previous_events[action]:
            InputMap.action_add_event(action, event)
    settings.save_settings()

    print("PASS: full command registry, gamepad defaults, keyboard rebinding, conflict protection, persistence and reset")
    quit()
