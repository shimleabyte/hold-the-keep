extends Control
## Pausable decision surface for data-driven world events.

const PIXEL_FONT := preload("res://scripts/ui/pixel_font.gd")
const RESOURCE_LABELS := {
    "wood": "KAYU",
    "stone": "BATU",
    "food": "MAKANAN",
    "iron": "BESI"
}

var event_manager
var _font: Font
var _viewport_size := Vector2(480, 270)
var _backdrop: ColorRect
var _panel: Panel
var _title: Label
var _description: Label
var _choices: VBoxContainer
var _cancel_button: Button
var _current_event: Dictionary = {}


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _font = PIXEL_FONT.get_font()
    _build_surface()
    Events.event_decision_requested.connect(_on_event_requested)
    Events.event_decision_resolved.connect(_on_event_resolved)
    visible = false
    configure_layout(_viewport_size)


func configure(manager) -> void:
    event_manager = manager


func _build_surface() -> void:
    _backdrop = ColorRect.new()
    _backdrop.color = Color(0.015, 0.018, 0.02, 0.86)
    _backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(_backdrop)

    _panel = Panel.new()
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color("#171914")
    panel_style.border_color = Color("#94784c")
    panel_style.set_border_width_all(2)
    panel_style.content_margin_left = 12.0
    panel_style.content_margin_right = 12.0
    panel_style.content_margin_top = 10.0
    panel_style.content_margin_bottom = 10.0
    _panel.add_theme_stylebox_override("panel", panel_style)
    _panel.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(_panel)

    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 7)
    _panel.add_child(stack)

    var eyebrow := _make_label("KEPUTUSAN PERBATASAN", 8, Color("#b18e59"))
    stack.add_child(eyebrow)

    _title = _make_label("", 15, Color("#f0d7a4"))
    _title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    stack.add_child(_title)

    _description = _make_label("", 9, Color("#c5c2b7"))
    _description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _description.custom_minimum_size.y = 28.0
    stack.add_child(_description)

    var separator := ColorRect.new()
    separator.color = Color("#4b4536")
    separator.custom_minimum_size.y = 1.0
    stack.add_child(separator)

    _choices = VBoxContainer.new()
    _choices.add_theme_constant_override("separation", 5)
    stack.add_child(_choices)

    _cancel_button = _make_button("TOLAK / LEWATI", true)
    _cancel_button.pressed.connect(_on_cancel_pressed)
    stack.add_child(_cancel_button)


func _make_label(value: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_override("font", _font)
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_outline_color", Color.BLACK)
    label.add_theme_constant_override("outline_size", 2)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label


func _make_button(value: String, danger: bool = false) -> Button:
    var button := Button.new()
    button.text = value
    button.custom_minimum_size = Vector2(0, 28)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.add_theme_font_override("font", _font)
    button.add_theme_font_size_override("font_size", 9)
    button.add_theme_color_override("font_color", Color("#e7dfca"))
    button.add_theme_color_override("font_hover_color", Color("#fff1cf"))
    button.add_theme_color_override("font_pressed_color", Color("#ffffff"))
    button.add_theme_color_override("font_disabled_color", Color("#77756c"))

    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("#292b22") if not danger else Color("#30201c")
    normal.border_color = Color("#786644") if not danger else Color("#815147")
    normal.set_border_width_all(1)
    normal.content_margin_left = 8.0
    normal.content_margin_right = 8.0
    normal.content_margin_top = 5.0
    normal.content_margin_bottom = 5.0
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color("#3a3b2b") if not danger else Color("#462924")
    hover.border_color = Color("#d0aa63") if not danger else Color("#cb785e")
    var pressed := hover.duplicate() as StyleBoxFlat
    pressed.bg_color = Color("#1c1d18")
    var disabled := normal.duplicate() as StyleBoxFlat
    disabled.bg_color = Color("#20211d")
    disabled.border_color = Color("#49483f")
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("disabled", disabled)
    return button


func _on_event_requested(event: Dictionary) -> void:
    if event_manager == null:
        return
    _current_event = event.duplicate(true)
    _title.text = String(event.get("name", "Peristiwa"))
    _description.text = String(event.get("text", "Pilih tindakan untuk merespons peristiwa ini."))
    _rebuild_choices()
    visible = true
    configure_layout(_viewport_size)
    get_tree().paused = true


func _rebuild_choices() -> void:
    for child in _choices.get_children():
        _choices.remove_child(child)
        child.queue_free()
    var choice_values: Variant = _current_event.get("choices", [])
    if not choice_values is Array:
        return
    for choice_value in choice_values:
        if not choice_value is Dictionary:
            continue
        var choice: Dictionary = choice_value
        var button := _make_button(_button_text(choice))
        button.disabled = not event_manager.can_choose(choice)
        button.tooltip_text = _choice_tooltip(choice)
        button.pressed.connect(_on_choice_pressed.bind(String(choice.get("id", ""))))
        _choices.add_child(button)


func _button_text(choice: Dictionary) -> String:
    var label := String(choice.get("label", choice.get("id", "Pilih")))
    var requirements: Variant = choice.get("requires", {})
    if requirements is Dictionary and not requirements.is_empty():
        var costs: Array[String] = []
        for resource in requirements:
            costs.append("%s %d" % [
                String(RESOURCE_LABELS.get(String(resource), String(resource).to_upper())),
                int(requirements[resource])
            ])
        label += "   [%s]" % " · ".join(costs)
    var consequences: Variant = choice.get("consequences", [])
    if consequences is Array:
        for consequence_value in consequences:
            if not consequence_value is Dictionary:
                continue
            var consequence: Dictionary = consequence_value
            var summary := _consequence_summary(consequence.get("effects", {}))
            if not summary.is_empty():
                label += "   ·   %d HARI: %s" % [
                    int(consequence.get("after_days", 0)), summary
                ]
    return label


func _consequence_summary(value: Variant) -> String:
    if not value is Dictionary:
        return ""
    var effects: Dictionary = value
    var parts: Array[String] = []
    for resource in ["food", "wood", "stone", "iron", "villagers"]:
        if not effects.has(resource):
            continue
        var amount := int(effects[resource])
        var sign := "+" if amount > 0 else ""
        parts.append("%s%d %s" % [
            sign, amount,
            String(RESOURCE_LABELS.get(resource, resource.to_upper()))
        ])
    if effects.has("food_pct"):
        var percent := int(effects["food_pct"])
        parts.append("%s%d%% MAKANAN" % ["+" if percent > 0 else "", percent])
    return ", ".join(parts)


func _choice_tooltip(choice: Dictionary) -> String:
    var tooltip := String(choice.get("description", ""))
    var consequences: Variant = choice.get("consequences", [])
    if consequences is Array:
        for consequence_value in consequences:
            if not consequence_value is Dictionary:
                continue
            var consequence: Dictionary = consequence_value
            var summary := _consequence_summary(consequence.get("effects", {}))
            if summary.is_empty():
                continue
            if not tooltip.is_empty():
                tooltip += "\n\n"
            tooltip += "Dalam %d hari: %s" % [
                int(consequence.get("after_days", 0)),
                String(consequence.get("result", summary))
            ]
    return tooltip


func _on_choice_pressed(choice_id: String) -> void:
    if event_manager == null:
        return
    if not event_manager.resolve_choice(choice_id):
        _rebuild_choices()


func _on_cancel_pressed() -> void:
    if event_manager != null:
        event_manager.cancel_pending_event()


func _on_event_resolved(_event_id: String, _choice_id: String) -> void:
    _current_event.clear()
    visible = false
    get_tree().paused = false


func configure_layout(viewport_size: Vector2) -> void:
    _viewport_size = Vector2(maxf(480.0, viewport_size.x), maxf(270.0, viewport_size.y))
    var panel_width := minf(390.0, _viewport_size.x - 24.0)
    var panel_height := minf(238.0, _viewport_size.y - 24.0)
    _panel.size = Vector2(panel_width, panel_height)
    _panel.position = (_viewport_size - _panel.size) * 0.5
    for child in _panel.get_children():
        if child is VBoxContainer:
            child.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
            child.position = Vector2(12, 10)
            child.size = _panel.size - Vector2(24, 20)


func _unhandled_key_input(event: InputEvent) -> void:
    if visible and event is InputEventKey and event.pressed and not event.echo:
        if Input.is_action_just_pressed("game_cancel"):
            _on_cancel_pressed()
            get_viewport().set_input_as_handled()
