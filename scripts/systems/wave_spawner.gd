extends Node
## Gelombang musuh tiap malam. Jumlah dan komposisi dari data/waves.json.

const MAP_SIZE := 64
const TILE := 16
const ENEMY_SCRIPT := preload("res://scripts/entities/enemy.gd")
const SPAWN_WINDOW := 0.6  # bagian malam di mana musuh muncul

var world
var flow
var player

var _to_spawn := 0
var _interval := 1.0
var _timer := 0.0
var _pool: Array = []
var _boss_pending := false
var _boss_t := 0.0


func _ready() -> void:
    Events.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(is_night: bool) -> void:
    if is_night:
        start_wave(GameClock.day)
    else:
        end_wave()


func wave_size(day: int) -> int:
    var cfg := DataDB.waves
    return mini(int(cfg["base"]) + int(cfg["per_day"]) * (day - 1), int(cfg["max"]))


func _pool_for(day: int) -> Array:
    var out: Array = []
    for t in DataDB.waves["types"]:
        if int(t["from_day"]) <= day:
            out.append(t)
    return out


func export_state() -> Dictionary:
    return {"to_spawn": _to_spawn, "interval": _interval, "timer": _timer, "boss": _boss_pending, "boss_t": _boss_t}


func import_state(d: Dictionary) -> void:
    _to_spawn = int(d.get("to_spawn", 0))
    _interval = float(d.get("interval", 1.0))
    _timer = float(d.get("timer", 0.0))
    _boss_pending = bool(d.get("boss", false))
    _boss_t = float(d.get("boss_t", 0.0))
    _pool = _pool_for(GameClock.day)


func restore_enemy(d: Dictionary) -> void:
    if not DataDB.enemies.has(d["id"]):
        return
    var e := ENEMY_SCRIPT.new()
    if bool(d.get("garrison", false)):
        var origin := Vector2(float(d.get("guard_x", d["x"])), float(d.get("guard_y", d["y"])))
        e.setup_guard(DataDB.enemies[d["id"]], world, flow, player, origin)
    else:
        e.setup(DataDB.enemies[d["id"]], world, flow, player)
    e.position = Vector2(float(d["x"]), float(d["y"]))
    e.hp = int(d["hp"])
    world.entities.add_child(e)


func start_wave(day: int) -> void:
    _pool = _pool_for(day)
    var count := wave_size(day)
    _to_spawn = count
    _timer = 0.0
    var night_secs := (GameClock.NIGHT_END - GameClock.NIGHT_START) * GameClock.DAY_LENGTH
    _interval = maxf(0.1, night_secs * SPAWN_WINDOW / count)
    Events.wave_started.emit(day, count)
    if day == int(DataDB.waves.get("final_day", 0)):
        _boss_pending = true
        _boss_t = 4.0
        Events.build_feedback.emit("Malam terakhir! Raja lawan datang bersama %d prajurit" % count)
    else:
        Events.build_feedback.emit("Malam tiba! %d musuh menyerang" % count)


func end_wave() -> void:
    _to_spawn = 0
    var left: Array = []
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if not enemy.is_garrison:
            left.append(enemy)
    for enemy in left:
        enemy.retreat()
    if left.size() > 0:
        Events.build_feedback.emit("Fajar tiba, musuh mundur")
    else:
        Events.build_feedback.emit("Fajar tiba. Semua musuh terkalahkan!")


func _process(delta: float) -> void:
    if _boss_pending:
        _boss_t -= delta
        if _boss_t <= 0.0:
            if spawn_one(String(DataDB.waves.get("boss", "king"))):
                _boss_pending = false
            else:
                _boss_t = 1.0
    if _to_spawn <= 0:
        return
    _timer += delta
    while _timer >= _interval and _to_spawn > 0:
        _timer -= _interval
        if spawn_one():
            _to_spawn -= 1
        else:
            break


func spawn_one(forced_type := "") -> bool:
    if _pool.is_empty() and forced_type == "":
        return false
    var cell := _pick_edge_cell()
    if cell.x < 0:
        return false
    var data: Dictionary = DataDB.enemies[forced_type if forced_type != "" else _pick_type()]
    var e := ENEMY_SCRIPT.new()
    e.setup(data, world, flow, player)
    e.position = Vector2(cell) * TILE + Vector2(TILE / 2.0, TILE / 2.0)
    world.entities.add_child(e)
    return true


func _pick_type() -> String:
    var total := 0
    for t in _pool:
        total += int(t["weight"])
    var r := randi() % total
    for t in _pool:
        r -= int(t["weight"])
        if r < 0:
            return t["id"]
    return _pool[0]["id"]


func _pick_edge_cell() -> Vector2i:
    for i in 30:
        var side := randi() % 4
        var t := randi_range(1, MAP_SIZE - 2)
        var c := Vector2i.ZERO
        match side:
            0: c = Vector2i(t, 1)
            1: c = Vector2i(t, MAP_SIZE - 2)
            2: c = Vector2i(1, t)
            _: c = Vector2i(MAP_SIZE - 2, t)
        if world.is_buildable(c) and not world.occupied.has(c) and flow.is_reachable(c):
            return c
    return Vector2i(-1, -1)
