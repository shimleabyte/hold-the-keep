extends CanvasLayer
## Panel teknologi: tombol Y atau tombol RISET di HUD. Tiga kolom era (Kayu, Batu, Besi).
## Klik kotak untuk memulai riset; arahkan mouse untuk melihat deskripsi dan syarat.
## Game di-pause selama panel terbuka (Y atau Esc menutup).

const PIXEL_FONT := preload("res://scripts/ui/pixel_font.gd")
const ICONS := {
    "wood": preload("res://assets/sprites/icon_wood.svg"),
    "stone": preload("res://assets/sprites/icon_stone.svg"),
    "iron": preload("res://assets/sprites/icon_iron.svg"),
}
const ERA_COLORS := [Color.WHITE, Color("#c9a06a"), Color("#aeb3b9"), Color("#e8803a")]
const NODE_W := 136
const NODE_H := 25
const STEP := 27
const COL_X := [10, 160, 310]
const TOP := 36
const GOLD := Color("#ffd23f")

var _font: Font
var _root: Control
var _dim: ColorRect
var _panel: Panel
var _nodes: Dictionary = {}
var _era_labels: Array = []
var _head_bar: StatBar
var _head_text: Label
var _foot: Array = []
var _hover_id := ""
var _blocked := false
var _scan_t := 0.0


func _ready() -> void:
    add_to_group("tech_panel")
    layer = 15
    process_mode = Node.PROCESS_MODE_ALWAYS
    _font = PIXEL_FONT.get_font()

    _root = Control.new()
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.visible = false
    add_child(_root)

    _dim = ColorRect.new()
    _dim.color = Color(0.015, 0.02, 0.028, 0.82)
    _dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.add_child(_dim)

    _panel = Panel.new()
    _panel.size = Vector2(472, 264)
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color("#171d20")
    sb.border_color = Color("#a17b4d")
    sb.set_border_width_all(1)
    sb.shadow_color = Color(0, 0, 0, 0.58)
    sb.shadow_size = 5
    sb.shadow_offset = Vector2(0, 3)
    _panel.add_theme_stylebox_override("panel", sb)
    _root.add_child(_panel)

    _label(_panel, "TECHNOLOGY", Vector2(8, 5), GOLD)
    _head_text = _label(_panel, "", Vector2(250, 5), Color.WHITE)
    _head_bar = StatBar.new()
    _head_bar.position = Vector2(372, 7)
    _head_bar.size = Vector2(90, 6)
    _head_bar.fill = Color("#6fcf5a")
    _panel.add_child(_head_bar)

    for e in 3:
        var l := _label(_panel, "ERA " + Tech.ERA_NAMES[e + 1], Vector2(COL_X[e] - 4 + 2, 20))
        _era_labels.append(l)

    var per_era := [0, 0, 0]
    for id in DataDB.tech_order:
        var t: Dictionary = DataDB.techs[id]
        var era := int(t["era"]) - 1
        var node := TechNode.new()
        node.id = id
        node.font = _font
        node.title = String(t["name"])
        node.time_text = "%dS" % int(t["time"])
        var costs: Array = []
        var cost := Tech.cost_of(id)
        for kind in ["wood", "stone", "iron"]:
            if cost.has(kind):
                costs.append([kind, int(cost[kind])])
        node.costs = costs
        node.icons = ICONS
        node.position = Vector2(COL_X[era] - 4, TOP - 4 + per_era[era] * STEP)
        node.size = Vector2(NODE_W, NODE_H)
        node.pressed.connect(_on_node_pressed)
        node.hovered.connect(_on_node_hover)
        _panel.add_child(node)
        _nodes[id] = node
        per_era[era] += 1

    for i in 3:
        _foot.append(_label(_panel, "", Vector2(8, 222 + i * 10), Color.WHITE))

    Events.tech_panel_requested.connect(_open)
    Events.tech_researched.connect(func(_id: String) -> void: _refresh())
    Events.supply_cost_source_changed.connect(_refresh)
    Events.supply_stock_changed.connect(_refresh)
    Events.game_over.connect(func(_d: int) -> void: _force_close())
    Events.game_won.connect(func(_d: int) -> void: _force_close())
    Events.campaign_won.connect(func(_d: int) -> void: _force_close())
    get_viewport().size_changed.connect(_layout_viewport)
    if not Settings.content_viewport_resized.is_connected(_layout_viewport):
        Settings.content_viewport_resized.connect(_layout_viewport)
    _layout_viewport()


func _label(parent: Node, text: String, pos: Vector2, color := Color.WHITE) -> Label:
    var l := Label.new()
    l.text = text
    l.position = pos
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    l.add_theme_font_override("font", _font)
    l.add_theme_font_size_override("font_size", 8)
    l.add_theme_color_override("font_color", color)
    parent.add_child(l)
    return l


func _layout_viewport(target_size: Vector2i = Vector2i.ZERO) -> void:
    var viewport_size := Vector2(target_size) if target_size != Vector2i.ZERO else get_viewport().get_visible_rect().size
    _panel.position = (viewport_size - _panel.size) * 0.5
    _root.queue_redraw()


func is_open() -> bool:
    return _root.visible


func _force_close() -> void:
    _blocked = true
    if _root.visible:
        _root.visible = false


func _open() -> void:
    if not _root.visible:
        _toggle()


func _toggle() -> void:
    if _blocked and not _root.visible:
        return
    var menu := get_tree().get_first_node_in_group("pause_menu")
    if menu != null and menu.is_open() and not _root.visible:
        return
    _root.visible = not _root.visible
    get_tree().paused = _root.visible
    if _root.visible:
        _hover_id = ""
        _refresh()
        _show_info("")


func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey and event.pressed and not event.echo):
        return
    if Input.is_action_just_pressed("toggle_technology") or (
        Input.is_action_just_pressed("game_cancel") and _root.visible
    ):
        _toggle()
        get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
    if not _root.visible:
        return
    _scan_t -= delta
    if _scan_t <= 0.0:
        _scan_t = 0.25
        _refresh()


func _state_of(id: String) -> String:
    if Tech.is_done(id):
        return "done"
    if Tech.current == id:
        return "researching"
    if not Tech.prerequisites_met(id):
        return "locked"
    return "available" if Tech.reason(id) == "" else "short"


func _refresh() -> void:
    for id in _nodes:
        var n: TechNode = _nodes[id]
        n.state = _state_of(id)
        n.progress = Tech.progress_ratio() if n.state == "researching" else 0.0
        n.afford = {}
        var supply = get_tree().get_first_node_in_group("supply_network")
        for c in n.costs:
            n.afford[c[0]] = supply.can_pay_cost({String(c[0]): int(c[1])}) if supply != null else Inventory.get_amount(c[0]) >= int(c[1])
        n.queue_redraw()
    for e in 3:
        _era_labels[e].add_theme_color_override("font_color", ERA_COLORS[e + 1] if Tech.era >= e + 1 else Color(1, 1, 1, 0.35))
        _era_labels[e].text = "ERA " + Tech.ERA_NAMES[e + 1] + ("" if Tech.era >= e + 1 else " (TERKUNCI)")
    if Tech.current != "":
        _head_text.text = "RISET: " + Tech.tech_name(Tech.current).substr(0, 14)
        _head_bar.set_value(Tech.progress_ratio())
        _head_bar.visible = true
    else:
        _head_text.text = "TIDAK ADA RISET"
        _head_bar.visible = false


func _on_node_hover(id: String) -> void:
    _hover_id = id
    _show_info(id)


func _show_info(id: String, result := "") -> void:
    if id == "":
        _foot[0].text = "Klik teknologi untuk meriset. Bahan dibayar di awal."
        _foot[1].text = ""
        _foot[2].text = ""
        return
    var t: Dictionary = DataDB.techs[id]
    _foot[0].text = "%s  (%d detik)" % [t["name"], int(t["time"])]
    _foot[0].add_theme_color_override("font_color", GOLD)
    _foot[1].text = String(t["desc"])
    var line := result
    var col := Color("#ffb347")
    var why := Tech.reason(id)
    if line == "":
        if Tech.is_done(id):
            line = "SELESAI"
            col = Color("#6fcf5a")
        elif why == "":
            line = "KLIK UNTUK MERISET"
            col = Color("#6fcf5a")
        else:
            line = why.to_upper()
    # Daftar syarat ditampilkan kecuali alasan penolakan sudah menyebut prasyarat yang kurang.
    var reqs: Array = []
    for r in t["requires"]:
        reqs.append(Tech.tech_name(r))
    var show_reqs := not reqs.is_empty() and not why.begins_with("Butuh: ") and not Tech.is_done(id)
    var prefix := ("SYARAT: " + ", ".join(reqs) + "  |  ") if show_reqs else ""
    _foot[2].text = prefix + line
    _foot[2].add_theme_color_override("font_color", col)


func _on_node_pressed(id: String) -> void:
    var why := Tech.reason(id)
    if why == "":
        Tech.start(id)
        _refresh()
        _show_info(id, "RISET DIMULAI")
    else:
        _show_info(id, why.to_upper())


## Satu kotak teknologi: nama, biaya, waktu, dan status.
class TechNode extends Control:
    signal pressed(id: String)
    signal hovered(id: String)
    var id := ""
    var title := ""
    var time_text := ""
    var costs: Array = []
    var icons: Dictionary = {}
    var font: Font
    var state := "locked"
    var progress := 0.0
    var afford: Dictionary = {}
    var hover := false

    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_STOP
        mouse_entered.connect(func() -> void:
            hover = true
            hovered.emit(id)
            queue_redraw())
        mouse_exited.connect(func() -> void:
            hover = false
            queue_redraw())

    func _gui_input(event: InputEvent) -> void:
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            pressed.emit(id)
            accept_event()

    func _draw() -> void:
        var bg := Color(0.13, 0.12, 0.16)
        var border := Color("#3a3a44")
        var text := Color(1, 1, 1, 0.4)
        match state:
            "done":
                bg = Color(0.1, 0.2, 0.12)
                border = Color("#6fcf5a")
                text = Color("#bfe8b5")
            "researching":
                bg = Color(0.2, 0.17, 0.08)
                border = Color("#ffd23f")
                text = Color("#ffd23f")
            "available":
                border = Color("#e8dcb8")
                text = Color.WHITE
            "short":
                border = Color("#6b5a40")
                text = Color(1, 1, 1, 0.75)
        if hover:
            bg = bg.lightened(0.15)
        draw_rect(Rect2(Vector2.ZERO, size), bg)
        if state == "researching":
            draw_rect(Rect2(1, size.y - 4, (size.x - 2) * progress, 3), Color("#6fcf5a"))
        draw_rect(Rect2(Vector2.ZERO, size), border, false, 1.0)
        draw_string(font, Vector2(4, 10), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 8, 8, text)
        if state == "done":
            draw_string(font, Vector2(4, 22), "SELESAI", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#6fcf5a"))
            return
        var x := 4.0
        for c in costs:
            var ok: bool = afford.get(c[0], true)
            var a := 1.0 if state != "locked" else 0.4
            draw_texture(icons[c[0]], Vector2(x, 14), Color(1, 1, 1, a))
            x += 11.0
            var s := str(c[1])
            var col := Color(1, 1, 1, a) if ok else Color("#ff8a7a")
            draw_string(font, Vector2(x, 22), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
            x += font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 4.0
        draw_string(font, Vector2(size.x - 28, 22), time_text, HORIZONTAL_ALIGNMENT_RIGHT, 24, 8, Color(1, 1, 1, 0.55))


## Bar horizontal sederhana.
class StatBar extends Control:
    var value := 0.0
    var fill := Color("#6fcf5a")

    func set_value(v: float) -> void:
        value = clampf(v, 0.0, 1.0)
        queue_redraw()

    func _draw() -> void:
        draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
        draw_rect(Rect2(1, 1, (size.x - 2.0) * value, size.y - 2.0), fill)
        draw_rect(Rect2(Vector2.ZERO, size), Color("#1a1410"), false, 1.0)
