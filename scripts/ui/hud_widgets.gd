extends RefCounted
class_name HudWidgets


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
    var _last_countdown_seconds := -1
    var _last_night_icon := false

    func countdown_text() -> String:
        var seconds: int = GameClock.seconds_until_phase_change()
        return "%02d:%02d" % [floori(float(seconds) / 60.0), seconds % 60]

    func countdown_tooltip() -> String:
        var night_now: bool = GameClock.time_of_day >= GameClock.NIGHT_START and GameClock.time_of_day < GameClock.NIGHT_END
        return ("Fajar dalam " if night_now else "Malam dimulai dalam ") + countdown_text()

    func _process(_delta: float) -> void:
        var seconds := GameClock.seconds_until_phase_change()
        var night_icon := GameClock.darkness() > 0.5
        if seconds == _last_countdown_seconds and night_icon == _last_night_icon:
            return
        _last_countdown_seconds = seconds
        _last_night_icon = night_icon
        tooltip_text = countdown_tooltip()
        queue_redraw()

    func _draw() -> void:
        var night: bool = GameClock.darkness() > 0.5
        draw_texture(moon if night else sun, Vector2(0, 0))
        var final_day := int(DataDB.waves.get("final_day", 0))
        draw_string(font, Vector2(13, 9), "%d/%d" % [GameClock.day, final_day],
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
        var countdown_color: Color = Color("#9eafd8") if night else Color("#e3bd67")
        draw_string(font, Vector2(tx, 17), countdown_text(),
            HORIZONTAL_ALIGNMENT_LEFT, tw, 6, countdown_color)


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
        draw_string(font, Vector2(48, 9), str(priority_rank), HORIZONTAL_ALIGNMENT_CENTER, 9, 6, Color("#d7ba7a"))



## Level, XP, and active-skill cooldowns.
class CombatBar extends Control:
    var font: Font
    var ability_icons: Array = []
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
        var ratio := float(xp) / float(maxi(1, next_xp)) if next_xp > 0 else 1.0
        draw_rect(Rect2(3, 3, 35, 5), Color("#29231d"))
        draw_rect(Rect2(4, 4, 33.0 * clampf(ratio, 0.0, 1.0), 3), Color("#d39b42"))
        draw_string(font, Vector2(3, 15), str(level), HORIZONTAL_ALIGNMENT_LEFT, 10, 6, Color("#ffd23f"))
        var abilities := [
            ["Q", true, float(state.get("dash_cd", 0.0))],
            ["C", bool(state.get("cleave_unlocked", false)), float(state.get("cleave_cd", 0.0))],
            ["V", bool(state.get("rally_unlocked", false)), float(state.get("rally_cd", 0.0))]
        ]
        for i in abilities.size():
            var item: Array = abilities[i]
            var x := 43.0 + i * 37.0
            var unlocked := bool(item[1])
            var cooldown := float(item[2])
            var ready := unlocked and cooldown <= 0.05
            var tint := Color("#ffd23f") if ready else (Color("#a99a83") if unlocked else Color("#665d52"))
            draw_rect(Rect2(x, 1, 34, 16), Color("#211b19"))
            draw_rect(Rect2(x, 1, 34, 16), Color("#6b5a40"), false, 1.0)
            if i < ability_icons.size() and ability_icons[i] is Texture2D:
                draw_texture(ability_icons[i], Vector2(x + 2, 3), tint)
            if unlocked and cooldown > 0.05:
                draw_string(font, Vector2(x + 17, 11), "%.0f" % cooldown,
                    HORIZONTAL_ALIGNMENT_LEFT, 15, 6, Color("#f0d8ad"))
            draw_string(font, Vector2(x + 23, 15), String(item[0]),
                HORIZONTAL_ALIGNMENT_LEFT, 9, 6, Color("#d7ba7a"))


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
        var progress: float = float(site.progress_ratio())
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
        focus_mode = Control.FOCUS_ALL
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
        elif event.is_action_pressed("ui_accept"):
            pressed.emit(id)
            accept_event()

    func _draw() -> void:
        var bg := Color(0.09, 0.08, 0.11, 0.88)
        if hover:
            bg = bg.lightened(0.18)
        draw_rect(Rect2(Vector2.ZERO, size), bg)
        draw_rect(Rect2(Vector2.ZERO, size), Color("#ffd23f") if selected else Color("#6b5a40"), false, 1.0)
        var a := 1.0 if affordable else 0.45
        # Permanent labels/costs are intentionally removed; details remain available by tooltip.
        draw_string(font, Vector2(3, 9), key_text, HORIZONTAL_ALIGNMENT_LEFT, 22, 6, Color(1, 1, 1, a * 0.8))
        var icon_size := Vector2(icon.get_size())
        var icon_pos := Vector2((size.x - icon_size.x) * 0.5, (size.y - icon_size.y) * 0.5)
        draw_texture(icon, icon_pos, Color(1, 1, 1, a))
        draw_circle(Vector2(size.x - 5, size.y - 5), 2.0,
            Color("#75b86c") if affordable else Color("#c75a4d"))
        if selected:
            draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Color("#ffd23f"), false, 1.0)

## Compact top-bar button for secondary panels.
class HudChip extends Control:
    signal pressed
    var label := ""
    var icon: Texture2D
    var font: Font
    var active := false
    var hover := false

    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_STOP
        focus_mode = Control.FOCUS_ALL
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
        elif event.is_action_pressed("ui_accept"):
            pressed.emit()
            accept_event()

    func _draw() -> void:
        var bg := Color("#51432f") if active else Color("#201d1a")
        if hover:
            bg = bg.lightened(0.18)
        draw_rect(Rect2(Vector2.ZERO, size), bg)
        draw_rect(Rect2(Vector2.ZERO, size), Color("#e0b969") if active else Color("#6b5a40"), false, 1.0)
        if icon != null:
            var icon_pos := (size - Vector2(icon.get_size())) * 0.5
            draw_texture(icon, icon_pos)
        elif not label.is_empty():
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
        focus_mode = Control.FOCUS_ALL
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
        elif event.is_action_pressed("ui_accept"):
            pressed.emit()
            accept_event()

    func _draw() -> void:
        var bg := Color(0.2, 0.17, 0.1, 0.9) if hover else Color(0.12, 0.1, 0.08, 0.9)
        draw_rect(Rect2(Vector2.ZERO, size), bg)
        draw_rect(Rect2(Vector2.ZERO, size), Color("#ffd23f") if busy else Color("#6b5a40"), false, 1.0)
        draw_texture(icon, (size - Vector2(icon.get_size())) * 0.5)
