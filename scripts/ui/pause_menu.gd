extends CanvasLayer

const PIXEL_FONT := preload("res://scripts/ui/pixel_font.gd")
## Menu jeda: P atau Esc (saat tidak membangun). Simpan/muat, layar penuh, vsync, volume.

var _root: Control
var _load_btn: Button
var _fs_btn: Button
var _vs_btn: Button
var _sh_btn: Button
var _vol: HSlider
var _blocked := false


func _ready() -> void:
    add_to_group("pause_menu")
    layer = 20
    process_mode = Node.PROCESS_MODE_ALWAYS

    _root = Control.new()
    _root.size = Vector2(480, 270)
    _root.visible = false
    var theme := Theme.new()
    theme.default_font = PIXEL_FONT.get_font()
    theme.default_font_size = 8
    _root.theme = theme
    add_child(_root)

    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.65)
    dim.size = Vector2(480, 270)
    _root.add_child(dim)

    var center := CenterContainer.new()
    center.size = Vector2(480, 270)
    _root.add_child(center)
    var panel := PanelContainer.new()
    center.add_child(panel)
    var box := VBoxContainer.new()
    box.custom_minimum_size = Vector2(190, 0)
    box.add_theme_constant_override("separation", 4)
    panel.add_child(box)

    var title := Label.new()
    title.text = "JEDA"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)

    _add_button(box, "Lanjutkan", _toggle)
    _add_button(box, "Simpan (F5)", func() -> void: SaveSystem.save_current())
    _load_btn = _add_button(box, "Muat (F9)", func() -> void: SaveSystem.request_load())
    _fs_btn = _add_button(box, "", func() -> void:
        Settings.set_fullscreen(not Settings.fullscreen)
        _refresh())
    _vs_btn = _add_button(box, "", func() -> void:
        Settings.set_vsync(not Settings.vsync)
        _refresh())

    _sh_btn = _add_button(box, "", func() -> void:
        Settings.set_screen_shake(not Settings.screen_shake)
        _refresh())

    var vl := Label.new()
    vl.text = "Volume"
    box.add_child(vl)
    _vol = HSlider.new()
    _vol.min_value = 0.0
    _vol.max_value = 1.0
    _vol.step = 0.05
    _vol.value = Settings.volume
    _vol.value_changed.connect(func(v: float) -> void: Settings.set_volume(v))
    box.add_child(_vol)

    _add_button(box, "Keluar ke desktop", func() -> void: get_tree().quit())

    Events.menu_requested.connect(_on_menu_requested)
    Events.game_over.connect(func(_d: int) -> void: _blocked = true)
    Events.game_won.connect(func(_d: int) -> void: _blocked = true)
    _refresh()


func _add_button(parent: Control, text: String, action: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.pressed.connect(action)
    parent.add_child(b)
    return b


func _refresh() -> void:
    _fs_btn.text = "Layar penuh: %s" % ("ya" if Settings.fullscreen else "tidak")
    _vs_btn.text = "VSync: %s" % ("ya" if Settings.vsync else "tidak")
    _sh_btn.text = "Guncangan layar: %s" % ("ya" if Settings.screen_shake else "tidak")
    _load_btn.disabled = not SaveSystem.has_save()


func is_open() -> bool:
    return _root.visible


func _on_menu_requested() -> void:
    if not _root.visible:
        _toggle()


func _toggle() -> void:
    if _blocked and not _root.visible:
        return
    var tp := get_tree().get_first_node_in_group("tech_panel")
    if tp != null and tp.is_open() and not _root.visible:
        return
    _root.visible = not _root.visible
    get_tree().paused = _root.visible
    if _root.visible:
        _vol.value = Settings.volume
        _refresh()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_P or (event.keycode == KEY_ESCAPE and _root.visible):
            _toggle()
            get_viewport().set_input_as_handled()
