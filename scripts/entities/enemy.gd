extends Node2D
## Enemy roles: melee raider, pouncing wolf, ranged archer, armored siege brute.
## Normal raiders follow the flow field; garrison units defend their stronghold radius.

const SpriteAnim := preload("res://scripts/entities/sprite_anim.gd")
const EnemyVisualScale := preload("res://scripts/entities/enemy_visual_scale.gd")
const FactionVisual := preload("res://scripts/entities/enemy_faction_visual.gd")
const CombatVisualFeedback := preload("res://scripts/entities/combat_visual_feedback.gd")
const ENEMY_TARGETING := preload("res://scripts/systems/enemy_targeting.gd")
const PATROL_MOVEMENT_SCRIPT := preload("res://scripts/behaviors/enemies/enemy_patrol_movement.gd")
const RAID_BEHAVIOR_SCRIPT := preload("res://scripts/behaviors/enemies/enemy_raid_behavior.gd")
const ENEMY_COMBAT_LIFECYCLE_SCRIPT := preload("res://scripts/behaviors/enemies/enemy_combat_lifecycle.gd")
const WarShamanSupportBehavior := preload("res://scripts/behaviors/war_shaman_support_behavior.gd")
const BeastRiderBehavior := preload("res://scripts/behaviors/beast_rider_behavior.gd")
const ShieldbearerBehavior := preload("res://scripts/behaviors/shieldbearer_behavior.gd")
const ScoutBehavior := preload("res://scripts/behaviors/scout_behavior.gd")
const SaboteurBehavior := preload("res://scripts/behaviors/saboteur_behavior.gd")
const SiegeEngineBehavior := preload("res://scripts/behaviors/siege_engine_behavior.gd")
const TEXTURES := {
    "bandit": preload("res://assets/sprites/enemy_bandit.svg"),
    "wolf": preload("res://assets/sprites/enemy_wolf.svg"),
    "soldier": preload("res://assets/sprites/enemy_soldier.svg"),
    "archer": preload("res://assets/sprites/enemy_archer.svg"),
    "brute": preload("res://assets/sprites/enemy_brute.svg"),
    "king": preload("res://assets/sprites/enemy_king.svg"),
}
const PLAYER_REACH := 12.0
const ATTACK_HIT_DELAY := 0.14
const SHIELD_TARGET_RANGE := 96.0
const SCOUT_FOCUS_RANGE := 220.0
const BEAST_TARGET_SCAN_LIMIT := 24
const BEAST_TARGET_ISOLATION_RADIUS := 76.0
const TARGET_REFRESH_INTERVAL := 0.12
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
var is_patrol := false
var patrol_camp_id := ""
var patrol_region_id := ""
var patrol_origin := Vector2.ZERO
var patrol_radius := 144.0
var patrol_points: Array[Vector2] = []
var patrol_waypoint_index := 0
var patrol_returning := false
var patrol_nav
var patrol_territory
var pending_patrol_state: Dictionary = {}
var _patrol_path := PackedVector2Array()
var _patrol_path_index := 0
var _patrol_path_version := -1
var _patrol_goal_cell := Vector2i(-1, -1)
var _patrol_repath_timer := 0.0
var is_supply_raider := false
var is_faction_raider := false
var faction_raid_target_kind := ""
var faction_raid_camp_id := ""
var faction_raid_region_id := ""
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
var faction_visual: Dictionary = {}
var campaign_site_id := ""
var _faction_tint := Color.WHITE
var support_behavior = WarShamanSupportBehavior.new()
var attack_range := PLAYER_REACH
var preferred_range := 0.0
var projectile_speed := 120.0
var armor := 0.0
var stagger_resistance := 0.0
var structure_damage_mult := 1.0
var shield_behavior = ShieldbearerBehavior.new()
var scout_behavior = ScoutBehavior.new()
var saboteur_behavior = SaboteurBehavior.new()
var siege_behavior = SiegeEngineBehavior.new()
var beast_behavior = BeastRiderBehavior.new()

var world
var flow
var player
var anim := SpriteAnim.new()
var combat_feedback = CombatVisualFeedback.new()
var patrol_movement = PATROL_MOVEMENT_SCRIPT.new()
var raid_behavior = RAID_BEHAVIOR_SCRIPT.new()
var combat_lifecycle = ENEMY_COMBAT_LIFECYCLE_SCRIPT.new()

var _offset := Vector2.ZERO
var _atk_cd := 0.0
var _moving := false
var _step_t := 0.0
var _hurt_t := 0.0
var _stagger_t := 0.0
var _contact_target_scan_t := 0.0
var _contact_target_cache: Node2D
var _ranged_target_scan_t := 0.0
var _ranged_target_cache: Node2D
var _guard_target_scan_t := 0.0
var _guard_target_cache: Node2D
var _shield_target_scan_t := 0.0
var _shield_target_cache: Node2D
var _pending = null
var _pending_t := 0.0
var _pending_is_projectile := false
var _pounce_windup_t := 0.0
var _pounce_t := 0.0
var _pounce_dir := Vector2.ZERO
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
    scale = EnemyVisualScale.from_data(data)
    is_boss = bool(data.get("boss", false))
    runs = bool(data.get("run", false))
    role = String(data.get("role", "pouncer" if id == "wolf" else "melee"))
    archetype = String(data.get("archetype", role))
    faction_id = faction_override
    faction_visual.clear()
    _faction_tint = Color.WHITE
    if not faction_id.is_empty():
        var faction_data: Dictionary = FactionRegistry.faction_for_stronghold(faction_id)
        if not faction_data.is_empty():
            _faction_tint = Color(String(faction_data.get("color", "#ffffff")))
            var visual_profile: Variant = faction_data.get("visual", {})
            if visual_profile is Dictionary:
                faction_visual = visual_profile.duplicate(true)
    attack_range = float(data.get("range", 30.0 if role == "pouncer" else PLAYER_REACH))
    preferred_range = float(data.get("preferred_range", 0.0))
    projectile_speed = float(data.get("projectile_speed", 120.0))
    armor = clampf(float(data.get("armor", 0.0)), 0.0, 0.8)
    stagger_resistance = clampf(float(data.get("stagger_resistance", 0.0)), 0.0, 0.9)
    structure_damage_mult = maxf(1.0, float(data.get("structure_damage_mult", 1.0)))
    is_patrol = false
    is_supply_raider = false
    is_faction_raider = false
    faction_raid_target_kind = ""
    faction_raid_camp_id = ""
    faction_raid_region_id = ""
    raid_target_cell = Vector2i(-1, -1)
    supply_raid_hits = 0
    raid_nav = null
    _raid_path = PackedVector2Array()
    _raid_path_index = 0
    _raid_path_version = -1
    _raid_repath_timer = 0.0
    patrol_camp_id = ""
    patrol_region_id = ""
    patrol_origin = Vector2.ZERO
    patrol_radius = 144.0
    patrol_points.clear()
    patrol_waypoint_index = 0
    patrol_returning = false
    patrol_nav = null
    patrol_territory = null
    pending_patrol_state.clear()
    _patrol_path = PackedVector2Array()
    _patrol_path_index = 0
    _patrol_path_version = -1
    _patrol_goal_cell = Vector2i(-1, -1)
    _patrol_repath_timer = 0.0
    world = world_ref
    flow = flow_ref
    player = player_ref
    support_behavior.configure(self, data)
    beast_behavior.configure(self, data)
    shield_behavior.configure(self, data, SHIELD_TARGET_RANGE)
    scout_behavior.configure(self, data)
    saboteur_behavior.configure(self, data)
    siege_behavior.configure(self, data)
    _offset = Vector2(randf_range(-4.0, 4.0), randf_range(-3.0, 3.0))
    scale = Vector2.ONE * scale_f
    _tex = TEXTURES.get(id, TEXTURES["bandit"])
    _fw = int(_tex.get_width() / float(SpriteAnim.FRAMES))
    _fh = int(_tex.get_height() / 3.0)


func setup_guard(data: Dictionary, world_ref, flow_ref, player_ref, origin: Vector2, faction_override := "") -> void:
    setup(data, world_ref, flow_ref, player_ref, faction_override)
    is_garrison = true
    guard_origin = origin


func setup_patrol(
    data: Dictionary,
    world_ref,
    flow_ref,
    player_ref,
    faction_override: String,
    camp_data: Dictionary,
    saved_patrol_state: Dictionary = {}
) -> void:
    setup_guard(data, world_ref, flow_ref, player_ref, Vector2.ZERO, faction_override)
    configure_patrol(camp_data, saved_patrol_state)


func configure_patrol(camp_data: Dictionary, saved_patrol_state: Dictionary = {}) -> void:
    is_garrison = true
    is_patrol = true
    patrol_camp_id = String(camp_data.get("camp_id", ""))
    patrol_region_id = String(camp_data.get("region_id", ""))
    var saved_origin: Variant = camp_data.get("camp_position", Vector2.ZERO)
    patrol_origin = Vector2(saved_origin)
    patrol_radius = clampf(float(camp_data.get("patrol_radius", 144.0)), 80.0, 220.0)
    patrol_points.clear()
    var raw_points: Array = camp_data.get("patrol_points", [])
    for point_value in raw_points:
        if point_value is Vector2:
            patrol_points.append(point_value)
    patrol_waypoint_index = posmod(int(saved_patrol_state.get("waypoint_index", 0)), maxi(1, patrol_points.size()))
    patrol_returning = bool(saved_patrol_state.get("returning", false))
    guard_origin = patrol_origin if patrol_returning or patrol_points.is_empty() else patrol_points[patrol_waypoint_index]
    pending_patrol_state.clear()
    patrol_nav = null
    patrol_territory = camp_data.get("territory", null)
    _patrol_path = PackedVector2Array()
    _patrol_path_index = 0
    _patrol_path_version = -1
    _patrol_goal_cell = Vector2i(-1, -1)
    _patrol_repath_timer = 0.0
    if is_inside_tree():
        patrol_nav = get_tree().get_first_node_in_group("navigation_grid")
        patrol_movement.configure(self)
        add_to_group("enemy_patrols")


func export_patrol_state() -> Dictionary:
    if not is_patrol:
        return {}
    return {
        "camp_id": patrol_camp_id,
        "waypoint_index": patrol_waypoint_index,
        "returning": patrol_returning
    }


func _ready() -> void:
    raid_behavior.configure(self)
    combat_lifecycle.configure(self)
    add_to_group("enemies")
    if is_patrol:
        add_to_group("enemy_patrols")
        patrol_nav = get_tree().get_first_node_in_group("navigation_grid")
        patrol_movement.configure(self)
    if archetype in ["saboteur", "siege_engine", "beast_rider"]:
        var nav_grid := get_tree().get_first_node_in_group("navigation_grid")
        if archetype == "saboteur":
            saboteur_behavior.set_navigation(nav_grid)
        elif archetype == "siege_engine":
            siege_behavior.set_navigation(nav_grid)
        elif archetype == "beast_rider":
            beast_behavior.set_navigation(nav_grid)
    if is_supply_raider:
        add_to_group("supply_raiders")
    if is_faction_raider:
        add_to_group("faction_raiders")
    if is_garrison:
        add_to_group("enemy_garrison")
    if archetype == "shieldbearer":
        shield_behavior.draw_telegraph(self, _fh)
    if role == "ranged":
        add_to_group("ranged_enemies")
    anim.view = SpriteAnim.SIDE
    modulate = _faction_tint


func _physics_process(delta: float) -> void:
    if combat_feedback.advance(delta):
        queue_redraw()
    _atk_cd = maxf(0.0, _atk_cd - delta)
    _hurt_t = maxf(0.0, _hurt_t - delta)
    _contact_target_scan_t = maxf(0.0, _contact_target_scan_t - delta)
    _ranged_target_scan_t = maxf(0.0, _ranged_target_scan_t - delta)
    _guard_target_scan_t = maxf(0.0, _guard_target_scan_t - delta)
    _shield_target_scan_t = maxf(0.0, _shield_target_scan_t - delta)
    support_behavior.advance_timers(delta)
    shield_behavior.advance_timers(delta)
    saboteur_behavior.advance_timers(delta)
    siege_behavior.advance_timers(delta)
    beast_behavior.advance_timers(delta)
    scout_behavior.advance_timers(delta)
    _resolve_pending(delta)
    _moving = false

    if _stagger_t > 0.0:
        if archetype == "scout":
            scout_behavior.interrupt()
        _stagger_t = maxf(0.0, _stagger_t - delta)
        _update_anim(delta)
        queue_redraw()
        return

    if is_patrol:
        _tick_patrol_route()

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

    if is_faction_raider:
        _tick_faction_raid(delta)
        _update_anim(delta)
        _footsteps(delta)
        return

    if archetype == "beast_rider":
        _tick_beast_rider(delta)
        _update_anim(delta)
        _footsteps(delta)
        return

    if archetype == "siege_engine":
        _tick_siege_engine(delta)
        _update_anim(delta)
        _footsteps(delta)
        return

    if archetype == "saboteur":
        _tick_saboteur(delta)
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

    var contact_target := _nearest_contact_target()
    if contact_target != null:
        _begin_attack(contact_target, contact_target.position - position)
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
    return raid_behavior.find_raid_depot()


func setup_faction_raid(
    target_cell: Vector2i,
    target_kind: String,
    navigation,
    camp_id: String,
    region_id: String,
    camp_origin: Vector2
) -> void:
    is_supply_raider = false
    is_faction_raider = true
    is_garrison = true
    faction_raid_target_kind = target_kind
    faction_raid_camp_id = camp_id
    faction_raid_region_id = region_id
    raid_target_cell = target_cell
    raid_nav = navigation
    guard_origin = camp_origin
    _raid_path = PackedVector2Array()
    _raid_path_index = 0
    _raid_path_version = -1
    _raid_repath_timer = 0.0


func _find_faction_raid_target():
    return raid_behavior.find_faction_raid_target()


func _faction_raid_target_valid(target, supply) -> bool:
    return raid_behavior.faction_raid_target_valid(target, supply)


func _tick_faction_raid(delta: float) -> void:
    raid_behavior.tick_faction_raid(delta)


func _tick_supply_raid(delta: float) -> void:
    raid_behavior.tick_supply_raid(delta)


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



func _tick_beast_rider(delta: float) -> void:
    beast_behavior.tick(delta)


func _tick_siege_engine(delta: float) -> void:
    siege_behavior.tick(delta)


func _tick_saboteur(delta: float) -> void:
    saboteur_behavior.tick(delta)


func _nearest_scout_target() -> Node2D:
    return scout_behavior.nearest_target()


func _tick_scout(delta: float) -> void:
    scout_behavior.tick(delta)


func apply_scout_mark(target: Node2D, duration: float) -> void:
    scout_behavior.apply_mark(target, duration)


func _valid_scout_mark(max_distance: float) -> Node2D:
    return scout_behavior.valid_mark(max_distance)


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


func _nearest_contact_target() -> Node2D:
    var reach := _attack_reach()
    # Preserve the existing player-first combat targeting rule every physics tick.
    if player != null and is_instance_valid(player) and player.visible:
        if position.distance_squared_to(player.position) < reach * reach:
            _contact_target_cache = player
            return _contact_target_cache
    if is_instance_valid(_contact_target_cache):
        var cached_player: bool = _contact_target_cache == player and player != null and is_instance_valid(player)
        var cached_defender: bool = _contact_target_cache.is_in_group("defenders")
        if (cached_player or cached_defender) and _contact_target_cache.visible and position.distance_squared_to(_contact_target_cache.position) < reach * reach:
            if _contact_target_scan_t > 0.0:
                return _contact_target_cache
    _contact_target_cache = null
    if _contact_target_scan_t > 0.0:
        return null
    _contact_target_scan_t = TARGET_REFRESH_INTERVAL
    for defender in get_tree().get_nodes_in_group("defenders"):
        if not is_instance_valid(defender) or not (defender is Node2D):
            continue
        var target := defender as Node2D
        if target.visible and position.distance_squared_to(target.position) < reach * reach:
            _contact_target_cache = target
            return _contact_target_cache
    return null


func _nearest_shield_target() -> Node2D:
    var marked := _valid_scout_mark(SHIELD_TARGET_RANGE)
    if marked != null:
        return marked
    if is_garrison:
        return _nearest_guard_target()
    if _shield_target_scan_t > 0.0 and is_instance_valid(_shield_target_cache):
        var cached_player: bool = _shield_target_cache == player and player != null and is_instance_valid(player)
        var cached_defender: bool = _shield_target_cache.is_in_group("defenders")
        if (cached_player or cached_defender) and _shield_target_cache.visible and position.distance_squared_to(_shield_target_cache.position) <= SHIELD_TARGET_RANGE * SHIELD_TARGET_RANGE:
            return _shield_target_cache
    if _shield_target_scan_t > 0.0:
        return null
    _shield_target_cache = null
    _shield_target_scan_t = TARGET_REFRESH_INTERVAL
    var candidates := get_tree().get_nodes_in_group("defenders")
    if player != null and is_instance_valid(player):
        candidates.append(player)
    _shield_target_cache = ENEMY_TARGETING.nearest(self, candidates, SHIELD_TARGET_RANGE)
    return _shield_target_cache


func _tick_shieldbearer(delta: float) -> void:
    shield_behavior.tick(delta)


func _tick_shaman_support() -> bool:
    return support_behavior.tick()


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
    if is_patrol and patrol_returning:
        _ranged_target_cache = null
        return null
    var marked := _valid_scout_mark(165.0)
    if marked != null:
        _ranged_target_cache = marked
        return marked
    var leash_center := patrol_origin if is_patrol else guard_origin
    var leash_radius := patrol_radius if is_patrol else (175.0 if is_garrison else 0.0)
    if _ranged_target_scan_t > 0.0 and is_instance_valid(_ranged_target_cache):
        var cached_distance := position.distance_squared_to(_ranged_target_cache.position)
        var cached_in_leash := leash_radius <= 0.0 or _ranged_target_cache.position.distance_to(leash_center) <= leash_radius
        var cached_player: bool = _ranged_target_cache == player and player != null and is_instance_valid(player)
        var cached_defender: bool = _ranged_target_cache.is_in_group("defenders")
        if (cached_player or cached_defender) and _ranged_target_cache.visible and cached_distance <= 165.0 * 165.0 and cached_in_leash:
            return _ranged_target_cache
    if _ranged_target_scan_t > 0.0:
        return null
    _ranged_target_cache = null
    _ranged_target_scan_t = TARGET_REFRESH_INTERVAL
    var candidates := get_tree().get_nodes_in_group("defenders")
    if player != null and is_instance_valid(player):
        candidates.append(player)
    _ranged_target_cache = ENEMY_TARGETING.nearest(self, candidates, 165.0, leash_center, leash_radius)
    return _ranged_target_cache


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
    if is_patrol and patrol_returning:
        _guard_target_cache = null
        return null
    var marked := _valid_scout_mark(150.0)
    if marked != null:
        _guard_target_cache = marked
        return marked
    var leash_center := patrol_origin if is_patrol else guard_origin
    var leash_radius := patrol_radius if is_patrol else 175.0
    if _guard_target_scan_t > 0.0 and is_instance_valid(_guard_target_cache):
        var cached_distance := position.distance_squared_to(_guard_target_cache.position)
        var cached_in_leash := _guard_target_cache.position.distance_to(leash_center) <= leash_radius
        var cached_player: bool = _guard_target_cache == player and player != null and is_instance_valid(player)
        var cached_defender: bool = _guard_target_cache.is_in_group("defenders")
        if (cached_player or cached_defender) and _guard_target_cache.visible and cached_distance <= 150.0 * 150.0 and cached_in_leash:
            return _guard_target_cache
    if _guard_target_scan_t > 0.0:
        return null
    _guard_target_cache = null
    _guard_target_scan_t = TARGET_REFRESH_INTERVAL
    var candidates := get_tree().get_nodes_in_group("defenders")
    if player != null and is_instance_valid(player):
        candidates.append(player)
    _guard_target_cache = ENEMY_TARGETING.nearest(self, candidates, 150.0, leash_center, leash_radius)
    return _guard_target_cache


func _begin_attack(target, direction: Vector2) -> void:
    combat_lifecycle.begin_attack(target, direction)


func _begin_ranged_attack(target: Node2D) -> void:
    combat_lifecycle.begin_ranged_attack(target)


func _resolve_pending(delta: float) -> void:
    combat_lifecycle.resolve_pending(delta)


func apply_stagger(duration: float) -> void:
    combat_lifecycle.apply_stagger(duration)


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
    if is_patrol:
        _move_patrol_toward(target, delta)
        return
    _move_toward_direct(target, delta)


func _move_toward_direct(target: Vector2, delta: float) -> void:
    var to := target - position
    var distance := to.length()
    if anim.face(to):
        queue_redraw()
    if distance > 0.5:
        _moving = true
        position += to / distance * minf(speed * delta, distance)


func _tick_patrol_route() -> void:
    patrol_movement.tick_route()
func _patrol_cell_in_enemy_region(cell: Vector2i) -> bool:
    return patrol_movement.cell_in_enemy_region(cell)
func _patrol_cell_allowed(cell: Vector2i) -> bool:
    return patrol_movement.cell_allowed(cell)
func _move_patrol_toward(target: Vector2, delta: float) -> void:
    patrol_movement.move_toward(target, delta)
func receive_healing(amount: int) -> void:
    combat_lifecycle.receive_healing(amount)


func take_damage(amount: int) -> void:
    combat_lifecycle.take_damage(amount)


func take_damage_from(amount: int, source_position: Vector2) -> void:
    combat_lifecycle.take_damage_from(amount, source_position)


func _take_damage_from(amount: int, source_position: Vector2) -> void:
    combat_lifecycle.take_damage_from(amount, source_position)


func retreat() -> void:
    if is_boss:
        return
    is_garrison = false
    remove_from_group("enemies")
    remove_from_group("enemy_garrison")
    remove_from_group("enemy_patrols")
    remove_from_group("ranged_enemies")
    remove_from_group("supply_raiders")
    remove_from_group("faction_raiders")
    queue_free()


func _draw() -> void:
    anim.draw(self, _tex, _fw, _fh)
    FactionVisual.draw_identity(self, faction_visual, archetype)
    combat_feedback.draw(self, _fh, _faction_tint)
    if is_supply_raider or is_faction_raider:
        draw_rect(Rect2(-3, -_fh - 8, 6, 3), Color("#f2b45f"))
        draw_line(Vector2(0, -_fh - 8), Vector2(0, -_fh - 12), Color("#f2b45f"), 1.0)
    if _pounce_windup_t > 0.0:
        draw_line(Vector2(0, -6), Vector2(0, -6) + _pounce_dir * 14.0,
            Color("#ffb347"), 2.0)
    match archetype:
        "scout":
            scout_behavior.draw_telegraph(self, _fh, color)
        "shieldbearer":
            draw_rect(Rect2(-11, -14, 5, 10), color, false, 1.5)
            draw_line(Vector2(-11, -10), Vector2(-6, -10), color, 1.0)
        "saboteur":
            draw_circle(Vector2(7, -12), 2.5, color)
            draw_line(Vector2(7, -15), Vector2(10, -18), color, 1.0)
            saboteur_behavior.draw_telegraph(self, _fh)
        "war_shaman":
            draw_arc(Vector2(0, -_fh * 0.55), 7.0, 0.0, TAU, 12, color, 1.0)
        "siege_engine":
            draw_rect(Rect2(-9, -14, 5, 5), color)
            draw_rect(Rect2(4, -14, 5, 5), color)
            siege_behavior.draw_telegraph(self, _fh)
        "beast_rider":
            draw_line(Vector2(-5, -12), Vector2(-10, -17), color, 1.5)
            draw_line(Vector2(5, -12), Vector2(10, -17), color, 1.5)
            beast_behavior.draw_telegraph(self, _fh)
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
