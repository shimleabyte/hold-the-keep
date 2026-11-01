extends Node2D
## Enemy roles: melee raider, pouncing wolf, ranged archer, armored siege brute.
## Normal raiders follow the flow field; garrison units defend their stronghold radius.

const SpriteAnim := preload("res://scripts/entities/sprite_anim.gd")
const Corpse := preload("res://scripts/entities/corpse.gd")
const ENEMY_BOLT := preload("res://scripts/entities/enemy_bolt.gd")
const ENEMY_TARGETING := preload("res://scripts/systems/enemy_targeting.gd")
const ENEMY_SUPPORT := preload("res://scripts/systems/enemy_support.gd")
const TEXTURES := {
    "bandit": preload("res://assets/sprites/enemy_bandit.svg"),
    "wolf": preload("res://assets/sprites/enemy_wolf.svg"),
    "soldier": preload("res://assets/sprites/enemy_soldier.svg"),
    "archer": preload("res://assets/sprites/enemy_bandit.svg"),
    "brute": preload("res://assets/sprites/enemy_soldier.svg"),
    "king": preload("res://assets/sprites/enemy_king.svg"),
}
const PLAYER_REACH := 12.0
const ATTACK_HIT_DELAY := 0.14
const SHIELD_TARGET_RANGE := 96.0
const SCOUT_FOCUS_RANGE := 220.0
const WALK_BASE_SPEED := 32.0
const RUN_BASE_SPEED := 58.0

var id := ""
var hp := 10
var max_hp := 10
var speed := 30.0
var damage := 5
var attack_interval := 1.0
var color := Color.RED
var scale_f := 1.0
var is_boss := false
var runs := false
var is_garrison := false
var is_supply_raider := false
var raid_target_cell := Vector2i(-1, -1)
var supply_raid_hits := 0
var raid_nav
var _raid_path := PackedVector2Array()
var _raid_path_index := 0
var _raid_path_version := -1
var _raid_repath_timer := 0.0
var guard_origin := Vector2.ZERO
var role := "melee"
var archetype := "raider"
var faction_id := ""
var campaign_site_id := ""
var _faction_tint := Color.WHITE
var support_radius := 0.0
var support_amount := 0
var support_interval := 0.0
var _support_cd := 0.0
var attack_range := PLAYER_REACH
var preferred_range := 0.0
var projectile_speed := 120.0
var armor := 0.0
var stagger_resistance := 0.0
var structure_damage_mult := 1.0
var shield_brace_trigger_range := 64.0
var shield_brace_windup_duration := 0.55
var shield_brace_duration := 1.05
var shield_brace_cooldown_duration := 4.2
var shield_brace_damage_multiplier := 0.45
var shield_brace_front_dot := 0.5
var scout_mark_range := 142.0
var scout_preferred_range := 96.0
var scout_windup_duration := 0.68
var scout_mark_duration := 5.4
var scout_mark_cooldown_duration := 8.4
var scout_share_radius := 190.0

var world
var flow
var player
var anim := SpriteAnim.new()

var _offset := Vector2.ZERO
var _atk_cd := 0.0
var _moving := false
var _step_t := 0.0
var _hurt_t := 0.0
var _stagger_t := 0.0
var _pending = null
var _pending_t := 0.0
var _pending_is_projectile := false
var _pounce_windup_t := 0.0
var _pounce_t := 0.0
var _pounce_dir := Vector2.ZERO
var _brace_windup_t := 0.0
var _brace_t := 0.0
var _brace_cd := 0.0
var _brace_dir := Vector2.ZERO
var _scout_windup_t := 0.0
var _scout_windup_target: Node2D
var _scout_mark_target: Node2D
var _scout_mark_t := 0.0
var _scout_mark_cd := 0.0
var _tex: Texture2D
var _fw := 20
var _fh := 20


func setup(data: Dictionary, world_ref, flow_ref, player_ref, faction_override := "") -> void:
    id = data["id"]
    max_hp = int(data["hp"])
    hp = max_hp
    speed = float(data["speed"])
    damage = int(data["damage"])
    attack_interval = float(data["attack_interval"])
    color = Color(data["color"])
    scale_f = float(data.get("scale", 1.0))
    is_boss = bool(data.get("boss", false))
    runs = bool(data.get("run", false))
    role = String(data.get("role", "pouncer" if id == "wolf" else "melee"))
    archetype = String(data.get("archetype", role))
    faction_id = faction_override
    _faction_tint = Color.WHITE
    if not faction_id.is_empty():
        var faction_data: Dictionary = FactionRegistry.faction_for_stronghold(faction_id)
        if not faction_data.is_empty():
            _faction_tint = Color(String(faction_data.get("color", "#ffffff")))
    support_radius = maxf(0.0, float(data.get("support_radius", 0.0)))
    support_amount = maxi(0, int(data.get("support_amount", 0)))
    support_interval = maxf(0.0, float(data.get("support_interval", 0.0)))
    _support_cd = 0.0
    attack_range = float(data.get("range", 30.0 if role == "pouncer" else PLAYER_REACH))
    preferred_range = float(data.get("preferred_range", 0.0))
    projectile_speed = float(data.get("projectile_speed", 120.0))
    armor = clampf(float(data.get("armor", 0.0)), 0.0, 0.8)
    stagger_resistance = clampf(float(data.get("stagger_resistance", 0.0)), 0.0, 0.9)
    structure_damage_mult = maxf(1.0, float(data.get("structure_damage_mult", 1.0)))
    shield_brace_trigger_range = clampf(float(data.get("brace_trigger_range", 64.0)), 24.0, 110.0)
    shield_brace_windup_duration = clampf(float(data.get("brace_windup", 0.55)), 0.2, 1.5)
    shield_brace_duration = clampf(float(data.get("brace_duration", 1.05)), 0.3, 2.0)
    shield_brace_cooldown_duration = clampf(float(data.get("brace_cooldown", 4.2)), 1.0, 12.0)
    shield_brace_damage_multiplier = clampf(float(data.get("brace_damage_multiplier", 0.45)), 0.1, 1.0)
    shield_brace_front_dot = clampf(float(data.get("brace_front_dot", 0.5)), 0.1, 0.95)
    scout_mark_range = clampf(float(data.get("scout_mark_range", 142.0)), 80.0, 190.0)
    scout_preferred_range = clampf(float(data.get("scout_preferred_range", 96.0)), 56.0, 140.0)
    scout_windup_duration = clampf(float(data.get("scout_windup", 0.68)), 0.25, 1.5)
    scout_mark_duration = clampf(float(data.get("scout_mark_duration", 5.4)), 2.5, 10.0)
    scout_mark_cooldown_duration = clampf(float(data.get("scout_mark_cooldown", 8.4)), 4.0, 18.0)
    scout_share_radius = clampf(float(data.get("scout_share_radius", 190.0)), 80.0, 280.0)
    _scout_windup_t = 0.0
    _scout_windup_target = null
    _scout_mark_target = null
    _scout_mark_t = 0.0
    _scout_mark_cd = 0.0
    _brace_windup_t = 0.0
    _brace_t = 0.0
    _brace_cd = 0.0
    _brace_dir = Vector2.ZERO
    world = world_ref
    flow = flow_ref
    player = player_ref
    _offset = Vector2(randf_range(-4.0, 4.0), randf_range(-3.0, 3.0))
    _tex = TEXTURES.get(id, TEXTURES["bandit"])
    _fw = int(_tex.get_width() / float(SpriteAnim.FRAMES))
    _fh = int(_tex.get_height() / 3.0)


func setup_guard(data: Dictionary, world_ref, flow_ref, player_ref, origin: Vector2, faction_override := "") -> void:
    setup(data, world_ref, flow_ref, player_ref, faction_override)
    is_garrison = true
    guard_origin = origin


func _ready() -> void:
    add_to_group("enemies")
    if is_supply_raider:
        add_to_group("supply_raiders")
    if is_garrison:
        add_to_group("enemy_garrison")
    if role == "ranged":
        add_to_group("ranged_enemies")
    anim.view = SpriteAnim.SIDE
    modulate = _faction_tint


func _physics_process(delta: float) -> void:
    _atk_cd = maxf(0.0, _atk_cd - delta)
    _hurt_t = maxf(0.0, _hurt_t - delta)
    _support_cd = maxf(0.0, _support_cd - delta)
    _brace_cd = maxf(0.0, _brace_cd - delta)
    _scout_mark_t = maxf(0.0, _scout_mark_t - delta)
    _scout_mark_cd = maxf(0.0, _scout_mark_cd - delta)
    if _scout_mark_t <= 0.0 or not is_instance_valid(_scout_mark_target):
        _scout_mark_t = 0.0
        _scout_mark_target = null
    _resolve_pending(delta)
    _moving = false

    if _stagger_t > 0.0:
        if archetype == "scout" and _scout_windup_t > 0.0:
            _scout_windup_t = 0.0
            _scout_windup_target = null
            _scout_mark_cd = maxf(_scout_mark_cd, 1.2)
        _stagger_t = maxf(0.0, _stagger_t - delta)
        _update_anim(delta)
        queue_redraw()
        return

    if _pounce_windup_t > 0.0:
        _pounce_windup_t = maxf(0.0, _pounce_windup_t - delta)
        _update_anim(delta)
        return

    if _pounce_t > 0.0:
        _pounce_t = maxf(0.0, _pounce_t - delta)
        position += _pounce_dir * speed * 2.4 * delta
        _moving = true
        _update_anim(delta)
        _footsteps(delta)
        return

    if is_supply_raider:
        _tick_supply_raid(delta)
        _update_anim(delta)
        _footsteps(delta)
        return

    if archetype == "scout":
        _tick_scout(delta)
        _update_anim(delta)
        _footsteps(delta)
        return

    if archetype == "shieldbearer":
        _tick_shieldbearer(delta)
        _update_anim(delta)
        _footsteps(delta)
        return

    if archetype == "war_shaman" and _tick_shaman_support():
        _update_anim(delta)
        _footsteps(delta)
        return

    if role == "ranged":
        _tick_ranged(delta)
        _update_anim(delta)
        _footsteps(delta)
        return

    if _tick_marked_target(delta):
        _update_anim(delta)
        _footsteps(delta)
        return

    if is_garrison:
        _tick_garrison(delta)
        _update_anim(delta)
        _footsteps(delta)
        return

    if player != null and is_instance_valid(player):
        if position.distance_to(player.position) < _attack_reach():
            _begin_attack(player, player.position - position)
            _update_anim(delta)
            return

    for defender in get_tree().get_nodes_in_group("defenders"):
        var target := defender as Node2D
        if target.visible and position.distance_to(target.position) < _attack_reach():
            _begin_attack(target, target.position - position)
            _update_anim(delta)
            return

    _tick_flow(delta)
    _update_anim(delta)
    _footsteps(delta)


func _attack_reach() -> float:
    return maxf(PLAYER_REACH, attack_range)


func setup_supply_raid(target_cell: Vector2i, navigation) -> void:
    is_supply_raider = true
    raid_target_cell = target_cell
    raid_nav = navigation
    _raid_path = PackedVector2Array()
    _raid_path_index = 0
    _raid_path_version = -1
    _raid_repath_timer = 0.0


func _find_raid_depot():
    for depot in get_tree().get_nodes_in_group("depots"):
        if is_instance_valid(depot) and depot.cell == raid_target_cell and ["storage", "outpost"].has(String(depot.id)):
            return depot
    return null


func _tick_supply_raid(delta: float) -> void:
    var depot = _find_raid_depot()
    if depot == null:
        retreat()
        return
    var supply = get_tree().get_first_node_in_group("supply_network")
    if supply == null or supply.is_depot_connected(depot):
        retreat()
        return

    var reach := maxf(_attack_reach(), 28.0)
    if player != null and is_instance_valid(player) and position.distance_to(player.position) <= reach:
        _begin_attack(player, player.position - position)
        return
    for defender in get_tree().get_nodes_in_group("defenders"):
        if not is_instance_valid(defender) or not defender.visible:
            continue
        if position.distance_to(defender.position) <= reach:
            _begin_attack(defender, defender.position - position)
            return
    if position.distance_to(depot.position) <= reach:
        _begin_attack(depot, depot.position - position)
        return

    if raid_nav == null:
        return
    _raid_repath_timer = maxf(0.0, _raid_repath_timer - delta)
    if _raid_path_version != raid_nav.version or _raid_path.is_empty() or _raid_repath_timer <= 0.0:
        var target_cells: Array[Vector2i] = depot.cells()
        _raid_path = raid_nav.path_adjacent(position, target_cells)
        _raid_path_index = 1 if _raid_path.size() > 1 else 0
        _raid_path_version = raid_nav.version
        _raid_repath_timer = 1.0
    while _raid_path_index < _raid_path.size() and position.distance_to(_raid_path[_raid_path_index]) <= 3.0:
        _raid_path_index += 1
    if _raid_path_index < _raid_path.size():
        _move_toward(_raid_path[_raid_path_index], delta)


func _tick_flow(delta: float) -> void:
    var cell := Vector2i((position / WorldConfig.tile_size).floor())
    var next: Vector2i = flow.next_cell(cell)
    if next == cell:
        _move_toward(flow.target_pos, delta)
        return
    var occupied = world.occupied.get(next)
    if occupied != null and is_instance_valid(occupied) and occupied.is_in_group("buildings"):
        if role == "ranged":
            _begin_ranged_attack(occupied as Node2D)
        else:
            _begin_attack(occupied, occupied.position - position)
        return
    _move_toward(Vector2(next) * WorldConfig.tile_size + Vector2(WorldConfig.tile_size / 2.0, WorldConfig.tile_size / 2.0) + _offset, delta)


func _nearest_scout_target() -> Node2D:
    var candidates := get_tree().get_nodes_in_group("defenders")
    if player != null and is_instance_valid(player):
        candidates.append(player)
    return ENEMY_TARGETING.nearest(
        self,
        candidates,
        scout_mark_range,
        guard_origin if is_garrison else Vector2.ZERO,
        175.0 if is_garrison else 0.0
    )


func _tick_scout(delta: float) -> void:
    if _scout_windup_t > 0.0:
        var target := _scout_windup_target
        if target == null or not is_instance_valid(target) or not target.visible or position.distance_to(target.position) > scout_mark_range + 24.0:
            _scout_windup_t = 0.0
            _scout_windup_target = null
            _scout_mark_cd = minf(_scout_mark_cd, 0.8)
            queue_redraw()
        else:
            var direction := target.position - position
            if direction.length_squared() > 0.01:
                anim.face(direction)
            _moving = false
            _scout_windup_t = maxf(0.0, _scout_windup_t - delta)
            if _scout_windup_t <= 0.0:
                _release_scout_mark(target)
            queue_redraw()
            return

    var target: Node2D = null
    if _scout_mark_t > 0.0 and is_instance_valid(_scout_mark_target):
        target = _scout_mark_target
    else:
        target = _nearest_scout_target()

    if target == null:
        if is_garrison:
            if position.distance_to(guard_origin) > 16.0:
                _move_toward(guard_origin, delta)
        else:
            _tick_flow(delta)
        return

    var to_target := target.position - position
    var distance := to_target.length()
    var direction := to_target.normalized() if distance > 0.01 else Vector2.DOWN

    if _scout_mark_t <= 0.0 and _scout_mark_cd <= 0.0 and distance <= scout_mark_range:
        _scout_windup_target = target
        _scout_windup_t = scout_windup_duration
        anim.face(direction)
        Events.fx_burst.emit("dust", position + Vector2(0, -3), -direction, 0.65)
        queue_redraw()
        return

    if distance < scout_preferred_range - 14.0:
        _move_toward(position - direction * 36.0, delta)
    elif distance > scout_preferred_range + 18.0:
        _move_toward(target.position - direction * scout_preferred_range, delta)
    else:
        _moving = false


func _release_scout_mark(target: Node2D) -> void:
    if target == null or not is_instance_valid(target) or not target.visible:
        _scout_windup_t = 0.0
        _scout_windup_target = null
        return
    _scout_windup_t = 0.0
    _scout_windup_target = null
    _scout_mark_target = target
    _scout_mark_t = scout_mark_duration
    _scout_mark_cd = scout_mark_cooldown_duration
    var target_position := target.global_position + Vector2(0, -8)
    Events.fx_burst.emit("rally", target_position, Vector2.ZERO, 1.0)

    for ally in get_tree().get_nodes_in_group("enemies"):
        if ally == self or not is_instance_valid(ally) or not (ally is Node2D):
            continue
        var enemy_ally := ally as Node2D
        if String(enemy_ally.get("faction_id")) != faction_id:
            continue
        if global_position.distance_to(enemy_ally.global_position) > scout_share_radius:
            continue
        if enemy_ally.has_method("apply_scout_mark"):
            enemy_ally.apply_scout_mark(target, scout_mark_duration)
    queue_redraw()


func apply_scout_mark(target: Node2D, duration: float) -> void:
    if target == null or not is_instance_valid(target) or not target.visible or duration <= 0.0:
        return
    if _scout_mark_t > 0.0 and is_instance_valid(_scout_mark_target) and _scout_mark_target != target:
        return
    _scout_mark_target = target
    _scout_mark_t = maxf(_scout_mark_t, minf(duration, 10.0))
    queue_redraw()


func _valid_scout_mark(max_distance: float) -> Node2D:
    if _scout_mark_t <= 0.0 or _scout_mark_target == null or not is_instance_valid(_scout_mark_target):
        return null
    if not _scout_mark_target.visible:
        return null
    if position.distance_to(_scout_mark_target.position) > max_distance:
        return null
    if is_garrison and _scout_mark_target.position.distance_to(guard_origin) > 175.0:
        return null
    return _scout_mark_target


func _tick_marked_target(delta: float) -> bool:
    var target := _valid_scout_mark(SCOUT_FOCUS_RANGE)
    if target == null:
        return false
    var distance := position.distance_to(target.position)
    if distance <= _attack_reach():
        _begin_attack(target, target.position - position)
    else:
        _move_toward(target.position, delta)
    return true


func _nearest_shield_target() -> Node2D:
    var marked := _valid_scout_mark(SHIELD_TARGET_RANGE)
    if marked != null:
        return marked
    if is_garrison:
        return _nearest_guard_target()
    var candidates := get_tree().get_nodes_in_group("defenders")
    if player != null and is_instance_valid(player):
        candidates.append(player)
    return ENEMY_TARGETING.nearest(self, candidates, SHIELD_TARGET_RANGE)


func _tick_shieldbearer(delta: float) -> void:
    if _brace_t > 0.0:
        _brace_t = maxf(0.0, _brace_t - delta)
        _moving = false
        if _brace_t <= 0.0:
            _brace_dir = Vector2.ZERO
        queue_redraw()
        return

    var target := _nearest_shield_target()
    if _brace_windup_t > 0.0:
        if target == null or position.distance_to(target.position) > shield_brace_trigger_range + 24.0:
            _brace_windup_t = 0.0
            _brace_cd = minf(_brace_cd, 0.8)
            _brace_dir = Vector2.ZERO
        else:
            var windup_direction := target.position - position
            if windup_direction.length_squared() > 0.01:
                _brace_dir = windup_direction.normalized()
                anim.face(_brace_dir)
            _brace_windup_t = maxf(0.0, _brace_windup_t - delta)
            if _brace_windup_t <= 0.0:
                _brace_t = shield_brace_duration
                Events.fx_burst.emit("stone", position + Vector2(0, -6), -_brace_dir, 0.55)
            queue_redraw()
            return

    if target == null:
        if is_garrison:
            if position.distance_to(guard_origin) > 16.0:
                _move_toward(guard_origin, delta)
        else:
            _tick_flow(delta)
        return

    var to_target := target.position - position
    var distance := to_target.length()
    if distance <= _attack_reach():
        _begin_attack(target, to_target)
        return

    if distance <= shield_brace_trigger_range and _brace_cd <= 0.0:
        _brace_dir = to_target.normalized() if distance > 0.01 else Vector2.DOWN
        anim.face(_brace_dir)
        _brace_windup_t = shield_brace_windup_duration
        _brace_cd = shield_brace_cooldown_duration
        Events.fx_burst.emit("dust", position + Vector2(0, -3), -_brace_dir, 0.55)
        queue_redraw()
        return

    if is_garrison:
        if position.distance_to(guard_origin) <= 150.0:
            _move_toward(target.position, delta)
        else:
            _move_toward(guard_origin, delta)
    elif distance <= SHIELD_TARGET_RANGE:
        _move_toward(target.position, delta)
    else:
        _tick_flow(delta)


func _tick_shaman_support() -> bool:
    if support_amount <= 0 or support_radius <= 0.0 or _support_cd > 0.0:
        return false
    if not ENEMY_SUPPORT.heal_nearest_ally(self, support_radius, support_amount):
        return false
    _support_cd = maxf(0.5, support_interval)
    return true


func _tick_ranged(delta: float) -> void:
    if is_garrison and position.distance_to(guard_origin) > 155.0:
        _move_toward(guard_origin, delta)
        return
    var target := _nearest_ranged_target()
    if target == null:
        if is_garrison:
            if position.distance_to(guard_origin) > 16.0:
                _move_toward(guard_origin, delta)
        else:
            _tick_flow(delta)
        return

    var to_target := target.position - position
    var distance := to_target.length()
    var direction := to_target.normalized() if distance > 0.01 else Vector2.DOWN
    if distance < preferred_range - 10.0:
        _move_toward(position - direction * 28.0, delta)
    elif distance <= attack_range:
        if _atk_cd <= 0.0:
            _begin_ranged_attack(target)
    else:
        _move_toward(target.position - direction * preferred_range, delta)


func _nearest_ranged_target() -> Node2D:
    var marked := _valid_scout_mark(165.0)
    if marked != null:
        return marked
    var candidates := get_tree().get_nodes_in_group("defenders")
    if player != null and is_instance_valid(player):
        candidates.append(player)
    return ENEMY_TARGETING.nearest(self, candidates, 165.0, guard_origin if is_garrison else Vector2.ZERO, 175.0 if is_garrison else 0.0)


func _tick_garrison(delta: float) -> void:
    var target := _nearest_guard_target()
    if target != null:
        var distance := position.distance_to(target.position)
        if distance <= _attack_reach():
            _begin_attack(target, target.position - position)
            return
        if position.distance_to(guard_origin) <= 150.0:
            _move_toward(target.position, delta)
        else:
            _move_toward(guard_origin, delta)
    elif position.distance_to(guard_origin) > 16.0:
        _move_toward(guard_origin, delta)


func _nearest_guard_target() -> Node2D:
    var marked := _valid_scout_mark(150.0)
    if marked != null:
        return marked
    var candidates := get_tree().get_nodes_in_group("defenders")
    if player != null and is_instance_valid(player):
        candidates.append(player)
    return ENEMY_TARGETING.nearest(self, candidates, 150.0, guard_origin, 175.0)


func _begin_attack(target, direction: Vector2) -> void:
    if _atk_cd > 0.0:
        return
    _atk_cd = attack_interval
    _pending = target
    _pending_is_projectile = false
    if anim.face(direction):
        queue_redraw()
    anim.play("attack", true)
    if role == "pouncer":
        _pending_t = 0.28
        _pounce_dir = direction.normalized()
        _pounce_windup_t = 0.12
        _pounce_t = 0.16
        Events.fx_burst.emit("dust", position + Vector2(0, -2), -_pounce_dir, 1.3)
    else:
        _pending_t = ATTACK_HIT_DELAY


func _begin_ranged_attack(target: Node2D) -> void:
    if _atk_cd > 0.0:
        return
    _atk_cd = attack_interval
    _pending = target
    _pending_is_projectile = true
    _pending_t = ATTACK_HIT_DELAY
    if anim.face(target.position - position):
        queue_redraw()
    anim.play("attack", true)


func _resolve_pending(delta: float) -> void:
    if _pending == null:
        return
    _pending_t -= delta
    if _pending_t > 0.0:
        return
    var target = _pending
    _pending = null
    if not is_instance_valid(target):
        _pending_is_projectile = false
        return
    if _pending_is_projectile:
        _pending_is_projectile = false
        var bolt := ENEMY_BOLT.new()
        bolt.global_position = global_position + Vector2(0, -8)
        bolt.setup(target, damage, projectile_speed)
        world.entities.add_child(bolt)
        return
    _pending_is_projectile = false
    if role == "pouncer" and position.distance_to(target.position) > 36.0:
        return
    if is_supply_raider and target.is_in_group("depots"):
        supply_raid_hits += 1
        if supply_raid_hits % 2 == 0:
            var supply = get_tree().get_first_node_in_group("supply_network")
            if supply != null:
                supply.raid_steal_from(target)
    var final_damage := damage
    if target.is_in_group("buildings"):
        final_damage = roundi(float(damage) * structure_damage_mult)
    target.take_damage(final_damage)


func apply_stagger(duration: float) -> void:
    _stagger_t = maxf(_stagger_t, duration * (1.0 - stagger_resistance))
    _pending = null
    _pending_is_projectile = false
    _pending_t = 0.0
    _pounce_windup_t = 0.0
    _pounce_t = 0.0
    if archetype == "shieldbearer":
        _brace_windup_t = 0.0
        _brace_t = 0.0
        _brace_cd = maxf(_brace_cd, 1.1)
        _brace_dir = Vector2.ZERO
    if archetype == "scout" and _scout_windup_t > 0.0:
        _scout_windup_t = 0.0
        _scout_windup_target = null
        _scout_mark_cd = maxf(_scout_mark_cd, 1.2)
    _hurt_t = maxf(_hurt_t, duration * 0.5)
    anim.play("hurt", true)


func _footsteps(delta: float) -> void:
    if not _moving or not (runs or is_boss):
        return
    _step_t -= delta
    if _step_t > 0.0:
        return
    _step_t = 0.5 if is_boss else 0.14
    Events.fx_burst.emit("dust", position + Vector2(0, -1), Vector2.ZERO, 2.0 if is_boss else 1.0)
    if is_boss and player != null and is_instance_valid(player) and position.distance_to(player.position) < 220.0:
        Events.screen_shake.emit(1.0, 0.1)


func _update_anim(delta: float) -> void:
    if anim.clip == "attack" and not anim.finished:
        pass
    elif _hurt_t > 0.0 or _stagger_t > 0.0:
        anim.play("hurt")
    elif _moving:
        anim.play("run" if runs else "walk")
        anim.speed_scale = clampf(speed / (RUN_BASE_SPEED if runs else WALK_BASE_SPEED), 0.6, 1.5)
    else:
        anim.play("idle")
        anim.speed_scale = 1.0
    if anim.update(delta):
        queue_redraw()


func _move_toward(target: Vector2, delta: float) -> void:
    var to := target - position
    var distance := to.length()
    if anim.face(to):
        queue_redraw()
    if distance > 0.5:
        _moving = true
        position += to / distance * minf(speed * delta, distance)


func receive_healing(amount: int) -> void:
    if hp <= 0 or amount <= 0:
        return
    var previous_hp := hp
    hp = mini(max_hp, hp + amount)
    if hp != previous_hp:
        queue_redraw()


func take_damage(amount: int) -> void:
    _take_damage_from(amount, Vector2.ZERO)


func take_damage_from(amount: int, source_position: Vector2) -> void:
    _take_damage_from(amount, source_position)


func _take_damage_from(amount: int, source_position: Vector2) -> void:
    if hp <= 0:
        return
    var damage_multiplier := 1.0 - armor
    var blocked_by_shield := false
    if archetype == "shieldbearer" and _brace_t > 0.0 and source_position != Vector2.ZERO:
        var incoming_direction := (source_position - global_position).normalized()
        blocked_by_shield = incoming_direction.dot(_brace_dir) >= shield_brace_front_dot
    if blocked_by_shield:
        damage_multiplier *= shield_brace_damage_multiplier
    var applied := maxi(1, roundi(float(amount) * damage_multiplier))
    hp -= applied
    if blocked_by_shield:
        Events.fx_burst.emit("stone", position + Vector2(0, -_fh * 0.4), -_brace_dir, 0.8)
    else:
        Events.fx_burst.emit("impact", position + Vector2(0, -_fh * 0.4), Vector2.ZERO, 2.0 if is_boss else 1.0)
    modulate = Color(1.8, 1.8, 1.8)
    create_tween().tween_property(self, "modulate", _faction_tint, 0.12)
    queue_redraw()
    if hp <= 0:
        remove_from_group("enemies")
        remove_from_group("enemy_garrison")
        remove_from_group("ranged_enemies")
        remove_from_group("supply_raiders")
        Events.enemy_killed.emit(id)
        if is_boss:
            if WorldConfig.profile_id == "frontier":
                Events.frontier_final_boss_defeated.emit(GameClock.day)
            else:
                Events.game_won.emit(GameClock.day)
        Events.fx_burst.emit("puff" if is_boss else "dust", position + Vector2(0, -2), Vector2.ZERO, 2.0 if is_boss else 1.5)
        if is_boss:
            Events.screen_shake.emit(3.0, 0.6)
        Corpse.spawn(get_parent(), _tex, _fw, _fh, anim.view, anim.flip, position)
        queue_free()
    elif not is_boss and not (anim.clip == "attack" and not anim.finished):
        _hurt_t = 0.18


func retreat() -> void:
    if is_boss:
        return
    is_garrison = false
    remove_from_group("enemies")
    remove_from_group("enemy_garrison")
    remove_from_group("ranged_enemies")
    remove_from_group("supply_raiders")
    queue_free()


func _draw() -> void:
    anim.draw(self, _tex, _fw, _fh)
    if is_supply_raider:
        draw_rect(Rect2(-3, -_fh - 8, 6, 3), Color("#f2b45f"))
        draw_line(Vector2(0, -_fh - 8), Vector2(0, -_fh - 12), Color("#f2b45f"), 1.0)
    if _pounce_windup_t > 0.0:
        draw_line(Vector2(0, -6), Vector2(0, -6) + _pounce_dir * 14.0,
            Color("#ffb347"), 2.0)
    match archetype:
        "scout":
            draw_line(Vector2(-4, -15), Vector2(0, -19), color, 1.5)
            draw_line(Vector2(0, -19), Vector2(4, -15), color, 1.5)
            var scout_target: Node2D = _scout_windup_target if _scout_windup_t > 0.0 else _scout_mark_target
            if scout_target != null and is_instance_valid(scout_target):
                var marker_center := scout_target.global_position - global_position + Vector2(0, -8)
                var marker_color := Color("#efca78") if _scout_windup_t > 0.0 else Color("#d99b45")
                draw_line(Vector2(0, -_fh - 5), marker_center, marker_color, 1.0)
                draw_arc(marker_center, 10.0, 0.0, TAU, 12, marker_color, 1.5)
            if _scout_windup_t > 0.0:
                draw_arc(Vector2(0, -_fh - 8), 5.0, 0.0, TAU, 8, Color("#efca78"), 1.5)
        "shieldbearer":
            draw_rect(Rect2(-11, -14, 5, 10), color, false, 1.5)
            draw_line(Vector2(-11, -10), Vector2(-6, -10), color, 1.0)
        "saboteur":
            draw_circle(Vector2(7, -12), 2.5, color)
            draw_line(Vector2(7, -15), Vector2(10, -18), color, 1.0)
        "war_shaman":
            draw_arc(Vector2(0, -_fh * 0.55), 7.0, 0.0, TAU, 12, color, 1.0)
        "siege_engine":
            draw_rect(Rect2(-9, -14, 5, 5), color)
            draw_rect(Rect2(4, -14, 5, 5), color)
        "beast_rider":
            draw_line(Vector2(-5, -12), Vector2(-10, -17), color, 1.5)
            draw_line(Vector2(5, -12), Vector2(10, -17), color, 1.5)
    if archetype == "shieldbearer" and (_brace_windup_t > 0.0 or _brace_t > 0.0):
        var brace_center := Vector2(0, -_fh * 0.55)
        var brace_angle := _brace_dir.angle()
        if _brace_windup_t > 0.0:
            draw_arc(brace_center, 17.0, brace_angle - 0.82, brace_angle + 0.82,
                12, Color("#d8bd87"), 1.5)
            draw_line(brace_center, brace_center + _brace_dir * 20.0, Color("#f0d7a5"), 2.0)
        else:
            draw_arc(brace_center, 18.0, brace_angle - 0.92, brace_angle + 0.92,
                12, Color("#d8bd87"), 2.0)
            draw_arc(brace_center, 22.0, brace_angle - 0.72, brace_angle + 0.72,
                12, Color("#8795a5"), 1.0)
    if role == "ranged":
        draw_arc(Vector2(7, -11), 4.0, -PI * 0.55, PI * 0.55, 7, Color("#91c99a"), 1.0)
        draw_line(Vector2(7, -15), Vector2(7, -7), Color("#d9e7c8"), 1.0)
    elif role == "siege":
        draw_rect(Rect2(-8, -14, 5, 4), Color("#8b6b50"))
        draw_rect(Rect2(3, -14, 5, 4), Color("#8b6b50"))
    if hp < max_hp:
        var width := 10.0 * (3.0 if is_boss else 1.0)
        var bar_y := -(_fh - roundi(0.2 * _fh)) - 4.0
        draw_rect(Rect2(-width / 2, bar_y, width, 2), Color(0, 0, 0, 0.7))
        draw_rect(Rect2(-width / 2, bar_y, width * float(hp) / max_hp, 2), Color("#e8483c"))
