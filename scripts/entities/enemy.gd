extends Node2D
## Enemy roles: melee raider, pouncing wolf, ranged archer, armored siege brute.
## Normal raiders follow the flow field; garrison units defend their stronghold radius.

const SpriteAnim := preload("res://scripts/entities/sprite_anim.gd")
const Corpse := preload("res://scripts/entities/corpse.gd")
const ENEMY_BOLT := preload("res://scripts/entities/enemy_bolt.gd")
const ENEMY_TARGETING := preload("res://scripts/systems/enemy_targeting.gd")
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
    "archer": preload("res://assets/sprites/enemy_bandit.svg"),
    "brute": preload("res://assets/sprites/enemy_soldier.svg"),
    "king": preload("res://assets/sprites/enemy_king.svg"),
}
const PLAYER_REACH := 12.0
const ATTACK_HIT_DELAY := 0.14
const SHIELD_TARGET_RANGE := 96.0
const SCOUT_FOCUS_RANGE := 220.0
const BEAST_TARGET_SCAN_LIMIT := 24
const BEAST_TARGET_ISOLATION_RADIUS := 76.0
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
    add_to_group("enemies")
    if is_patrol:
        add_to_group("enemy_patrols")
        patrol_nav = get_tree().get_first_node_in_group("navigation_grid")
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
    _atk_cd = maxf(0.0, _atk_cd - delta)
    _hurt_t = maxf(0.0, _hurt_t - delta)
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
    var group_name := "depots" if faction_raid_target_kind == "depot" else "roads"
    for candidate in get_tree().get_nodes_in_group(group_name):
        if not is_instance_valid(candidate) or candidate.cell != raid_target_cell:
            continue
        var candidate_id := String(candidate.id)
        if faction_raid_target_kind == "depot" and ["storage", "outpost"].has(candidate_id):
            return candidate
        if faction_raid_target_kind == "road" and ["road", "bridge"].has(candidate_id):
            return candidate
    return null


func _faction_raid_target_valid(target, supply) -> bool:
    if target == null or not is_instance_valid(target) or int(target.hp) <= 0:
        return false
    if supply == null or not is_instance_valid(supply) or supply.territory == null:
        return false
    supply._ensure_current()
    if String(supply.world.region_id(target.cell)) != faction_raid_region_id:
        return false

    var owner := String(supply.territory.owner_at(target.cell))
    var region: Dictionary = supply.territory.get_region_state(faction_raid_region_id)
    var control := String(region.get("control", "neutral"))
    var exposed := owner == "contested" or (owner == "player" and control in ["enemy", "contested"])
    if not exposed:
        return false

    if faction_raid_target_kind == "depot":
        return ["storage", "outpost"].has(String(target.id)) and supply.is_depot_connected(target)
    if faction_raid_target_kind == "road":
        if not ["road", "bridge"].has(String(target.id)):
            return false
        for cell in target.cells():
            if supply.connected_road_cells.has(cell):
                return true
    return false


func _tick_faction_raid(delta: float) -> void:
    var target = _find_faction_raid_target()
    var supply = get_tree().get_first_node_in_group("supply_network")
    if not _faction_raid_target_valid(target, supply):
        retreat()
        return

    var reach := maxf(_attack_reach(), 28.0)
    if player != null and is_instance_valid(player) and position.distance_to(player.position) <= reach:
        if role == "ranged":
            _begin_ranged_attack(player)
        else:
            _begin_attack(player, player.position - position)
        return
    for defender in get_tree().get_nodes_in_group("defenders"):
        if not is_instance_valid(defender) or not defender.visible:
            continue
        if position.distance_to(defender.position) <= reach:
            if role == "ranged":
                _begin_ranged_attack(defender)
            else:
                _begin_attack(defender, defender.position - position)
            return
    if position.distance_to(target.position) <= reach:
        if role == "ranged":
            _begin_ranged_attack(target)
        else:
            _begin_attack(target, target.position - position)
        return

    if raid_nav == null:
        retreat()
        return
    _raid_repath_timer = maxf(0.0, _raid_repath_timer - delta)
    if _raid_path_version != raid_nav.version or _raid_path.is_empty() or _raid_repath_timer <= 0.0:
        var target_cells: Array[Vector2i] = target.cells()
        _raid_path = raid_nav.path_adjacent(position, target_cells)
        _raid_path_index = 1 if _raid_path.size() > 1 else 0
        _raid_path_version = raid_nav.version
        _raid_repath_timer = 1.0
        if _raid_path.is_empty():
            retreat()
            return
    while _raid_path_index < _raid_path.size() and position.distance_to(_raid_path[_raid_path_index]) <= 3.0:
        _raid_path_index += 1
    if _raid_path_index < _raid_path.size():
        _move_toward(_raid_path[_raid_path_index], delta)


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
        return null
    var marked := _valid_scout_mark(165.0)
    if marked != null:
        return marked
    var candidates := get_tree().get_nodes_in_group("defenders")
    if player != null and is_instance_valid(player):
        candidates.append(player)
    var leash_center := patrol_origin if is_patrol else guard_origin
    var leash_radius := patrol_radius if is_patrol else (175.0 if is_garrison else 0.0)
    return ENEMY_TARGETING.nearest(self, candidates, 165.0, leash_center, leash_radius)


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
        return null
    var marked := _valid_scout_mark(150.0)
    if marked != null:
        return marked
    var candidates := get_tree().get_nodes_in_group("defenders")
    if player != null and is_instance_valid(player):
        candidates.append(player)
    var leash_center := patrol_origin if is_patrol else guard_origin
    var leash_radius := patrol_radius if is_patrol else 175.0
    return ENEMY_TARGETING.nearest(self, candidates, 150.0, leash_center, leash_radius)


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
    if (is_supply_raider or is_faction_raider) and target.is_in_group("depots"):
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
        shield_behavior.interrupt()
    if archetype == "scout":
        scout_behavior.interrupt()
    if archetype == "saboteur":
        saboteur_behavior.interrupt()
    if archetype == "siege_engine":
        siege_behavior.interrupt()
    if archetype == "beast_rider":
        beast_behavior.interrupt()
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
    if patrol_points.is_empty():
        guard_origin = patrol_origin
        return
    if position.distance_to(patrol_origin) > patrol_radius:
        patrol_returning = true
    if patrol_returning:
        guard_origin = patrol_origin
        if position.distance_to(patrol_origin) <= 14.0:
            patrol_returning = false
            patrol_waypoint_index = posmod(patrol_waypoint_index, patrol_points.size())
            guard_origin = patrol_points[patrol_waypoint_index]
        return
    var waypoint: Vector2 = patrol_points[patrol_waypoint_index]
    guard_origin = waypoint
    if position.distance_to(waypoint) <= 12.0:
        patrol_waypoint_index = (patrol_waypoint_index + 1) % patrol_points.size()
        guard_origin = patrol_points[patrol_waypoint_index]


func _patrol_cell_in_enemy_region(cell: Vector2i) -> bool:
    if patrol_nav == null or not patrol_nav.is_walkable(cell):
        return false
    if String(world.region_id(cell)) != patrol_region_id:
        return false
    if patrol_territory != null and patrol_territory.owner_at(cell) != "enemy":
        return false
    return true


func _patrol_cell_allowed(cell: Vector2i) -> bool:
    if not _patrol_cell_in_enemy_region(cell):
        return false
    return Vector2(patrol_nav.cell_of(patrol_origin) - cell).length() * WorldConfig.tile_size <= patrol_radius + WorldConfig.tile_size


func _move_patrol_toward(target: Vector2, delta: float) -> void:
    if patrol_nav == null:
        return
    var goal_cell: Vector2i = patrol_nav.cell_of(target)
    if not WorldConfig.is_valid_cell(goal_cell) or not _patrol_cell_allowed(goal_cell):
        return
    _patrol_repath_timer = maxf(0.0, _patrol_repath_timer - delta)
    if _patrol_path_version != patrol_nav.version or _patrol_goal_cell != goal_cell or _patrol_path.is_empty() or _patrol_repath_timer <= 0.0:
        var candidate_path: PackedVector2Array = patrol_nav.path_to(global_position, goal_cell)
        var valid_path := not candidate_path.is_empty()
        if valid_path:
            for path_point in candidate_path:
                var path_cell: Vector2i = patrol_nav.cell_of(path_point)
                var cell_is_allowed := _patrol_cell_in_enemy_region(path_cell)
                if not patrol_returning:
                    cell_is_allowed = _patrol_cell_allowed(path_cell)
                if not cell_is_allowed:
                    valid_path = false
                    break
        if not valid_path:
            _patrol_path = PackedVector2Array()
            return
        _patrol_path = candidate_path
        _patrol_path_index = 1 if candidate_path.size() > 1 else 0
        _patrol_path_version = patrol_nav.version
        _patrol_goal_cell = goal_cell
        _patrol_repath_timer = 0.55

    while _patrol_path_index < _patrol_path.size() and global_position.distance_to(_patrol_path[_patrol_path_index]) <= 3.0:
        _patrol_path_index += 1
    if _patrol_path_index < _patrol_path.size():
        _move_toward_direct(_patrol_path[_patrol_path_index], delta)
    elif global_position.distance_to(target) <= float(WorldConfig.tile_size):
        _move_toward_direct(target, delta)


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
    var blocked_by_shield := archetype == "shieldbearer" and shield_behavior.blocks_hit_from(source_position)
    if blocked_by_shield:
        damage_multiplier *= shield_behavior.block_damage_multiplier
    var applied := maxi(1, roundi(float(amount) * damage_multiplier))
    hp -= applied
    if blocked_by_shield:
        Events.fx_burst.emit("stone", position + Vector2(0, -_fh * 0.4), -shield_behavior.brace_direction, 0.8)
    else:
        Events.fx_burst.emit("impact", position + Vector2(0, -_fh * 0.4), Vector2.ZERO, 2.0 if is_boss else 1.0)
    modulate = Color(1.8, 1.8, 1.8)
    create_tween().tween_property(self, "modulate", _faction_tint, 0.12)
    queue_redraw()
    if hp <= 0:
        remove_from_group("enemies")
        remove_from_group("enemy_garrison")
        remove_from_group("enemy_patrols")
        remove_from_group("ranged_enemies")
        remove_from_group("supply_raiders")
        remove_from_group("faction_raiders")
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
    remove_from_group("enemy_patrols")
    remove_from_group("ranged_enemies")
    remove_from_group("supply_raiders")
    remove_from_group("faction_raiders")
    queue_free()


func _draw() -> void:
    anim.draw(self, _tex, _fw, _fh)
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
