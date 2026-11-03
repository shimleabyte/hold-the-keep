extends CanvasLayer

const PIXEL_FONT := preload("res://scripts/ui/pixel_font.gd")
var campaign
var _panel: Panel
var _body: Label
var _font: Font
var _timer := 0.0


func _ready() -> void:
    layer = 16
    process_mode = Node.PROCESS_MODE_ALWAYS
    _font = PIXEL_FONT.get_font()
    _panel = Panel.new()
    _panel.position = Vector2(6, 38)
    _panel.size = Vector2(264, 192)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#111a1d")
    style.border_color = Color("#a17b4d")
    style.set_border_width_all(1)
    _panel.add_theme_stylebox_override("panel", style)
    _panel.visible = false
    add_child(_panel)

    var title := Label.new()
    title.text = "FRONTIER OBJECTIVES  [O]"
    title.position = Vector2(8, 6)
    title.add_theme_font_override("font", _font)
    title.add_theme_font_size_override("font_size", 8)
    title.add_theme_color_override("font_color", Color("#ffd27e"))
    _panel.add_child(title)

    _body = Label.new()
    _body.position = Vector2(8, 22)
    _body.size = Vector2(248, 164)
    _body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _body.add_theme_font_override("font", _font)
    _body.add_theme_font_size_override("font_size", 7)
    _body.add_theme_color_override("font_color", Color("#eadfc9"))
    _panel.add_child(_body)
    Events.frontier_objective_changed.connect(func(_id: String, _done: bool) -> void: _refresh())
    Events.frontier_act_unlocked.connect(func(_act: int) -> void: _refresh())
    _refresh()


func _process(delta: float) -> void:
    _timer -= delta
    if _timer <= 0.0:
        _timer = 0.5
        if _panel.visible:
            _refresh()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_O:
        if WorldConfig.is_frontier_profile():
            _panel.visible = not _panel.visible
            _refresh()
            get_viewport().set_input_as_handled()


func _refresh() -> void:
    if campaign != null:
        _body.text = campaign.objective_summary()
