extends CanvasLayer

const PIXEL_FONT := preload("res://scripts/ui/pixel_font.gd")
const RESOLUTION_PRESETS := [
    Vector2i(960, 540),
    Vector2i(1024, 768),
    Vector2i(1024, 640),
    Vector2i(1152, 720),
    Vector2i(1280, 720),
    Vector2i(1280, 800),
    Vector2i(1280, 960),
    Vector2i(1366, 768),
    Vector2i(1440, 900),
    Vector2i(1600, 900),
    Vector2i(1600, 1200),
    Vector2i(1680, 1050),
    Vector2i(1920, 1080),
    Vector2i(1920, 1200)
]
## Menu jeda: P atau Esc (saat tidak membangun). Simpan/muat, layar penuh, vsync, volume.

var _root: Control
var _load_btn: Button
var _fs_btn: Button
var _resolution: OptionButton
var _resolution_values: Array[Vector2i] = []
var _vs_btn: Button
var _sh_btn: Button
var _vol: HSlider
var _menu_center: CenterContainer
var _controls_center: CenterContainer
var _controls_buttons: Dictionary = {}
var _controls_status: Label
var _campaign_center: CenterContainer
var _campaign_profile: OptionButton
var _campaign_info: Label
var _campaign_dialog: ConfirmationDialog
var _rebinding_action := ""
var _blocked := false


func _ready() -> void:
    add_to_group("pause_menu")
    layer = 20
    process_mode = Node.PROCESS_MODE_ALWAYS

    _root = Control.new()
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.visible = false
    var theme := Theme.new()
    theme.default_font = PIXEL_FONT.get_font()
    theme.default_font_size = 8

    var button_normal := StyleBoxFlat.new()
    button_normal.bg_color = Color("#20282a")
    button_normal.border_color = Color("#756044")
    button_normal.set_border_width_all(1)
    var button_hover := StyleBoxFlat.new()
    button_hover.bg_color = Color("#354044")
    button_hover.border_color = Color("#d0a35e")
    button_hover.set_border_width_all(1)
    var button_pressed := StyleBoxFlat.new()
    button_pressed.bg_color = Color("#51402b")
    button_pressed.border_color = Color("#e8c078")
    button_pressed.set_border_width_all(1)
    theme.set_stylebox("normal", "Button", button_normal)
    theme.set_stylebox("hover", "Button", button_hover)
    theme.set_stylebox("pressed", "Button", button_pressed)
    theme.set_stylebox("focus", "Button", button_hover)
    theme.set_stylebox("normal", "OptionButton", button_normal)
    theme.set_stylebox("hover", "OptionButton", button_hover)
    theme.set_stylebox("pressed", "OptionButton", button_pressed)
    theme.set_stylebox("focus", "OptionButton", button_hover)
    theme.set_color("font_color", "Button", Color("#eadcc1"))
    theme.set_color("font_color", "OptionButton", Color("#eadcc1"))
    theme.set_color("font_hover_color", "Button", Color("#fff1d2"))
    theme.set_color("font_pressed_color", "Button", Color("#ffd38d"))
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color("#171d20")
    panel_style.border_color = Color("#a17b4d")
    panel_style.set_border_width_all(1)
    panel_style.shadow_color = Color(0, 0, 0, 0.58)
    panel_style.shadow_size = 5
    panel_style.shadow_offset = Vector2(0, 3)
    theme.set_stylebox("panel", "PanelContainer", panel_style)
    _root.theme = theme
    add_child(_root)

    var dim := ColorRect.new()
    dim.color = Color(0.015, 0.02, 0.028, 0.82)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.add_child(dim)

    _menu_center = CenterContainer.new()
    _menu_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.add_child(_menu_center)
    var panel := PanelContainer.new()
    _menu_center.add_child(panel)
    var box := VBoxContainer.new()
    box.custom_minimum_size = Vector2(190, 0)
    box.add_theme_constant_override("separation", 3)
    panel.add_child(box)

    var title := Label.new()
    title.text = "JEDA"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)

    _add_button(box, "Lanjutkan", _toggle)
    _add_button(box, "Atur kontrol", _open_controls)
    _add_button(box, "Simpan (F5)", func() -> void: SaveSystem.save_current())
    _load_btn = _add_button(box, "Muat (F9)", func() -> void: SaveSystem.request_load())
    _add_button(box, "Kampanye baru", _open_campaign_panel)
    _fs_btn = _add_button(box, "", func() -> void:
        Settings.set_fullscreen(not Settings.fullscreen)
        _refresh())

    var resolution_label := Label.new()
    resolution_label.text = "RESOLUSI JENDELA"
    box.add_child(resolution_label)
    _resolution = OptionButton.new()
    _resolution.custom_minimum_size = Vector2(190, 18)
    var screen_size := DisplayServer.screen_get_size()
    for preset in RESOLUTION_PRESETS:
        if preset.x <= screen_size.x and preset.y <= screen_size.y:
            _resolution_values.append(preset)
            _resolution.add_item("%d x %d" % [preset.x, preset.y])
    if not _resolution_values.has(Settings.windowed_size):
        _resolution_values.append(Settings.windowed_size)
        _resolution.add_item("%d x %d" % [Settings.windowed_size.x, Settings.windowed_size.y])
    _resolution.item_selected.connect(_on_resolution_selected)
    box.add_child(_resolution)

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
    _vol.custom_minimum_size = Vector2(190, 15)
    box.add_child(_vol)

    _add_button(box, "Keluar ke desktop", func() -> void: get_tree().quit())
    _build_controls_panel()
    _build_campaign_panel()

    Events.menu_requested.connect(_on_menu_requested)
    Events.game_over.connect(func(_d: int) -> void: _blocked = true)
    Events.game_won.connect(func(_d: int) -> void: _blocked = true)
    Events.campaign_won.connect(func(_d: int) -> void: _blocked = true)
    _refresh()


func _build_controls_panel() -> void:
    _controls_center = CenterContainer.new()
    _controls_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _controls_center.visible = false
    _root.add_child(_controls_center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(410, 248)
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
    scroll.custom_minimum_size = Vector2(390, 148)
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    box.add_child(scroll)

    var rows := VBoxContainer.new()
    rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    rows.add_theme_constant_override("separation", 2)
    scroll.add_child(rows)

    var labels := {"move_up":"GERAK ATAS","move_down":"GERAK BAWAH","move_left":"GERAK KIRI","move_right":"GERAK KANAN","interact":"INTERAKSI","attack":"SERANG","sprint":"LARI","ability_dash":"DASH","ability_cleave":"TEBAS","ability_rally":"SERUAN","job_woodcutter":"PENEBANG","job_miner":"PENAMBANG","job_farmer":"PETANI","job_builder":"PEMBANGUN","job_hunter":"PEMBURU","job_scout":"PENGINTAI","job_healer":"PENYEMBUH","job_blacksmith":"PANDAI BESI","job_soldier":"PRAJURIT","menu_pause":"MENU / JEDA","toggle_technology":"TEKNOLOGI","toggle_objectives":"OBJEKTIF","toggle_map":"PETA","toggle_help":"BANTUAN","toggle_fps":"TAMPILKAN FPS","toggle_construction_queue":"ANTREAN KONSTRUKSI","command_expedition":"KOMANDO EKSPEDISI","save_game":"SIMPAN","load_game":"MUAT SAVE"}
    for group_value in Settings.BINDABLE_GROUPS:
        var group: Dictionary = group_value
        var heading := Label.new()
        heading.text = String(group.get("title", "CONTROLS"))
        heading.add_theme_color_override("font_color", Color("#d0ad70"))
        rows.add_child(heading)
        for action_value in group.get("actions", []):
            var action := String(action_value)
            var row := HBoxContainer.new()
            row.custom_minimum_size = Vector2(0, 20)
            rows.add_child(row)

            var label := Label.new()
            label.text = String(labels.get(action, action.to_upper()))
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

    var control_actions := HBoxContainer.new()
    control_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    box.add_child(control_actions)

    var reset := Button.new()
    reset.text = "PULIHKAN DEFAULT"
    reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    reset.pressed.connect(_restore_default_bindings)
    control_actions.add_child(reset)

    var back := Button.new()
    back.text = "KEMBALI"
    back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    back.pressed.connect(_close_controls)
    control_actions.add_child(back)


func _build_campaign_panel() -> void:
    _campaign_center = CenterContainer.new()
    _campaign_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _campaign_center.visible = false
    _root.add_child(_campaign_center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(250, 150)
    _campaign_center.add_child(panel)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 5)
    panel.add_child(box)

    var title := Label.new()
    title.text = "KAMPANYE BARU"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(title)

    _campaign_info = Label.new()
    _campaign_info.custom_minimum_size = Vector2(220, 44)
    _campaign_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _campaign_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(_campaign_info)

    var profile_label := Label.new()
    profile_label.text = "PROFIL DUNIA"
    profile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(profile_label)

    _campaign_profile = OptionButton.new()
    _campaign_profile.custom_minimum_size = Vector2(220, 20)
    _campaign_profile.add_item("CLASSIC · 64 × 64")
    _campaign_profile.add_item("FRONTIER · 128 × 128")
    _campaign_profile.add_item("FRONTIER EXPEDITION · 192 × 192")
    _campaign_profile.item_selected.connect(_on_campaign_profile_selected)
    box.add_child(_campaign_profile)

    var start := Button.new()
    start.text = "MULAI KAMPANYE"
    start.custom_minimum_size = Vector2(220, 20)
    start.pressed.connect(_confirm_new_campaign)
    box.add_child(start)

    var back := Button.new()
    back.text = "KEMBALI"
    back.custom_minimum_size = Vector2(220, 20)
    back.pressed.connect(_close_campaign_panel)
    box.add_child(back)

    _campaign_dialog = ConfirmationDialog.new()
    _campaign_dialog.title = "KAMPANYE BARU"
    _campaign_dialog.dialog_text = "Mulai dunia baru? Save lama akan menjadi backup sementara dan dapat diganti oleh penyimpanan berikutnya."
    _campaign_dialog.ok_button_text = "MULAI"
    _campaign_dialog.cancel_button_text = "BATAL"
    _campaign_dialog.confirmed.connect(_start_new_campaign)
    _root.add_child(_campaign_dialog)

    _campaign_profile.select(_profile_option_index(WorldConfig.profile_id))
    _on_campaign_profile_selected(_campaign_profile.selected)


func _profile_option_index(profile_id: String) -> int:
    match profile_id:
        "frontier":
            return 1
        "frontier_expedition":
            return 2
    return 0


func _on_campaign_profile_selected(index: int) -> void:
    if _campaign_info == null:
        return
    match index:
        1:
            _campaign_info.text = "128 × 128 tiles · lima region · kampanye Conquest 20 hari."
        2:
            _campaign_info.text = "192 × 192 tiles · 2.25× luas Frontier · empat outer marches terbuka melalui discovery. Fog permanen menyimpan jejak eksplorasi."
        _:
            _campaign_info.text = "64 × 64 tiles · campaign 15 hari · map Classic tetap seperti semula."


func _open_campaign_panel() -> void:
    _menu_center.visible = false
    _controls_center.visible = false
    _campaign_profile.select(_profile_option_index(WorldConfig.profile_id))
    _on_campaign_profile_selected(_campaign_profile.selected)
    _campaign_center.visible = true


func _close_campaign_panel() -> void:
    _campaign_center.visible = false
    _menu_center.visible = true


func _confirm_new_campaign() -> void:
    _campaign_dialog.popup_centered()


func _start_new_campaign() -> void:
    var selected_profile := "classic"
    match _campaign_profile.selected:
        1:
            selected_profile = "frontier"
        2:
            selected_profile = "frontier_expedition"
    if not WorldConfig.apply_profile(selected_profile):
        return
    Settings.set_world_profile(selected_profile)
    Inventory.reset()
    GameClock.reset()
    Tech.reset()
    SaveSystem.pending.clear()
    get_tree().paused = false
    get_tree().reload_current_scene()


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


func _restore_default_bindings() -> void:
    Settings.restore_default_bindings()
    for action in Settings.BINDABLE_ACTIONS:
        _controls_buttons[action].text = Settings.binding_label(action)
    _controls_status.text = "DEFAULT DIPULIHKAN"


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
    b.custom_minimum_size = Vector2(190, 18)
    b.pressed.connect(action)
    parent.add_child(b)
    return b


func _refresh() -> void:
    _fs_btn.text = "Layar penuh: %s" % ("ya" if Settings.fullscreen else "tidak")
    _vs_btn.text = "VSync: %s" % ("ya" if Settings.vsync else "tidak")
    _sh_btn.text = "Guncangan layar: %s" % ("ya" if Settings.screen_shake else "tidak")
    _load_btn.disabled = not SaveSystem.has_save()
    _resolution.disabled = Settings.fullscreen
    var selected_index := _resolution_values.find(Settings.windowed_size)
    if selected_index >= 0:
        _resolution.select(selected_index)


func _on_resolution_selected(index: int) -> void:
    if index < 0 or index >= _resolution_values.size():
        return
    Settings.set_window_size(_resolution_values[index])
    _refresh()


func is_open() -> bool:
    return _root.visible


func _on_menu_requested() -> void:
    if not _root.visible:
        _toggle()


func _toggle() -> void:
    if _campaign_center != null and _campaign_center.visible:
        _close_campaign_panel()
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
    if event is InputEventKey and event.pressed and not event.echo:
        if _rebinding_action != "":
            _capture_binding(event)
            get_viewport().set_input_as_handled()
            return
        if Input.is_action_just_pressed("game_cancel") and _root.visible:
            if _campaign_center.visible:
                _close_campaign_panel()
            elif _controls_center.visible:
                _close_controls()
            else:
                _toggle()
            get_viewport().set_input_as_handled()
            return
        if Input.is_action_just_pressed("menu_pause"):
            _toggle()
            get_viewport().set_input_as_handled()
