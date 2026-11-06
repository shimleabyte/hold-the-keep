class_name TitleScreen
extends CanvasLayer

signal mode_selected(profile_id: String)

const PIXEL_FONT := preload("res://scripts/ui/pixel_font.gd")

const INK := Color("#111719")
const PANEL := Color("#1a2223")
const PANEL_HOVER := Color("#26302f")
const EDGE := Color("#756044")
const GOLD := Color("#d4ad70")
const TEXT := Color("#eadfc9")
const MUTED := Color("#a59b88")

var _continue_button: Button
var _settings_layer: Control
var _settings_center: CenterContainer
var _fullscreen_button: Button
var _vsync_button: Button
var _shake_button: Button
var _volume_slider: HSlider
var _main_first_focus: Control


func _ready() -> void:
    name = "TitleScreen"
    layer = 30
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_screen()


func _build_screen() -> void:
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(root)

    var background := ColorRect.new()
    background.color = INK
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(background)

    var frame := Panel.new()
    frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    frame.offset_left = 14
    frame.offset_top = 14
    frame.offset_right = -14
    frame.offset_bottom = -14
    var frame_style := StyleBoxFlat.new()
    frame_style.bg_color = Color(0, 0, 0, 0)
    frame_style.border_color = Color("#3b4540")
    frame_style.set_border_width_all(1)
    frame.add_theme_stylebox_override("panel", frame_style)
    root.add_child(frame)

    var content := VBoxContainer.new()
    content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.offset_left = 34
    content.offset_top = 24
    content.offset_right = -34
    content.offset_bottom = -22
    content.add_theme_constant_override("separation", 6)
    root.add_child(content)

    var top_line := HBoxContainer.new()
    content.add_child(top_line)
    var edition := _label("A DARK MEDIEVAL SURVIVAL STRATEGY", 8, GOLD)
    edition.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_line.add_child(edition)
    top_line.add_child(_label("BUILD  /  0.1", 7, MUTED))

    var title_scroll := ScrollContainer.new()
    title_scroll.name = "TitleContentScroll"
    title_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    title_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    title_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    content.add_child(title_scroll)

    var title_block := VBoxContainer.new()
    title_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_block.size_flags_vertical = Control.SIZE_EXPAND_FILL
    title_block.alignment = BoxContainer.ALIGNMENT_CENTER
    title_block.add_theme_constant_override("separation", 0)
    title_scroll.add_child(title_block)

    var overline := _label("THE BORDERLANDS ARE NOT YOURS", 8, GOLD)
    overline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_block.add_child(overline)

    var title := _label("HOLD THE KEEP", 34, TEXT)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_block.add_child(title)

    var subtitle := _label("Raise a settlement. Hold the line. Outlast the dark.", 9, MUTED)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_block.add_child(subtitle)

    var separator := ColorRect.new()
    separator.color = EDGE
    separator.custom_minimum_size = Vector2(110, 1)
    separator.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    title_block.add_child(separator)

    var choose := _label("CHOOSE YOUR CAMPAIGN", 9, GOLD)
    choose.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_block.add_child(choose)

    var continue_row := HBoxContainer.new()
    continue_row.alignment = BoxContainer.ALIGNMENT_CENTER
    title_block.add_child(continue_row)
    _continue_button = Button.new()
    _continue_button.name = "ContinueButton"
    _continue_button.text = "CONTINUE LAST CAMPAIGN"
    _continue_button.custom_minimum_size = Vector2(210, 25)
    _style_button(_continue_button, false)
    _continue_button.disabled = not SaveSystem.has_save()
    _continue_button.tooltip_text = "Resume the most recent valid save" if not _continue_button.disabled else "No valid save was found"
    _continue_button.pressed.connect(_continue_campaign)
    continue_row.add_child(_continue_button)

    var modes := HFlowContainer.new()
    modes.name = "CampaignOptions"
    modes.alignment = FlowContainer.ALIGNMENT_CENTER
    modes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    modes.add_theme_constant_override("h_separation", 12)
    modes.add_theme_constant_override("v_separation", 10)
    title_block.add_child(modes)

    # Fit all three campaign choices on the default 640px logical viewport.
    # Narrower screens still wrap naturally instead of clipping the option.
    var available_mode_width := get_viewport().get_visible_rect().size.x - 68.0
    var mode_card_width := clampf((available_mode_width - 36.0) / 3.0, 120.0, 220.0)
    modes.add_child(_mode_card(
        "01  /  CLASSIC",
        "THE LAST HOLD",
        "A 128 × 128 homeland. Establish a settlement, secure the surrounding wilds and hold against a rival civilization.",
        "ENTER CLASSIC",
        "classic",
        mode_card_width
    ))
    modes.add_child(_mode_card(
        "02  /  FRONTIER",
        "A WIDER WAR",
        "A 192 × 192 world of five regions. Expand across distant biomes, secure supply lines and fight rival kingdoms.",
        "ENTER FRONTIER",
        "frontier",
        mode_card_width
    ))
    modes.add_child(_mode_card(
        "03  /  FRONTIER: EXPEDITION",
        "BEYOND THE FRONTIER",
        "A vast 256 × 256 world with a 160 × 160 heartland. Survey sealed crossings, open four outer marches and establish routes to rival strongholds.",
        "FRONTIER: EXPEDITION",
        "frontier_expedition",
        mode_card_width
    ))

    var footer := HBoxContainer.new()
    content.add_child(footer)
    var note := _label("NO ROAD IS SAFE. NO WINTER IS KIND.", 7, MUTED)
    note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    footer.add_child(note)

    var settings := Button.new()
    settings.name = "SettingsButton"
    settings.text = "SETTINGS"
    settings.custom_minimum_size = Vector2(76, 24)
    _style_button(settings, false)
    settings.pressed.connect(_open_settings)
    footer.add_child(settings)

    var quit := Button.new()
    quit.text = "QUIT"
    quit.custom_minimum_size = Vector2(64, 24)
    _style_button(quit, false)
    quit.pressed.connect(func() -> void: get_tree().quit())
    footer.add_child(quit)

    _build_settings_panel()
    _main_first_focus = modes.get_child(0).get_child(0).get_child(3) if _continue_button.disabled else _continue_button
    call_deferred("_grab_initial_focus")


func _build_settings_panel() -> void:
    _settings_layer = Control.new()
    _settings_layer.name = "SettingsPanel"
    _settings_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _settings_layer.visible = false
    _settings_layer.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(_settings_layer)

    var dim := ColorRect.new()
    dim.color = Color(0.01, 0.015, 0.018, 0.88)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _settings_layer.add_child(dim)

    _settings_center = CenterContainer.new()
    _settings_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _settings_layer.add_child(_settings_center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(280, 0)
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = PANEL
    panel_style.border_color = EDGE
    panel_style.set_border_width_all(1)
    panel_style.content_margin_left = 18
    panel_style.content_margin_right = 18
    panel_style.content_margin_top = 14
    panel_style.content_margin_bottom = 14
    panel.add_theme_stylebox_override("panel", panel_style)
    _settings_center.add_child(panel)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 8)
    panel.add_child(box)

    var heading := _label("FIELD SETTINGS", 13, GOLD)
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(heading)

    _fullscreen_button = _settings_toggle(box, "FULLSCREEN", func() -> void:
        Settings.set_fullscreen(not Settings.fullscreen)
        _refresh_settings())
    _vsync_button = _settings_toggle(box, "VERTICAL SYNC", func() -> void:
        Settings.set_vsync(not Settings.vsync)
        _refresh_settings())
    _shake_button = _settings_toggle(box, "SCREEN SHAKE", func() -> void:
        Settings.set_screen_shake(not Settings.screen_shake)
        _refresh_settings())

    var volume_label := _label("MASTER VOLUME", 8, MUTED)
    box.add_child(volume_label)
    _volume_slider = HSlider.new()
    _volume_slider.min_value = 0.0
    _volume_slider.max_value = 1.0
    _volume_slider.step = 0.05
    _volume_slider.value = Settings.volume
    _volume_slider.custom_minimum_size = Vector2(230, 20)
    _volume_slider.value_changed.connect(func(value: float) -> void:
        Settings.set_volume(value))
    box.add_child(_volume_slider)

    var back := Button.new()
    back.text = "RETURN TO TITLE"
    back.custom_minimum_size = Vector2(0, 27)
    _style_button(back, true)
    back.pressed.connect(_close_settings)
    box.add_child(back)
    _refresh_settings()


func _settings_toggle(parent: VBoxContainer, caption: String, callback: Callable) -> Button:
    var button := Button.new()
    button.custom_minimum_size = Vector2(0, 27)
    _style_button(button, false)
    button.pressed.connect(callback)
    parent.add_child(button)
    return button


func _refresh_settings() -> void:
    if _fullscreen_button == null:
        return
    _fullscreen_button.text = "FULLSCREEN  /  %s" % ("ON" if Settings.fullscreen else "OFF")
    _vsync_button.text = "VERTICAL SYNC  /  %s" % ("ON" if Settings.vsync else "OFF")
    _shake_button.text = "SCREEN SHAKE  /  %s" % ("ON" if Settings.screen_shake else "OFF")
    _volume_slider.set_value_no_signal(Settings.volume)


func _open_settings() -> void:
    _refresh_settings()
    _settings_layer.visible = true
    _fullscreen_button.grab_focus()


func _close_settings() -> void:
    _settings_layer.visible = false
    if is_instance_valid(_main_first_focus):
        _main_first_focus.grab_focus()


func _continue_campaign() -> void:
    # SaveSystem restores the exact historical profile dimensions before reloading.
    SaveSystem.request_load()


func _grab_initial_focus() -> void:
    if is_instance_valid(_main_first_focus):
        _main_first_focus.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
    if _settings_layer != null and _settings_layer.visible and event.is_action_pressed("ui_cancel"):
        _close_settings()
        get_viewport().set_input_as_handled()


func _mode_card(
    kicker: String,
    heading: String,
    description: String,
    button_text: String,
    profile_id: String,
    card_width: float
) -> PanelContainer:
    var card := PanelContainer.new()
    card.name = "CampaignCard_" + profile_id
    card.custom_minimum_size = Vector2(card_width, 136)
    var card_style := StyleBoxFlat.new()
    card_style.bg_color = PANEL
    card_style.border_color = EDGE
    card_style.set_border_width_all(1)
    card_style.content_margin_left = 12
    card_style.content_margin_right = 12
    card_style.content_margin_top = 9
    card_style.content_margin_bottom = 9
    card.add_theme_stylebox_override("panel", card_style)

    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation", 5)
    card.add_child(body)
    body.add_child(_label(kicker, 7, GOLD))
    body.add_child(_label(heading, 12, TEXT))
    var copy := _label(description, 7, MUTED)
    copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    copy.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_child(copy)

    var enter := Button.new()
    enter.name = "Select_" + profile_id
    enter.set_meta("campaign_profile_id", profile_id)
    enter.text = button_text
    enter.custom_minimum_size = Vector2(0, 27)
    _style_button(enter, true)
    enter.pressed.connect(func() -> void: mode_selected.emit(profile_id))
    body.add_child(enter)
    return card


func _label(value: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_override("font", PIXEL_FONT.get_font())
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    return label


func _style_button(button: Button, primary: bool) -> void:
    button.focus_mode = Control.FOCUS_ALL
    button.add_theme_font_override("font", PIXEL_FONT.get_font())
    button.add_theme_font_size_override("font_size", 8)
    button.add_theme_color_override("font_color", TEXT)
    button.add_theme_color_override("font_hover_color", Color("#fff0d0"))
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("#55432d") if primary else PANEL
    normal.border_color = GOLD if primary else EDGE
    normal.set_border_width_all(1)
    var hover := StyleBoxFlat.new()
    hover.bg_color = Color("#725638") if primary else PANEL_HOVER
    hover.border_color = Color("#f0cb8c")
    hover.set_border_width_all(1)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", hover)
    button.add_theme_stylebox_override("focus", hover)
