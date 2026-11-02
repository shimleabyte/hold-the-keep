extends CanvasLayer
## HUD: panel atas (sumber daya, jam, musuh, penduduk), vitals, kuota job (bisa diklik),
## bar boss, bar bangunan (bisa diklik), bantuan (H), dan layar game over / menang.

const PIXEL_FONT := preload("res://scripts/ui/pixel_font.gd")
const MAP_PANEL_SCRIPT := preload("res://scripts/ui/world_map_panel.gd")
const ICONS := {
    "wood": preload("res://assets/sprites/icon_wood.svg"),
    "stone": preload("res://assets/sprites/icon_stone.svg"),
    "food": preload("res://assets/sprites/icon_food.svg"),
    "heart": preload("res://assets/sprites/icon_heart.svg"),
    "keep": preload("res://assets/sprites/icon_keep.svg"),
    "people": preload("res://assets/sprites/icon_people.svg"),
    "sun": preload("res://assets/sprites/icon_sun.svg"),
    "moon": preload("res://assets/sprites/icon_moon.svg"),
    "skull": preload("res://assets/sprites/icon_skull.svg"),
    "axe": preload("res://assets/sprites/icon_axe.svg"),
    "pick": preload("res://assets/sprites/icon_pick.svg"),
    "wheat": preload("res://assets/sprites/icon_wheat.svg"),
    "sword": preload("res://assets/sprites/icon_sword.svg"),
    "house": preload("res://assets/sprites/icon_house.svg"),
    "wall": preload("res://assets/sprites/icon_wall.svg"),
    "tower": preload("res://assets/sprites/icon_tower.svg"),
    "storage": preload("res://assets/sprites/icon_storage.svg"),
    "farm": preload("res://assets/sprites/icon_farm.svg"),
    "iron": preload("res://assets/sprites/icon_iron.svg"),
    "tech": preload("res://assets/sprites/icon_tech.svg"),
    "stone_wall": preload("res://assets/sprites/icon_stone_wall.svg"),
    "forge": preload("res://assets/sprites/icon_forge.svg"),
    "outpost": preload("res://assets/sprites/icon_outpost.svg"),
    "hammer": preload("res://assets/sprites/icon_hammer.svg"),
    "road": preload("res://assets/sprites/icon_road.svg"),
    "bridge": preload("res://assets/sprites/icon_bridge.svg"),
    "lumber_camp": preload("res://assets/sprites/icon_lumber_camp.svg"),
    "quarry": preload("res://assets/sprites/icon_quarry.svg"),
}
const JOBS := ["woodcutter", "miner", "farmer", "builder", "soldier"]
const JOB_ICONS := {"woodcutter": "axe", "miner": "pick", "farmer": "wheat", "builder": "hammer", "soldier": "sword"}
const PANEL_BG := Color(0.09, 0.08, 0.11, 0.82)
const PANEL_BORDER := Color("#6b5a40")
const GOLD := Color("#ffd23f")
const SLOT_W := 70
const SLOT_H := 30

const HELP_ROWS := [
    ["WASD", "GERAK"],
    ["TAHAN SHIFT", "LARI"],
    ["Y", "TEKNOLOGI (RISET)"],
    ["E / SPASI", "TEBANG, TAMBANG"],
    ["F / KLIK", "SERANG"],
    ["Q", "DASH (LEVEL 1)"],
    ["C", "TEBAS (LEVEL 2)"],
    ["V", "SERUAN (LEVEL 3)"],
    ["1-9 / 0", "PILIH BANGUNAN"],
    ["B / QUEUE", "ANTREAN KONSTRUKSI"],
    ["KLIK KIRI", "PASANG BANGUNAN"],
    ["KLIK KANAN", "BATAL / BONGKAR"],
    ["T M K R B", "TAMBAH JOB"],
    ["G", "SERBU / TARIK PRAJURIT"],
    ["SHIFT + T M K R B", "KURANGI JOB"],
    ["ALT + T/M/K/R/B", "NAIKKAN PRIORITAS"],
    ["ALT + SHIFT + KEY", "TURUNKAN PRIORITAS"],
    ["KLIK + / -", "UBAH KUOTA JOB"],
    ["P / ESC", "MENU"],
    ["F5 / F9", "SIMPAN / MUAT"],
    ["F3", "TAMPILKAN FPS"],
    ["TAB", "PETA WILAYAH"],
    ["O", "OBJEKTIF CONQUEST"],
    ["E (DI SITUS)", "INTERAKSI OBJEKTIF"],
    ["JOBS", "PANEL KUOTA"],
]

var _font: Font
var _viewport_size := Vector2(480, 270)
var _top_bar: Panel
var _clock_widget: ClockWidget
var _people_icon: TextureRect
var _vitals_panel: Panel
var _stage_panel: Panel
var _build_left_hint: Label
var _build_right_hint: Label
var _queue_button: HudChip
var _queue_backdrop: ColorRect
var _queue_panel: Panel
var _queue_count_label: Label
var _queue_list: VBoxContainer
var _blockers: Array[Control] = []

var _wood: Label
var _stone: Label
var _food: Label
var _pop: Label
var _foes_icon: TextureRect
var _foes: Label
var _fps: Label
var _iron: Label
var _iron_icon: TextureRect
var _tech_btn: TechButton
var _map_button: HudChip
var _jobs_button: HudChip
var _jobs_panel: Panel
var _outpost_button: HudChip
var _outpost_backdrop: ColorRect
var _outpost_panel: Panel
var _outpost_list: VBoxContainer
var _cost_source_option: OptionButton
var _shipment_source: OptionButton
var _shipment_destination: OptionButton
var _shipment_kind: OptionButton
var _shipment_amount: SpinBox
var _shipment_send_button: Button
var _shipment_orders_list: VBoxContainer
var _shipment_refreshing := false
var _outpost_refresh_t := 0.0
var _map_backdrop: ColorRect
var _map_panel
var _stage_label: Label
var _stage_bar: StatBar
var _research_panel: Panel
var _research_name: Label
var _research_bar: StatBar
var _slot_nodes: Array = []
var _hp_bar: StatBar
var _hp_text: Label
var _keep_bar: StatBar
var _keep_text: Label
var _combat_bar: CombatBar
var _boss_panel: Panel
var _boss_bar: StatBar
var _boss_title: Label
var _jobs: Dictionary = {}
var _slots: Dictionary = {}
var _help: Panel
var _msg: Label
var _banner: Label
var _over: ColorRect
var _over_label: Label

var _selected := ""
var _msg_tween: Tween
var _banner_tween: Tween
var _scan_t := 0.0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS  # supaya tombol R/H jalan saat tree di-pause
    add_to_group("hud")
    _font = PIXEL_FONT.get_font()

    _build_top_bar()
    _build_vitals()
    _build_stage_bar()
    _build_combat_bar()
    _build_jobs()
    _build_boss_bar()
    _build_build_bar()
    _build_help()
    _build_messages()
    _build_overlay()
    _build_map()
    _build_outpost_panel()
    _build_construction_queue_panel()

    Events.resource_changed.connect(_on_resource_changed)
    Events.supply_cost_source_changed.connect(_on_supply_state_changed)
    Events.supply_stock_changed.connect(_on_supply_state_changed)
    Events.supply_pressure_changed.connect(_on_supply_state_changed)
    Events.build_selected.connect(_on_build_selected)
    Events.construction_queue_changed.connect(_on_construction_queue_changed)
    Events.build_feedback.connect(_show_message)
    Events.player_hp_changed.connect(_on_player_hp)
    Events.keep_hp_changed.connect(_on_keep_hp)
    Events.game_over.connect(_on_game_over)
    Events.game_won.connect(_on_game_won)
    Events.campaign_won.connect(_on_campaign_won)
    Events.event_triggered.connect(_on_event)
    Events.village_changed.connect(_on_village_changed)
    Events.tech_researched.connect(_on_tech_changed)
    Events.stage_changed.connect(_on_stage_changed)
    var main_node = get_tree().get_first_node_in_group("main")
    if main_node != null:
        var initial_stage: Dictionary = main_node.spawner.stage_info(GameClock.day)
        _on_stage_changed(String(initial_stage.get("id", "frontier")), String(initial_stage.get("name", "PERBATASAN")), GameClock.day)
    _refresh_resources()
    _refresh_slots()
    get_viewport().size_changed.connect(_on_viewport_size_changed)
    if not Settings.content_viewport_resized.is_connected(_on_content_viewport_resized):
        Settings.content_viewport_resized.connect(_on_content_viewport_resized)
    _layout_viewport()


# ---------------------------------------------------------------- pembangun UI

func _panel(pos: Vector2, panel_size: Vector2, parent: Node = null) -> Panel:
    var p := Panel.new()
    p.position = pos
    p.size = panel_size
    var sb := StyleBoxFlat.new()
    sb.bg_color = PANEL_BG
    sb.border_color = PANEL_BORDER
    sb.set_border_width_all(1)
    sb.shadow_color = Color(0, 0, 0, 0.48)
    sb.shadow_size = 3
    sb.shadow_offset = Vector2(0, 2)
    sb.corner_radius_top_left = 0
    sb.corner_radius_top_right = 0
    sb.corner_radius_bottom_left = 0
    sb.corner_radius_bottom_right = 0
    p.add_theme_stylebox_override("panel", sb)
    p.mouse_filter = Control.MOUSE_FILTER_STOP
    (parent if parent != null else self).add_child(p)
    if parent == null:
        _blockers.append(p)
    return p


func _label(parent: Node, text: String, pos: Vector2, color := Color.WHITE) -> Label:
    var l := Label.new()
    l.text = text
    l.position = pos
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    l.add_theme_font_override("font", _font)
    l.add_theme_font_size_override("font_size", 8)
    l.add_theme_color_override("font_color", color)
    l.add_theme_color_override("font_outline_color", Color.BLACK)
    l.add_theme_constant_override("outline_size", 2)
    parent.add_child(l)
    return l


func _icon(parent: Node, icon_name: String, pos: Vector2) -> TextureRect:
    var r := TextureRect.new()
    r.texture = ICONS[icon_name]
    r.position = pos
    r.stretch_mode = TextureRect.STRETCH_KEEP
    r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(r)
    return r


## Ikon + angka.
func _stat(parent: Node, icon_name: String, pos: Vector2) -> Label:
    _icon(parent, icon_name, pos + Vector2(0, 2))
    return _label(parent, "0", pos + Vector2(13, 0))


func _build_top_bar() -> void:
    _top_bar = _panel(Vector2.ZERO, Vector2(480, 18))
    var bar := _top_bar
    _wood = _stat(bar, "wood", Vector2(3, 1))
    _wood.add_theme_color_override("font_color", Color("#d9bd8d"))
    _stone = _stat(bar, "stone", Vector2(39, 1))
    _stone.add_theme_color_override("font_color", Color("#c2c9ca"))
    _food = _stat(bar, "food", Vector2(75, 1))
    _food.add_theme_color_override("font_color", Color("#e2cb78"))
    _iron_icon = _icon(bar, "iron", Vector2(111, 3))
    _iron = _label(bar, "0", Vector2(124, 1), Color("#e19a68"))
    for divider_x in [35.0, 71.0, 107.0, 145.0]:
        var divider := ColorRect.new()
        divider.position = Vector2(divider_x, 4)
        divider.size = Vector2(1, 10)
        divider.color = Color("#756044")
        divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
        bar.add_child(divider)

    _clock_widget = ClockWidget.new()
    _clock_widget.font = _font
    _clock_widget.sun = ICONS["sun"]
    _clock_widget.moon = ICONS["moon"]
    _clock_widget.position = Vector2(151, 2)
    _clock_widget.size = Vector2(142, 11)
    bar.add_child(_clock_widget)

    _foes_icon = _icon(bar, "skull", Vector2(300, 3))
    _foes = _label(bar, "0", Vector2(313, 1), Color("#ff8a7a"))
    _foes_icon.visible = false
    _foes.visible = false

    _people_icon = _icon(bar, "people", Vector2(336, 3))
    _pop = _label(bar, "0/0", Vector2(349, 1), Color("#a9c9bf"))

    _map_button = HudChip.new()
    _map_button.label = "MAP"
    _map_button.font = _font
    _map_button.position = Vector2(370, 1)
    _map_button.size = Vector2(35, 13)
    _map_button.pressed.connect(_toggle_map)
    bar.add_child(_map_button)

    _jobs_button = HudChip.new()
    _jobs_button.label = "JOBS"
    _jobs_button.font = _font
    _jobs_button.position = Vector2(409, 1)
    _jobs_button.size = Vector2(35, 13)
    _jobs_button.pressed.connect(_toggle_jobs)
    bar.add_child(_jobs_button)

    _tech_btn = TechButton.new()
    _tech_btn.icon = ICONS["tech"]
    _tech_btn.font = _font
    _tech_btn.position = Vector2(448, 1)
    _tech_btn.size = Vector2(30, 13)
    _tech_btn.pressed.connect(func() -> void: Events.tech_panel_requested.emit())
    bar.add_child(_tech_btn)

    _research_panel = _panel(Vector2(4, 45), Vector2(126, 12))
    _research_name = _label(_research_panel, "", Vector2(3, 1), Color("#ffd23f"))
    _research_bar = StatBar.new()
    _research_bar.position = Vector2(77, 3)
    _research_bar.size = Vector2(45, 6)
    _research_bar.fill = Color("#6fcf5a")
    _research_panel.add_child(_research_bar)
    _research_panel.visible = false

    _fps = _label(self, "", Vector2(72, 259), Color("#9ad0ff"))
    _fps.visible = false

func _build_vitals() -> void:
    _vitals_panel = _panel(Vector2(4, 22), Vector2(122, 20))
    var p := _vitals_panel
    _icon(p, "heart", Vector2(3, 2))
    _hp_bar = StatBar.new()
    _hp_bar.position = Vector2(17, 3)
    _hp_bar.size = Vector2(45, 5)
    _hp_bar.fill = Color("#d63a3a")
    p.add_child(_hp_bar)
    _hp_text = _label(p, "100", Vector2(66, 1))
    _icon(p, "keep", Vector2(3, 10))
    _keep_bar = StatBar.new()
    _keep_bar.position = Vector2(17, 11)
    _keep_bar.size = Vector2(45, 5)
    _keep_bar.fill = GOLD
    p.add_child(_keep_bar)
    _keep_text = _label(p, "-", Vector2(66, 9))

func _build_stage_bar() -> void:
    _stage_panel = _panel(Vector2(136, 22), Vector2(205, 20))
    var p := _stage_panel
    _stage_label = _label(p, "BAB I  PERBATASAN", Vector2(3, 1), Color("#f0d39a"))
    _stage_label.add_theme_font_size_override("font_size", 9)
    _stage_bar = StatBar.new()
    _stage_bar.position = Vector2(3, 13)
    _stage_bar.size = Vector2(199, 4)
    _stage_bar.fill = Color("#b98c4a")
    p.add_child(_stage_bar)


func _build_combat_bar() -> void:
    _combat_bar = CombatBar.new()
    _combat_bar.font = _font
    _combat_bar.position = Vector2(151, 219)
    _combat_bar.size = Vector2(178, 18)
    _combat_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_combat_bar)

func _build_jobs() -> void:
    _jobs_panel = _panel(Vector2(400, 22), Vector2(76, 84))
    for i in JOBS.size():
        var row := JobRow.new()
        row.job = JOBS[i]
        row.icon = ICONS[JOB_ICONS[JOBS[i]]]
        row.font = _font
        row.position = Vector2(2, 3 + i * 12)
        row.size = Vector2(72, 12)
        row.adjust.connect(_on_job_adjust)
        row.priority_adjust.connect(_on_job_priority_adjust)
        _jobs_panel.add_child(row)
        _jobs[JOBS[i]] = row
    _outpost_button = HudChip.new()
    _outpost_button.label = "POS"
    _outpost_button.font = _font
    _outpost_button.position = Vector2(2, 67)
    _outpost_button.size = Vector2(72, 13)
    _outpost_button.pressed.connect(_toggle_outposts)
    _jobs_panel.add_child(_outpost_button)
    _jobs_panel.visible = false

func _build_boss_bar() -> void:
    _boss_panel = _panel(Vector2(140, 46), Vector2(200, 18))
    _boss_title = _label(_boss_panel, "RAJA LAWAN", Vector2(0, 0), Color("#ff8a7a"))
    _boss_title.size = Vector2(200, 9)
    _boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _boss_bar = StatBar.new()
    _boss_bar.position = Vector2(6, 10)
    _boss_bar.size = Vector2(188, 6)
    _boss_bar.fill = Color("#c0392b")
    _boss_panel.add_child(_boss_bar)
    _boss_panel.visible = false


func _build_build_bar() -> void:
    _queue_button = HudChip.new()
    _queue_button.label = "QUEUE"
    _queue_button.font = _font
    _queue_button.position = Vector2(4, 211)
    _queue_button.size = Vector2(38, 12)
    _queue_button.tooltip_text = "Buka antrean konstruksi (B)"
    _queue_button.pressed.connect(_toggle_construction_queue)
    add_child(_queue_button)
    _blockers.append(_queue_button)
    _build_left_hint = _label(self, "BANGUNAN 1-8", Vector2(46, 225), Color(1, 1, 1, 0.78))
    _build_right_hint = _label(self, "TAB PETA  ·  H BANTUAN", Vector2(360, 225), Color(1, 1, 1, 0.78))
    _build_right_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _rebuild_build_bar()

func _rebuild_build_bar() -> void:
    for s in _slot_nodes:
        _blockers.erase(s)
        s.queue_free()
    _slot_nodes.clear()
    _slots.clear()
    var ids: Array = Tech.available_buildings()
    var n := ids.size()
    if n <= 0:
        return
    var available_width := maxf(220.0, _viewport_size.x - 14.0)
    var w := mini(SLOT_W, int((available_width - (n - 1) * 3.0) / maxi(1, n)))
    var total := n * w + (n - 1) * 3
    var x0 := int((_viewport_size.x - total) / 2.0)
    for i in n:
        var id: String = ids[i]
        var slot := BuildSlot.new()
        slot.id = id
        slot.font = _font
        slot.key_text = str(i + 1)
        var data: Dictionary = DataDB.buildings[id]
        slot.title = String(data.get("short", data["name"])) if w < SLOT_W else String(data["name"])
        slot.icon = ICONS[id]
        var costs: Array = []
        var cost := DataDB.cost_of(id)
        for kind in ["wood", "stone", "iron"]:
            if cost.has(kind):
                costs.append([ICONS[kind], int(cost[kind])])
        slot.costs = costs
        slot.position = Vector2(x0 + i * (w + 3), _viewport_size.y - SLOT_H - 2)
        slot.size = Vector2(w, SLOT_H)
        slot.pressed.connect(_on_slot_pressed)
        add_child(slot)
        _blockers.append(slot)
        _slot_nodes.append(slot)
        _slots[id] = slot
    _refresh_slots()


func _build_map() -> void:
    _map_backdrop = ColorRect.new()
    _map_backdrop.color = Color(0.015, 0.02, 0.028, 0.78)
    _map_backdrop.size = _viewport_size
    _map_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    _map_backdrop.gui_input.connect(_on_map_backdrop_input)
    _map_backdrop.visible = false
    add_child(_map_backdrop)
    _blockers.append(_map_backdrop)

    _map_panel = MAP_PANEL_SCRIPT.new()
    _map_panel.configure_layout(_viewport_size)
    _map_panel.position = (_viewport_size - _map_panel.size) * 0.5
    _map_panel.visible = false
    _map_panel.close_requested.connect(_toggle_map)
    add_child(_map_panel)
    _blockers.append(_map_panel)


func _on_map_backdrop_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _toggle_map()


func _toggle_map() -> void:
    var opening: bool = not _map_panel.visible
    if opening:
        _close_construction_queue()
    if opening and _outpost_panel.visible:
        _outpost_panel.visible = false
        _outpost_backdrop.visible = false
        _outpost_button.active = false
        _outpost_button.queue_redraw()
    _map_panel.visible = opening
    _map_backdrop.visible = opening
    if opening:
        _jobs_panel.visible = false
        _jobs_button.active = false
        _jobs_button.queue_redraw()
    _map_button.active = opening
    _map_button.queue_redraw()


func _toggle_jobs() -> void:
    var opening := not _jobs_panel.visible
    if opening:
        _close_construction_queue()
    if opening and _outpost_panel.visible:
        _outpost_panel.visible = false
        _outpost_backdrop.visible = false
        _outpost_button.active = false
        _outpost_button.queue_redraw()
    _jobs_panel.visible = opening
    _jobs_button.active = opening
    if opening and _map_panel.visible:
        _map_panel.visible = false
        _map_backdrop.visible = false
        _map_button.active = false
        _map_button.queue_redraw()
    _jobs_button.queue_redraw()


func _build_outpost_panel() -> void:
    _outpost_backdrop = ColorRect.new()
    _outpost_backdrop.color = Color(0.015, 0.02, 0.028, 0.84)
    _outpost_backdrop.size = _viewport_size
    _outpost_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    _outpost_backdrop.gui_input.connect(_on_outpost_backdrop_input)
    _outpost_backdrop.visible = false
    add_child(_outpost_backdrop)
    _blockers.append(_outpost_backdrop)

    _outpost_panel = _panel(Vector2.ZERO, Vector2(356, 238))
    _outpost_panel.visible = false
    var title := _label(_outpost_panel, "LOGISTIK & PERTAHANAN POS", Vector2(10, 7), GOLD)
    title.add_theme_font_size_override("font_size", 9)

    var close := HudChip.new()
    close.label = "X"
    close.font = _font
    close.position = Vector2(330, 4)
    close.size = Vector2(19, 15)
    close.pressed.connect(_toggle_outposts)
    _outpost_panel.add_child(close)

    var source_hint := _label(_outpost_panel, "SUMBER BIAYA", Vector2(10, 22), Color("#c9b99d"))
    source_hint.add_theme_font_size_override("font_size", 6)
    source_hint.size = Vector2(88, 12)

    _cost_source_option = OptionButton.new()
    _cost_source_option.position = Vector2(96, 19)
    _cost_source_option.size = Vector2(252, 18)
    _cost_source_option.add_theme_font_override("font", _font)
    _cost_source_option.add_theme_font_size_override("font_size", 7)
    _cost_source_option.tooltip_text = "Konstruksi dan riset membayar seluruh biaya dari depot ini saja."
    _cost_source_option.item_selected.connect(_on_cost_source_selected)
    _outpost_panel.add_child(_cost_source_option)

    var depot_scroll := ScrollContainer.new()
    depot_scroll.position = Vector2(8, 39)
    depot_scroll.size = Vector2(340, 66)
    depot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    depot_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    _outpost_panel.add_child(depot_scroll)

    _outpost_list = VBoxContainer.new()
    _outpost_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _outpost_list.add_theme_constant_override("separation", 3)
    depot_scroll.add_child(_outpost_list)

    var shipment_title := _label(_outpost_panel, "PERINTAH ANGKUT FISIK", Vector2(10, 105), GOLD)
    shipment_title.add_theme_font_size_override("font_size", 7)
    _label(_outpost_panel, "ASAL", Vector2(10, 116), Color("#c9b99d")).add_theme_font_size_override("font_size", 6)
    _label(_outpost_panel, "TUJUAN", Vector2(183, 116), Color("#c9b99d")).add_theme_font_size_override("font_size", 6)

    _shipment_source = OptionButton.new()
    _shipment_source.position = Vector2(8, 126)
    _shipment_source.size = Vector2(166, 18)
    _shipment_source.add_theme_font_override("font", _font)
    _shipment_source.add_theme_font_size_override("font_size", 7)
    _outpost_panel.add_child(_shipment_source)

    _shipment_destination = OptionButton.new()
    _shipment_destination.position = Vector2(180, 126)
    _shipment_destination.size = Vector2(168, 18)
    _shipment_destination.add_theme_font_override("font", _font)
    _shipment_destination.add_theme_font_size_override("font_size", 7)
    _outpost_panel.add_child(_shipment_destination)

    _shipment_kind = OptionButton.new()
    _shipment_kind.position = Vector2(8, 150)
    _shipment_kind.size = Vector2(116, 19)
    _shipment_kind.add_theme_font_override("font", _font)
    _shipment_kind.add_theme_font_size_override("font_size", 7)
    for kind in ["wood", "stone", "food", "iron"]:
        _shipment_kind.add_item(kind.to_upper())
        _shipment_kind.set_item_metadata(_shipment_kind.item_count - 1, kind)
    _shipment_kind.select(0)
    _outpost_panel.add_child(_shipment_kind)

    _shipment_amount = SpinBox.new()
    _shipment_amount.position = Vector2(130, 150)
    _shipment_amount.size = Vector2(76, 19)
    _shipment_amount.min_value = 1
    _shipment_amount.max_value = 60
    _shipment_amount.step = 1
    _shipment_amount.value = 6
    _shipment_amount.add_theme_font_override("font", _font)
    _shipment_amount.add_theme_font_size_override("font_size", 7)
    _outpost_panel.add_child(_shipment_amount)

    _shipment_send_button = Button.new()
    _shipment_send_button.text = "BUAT ORDER"
    _shipment_send_button.position = Vector2(212, 150)
    _shipment_send_button.size = Vector2(136, 19)
    _shipment_send_button.add_theme_font_override("font", _font)
    _shipment_send_button.add_theme_font_size_override("font_size", 7)
    _shipment_send_button.pressed.connect(_create_shipment_order)
    _outpost_panel.add_child(_shipment_send_button)

    _label(_outpost_panel, "STATUS PENGIRIMAN", Vector2(10, 174), Color("#c9b99d")).add_theme_font_size_override("font_size", 6)
    var order_scroll := ScrollContainer.new()
    order_scroll.position = Vector2(8, 184)
    order_scroll.size = Vector2(340, 46)
    order_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    order_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    _outpost_panel.add_child(order_scroll)

    _shipment_orders_list = VBoxContainer.new()
    _shipment_orders_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _shipment_orders_list.add_theme_constant_override("separation", 2)
    order_scroll.add_child(_shipment_orders_list)
    _refresh_outpost_panel()

func _on_outpost_backdrop_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _toggle_outposts()


func _refresh_outpost_panel() -> void:
    if _outpost_list == null:
        return
    for child in _outpost_list.get_children():
        child.free()

    var depots: Array = []
    for depot in get_tree().get_nodes_in_group("depots"):
        if is_instance_valid(depot) and ["outpost", "storage"].has(String(depot.id)):
            depots.append(depot)
    depots.sort_custom(func(a, b) -> bool:
        if String(a.id) != String(b.id):
            return String(a.id) == "outpost"
        if a.cell.y != b.cell.y:
            return a.cell.y < b.cell.y
        return a.cell.x < b.cell.x
    )

    if depots.is_empty():
        var empty := _label(_outpost_list, "Belum ada Outpost atau Storage.", Vector2.ZERO, Color("#c9b99d"))
        empty.add_theme_font_size_override("font_size", 8)
    else:
        for depot in depots:
            var row := HBoxContainer.new()
            row.custom_minimum_size = Vector2(276, 38)
            row.add_theme_constant_override("separation", 5)
            _outpost_list.add_child(row)
    
            var details := VBoxContainer.new()
            details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            details.add_theme_constant_override("separation", 1)
            row.add_child(details)
    
            var heading := Label.new()
            heading.add_theme_font_override("font", _font)
            heading.add_theme_font_size_override("font_size", 7)
            heading.add_theme_color_override("font_color", Color("#f0d39a"))
            if String(depot.id) == "outpost":
                heading.text = "POS %d,%d  ·  PENJAGA %d/%d" % [depot.cell.x, depot.cell.y, depot.guard_count(), depot.guard_capacity]
            else:
                heading.text = "GUDANG %d,%d" % [depot.cell.x, depot.cell.y]
            var main_node = get_tree().get_first_node_in_group("main")
            if main_node != null and main_node.supply != null:
                var pressure: Dictionary = main_node.supply.depot_pressure_state(depot)
                var pressure_status := String(pressure.get("status", "connected"))
                var pressure_label := String(pressure.get("label", ""))
                if pressure_status != "connected":
                    heading.text += " · " + pressure_label
                    heading.add_theme_color_override("font_color", Color("#ef8e73") if pressure_status in ["vulnerable", "raiding"] else Color("#d6b36d"))
                heading.tooltip_text = "Pemulihan: sambungkan jalan ke Keep atau amankan wilayah. Penjaga Outpost dapat menahan saboteur; Builder dapat memperbaiki depot menggunakan sumber biaya aktif."
            details.add_child(heading)
    
            var stock := Label.new()
            stock.add_theme_font_override("font", _font)
            stock.add_theme_font_size_override("font_size", 6)
            stock.add_theme_color_override("font_color", Color("#c4c0b5"))
            stock.text = "KAYU %d  BATU %d  PANGAN %d  BESI %d  / %d" % [
                depot.stockpile_amount("wood"), depot.stockpile_amount("stone"),
                depot.stockpile_amount("food"), depot.stockpile_amount("iron"),
                depot.stockpile_capacity
            ]
            details.add_child(stock)
    
            if String(depot.id) == "outpost":
                var release := Button.new()
                release.text = "-"
                release.custom_minimum_size = Vector2(25, 22)
                release.disabled = depot.guard_count() <= 0
                release.tooltip_text = "Tarik satu penjaga dari Outpost"
                release.add_theme_font_override("font", _font)
                release.add_theme_font_size_override("font_size", 8)
                release.pressed.connect(_release_outpost_guard.bind(depot))
                row.add_child(release)
    
                var assign := Button.new()
                assign.text = "+"
                assign.custom_minimum_size = Vector2(25, 22)
                assign.disabled = depot.free_guard_slots() <= 0
                assign.tooltip_text = "Tugaskan prajurit terdekat yang belum menjaga Outpost"
                assign.add_theme_font_override("font", _font)
                assign.add_theme_font_size_override("font_size", 8)
                assign.pressed.connect(_assign_outpost_guard.bind(depot))
                row.add_child(assign)

    _refresh_shipment_controls()


func _depot_option_cell(option: OptionButton) -> Vector2i:
    if option == null or option.get_selected() < 0:
        return Vector2i(-1, -1)
    var metadata: Variant = option.get_item_metadata(option.get_selected())
    if not (metadata is Dictionary):
        return Vector2i(-1, -1)
    return Vector2i(int(metadata.get("cx", -1)), int(metadata.get("cy", -1)))


func _refresh_depot_option(option: OptionButton, depots: Array, preferred: Vector2i, default_index: int) -> void:
    option.clear()
    var selected_index := -1
    for depot in depots:
        var cell: Vector2i = depot.cell
        var label := "KEEP" if String(depot.id) == "keep" else ("POS" if String(depot.id) == "outpost" else "GUDANG")
        option.add_item("%s %d,%d" % [label, cell.x, cell.y])
        var index := option.item_count - 1
        option.set_item_metadata(index, {"cx": cell.x, "cy": cell.y})
        if cell == preferred:
            selected_index = index
    if selected_index < 0 and option.item_count > 0:
        selected_index = clampi(default_index, 0, option.item_count - 1)
    if selected_index >= 0:
        option.select(selected_index)
    option.disabled = option.item_count < 2



func _refresh_cost_source_controls(depots: Array) -> void:
    if _cost_source_option == null:
        return
    var main_node = get_tree().get_first_node_in_group("main")
    if main_node == null or main_node.supply == null:
        _cost_source_option.disabled = true
        return
    var selected_cell: Vector2i = main_node.supply.get_cost_source_cell()
    var selected_index := -1
    var keep_index := -1
    _cost_source_option.clear()
    for depot in depots:
        var cell: Vector2i = depot.cell
        var connected: bool = main_node.supply.is_depot_connected(depot)
        var label := "KEEP" if String(depot.id) == "keep" else (
            "POS %d,%d" % [cell.x, cell.y] if String(depot.id) == "outpost"
            else "GUDANG %d,%d" % [cell.x, cell.y]
        )
        if not connected:
            label += " · PUTUS"
        _cost_source_option.add_item(label)
        var index := _cost_source_option.item_count - 1
        _cost_source_option.set_item_metadata(index, {"cx": cell.x, "cy": cell.y})
        if not connected and cell != selected_cell:
            _cost_source_option.set_item_disabled(index, true)
        if String(depot.id) == "keep":
            keep_index = index
        if cell == selected_cell:
            selected_index = index
    if selected_index < 0 and keep_index >= 0:
        for depot in depots:
            if String(depot.id) == "keep":
                main_node.supply.set_cost_source(depot.cell)
                selected_index = keep_index
                break
    if selected_index >= 0:
        _cost_source_option.select(selected_index)
    _cost_source_option.disabled = WorldConfig.profile_id != "frontier" or depots.size() < 2


func _on_cost_source_selected(index: int) -> void:
    if _cost_source_option == null or index < 0:
        return
    var metadata: Variant = _cost_source_option.get_item_metadata(index)
    if not (metadata is Dictionary):
        return
    var cell := Vector2i(int(metadata.get("cx", -1)), int(metadata.get("cy", -1)))
    var main_node = get_tree().get_first_node_in_group("main")
    if main_node == null or not main_node.supply.set_cost_source(cell):
        _show_message("Depot sumber biaya tidak terhubung")
        _refresh_outpost_panel()
        return
    _show_message("Biaya konstruksi dan riset: " + main_node.supply.cost_source_label())
    _refresh_slots()


func _on_supply_state_changed() -> void:
    _refresh_slots()
    _refresh_outpost_panel()


func _refresh_shipment_controls() -> void:
    if _shipment_source == null or _shipment_destination == null or _shipment_orders_list == null:
        return
    var previous_source := _depot_option_cell(_shipment_source)
    var previous_destination := _depot_option_cell(_shipment_destination)
    var endpoints: Array = []
    for depot in get_tree().get_nodes_in_group("depots"):
        if is_instance_valid(depot) and ["keep", "storage", "outpost"].has(String(depot.id)):
            endpoints.append(depot)
    endpoints.sort_custom(func(a, b) -> bool:
        if String(a.id) == "keep" or String(b.id) == "keep":
            return String(a.id) == "keep"
        if a.cell.y != b.cell.y:
            return a.cell.y < b.cell.y
        return a.cell.x < b.cell.x
    )
    _refresh_cost_source_controls(endpoints)
    _shipment_refreshing = true
    _refresh_depot_option(_shipment_source, endpoints, previous_source, 0)
    _refresh_depot_option(_shipment_destination, endpoints, previous_destination, 1)
    var frontier_enabled := WorldConfig.profile_id == "frontier" and endpoints.size() >= 2
    _shipment_source.disabled = not frontier_enabled
    _shipment_destination.disabled = not frontier_enabled
    _shipment_kind.disabled = WorldConfig.profile_id != "frontier"
    _shipment_amount.editable = WorldConfig.profile_id == "frontier"
    _shipment_send_button.disabled = not frontier_enabled
    _shipment_refreshing = false

    for child in _shipment_orders_list.get_children():
        child.free()
    var main_node = get_tree().get_first_node_in_group("main")
    if main_node == null:
        return
    var orders: Array[Dictionary] = main_node.supply.get_shipment_orders()
    if orders.is_empty():
        var empty := _label(_shipment_orders_list, "Belum ada perintah pengiriman.", Vector2.ZERO, Color("#c9b99d"))
        empty.add_theme_font_size_override("font_size", 7)
        return
    var shown := 0
    for order_index in range(orders.size() - 1, -1, -1):
        var order: Dictionary = orders[order_index]
        var row := HBoxContainer.new()
        row.custom_minimum_size = Vector2(328, 17)
        row.add_theme_constant_override("separation", 4)
        _shipment_orders_list.add_child(row)

        var source_name := _shipment_name(Vector2i(int(order["source_x"]), int(order["source_y"])))
        var destination_name := _shipment_name(Vector2i(int(order["destination_x"]), int(order["destination_y"])))
        var state_name: String = main_node.supply.get_shipment_status_label(String(order["status"]))
        var detail := Label.new()
        detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        detail.add_theme_font_override("font", _font)
        detail.add_theme_font_size_override("font_size", 6)
        detail.add_theme_color_override("font_color", Color("#d5c8ae"))
        detail.text = "#%d %d %s  %s → %s  [%s]" % [
            int(order["id"]), int(order["amount"]), String(order["kind"]).to_upper(),
            source_name, destination_name, state_name
        ]
        detail.clip_text = true
        row.add_child(detail)

        var cancel := Button.new()
        cancel.text = "X"
        cancel.custom_minimum_size = Vector2(18, 16)
        cancel.add_theme_font_override("font", _font)
        cancel.add_theme_font_size_override("font_size", 6)
        cancel.disabled = not ["queued", "in_transit", "blocked"].has(String(order["status"]))
        cancel.tooltip_text = "Batalkan dan pulihkan cargo"
        cancel.pressed.connect(_cancel_shipment_order.bind(int(order["id"])))
        row.add_child(cancel)
        shown += 1
        if shown >= 8:
            break


func _shipment_name(cell: Vector2i) -> String:
    var main_node = get_tree().get_first_node_in_group("main")
    if main_node != null:
        for depot in get_tree().get_nodes_in_group("depots"):
            if is_instance_valid(depot) and depot.cell == cell:
                return "KEEP" if depot.id == "keep" else ("POS" if depot.id == "outpost" else "GDG")
    return "HILANG"


func _create_shipment_order() -> void:
    var main_node = get_tree().get_first_node_in_group("main")
    if main_node == null or _shipment_source.get_selected() < 0 or _shipment_destination.get_selected() < 0:
        _show_message("Pilih depot asal dan tujuan")
        return
    var source_cell := _depot_option_cell(_shipment_source)
    var destination_cell := _depot_option_cell(_shipment_destination)
    var kind: String = String(_shipment_kind.get_item_metadata(_shipment_kind.get_selected()))
    var amount := int(_shipment_amount.value)
    var order_id: int = main_node.supply.create_shipment(source_cell, destination_cell, kind, amount)
    if order_id < 0:
        _show_message("Order ditolak: stok, kapasitas atau jalur tidak cukup")
    else:
        _show_message("Order #%d dibuat; cargo telah dicadangkan" % order_id)
    _refresh_outpost_panel()


func _cancel_shipment_order(order_id: int) -> void:
    var main_node = get_tree().get_first_node_in_group("main")
    if main_node == null or not main_node.supply.cancel_shipment(order_id):
        _show_message("Order tidak dapat dibatalkan")
    else:
        _show_message("Order dibatalkan; cargo dipulihkan")
    _refresh_outpost_panel()



func _assign_outpost_guard(outpost) -> void:
    var main_node = get_tree().get_first_node_in_group("main")
    if main_node == null or not main_node.village.assign_nearest_outpost_guard(outpost):
        _show_message("Tidak ada prajurit yang tersedia atau slot penjaga penuh")
    else:
        _show_message("Prajurit ditugaskan menjaga Outpost")
    _refresh_outpost_panel()


func _release_outpost_guard(outpost) -> void:
    var main_node = get_tree().get_first_node_in_group("main")
    if main_node == null or not main_node.village.release_outpost_guard(outpost):
        _show_message("Tidak ada penjaga untuk ditarik")
    else:
        _show_message("Penjaga kembali ke pertahanan umum")
    _refresh_outpost_panel()


func _toggle_outposts() -> void:
    var opening: bool = not _outpost_panel.visible
    if opening:
        _close_construction_queue()
    _outpost_panel.visible = opening
    _outpost_backdrop.visible = opening
    _outpost_button.active = opening
    _outpost_button.queue_redraw()
    if opening:
        _jobs_panel.visible = false
        _jobs_button.active = false
        _jobs_button.queue_redraw()
        if _map_panel.visible:
            _map_panel.visible = false
            _map_backdrop.visible = false
            _map_button.active = false
            _map_button.queue_redraw()
        _outpost_refresh_t = 0.0
        _refresh_outpost_panel()


func _build_construction_queue_panel() -> void:
    _queue_backdrop = ColorRect.new()
    _queue_backdrop.color = Color(0.015, 0.02, 0.028, 0.86)
    _queue_backdrop.size = _viewport_size
    _queue_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    _queue_backdrop.gui_input.connect(_on_queue_backdrop_input)
    _queue_backdrop.visible = false
    add_child(_queue_backdrop)
    _blockers.append(_queue_backdrop)

    _queue_panel = _panel(Vector2.ZERO, Vector2(356, 220))
    _queue_panel.visible = false
    var title := _label(_queue_panel, "ANTREAN KONSTRUKSI", Vector2(10, 7), GOLD)
    title.add_theme_font_size_override("font_size", 9)
    _queue_count_label = _label(_queue_panel, "0 PROYEK", Vector2(10, 22), Color("#c9b99d"))
    _queue_count_label.add_theme_font_size_override("font_size", 6)

    var close := HudChip.new()
    close.label = "X"
    close.font = _font
    close.position = Vector2(330, 4)
    close.size = Vector2(19, 15)
    close.pressed.connect(_toggle_construction_queue)
    _queue_panel.add_child(close)

    var scroll := ScrollContainer.new()
    scroll.position = Vector2(8, 36)
    scroll.size = Vector2(340, 176)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    _queue_panel.add_child(scroll)

    _queue_list = VBoxContainer.new()
    _queue_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _queue_list.add_theme_constant_override("separation", 3)
    scroll.add_child(_queue_list)


func _on_queue_backdrop_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _close_construction_queue()


func _toggle_construction_queue() -> void:
    var opening: bool = not _queue_panel.visible
    if opening:
        _map_panel.visible = false
        _map_backdrop.visible = false
        _map_button.active = false
        _map_button.queue_redraw()
        _jobs_panel.visible = false
        _jobs_button.active = false
        _jobs_button.queue_redraw()
        _outpost_panel.visible = false
        _outpost_backdrop.visible = false
        _outpost_button.active = false
        _outpost_button.queue_redraw()
        _help.visible = false
        _refresh_construction_queue()
    _queue_panel.visible = opening
    _queue_backdrop.visible = opening
    _queue_button.active = opening
    _queue_button.queue_redraw()


func _close_construction_queue() -> void:
    _queue_panel.visible = false
    _queue_backdrop.visible = false
    _queue_button.active = false
    _queue_button.queue_redraw()


func _on_construction_queue_changed() -> void:
    if _queue_panel.visible:
        _refresh_construction_queue()


func _refresh_construction_queue() -> void:
    if _queue_list == null:
        return
    for child in _queue_list.get_children():
        child.queue_free()
    var main_node = get_tree().get_first_node_in_group("main")
    if main_node == null or main_node.build == null:
        _queue_count_label.text = "GAME BELUM SIAP"
        return
    var sites: Array = main_node.build.construction_queue()
    _queue_count_label.text = "%d PROYEK AKTIF" % sites.size()
    if sites.is_empty():
        var empty := _label(_queue_list, "BELUM ADA BLUEPRINT. PILIH BANGUNAN DAN TEMPATKAN DI PETA.", Vector2.ZERO, Color("#c9b99d"))
        empty.add_theme_font_size_override("font_size", 7)
        empty.custom_minimum_size = Vector2(320, 28)
        return
    for index in sites.size():
        var site = sites[index]
        if not is_instance_valid(site):
            continue
        var row := ConstructionQueueRow.new()
        row.site = site
        row.font = _font
        row.order_index = index
        row.can_move_up = index > 0
        row.can_move_down = index < sites.size() - 1
        row.custom_minimum_size = Vector2(328, 32)
        row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.move_requested.connect(_on_queue_move_requested)
        row.cancel_requested.connect(_on_queue_cancel_requested)
        _queue_list.add_child(row)


func _on_queue_move_requested(site, direction: int) -> void:
    var main_node = get_tree().get_first_node_in_group("main")
    if main_node != null:
        main_node.build.move_construction_site(site, direction)


func _on_queue_cancel_requested(site) -> void:
    var main_node = get_tree().get_first_node_in_group("main")
    if main_node != null:
        main_node.build.cancel_site(site)


func _build_help() -> void:
    var h := HELP_ROWS.size() * 10 + 30
    _help = _panel(Vector2((_viewport_size.x - 288.0) / 2.0, (_viewport_size.y - h) / 2.0), Vector2(288, h))
    var title := _label(_help, "KONTROL", Vector2(0, 5), GOLD)
    title.size = Vector2(288, 9)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    for i in HELP_ROWS.size():
        _label(_help, HELP_ROWS[i][0], Vector2(14, 18 + i * 10), Color("#ffd9a0"))
        _label(_help, HELP_ROWS[i][1], Vector2(124, 18 + i * 10))
    var foot := _label(_help, "H  TUTUP BANTUAN", Vector2(0, h - 12), Color(1, 1, 1, 0.7))
    foot.size = Vector2(288, 9)
    foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _help.visible = false

func _build_messages() -> void:
    _msg = _label(self, "", Vector2(0, 194))
    _msg.size = Vector2(480, 12)
    _msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _msg.modulate.a = 0.0
    _banner = _label(self, "", Vector2(0, 44))
    _banner.size = Vector2(480, 30)
    _banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _banner.modulate.a = 0.0


func _build_overlay() -> void:
    _over = ColorRect.new()
    _over.color = Color(0, 0, 0, 0.75)
    _over.size = _viewport_size
    _over.visible = false
    add_child(_over)
    _over_label = Label.new()
    _over_label.position = Vector2(0, 85)
    _over_label.size = Vector2(480, 100)
    _over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _over_label.add_theme_font_override("font", _font)
    _over_label.add_theme_font_size_override("font_size", 16)
    _over.add_child(_over_label)


# ---------------------------------------------------------------- responsive layout

func _on_viewport_size_changed() -> void:
    _layout_viewport()


func _on_content_viewport_resized(next_size: Vector2i) -> void:
    _layout_viewport(Vector2(next_size))


func _layout_viewport(target_size: Vector2 = Vector2.ZERO) -> void:
    var next_size := target_size
    if next_size == Vector2.ZERO:
        next_size = get_viewport().get_visible_rect().size
    _viewport_size = Vector2(maxf(480.0, next_size.x), maxf(270.0, next_size.y))

    _top_bar.size.x = _viewport_size.x
    _foes_icon.position.x = _viewport_size.x - 180.0
    _foes.position.x = _viewport_size.x - 167.0
    _clock_widget.position.x = 151.0
    _people_icon.position.x = _viewport_size.x - 144.0
    _pop.position.x = _viewport_size.x - 131.0

    _map_button.position.x = _viewport_size.x - 110.0
    _jobs_button.position.x = _viewport_size.x - 71.0
    _tech_btn.position.x = _viewport_size.x - 32.0

    _vitals_panel.position = Vector2(4, 22)
    _stage_panel.position = Vector2((_viewport_size.x - _stage_panel.size.x) * 0.5, 22)
    _jobs_panel.position = Vector2(_viewport_size.x - _jobs_panel.size.x - 4.0, 22)
    _boss_panel.position = Vector2((_viewport_size.x - _boss_panel.size.x) * 0.5, 46)

    _map_backdrop.size = _viewport_size
    _map_panel.configure_layout(_viewport_size)
    _outpost_backdrop.size = _viewport_size
    _outpost_panel.position = (_viewport_size - _outpost_panel.size) * 0.5
    _map_panel.position = (_viewport_size - _map_panel.size) * 0.5
    _queue_backdrop.size = _viewport_size
    _queue_panel.position = (_viewport_size - _queue_panel.size) * 0.5

    var help_height := _help.size.y
    _help.position = Vector2((_viewport_size.x - _help.size.x) * 0.5, (_viewport_size.y - help_height) * 0.5)

    var build_y := _viewport_size.y - SLOT_H - 2.0
    var hint_y := build_y - 14.0
    _queue_button.position = Vector2(5, hint_y - 1.0)
    _build_left_hint.position = Vector2(46, hint_y)
    _build_right_hint.position = Vector2(_viewport_size.x - 132.0, hint_y)
    _build_right_hint.size = Vector2(127.0, 10)
    _build_right_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

    _combat_bar.position = Vector2((_viewport_size.x - _combat_bar.size.x) * 0.5, build_y - _combat_bar.size.y - 19.0)
    _msg.position = Vector2(0, _combat_bar.position.y - _msg.size.y - 6.0)
    _msg.size.x = _viewport_size.x
    _banner.position = Vector2(0, maxf(82.0, _viewport_size.y * 0.16))
    _banner.size.x = _viewport_size.x
    _fps.position = Vector2(_viewport_size.x - 58.0, 96.0)

    _over.size = _viewport_size
    _over_label.position = Vector2(0, (_viewport_size.y - _over_label.size.y) * 0.5)
    _over_label.size.x = _viewport_size.x

    for slot_index in _slot_nodes.size():
        var slot: BuildSlot = _slot_nodes[slot_index]
        var total_width := 0.0
        for current in _slot_nodes:
            total_width += current.size.x
        total_width += maxi(0, _slot_nodes.size() - 1) * 3.0
        var slot_x := (_viewport_size.x - total_width) * 0.5
        for j in slot_index:
            slot_x += _slot_nodes[j].size.x + 3.0
        slot.position = Vector2(slot_x, build_y)


# ---------------------------------------------------------------- loop & input

func _process(delta: float) -> void:
    if _outpost_panel.visible:
        _outpost_refresh_t -= delta
        if _outpost_refresh_t <= 0.0:
            _outpost_refresh_t = 1.0
            _refresh_outpost_panel()
    if _fps.visible:
        _fps.text = "%d FPS" % Engine.get_frames_per_second()
    _scan_t -= delta
    if _scan_t > 0.0:
        return
    _scan_t = 0.2
    var player = get_tree().get_first_node_in_group("player")
    if player != null:
        _combat_bar.update_state(player.combat_status())
    _research_panel.visible = Tech.current != ""
    if Tech.current != "":
        _research_name.text = Tech.tech_name(Tech.current).substr(0, 12)
        _research_bar.set_value(Tech.progress_ratio())
    _tech_btn.busy = Tech.current != ""
    _tech_btn.queue_redraw()
    var main_node = get_tree().get_first_node_in_group("main")
    if main_node != null:
        var stage: Dictionary = main_node.spawner.stage_info(GameClock.day)
        var from_day := int(stage.get("from_day", 1))
        var to_day := int(stage.get("to_day", 15))
        var objective_suffix := ""
        var campaign = main_node.campaign
        if campaign != null:
            var objectives: Array = campaign.objectives_in_order()
            if objectives.size() > 1:
                var completed := 0
                for objective in objectives:
                    if bool(objective.get("destroyed", false)):
                        completed += 1
                objective_suffix = "  %d/%d" % [mini(completed + 1, objectives.size()), objectives.size()]
        _stage_label.text = "%s  %s%s" % [
            String(stage.get("label", "BAB I")),
            String(stage.get("name", "PERBATASAN")),
            objective_suffix
        ]
        var stage_progress := float(GameClock.day - from_day + 1) / float(maxi(1, to_day - from_day + 1))
        _stage_bar.set_value(clampf(stage_progress, 0.0, 1.0))
        if _map_panel.world != main_node.world or _map_panel.fog != main_node.fog or _map_panel.territory != main_node.territory:
            _map_panel.configure(main_node.world, main_node.fog, main_node.territory, _font)

    var foes := get_tree().get_nodes_in_group("enemies")
    _foes.text = str(foes.size())
    _foes.visible = foes.size() > 0
    _foes_icon.visible = foes.size() > 0
    var boss = null
    for e in foes:
        if e.is_boss:
            boss = e
            break
    if boss != null:
        _boss_title.text = "RAJA LAWAN"
        _boss_title.add_theme_color_override("font_color", Color("#ff8a7a"))
        _boss_panel.visible = true
        _boss_bar.set_value(float(boss.hp) / boss.max_hp)
    else:
        var campaign = get_tree().get_first_node_in_group("campaign")
        var stronghold = campaign.current_target_node() if campaign != null else get_tree().get_first_node_in_group("enemy_strongholds")
        var fog = get_tree().get_first_node_in_group("fog_of_war")
        var discovered: bool = stronghold != null and fog != null and bool(fog.is_revealed_cell(stronghold.cell))
        _boss_panel.visible = discovered
        if discovered:
            _boss_title.text = String(stronghold.faction_id).replace("_", " ").to_upper()
            _boss_title.add_theme_color_override("font_color", Color("#d97868"))
            _boss_bar.set_value(float(stronghold.hp) / stronghold.max_hp)


func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey and event.pressed and not event.echo):
        return
    if _over.visible:
        if event.keycode == KEY_L:
            SaveSystem.request_load()
        elif event.keycode == KEY_R:
            Inventory.reset()
            GameClock.reset()
            Tech.reset()
            get_tree().paused = false
            get_tree().reload_current_scene()
        return
    if event.keycode == KEY_B:
        _toggle_construction_queue()
        get_viewport().set_input_as_handled()
    elif event.keycode == KEY_ESCAPE and _queue_panel.visible:
        _toggle_construction_queue()
        get_viewport().set_input_as_handled()
    elif event.keycode == KEY_ESCAPE and _map_panel.visible:
        _toggle_map()
        get_viewport().set_input_as_handled()
    elif event.keycode == KEY_ESCAPE and _jobs_panel.visible:
        _toggle_jobs()
        get_viewport().set_input_as_handled()
    elif event.keycode == KEY_ESCAPE and _outpost_panel.visible:
        _toggle_outposts()
        get_viewport().set_input_as_handled()
    elif event.keycode == KEY_TAB:
        _toggle_map()
        get_viewport().set_input_as_handled()
    elif event.keycode == KEY_H or event.keycode == KEY_F1:
        _help.visible = not _help.visible
    elif event.keycode == KEY_F3:
        _fps.visible = not _fps.visible
        _fps.text = ""


## True jika titik (koordinat viewport) berada di atas panel HUD yang menangkap mouse.
func blocks_mouse(pos: Vector2) -> bool:
    for c in _blockers:
        if c.visible and Rect2(c.position, c.size).has_point(pos):
            return true
    return false


# ---------------------------------------------------------------- handler event

func _on_stage_changed(stage_id: String, stage_name: String, day: int) -> void:
    var main_node = get_tree().get_first_node_in_group("main")
    var stage_summary := ""
    if main_node != null:
        var stage: Dictionary = main_node.spawner.stage_info(day)
        stage_summary = String(stage.get("summary", ""))
    _banner.text = "%s  %s  ·  HARI %d\n%s" % [
        String(stage_id).to_upper(), stage_name, day, stage_summary
    ]
    _banner.modulate.a = 1.0
    if _banner_tween != null:
        _banner_tween.kill()
    _banner_tween = create_tween()
    _banner_tween.tween_interval(3.6)
    _banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)


func _on_resource_changed(_kind: String, _amount: int) -> void:
    _refresh_resources()
    _refresh_slots()


func _on_build_selected(id: String) -> void:
    _selected = id
    _refresh_slots()


func _on_tech_changed(_id: String) -> void:
    _rebuild_build_bar()
    _refresh_resources()


func _on_slot_pressed(id: String) -> void:
    Events.build_request.emit(id)


func _on_job_adjust(job: String, delta: int) -> void:
    Events.job_quota_request.emit(job, delta)


func _on_job_priority_adjust(job: String, delta: int) -> void:
    Events.job_priority_request.emit(job, delta)


func _on_player_hp(hp: int, max_hp: int) -> void:
    _hp_bar.set_value(float(hp) / max_hp)
    _hp_text.text = str(hp)


func _on_keep_hp(hp: int, max_hp: int) -> void:
    var ratio := float(hp) / max_hp
    _keep_bar.fill = GOLD if ratio > 0.3 else Color("#d63a3a")
    _keep_bar.set_value(ratio)
    _keep_text.text = str(hp)


func _on_village_changed(pop: int, cap: int, quota: Dictionary, assigned: Dictionary) -> void:
    _pop.text = "%d/%d" % [pop, cap]
    _pop.add_theme_color_override("font_color", Color("#ff8a7a") if pop > cap else Color.WHITE)
    var village = get_tree().get_first_node_in_group("village")
    for j in JOBS:
        var rank: int = (int(village.job_priority.find(j)) + 1) if village != null else JOBS.find(j) + 1
        _jobs[j].set_counts(int(assigned[j]), int(quota[j]), rank)


func _refresh_resources() -> void:
    _wood.text = str(Inventory.get_amount("wood"))
    _stone.text = str(Inventory.get_amount("stone"))
    _food.text = str(Inventory.get_amount("food"))
    _iron.text = str(Inventory.get_amount("iron"))
    var show_iron := Tech.has_flag("iron_mining") or Inventory.get_amount("iron") > 0
    _iron.visible = show_iron
    _iron_icon.visible = show_iron


func _refresh_slots() -> void:
    for id in _slots:
        var slot: BuildSlot = _slots[id]
        slot.selected = id == _selected
        var cost: Dictionary = DataDB.cost_of(id)
        var supply = get_tree().get_first_node_in_group("supply_network")
        slot.affordable = supply.can_pay_cost(cost) if supply != null else Inventory.can_afford(cost)
        slot.queue_redraw()


func _load_hint() -> String:
    return "\nL: MUAT SAVE TERAKHIR" if SaveSystem.has_save() else ""


func _on_event(title: String, text: String) -> void:
    _banner.text = "%s\n%s" % [title, text]
    _banner.modulate.a = 1.0
    if _banner_tween != null:
        _banner_tween.kill()
    _banner_tween = create_tween()
    _banner_tween.tween_interval(4.0)
    _banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)


func _close_secondary_panels() -> void:
    _map_panel.visible = false
    _map_backdrop.visible = false
    _map_button.active = false
    _map_button.queue_redraw()
    _jobs_panel.visible = false
    _jobs_button.active = false
    _jobs_button.queue_redraw()
    _outpost_panel.visible = false
    _outpost_backdrop.visible = false
    _outpost_button.active = false
    _outpost_button.queue_redraw()
    _close_construction_queue()
    _help.visible = false


func _on_game_won(day: int) -> void:
    _close_secondary_panels()
    _over_label.text = "KAMU MENANG!\nRaja lawan tumbang di hari %d\nTekan R untuk main lagi" % day + _load_hint()
    _over.visible = true
    get_tree().paused = true


func _on_game_over(day: int) -> void:
    _close_secondary_panels()
    _over_label.text = "KEEP HANCUR\nBertahan sampai hari %d\nTekan R untuk mulai ulang" % day + _load_hint()
    _over.visible = true
    get_tree().paused = true


func _on_campaign_won(day: int) -> void:
    _close_secondary_panels()
    var main_node = get_tree().get_first_node_in_group("main")
    var objective_count: int = main_node.campaign.objectives_in_order().size() if main_node != null else 1
    var victory_title := "SELURUH WILAYAH DITAKLUK" if objective_count > 1 else "BENTENG LAWAN TAKLUK"
    _over_label.text = "%s\\nWilayah musuh jatuh pada hari %d\\nTekan R untuk main lagi" % [victory_title, day] + _load_hint()
    _over.visible = true
    get_tree().paused = true


func _show_message(text: String) -> void:
    _msg.text = text
    _msg.modulate.a = 1.0
    if _msg_tween != null:
        _msg_tween.kill()
    _msg_tween = create_tween()
    _msg_tween.tween_interval(1.8)
    _msg_tween.tween_property(_msg, "modulate:a", 0.0, 0.5)


# ---------------------------------------------------------------- widget

## Bar horizontal untuk HP.
class StatBar extends Control:
    var value := 1.0
    var fill := Color("#d63a3a")

    func set_value(v: float) -> void:
        value = clampf(v, 0.0, 1.0)
        queue_redraw()

    func _draw() -> void:
        draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
        var w := (size.x - 2.0) * value
        draw_rect(Rect2(1, 1, w, size.y - 2.0), fill)
        draw_rect(Rect2(1, 1, w, 1), fill.lightened(0.35))
        draw_rect(Rect2(Vector2.ZERO, size), Color("#1a1410"), false, 1.0)


## Ikon matahari/bulan, "HARI n/N", dan lintasan waktu dengan penanda.
class ClockWidget extends Control:
    var font: Font
    var sun: Texture2D
    var moon: Texture2D

    func _process(_delta: float) -> void:
        queue_redraw()

    func _draw() -> void:
        var night: bool = GameClock.darkness() > 0.5
        draw_texture(moon if night else sun, Vector2(0, 0))
        var final_day := int(DataDB.waves.get("final_day", 0))
        draw_string(font, Vector2(13, 9), "HARI %d/%d" % [GameClock.day, final_day],
            HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
        var tx := 76.0
        var tw := 64.0
        var ty := 3.0
        var th := 5.0
        var ns: float = GameClock.NIGHT_START
        var ne: float = GameClock.NIGHT_END
        draw_rect(Rect2(tx, ty, tw * ns, th), Color("#d9b84a"))
        draw_rect(Rect2(tx + tw * ns, ty, tw * (ne - ns), th), Color("#3b4f8a"))
        draw_rect(Rect2(tx + tw * ne, ty, tw * (1.0 - ne), th), Color("#d98a4a"))
        draw_rect(Rect2(tx - 1, ty - 1, tw + 2, th + 2), Color("#1a1410"), false, 1.0)
        var mx: float = tx + tw * GameClock.time_of_day
        draw_rect(Rect2(mx - 1, ty - 2, 2, th + 4), Color.WHITE)


## Satu baris job: ikon, tombol -, "terisi/kuota", tombol +. Bisa diklik.
class JobRow extends Control:
    signal adjust(job: String, delta: int)
    signal priority_adjust(job: String, delta: int)
    var job := ""
    var icon: Texture2D
    var font: Font
    var assigned := 0
    var quota := 0
    var priority_rank := 1

    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_STOP

    func set_counts(a: int, q: int, rank: int = 1) -> void:
        assigned = a
        quota = q
        priority_rank = rank
        queue_redraw()

    func _gui_input(event: InputEvent) -> void:
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            if Rect2(15, 1, 10, 10).has_point(event.position):
                adjust.emit(job, -1)
            elif Rect2(58, 1, 10, 10).has_point(event.position):
                adjust.emit(job, 1)
            accept_event()
        elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
            priority_adjust.emit(job, 1 if event.shift_pressed else -1)
            accept_event()

    func _draw() -> void:
        draw_texture(icon, Vector2(2, 1))
        for box in [Rect2(15, 1, 10, 10), Rect2(58, 1, 10, 10)]:
            draw_rect(box, Color(0.2, 0.18, 0.22))
            draw_rect(box, Color("#6b5a40"), false, 1.0)
        draw_rect(Rect2(17, 5, 6, 2), Color.WHITE)
        draw_rect(Rect2(60, 5, 6, 2), Color.WHITE)
        draw_rect(Rect2(62, 3, 2, 6), Color.WHITE)
        var col := Color.WHITE
        if assigned < quota:
            col = Color("#ffb347")  # kuota belum terisi
        draw_string(font, Vector2(27, 9), "%d/%d" % [assigned, quota], HORIZONTAL_ALIGNMENT_CENTER, 19, 7, col)
        draw_string(font, Vector2(48, 9), "P%d" % priority_rank, HORIZONTAL_ALIGNMENT_CENTER, 9, 6, Color("#d7ba7a"))



## Level, XP, and active-skill cooldowns.
class CombatBar extends Control:
    var font: Font
    var state: Dictionary = {}

    func update_state(value: Dictionary) -> void:
        state = value
        queue_redraw()

    func _draw() -> void:
        draw_rect(Rect2(Vector2.ZERO, size), Color("#111319", 0.88))
        draw_rect(Rect2(Vector2.ZERO, size), Color("#6b5a40"), false, 1.0)
        var level := int(state.get("level", 1))
        var xp := int(state.get("xp", 0))
        var next_xp := int(state.get("next_xp", 0))
        draw_string(font, Vector2(4, 10), "LV%d" % level, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("#ffd23f"))
        var ratio := float(xp) / float(maxi(1, next_xp)) if next_xp > 0 else 1.0
        draw_rect(Rect2(25, 4, 25, 7), Color("#29231d"))
        draw_rect(Rect2(26, 5, 23.0 * clampf(ratio, 0.0, 1.0), 5), Color("#d39b42"))
        var abilities := [
            ["Q", "DASH", true, float(state.get("dash_cd", 0.0))],
            ["C", "TEBAS", bool(state.get("cleave_unlocked", false)), float(state.get("cleave_cd", 0.0))],
            ["V", "SERUAN", bool(state.get("rally_unlocked", false)), float(state.get("rally_cd", 0.0))]
        ]
        for i in abilities.size():
            var item: Array = abilities[i]
            var x := 54.0 + i * 40.0
            var unlocked := bool(item[2])
            var cooldown := float(item[3])
            var ready := unlocked and cooldown <= 0.05
            var tint := Color("#ffd23f") if ready else (Color("#a99a83") if unlocked else Color("#665d52"))
            draw_rect(Rect2(x, 2, 38, 12), Color("#211b19"))
            draw_rect(Rect2(x, 2, 38, 12), Color("#6b5a40"), false, 1.0)
            var status := "OK" if ready else ("--" if not unlocked else "%.0f" % cooldown)
            draw_string(font, Vector2(x + 3, 10), String(item[0]) + " " + status,
                HORIZONTAL_ALIGNMENT_LEFT, -1, 7, tint)


## Slot bar bangunan: ikon, nomor + nama, biaya. Bisa diklik.
class ConstructionQueueRow extends Control:
    signal move_requested(site, direction: int)
    signal cancel_requested(site)
    var site: Node
    var font: Font
    var order_index := 0
    var can_move_up := false
    var can_move_down := false
    var _last_progress := -1.0

    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_STOP
        tooltip_text = "UP: dahulukan  ·  DN: tunda  ·  X: batalkan dan kembalikan biaya belum terpakai"

    func _process(_delta: float) -> void:
        if site == null or not is_instance_valid(site):
            return
        var progress: float = site.progress_ratio()
        if absf(progress - _last_progress) >= 0.002:
            _last_progress = progress
            queue_redraw()

    func _gui_input(event: InputEvent) -> void:
        if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
            return
        var x := size.x
        if Rect2(x - 61.0, 1.0, 19.0, 14.0).has_point(event.position):
            if can_move_up:
                move_requested.emit(site, -1)
            accept_event()
        elif Rect2(x - 40.0, 1.0, 19.0, 14.0).has_point(event.position):
            if can_move_down:
                move_requested.emit(site, 1)
            accept_event()
        elif Rect2(x - 19.0, 1.0, 18.0, 14.0).has_point(event.position):
            cancel_requested.emit(site)
            accept_event()

    func _draw() -> void:
        if site == null or not is_instance_valid(site):
            return
        draw_rect(Rect2(Vector2.ZERO, size), Color("#191a18"))
        draw_rect(Rect2(Vector2.ZERO, size), Color("#554a37"), false, 1.0)
        var building_name := String(site.data.get("short", site.data.get("name", site.id)))
        draw_string(font, Vector2(6, 10), "%02d  %s" % [order_index + 1, building_name],
            HORIZONTAL_ALIGNMENT_LEFT, maxf(80.0, size.x - 72.0), 7, Color("#e5d7bb"))
        var progress := site.progress_ratio()
        draw_rect(Rect2(6, 17, 72, 5), Color("#090b0b"))
        draw_rect(Rect2(7, 18, 70.0 * progress, 3), Color("#d6bc78"))
        var cost_text := ""
        for pair in [["wood", "W"], ["stone", "S"], ["iron", "I"], ["food", "F"]]:
            if site.paid_cost.has(pair[0]):
                if not cost_text.is_empty():
                    cost_text += " "
                cost_text += "%s%d" % [String(pair[1]), int(site.paid_cost[pair[0]])]
        var detail := "%d%%  %s" % [roundi(progress * 100.0), cost_text]
        draw_string(font, Vector2(86, 22), detail, HORIZONTAL_ALIGNMENT_LEFT,
            maxf(70.0, size.x - 154.0), 6, Color("#c5b99f"))
        _draw_action_button(Rect2(size.x - 61.0, 1.0, 19.0, 14.0), "UP", can_move_up)
        _draw_action_button(Rect2(size.x - 40.0, 1.0, 19.0, 14.0), "DN", can_move_down)
        _draw_action_button(Rect2(size.x - 19.0, 1.0, 18.0, 14.0), "X", true)

    func _draw_action_button(rect: Rect2, caption: String, enabled: bool) -> void:
        draw_rect(rect, Color("#373126") if enabled else Color("#242321"))
        draw_rect(rect, Color("#88734d") if enabled else Color("#49443b"), false, 1.0)
        draw_string(font, rect.position + Vector2(3, 10), caption, HORIZONTAL_ALIGNMENT_LEFT,
            rect.size.x - 3.0, 6, Color("#ead7ae") if enabled else Color("#777064"))


## Slot bar bangunan: ikon, nomor + nama, biaya. Bisa diklik.
class BuildSlot extends Control:
    signal pressed(id: String)
    var id := ""
    var key_text := ""
    var title := ""
    var icon: Texture2D
    var costs: Array = []
    var font: Font
    var selected := false
    var affordable := true
    var hover := false

    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_STOP
        mouse_entered.connect(func() -> void:
            hover = true
            queue_redraw())
        mouse_exited.connect(func() -> void:
            hover = false
            queue_redraw())

    func _gui_input(event: InputEvent) -> void:
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            pressed.emit(id)
            accept_event()

    func _draw() -> void:
        var bg := Color(0.09, 0.08, 0.11, 0.88)
        if hover:
            bg = bg.lightened(0.18)
        draw_rect(Rect2(Vector2.ZERO, size), bg)
        draw_rect(Rect2(Vector2.ZERO, size), Color("#ffd23f") if selected else Color("#6b5a40"), false, 1.0)
        var a := 1.0 if affordable else 0.45
        # baris atas: nomor, ikon, nama; baris bawah: biaya
        draw_string(font, Vector2(3, 11), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, a * 0.6))
        draw_texture(icon, Vector2(10, 2), Color(1, 1, 1, a))
        var title_col := Color("#ffd23f") if selected else Color.WHITE
        title_col.a = a
        draw_string(font, Vector2(29, 11), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, title_col)
        var x := 4.0
        for c in costs:
            draw_texture(c[0], Vector2(x, 18), Color(1, 1, 1, a))
            x += 11.0
            var t := str(c[1])
            draw_string(font, Vector2(x, 27), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, a))
            x += font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 4.0

## Compact top-bar button for secondary panels.
class HudChip extends Control:
    signal pressed
    var label := ""
    var font: Font
    var active := false
    var hover := false

    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_STOP
        mouse_entered.connect(func() -> void:
            hover = true
            queue_redraw())
        mouse_exited.connect(func() -> void:
            hover = false
            queue_redraw())

    func _gui_input(event: InputEvent) -> void:
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            pressed.emit()
            accept_event()

    func _draw() -> void:
        var bg := Color("#51432f") if active else Color("#201d1a")
        if hover:
            bg = bg.lightened(0.18)
        draw_rect(Rect2(Vector2.ZERO, size), bg)
        draw_rect(Rect2(Vector2.ZERO, size), Color("#e0b969") if active else Color("#6b5a40"), false, 1.0)
        draw_string(font, Vector2(size.x / 2.0, 9), label, HORIZONTAL_ALIGNMENT_CENTER, -1, 7, Color("#f0e2c7"))


## Tombol "RISET [Y]" di panel atas.
class TechButton extends Control:
    signal pressed
    var icon: Texture2D
    var font: Font
    var hover := false
    var busy := false

    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_STOP
        mouse_entered.connect(func() -> void:
            hover = true
            queue_redraw())
        mouse_exited.connect(func() -> void:
            hover = false
            queue_redraw())

    func _gui_input(event: InputEvent) -> void:
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            pressed.emit()
            accept_event()

    func _draw() -> void:
        var bg := Color(0.2, 0.17, 0.1, 0.9) if hover else Color(0.12, 0.1, 0.08, 0.9)
        draw_rect(Rect2(Vector2.ZERO, size), bg)
        draw_rect(Rect2(Vector2.ZERO, size), Color("#ffd23f") if busy else Color("#6b5a40"), false, 1.0)
        draw_texture(icon, Vector2(2, 1))
        draw_string(font, Vector2(14, 10), "Y", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
