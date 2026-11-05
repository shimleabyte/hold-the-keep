extends Control
## Landscape touchscreen layer. Touches are translated into the existing InputMap,
## so gameplay logic stays shared with keyboard/mouse and gamepad.

const JOYSTICK_RADIUS := 48.0
const JOYSTICK_KNOB_RADIUS := 17.0
const JOYSTICK_MAX_TRAVEL := 31.0
const JOYSTICK_HIT_RADIUS := 54.0
const JOYSTICK_EDGE_INSET := 60.0
const JOYSTICK_BOTTOM_INSET := 100.0
const BUTTON_HIT_PADDING := 8.0

const ATTACK_ICON := preload("res://assets/sprites/icon_sword.svg")
const INTERACT_ICON := preload("res://assets/sprites/icon_hammer.svg")
const DASH_ICON := preload("res://assets/sprites/icon_compass.svg")
const CLEAVE_ICON := preload("res://assets/sprites/icon_axe.svg")
const RALLY_ICON := preload("res://assets/sprites/icon_people.svg")

var force_enabled := false

var _viewport_size := Vector2(640.0, 360.0)
var _safe_bounds := Rect2(Vector2.ZERO, Vector2(640.0, 360.0))
var _joystick_center := Vector2(70.0, 284.0)
var _pause_center := Vector2(28.0, 76.0)
var _stick_value := Vector2.ZERO
var _joystick_touch_id := -1
var _pause_touch_id := -1
var _touch_actions: Dictionary = {}
var _touch_action_counts: Dictionary = {}
var _pressed_actions: Dictionary = {}
var _button_layout: Array[Dictionary] = []


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    process_mode = Node.PROCESS_MODE_ALWAYS
    visible = force_enabled or _device_has_touchscreen()
    _refresh_layout()
    get_viewport().size_changed.connect(_refresh_layout)


func _process(_delta: float) -> void:
    var should_show := force_enabled or _device_has_touchscreen()
    var pause_menu = get_tree().get_first_node_in_group("pause_menu")
    if pause_menu != null and pause_menu.has_method("is_open") and pause_menu.is_open():
        should_show = false

    var hud := get_parent()
    if hud is CanvasLayer:
        for overlay_property in [
            "_map_panel",
            "_jobs_panel",
            "_outpost_panel",
            "_queue_panel",
            "_help",
            "_over",
            "_event_decision_panel"
        ]:
            var overlay = hud.get(overlay_property) as Control
            if overlay != null and overlay.visible:
                should_show = false
                break

    var technology_panel = get_tree().get_first_node_in_group("tech_panel")
    if technology_panel != null and technology_panel.has_method("is_open") and technology_panel.is_open():
        should_show = false

    if visible and not should_show:
        _release_all_touches()
    if visible != should_show:
        visible = should_show
        queue_redraw()


func _input(event: InputEvent) -> void:
    if not visible:
        return
    if event is InputEventScreenTouch:
        var touch_position := _to_local_position(event.position)
        if event.pressed and not event.canceled:
            if handle_touch_press(event.index, touch_position):
                get_viewport().set_input_as_handled()
        elif handle_touch_release(event.index):
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag:
        if handle_touch_move(event.index, _to_local_position(event.position)):
            get_viewport().set_input_as_handled()


func _to_local_position(viewport_position: Vector2) -> Vector2:
    return get_global_transform_with_canvas().affine_inverse() * viewport_position


func _device_has_touchscreen() -> bool:
    return OS.get_name() == "Android" or DisplayServer.has_feature(DisplayServer.FEATURE_TOUCHSCREEN)


static func safe_bounds_for_viewport(
    viewport_size: Vector2,
    display_safe_area: Rect2i,
    physical_screen_size: Vector2i
) -> Rect2:
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        return Rect2()
    if physical_screen_size.x <= 0 or physical_screen_size.y <= 0 or display_safe_area.size.x <= 0 or display_safe_area.size.y <= 0:
        return Rect2(Vector2.ZERO, viewport_size)

    var scale := Vector2(
        viewport_size.x / float(physical_screen_size.x),
        viewport_size.y / float(physical_screen_size.y)
    )
    var safe_position := Vector2(display_safe_area.position) * scale
    var safe_end := Vector2(display_safe_area.position + display_safe_area.size) * scale
    safe_position.x = clampf(safe_position.x, 0.0, viewport_size.x)
    safe_position.y = clampf(safe_position.y, 0.0, viewport_size.y)
    safe_end.x = clampf(safe_end.x, safe_position.x, viewport_size.x)
    safe_end.y = clampf(safe_end.y, safe_position.y, viewport_size.y)
    return Rect2(safe_position, safe_end - safe_position)


func configure_viewport(viewport_size: Vector2) -> void:
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        return
    _viewport_size = viewport_size
    _apply_layout()


func _refresh_layout() -> void:
    var visible_size := get_viewport().get_visible_rect().size
    if visible_size.x > 0.0 and visible_size.y > 0.0:
        _viewport_size = visible_size
    _apply_layout()


func _apply_layout() -> void:
    var safe := Rect2(Vector2.ZERO, _viewport_size)
    if OS.get_name() == "Android":
        safe = safe_bounds_for_viewport(
            _viewport_size,
            DisplayServer.get_display_safe_area(),
            DisplayServer.screen_get_size()
        )
    _safe_bounds = safe

    var left := safe.position.x
    var top := safe.position.y
    var right := safe.end.x
    var bottom := safe.end.y
    _joystick_center = Vector2(
        left + JOYSTICK_EDGE_INSET,
        bottom - JOYSTICK_BOTTOM_INSET
    )
    _pause_center = Vector2(left + 28.0, top + 86.0)

    _button_layout = [
        {
            "action": "attack",
            "label": "ATK",
            "icon": ATTACK_ICON,
            "center": Vector2(right - 55.0, bottom - 78.0),
            "radius": 30.0
        },
        {
            "action": "interact",
            "label": "USE",
            "icon": INTERACT_ICON,
            "center": Vector2(right - 125.0, bottom - 60.0),
            "radius": 23.0
        },
        {
            "action": "ability_dash",
            "label": "DASH",
            "icon": DASH_ICON,
            "center": Vector2(right - 125.0, bottom - 132.0),
            "radius": 23.0
        },
        {
            "action": "ability_cleave",
            "label": "CUT",
            "icon": CLEAVE_ICON,
            "center": Vector2(right - 55.0, bottom - 153.0),
            "radius": 23.0
        },
        {
            "action": "ability_rally",
            "label": "CALL",
            "icon": RALLY_ICON,
            "center": Vector2(right - 195.0, bottom - 101.0),
            "radius": 23.0
        }
    ]
    queue_redraw()


func joystick_center() -> Vector2:
    return _joystick_center


func button_center(action: String) -> Vector2:
    for button in _button_layout:
        if String(button["action"]) == action:
            return button["center"]
    return Vector2(-1.0, -1.0)


func handle_touch_press(touch_id: int, position: Vector2) -> bool:
    if _joystick_touch_id == touch_id or _touch_actions.has(touch_id) or _pause_touch_id == touch_id:
        return false

    if _joystick_touch_id == -1 and position.distance_to(_joystick_center) <= JOYSTICK_HIT_RADIUS:
        _joystick_touch_id = touch_id
        _update_joystick(position)
        queue_redraw()
        return true

    if position.distance_to(_pause_center) <= 27.0:
        _pause_touch_id = touch_id
        var pause_menu = get_tree().get_first_node_in_group("pause_menu")
        if pause_menu != null and pause_menu.has_method("_toggle"):
            pause_menu._toggle()
        queue_redraw()
        return true

    for button in _button_layout:
        var center: Vector2 = button["center"]
        var radius := float(button["radius"]) + BUTTON_HIT_PADDING
        if position.distance_to(center) > radius:
            continue
        var action := String(button["action"])
        _touch_actions[touch_id] = action
        var touch_count := int(_touch_action_counts.get(action, 0)) + 1
        _touch_action_counts[action] = touch_count
        _pressed_actions[action] = true
        if touch_count == 1:
            Input.action_press(action)
        queue_redraw()
        return true

    return false


func handle_touch_move(touch_id: int, position: Vector2) -> bool:
    if touch_id == _joystick_touch_id:
        _update_joystick(position)
        queue_redraw()
        return true
    return _touch_actions.has(touch_id) or touch_id == _pause_touch_id


func handle_touch_release(touch_id: int) -> bool:
    if touch_id == _joystick_touch_id:
        _joystick_touch_id = -1
        _stick_value = Vector2.ZERO
        _apply_movement(Vector2.ZERO)
        queue_redraw()
        return true

    if _touch_actions.has(touch_id):
        var action := String(_touch_actions[touch_id])
        _touch_actions.erase(touch_id)
        var touch_count := int(_touch_action_counts.get(action, 1)) - 1
        if touch_count <= 0:
            _touch_action_counts.erase(action)
            _pressed_actions.erase(action)
            Input.action_release(action)
        else:
            _touch_action_counts[action] = touch_count
        queue_redraw()
        return true

    if touch_id == _pause_touch_id:
        _pause_touch_id = -1
        queue_redraw()
        return true
    return false


func _update_joystick(position: Vector2) -> void:
    var offset := position - _joystick_center
    var clamped_offset := offset.limit_length(JOYSTICK_MAX_TRAVEL)
    _stick_value = clamped_offset / JOYSTICK_MAX_TRAVEL
    _apply_movement(_stick_value)


func _apply_movement(direction: Vector2) -> void:
    _set_axis_action("move_left", maxf(0.0, -direction.x))
    _set_axis_action("move_right", maxf(0.0, direction.x))
    _set_axis_action("move_up", maxf(0.0, -direction.y))
    _set_axis_action("move_down", maxf(0.0, direction.y))
    if direction.length() >= 0.92:
        Input.action_press("sprint")
    else:
        Input.action_release("sprint")


func _set_axis_action(action: String, strength: float) -> void:
    if strength <= 0.001:
        Input.action_release(action)
    else:
        Input.action_press(action, clampf(strength, 0.0, 1.0))


func _release_all_touches() -> void:
    for action_value in _touch_action_counts.keys():
        Input.action_release(String(action_value))
    _touch_actions.clear()
    _touch_action_counts.clear()
    _pressed_actions.clear()
    _joystick_touch_id = -1
    _pause_touch_id = -1
    _stick_value = Vector2.ZERO
    _apply_movement(Vector2.ZERO)
    queue_redraw()


func _draw() -> void:
    if not visible:
        return

    _draw_joystick()
    _draw_pause_button()
    for button in _button_layout:
        _draw_action_button(button)


func _draw_joystick() -> void:
    draw_circle(_joystick_center, JOYSTICK_RADIUS, Color(0.035, 0.045, 0.045, 0.54))
    draw_arc(_joystick_center, JOYSTICK_RADIUS - 1.0, 0.0, TAU, 40, Color("#b08a58", 0.66), 1.5)
    draw_arc(_joystick_center, JOYSTICK_RADIUS - 11.0, 0.0, TAU, 40, Color("#8d795b", 0.22), 1.0)
    var knob_position := _joystick_center + _stick_value * JOYSTICK_MAX_TRAVEL
    draw_circle(knob_position, JOYSTICK_KNOB_RADIUS + 2.0, Color(0.01, 0.015, 0.015, 0.72))
    draw_circle(knob_position, JOYSTICK_KNOB_RADIUS, Color("#89704d", 0.93))
    draw_arc(knob_position, JOYSTICK_KNOB_RADIUS - 1.0, 0.0, TAU, 24, Color("#f0d3a1", 0.72), 1.2)


func _draw_pause_button() -> void:
    var radius := 17.0
    draw_circle(_pause_center, radius, Color(0.035, 0.045, 0.045, 0.72))
    draw_arc(_pause_center, radius - 0.5, 0.0, TAU, 28, Color("#b08a58", 0.8), 1.2)
    var font := ThemeDB.fallback_font
    draw_string(font, _pause_center + Vector2(-4.5, 3.0), "II", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#f1dfbd"))


func _draw_action_button(button: Dictionary) -> void:
    var action := String(button["action"])
    var center: Vector2 = button["center"]
    var radius := float(button["radius"])
    var is_pressed := _pressed_actions.has(action)
    var background := Color("#735b3d", 0.92) if is_pressed else Color(0.035, 0.045, 0.045, 0.78)
    var border := Color("#ffe0a2", 0.98) if is_pressed else Color("#b08a58", 0.88)
    draw_circle(center, radius + 2.0, Color(0.01, 0.012, 0.012, 0.45))
    draw_circle(center, radius, background)
    draw_arc(center, radius - 0.5, 0.0, TAU, 32, border, 1.5)
    var icon: Texture2D = button["icon"]
    var icon_rect := Rect2(center + Vector2(-9.0, -15.0), Vector2(18.0, 18.0))
    draw_texture_rect(icon, icon_rect, false, Color("#f0d6aa"))
    var font := ThemeDB.fallback_font
    var label := String(button["label"])
    draw_string(font, center + Vector2(-radius, radius * 0.73), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 8, Color("#f5e8ce"))
