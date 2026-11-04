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
    content.add_theme_constant_override("separation", 8)
    root.add_child(content)

    var top_line := HBoxContainer.new()
    content.add_child(top_line)
    var edition := _label("A DARK MEDIEVAL SURVIVAL STRATEGY", 8, GOLD)
    edition.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_line.add_child(edition)
    top_line.add_child(_label("BUILD  /  0.1", 7, MUTED))

    var title_block := VBoxContainer.new()
    title_block.size_flags_vertical = Control.SIZE_EXPAND_FILL
    title_block.alignment = BoxContainer.ALIGNMENT_CENTER
    title_block.add_theme_constant_override("separation", 0)
    content.add_child(title_block)

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

    var modes := HBoxContainer.new()
    modes.alignment = BoxContainer.ALIGNMENT_CENTER
    modes.add_theme_constant_override("separation", 12)
    title_block.add_child(modes)
    modes.add_child(_mode_card(
        "01  /  CLASSIC",
        "THE LAST HOLD",
        "A compact 64 × 64 frontier. Build your keep, develop your village and survive a focused campaign.",
        "ENTER CLASSIC",
        "classic"
    ))
    modes.add_child(_mode_card(
        "02  /  FRONTIER",
        "A WIDER WAR",
        "A 128 × 128 world of five regions. Expand outward, secure supply lines and conquer rival strongholds.",
        "ENTER FRONTIER",
        "frontier"
    ))

    var footer := HBoxContainer.new()
    content.add_child(footer)
    var note := _label("NO ROAD IS SAFE. NO WINTER IS KIND.", 7, MUTED)
    note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    footer.add_child(note)
    var quit := Button.new()
    quit.text = "QUIT"
    quit.custom_minimum_size = Vector2(64, 24)
    _style_button(quit, false)
    quit.pressed.connect(func() -> void: get_tree().quit())
    footer.add_child(quit)


func _mode_card(kicker: String, heading: String, description: String, button_text: String, profile_id: String) -> PanelContainer:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(220, 126)
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
    body.add_child(_label(heading, 15, TEXT))
    var copy := _label(description, 8, MUTED)
    copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    copy.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_child(copy)

    var enter := Button.new()
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
