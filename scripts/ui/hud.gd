extends CanvasLayer
## HUD: panel atas (sumber daya, jam, musuh, penduduk), vitals, kuota job (bisa diklik),
## bar boss, bar bangunan (bisa diklik), bantuan (H), dan layar game over / menang.

const PIXEL_FONT := preload("res://scripts/ui/pixel_font.gd")
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
}
const JOBS := ["woodcutter", "miner", "farmer", "soldier"]
const JOB_ICONS := {"woodcutter": "axe", "miner": "pick", "farmer": "wheat", "soldier": "sword"}
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
    ["1-6", "PILIH BANGUNAN"],
    ["KLIK KIRI", "PASANG BANGUNAN"],
    ["KLIK KANAN", "BATAL / BONGKAR"],
    ["T M K R", "TAMBAH JOB"],
    ["SHIFT + T M K R", "KURANGI JOB"],
    ["KLIK + / -", "UBAH KUOTA JOB"],
    ["P / ESC", "MENU"],
    ["F5 / F9", "SIMPAN / MUAT"],
    ["F3", "TAMPILKAN FPS"],
]

var _font: Font
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
var _research_panel: Panel
var _research_name: Label
var _research_bar: StatBar
var _slot_nodes: Array = []
var _hp_bar: StatBar
var _hp_text: Label
var _keep_bar: StatBar
var _keep_text: Label
var _boss_panel: Panel
var _boss_bar: StatBar
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
    _build_jobs()
    _build_boss_bar()
    _build_build_bar()
    _build_help()
    _build_messages()
    _build_overlay()

    Events.resource_changed.connect(_on_resource_changed)
    Events.build_selected.connect(_on_build_selected)
    Events.build_feedback.connect(_show_message)
    Events.player_hp_changed.connect(_on_player_hp)
    Events.keep_hp_changed.connect(_on_keep_hp)
    Events.game_over.connect(_on_game_over)
    Events.game_won.connect(_on_game_won)
    Events.event_triggered.connect(_on_event)
    Events.village_changed.connect(_on_village_changed)
    Events.tech_researched.connect(_on_tech_changed)
    _refresh_resources()
    _refresh_slots()


# ---------------------------------------------------------------- pembangun UI

func _panel(pos: Vector2, panel_size: Vector2, parent: Node = null) -> Panel:
    var p := Panel.new()
    p.position = pos
    p.size = panel_size
    var sb := StyleBoxFlat.new()
    sb.bg_color = PANEL_BG
    sb.border_color = PANEL_BORDER
    sb.set_border_width_all(1)
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
    var bar := _panel(Vector2(0, 0), Vector2(480, 15))
    _wood = _stat(bar, "wood", Vector2(3, 1))
    _stone = _stat(bar, "stone", Vector2(46, 1))
    _food = _stat(bar, "food", Vector2(89, 1))
    _iron_icon = _icon(bar, "iron", Vector2(132, 3))
    _iron = _label(bar, "0", Vector2(145, 1))

    var clock := ClockWidget.new()
    clock.font = _font
    clock.sun = ICONS["sun"]
    clock.moon = ICONS["moon"]
    clock.position = Vector2(176, 2)
    clock.size = Vector2(142, 11)
    bar.add_child(clock)

    _foes_icon = _icon(bar, "skull", Vector2(322, 3))
    _foes = _label(bar, "0", Vector2(335, 1), Color("#ff8a7a"))
    _foes_icon.visible = false
    _foes.visible = false

    _icon(bar, "people", Vector2(362, 3))
    _pop = _label(bar, "0/0", Vector2(375, 1))

    _tech_btn = TechButton.new()
    _tech_btn.icon = ICONS["tech"]
    _tech_btn.font = _font
    _tech_btn.position = Vector2(420, 1)
    _tech_btn.size = Vector2(58, 13)
    _tech_btn.pressed.connect(func() -> void: Events.tech_panel_requested.emit())
    bar.add_child(_tech_btn)

    # Progres riset: muncul di bawah jam saat ada riset berjalan.
    _research_panel = _panel(Vector2(176, 16), Vector2(146, 12))
    _research_name = _label(_research_panel, "", Vector2(3, 1), Color("#ffd23f"))
    _research_bar = StatBar.new()
    _research_bar.position = Vector2(80, 3)
    _research_bar.size = Vector2(62, 6)
    _research_bar.fill = Color("#6fcf5a")
    _research_panel.add_child(_research_bar)
    _research_panel.visible = false

    _fps = _label(self, "", Vector2(72, 259), Color("#9ad0ff"))
    _fps.visible = false


func _build_vitals() -> void:
    var p := _panel(Vector2(3, 18), Vector2(94, 27))
    _icon(p, "heart", Vector2(4, 3))
    _hp_bar = StatBar.new()
    _hp_bar.position = Vector2(17, 4)
    _hp_bar.size = Vector2(42, 7)
    _hp_bar.fill = Color("#d63a3a")
    p.add_child(_hp_bar)
    _hp_text = _label(p, "100", Vector2(62, 2))
    _icon(p, "keep", Vector2(4, 15))
    _keep_bar = StatBar.new()
    _keep_bar.position = Vector2(17, 16)
    _keep_bar.size = Vector2(42, 7)
    _keep_bar.fill = GOLD
    p.add_child(_keep_bar)
    _keep_text = _label(p, "-", Vector2(62, 14))


func _build_jobs() -> void:
    var p := _panel(Vector2(402, 18), Vector2(74, 54))
    for i in JOBS.size():
        var row := JobRow.new()
        row.job = JOBS[i]
        row.icon = ICONS[JOB_ICONS[JOBS[i]]]
        row.font = _font
        row.position = Vector2(2, 3 + i * 12)
        row.size = Vector2(70, 12)
        row.adjust.connect(_on_job_adjust)
        p.add_child(row)
        _jobs[JOBS[i]] = row


func _build_boss_bar() -> void:
    _boss_panel = _panel(Vector2(140, 18), Vector2(200, 18))
    var name_lbl := _label(_boss_panel, "RAJA LAWAN", Vector2(0, 0), Color("#ff8a7a"))
    name_lbl.size = Vector2(200, 9)
    name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _boss_bar = StatBar.new()
    _boss_bar.position = Vector2(6, 10)
    _boss_bar.size = Vector2(188, 6)
    _boss_bar.fill = Color("#c0392b")
    _boss_panel.add_child(_boss_bar)
    _boss_panel.visible = false


func _build_build_bar() -> void:
    _label(self, "H BANTUAN", Vector2(4, 270 - SLOT_H - 14), Color(1, 1, 1, 0.7))
    _rebuild_build_bar()


## Bar hanya menampilkan bangunan yang sudah terbuka; dibangun ulang saat riset selesai.
## Bangunan baru selalu di ujung kanan, jadi nomor hotkey yang sudah dikenal tidak bergeser.
func _rebuild_build_bar() -> void:
    for s in _slot_nodes:
        _blockers.erase(s)
        s.queue_free()
    _slot_nodes.clear()
    _slots.clear()
    var ids: Array = Tech.available_buildings()
    var n := ids.size()
    var w := mini(SLOT_W, int((466.0 - (n - 1) * 3.0) / n))
    var total := n * w + (n - 1) * 3
    var x0 := (480 - total) / 2
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
        slot.position = Vector2(x0 + i * (w + 3), 270 - SLOT_H - 2)
        slot.size = Vector2(w, SLOT_H)
        slot.pressed.connect(_on_slot_pressed)
        add_child(slot)
        _blockers.append(slot)
        _slot_nodes.append(slot)
        _slots[id] = slot
    _refresh_slots()


func _build_help() -> void:
    var h := HELP_ROWS.size() * 11 + 36
    _help = _panel(Vector2(96, (270 - h) / 2), Vector2(288, h))
    var title := _label(_help, "KONTROL", Vector2(0, 6), GOLD)
    title.size = Vector2(288, 9)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    for i in HELP_ROWS.size():
        _label(_help, HELP_ROWS[i][0], Vector2(14, 22 + i * 11), Color("#ffd9a0"))
        _label(_help, HELP_ROWS[i][1], Vector2(124, 22 + i * 11))
    var foot := _label(_help, "H  TUTUP BANTUAN", Vector2(0, h - 13), Color(1, 1, 1, 0.7))
    foot.size = Vector2(288, 9)
    foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _help.visible = false


func _build_messages() -> void:
    _msg = _label(self, "", Vector2(0, 208))
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
    _over.size = Vector2(480, 270)
    _over.visible = false
    add_child(_over)
    _over_label = Label.new()
    _over_label.position = Vector2(0, 90)
    _over_label.size = Vector2(480, 100)
    _over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _over_label.add_theme_font_override("font", _font)
    _over_label.add_theme_font_size_override("font_size", 16)
    _over.add_child(_over_label)


# ---------------------------------------------------------------- loop & input

func _process(delta: float) -> void:
    if _fps.visible:
        _fps.text = "%d FPS" % Engine.get_frames_per_second()
    _scan_t -= delta
    if _scan_t > 0.0:
        return
    _scan_t = 0.2
    _research_panel.visible = Tech.current != ""
    if Tech.current != "":
        _research_name.text = Tech.tech_name(Tech.current).substr(0, 12)
        _research_bar.set_value(Tech.progress_ratio())
    _tech_btn.busy = Tech.current != ""
    _tech_btn.queue_redraw()
    var foes := get_tree().get_nodes_in_group("enemies")
    _foes.text = str(foes.size())
    _foes.visible = foes.size() > 0
    _foes_icon.visible = foes.size() > 0
    var boss = null
    for e in foes:
        if e.is_boss:
            boss = e
            break
    _boss_panel.visible = boss != null
    if boss != null:
        _boss_bar.set_value(float(boss.hp) / boss.max_hp)


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
    if event.keycode == KEY_H or event.keycode == KEY_F1:
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
    for j in JOBS:
        _jobs[j].set_counts(int(assigned[j]), int(quota[j]))


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
        slot.affordable = Inventory.can_afford(DataDB.cost_of(id))
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


func _on_game_won(day: int) -> void:
    _over_label.text = "KAMU MENANG!\nRaja lawan tumbang di hari %d\nTekan R untuk main lagi" % day + _load_hint()
    _over.visible = true
    get_tree().paused = true


func _on_game_over(day: int) -> void:
    _over_label.text = "KEEP HANCUR\nBertahan sampai hari %d\nTekan R untuk mulai ulang" % day + _load_hint()
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
    var job := ""
    var icon: Texture2D
    var font: Font
    var assigned := 0
    var quota := 0

    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_STOP

    func set_counts(a: int, q: int) -> void:
        assigned = a
        quota = q
        queue_redraw()

    func _gui_input(event: InputEvent) -> void:
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            if Rect2(15, 1, 10, 10).has_point(event.position):
                adjust.emit(job, -1)
            elif Rect2(58, 1, 10, 10).has_point(event.position):
                adjust.emit(job, 1)
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
        draw_string(font, Vector2(26, 9), "%d/%d" % [assigned, quota], HORIZONTAL_ALIGNMENT_CENTER, 31, 8, col)


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
        draw_string(font, Vector2(14, 10), "RISET Y", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
