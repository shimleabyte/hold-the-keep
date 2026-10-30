extends CanvasLayer

const PIXEL_FONT := preload("res://scripts/ui/pixel_font.gd")
## Menu jeda: P atau Esc (saat tidak membangun). Simpan/muat, layar penuh, vsync, volume.

var _root: Control
var _load_btn: Button
var _fs_btn: Button
var _vs_btn: Button
var _sh_btn: Button
var _vol: HSlider
var _menu_center: CenterContainer
var _controls_center: CenterContainer
var _controls_buttons: Dictionary = {}
var _controls_status: Label
var _rebinding_action := ""
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

    _menu_center = CenterContainer.new()
    _menu_center.size = Vector2(480, 270)
    _root.add_child(_menu_center)
    var panel := PanelContainer.new()
    _menu_center.add_child(panel)
    var box := VBoxContainer.new()
    box.custom_minimum_size = Vector2(190, 0)
    box.add_theme_constant_override("separation", 4)
    panel.add_child(box)

    var title := Label.new()
    title.text = "JEDA"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)

    _add_button(box, "Lanjutkan", _toggle)
    _add_button(box, "Atur kontrol", _open_controls)
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
    _build_controls_panel()

    Events.menu_requested.connect(_on_menu_requested)
    Events.game_over.connect(func(_d: int) -> void: _blocked = true)
    Events.game_won.connect(func(_d: int) -> void: _blocked = true)
    _refresh()


func _build_controls_panel() -> void:
    _controls_center = CenterContainer.new()
    _controls_center.size = Vector2(480, 270)
    _controls_center.visible = false
    _root.add_child(_controls_center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(370, 238)
    _controls_center.add_child(panel)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 3)
    panel.add_child(box)

    var title := Label.new()
    title.text = "KONTROL UTAMA"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)

    var hint := Label.new()
    hint.text = "Pilih tombol di kanan, lalu tekan tombol pengganti."
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(hint)

    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(350, 150)
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    box.add_child(scroll)

    var rows := VBoxContainer.new()
    rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    rows.add_theme_constant_override("separation", 2)
    scroll.add_child(rows)

    var labels := {
        "move_up": "GERAK ATAS",
        "move_down": "GERAK BAWAH",
        "move_left": "GERAK KIRI",
        "move_right": "GERAK KANAN",
        "interact": "INTERAKSI",
        "attack": "SERANG",
        "sprint": "LARI"
    }
    for action in Settings.BINDABLE_ACTIONS:
        var row := HBoxContainer.new()
        row.custom_minimum_size.y = 20
        rows.add_child(row)

        var label := Label.new()
        label.text = labels.get(action, action.to_upper())
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        row.add_child(label)

        var key_button := Button.new()
        key_button.custom_minimum_size = Vector2(82, 19)
        key_button.text = Settings.binding_label(action)
        key_button.pressed.connect(_begin_rebind.bind(action))
        row.add_child(key_button)
        _controls_buttons[action] = key_button

    _controls_status = Label.new()
    _controls_status.text = "ESC MEMBATALKAN CAPTURE"
    _controls_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(_controls_status)

    var back := Button.new()
    back.text = "KEMBALI"
    back.pressed.connect(_close_controls)
    box.add_child(back)


func _open_controls() -> void:
    _menu_center.visible = false
    _controls_center.visible = true
    _controls_status.text = "PILIH AKSI UNTUK MENGGANTI TOMBOL"
    for action in Settings.BINDABLE_ACTIONS:
        _controls_buttons[action].text = Settings.binding_label(action)
    _controls_buttons[Settings.BINDABLE_ACTIONS[0]].grab_focus()


func _close_controls() -> void:
    _rebinding_action = ""
    _controls_center.visible = false
    _menu_center.visible = true


func _begin_rebind(action: String) -> void:
    _rebinding_action = action
    _controls_buttons[action].text = "TEKAN..."
    _controls_status.text = "TEKAN TOMBOL BARU — ESC BATAL"


func _capture_binding(event: InputEventKey) -> void:
    if _rebinding_action == "":
        return
    if event.keycode == KEY_ESCAPE:
        _controls_buttons[_rebinding_action].text = Settings.binding_label(_rebinding_action)
        _controls_status.text = "CAPTURE DIBATALKAN"
        _rebinding_action = ""
        return

    var code := int(event.physical_keycode)
    if code == 0:
        code = int(event.keycode)
    var action := _rebinding_action
    if Settings.set_key_binding(action, code):
        _controls_buttons[action].text = Settings.binding_label(action)
        _controls_status.text = "BINDING DISIMPAN"
        _rebinding_action = ""
    else:
        _controls_status.text = "TOMBOL DIPAKAI ATAU TIDAK VALID"


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
    if _controls_center != null and _controls_center.visible:
        _close_controls()
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
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    if _rebinding_action != "":
        _capture_binding(event)
        get_viewport().set_input_as_handled()
        return
    if event.keycode == KEY_ESCAPE and _root.visible:
        if _controls_center.visible:
            _close_controls()
        else:
            _toggle()
        get_viewport().set_input_as_handled()
        return
    if event.keycode == KEY_P:
        _toggle()
        get_viewport().set_input_as_handled()
