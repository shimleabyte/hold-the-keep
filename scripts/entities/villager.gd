extends Node2D
## Villager dengan job. Mesin state sederhana:
## IDLE -> TO_WORK -> WORKING -> TO_DEPOT -> (kembali TO_WORK)
## Malam: non-prajurit lari ke keep dan bersembunyi; prajurit bertarung.
## Origin node = kaki (untuk Y-sort).

const SpriteAnim := preload("res://scripts/entities/sprite_anim.gd")
const Corpse := preload("res://scripts/entities/corpse.gd")
const ArcherCombat := preload("res://scripts/entities/villager_archer_combat.gd")
const ScoutBehavior := preload("res://scripts/entities/villager_scout_behavior.gd")
const HealerBehavior := preload("res://scripts/entities/villager_healer_behavior.gd")
const BlacksmithBehavior := preload("res://scripts/entities/villager_blacksmith_behavior.gd")
const BuilderBehavior := preload("res://scripts/entities/villager_builder_behavior.gd")

enum State { IDLE, TO_WORK, WORKING, TO_DEPOT, FLEEING, HIDDEN, FIGHT, EXPEDITION, RECALLING, SCOUTING, SCOUT_RETURNING }

const TEXTURES := {
    "": preload("res://assets/sprites/villager_idle.svg"),
    "woodcutter": preload("res://assets/sprites/villager_woodcutter.svg"),
    "miner": preload("res://assets/sprites/villager_miner.svg"),
    "farmer": preload("res://assets/sprites/villager_farmer.svg"),
    "builder": preload("res://assets/sprites/villager_builder.svg"),
    "hunter": preload("res://assets/sprites/villager_hunter.svg"),
    "scout": preload("res://assets/sprites/villager_scout.svg"),
    "healer": preload("res://assets/sprites/villager_healer.svg"),
    "blacksmith": preload("res://assets/sprites/villager_blacksmith.svg"),
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
const ARCHER_SEARCH := 260.0
const OUTPOST_GUARD_RADIUS := 128.0
const OUTPOST_GUARD_ARRIVAL_RADIUS := 45.0
const REACH := 11.0
const DEFAULT_WORK_RADIUS := 12.0
const MAX_WORK_PATH_CHECKS := 8
const TARGET_RETRY_COOLDOWN := 6.0
const BUILDER_REPAIR_INTERVAL := 1.6
const BUILDER_REPAIR_AMOUNT := 12
const HEAL_INTERVAL := 3.2
const HEAL_AMOUNT := 10
const SMITH_WORK_SECONDS := 4.5
const BLACKSMITH_WEAPON_COST := {"iron": 3, "wood": 1}
const BLACKSMITH_ARMOR_COST := {"iron": 4, "wood": 2}
const SCOUT_REVEAL_RADIUS := 144.0
const SCOUT_MAX_PATH_CELLS := 64
const SCOUT_SURVEY_SECONDS := 1.4
const SCOUT_RECHECK_SECONDS := 5.0
const SCOUT_SEARCH_RADII: Array[int] = [20, 16, 12, 8]
const SCOUT_DIRECTIONS: Array[Vector2i] = [
    Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
    Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)
]

var occupation := ""
var military_specialization := ""
var job: String:
    get:
        return "soldier" if not military_specialization.is_empty() else occupation
    set(value):
        if value in ["soldier", "archer"]:
            military_specialization = value
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
var guard_outpost = null
var _guard_repath_t := 0.0

var _depot = null
var _path := PackedVector2Array()
var _pi := 0
var _path_ver := -1
var _goal_cells: Array[Vector2i] = []
var _blocked_targets: Dictionary = {}
var _blocked_nav_version := -1
var work_ai_status := "UNASSIGNED"
var work_ai_detail := ""
var _decide_t := 0.0
var _work_t := 0.0
var _wander_t := 2.0
var _atk_cd := 0.0
var _scan_t := 0.0
var _repath_t := 0.0
var _foe = null
var anim := SpriteAnim.new()
var _archer_combat := ArcherCombat.new()
var _scout_behavior = ScoutBehavior.new()
var _healer_behavior = HealerBehavior.new()
var _blacksmith_behavior = BlacksmithBehavior.new()
var _builder_behavior = BuilderBehavior.new()
var _hurt_t := 0.0
var _pending_foe = null
var _pending_t := 0.0
var _hit_done := false
var _running := false
var _rally_t := 0.0
var _rally_damage_mult := 1.0
var _rally_interval_mult := 1.0
var _scout_target_cell := Vector2i(-1, -1)
var _scout_cursor := 0
var _scout_survey_t := 0.0
var _scout_revealed_at_target := false
var weapon_equipped := false
var armor_equipped := false
var _smith_recipe := ""


func _ready() -> void:
    _scout_behavior.configure(self)
    _healer_behavior.configure(self)
    _blacksmith_behavior.configure(self)
    _builder_behavior.configure(self)
    add_to_group("villagers")
    Events.tech_researched.connect(_on_tech)
    _decide_t = randf_range(0.0, 1.0)
    _blocked_nav_version = nav.version if nav != null else -1


## Stat dinamis dari teknologi.
func _carry_cap() -> int:
    return roundi(Tech.stat("villager.carry", float(CARRY_CAP)))


func _hit_interval() -> float:
    return HIT_INTERVAL / Tech.stat("villager.gather_speed", 1.0)


func _soldier_damage() -> int:
    var value := Tech.stat("soldier.damage", float(SOLDIER_DAMAGE))
    if weapon_equipped:
        value *= 1.2
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
    if j != "soldier":
        return WORKER_HP
    var value := Tech.stat("soldier.hp", float(SOLDIER_HP))
    if armor_equipped:
        value *= 1.2
    return roundi(value)


func equip_weapon() -> bool:
    if job != "soldier" or weapon_equipped:
        return false
    weapon_equipped = true
    queue_redraw()
    return true


func equip_armor() -> bool:
    if job != "soldier" or armor_equipped:
        return false
    var old_max := maxi(1, max_hp)
    armor_equipped = true
    max_hp = _hp_cap_for(job)
    hp = clampi(roundi(float(hp) * float(max_hp) / float(old_max)), 1, max_hp)
    queue_redraw()
    return true


func _blacksmith_recipe_for(soldier: Variant) -> String:
    if not is_instance_valid(soldier) or String(soldier.job) != "soldier" or int(soldier.hp) <= 0:
        return ""
    if Tech.is_done("iron_weapons") and not bool(soldier.weapon_equipped):
        return "weapon"
    if Tech.is_done("iron_armor") and not bool(soldier.armor_equipped):
        return "armor"
    return ""


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


func set_job(j: String, preferred_workplace = null) -> bool:
    if j == "archer" and is_archer():
        return true
    if j == "soldier" and job == "soldier" and not is_archer():
        return true
    if j != "archer" and j != "soldier" and j == job:
        return true
    release_outpost_guard()
    _release()
    _release_workplace()
    _expeditioning = false
    _expedition_target = null
    _scout_target_cell = Vector2i(-1, -1)
    _scout_survey_t = 0.0
    _scout_revealed_at_target = false
    var old_max := max_hp
    if job == "soldier" and not ["soldier", "archer"].has(j):
        weapon_equipped = false
        armor_equipped = false
    job = j
    if j == "archer" and not _claim_workplace("archer", preferred_workplace):
        job = "soldier"
        add_to_group("defenders")
        max_hp = _hp_cap_for("soldier")
        hp = clampi(roundi(float(hp) * max_hp / maxi(1, old_max)), 1, max_hp)
        state = State.IDLE
        queue_redraw()
        return false
    if job in ["builder", "hunter", "scout", "healer", "blacksmith"] and not _claim_workplace(job):
        job = ""
        remove_from_group("defenders")
        max_hp = _hp_cap_for("")
        hp = clampi(roundi(float(hp) * max_hp / maxi(1, old_max)), 1, max_hp)
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
    _blocked_targets.clear()
    work_ai_status = "IDLE_READY" if not job.is_empty() else "UNASSIGNED"
    work_ai_detail = ""
    if state != State.HIDDEN and state != State.FLEEING:
        state = State.IDLE
        _path = PackedVector2Array()
        _pi = 0
    queue_redraw()
    return true

func has_valid_workplace() -> bool:
    var expected_job := "archer" if is_archer() else job
    return workplace != null and is_instance_valid(workplace) and workplace_job == expected_job


func is_archer() -> bool:
    return job == "soldier" and military_specialization == "archer"


func _claim_workplace(work_job: String, preferred_workplace = null) -> bool:
    var best = null
    var best_path_length := INF
    for candidate in get_tree().get_nodes_in_group("buildings"):
        if preferred_workplace != null and candidate != preferred_workplace:
            continue
        if not candidate.has_method("free_slots") or candidate.free_slots(work_job) <= 0:
            continue
        var cells: Array[Vector2i] = candidate.cells()
        var path: PackedVector2Array = nav.path_adjacent(position, cells)
        if path.is_empty() and (work_job != "archer" or position.distance_to(candidate.position) > OUTPOST_GUARD_ARRIVAL_RADIUS):
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
    var was_archer := is_archer() and workplace_job == "archer"
    _release()
    workplace = null
    workplace_job = ""
    _scout_target_cell = Vector2i(-1, -1)
    _scout_survey_t = 0.0
    _scout_revealed_at_target = false
    if was_archer:
        military_specialization = "soldier"
        add_to_group("defenders")
        max_hp = _hp_cap_for("soldier")
        hp = clampi(hp, 1, max_hp)
        _path = PackedVector2Array()
        _pi = 0
        if _expeditioning and is_instance_valid(_expedition_target):
            state = State.EXPEDITION
        elif state != State.HIDDEN and state != State.FLEEING:
            state = State.IDLE
        queue_redraw()
        return
    if job == "scout":
        _path = PackedVector2Array()
        _pi = 0
        _decide_t = SCOUT_RECHECK_SECONDS
    state = State.IDLE

func on_repair_target_lost(building) -> void:
    if target == building:
        _release()
        state = State.IDLE


func on_construction_site_lost(site) -> void:
    if target != site:
        return
    target = null
    _work_t = 0.0
    _hit_done = false
    _path = PackedVector2Array()
    _pi = 0
    state = State.IDLE


## Dipanggil pohon/batu saat dipukul oleh villager ini.
func receive(kind: String, amount: int) -> void:
    if carry_kind != kind:
        carry = 0
    carry_kind = kind
    carry += amount
    queue_redraw()


func heal(amount: int) -> int:
    if hp <= 0 or amount <= 0 or hp >= max_hp:
        return 0
    var restored := mini(amount, max_hp - hp)
    hp += restored
    queue_redraw()
    modulate = Color(0.72, 1.15, 0.78)
    create_tween().tween_property(self, "modulate", Color.WHITE, 0.35)
    return restored


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
    release_outpost_guard()
    _release()
    _release_workplace()
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
    _tick_blocked_targets(delta)

    if state == State.HIDDEN:
        if not GameClock.is_night:
            visible = true
            state = State.IDLE
        return

    if GameClock.is_night and job != "soldier" and state != State.FLEEING:
        _begin_flee()

    if nav.version != _path_ver and (state == State.TO_WORK or state == State.TO_DEPOT or state == State.FLEEING or state == State.EXPEDITION or state == State.RECALLING or state == State.SCOUTING or state == State.SCOUT_RETURNING or (state == State.IDLE and is_outpost_guard())):
        _repath()

    match state:
        State.IDLE:
            _tick_idle(delta)
        State.TO_WORK:
            if target == null or not is_instance_valid(target):
                _release()
                state = State.IDLE
                _decide_t = 0.15
            elif job == "healer" and (String(target.job) != "soldier"
                    or int(target.hp) <= 0 or int(target.hp) >= int(target.max_hp)
                    or target.is_expeditioning() or target.is_recalling_expedition()
                    or target.state in [State.HIDDEN, State.FLEEING]
                    or not _is_in_workplace_radius(target)):
                _release()
                state = State.IDLE
                _decide_t = 0.15
            elif job == "blacksmith" and (not has_valid_workplace()
                    or String(target.job) != "soldier" or _blacksmith_recipe_for(target) == ""
                    or target.is_expeditioning() or target.is_recalling_expedition()
                    or target.state in [State.HIDDEN, State.FLEEING, State.FIGHT]
                    or not _is_in_workplace_radius(target)):
                _release()
                state = State.IDLE
                _decide_t = 0.2
            elif _move_along(delta):
                state = State.WORKING
                _work_t = 0.0
                _hit_done = false
                if job == "builder" and target.has_method("is_construction_site") and target.is_construction_site():
                    target.worker_arrived(self)
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
        State.SCOUTING:
            _tick_scouting(delta)
        State.SCOUT_RETURNING:
            if _move_along(delta):
                _scout_target_cell = Vector2i(-1, -1)
                state = State.IDLE
                _decide_t = SCOUT_RECHECK_SECONDS
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
        State.RECALLING, State.SCOUTING, State.SCOUT_RETURNING:
            moving = _pi < _path.size()
            _running = state == State.RECALLING or state == State.SCOUT_RETURNING
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
        if job in ["woodcutter", "miner", "builder", "blacksmith", "farmer"]:
            anim.work_style = job
        if job == "farmer":
            anim.speed_scale = 1.0
            var farm_motion_cycle := FARM_CYCLE / 10.0
            anim.manual_progress = fposmod(_work_t, farm_motion_cycle) / farm_motion_cycle
        elif job == "blacksmith":
            anim.speed_scale = 1.0
            var forge_motion_cycle := SMITH_WORK_SECONDS / 3.0
            anim.manual_progress = fposmod(_work_t, forge_motion_cycle) / forge_motion_cycle
        elif job == "builder":
            anim.speed_scale = 1.0
            anim.manual_progress = fposmod(_work_t, BUILDER_REPAIR_INTERVAL) / BUILDER_REPAIR_INTERVAL
        else:
            anim.speed_scale = 1.0
            anim.manual_progress = fposmod(_work_t, _hit_interval()) / _hit_interval()
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
    if job == "soldier" and is_outpost_guard():
        _tick_outpost_guard(delta)
        return
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


func _facility_sabotaged(facility: Variant) -> bool:
    if facility == null or not is_instance_valid(facility):
        return false
    return facility.has_method("is_sabotaged") and bool(facility.is_sabotaged())


func _tick_working(delta: float) -> void:
    if _facility_sabotaged(target) or _facility_sabotaged(workplace):
        if job == "blacksmith" and _facility_sabotaged(workplace):
            _release()
            state = State.IDLE
            _decide_t = 1.0
        anim.play("idle")
        return
    if target == null or not is_instance_valid(target):
        _release()
        state = State.IDLE
        _decide_t = 0.15
        return
    if job == "blacksmith":
        _blacksmith_behavior.tick(delta)
        return
    if job == "healer":
        _healer_behavior.tick(delta)
        return
    if job == "builder":
        _builder_behavior.tick(delta)
        return
    if job == "farmer":
        anim.face(target.position - position)
        _work_t += delta
        if _work_t >= FARM_CYCLE:
            _work_t = 0.0
            Events.fx_burst.emit("food", target.global_position + Vector2(0, -6), Vector2.UP, 0.65)
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


func is_unavailable_for_blacksmithing() -> bool:
    return state in [State.HIDDEN, State.FLEEING, State.FIGHT]


func is_unavailable_for_healing() -> bool:
    return state in [State.HIDDEN, State.FLEEING]


func is_expeditioning() -> bool:
    return _expeditioning


func is_recalling_expedition() -> bool:
    return state == State.RECALLING


func is_outpost_guard() -> bool:
    return guard_outpost != null and is_instance_valid(guard_outpost)


func assign_outpost_guard(outpost) -> bool:
    return assign_garrison_guard(outpost)


func assign_garrison_guard(garrison) -> bool:
    if job != "soldier" or is_archer() or not is_instance_valid(garrison) or int(garrison.guard_capacity) <= 0:
        return false
    if _expeditioning or state == State.RECALLING:
        return false
    if is_outpost_guard():
        return guard_outpost == garrison
    if not garrison.has_method("claim_guard"):
        return false

    var cells: Array[Vector2i] = garrison.cells()
    var path: PackedVector2Array = nav.path_adjacent(position, cells)
    if path.is_empty() and position.distance_to(garrison.position) > OUTPOST_GUARD_ARRIVAL_RADIUS:
        return false
    if not garrison.claim_guard(self):
        return false

    guard_outpost = garrison
    _expeditioning = false
    _expedition_target = null
    _foe = null
    _pending_foe = null
    _pending_t = 0.0
    _goal_cells = cells
    _path = PackedVector2Array()
    _pi = 0
    if not path.is_empty():
        _set_path(path)
    _guard_repath_t = 0.0
    _scan_t = 0.0
    state = State.IDLE
    queue_redraw()
    return true


func release_outpost_guard() -> void:
    var previous = guard_outpost
    guard_outpost = null
    if previous != null and is_instance_valid(previous):
        previous.release_guard(self)
    _foe = null
    _pending_foe = null
    _pending_t = 0.0
    _path = PackedVector2Array()
    _pi = 0
    _guard_repath_t = 0.0
    if job == "soldier" and state != State.HIDDEN and state != State.FLEEING:
        state = State.IDLE
    queue_redraw()


func on_guard_outpost_lost(outpost) -> void:
    if guard_outpost != outpost:
        return
    guard_outpost = null
    _foe = null
    _pending_foe = null
    _pending_t = 0.0
    _path = PackedVector2Array()
    _pi = 0
    _guard_repath_t = 0.0
    if job == "soldier" and state != State.HIDDEN and state != State.FLEEING:
        state = State.IDLE
    queue_redraw()


func _tick_outpost_guard(delta: float) -> void:
    if not is_outpost_guard() or int(guard_outpost.guard_capacity) <= 0 or int(guard_outpost.hp) <= 0:
        if guard_outpost != null:
            on_guard_outpost_lost(guard_outpost)
        return

    if nav.version != _path_ver:
        _path = PackedVector2Array()
        _pi = 0
        _path_ver = nav.version
        _guard_repath_t = 0.0

    if position.distance_to(guard_outpost.position) > OUTPOST_GUARD_ARRIVAL_RADIUS:
        if _pi < _path.size():
            _move_along(delta)
            return
        _guard_repath_t -= delta
        if _guard_repath_t <= 0.0:
            _guard_repath_t = 1.0
            _goal_cells = guard_outpost.cells()
            var path: PackedVector2Array = nav.path_adjacent(position, _goal_cells)
            if not path.is_empty():
                _set_path(path)
                _move_along(delta)
        return

    _path = PackedVector2Array()
    _pi = 0
    _scan_t -= delta
    if _scan_t <= 0.0:
        _scan_t = 0.3
        _foe = _nearest_enemy()
        if _foe != null:
            state = State.FIGHT
            _path = PackedVector2Array()
            _pi = 0


func start_expedition(stronghold) -> bool:
    if job != "soldier" or is_outpost_guard() or not is_instance_valid(stronghold):
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
        if is_outpost_guard():
            _path = PackedVector2Array()
            _pi = 0
            _guard_repath_t = 0.0
            state = State.IDLE
        else:
            state = State.EXPEDITION if _expeditioning and is_instance_valid(_expedition_target) else State.IDLE
        return
    var dist := position.distance_to(_foe.position)
    if _archer_combat.tick(self, _foe, delta):
        return
    if not is_archer() and dist < REACH:
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
    if nav.version != _blocked_nav_version:
        _blocked_targets.clear()
        _blocked_nav_version = nav.version
    if job.is_empty():
        _set_work_status("UNASSIGNED", "No occupation is assigned")
        return
    if carry > 0:
        _go_depot()
        return
    if job == "scout":
        _set_work_status("SCOUT_SEARCHING", "Evaluating unexplored cells")
        _find_scout_work()
        return
    _set_work_status("SEARCHING", "Evaluating eligible work targets")
    var cands: Array = []
    match job:
        "woodcutter", "miner":
            if not has_valid_workplace():
                _release_workplace()
                _claim_workplace(job)
            # Once a matching worksite exists, its capacity is authoritative.
            # Keep the old connected-depot radius only when no specialty site exists.
            if not has_valid_workplace() and _has_specialized_workplace(job):
                _set_work_status("WORKPLACE_UNAVAILABLE", "Matching specialist workplaces are full or unreachable")
                return
            var kind := "wood" if job == "woodcutter" else _mine_kind()
            for n in get_tree().get_nodes_in_group("harvestable"):
                var in_work_area := _is_in_workplace_radius(n) if has_valid_workplace() else _is_in_gather_radius(n)
                if n.yield_kind == kind and n.is_available(self) and in_work_area:
                    cands.append(n)
        "hunter":
            if not has_valid_workplace():
                _release_workplace()
                if not _claim_workplace("hunter"):
                    _set_work_status("NO_WORKPLACE", "Hunter requires an available Hunting Lodge")
                    return
            for wildlife in get_tree().get_nodes_in_group("wildlife"):
                if wildlife.yield_kind == "food" and wildlife.is_available(self) \
                        and _is_in_workplace_radius(wildlife):
                    cands.append(wildlife)
        "farmer":
            for f in get_tree().get_nodes_in_group("farms"):
                if f.free_slots("farmer") > 0 and _is_in_work_radius(f):
                    cands.append(f)
        "blacksmith":
            if not has_valid_workplace():
                _release_workplace()
                if not _claim_workplace("blacksmith"):
                    _set_work_status("NO_WORKPLACE", "Blacksmith requires an available Forge")
                    return
            if _facility_sabotaged(workplace):
                _set_work_status("WORKPLACE_SABOTAGED", "Forge is temporarily disabled")
                return
            for soldier in get_tree().get_nodes_in_group("villagers"):
                if soldier == self or not is_instance_valid(soldier) or String(soldier.job) != "soldier":
                    continue
                if _blacksmith_recipe_for(soldier) == "" or soldier.is_expeditioning() \
                        or soldier.is_recalling_expedition() or soldier.state in [State.HIDDEN, State.FLEEING, State.FIGHT]:
                    continue
                if not _is_in_workplace_radius(soldier) or workplace.is_blacksmith_target_reserved(soldier, self):
                    continue
                cands.append(soldier)
        "healer":
            if not has_valid_workplace():
                _release_workplace()
                if not _claim_workplace("healer"):
                    _set_work_status("NO_WORKPLACE", "Healer requires an available Infirmary")
                    return
            for patient in get_tree().get_nodes_in_group("villagers"):
                if patient == self or not is_instance_valid(patient) or String(patient.job) != "soldier":
                    continue
                if int(patient.hp) <= 0 or int(patient.hp) >= int(patient.max_hp):
                    continue
                if patient.is_expeditioning() or patient.is_recalling_expedition() \
                        or patient.state in [State.HIDDEN, State.FLEEING]:
                    continue
                if not _is_in_workplace_radius(patient) or workplace.is_heal_target_reserved(patient, self):
                    continue
                cands.append(patient)
        "builder":
            if not has_valid_workplace():
                _release_workplace()
                if not _claim_workplace("builder"):
                    _set_work_status("NO_WORKPLACE", "Builder requires an available Keep or Outpost slot")
                    return
            var radius := float(workplace.data.get("work_radius", DEFAULT_WORK_RADIUS)) * WorldConfig.tile_size
            var construction_sites: Array = get_tree().get_nodes_in_group("construction_sites")
            construction_sites.sort_custom(func(a, b) -> bool:
                return int(a.queue_order) < int(b.queue_order)
            )
            for site in construction_sites:
                if site.has_method("can_claim") and site.can_claim(self) \
                        and _is_builder_site_in_range(site):
                    cands.append(site)
            for building in get_tree().get_nodes_in_group("buildings"):
                if building.hp <= 0 or building.hp >= building.max_hp:
                    continue
                if workplace.position.distance_squared_to(building.position) > radius * radius:
                    continue
                if building.can_assign_repairer(self):
                    cands.append(building)
    cands.sort_custom(func(a, b) -> bool:
        var a_is_site: bool = a.has_method("is_construction_site") and a.is_construction_site()
        var b_is_site: bool = b.has_method("is_construction_site") and b.is_construction_site()
        if job == "healer":
            var a_ratio := float(a.hp) / float(maxi(1, a.max_hp))
            var b_ratio := float(b.hp) / float(maxi(1, b.max_hp))
            if not is_equal_approx(a_ratio, b_ratio):
                return a_ratio < b_ratio
        if a_is_site != b_is_site:
            return a_is_site
        if a_is_site and b_is_site and int(a.queue_order) != int(b.queue_order):
            return int(a.queue_order) < int(b.queue_order)
        return a.position.distance_squared_to(position) < b.position.distance_squared_to(position)
    )
    var reachable_candidates: Array[Dictionary] = []
    var checked_candidates := 0
    var blocked_candidates := 0
    var unreachable_candidates := 0
    var candidate_index := 0
    while candidate_index < cands.size() and checked_candidates < MAX_WORK_PATH_CHECKS:
        var candidate = cands[candidate_index]
        candidate_index += 1
        if _is_target_blocked(candidate):
            blocked_candidates += 1
            continue
        checked_candidates += 1
        var candidate_cells := _cells_of(candidate)
        var candidate_path: PackedVector2Array = nav.path_adjacent(position, candidate_cells)
        if candidate_path.is_empty():
            unreachable_candidates += 1
            _mark_target_blocked(candidate, "NO_PATH")
            continue
        reachable_candidates.append({
            "target": candidate,
            "cells": candidate_cells,
            "path": candidate_path
        })

    # Preserve Builder queue order and Healer urgency. Other jobs compare actual
    # A* route lengths among a bounded candidate set instead of straight distance.
    if job not in ["builder", "healer"]:
        reachable_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
            var path_a: PackedVector2Array = a["path"]
            var path_b: PackedVector2Array = b["path"]
            return path_a.size() < path_b.size()
        )

    for route in reachable_candidates:
        var n = route["target"]
        var cells: Array[Vector2i] = route["cells"]
        var p: PackedVector2Array = route["path"]
        if job == "builder":
            if n.has_method("is_construction_site") and n.is_construction_site():
                if not n.claim(self):
                    continue
            elif not n.claim_repairer(self):
                continue
        elif job == "healer":
            if not workplace.claim_heal_target(self, n):
                continue
        elif job == "blacksmith":
            if not workplace.claim_blacksmith_target(self, n):
                continue
            _smith_recipe = _blacksmith_recipe_for(n)
            if _smith_recipe == "":
                workplace.release_blacksmith_target(self)
                continue
        elif not _claim(n):
            continue
        target = n
        _goal_cells = cells
        _set_path(p)
        state = State.TO_WORK
        _set_work_status("MOVING_TO_WORK", "Following the shortest valid route to an eligible target")
        return

    if cands.is_empty():
        _set_work_status("NO_AVAILABLE_TARGET", "No eligible target is available inside the assigned work area")
    elif reachable_candidates.is_empty():
        if blocked_candidates > 0 and unreachable_candidates == 0:
            _set_work_status("TARGET_RETRY_COOLDOWN", "Recent path failures are cooling down before another attempt")
        else:
            _set_work_status("NO_REACHABLE_TARGET", "Nearby targets exist, but no tested path is reachable")
    else:
        _set_work_status("TARGET_RESERVED", "Reachable targets were claimed by another worker")


func _set_work_status(status: String, detail: String = "") -> void:
    work_ai_status = status
    work_ai_detail = detail


func _is_target_blocked(candidate: Variant) -> bool:
    if candidate == null or not is_instance_valid(candidate):
        return false
    return _blocked_targets.has(candidate.get_instance_id())


func _mark_target_blocked(candidate: Variant, reason: String) -> void:
    if candidate == null or not is_instance_valid(candidate):
        return
    _blocked_targets[candidate.get_instance_id()] = {
        "remaining": TARGET_RETRY_COOLDOWN,
        "reason": reason
    }


func _tick_blocked_targets(delta: float) -> void:
    if nav == null:
        return
    if nav.version != _blocked_nav_version:
        _blocked_targets.clear()
        _blocked_nav_version = nav.version
        return
    for target_id in _blocked_targets.keys():
        var record: Dictionary = _blocked_targets[target_id]
        var remaining := maxf(0.0, float(record.get("remaining", 0.0)) - delta)
        if remaining <= 0.0 or not is_instance_valid(instance_from_id(int(target_id))):
            _blocked_targets.erase(target_id)
        else:
            record["remaining"] = remaining
            _blocked_targets[target_id] = record


func worker_ai_diagnostics() -> Dictionary:
    var target_label := ""
    if target != null and is_instance_valid(target):
        target_label = String(target.name)
    var workplace_label := ""
    if workplace != null and is_instance_valid(workplace):
        workplace_label = String(workplace.id)
    return {
        "job": job,
        "state": String(State.keys()[state]),
        "status": work_ai_status,
        "detail": work_ai_detail,
        "target": target_label,
        "workplace": workplace_label,
        "carry_kind": carry_kind,
        "carry": carry,
        "remaining_path_points": maxi(0, _path.size() - _pi),
        "temporarily_blocked_targets": _blocked_targets.size()
    }


func _find_scout_work() -> void:
    _scout_behavior.find_work()


func _scout_target_reserved(cell: Vector2i) -> bool:
    return _scout_behavior.target_reserved(cell)


func _tick_scouting(delta: float) -> void:
    _scout_behavior.tick(delta)


func _return_to_scout_post() -> void:
    _scout_behavior.return_to_post()


## Public bridge used by VillagerScoutBehavior; movement and private state stay host-owned.
func scout_behavior_cursor() -> int:
    return _scout_cursor


func scout_behavior_reserved_cell() -> Vector2i:
    return _scout_target_cell


func scout_behavior_start_survey(cell: Vector2i, direction_index: int, path: PackedVector2Array) -> void:
    _scout_target_cell = cell
    _scout_cursor = (direction_index + 1) % SCOUT_DIRECTIONS.size()
    _scout_survey_t = 0.0
    _scout_revealed_at_target = false
    _goal_cells = [cell]
    _set_path(path)
    state = State.SCOUTING


func scout_behavior_reset_survey() -> void:
    _scout_target_cell = Vector2i(-1, -1)
    _scout_survey_t = 0.0
    _scout_revealed_at_target = false


func scout_behavior_repath_if_needed() -> bool:
    if nav.version != _path_ver:
        _repath()
    return state == State.SCOUTING


func scout_behavior_has_arrived() -> bool:
    return _pi >= _path.size()


func scout_behavior_move(delta: float) -> void:
    _move_along(delta)


func scout_behavior_is_revealed() -> bool:
    return _scout_revealed_at_target


func scout_behavior_mark_revealed() -> void:
    _scout_revealed_at_target = true


func scout_behavior_advance_survey(delta: float) -> bool:
    _scout_survey_t += delta
    return _scout_survey_t >= SCOUT_SURVEY_SECONDS


func scout_behavior_finish_survey() -> void:
    scout_behavior_reset_survey()
    scout_behavior_wait_for_scout()


func scout_behavior_wait_for_scout() -> void:
    state = State.IDLE
    _decide_t = SCOUT_RECHECK_SECONDS


func scout_behavior_set_return_path(cells: Array[Vector2i], path: PackedVector2Array) -> void:
    _goal_cells = cells
    _set_path(path)
    state = State.SCOUT_RETURNING


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
    if job == "healer":
        _release_heal_target()
    elif job == "blacksmith":
        _release_blacksmith_target()
    elif target != null and is_instance_valid(target):
        if target.has_method("release_repairer") and job == "builder":
            target.release_repairer(self)
        elif target.has_method("release"):
            target.release(self)
        elif target.get("worker") == self:
            target.worker = null
    target = null
    _work_t = 0.0
    _hit_done = false


## Public bridge for the healer component to release its host-owned work claim.
func healer_behavior_release(recheck_delay: float) -> void:
    _release()
    state = State.IDLE
    _decide_t = recheck_delay


## Public bridge for blacksmith policy; Villager owns the recipe claim and work timer.
func blacksmith_behavior_recipe_for(soldier: Variant) -> String:
    return _blacksmith_recipe_for(soldier)


func blacksmith_behavior_assigned_recipe() -> String:
    return _smith_recipe


func blacksmith_behavior_advance_work(delta: float) -> bool:
    var previous_work_t := _work_t
    _work_t += delta
    var strike_interval := SMITH_WORK_SECONDS / 3.0
    var previous_strikes := floori(previous_work_t / strike_interval)
    var current_strikes := floori(_work_t / strike_interval)
    if workplace != null and is_instance_valid(workplace):
        for strike in range(previous_strikes, current_strikes):
            Events.fx_burst.emit("spark", workplace.global_position + Vector2(0, -7), Vector2.UP, 0.65)
    return _work_t >= SMITH_WORK_SECONDS


func blacksmith_behavior_release(recheck_delay: float) -> void:
    _release()
    state = State.IDLE
    _decide_t = recheck_delay


func builder_behavior_advance_construction(delta: float) -> bool:
    _work_t += delta
    if _work_t < BUILDER_REPAIR_INTERVAL:
        return false
    _work_t = fposmod(_work_t, BUILDER_REPAIR_INTERVAL)
    return true


func builder_behavior_advance_work(delta: float) -> bool:
    _work_t += delta
    if _work_t < BUILDER_REPAIR_INTERVAL:
        return false
    _work_t = 0.0
    return true


func builder_behavior_release(reason: String = "IDLE") -> void:
    _release()
    state = State.IDLE
    _decide_t = 0.5
    _set_work_status(reason, "Builder released the previous task and will re-evaluate work")


func _release_heal_target() -> void:
    if workplace != null and is_instance_valid(workplace) and workplace.has_method("release_heal_target"):
        workplace.release_heal_target(self)


func _release_blacksmith_target() -> void:
    if workplace != null and is_instance_valid(workplace) and workplace.has_method("release_blacksmith_target"):
        workplace.release_blacksmith_target(self)
    _smith_recipe = ""


func _has_specialized_workplace(job_name: String) -> bool:
    for building in get_tree().get_nodes_in_group("buildings"):
        if not is_instance_valid(building) or int(building.hp) <= 0:
            continue
        var workplaces: Dictionary = building.data.get("workplaces", {})
        if workplaces.has(job_name):
            return true
    return false


func _is_in_workplace_radius(candidate) -> bool:
    if not has_valid_workplace():
        return false
    var radius := float(workplace.data.get("work_radius", DEFAULT_WORK_RADIUS)) * WorldConfig.tile_size
    return workplace.position.distance_squared_to(candidate.position) <= radius * radius


## Frontier deliberately keeps its starting clearing free of resources. Let the
## initial Keep depot reach the resource ring; specialist worksite radii remain
## authoritative once a Lumber Camp or Quarry has been assigned.
func _is_in_gather_radius(candidate) -> bool:
    var supply = get_tree().get_first_node_in_group("supply_network")
    for depot in get_tree().get_nodes_in_group("depots"):
        if supply != null and not supply.is_depot_connected(depot):
            continue
        var radius := float(depot.data.get("work_radius", DEFAULT_WORK_RADIUS))
        if WorldConfig.is_frontier_profile() and String(depot.id) == "keep":
            var clearing_radius := maxf(
                WorldConfig.safe_radius + 7.0,
                float(WorldConfig.map_size) * 0.15
            )
            radius = maxf(radius, clearing_radius + 4.0)
        radius *= WorldConfig.tile_size
        if depot.position.distance_squared_to(candidate.position) <= radius * radius:
            return true
    return false


## Frontier builders can reach construction sites just beyond their depot's
## claim edge. Repairs remain restricted to the workplace's normal work radius.
func _is_builder_site_in_range(site) -> bool:
    if not has_valid_workplace():
        return false
    var radius := float(workplace.data.get("work_radius", DEFAULT_WORK_RADIUS))
    if WorldConfig.is_frontier_profile():
        var fallback_claim_radius := WorldConfig.starting_claim_radius if String(workplace.id) == "keep" else 0.0
        var claim_radius := float(workplace.data.get("claim_radius", fallback_claim_radius))
        if claim_radius > 0.0:
            radius = maxf(radius, claim_radius + 2.0)
    radius *= WorldConfig.tile_size
    return workplace.position.distance_squared_to(site.position) <= radius * radius


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
    var best_priority := 2
    var best_path_length := INF
    var best_path := PackedVector2Array()
    var supply = get_tree().get_first_node_in_group("supply_network")
    for depot in get_tree().get_nodes_in_group("depots"):
        if supply != null and not supply.is_depot_connected(depot):
            continue
        if depot.id == "granary" and carry_kind != "food":
            continue
        if depot.id == "granary" and carry > 0 and not depot.can_store_resource(carry_kind, carry):
            continue
        if WorldConfig.is_frontier_profile() and carry > 0 and depot.id != "keep":
            if not depot.can_store_resource(carry_kind, carry):
                continue
        var path: PackedVector2Array = nav.path_adjacent(position, depot.cells())
        if path.is_empty():
            continue
        var priority := 0 if carry_kind == "food" and depot.id == "granary" else 1
        if priority < best_priority or (priority == best_priority and float(path.size()) < best_path_length):
            best_priority = priority
            best_path_length = float(path.size())
            _depot = depot
            best_path = path
    if _depot == null:
        state = State.IDLE
        _decide_t = 4.0
        _set_work_status("NO_REACHABLE_DEPOT", "Cargo is retained; no connected depot has a valid path or capacity")
        return
    _goal_cells = _depot.cells()
    _set_path(best_path)
    state = State.TO_DEPOT
    _set_work_status("DELIVERING", "Carrying %d %s to %s" % [carry, carry_kind, String(_depot.id)])


func _deposit() -> void:
    if carry > 0 and carry_kind != "":
        var supply = get_tree().get_first_node_in_group("supply_network")
        if _depot == null or not is_instance_valid(_depot):
            _depot = null
            _go_depot()
            return
        if supply != null and not supply.is_depot_connected(_depot):
            _depot = null
            _go_depot()
            return
        if _depot.id == "granary":
            if not _depot.store_resource(carry_kind, carry):
                _depot = null
                _go_depot()
                return
        elif WorldConfig.is_frontier_profile() and _depot.id != "keep":
            if not _depot.store_resource(carry_kind, carry):
                _depot = null
                _go_depot()
                return
        else:
            Inventory.add(carry_kind, carry)
    carry = 0
    carry_kind = ""
    queue_redraw()


func _return_to_work() -> void:
    if target == null or not is_instance_valid(target):
        target = null
        state = State.IDLE
        _set_work_status("TARGET_LOST", "Previous target no longer exists after delivery")
        return
    if target.has_method("is_available") and not target.is_available(self):
        _release()
        state = State.IDLE
        _decide_t = 0.25
        _set_work_status("TARGET_UNAVAILABLE", "Previous target is no longer available")
        return
    _goal_cells = _cells_of(target)
    var p: PackedVector2Array = nav.path_adjacent(position, _goal_cells)
    if p.is_empty():
        _mark_target_blocked(target, "RETURN_ROUTE_BLOCKED")
        _release()
        state = State.IDLE
        _decide_t = 0.25
        _set_work_status("RETURN_ROUTE_BLOCKED", "Could not route back to previous target; selecting another")
        return
    _set_path(p)
    state = State.TO_WORK
    _set_work_status("RETURNING_TO_WORK", "Returning to previous target after delivery")


# ---------------------------------------------------------------- malam

func _find_keep():
    for d in get_tree().get_nodes_in_group("depots"):
        if d.id == "keep":
            return d
    return null


func _begin_flee() -> void:
    _release()
    _scout_target_cell = Vector2i(-1, -1)
    _scout_survey_t = 0.0
    _scout_revealed_at_target = false
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
    var best_d := ARCHER_SEARCH if is_archer() else SOLDIER_SEARCH
    var candidates := get_tree().get_nodes_in_group("enemy_garrison") if _expeditioning else get_tree().get_nodes_in_group("enemies")
    for e in candidates:
        var enemy := e as Node2D
        if is_outpost_guard() and enemy.position.distance_to(guard_outpost.position) > float(guard_outpost.data.get("guard_radius", OUTPOST_GUARD_RADIUS)):
            continue
        var d := position.distance_to(enemy.position)
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
    var p: PackedVector2Array
    if state == State.SCOUTING:
        p = nav.path_to(position, _scout_target_cell)
    elif state == State.SCOUT_RETURNING and has_valid_workplace():
        p = nav.path_adjacent(position, workplace.cells())
    else:
        p = nav.path_adjacent(position, _goal_cells)
    if p.is_empty():
        match state:
            State.FLEEING:
                _hide()
            State.TO_WORK:
                _mark_target_blocked(target, "PATH_BLOCKED")
                _release()
                state = State.IDLE
                _decide_t = 0.25
                _set_work_status("PATH_BLOCKED", "Navigation changed and the assigned target is no longer reachable")
            State.EXPEDITION, State.RECALLING:
                _expeditioning = false
                _expedition_target = null
                state = State.IDLE
                Events.build_feedback.emit("Prajurit tidak menemukan jalur pulang")
            State.SCOUTING, State.SCOUT_RETURNING:
                _scout_target_cell = Vector2i(-1, -1)
                _scout_survey_t = 0.0
                state = State.IDLE
                _decide_t = SCOUT_RECHECK_SECONDS
            _:
                state = State.IDLE
                _set_work_status("PATH_BLOCKED", "Current navigation goal became unreachable")
        return
    _set_path(p)


## true jika sudah sampai di ujung jalur.
func _move_along(delta: float) -> bool:
    if _pi >= _path.size():
        return true
    var tgt := _path[_pi]
    var to := tgt - position
    var d := to.length()
    var fast := state == State.FLEEING or state == State.EXPEDITION or state == State.RECALLING or state == State.SCOUT_RETURNING or (state == State.FIGHT and _foe != null and is_instance_valid(_foe) and position.distance_to(_foe.position) > RUN_DISTANCE)
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
        "hunter":
            return Color("#b77c43")
        "scout":
            return Color("#b7a37b")
        "soldier":
            return Color("#3f6fb5")
    return Color("#d9d2c3")


func _draw() -> void:
    anim.draw(self, TEXTURES.get(job, TEXTURES[""]), FW, FH)
    if is_archer():
        draw_arc(Vector2(7, -9), 7.0, -PI * 0.45, PI * 0.45, 12, Color("#a9824d"), 1.6)
        draw_line(Vector2(2, -14), Vector2(2, -4), Color("#d4bd8e"), 0.7)
        draw_line(Vector2(2, -9), Vector2(10, -9), Color("#c7a36e"), 0.8)
        draw_line(Vector2(-6, -14), Vector2(-4, -18), Color("#87603b"), 1.4)
    if job == "soldier" and armor_equipped:
        draw_rect(Rect2(-3, -13, 6, 5), Color("#64727b"))
        draw_rect(Rect2(-2, -12, 4, 3), Color("#c0c6c2"))
        draw_rect(Rect2(-4, -10, 1, 3), Color("#8e9aa0"))
        draw_rect(Rect2(3, -10, 1, 3), Color("#8e9aa0"))
    if job == "soldier" and weapon_equipped and not is_archer():
        draw_line(Vector2(6, -8), Vector2(10, -15), Color("#d6dde0"), 1.5)
        draw_line(Vector2(5, -9), Vector2(8, -8), Color("#c58a42"), 1.5)
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
