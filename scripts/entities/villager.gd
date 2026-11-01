extends Node2D
## Villager dengan job. Mesin state sederhana:
## IDLE -> TO_WORK -> WORKING -> TO_DEPOT -> (kembali TO_WORK)
## Malam: non-prajurit lari ke keep dan bersembunyi; prajurit bertarung.
## Origin node = kaki (untuk Y-sort).

const SpriteAnim := preload("res://scripts/entities/sprite_anim.gd")
const Corpse := preload("res://scripts/entities/corpse.gd")

enum State { IDLE, TO_WORK, WORKING, TO_DEPOT, FLEEING, HIDDEN, FIGHT, EXPEDITION, RECALLING }

const TEXTURES := {
    "": preload("res://assets/sprites/villager_idle.svg"),
    "woodcutter": preload("res://assets/sprites/villager_woodcutter.svg"),
    "miner": preload("res://assets/sprites/villager_miner.svg"),
    "farmer": preload("res://assets/sprites/villager_farmer.svg"),
    "builder": preload("res://assets/sprites/villager_miner.svg"),
    "soldier": preload("res://assets/sprites/villager_soldier.svg"),
}

const FW := 20
const FH := 20
const SPEED := 42.0
const RUN_SPEED := 66.0
const RUN_DISTANCE := 70.0  # prajurit berlari jika musuh lebih jauh dari ini
const ATTACK_HIT_DELAY := 0.14
const HURT_TIME := 0.2
const CARRY_CAP := 6
const HIT_INTERVAL := 1.2
const FARM_CYCLE := 12.0
const FARM_YIELD := 3
const SOLDIER_HP := 60
const WORKER_HP := 20
const SOLDIER_DAMAGE := 8
const SOLDIER_INTERVAL := 0.8
const SOLDIER_SEARCH := 300.0
const REACH := 11.0
const DEFAULT_WORK_RADIUS := 12.0
const BUILDER_REPAIR_INTERVAL := 1.6
const BUILDER_REPAIR_AMOUNT := 12

var occupation := ""
var military_specialization := ""
var job: String:
    get:
        return military_specialization if not military_specialization.is_empty() else occupation
    set(value):
        if value == "soldier":
            military_specialization = "soldier"
            occupation = ""
        else:
            occupation = value
            military_specialization = ""
var workplace = null
var workplace_job := ""
var state := State.IDLE
var carry_kind := ""
var carry := 0
var hp := WORKER_HP
var max_hp := WORKER_HP
var nav
var world
var target = null
var _expedition_target = null
var _expeditioning := false

var _depot = null
var _path := PackedVector2Array()
var _pi := 0
var _path_ver := -1
var _goal_cells: Array[Vector2i] = []
var _bad: Array = []
var _decide_t := 0.0
var _work_t := 0.0
var _wander_t := 2.0
var _atk_cd := 0.0
var _scan_t := 0.0
var _repath_t := 0.0
var _foe = null
var anim := SpriteAnim.new()
var _hurt_t := 0.0
var _pending_foe = null
var _pending_t := 0.0
var _hit_done := false
var _running := false
var _rally_t := 0.0
var _rally_damage_mult := 1.0
var _rally_interval_mult := 1.0


func _ready() -> void:
    add_to_group("villagers")
    Events.tech_researched.connect(_on_tech)
    _decide_t = randf_range(0.0, 1.0)


## Stat dinamis dari teknologi.
func _carry_cap() -> int:
    return roundi(Tech.stat("villager.carry", float(CARRY_CAP)))


func _hit_interval() -> float:
    return HIT_INTERVAL / Tech.stat("villager.gather_speed", 1.0)


func _soldier_damage() -> int:
    var value := Tech.stat("soldier.damage", float(SOLDIER_DAMAGE))
    if _rally_t > 0.0:
        value *= _rally_damage_mult
    return roundi(value)


func _soldier_attack_interval() -> float:
    return SOLDIER_INTERVAL * (_rally_interval_mult if _rally_t > 0.0 else 1.0)


func apply_rally(duration: float, damage_multiplier: float, interval_multiplier: float) -> void:
    if job != "soldier":
        return
    _rally_t = maxf(_rally_t, duration)
    _rally_damage_mult = maxf(_rally_damage_mult, damage_multiplier)
    _rally_interval_mult = minf(_rally_interval_mult, interval_multiplier)
    Events.fx_burst.emit("rally", position + Vector2(0, -8), Vector2.ZERO, 0.7)


func _hp_cap_for(j: String) -> int:
    return roundi(Tech.stat("soldier.hp", float(SOLDIER_HP))) if j == "soldier" else WORKER_HP


func _on_tech(_tech_id: String) -> void:
    var old := max_hp
    max_hp = _hp_cap_for(job)
    if max_hp != old:
        hp = clampi(roundi(float(hp) * max_hp / old), 1, max_hp)
        queue_redraw()


## Penambang memilih besi bila stoknya kurang dari separuh batu (dan ada bijih yang bisa ditambang).
func _mine_kind() -> String:
    if Tech.has_flag("iron_mining") and Inventory.get_amount("iron") <= Inventory.get_amount("stone") * 0.5:
        for n in get_tree().get_nodes_in_group("harvestable"):
            if n.yield_kind == "iron":
                return "iron"
    return "stone"


func set_job(j: String) -> bool:
    if j == job:
        return true
    _release()
    _release_workplace()
    _expeditioning = false
    _expedition_target = null
    var old_max := max_hp
    job = j
    if job == "builder" and not _claim_workplace("builder"):
        job = ""
        state = State.IDLE
        return false
    if job == "soldier":
        add_to_group("defenders")
        max_hp = _hp_cap_for(job)
    else:
        remove_from_group("defenders")
        max_hp = _hp_cap_for(job)
    hp = clampi(int(round(float(hp) * max_hp / maxi(1, old_max))), 1, max_hp)
    _work_t = 0.0
    _bad.clear()
    if state != State.HIDDEN and state != State.FLEEING:
        state = State.IDLE
        _path = PackedVector2Array()
        _pi = 0
    queue_redraw()
    return true


func has_valid_workplace() -> bool:
    return workplace != null and is_instance_valid(workplace) and workplace_job == job


func _claim_workplace(work_job: String) -> bool:
    var best = null
    var best_path_length := INF
    for candidate in get_tree().get_nodes_in_group("buildings"):
        if not candidate.has_method("free_slots") or candidate.free_slots(work_job) <= 0:
            continue
        var cells: Array[Vector2i] = candidate.cells()
        var path: PackedVector2Array = nav.path_adjacent(position, cells)
        if path.is_empty():
            continue
        if float(path.size()) < best_path_length:
            best_path_length = float(path.size())
            best = candidate
    if best == null or not best.claim(self, work_job):
        return false
    workplace = best
    workplace_job = work_job
    return true


func _release_workplace() -> void:
    if workplace != null and is_instance_valid(workplace):
        workplace.release(self)
    workplace = null
    workplace_job = ""


func on_workplace_lost(building) -> void:
    if workplace != building:
        return
    workplace = null
    workplace_job = ""
    _release()
    state = State.IDLE


func on_repair_target_lost(building) -> void:
    if target == building:
        _release()
        state = State.IDLE


## Dipanggil pohon/batu saat dipukul oleh villager ini.
func receive(kind: String, amount: int) -> void:
    if carry_kind != kind:
        carry = 0
    carry_kind = kind
    carry += amount
    queue_redraw()


func take_damage(amount: int) -> void:
    if hp <= 0:
        return
    hp -= amount
    Events.fx_burst.emit("hurt", position + Vector2(0, -8), Vector2.ZERO, 1.0)
    modulate = Color(1.7, 0.6, 0.6)
    create_tween().tween_property(self, "modulate", Color.WHITE, 0.2)
    queue_redraw()
    if hp <= 0:
        Events.villager_died.emit()
        Corpse.spawn(get_parent(), TEXTURES.get(job, TEXTURES[""]), FW, FH, anim.view, anim.flip, position)
        leave()
    elif not (anim.clip == "attack" and not anim.finished):
        _hurt_t = HURT_TIME


func leave() -> void:
    _release()
    remove_from_group("villagers")
    remove_from_group("defenders")
    queue_free()


# ---------------------------------------------------------------- loop

func _physics_process(delta: float) -> void:
    _atk_cd = maxf(0.0, _atk_cd - delta)
    _hurt_t = maxf(0.0, _hurt_t - delta)
    _rally_t = maxf(0.0, _rally_t - delta)
    if _rally_t <= 0.0:
        _rally_damage_mult = 1.0
        _rally_interval_mult = 1.0
    _resolve_pending(delta)

    if state == State.HIDDEN:
        if not GameClock.is_night:
            visible = true
            state = State.IDLE
        return

    if GameClock.is_night and job != "soldier" and state != State.FLEEING:
        _begin_flee()

    if nav.version != _path_ver and (state == State.TO_WORK or state == State.TO_DEPOT or state == State.FLEEING or state == State.EXPEDITION or state == State.RECALLING):
        _repath()

    match state:
        State.IDLE:
            _tick_idle(delta)
        State.TO_WORK:
            if target == null or not is_instance_valid(target):
                target = null
                state = State.IDLE
            elif _move_along(delta):
                state = State.WORKING
                _work_t = 0.0
                _hit_done = false
        State.WORKING:
            _tick_working(delta)
        State.TO_DEPOT:
            if _depot == null or not is_instance_valid(_depot):
                _go_depot()
            elif _move_along(delta):
                _deposit()
                _return_to_work()
        State.FLEEING:
            if _move_along(delta):
                _hide()
        State.FIGHT:
            _tick_fight(delta)
        State.EXPEDITION:
            _tick_expedition(delta)
        State.RECALLING:
            if _move_along(delta):
                state = State.IDLE
                _scan_t = 0.0
                _wander_t = 2.0
    _update_anim(delta)


## Pilih klip animasi dari state. Kerja penebang/penambang disinkronkan dengan timer pukulan.
func _update_anim(delta: float) -> void:
    var moving := false
    _running = false
    match state:
        State.TO_WORK, State.TO_DEPOT:
            moving = true
        State.EXPEDITION:
            moving = _pi < _path.size()
            _running = _expedition_target != null and is_instance_valid(_expedition_target) and position.distance_to(_expedition_target.position) > RUN_DISTANCE
        State.RECALLING:
            moving = _pi < _path.size()
            _running = true
        State.FLEEING:
            moving = true
            _running = true
        State.IDLE:
            moving = _pi < _path.size()
        State.FIGHT:
            if _foe != null and is_instance_valid(_foe):
                var dist := position.distance_to(_foe.position)
                moving = dist >= REACH
                _running = dist > RUN_DISTANCE
    anim.manual_progress = -1.0
    if anim.clip == "attack" and not anim.finished:
        pass  # biarkan tebasan selesai
    elif _hurt_t > 0.0:
        anim.play("hurt")
    elif state == State.WORKING:
        anim.play("work")
        if job == "farmer":
            anim.speed_scale = 0.5
        else:
            anim.manual_progress = _work_t / _hit_interval()
    elif moving:
        anim.play("run" if _running else "walk")
        anim.speed_scale = 1.0
    else:
        anim.play("idle")
        anim.speed_scale = 1.0
    if anim.update(delta):
        queue_redraw()


func _resolve_pending(delta: float) -> void:
    if _pending_foe == null:
        return
    _pending_t -= delta
    if _pending_t > 0.0:
        return
    var f = _pending_foe
    _pending_foe = null
    if is_instance_valid(f):
        f.take_damage(_soldier_damage())


func _tick_idle(delta: float) -> void:
    if _pi < _path.size():
        _move_along(delta)
    if job == "soldier":
        _scan_t -= delta
        if _scan_t <= 0.0:
            _scan_t = 0.3
            _foe = _nearest_enemy()
            if _foe != null:
                state = State.FIGHT
                _path = PackedVector2Array()
                _pi = 0
                return
    elif job != "":
        _decide_t -= delta
        if _decide_t <= 0.0:
            _decide_t = 1.5
            _find_work()
            return
    if _pi >= _path.size():
        _wander_t -= delta
        if _wander_t <= 0.0:
            _wander()


func _tick_working(delta: float) -> void:
    if target == null or not is_instance_valid(target):
        target = null
        state = State.IDLE
        return
    if job == "builder":
        if int(target.hp) <= 0 or int(target.hp) >= int(target.max_hp):
            _release()
            state = State.IDLE
            return
        anim.face(target.position - position)
        _work_t += delta
        if _work_t >= BUILDER_REPAIR_INTERVAL:
            _work_t = 0.0
            if not target.repair(BUILDER_REPAIR_AMOUNT):
                _release()
                state = State.IDLE
                return
            if int(target.hp) >= int(target.max_hp):
                _release()
                state = State.IDLE
        return
    if job == "farmer":
        anim.face(target.position - position)
        _work_t += delta
        if _work_t >= FARM_CYCLE:
            _work_t = 0.0
            receive("food", roundi(Tech.stat("farm.yield", float(FARM_YIELD))))
            if carry >= _carry_cap():
                _go_depot()
        return
    if not target.is_available(self):
        if carry > 0:
            _go_depot()
        else:
            _release()
            state = State.IDLE
        return
    anim.face(target.position - position)
    _work_t += delta
    if not _hit_done and _work_t >= _hit_interval() * 0.5:
        _hit_done = true  # frame benturan: alat mengenai sasaran
        target.hit(self)
        if carry >= _carry_cap() or not target.is_available(self):
            _hit_done = false
            _work_t = 0.0
            if carry > 0:
                _go_depot()
            else:
                _release()
                state = State.IDLE
            return
    if _work_t >= _hit_interval():
        _work_t = 0.0
        _hit_done = false


func is_expeditioning() -> bool:
    return _expeditioning


func is_recalling_expedition() -> bool:
    return state == State.RECALLING


func start_expedition(stronghold) -> bool:
    if job != "soldier" or not is_instance_valid(stronghold):
        return false
    _release()
    _foe = null
    _pending_foe = null
    _expedition_target = stronghold
    _expeditioning = true
    state = State.EXPEDITION
    _goal_cells = stronghold.cells()
    _repath_t = 0.0
    if not _plan_expedition_path():
        recall_expedition()
        return false
    return true


func recall_expedition() -> void:
    _expeditioning = false
    _expedition_target = null
    _foe = null
    _pending_foe = null
    var keep = _find_keep()
    if keep == null:
        _path = PackedVector2Array()
        _pi = 0
        state = State.IDLE
        return
    _goal_cells = keep.cells()
    var path: PackedVector2Array = nav.path_adjacent(position, _goal_cells)
    if path.is_empty():
        _path = PackedVector2Array()
        _pi = 0
        state = State.IDLE
        return
    _set_path(path)
    state = State.RECALLING


func _plan_expedition_path() -> bool:
    if not _expeditioning or not is_instance_valid(_expedition_target):
        return false
    _goal_cells = _expedition_target.cells()
    var path: PackedVector2Array = nav.path_adjacent(position, _goal_cells)
    if path.is_empty():
        return false
    _set_path(path)
    return true


func _tick_expedition(delta: float) -> void:
    if not _expeditioning or not is_instance_valid(_expedition_target):
        recall_expedition()
        return
    _scan_t -= delta
    if _scan_t <= 0.0:
        _scan_t = 0.3
        _foe = _nearest_enemy()
    if _foe != null and is_instance_valid(_foe):
        state = State.FIGHT
        _tick_fight(delta)
        return

    var distance := position.distance_to(_expedition_target.position)
    if distance <= 42.0:
        if anim.face(_expedition_target.position - position):
            queue_redraw()
        if _atk_cd <= 0.0:
            _atk_cd = _soldier_attack_interval()
            _pending_foe = _expedition_target
            _pending_t = ATTACK_HIT_DELAY
            anim.play("attack", true)
        return

    _repath_t -= delta
    if _repath_t <= 0.0:
        _repath_t = 1.0
        if _pi >= _path.size():
            _plan_expedition_path()
    if _pi < _path.size():
        _move_along(delta)


func _tick_fight(delta: float) -> void:
    _scan_t -= delta
    if _scan_t <= 0.0:
        _scan_t = 0.3
        _foe = _nearest_enemy()
    if _foe == null or not is_instance_valid(_foe):
        _foe = null
        state = State.EXPEDITION if _expeditioning and is_instance_valid(_expedition_target) else State.IDLE
        return
    var dist := position.distance_to(_foe.position)
    if dist < REACH:
        if anim.face(_foe.position - position):
            queue_redraw()
        if _atk_cd <= 0.0:
            _atk_cd = _soldier_attack_interval()
            _pending_foe = _foe
            _pending_t = ATTACK_HIT_DELAY
            anim.play("attack", true)
        return
    _repath_t -= delta
    if _repath_t <= 0.0:
        _repath_t = 0.5
        var p: PackedVector2Array = nav.path_to(position, nav.cell_of(_foe.position))
        if not p.is_empty():
            _set_path(p)
    if _pi < _path.size():
        _move_along(delta)
    else:
        position += (_foe.position - position).normalized() * (RUN_SPEED if dist > RUN_DISTANCE else SPEED) * delta


# ---------------------------------------------------------------- jobs

func _find_work() -> void:
    if carry > 0:
        _go_depot()
        return
    var cands: Array = []
    match job:
        "woodcutter", "miner":
            var kind := "wood" if job == "woodcutter" else _mine_kind()
            for n in get_tree().get_nodes_in_group("harvestable"):
                if n.yield_kind == kind and n.is_available(self) and _is_in_work_radius(n) and not _bad.has(n):
                    cands.append(n)
        "farmer":
            for f in get_tree().get_nodes_in_group("farms"):
                if f.free_slots("farmer") > 0 and _is_in_work_radius(f) and not _bad.has(f):
                    cands.append(f)
        "builder":
            if not has_valid_workplace():
                _release_workplace()
                if not _claim_workplace("builder"):
                    return
            var radius := float(workplace.data.get("work_radius", DEFAULT_WORK_RADIUS)) * WorldConfig.tile_size
            for building in get_tree().get_nodes_in_group("buildings"):
                if building.hp <= 0 or building.hp >= building.max_hp or _bad.has(building):
                    continue
                if workplace.position.distance_squared_to(building.position) > radius * radius:
                    continue
                if building.can_assign_repairer(self):
                    cands.append(building)
    cands.sort_custom(func(a, b) -> bool: return a.position.distance_squared_to(position) < b.position.distance_squared_to(position))
    for i in mini(8, cands.size()):
        var n = cands[i]
        var cells := _cells_of(n)
        var p: PackedVector2Array = nav.path_adjacent(position, cells)
        if p.is_empty():
            _bad.append(n)
            continue
        if job == "builder":
            if not n.claim_repairer(self):
                continue
        elif not _claim(n):
            continue
        target = n
        _goal_cells = cells
        _set_path(p)
        state = State.TO_WORK
        return
    _bad.clear()


func _cells_of(n) -> Array[Vector2i]:
    if n.has_method("cells"):
        return n.cells()
    var out: Array[Vector2i] = [nav.cell_of(n.position + Vector2(0, -1))]
    return out


func _claim(n) -> bool:
    if n.has_method("claim"):
        return n.claim(self, "farmer") if job == "farmer" else n.claim(self)
    n.worker = self
    return true


func _release() -> void:
    if target != null and is_instance_valid(target):
        if target.has_method("release_repairer") and job == "builder":
            target.release_repairer(self)
        elif target.has_method("release"):
            target.release(self)
        elif target.get("worker") == self:
            target.worker = null
    target = null
    _work_t = 0.0
    _hit_done = false


func _is_in_work_radius(candidate) -> bool:
    var supply = get_tree().get_first_node_in_group("supply_network")
    for depot in get_tree().get_nodes_in_group("depots"):
        if supply != null and not supply.is_depot_connected(depot):
            continue
        var radius := float(depot.data.get("work_radius", DEFAULT_WORK_RADIUS)) * WorldConfig.tile_size
        if depot.position.distance_squared_to(candidate.position) <= radius * radius:
            return true
    return false


func _go_depot() -> void:
    _depot = null
    var best_path_length := INF
    var best_path := PackedVector2Array()
    var supply = get_tree().get_first_node_in_group("supply_network")
    for depot in get_tree().get_nodes_in_group("depots"):
        if supply != null and not supply.is_depot_connected(depot):
            continue
        var path: PackedVector2Array = nav.path_adjacent(position, depot.cells())
        if path.is_empty():
            continue
        if float(path.size()) < best_path_length:
            best_path_length = float(path.size())
            _depot = depot
            best_path = path
    if _depot == null:
        state = State.IDLE
        return
    _goal_cells = _depot.cells()
    _set_path(best_path)
    state = State.TO_DEPOT


func _deposit() -> void:
    if carry > 0 and carry_kind != "":
        var supply = get_tree().get_first_node_in_group("supply_network")
        if supply != null and _depot != null and is_instance_valid(_depot) and not supply.is_depot_connected(_depot):
            _depot = null
            _go_depot()
            return
        Inventory.add(carry_kind, carry)
    carry = 0
    carry_kind = ""
    queue_redraw()


func _return_to_work() -> void:
    if target == null or not is_instance_valid(target):
        target = null
        state = State.IDLE
        return
    if target.has_method("is_available") and not target.is_available(self):
        _release()
        state = State.IDLE
        return
    _goal_cells = _cells_of(target)
    var p: PackedVector2Array = nav.path_adjacent(position, _goal_cells)
    if p.is_empty():
        _release()
        state = State.IDLE
        return
    _set_path(p)
    state = State.TO_WORK


# ---------------------------------------------------------------- malam

func _find_keep():
    for d in get_tree().get_nodes_in_group("depots"):
        if d.id == "keep":
            return d
    return null


func _begin_flee() -> void:
    _release()
    var keep = _find_keep()
    state = State.FLEEING
    if keep == null:
        _hide()
        return
    _goal_cells = keep.cells()
    var p: PackedVector2Array = nav.path_adjacent(position, _goal_cells)
    if p.is_empty():
        _hide()
    else:
        _set_path(p)


func _hide() -> void:
    _deposit()
    visible = false
    state = State.HIDDEN


func _nearest_enemy():
    var best = null
    var best_d := SOLDIER_SEARCH
    var candidates := get_tree().get_nodes_in_group("enemy_garrison") if _expeditioning else get_tree().get_nodes_in_group("enemies")
    for e in candidates:
        var d := position.distance_to((e as Node2D).position)
        if d < best_d:
            best_d = d
            best = e
    return best


# ---------------------------------------------------------------- gerak

func _wander() -> void:
    _wander_t = randf_range(3.0, 8.0)
    var keep = _find_keep()
    if keep == null:
        return
    var c: Vector2i = keep.cell + Vector2i(1, 3) + Vector2i(randi_range(-3, 3), randi_range(-1, 2))
    if not nav.is_walkable(c):
        return
    var p: PackedVector2Array = nav.path_to(position, c)
    if not p.is_empty():
        _set_path(p)


func _set_path(p: PackedVector2Array) -> void:
    _path = p
    _pi = 1 if p.size() > 1 else 0
    _path_ver = nav.version


func _repath() -> void:
    var p: PackedVector2Array = nav.path_adjacent(position, _goal_cells)
    if p.is_empty():
        match state:
            State.FLEEING:
                _hide()
            State.TO_WORK:
                _release()
                state = State.IDLE
            State.EXPEDITION, State.RECALLING:
                _expeditioning = false
                _expedition_target = null
                state = State.IDLE
                Events.build_feedback.emit("Prajurit tidak menemukan jalur pulang")
            _:
                state = State.IDLE
        return
    _set_path(p)


## true jika sudah sampai di ujung jalur.
func _move_along(delta: float) -> bool:
    if _pi >= _path.size():
        return true
    var tgt := _path[_pi]
    var to := tgt - position
    var d := to.length()
    var fast := state == State.FLEEING or state == State.EXPEDITION or state == State.RECALLING or (state == State.FIGHT and _foe != null and is_instance_valid(_foe) and position.distance_to(_foe.position) > RUN_DISTANCE)
    var step := (RUN_SPEED if fast else SPEED) * delta
    if not anim.is_busy() and anim.face(to):
        queue_redraw()
    if d <= step:
        position = tgt
        _pi += 1
        return _pi >= _path.size()
    position += to / d * step
    return false


# ---------------------------------------------------------------- gambar

func _job_color() -> Color:
    match job:
        "woodcutter":
            return Color("#4e9a4a")
        "miner":
            return Color("#8a8f98")
        "farmer":
            return Color("#d6b13c")
        "soldier":
            return Color("#3f6fb5")
    return Color("#d9d2c3")


func _draw() -> void:
    anim.draw(self, TEXTURES.get(job, TEXTURES[""]), FW, FH)
    if job == "builder":
        draw_rect(Rect2(8, -13, 2, 6), Color("#704b2a"))
        draw_rect(Rect2(7, -15, 5, 2), Color("#aeb5bf"))
        draw_rect(Rect2(9, -16, 3, 2), Color("#d5dbe3"))
    if carry > 0:
        var cc := Color("#a8743a")
        if carry_kind == "stone":
            cc = Color("#aeb3b9")
        elif carry_kind == "iron":
            cc = Color("#c97b3a")
        elif carry_kind == "food":
            cc = Color("#e8c23a")
        draw_rect(Rect2(-7, -8, 3, 3), cc)
        draw_rect(Rect2(-7, -8, 3, 1), cc.lightened(0.3))
    if hp < max_hp:
        draw_rect(Rect2(-5, -20, 10, 2), Color(0, 0, 0, 0.7))
        draw_rect(Rect2(-5, -20, 10.0 * float(maxi(hp, 0)) / max_hp, 2), Color("#6fcf5a"))
