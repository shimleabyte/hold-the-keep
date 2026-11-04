extends RefCounted
## Owns construction queue panel composition, visibility and row interactions.
## HUD retains viewport ownership, global panel arbitration and the public callbacks.

const HUD_WIDGETS := preload("res://scripts/ui/hud_widgets.gd")

var _hud: Variant


func configure(hud: Variant) -> void:
    _hud = hud


func build() -> void:
    _hud._queue_backdrop = ColorRect.new()
    _hud._queue_backdrop.color = Color(0.015, 0.02, 0.028, 0.86)
    _hud._queue_backdrop.size = _hud._viewport_size
    _hud._queue_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    _hud._queue_backdrop.gui_input.connect(_hud._on_queue_backdrop_input)
    _hud._queue_backdrop.visible = false
    _hud.add_child(_hud._queue_backdrop)
    _hud._blockers.append(_hud._queue_backdrop)

    _hud._queue_panel = _hud._panel(Vector2.ZERO, Vector2(356, 220))
    _hud._queue_panel.visible = false
    var title := _hud._label(_hud._queue_panel, "ANTREAN KONSTRUKSI", Vector2(10, 7), Color("#ffd23f"))
    title.add_theme_font_size_override("font_size", 9)
    _hud._queue_count_label = _hud._label(_hud._queue_panel, "0 PROYEK", Vector2(10, 22), Color("#c9b99d"))
    _hud._queue_count_label.add_theme_font_size_override("font_size", 6)

    var close := HUD_WIDGETS.HudChip.new()
    close.label = "X"
    close.font = _hud._font
    close.position = Vector2(330, 4)
    close.size = Vector2(19, 15)
    close.pressed.connect(_hud._toggle_construction_queue)
    _hud._queue_panel.add_child(close)

    var scroll := ScrollContainer.new()
    scroll.position = Vector2(8, 36)
    scroll.size = Vector2(340, 176)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    _hud._queue_panel.add_child(scroll)

    _hud._queue_list = VBoxContainer.new()
    _hud._queue_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _hud._queue_list.add_theme_constant_override("separation", 3)
    scroll.add_child(_hud._queue_list)


func on_backdrop_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        close()


func toggle() -> void:
    var opening: bool = not _hud._queue_panel.visible
    if opening:
        _hud._map_panel.visible = false
        _hud._map_backdrop.visible = false
        _hud._map_button.active = false
        _hud._map_button.queue_redraw()
        _hud._jobs_panel.visible = false
        _hud._jobs_button.active = false
        _hud._jobs_button.queue_redraw()
        _hud._outpost_panel.visible = false
        _hud._outpost_backdrop.visible = false
        _hud._outpost_button.active = false
        _hud._outpost_button.queue_redraw()
        _hud._help.visible = false
        refresh()
    _hud._queue_panel.visible = opening
    _hud._queue_backdrop.visible = opening
    _hud._queue_button.active = opening
    _hud._queue_button.queue_redraw()


func close() -> void:
    _hud._queue_panel.visible = false
    _hud._queue_backdrop.visible = false
    _hud._queue_button.active = false
    _hud._queue_button.queue_redraw()


func on_changed() -> void:
    if _hud._queue_panel.visible:
        refresh()


func refresh() -> void:
    if _hud._queue_list == null:
        return
    for child in _hud._queue_list.get_children():
        child.queue_free()
    var main_node = _hud.get_tree().get_first_node_in_group("main")
    if main_node == null or main_node.build == null:
        _hud._queue_count_label.text = "GAME BELUM SIAP"
        return
    var sites: Array = main_node.build.construction_queue()
    _hud._queue_count_label.text = "%d PROYEK AKTIF" % sites.size()
    if sites.is_empty():
        var empty := _hud._label(_hud._queue_list, "BELUM ADA BLUEPRINT. PILIH BANGUNAN DAN TEMPATKAN DI PETA.", Vector2.ZERO, Color("#c9b99d"))
        empty.add_theme_font_size_override("font_size", 7)
        empty.custom_minimum_size = Vector2(320, 28)
        return
    for index in sites.size():
        var site = sites[index]
        if not is_instance_valid(site):
            continue
        var row := HUD_WIDGETS.ConstructionQueueRow.new()
        row.site = site
        row.font = _hud._font
        row.order_index = index
        row.can_move_up = index > 0
        row.can_move_down = index < sites.size() - 1
        row.custom_minimum_size = Vector2(328, 32)
        row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.move_requested.connect(_hud._on_queue_move_requested)
        row.cancel_requested.connect(_hud._on_queue_cancel_requested)
        _hud._queue_list.add_child(row)


func move_requested(site, direction: int) -> void:
    var main_node = _hud.get_tree().get_first_node_in_group("main")
    if main_node != null:
        main_node.build.move_construction_site(site, direction)


func cancel_requested(site) -> void:
    var main_node = _hud.get_tree().get_first_node_in_group("main")
    if main_node != null:
        main_node.build.cancel_site(site)
