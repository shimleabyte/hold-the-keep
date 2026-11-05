extends Node
## Pengaturan pemain di user://settings.cfg (display, audio, dan keybind utama).

const PATH := "user://settings.cfg"
const MIN_WINDOW_SIZE := Vector2i(960, 540)
const MIN_VIEWPORT_SIZE := Vector2i(480, 270)
const VIEWPORT_PIXEL_SCALE := 2
const BINDABLE_GROUPS := [
    {
        "title": "MOVEMENT & COMBAT",
        "actions": [
            "move_up", "move_down", "move_left", "move_right",
            "interact", "attack", "sprint",
            "ability_dash", "ability_cleave", "ability_rally"
        ]
    },
    {
        "title": "VILLAGE JOBS",
        "actions": [
            "job_woodcutter", "job_miner", "job_farmer", "job_builder",
            "job_hunter", "job_scout", "job_healer", "job_blacksmith", "job_soldier"
        ]
    },
    {
        "title": "BUILDING SLOTS",
        "actions": [
            "build_slot_1", "build_slot_2", "build_slot_3", "build_slot_4", "build_slot_5",
            "build_slot_6", "build_slot_7", "build_slot_8", "build_slot_9", "build_slot_10"
        ]
    },
    {
        "title": "SYSTEM & STRATEGY",
        "actions": [
            "menu_pause", "toggle_technology", "toggle_objectives", "toggle_map",
            "toggle_help", "toggle_fps", "toggle_construction_queue",
            "command_expedition", "save_game", "load_game"
        ]
    }
]
const BINDABLE_ACTIONS := [
    "move_up", "move_down", "move_left", "move_right",
    "interact", "attack", "sprint", "ability_dash", "ability_cleave", "ability_rally",
    "job_woodcutter", "job_miner", "job_farmer", "job_builder", "job_hunter",
    "job_scout", "job_healer", "job_blacksmith", "job_soldier",
    "build_slot_1", "build_slot_2", "build_slot_3", "build_slot_4", "build_slot_5",
    "build_slot_6", "build_slot_7", "build_slot_8", "build_slot_9", "build_slot_10",
    "menu_pause", "toggle_technology", "toggle_objectives", "toggle_map",
    "toggle_help", "toggle_fps", "toggle_construction_queue",
    "command_expedition", "save_game", "load_game"
]
const RESERVED_KEYS := [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]

var fullscreen := false
var windowed_size := Vector2i(1280, 720)
var vsync := true
var volume := 0.8
var screen_shake := true
var world_profile := "classic"
var custom_bindings: Dictionary = {}
var _last_window_size := Vector2i.ZERO

signal content_viewport_resized(viewport_size: Vector2i)
signal bindings_changed


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
    var accepted: Dictionary = {}
    for action in BINDABLE_ACTIONS:
        if not custom_bindings.has(action):
            continue
        var code := int(custom_bindings[action])
        if code <= 0 or code in RESERVED_KEYS or code in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
            continue
        if _key_is_used_by_other_action(action, code):
            continue
        _replace_keyboard_binding(action, code)
        accepted[action] = code
    custom_bindings = accepted


func _replace_keyboard_binding(action: String, code: int) -> void:
    _replace_keyboard_bindings(action, [code])


func _replace_keyboard_bindings(action: String, codes: Array) -> void:
    if not InputMap.has_action(action):
        return
    for event in InputMap.action_get_events(action):
        if event is InputEventKey:
            InputMap.action_erase_event(action, event)
    for code_value in codes:
        var key := InputEventKey.new()
        key.physical_keycode = int(code_value) as Key
        InputMap.action_add_event(action, key)


func restore_default_bindings() -> void:
    custom_bindings.clear()
    for action in BINDABLE_ACTIONS:
        _replace_keyboard_bindings(
            action, InputSetup.DEFAULT_KEY_BINDINGS.get(action, [])
        )
    save_settings()
    bindings_changed.emit()


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
    bindings_changed.emit()
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


func _format_key_label(code: int) -> String:
    match code:
        KEY_UP:
            return "UP"
        KEY_DOWN:
            return "DOWN"
        KEY_LEFT:
            return "LEFT"
        KEY_RIGHT:
            return "RIGHT"
        KEY_SPACE:
            return "SPACE"
        KEY_ESCAPE:
            return "ESC"
        KEY_KP_ENTER:
            return "NUM ENTER"
        _:
            return OS.get_keycode_string(code).to_upper()


func binding_label(action: String) -> String:
    if not InputMap.has_action(action):
        return "—"
    var labels: PackedStringArray = []
    for event in InputMap.action_get_events(action):
        if not event is InputEventKey:
            continue
        var code := int(event.physical_keycode)
        if code == 0:
            code = int(event.keycode)
        if code <= 0:
            continue
        var label := _format_key_label(code)
        if not labels.has(label):
            labels.append(label)
    return " / ".join(labels) if not labels.is_empty() else "—"


func binding_short_label(action: String) -> String:
    var code := get_key_binding(action)
    if code <= 0:
        return "—"
    var label := _format_key_label(code)
    if label == "SPACE":
        return "SPC"
    if label == "NUM ENTER":
        return "NENT"
    return label


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
    _sync_content_viewport()
    call_deferred("_sync_content_viewport")


func _process(_delta: float) -> void:
    # Root Window.size_changed is unreliable with viewport stretch mode.
    # Poll the native size cheaply; recompute only when the actual window changes.
    var current_size := DisplayServer.window_get_size()
    if current_size.x > 0 and current_size.y > 0 and current_size != _last_window_size:
        _sync_content_viewport(current_size)


func viewport_size_for_window(window_size: Vector2i) -> Vector2i:
    if window_size.x <= 0 or window_size.y <= 0:
        return MIN_VIEWPORT_SIZE
    return Vector2i(
        maxi(MIN_VIEWPORT_SIZE.x, floori(float(window_size.x) / float(VIEWPORT_PIXEL_SCALE))),
        maxi(MIN_VIEWPORT_SIZE.y, floori(float(window_size.y) / float(VIEWPORT_PIXEL_SCALE)))
    )


func _sync_content_viewport(window_size: Vector2i = Vector2i.ZERO) -> void:
    var actual_size := window_size
    if actual_size.x <= 0 or actual_size.y <= 0:
        actual_size = DisplayServer.window_get_size()
    if actual_size.x <= 0 or actual_size.y <= 0:
        return # Keep the last valid viewport while the window is minimized.

    _last_window_size = actual_size
    var target_size := viewport_size_for_window(actual_size)
    var root_window := get_tree().root
    if root_window.content_scale_size == target_size:
        return

    root_window.content_scale_size = target_size
    content_viewport_resized.emit(target_size)


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
