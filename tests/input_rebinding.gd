extends SceneTree
## Checks persisted keyboard rebinding, duplicate rejection, and protected shortcuts.

func _initialize() -> void:
    await process_frame
    var settings = root.get_node("Settings")
    var previous_bindings: Dictionary = settings.custom_bindings.duplicate()
    var previous_events: Dictionary = {}
    for action in settings.BINDABLE_ACTIONS:
        previous_events[action] = InputMap.action_get_events(action).duplicate()

    assert(settings.set_key_binding("move_up", KEY_I),
        "A free key should be accepted")
    assert(settings.get_key_binding("move_up") == KEY_I,
        "InputMap should apply the new key immediately")
    assert(not settings.set_key_binding("move_down", KEY_I),
        "A key already used by another core action must be rejected")
    assert(not settings.set_key_binding("move_up", KEY_P),
        "Hardcoded menu shortcuts must be protected")

    var config := ConfigFile.new()
    assert(config.load("user://settings.cfg") == OK,
        "Settings file should exist after rebinding")
    assert(int(config.get_value("input", "move_up", 0)) == KEY_I,
        "New key should persist in settings.cfg")

    settings.custom_bindings = previous_bindings
    for action in settings.BINDABLE_ACTIONS:
        InputMap.action_erase_events(action)
        for event in previous_events[action]:
            InputMap.action_add_event(action, event)
    settings.save_settings()

    print("PASS: key rebinding, duplicate/reserved rejection, settings persistence, and restoration")
    quit()
