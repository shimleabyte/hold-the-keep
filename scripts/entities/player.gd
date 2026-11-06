class_name Player
extends CharacterBody2D
## Pemain top-down. Origin node = kaki (untuk Y-sort).
## Animasi: idle, jalan, lari (tahan Shift), serang, panen, kena pukul. Damage serangan dan panen
## jatuh di frame benturan (bukan saat tombol ditekan).

const SpriteAnim := preload("res://scripts/entities/sprite_anim.gd")
const CombatVisualFeedback := preload("res://scripts/entities/combat_visual_feedback.gd")
const PlayerCombatFlow := preload("res://scripts/entities/player_combat_flow.gd")
const SPRITE := preload("res://assets/sprites/player.svg")
const FW: int = 24
const FH: int = 28

const SPEED := 70.0
const RUN_SPEED := 108.0
const INTERACT_RANGE := 22.0
const HIT_COOLDOWN := 0.3
const HARVEST_ANIM_FPS := 14.0
const HIT_DELAY := 0.14  # frame ke-3 pada 14 fps

const MAX_HP := 100
const ATTACK_RANGE := 24.0
const ATTACK_DAMAGE := 9
const ATTACK_ARC_MIN_DOT := 0.5 # 120-degree forward sector, matching the readable melee swing
const ATTACK_ARC_HALF_ANGLE := PI / 3.0
const CLEAVE_HALF_ANGLE := 1.2
const ATTACK_COOLDOWN := 0.45
const REGEN_DELAY := 4.0
const REGEN_PER_SEC := 3.0
const RESPAWN_INVULN := 2.0
const HURT_TIME := 0.2
const SWING_TIME := 0.28  # busur tebasan: dari aba-aba, melewati benturan, sampai pulih
const DASH_SPEED := 280.0
const DASH_DURATION := 0.22
const DASH_COOLDOWN := 5.5
const CLEAVE_COOLDOWN := 8.0
const RALLY_COOLDOWN := 18.0
const CLEAVE_RANGE := 56.0
const RALLY_RADIUS := 144.0
const MAX_LEVEL := 10
const XP_REWARDS := {"bandit": 10, "wolf": 9, "soldier": 20, "archer": 18, "brute": 32, "king": 150}

var camera: Camera2D
var facing := Vector2.DOWN
var _attack_direction := Vector2.DOWN
var _cleave_direction := Vector2.DOWN
var hp := MAX_HP
var spawn_pos := Vector2.ZERO
var anim := SpriteAnim.new()
var combat_feedback = CombatVisualFeedback.new()
var combat_flow = PlayerCombatFlow.new()

var _cooldown := 0.0
var _atk_cd := 0.0
var _swing := 0.0
var _invuln := 0.0
var _since_hit := 99.0
var _regen_acc := 0.0
var _build_mode := false
var _running := false
var _hurt_t := 0.0
var _pending_attack := -1.0
var _attack_profile: Dictionary = {}
var _pending_harvest = null
var _harvest_t := 0.0
var _harvest_anim_active := false
var _step_t := 0.0
var _shake_t := 0.0
var _shake_dur := 0.1
var _shake_s := 0.0
var level := 1
var experience := 0
var _dash_t := 0.0
var _dash_cd := 0.0
var _dash_elapsed := 0.0
var _perfect_dodge_registered := false
var _dash_can_perfect_dodge := false
var _dash_dir := Vector2.DOWN
var _cleave_pending := -1.0
var _cleave_t := 0.0
var _cleave_cd := 0.0
var _cleave_empowered := false
var _rally_cd := 0.0
var _rally_t := 0.0


func _ready() -> void:
    add_to_group("player")
    motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

    var shape := CircleShape2D.new()
    shape.radius = 4.0
    var col := CollisionShape2D.new()
    col.shape = shape
    col.position = Vector2(0, -4)
    add_child(col)

    camera = Camera2D.new()
    camera.position = Vector2(0, -8)
    camera.position_smoothing_enabled = true
    camera.position_smoothing_speed = 8.0
    add_child(camera)

    Events.build_selected.connect(_on_build_selected)
    Events.screen_shake.connect(_on_shake)
    Events.enemy_killed.connect(_on_enemy_killed)
    Events.player_hp_changed.emit(hp, MAX_HP)


func _on_build_selected(id: String) -> void:
    _build_mode = id != ""


func _on_shake(strength: float, duration: float) -> void:
    if not Settings.screen_shake:
        return
    var current := _shake_s * (_shake_t / _shake_dur) if _shake_t > 0.0 else 0.0
    if strength >= current:
        _shake_s = strength
        _shake_dur = maxf(duration, 0.01)
        _shake_t = duration


func _tick_shake(delta: float) -> void:
    if _shake_t > 0.0:
        _shake_t -= delta
        var k := maxf(_shake_t, 0.0) / _shake_dur
        camera.offset = Vector2(roundf(randf_range(-1.0, 1.0) * _shake_s * k), roundf(randf_range(-1.0, 1.0) * _shake_s * k))
    elif camera.offset != Vector2.ZERO:
        camera.offset = Vector2.ZERO


func set_camera_limits(rect: Rect2i) -> void:
    camera.limit_left = rect.position.x
    camera.limit_top = rect.position.y
    camera.limit_right = rect.end.x
    camera.limit_bottom = rect.end.y


func _physics_process(delta: float) -> void:
    if combat_feedback.advance(delta):
        queue_redraw()
    combat_flow.advance(delta)
    _cooldown = maxf(0.0, _cooldown - delta)
    _atk_cd = maxf(0.0, _atk_cd - delta)
    _dash_cd = maxf(0.0, _dash_cd - delta)
    _cleave_cd = maxf(0.0, _cleave_cd - delta)
    _rally_cd = maxf(0.0, _rally_cd - delta)
    _rally_t = maxf(0.0, _rally_t - delta)
    _invuln = maxf(0.0, _invuln - delta)
    _hurt_t = maxf(0.0, _hurt_t - delta)
    _since_hit += delta
    _regen(delta)
    if _swing > 0.0:
        _swing = maxf(0.0, _swing - delta)
        queue_redraw()
    if _cleave_t > 0.0:
        _cleave_t = maxf(0.0, _cleave_t - delta)
        if _cleave_t <= 0.0:
            _cleave_empowered = false
        queue_redraw()

    var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if _dash_t > 0.0:
        _dash_elapsed += delta
        var dash_step := minf(delta, _dash_t)
        _dash_t = maxf(0.0, _dash_t - delta)
        velocity = _dash_dir * DASH_SPEED * (dash_step / maxf(delta, 0.001))
        _running = true
        move_and_slide()
        if _dash_t <= 0.0:
            _finish_dash()
    else:
        _running = dir != Vector2.ZERO and Input.is_action_pressed("sprint")
        velocity = dir * (RUN_SPEED if _running else SPEED)
        if dir != Vector2.ZERO:
            facing = dir.normalized()
            if not anim.is_busy() and anim.face(dir):
                queue_redraw()
        move_and_slide()

    if _harvest_anim_active and not Input.is_action_pressed("interact"):
        _cancel_harvest_animation()
    if Input.is_action_pressed("interact") and _cooldown <= 0.0:
        _try_interact()
    if Input.is_action_pressed("attack") and _atk_cd <= 0.0 and _dash_t <= 0.0 and not _build_mode and not _click_on_hud():
        _attack()
    if not _build_mode:
        if Input.is_action_just_pressed("ability_dash"):
            activate_ability("dash")
        elif Input.is_action_just_pressed("ability_cleave"):
            activate_ability("cleave")
        elif Input.is_action_just_pressed("ability_rally"):
            activate_ability("rally")
    _tick_pending(delta)
    _update_anim(delta)
    _tick_shake(delta)
    _footsteps(delta)


func _footsteps(delta: float) -> void:
    if not _running or velocity.length() < 5.0:
        return
    _step_t -= delta
    if _step_t <= 0.0:
        _step_t = 0.11
        Events.fx_burst.emit("dust", global_position + Vector2(0, -1), -facing, 1.0)


func _update_anim(delta: float) -> void:
    if anim.is_busy():
        pass  # biarkan ayunan/panen selesai
    elif _hurt_t > 0.0:
        anim.play("hurt")
    elif velocity.length() > 5.0:
        anim.play("run" if _running else "walk")
    else:
        anim.play("idle")
    if anim.update(delta):
        queue_redraw()


func _cancel_harvest_animation() -> void:
    _harvest_anim_active = false
    _pending_harvest = null
    _harvest_t = 0.0
    if anim.clip == "work":
        anim.play("idle", true)
        queue_redraw()


func _tick_pending(delta: float) -> void:
    if _pending_attack >= 0.0:
        _pending_attack -= delta
        if _pending_attack < 0.0:
            _apply_attack()
    if _pending_harvest != null:
        _harvest_t -= delta
        if _harvest_t <= 0.0:
            var n = _pending_harvest
            _pending_harvest = null
            if is_instance_valid(n):
                if n.is_in_group("harvestable"):
                    Events.player_harvested.emit(n.yield_kind)
                    n.hit()
                elif n.is_in_group("clearable_resource_residues"):
                    n.clear_residue()
    if _cleave_pending >= 0.0:
        _cleave_pending -= delta
        if _cleave_pending < 0.0:
            _apply_cleave()

## Klik kiri di atas panel HUD tidak boleh jadi serangan (tombol F / gamepad tetap bisa).
func _click_on_hud() -> bool:
    if Input.is_physical_key_pressed(KEY_F) or Input.is_joy_button_pressed(0, JOY_BUTTON_X):
        return false
    var commander: ArmyCommand = get_tree().get_first_node_in_group("army_command_manager") as ArmyCommand
    if commander != null and commander.has_method("blocks_player_attack") and commander.blocks_player_attack():
        return true
    var hud := get_tree().get_first_node_in_group("hud")
    return hud != null and hud.blocks_mouse(get_viewport().get_mouse_position())


func _regen(delta: float) -> void:
    if hp >= MAX_HP or _since_hit < Tech.stat("player.regen_delay", REGEN_DELAY):
        return
    _regen_acc += Tech.stat("player.regen_rate", REGEN_PER_SEC) * delta
    if _regen_acc >= 1.0:
        var add := int(_regen_acc)
        _regen_acc -= add
        hp = mini(MAX_HP, hp + add)
        Events.player_hp_changed.emit(hp, MAX_HP)


func _nearest_enemy(max_dist: float) -> Node2D:
    var origin := global_position + Vector2(0, -4)
    var best: Node2D = null
    var best_d := max_dist
    for e in get_tree().get_nodes_in_group("enemies"):
        var n := e as Node2D
        var d := origin.distance_to(n.global_position + Vector2(0, -4))
        if d < best_d:
            best_d = d
            best = n
    return best


func _attack() -> void:
    _atk_cd = ATTACK_COOLDOWN
    var foe := _nearest_enemy(ATTACK_RANGE * 2.0)
    if foe != null:
        facing = (foe.global_position - global_position).normalized()
        anim.face(foe.global_position - global_position)

    _attack_direction = facing.normalized() if facing.length_squared() > 0.0001 else Vector2.DOWN
    _attack_profile = combat_flow.begin_attack()
    var hit_delay := float(_attack_profile.get("hit_delay", HIT_DELAY))
    var swing_time := float(_attack_profile.get("swing_time", SWING_TIME))
    var animation_fps := float(_attack_profile.get("animation_fps", 14.0))

    anim.play("attack", true, animation_fps)
    _pending_attack = hit_delay
    combat_feedback.begin_windup(_attack_direction, hit_delay, false)
    _swing = swing_time
    Events.player_attacked.emit()
    Events.fx_burst.emit("blade_trail", global_position + Vector2(0, -7), _attack_direction, 1.0)
    queue_redraw()


## A normal swing only connects inside the captured 120-degree forward-facing sector.
func _is_inside_attack_arc(
    origin: Vector2,
    target_position: Vector2,
    attack_direction: Vector2,
    max_range: float = ATTACK_RANGE,
    min_dot: float = ATTACK_ARC_MIN_DOT
) -> bool:
    var offset := target_position - origin
    var distance_squared := offset.length_squared()
    if distance_squared > max_range * max_range:
        return false
    if distance_squared <= 0.0001:
        return true
    var direction := attack_direction.normalized()
    if direction.length_squared() <= 0.0001:
        return false
    return offset.normalized().dot(direction) >= min_dot


## Resolve damage on the impact frame; enemies and objectives share the same attack sector.
func _apply_attack() -> void:
    combat_feedback.end_windup()
    var origin := global_position + Vector2(0, -6)
    var damage_scale := float(_attack_profile.get("damage_scale", 1.0))
    var reach := float(_attack_profile.get("reach", ATTACK_RANGE))
    var arc_min_dot := float(_attack_profile.get("arc_min_dot", ATTACK_ARC_MIN_DOT))
    var stagger := float(_attack_profile.get("stagger", 0.0))
    var resolve_per_hit := float(_attack_profile.get("resolve_on_hit", 0.0))
    var visual_kind := String(_attack_profile.get("visual", "quick"))
    var hit_count := 0

    for enemy in get_tree().get_nodes_in_group("enemies"):
        var foe := enemy as Node2D
        if not is_instance_valid(foe):
            continue
        if not _is_inside_attack_arc(
            origin,
            foe.global_position + Vector2(0, -4),
            _attack_direction,
            reach,
            arc_min_dot
        ):
            continue

        var hit_damage := maxi(1, roundi(float(_player_damage(ATTACK_DAMAGE)) * damage_scale))
        if foe.has_method("take_damage_from"):
            foe.take_damage_from(hit_damage, global_position)
        elif foe.has_method("take_damage"):
            foe.take_damage(hit_damage)

        if stagger > 0.0 and is_instance_valid(foe) and foe.has_method("apply_stagger"):
            foe.apply_stagger(stagger)
        Events.fx_burst.emit(
            "heavy_impact" if visual_kind == "finisher" or visual_kind == "riposte" else "impact",
            foe.global_position + Vector2(0, -6),
            _attack_direction,
            1.35 if visual_kind == "finisher" or visual_kind == "riposte" else 1.0
        )
        hit_count += 1

    var site_scale := damage_scale * Tech.stat("campaign.site_damage", 1.0)
    for target in get_tree().get_nodes_in_group("campaign_targets"):
        if not is_instance_valid(target):
            continue
        if not _is_inside_attack_arc(origin, target.global_position, _attack_direction, reach, arc_min_dot):
            continue
        var site_damage := roundi(float(_player_damage(ATTACK_DAMAGE)) * site_scale)
        target.take_damage(maxi(1, site_damage))

    var campaign = get_tree().get_first_node_in_group("campaign")
    for stronghold in get_tree().get_nodes_in_group("enemy_strongholds"):
        if not is_instance_valid(stronghold):
            continue
        if not _is_inside_attack_arc(origin, stronghold.global_position, _attack_direction, reach, arc_min_dot):
            continue
        if campaign != null and not campaign.is_current_objective(stronghold.stronghold_id):
            continue
        var stronghold_damage := roundi(float(_player_damage(ATTACK_DAMAGE)) * site_scale)
        stronghold.take_damage(maxi(1, stronghold_damage))

    if hit_count > 0:
        combat_flow.add_resolve(minf(resolve_per_hit * float(mini(hit_count, 3)), 28.0))
        if visual_kind == "finisher" or visual_kind == "riposte":
            Events.screen_shake.emit(0.42, 0.08)
            Audio.play("impact_hit", 1.1, -4.0)

    queue_redraw()


func activate_ability(id: String) -> bool:
    match id:
        "dash":
            return _use_dash()
        "cleave":
            return _use_cleave()
        "rally":
            return _use_rally()
    return false


func _use_dash() -> bool:
    if _dash_cd > 0.0:
        return false
    var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    _dash_dir = input_dir.normalized() if input_dir != Vector2.ZERO else facing.normalized()
    if _dash_dir == Vector2.ZERO:
        _dash_dir = Vector2.DOWN
    _dash_cd = DASH_COOLDOWN
    _dash_t = DASH_DURATION
    _dash_elapsed = 0.0
    _perfect_dodge_registered = false
    _dash_can_perfect_dodge = _invuln <= 0.0
    combat_feedback.register_ability("dash", _dash_dir, DASH_DURATION + 0.08)
    Audio.play("dash", 1.0, -5.0)
    _invuln = maxf(_invuln, DASH_DURATION + 0.12)
    _pending_attack = -1.0
    combat_feedback.end_windup()
    _pending_harvest = null
    _harvest_anim_active = false
    facing = _dash_dir
    anim.face(_dash_dir)
    anim.play("run", true, 18.0)
    _swing = 0.0
    Events.fx_burst.emit("dash", global_position + Vector2(0, -2), -_dash_dir, 1.5)
    queue_redraw()
    return true


func _finish_dash() -> void:
    var origin := global_position + Vector2(0, -5)
    for e in get_tree().get_nodes_in_group("enemies"):
        var foe := e as Node2D
        if origin.distance_to(foe.global_position + Vector2(0, -4)) <= 22.0:
            var hit_damage := _player_damage(14 + level * 2)
            if foe.has_method("take_damage_from"):
                foe.take_damage_from(hit_damage, global_position)
            else:
                foe.take_damage(hit_damage)
            if foe.has_method("apply_stagger"):
                foe.apply_stagger(0.38)
    _dash_can_perfect_dodge = false
    Events.fx_burst.emit("dash_impact", global_position + Vector2(0, -2), _dash_dir, 1.0)
    queue_redraw()


func _use_cleave() -> bool:
    if level < 2 or _cleave_cd > 0.0:
        return false
    var foe := _nearest_enemy(100.0)
    if foe != null:
        facing = (foe.global_position - global_position).normalized()
        anim.face(facing)
    _cleave_direction = facing.normalized() if facing.length_squared() > 0.0001 else Vector2.DOWN
    _cleave_cd = CLEAVE_COOLDOWN
    _cleave_empowered = combat_flow.try_spend_resolve(60.0)
    _cleave_pending = 0.22
    _cleave_t = 0.46
    combat_feedback.register_ability(
        "cleave_empowered" if _cleave_empowered else "cleave",
        _cleave_direction,
        _cleave_t
    )
    Audio.play("cleave", 1.0 if not _cleave_empowered else 0.88, -5.0)
    _pending_attack = -1.0
    _swing = 0.0
    combat_feedback.end_windup()
    anim.play("attack", true, 12.0 if _cleave_empowered else 14.0)
    Events.player_attacked.emit()
    Events.fx_burst.emit(
        "cleave_charge",
        global_position + Vector2(0, -7),
        _cleave_direction,
        1.0 if not _cleave_empowered else 1.8
    )
    queue_redraw()
    return true


func _apply_cleave() -> void:
    var origin := global_position + Vector2(0, -6)
    var radius := CLEAVE_RANGE + (14.0 if _cleave_empowered else 0.0)
    var damage_scale := 1.0 if not _cleave_empowered else 1.55
    var stagger_duration := 0.55 if not _cleave_empowered else 0.88

    for enemy in get_tree().get_nodes_in_group("enemies"):
        var foe := enemy as Node2D
        if not is_instance_valid(foe):
            continue
        var to_foe := foe.global_position + Vector2(0, -4) - origin
        if to_foe.length() > radius:
            continue
        if to_foe.length_squared() > 0.01 and to_foe.normalized().dot(_cleave_direction) < cos(CLEAVE_HALF_ANGLE):
            continue

        var hit_damage := maxi(1, roundi(float(_player_damage(20 + level * 3)) * damage_scale))
        if foe.has_method("take_damage_from"):
            foe.take_damage_from(hit_damage, global_position)
        elif foe.has_method("take_damage"):
            foe.take_damage(hit_damage)
        if is_instance_valid(foe) and foe.has_method("apply_stagger"):
            foe.apply_stagger(stagger_duration)

        Events.fx_burst.emit(
            "heavy_impact" if _cleave_empowered else "impact",
            foe.global_position + Vector2(0, -6),
            _cleave_direction,
            1.6 if _cleave_empowered else 1.1
        )

    if _cleave_empowered:
        Events.fx_burst.emit("heavy_impact", global_position + Vector2(0, -7), _cleave_direction, 2.0)
    Events.screen_shake.emit(1.0 if _cleave_empowered else 0.8, 0.13 if _cleave_empowered else 0.1)
    queue_redraw()


func _use_rally() -> bool:
    if level < 3 or _rally_cd > 0.0:
        return false
    _rally_cd = RALLY_COOLDOWN
    _rally_t = 8.0
    anim.play("idle", true)
    combat_feedback.register_ability("rally", Vector2.ZERO, 0.35)
    Audio.play("rally", 1.0, -5.0)
    var affected := 0
    for defender in get_tree().get_nodes_in_group("defenders"):
        if not is_instance_valid(defender):
            continue
        if global_position.distance_to(defender.global_position) <= RALLY_RADIUS:
            defender.apply_rally(8.0, 1.5, 0.78)
            Events.fx_burst.emit("rally", defender.global_position + Vector2(0, -7), Vector2.ZERO, 0.35)
            affected += 1
    Events.fx_burst.emit("rally", global_position + Vector2(0, -8), Vector2.ZERO, 2.8)
    Events.build_feedback.emit("SERUAN PERANG: %d prajurit diperkuat" % affected)
    return true


func _register_perfect_dodge(source_position: Vector2) -> void:
    if _perfect_dodge_registered or not _dash_can_perfect_dodge:
        return
    if _dash_elapsed > 0.16 or source_position == Vector2.ZERO:
        return

    _perfect_dodge_registered = true
    combat_flow.register_perfect_dodge()
    combat_feedback.register_ability("riposte", (global_position - source_position).normalized(), 0.58)
    Events.fx_burst.emit(
        "perfect_dodge",
        global_position + Vector2(0, -7),
        (global_position - source_position).normalized(),
        1.7
    )
    Audio.play("block", 1.15, -4.0)
    queue_redraw()


func _player_damage(base_damage: int) -> int:
    var base := float(base_damage + maxi(0, level - 1))
    var damage_value := Tech.stat("player.damage", base)
    if _rally_t > 0.0:
        damage_value *= 1.25
    return maxi(1, roundi(damage_value))


func _on_enemy_killed(enemy_id: String) -> void:
    gain_experience(int(XP_REWARDS.get(enemy_id, 8)))


func _xp_to_next() -> int:
    return 50 + maxi(0, level - 1) * 25


func gain_experience(amount: int) -> void:
    if amount <= 0 or level >= MAX_LEVEL:
        return
    experience += amount
    while level < MAX_LEVEL and experience >= _xp_to_next():
        experience -= _xp_to_next()
        level += 1
        hp = mini(MAX_HP, hp + 18)
        Events.player_hp_changed.emit(hp, MAX_HP)
        Events.event_triggered.emit("NAIK LEVEL", "Level %d — kemampuan tempur meningkat" % level)
    if level >= MAX_LEVEL:
        experience = 0


func combat_status() -> Dictionary:
    var flow_status: Dictionary = combat_flow.status()
    return {
        "level": level,
        "xp": experience,
        "next_xp": _xp_to_next() if level < MAX_LEVEL else 0,
        "dash_cd": _dash_cd,
        "cleave_cd": _cleave_cd,
        "rally_cd": _rally_cd,
        "cleave_unlocked": level >= 2,
        "rally_unlocked": level >= 3,
        "resolve": float(flow_status.get("resolve", 0.0)),
        "resolve_max": float(flow_status.get("resolve_max", 100.0)),
        "combo_step": int(flow_status.get("combo_step", 0)),
        "riposte_ready": bool(flow_status.get("riposte_ready", false)),
        "riposte_remaining": float(flow_status.get("riposte_remaining", 0.0)),
        "cleave_empowered_ready": bool(flow_status.get("cleave_empowered_ready", false))
    }


func export_combat_state() -> Dictionary:
    return {"level": level, "xp": experience}


func import_combat_state(data: Dictionary) -> void:
    level = clampi(int(data.get("level", 1)), 1, MAX_LEVEL)
    experience = maxi(0, int(data.get("xp", 0)))
    if level >= MAX_LEVEL:
        experience = 0
    else:
        experience = mini(experience, _xp_to_next() - 1)


func take_damage(amount: int) -> void:
    take_damage_from(amount, Vector2.ZERO)


func take_damage_from(amount: int, source_position: Vector2) -> void:
    if _invuln > 0.0 or hp <= 0:
        if hp > 0 and _dash_t > 0.0 and _dash_can_perfect_dodge and _invuln > 0.0:
            _register_perfect_dodge(source_position)
        return
    hp -= amount
    _since_hit = 0.0
    if hp > 0:
        combat_feedback.register_hit(source_position, global_position, 1.0)
    Events.fx_burst.emit("hurt", global_position + Vector2(0, -8), Vector2.ZERO, 1.0)
    Events.screen_shake.emit(1.0, 0.1)
    _hurt_t = HURT_TIME
    modulate = Color(1.6, 0.6, 0.6)
    create_tween().tween_property(self, "modulate", Color.WHITE, 0.2)
    if hp <= 0:
        _die()
    Events.player_hp_changed.emit(maxi(hp, 0), MAX_HP)


func _die() -> void:
    hp = MAX_HP
    global_position = spawn_pos
    velocity = Vector2.ZERO
    _invuln = RESPAWN_INVULN
    _pending_attack = -1.0
    combat_feedback.end_windup()
    _pending_harvest = null
    _harvest_anim_active = false
    _cleave_pending = -1.0
    _dash_t = 0.0
    _rally_t = 0.0
    _dash_can_perfect_dodge = false
    _cleave_empowered = false
    combat_flow.reset()
    anim.play("idle", true)
    Events.build_feedback.emit("Kamu tumbang! Kembali ke keep")
    Events.player_hp_changed.emit(hp, MAX_HP)


func _try_interact() -> void:
    var origin := global_position + Vector2(0, -4)
    var nearest_site: Node2D = null
    var site_distance := INTERACT_RANGE
    for candidate in get_tree().get_nodes_in_group("frontier_sites"):
        if not is_instance_valid(candidate):
            continue
        var distance := origin.distance_to(candidate.global_position + Vector2(0, -4))
        if distance < site_distance:
            nearest_site = candidate
            site_distance = distance
    if nearest_site != null and nearest_site.has_method("interact"):
        _cooldown = 0.45
        nearest_site.interact()
        return
    var nearest_camp: Node2D = null
    var camp_distance := INTERACT_RANGE
    for candidate in get_tree().get_nodes_in_group("faction_camp_targets"):
        if not is_instance_valid(candidate) or not candidate.visible:
            continue
        var distance := origin.distance_to(candidate.global_position + Vector2(0, -4))
        if distance < camp_distance:
            nearest_camp = candidate
            camp_distance = distance
    if nearest_camp != null and nearest_camp.has_method("interact"):
        _cooldown = 0.45
        nearest_camp.interact()
        return
    var best: Node2D = null
    var best_dist := INTERACT_RANGE
    for group_name in ["harvestable", "clearable_resource_residues"]:
        for n in get_tree().get_nodes_in_group(group_name):
            var node := n as Node2D
            var distance := origin.distance_to(node.global_position + Vector2(0, -4))
            if distance < best_dist:
                best_dist = distance
                best = node
    if best != null:
        _cooldown = HIT_COOLDOWN
        facing = (best.global_position - global_position).normalized()
        anim.face(best.global_position - global_position)
        anim.play("work", true, HARVEST_ANIM_FPS)
        _harvest_anim_active = true
        _pending_harvest = best
        _harvest_t = HIT_DELAY
        queue_redraw()
    else:
        if _harvest_anim_active:
            _cancel_harvest_animation()
        for n in get_tree().get_nodes_in_group("ore_locked"):
            if origin.distance_to((n as Node2D).global_position + Vector2(0, -4)) < INTERACT_RANGE:
                _cooldown = 0.8
                Events.build_feedback.emit("Butuh teknologi: " + Tech.tech_name("iron_mining"))
                break

func _draw() -> void:
    _draw_dash_afterimages()
    anim.draw(self, SPRITE, FW, FH)
    combat_feedback.draw(self, FH, Color("#c8caa0"))
    if _swing > 0.0:
        _draw_slash()
    if _cleave_t > 0.0:
        _draw_cleave()


func _draw_dash_afterimages() -> void:
    if _dash_t <= 0.0:
        return
    var progress := clampf(1.0 - _dash_t / DASH_DURATION, 0.0, 1.0)
    var frame_rect := Rect2(anim.frame_index() * FW, anim.view * FH, FW, FH)
    var mirror := Vector2(-1.0, 1.0) if anim.flip and anim.view == SpriteAnim.SIDE else Vector2.ONE
    for echo in range(3, 0, -1):
        var fade := (1.0 - float(echo) / 4.0) * (1.0 - progress * 0.35)
        var offset := anim.motion_offset() - _dash_dir * float(echo * 5)
        draw_set_transform(offset, 0.0, mirror)
        draw_texture_rect_region(
            SPRITE,
            Rect2(-FW / 2.0, -FH, FW, FH),
            frame_rect,
            Color(0.62, 0.79, 0.76, fade * 0.72)
        )
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_cleave() -> void:
    var progress := 1.0 - _cleave_t / 0.46
    var radius := (CLEAVE_RANGE + (14.0 if _cleave_empowered else 0.0)) * (0.68 + progress * 0.32)
    var base := _cleave_direction.angle()
    var fade := 1.0 - maxf(0.0, progress - 0.72) / 0.28
    var tint := Color("#ffe8a0") if _cleave_empowered else Color("#eab65c")
    for trail in range(10):
        var angle := lerpf(-CLEAVE_HALF_ANGLE, CLEAVE_HALF_ANGLE, progress) - float(trail) * 0.17
        var alpha := (1.0 - float(trail) / 10.0) * fade
        draw_arc(
            Vector2(0, -6),
            radius - float(trail) * (1.0 if _cleave_empowered else 0.6),
            base + angle - 0.18,
            base + angle,
            7,
            Color(tint.r, tint.g, tint.b, alpha),
            2.0 if trail < 3 else 1.0
        )
    if _cleave_empowered:
        draw_arc(Vector2(0, -6), radius * 0.72, base - 0.9, base + 0.9,
            12, Color(1.0, 0.92, 0.66, fade * 0.8), 1.0)


## Weapon-specific trails use the same low-cost draw primitives and existing sprite.
func _draw_slash() -> void:
    var swing_time := maxf(0.001, float(_attack_profile.get("swing_time", SWING_TIME)))
    var t := clampf(1.0 - _swing / swing_time, 0.0, 1.0)
    var visual := String(_attack_profile.get("visual", "quick"))
    var half_angle := float(_attack_profile.get("draw_half_angle", ATTACK_ARC_HALF_ANGLE))
    var reach := float(_attack_profile.get("reach", ATTACK_RANGE))
    var base := _attack_direction.angle()
    var head := lerpf(-half_angle, half_angle, t)
    var center := Vector2(0, -6)
    var fade := 1.0 - maxf(0.0, t - 0.68) / 0.32
    var trail_count := 5 if visual == "quick" else 7
    var trail_gap := 0.19 if visual == "quick" else 0.23
    var tint := Color("#fff2d5")
    if visual == "finisher":
        tint = Color("#ffd078")
    elif visual == "riposte":
        tint = Color("#e8f3d2")

    for trail in trail_count:
        var angle := head - float(trail) * trail_gap
        var alpha := (1.0 - float(trail) / float(trail_count)) * fade
        draw_arc(
            center,
            reach - float(trail) * (0.55 if visual == "quick" else 0.85),
            base + angle - 0.22,
            base + angle,
            7,
            Color(tint.r, tint.g, tint.b, alpha * 0.94),
            2.0 if trail < 2 else 1.0
        )

    if visual == "cross":
        var cross_angle := base - 0.42 + t * 0.84
        draw_arc(center, reach * 0.78, cross_angle - 0.42, cross_angle + 0.14,
            8, Color(1.0, 0.78, 0.43, fade * 0.72), 1.0)
    elif visual == "finisher" or visual == "riposte":
        draw_arc(center, reach * 0.72, base - half_angle * 0.8, base + half_angle * 0.8,
            10, Color(1.0, 0.88, 0.62, fade * 0.8), 1.5)
        var tip := center + Vector2.RIGHT.rotated(base) * reach
        var side := Vector2.RIGHT.rotated(base + PI * 0.5) * 5.0
        draw_line(tip - side, tip + side, Color(1.0, 0.91, 0.72, fade), 1.5)
