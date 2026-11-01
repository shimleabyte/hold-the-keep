extends Node
## Pengaturan pemain di user://settings.cfg (display, audio, dan keybind utama).

const PATH := "user://settings.cfg"
const MIN_WINDOW_SIZE := Vector2i(960, 540)
const BINDABLE_ACTIONS := [
    "move_up", "move_down", "move_left", "move_right",
    "interact", "attack", "sprint"
]
const RESERVED_KEYS := [
    KEY_ESCAPE, KEY_P, KEY_Y, KEY_H, KEY_F1, KEY_F3, KEY_F5, KEY_F9,
    KEY_T, KEY_M, KEY_K, KEY_R, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6,
    KEY_TAB, KEY_ENTER, KEY_KP_ENTER, KEY_G,
    KEY_Q, KEY_C, KEY_V
]

var fullscreen := false
var windowed_size := Vector2i(1280, 720)
var vsync := true
var volume := 0.8
var screen_shake := true
var world_profile := "classic"
var custom_bindings: Dictionary = {}


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    load_settings()
    _apply_custom_bindings()
    apply()
    _log_session_header()


func load_settings() -> void:
    custom_bindings.clear()
    var config := ConfigFile.new()
    var has_saved_settings := config.load(PATH) == OK
    var screen_size := DisplayServer.screen_get_size()
    var saved_width := windowed_size.x
    var saved_height := windowed_size.y
    if has_saved_settings:
        fullscreen = bool(config.get_value("display", "fullscreen", fullscreen))
        saved_width = int(config.get_value("display", "window_width", saved_width))
        saved_height = int(config.get_value("display", "window_height", saved_height))
        vsync = bool(config.get_value("display", "vsync", vsync))
        volume = clampf(float(config.get_value("audio", "volume", volume)), 0.0, 1.0)
        screen_shake = bool(config.get_value("display", "screen_shake", screen_shake))
        world_profile = String(config.get_value("world", "profile", world_profile))
        if not WorldConfig.PROFILES.has(world_profile):
            world_profile = "classic"
        for action in BINDABLE_ACTIONS:
            if config.has_section_key("input", action):
                var code := int(config.get_value("input", action, 0))
                if code > 0:
                    custom_bindings[action] = code
    windowed_size = Vector2i(
        clampi(saved_width, MIN_WINDOW_SIZE.x, maxi(MIN_WINDOW_SIZE.x, screen_size.x)),
        clampi(saved_height, MIN_WINDOW_SIZE.y, maxi(MIN_WINDOW_SIZE.y, screen_size.y))
    )


func save_settings() -> void:
    var config := ConfigFile.new()
    config.set_value("display", "fullscreen", fullscreen)
    config.set_value("display", "window_width", windowed_size.x)
    config.set_value("display", "window_height", windowed_size.y)
    config.set_value("display", "vsync", vsync)
    config.set_value("audio", "volume", volume)
    config.set_value("display", "screen_shake", screen_shake)
    config.set_value("world", "profile", world_profile)
    for action in custom_bindings:
        config.set_value("input", action, int(custom_bindings[action]))
    config.save(PATH)


func _apply_custom_bindings() -> void:
    for action in custom_bindings:
        _replace_keyboard_binding(String(action), int(custom_bindings[action]))


func _replace_keyboard_binding(action: String, code: int) -> void:
    if not InputMap.has_action(action):
        return
    for event in InputMap.action_get_events(action):
        if event is InputEventKey:
            InputMap.action_erase_event(action, event)
    var key := InputEventKey.new()
    key.physical_keycode = code as Key
    InputMap.action_add_event(action, key)


func _key_is_used_by_other_action(action: String, code: int) -> bool:
    for other in BINDABLE_ACTIONS:
        if other == action:
            continue
        for event in InputMap.action_get_events(other):
            if event is InputEventKey:
                if int(event.physical_keycode) == code or int(event.keycode) == code:
                    return true
    return false


func set_key_binding(action: String, code: int) -> bool:
    if not BINDABLE_ACTIONS.has(action) or not InputMap.has_action(action) or code <= 0 or code in RESERVED_KEYS:
        return false
    if code in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
        return false
    if _key_is_used_by_other_action(action, code):
        return false
    _replace_keyboard_binding(action, code)
    custom_bindings[action] = code
    save_settings()
    return true


func get_key_binding(action: String) -> int:
    if not InputMap.has_action(action):
        return 0
    for event in InputMap.action_get_events(action):
        if event is InputEventKey:
            if event.physical_keycode != 0:
                return int(event.physical_keycode)
            if event.keycode != 0:
                return int(event.keycode)
    return 0


func binding_label(action: String) -> String:
    var code := get_key_binding(action)
    return OS.get_keycode_string(code).to_upper() if code > 0 else "—"


func apply() -> void:
    get_tree().root.min_size = MIN_WINDOW_SIZE
    DisplayServer.window_set_mode(
        DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
    )
    if not fullscreen:
        DisplayServer.window_set_size(windowed_size)
    DisplayServer.window_set_vsync_mode(
        DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
    )
    AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))


func set_fullscreen(value: bool) -> void:
    fullscreen = value
    apply()
    save_settings()


func set_window_size(value: Vector2i) -> void:
    var screen_size := DisplayServer.screen_get_size()
    var safe_width := clampi(value.x, 960, maxi(960, screen_size.x))
    var safe_height := clampi(value.y, 540, maxi(540, screen_size.y))
    windowed_size = Vector2i(safe_width, safe_height)
    fullscreen = false
    apply()
    save_settings()


func set_vsync(value: bool) -> void:
    vsync = value
    apply()
    save_settings()


func set_screen_shake(value: bool) -> void:
    screen_shake = value
    save_settings()


func set_volume(value: float) -> void:
    volume = clampf(value, 0.0, 1.0)
    apply()
    save_settings()


func set_world_profile(profile_id: String) -> bool:
    if not WorldConfig.PROFILES.has(profile_id):
        return false
    world_profile = profile_id
    save_settings()
    return true


func _log_session_header() -> void:
    print("== Hold the Keep | Godot %s | %s | %s ==" % [
        Engine.get_version_info()["string"], OS.get_name(), OS.get_model_name()])
