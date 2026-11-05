extends CanvasLayer

const HUD_WIDGETS := preload("res://scripts/ui/hud_widgets.gd")
const CONSTRUCTION_QUEUE_PANEL_SCRIPT := preload("res://scripts/ui/construction_queue_panel.gd")
const OUTPOST_PANEL_SCRIPT := preload("res://scripts/ui/outpost_panel.gd")
## HUD: panel atas (sumber daya, jam, musuh, penduduk), vitals, kuota job (bisa diklik),
## bar boss, bar bangunan (bisa diklik), bantuan (H), dan layar game over / menang.

const PIXEL_FONT := preload("res://scripts/ui/pixel_font.gd")
const MAP_PANEL_SCRIPT := preload("res://scripts/ui/world_map_panel.gd")
const EVENT_DECISION_PANEL_SCRIPT := preload("res://scripts/ui/event_decision_panel.gd")
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
    "granary": preload("res://assets/sprites/icon_granary.svg"),
    "hunting_lodge": preload("res://assets/sprites/icon_hunting_lodge.svg"),
    "bow": preload("res://assets/sprites/icon_bow.svg"),
    "scout_post": preload("res://assets/sprites/icon_scout_post.svg"),
    "compass": preload("res://assets/sprites/icon_compass.svg"),
    "infirmary": preload("res://assets/sprites/icon_infirmary.svg"),
    "barracks": preload("res://assets/sprites/icon_barracks.svg"),
    "archery_range": preload("res://assets/sprites/icon_archery_range.svg"),
    "healer": preload("res://assets/sprites/icon_healer.svg"),
}
const JOBS := ["woodcutter", "miner", "farmer", "builder", "hunter", "scout", "healer", "blacksmith", "soldier"]
const JOB_ICONS := {"woodcutter": "axe", "miner": "pick", "farmer": "wheat", "builder": "hammer", "hunter": "bow", "scout": "compass", "healer": "healer", "blacksmith": "forge", "soldier": "sword"}
const PANEL_BG := Color(0.09, 0.08, 0.11, 0.82)
const PANEL_BORDER := Color("#6b5a40")
const FEEDBACK_MESSAGE_SECONDS := 2.0
const BOSS_WARNING_MESSAGE_SECONDS := 4.0
const GOLD := Color("#ffd23f")
const SLOT_W := 70
const SLOT_H := 30

const HELP_PANEL_WIDTH := 400.0
const HELP_ROW_HEIGHT := 10.0

var _font: Font
var _viewport_size := Vector2(480, 270)
var _top_bar: Panel
var _clock_widget: HUD_WIDGETS.ClockWidget
var _people_icon: TextureRect
var _stage_icon: TextureRect
var _vitals_panel: Panel
var _stage_panel: Panel
var _build_left_hint: Label
var _build_right_hint: Label
var _queue_button: HUD_WIDGETS.HudChip
var _queue_backdrop: ColorRect
var _queue_panel: Panel
var _queue_count_label: Label
var _queue_list: VBoxContainer
var _queue_panel_component = CONSTRUCTION_QUEUE_PANEL_SCRIPT.new()
var _outpost_panel_component = OUTPOST_PANEL_SCRIPT.new()
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
var _tech_btn: HUD_WIDGETS.TechButton
var _map_button: HUD_WIDGETS.HudChip
var _jobs_button: HUD_WIDGETS.HudChip
var _jobs_panel: Panel
var _outpost_button: HUD_WIDGETS.HudChip
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
var _stage_bar: HUD_WIDGETS.StatBar
var _research_panel: Panel
var _research_name: Label
var _research_bar: HUD_WIDGETS.StatBar
var _slot_nodes: Array = []
var _hp_bar: HUD_WIDGETS.StatBar
var _hp_text: Label
var _keep_bar: HUD_WIDGETS.StatBar
var _keep_text: Label
var _combat_bar: HUD_WIDGETS.CombatBar
var _boss_panel: Panel
var _boss_bar: HUD_WIDGETS.StatBar
var _boss_title: Label
var _jobs: Dictionary = {}
var _slots: Dictionary = {}
var _help: Panel
var _help_key_labels: Array[Label] = []
var _help_desc_labels: Array[Label] = []
var _msg: Label
var _msg_bubble: Panel
var _banner: Label
var _event_decision_panel
var _over: ColorRect
var _over_label: Label

var _selected := ""
var _msg_tween: Tween
var _banner_tween: Tween
var _scan_t := 0.0


func _ready() -> void:
    _queue_panel_component.configure(self)
    _outpost_panel_component.configure(self, ICONS)
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
    if not Settings.bindings_changed.is_connected(_on_bindings_changed):
        Settings.bindings_changed.connect(_on_bindings_changed)
    var main_node = get_tree().get_first_node_in_group("main")
    if main_node != null:
        var initial_stage: Dictionary = main_node.spawner.stage_info(GameClock.day)
        _on_stage_changed(String(initial_stage.get("id", "frontier")), String(initial_stage.get("name", "PERBATASAN")), GameClock.day)
    _event_decision_panel = EVENT_DECISION_PANEL_SCRIPT.new()
    if main_node != null:
        _event_decision_panel.configure(main_node.events)
    add_child(_event_decision_panel)
    _refresh_resources()
    _refresh_slots()
    get_viewport().size_changed.connect(_on_viewport_size_changed)
    if not Settings.content_viewport_resized.is_connected(_on_content_viewport_resized):
        Settings.content_viewport_resized.connect(_on_content_viewport_resized)
    _layout_viewport()


# ---------------------------------------------------------------- pembangun UI

func _bind_focus_hint(control: Control) -> void:
    if not control.tooltip_text.is_empty():
        control.focus_entered.connect(_show_message.bind(control.tooltip_text))


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
    var icon_node := _icon(parent, icon_name, pos + Vector2(0, 2))
    icon_node.tooltip_text = "%s tersimpan" % icon_name.capitalize()
    var value := _label(parent, "0", pos + Vector2(13, 0))
    value.tooltip_text = "%s tersimpan" % icon_name.capitalize()
    value.mouse_filter = Control.MOUSE_FILTER_STOP
    return value


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
    _iron.tooltip_text = "Besi tersimpan"
    _iron.mouse_filter = Control.MOUSE_FILTER_STOP
    _iron_icon.tooltip_text = "Besi tersimpan"
    for divider_x in [35.0, 71.0, 107.0, 145.0]:
        var divider := ColorRect.new()
        divider.position = Vector2(divider_x, 4)
        divider.size = Vector2(1, 10)
        divider.color = Color("#756044")
        divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
        bar.add_child(divider)

    _clock_widget = HUD_WIDGETS.ClockWidget.new()
    _clock_widget.font = _font
    _clock_widget.sun = ICONS["sun"]
    _clock_widget.moon = ICONS["moon"]
    _clock_widget.position = Vector2(151, 0)
    _clock_widget.size = Vector2(142, 18)
    _clock_widget.tooltip_text = "Hari dan siklus siang / malam"
    bar.add_child(_clock_widget)

    _foes_icon = _icon(bar, "skull", Vector2(300, 3))
    _foes = _label(bar, "0", Vector2(313, 1), Color("#ff8a7a"))
    _foes_icon.tooltip_text = "Nearby hostile forces"
    _foes.tooltip_text = "Nearby hostile forces"
    _foes_icon.visible = false
    _foes.visible = false

    _people_icon = _icon(bar, "people", Vector2(358, 3))
    _pop = _label(bar, "0/0", Vector2(371, 1), Color("#a9c9bf"))
    _pop.tooltip_text = "Jumlah warga / kapasitas rumah"
    _pop.mouse_filter = Control.MOUSE_FILTER_STOP
    _people_icon.tooltip_text = "Jumlah warga / kapasitas rumah"

    _map_button = HUD_WIDGETS.HudChip.new()
    _map_button.icon = ICONS["compass"]
    _map_button.font = _font
    _map_button.tooltip_text = "Peta wilayah  ·  TAB"
    _map_button.position = Vector2(410, 1)
    _map_button.size = Vector2(18, 14)
    _map_button.pressed.connect(_toggle_map)
    _bind_focus_hint(_map_button)
    bar.add_child(_map_button)

    _jobs_button = HUD_WIDGETS.HudChip.new()
    _jobs_button.icon = ICONS["people"]
    _jobs_button.font = _font
    _jobs_button.tooltip_text = "Pekerjaan dan prioritas warga"
    _jobs_button.position = Vector2(432, 1)
    _jobs_button.size = Vector2(18, 14)
    _jobs_button.pressed.connect(_toggle_jobs)
    _bind_focus_hint(_jobs_button)
    bar.add_child(_jobs_button)

    _tech_btn = HUD_WIDGETS.TechButton.new()
    _tech_btn.icon = ICONS["tech"]
    _tech_btn.font = _font
    _tech_btn.tooltip_text = "Riset teknologi  ·  Y"
    _tech_btn.position = Vector2(454, 1)
    _tech_btn.size = Vector2(22, 14)
    _tech_btn.pressed.connect(func() -> void: Events.tech_panel_requested.emit())
    _bind_focus_hint(_tech_btn)
    bar.add_child(_tech_btn)

    _research_panel = _panel(Vector2(4, 45), Vector2(126, 12))
    _research_name = _label(_research_panel, "", Vector2(3, 1), Color("#ffd23f"))
    _research_name.visible = false
    _icon(_research_panel, "tech", Vector2(3, 0))
    _research_panel.tooltip_text = "Progres riset aktif"
    _research_bar = HUD_WIDGETS.StatBar.new()
    _research_bar.position = Vector2(22, 3)
    _research_bar.size = Vector2(99, 6)
    _research_bar.fill = Color("#6fcf5a")
    _research_panel.add_child(_research_bar)
    _research_panel.visible = false

    _fps = _label(self, "", Vector2(72, 259), Color("#9ad0ff"))
    _fps.visible = false

func _build_vitals() -> void:
    _vitals_panel = _panel(Vector2(4, 22), Vector2(122, 20))
    _vitals_panel.tooltip_text = "Kesehatan pemain dan ketahanan benteng"
    var p := _vitals_panel
    _icon(p, "heart", Vector2(3, 2))
    _hp_bar = HUD_WIDGETS.StatBar.new()
    _hp_bar.position = Vector2(17, 3)
    _hp_bar.size = Vector2(98, 5)
    _hp_bar.fill = Color("#d63a3a")
    p.add_child(_hp_bar)
    _hp_text = _label(p, "100", Vector2(66, 1))
    _hp_text.visible = false
    _icon(p, "keep", Vector2(3, 10))
    _keep_bar = HUD_WIDGETS.StatBar.new()
    _keep_bar.position = Vector2(17, 11)
    _keep_bar.size = Vector2(98, 5)
    _keep_bar.fill = GOLD
    p.add_child(_keep_bar)
    _keep_text = _label(p, "-", Vector2(66, 9))
    _keep_text.visible = false

func _build_stage_bar() -> void:
    _stage_panel = _panel(Vector2(136, 22), Vector2(205, 20))
    var p := _stage_panel
    _stage_icon = _icon(p, "compass", Vector2(4, 3))
    _stage_label = _label(p, "BAB I  PERBATASAN", Vector2(3, 1), Color("#f0d39a"))
    _stage_label.visible = false
    _stage_bar = HUD_WIDGETS.StatBar.new()
    _stage_bar.position = Vector2(22, 6)
    _stage_bar.size = Vector2(178, 8)
    _stage_panel.tooltip_text = "Campaign chapter and progression"
    _stage_bar.fill = Color("#b98c4a")
    p.add_child(_stage_bar)


func _build_combat_bar() -> void:
    _combat_bar = HUD_WIDGETS.CombatBar.new()
    _combat_bar.font = _font
    _combat_bar.position = Vector2(151, 219)
    _combat_bar.size = Vector2(158, 18)
    _combat_bar.ability_icons = [ICONS["compass"], ICONS["sword"], ICONS["people"]]
    _combat_bar.tooltip_text = "Q · Dash    C · Tebas    V · Seruan — ikon menunjukkan status dan cooldown"
    _combat_bar.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(_combat_bar)
    _blockers.append(_combat_bar)

func _build_jobs() -> void:
    _jobs_panel = _panel(Vector2(400, 22), Vector2(76, 132))
    for i in JOBS.size():
        var row := HUD_WIDGETS.JobRow.new()
        row.job = JOBS[i]
        row.icon = ICONS[JOB_ICONS[JOBS[i]]]
        row.font = _font
        row.position = Vector2(2, 3 + i * 12)
        row.size = Vector2(72, 12)
        var job_descriptions := {
            "woodcutter": "Penebang — mengumpulkan kayu",
            "miner": "Penambang — mengambil batu dan bijih",
            "farmer": "Petani — menghasilkan makanan",
            "builder": "Pembangun — membangun dan memperbaiki",
            "hunter": "Pemburu — memasok makanan dari satwa",
            "scout": "Pengintai — membuka wilayah",
            "healer": "Penyembuh — memulihkan unit terluka",
            "blacksmith": "Pandai besi — membuat perlengkapan prajurit",
            "soldier": "Prajurit — mempertahankan permukiman"
        }
        row.tooltip_text = String(job_descriptions.get(JOBS[i], JOBS[i])) + "  ·  Left click −/+ quota, right click priority"
        row.adjust.connect(_on_job_adjust)
        row.priority_adjust.connect(_on_job_priority_adjust)
        _jobs_panel.add_child(row)
        _jobs[JOBS[i]] = row
    _outpost_button = HUD_WIDGETS.HudChip.new()
    _outpost_button.icon = ICONS["outpost"]
    _outpost_button.font = _font
    _outpost_button.tooltip_text = "Outposts, garrisons and logistics"
    _outpost_button.position = Vector2(2, 116)
    _outpost_button.size = Vector2(72, 13)
    _outpost_button.pressed.connect(_toggle_outposts)
    _bind_focus_hint(_outpost_button)
    _jobs_panel.add_child(_outpost_button)
    _jobs_panel.visible = false

func _build_boss_bar() -> void:
    _boss_panel = _panel(Vector2(140, 46), Vector2(200, 18))
    _boss_title = _label(_boss_panel, "RAJA LAWAN", Vector2(0, 0), Color("#ff8a7a"))
    _boss_title.size = Vector2(200, 9)
    _boss_title.visible = false
    _icon(_boss_panel, "skull", Vector2(4, 3))
    _boss_bar = HUD_WIDGETS.StatBar.new()
    _boss_bar.position = Vector2(23, 5)
    _boss_bar.size = Vector2(170, 8)
    _boss_bar.fill = Color("#c0392b")
    _boss_panel.add_child(_boss_bar)
    _boss_panel.visible = false


func _build_build_bar() -> void:
    _queue_button = HUD_WIDGETS.HudChip.new()
    _queue_button.icon = ICONS["hammer"]
    _queue_button.font = _font
    _queue_button.position = Vector2(4, 211)
    _queue_button.size = Vector2(18, 16)
    _queue_button.tooltip_text = "Buka antrean konstruksi (%s)" % Settings.binding_label("toggle_construction_queue")
    _queue_button.pressed.connect(_toggle_construction_queue)
    _bind_focus_hint(_queue_button)
    add_child(_queue_button)
    _blockers.append(_queue_button)
    _build_left_hint = _label(self, "BANGUNAN 1-8", Vector2(46, 225), Color(1, 1, 1, 0.78))
    _build_left_hint.visible = false
    _build_right_hint = _label(self, "", Vector2(360, 225), Color(1, 1, 1, 0.78))
    _build_right_hint.visible = false
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
        var slot := HUD_WIDGETS.BuildSlot.new()
        slot.id = id
        slot.font = _font
        var data: Dictionary = DataDB.buildings[id]
        slot.title = String(data.get("short", data["name"]))
        slot.icon = ICONS[id]
        _update_build_slot_binding(slot, i)
        _bind_focus_hint(slot)
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
    _outpost_panel_component._build_outpost_panel()

func _on_outpost_backdrop_input(event: InputEvent) -> void:
    _outpost_panel_component._on_outpost_backdrop_input(event)


func _refresh_outpost_panel() -> void:
    _outpost_panel_component._refresh_outpost_panel()

func _depot_option_cell(option: OptionButton) -> Vector2i:
    return _outpost_panel_component._depot_option_cell(option)


func _refresh_depot_option(option: OptionButton, depots: Array, preferred: Vector2i, default_index: int) -> void:
    _outpost_panel_component._refresh_depot_option(option, depots, preferred, default_index)



func _refresh_cost_source_controls(depots: Array) -> void:
    _outpost_panel_component._refresh_cost_source_controls(depots)


func _on_cost_source_selected(index: int) -> void:
    _outpost_panel_component._on_cost_source_selected(index)


func _on_supply_state_changed() -> void:
    _outpost_panel_component._on_supply_state_changed()


func _refresh_shipment_controls() -> void:
    _outpost_panel_component._refresh_shipment_controls()


func _refresh_shipment_kind_options(depots: Array) -> void:
    _outpost_panel_component._refresh_shipment_kind_options(depots)


func _on_shipment_endpoint_selected(_index: int) -> void:
    _outpost_panel_component._on_shipment_endpoint_selected(_index)


func _shipment_name(cell: Vector2i) -> String:
    return _outpost_panel_component._shipment_name(cell)


func _create_shipment_order() -> void:
    _outpost_panel_component._create_shipment_order()


func _cancel_shipment_order(order_id: int) -> void:
    _outpost_panel_component._cancel_shipment_order(order_id)



func _assign_outpost_guard(outpost) -> void:
    _outpost_panel_component._assign_outpost_guard(outpost)


func _release_outpost_guard(outpost) -> void:
    _outpost_panel_component._release_outpost_guard(outpost)


func _assign_archer(archery_range) -> void:
    _outpost_panel_component._assign_archer(archery_range)


func _release_archer(archery_range) -> void:
    _outpost_panel_component._release_archer(archery_range)


func _toggle_outposts() -> void:
    _outpost_panel_component._toggle_outposts()


func _build_construction_queue_panel() -> void:
    _queue_panel_component.build()


func _on_queue_backdrop_input(event: InputEvent) -> void:
    _queue_panel_component.on_backdrop_input(event)


func _toggle_construction_queue() -> void:
    _queue_panel_component.toggle()


func _close_construction_queue() -> void:
    _queue_panel_component.close()


func _on_construction_queue_changed() -> void:
    _queue_panel_component.on_changed()


func _refresh_construction_queue() -> void:
    _queue_panel_component.refresh()


func _on_queue_move_requested(site, direction: int) -> void:
    _queue_panel_component.move_requested(site, direction)


func _on_queue_cancel_requested(site) -> void:
    _queue_panel_component.cancel_requested(site)


func _current_help_rows() -> Array:
    var movement_vertical := "%s  %s" % [
        Settings.binding_label("move_up"), Settings.binding_label("move_down")
    ]
    var movement_horizontal := "%s  %s" % [
        Settings.binding_label("move_left"), Settings.binding_label("move_right")
    ]
    var build_keys := PackedStringArray()
    for slot_index in 10:
        build_keys.append(Settings.binding_short_label("build_slot_%d" % (slot_index + 1)))
    var job_keys := PackedStringArray()
    for job in JOBS:
        job_keys.append(Settings.binding_short_label("job_" + job))
    return [
        [movement_vertical, "GERAK ATAS / BAWAH"],
        [movement_horizontal, "GERAK KIRI / KANAN"],
        [Settings.binding_label("interact"), "INTERAKSI / PANEN"],
        [Settings.binding_label("attack") + " / KLIK KIRI", "SERANG"],
        [Settings.binding_label("sprint"), "TAHAN UNTUK LARI"],
        [Settings.binding_label("ability_dash"), "DASH (LEVEL 1)"],
        [Settings.binding_label("ability_cleave"), "TEBAS (LEVEL 2)"],
        [Settings.binding_label("ability_rally"), "SERUAN (LEVEL 3)"],
        [" ".join(build_keys), "PILIH BANGUNAN"],
        ["KLIK KIRI / KANAN", "PASANG / BATALKAN / BONGKAR"],
        [" ".join(job_keys), "PILIH JOB"],
        ["SHIFT + JOB", "KURANGI KUOTA"],
        ["ALT + JOB", "NAIKKAN PRIORITAS"],
        ["ALT + SHIFT + JOB", "TURUNKAN PRIORITAS"],
        ["KLIK − / +", "UBAH KUOTA JOB"],
        [Settings.binding_label("toggle_technology") + " / " + Settings.binding_label("toggle_construction_queue"), "TEKNOLOGI / ANTREAN"],
        [Settings.binding_label("toggle_map") + " / " + Settings.binding_label("toggle_objectives"), "PETA / OBJEKTIF"],
        [Settings.binding_label("command_expedition") + " / " + Settings.binding_label("menu_pause"), "EKSPEDISI / JEDA"],
        [Settings.binding_label("save_game") + " / " + Settings.binding_label("load_game"), "SIMPAN / MUAT"],
    ]


func _build_help() -> void:
    var rows := _current_help_rows()
    var h := rows.size() * HELP_ROW_HEIGHT + 30.0
    _help = _panel(
        Vector2((_viewport_size.x - HELP_PANEL_WIDTH) * 0.5, (_viewport_size.y - h) * 0.5),
        Vector2(HELP_PANEL_WIDTH, h)
    )
    var title := _label(_help, "KONTROL", Vector2(0, 5), GOLD)
    title.size = Vector2(HELP_PANEL_WIDTH, 9)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    for i in rows.size():
        var key_label := _label(_help, rows[i][0], Vector2(12, 18 + i * HELP_ROW_HEIGHT), Color("#ffd9a0"))
        key_label.size = Vector2(202, 9)
        var desc_label := _label(_help, rows[i][1], Vector2(220, 18 + i * HELP_ROW_HEIGHT))
        desc_label.size = Vector2(168, 9)
        _help_key_labels.append(key_label)
        _help_desc_labels.append(desc_label)
    var foot := _label(_help, "%s  TUTUP BANTUAN" % Settings.binding_label("toggle_help"), Vector2(0, h - 12), Color(1, 1, 1, 0.7))
    foot.size = Vector2(HELP_PANEL_WIDTH, 9)
    foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _help.visible = false


func _update_build_slot_binding(slot: HUD_WIDGETS.BuildSlot, slot_index: int) -> void:
    var action := "build_slot_%d" % (slot_index + 1)
    slot.key_text = Settings.binding_short_label(action)
    var data: Dictionary = DataDB.buildings[slot.id]
    var cost := DataDB.cost_of(slot.id)
    var cost_parts: Array[String] = []
    for kind in ["wood", "stone", "iron", "food"]:
        if cost.has(kind):
            cost_parts.append("%s %d" % [kind.capitalize(), int(cost[kind])])
    slot.tooltip_text = "%s  ·  tombol %s\n%s" % [
        String(data["name"]), Settings.binding_label(action),
        ", ".join(PackedStringArray(cost_parts)) if not cost_parts.is_empty() else "Tanpa biaya resource"
    ]
    slot.queue_redraw()


func _on_bindings_changed() -> void:
    for i in _slot_nodes.size():
        var slot: HUD_WIDGETS.BuildSlot = _slot_nodes[i]
        _update_build_slot_binding(slot, i)
    _queue_button.tooltip_text = "Buka antrean konstruksi (%s)" % Settings.binding_label("toggle_construction_queue")
    _combat_bar.tooltip_text = "%s · Dash    %s · Tebas    %s · Seruan — status dan cooldown" % [
        Settings.binding_label("ability_dash"),
        Settings.binding_label("ability_cleave"),
        Settings.binding_label("ability_rally")
    ]
    _build_right_hint.text = "%s PETA  ·  %s BANTUAN" % [
        Settings.binding_label("toggle_map"), Settings.binding_label("toggle_help")
    ]
    for i in JOBS.size():
        var job_action := "job_" + JOBS[i]
        var row: HUD_WIDGETS.JobRow = _jobs[JOBS[i]]
        var descriptions := {
            "woodcutter": "Penebang — mengumpulkan kayu",
            "miner": "Penambang — mengambil batu dan bijih",
            "farmer": "Petani — menghasilkan makanan",
            "builder": "Pembangun — membangun dan memperbaiki",
            "hunter": "Pemburu — memasok makanan dari satwa",
            "scout": "Pengintai — membuka wilayah",
            "healer": "Penyembuh — memulihkan unit terluka",
            "blacksmith": "Pandai besi — membuat perlengkapan prajurit",
            "soldier": "Prajurit — mempertahankan permukiman"
        }
        row.tooltip_text = "%s  ·  %s tambah kuota, SHIFT kurangi, ALT ubah prioritas" % [
            String(descriptions.get(JOBS[i], JOBS[i])),
            Settings.binding_label(job_action)
        ]
    var rows := _current_help_rows()
    for i in mini(rows.size(), _help_key_labels.size()):
        _help_key_labels[i].text = rows[i][0]
        _help_desc_labels[i].text = rows[i][1]
    if _help.get_child_count() > 0:
        var footer := _help.get_child(_help.get_child_count() - 1) as Label
        if footer != null:
            footer.text = "%s  TUTUP BANTUAN" % Settings.binding_label("toggle_help")

func _build_messages() -> void:
    # Short-lived feedback uses a compact dark bubble instead of floating text
    # across the entire playfield.
    _msg_bubble = Panel.new()
    _msg_bubble.size = Vector2(280, 22)
    _msg_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _msg_bubble.visible = false
    var bubble_style := StyleBoxFlat.new()
    bubble_style.bg_color = Color(0.055, 0.05, 0.045, 0.96)
    bubble_style.border_color = Color("#9a7948")
    bubble_style.set_border_width_all(1)
    bubble_style.corner_radius_top_left = 2
    bubble_style.corner_radius_top_right = 2
    bubble_style.corner_radius_bottom_left = 2
    bubble_style.corner_radius_bottom_right = 2
    _msg_bubble.add_theme_stylebox_override("panel", bubble_style)
    add_child(_msg_bubble)
    _msg = _label(_msg_bubble, "", Vector2(6, 2))
    _msg.size = Vector2(268, 18)
    _msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _msg.modulate.a = 1.0
    _msg_bubble.modulate.a = 0.0
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
    _people_icon.position.x = _viewport_size.x - 122.0
    _pop.position.x = _viewport_size.x - 109.0

    _map_button.position.x = _viewport_size.x - 70.0
    _jobs_button.position.x = _viewport_size.x - 48.0
    _tech_btn.position.x = _viewport_size.x - 26.0

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
    _queue_button.position = Vector2(5, build_y - 18.0)
    _build_left_hint.position = Vector2(46, build_y - 14.0)
    _build_right_hint.position = Vector2(_viewport_size.x - 132.0, build_y - 14.0)
    _build_right_hint.size = Vector2(127.0, 10)
    _build_right_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

    _combat_bar.position = Vector2((_viewport_size.x - _combat_bar.size.x) * 0.5, build_y - _combat_bar.size.y - 19.0)
    _msg_bubble.position = Vector2(
        (_viewport_size.x - _msg_bubble.size.x) * 0.5,
        _combat_bar.position.y - _msg_bubble.size.y - 6.0
    )
    _banner.position = Vector2(0, maxf(82.0, _viewport_size.y * 0.16))
    _banner.size.x = _viewport_size.x
    if _event_decision_panel != null:
        _event_decision_panel.configure_layout(_viewport_size)
    _fps.position = Vector2(_viewport_size.x - 58.0, 96.0)

    _over.size = _viewport_size
    _over_label.position = Vector2(0, (_viewport_size.y - _over_label.size.y) * 0.5)
    _over_label.size.x = _viewport_size.x

    for slot_index in _slot_nodes.size():
        var slot: HUD_WIDGETS.BuildSlot = _slot_nodes[slot_index]
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
        _research_panel.tooltip_text = "%s — progres riset %d%%" % [
            Tech.tech_name(Tech.current), roundi(Tech.progress_ratio() * 100.0)
        ]
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
    var queued_spawns: int = main_node.spawner.remaining_wave_spawns() if main_node != null else 0
    _foes.text = "%d+%d" % [foes.size(), queued_spawns] if queued_spawns > 0 else str(foes.size())
    var hostile_pressure: int = foes.size() + queued_spawns
    _foes.tooltip_text = "%d musuh aktif · %d tersisa dalam gelombang" % [foes.size(), queued_spawns]
    _foes_icon.tooltip_text = _foes.tooltip_text
    _foes.visible = hostile_pressure > 0
    _foes_icon.visible = hostile_pressure > 0
    var boss = null
    for e in foes:
        if e.is_boss:
            boss = e
            break
    if boss != null:
        _boss_title.text = "RAJA LAWAN"
        _boss_title.add_theme_color_override("font_color", Color("#ff8a7a"))
        _boss_panel.tooltip_text = "Raja lawan — ketahanan"
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
            _boss_panel.tooltip_text = "%s stronghold integrity" % String(stronghold.faction_id).replace("_", " ").capitalize()
            _boss_bar.set_value(float(stronghold.hp) / stronghold.max_hp)


func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey and event.pressed and not event.echo):
        return
    if _over.visible:
        if Input.is_action_just_pressed("load_last_save"):
            SaveSystem.request_load()
        elif Input.is_action_just_pressed("restart_game"):
            Inventory.reset()
            GameClock.reset()
            Tech.reset()
            get_tree().paused = false
            get_tree().reload_current_scene()
        return
    if _event_decision_panel != null and _event_decision_panel.visible:
        return
    if Input.is_action_just_pressed("toggle_construction_queue"):
        _toggle_construction_queue()
        get_viewport().set_input_as_handled()
    elif Input.is_action_just_pressed("game_cancel") and _queue_panel.visible:
        _toggle_construction_queue()
        get_viewport().set_input_as_handled()
    elif Input.is_action_just_pressed("game_cancel") and _map_panel.visible:
        _toggle_map()
        get_viewport().set_input_as_handled()
    elif Input.is_action_just_pressed("game_cancel") and _jobs_panel.visible:
        _toggle_jobs()
        get_viewport().set_input_as_handled()
    elif Input.is_action_just_pressed("game_cancel") and _outpost_panel.visible:
        _toggle_outposts()
        get_viewport().set_input_as_handled()
    elif Input.is_action_just_pressed("toggle_map"):
        _toggle_map()
        get_viewport().set_input_as_handled()
    elif Input.is_action_just_pressed("toggle_help"):
        _help.visible = not _help.visible
        get_viewport().set_input_as_handled()
    elif Input.is_action_just_pressed("toggle_fps"):
        _fps.visible = not _fps.visible
        _fps.text = ""
        get_viewport().set_input_as_handled()


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
    _stage_panel.tooltip_text = "%s — %s  ·  Day %d\n%s" % [
        String(stage_id).to_upper(), stage_name, day, stage_summary
    ]
    _stage_icon.tooltip_text = _stage_panel.tooltip_text
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
        _jobs[j].set_counts(int(assigned.get(j, 0)), int(quota.get(j, 0)), rank)


func _refresh_resources() -> void:
    _wood.text = str(Inventory.get_amount("wood"))
    _stone.text = str(Inventory.get_amount("stone"))
    var village = get_tree().get_first_node_in_group("village")
    _food.text = str(village.food_available() if village != null else Inventory.get_amount("food"))
    _iron.text = str(Inventory.get_amount("iron"))
    var show_iron := Tech.has_flag("iron_mining") or Inventory.get_amount("iron") > 0
    _iron.visible = show_iron
    _iron_icon.visible = show_iron


func _refresh_slots() -> void:
    for id in _slots:
        var slot: HUD_WIDGETS.BuildSlot = _slots[id]
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


func _message_duration(message: String) -> float:
    if message.begins_with("Raja lawan mendekat!"):
        return BOSS_WARNING_MESSAGE_SECONDS
    return FEEDBACK_MESSAGE_SECONDS


func _show_message(text: String) -> void:
    _msg.text = text
    _msg_bubble.visible = true
    _msg_bubble.modulate.a = 1.0
    if _msg_tween != null:
        _msg_tween.kill()
    _msg_tween = create_tween()
    _msg_tween.tween_interval(_message_duration(text))
    _msg_tween.tween_property(_msg_bubble, "modulate:a", 0.0, 0.45)
    _msg_tween.tween_callback(func() -> void: _msg_bubble.visible = false)

