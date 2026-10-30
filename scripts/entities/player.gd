extends CharacterBody2D
## Pemain top-down. Origin node = kaki (untuk Y-sort).
## Animasi: idle, jalan, lari (tahan Shift), serang, panen, kena pukul. Damage serangan dan panen
## jatuh di frame benturan (bukan saat tombol ditekan).

const SpriteAnim := preload("res://scripts/entities/sprite_anim.gd")
const SPRITE := preload("res://assets/sprites/player.svg")
const FW := 20
const FH := 20

const SPEED := 70.0
const RUN_SPEED := 108.0
const INTERACT_RANGE := 22.0
const HIT_COOLDOWN := 0.3
const HARVEST_ANIM_FPS := 14.0
const HIT_DELAY := 0.14  # frame ke-3 pada 14 fps

const MAX_HP := 100
const ATTACK_RANGE := 24.0
const ATTACK_DAMAGE := 9
const ATTACK_COOLDOWN := 0.45
const REGEN_DELAY := 4.0
const REGEN_PER_SEC := 3.0
const RESPAWN_INVULN := 2.0
const HURT_TIME := 0.2
const SWING_TIME := 0.28  # busur tebasan: dari aba-aba, melewati benturan, sampai pulih

var camera: Camera2D
var facing := Vector2.DOWN
var hp := MAX_HP
var spawn_pos := Vector2.ZERO
var anim := SpriteAnim.new()

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
var _pending_harvest = null
var _harvest_t := 0.0
var _step_t := 0.0
var _shake_t := 0.0
var _shake_dur := 0.1
var _shake_s := 0.0


func _ready() -> void:
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
    _cooldown = maxf(0.0, _cooldown - delta)
    _atk_cd = maxf(0.0, _atk_cd - delta)
    _invuln = maxf(0.0, _invuln - delta)
    _hurt_t = maxf(0.0, _hurt_t - delta)
    _since_hit += delta
    _regen(delta)
    if _swing > 0.0:
        _swing = maxf(0.0, _swing - delta)
        queue_redraw()

    var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    _running = dir != Vector2.ZERO and Input.is_action_pressed("sprint")
    velocity = dir * (RUN_SPEED if _running else SPEED)
    if dir != Vector2.ZERO:
        facing = dir.normalized()
        if not anim.is_busy() and anim.face(dir):
            queue_redraw()
    move_and_slide()

    if Input.is_action_pressed("interact") and _cooldown <= 0.0:
        _try_interact()
    if Input.is_action_pressed("attack") and _atk_cd <= 0.0 and not _build_mode and not _click_on_hud():
        _attack()
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
            if is_instance_valid(n) and n.is_in_group("harvestable"):
                Events.player_harvested.emit(n.yield_kind)
                n.hit()


## Klik kiri di atas panel HUD tidak boleh jadi serangan (tombol F / gamepad tetap bisa).
func _click_on_hud() -> bool:
    if Input.is_physical_key_pressed(KEY_F) or Input.is_joy_button_pressed(0, JOY_BUTTON_X):
        return false
    var hud := get_tree().get_first_node_in_group("hud")
    return hud != null and hud.blocks_mouse(get_viewport().get_mouse_position())


func _regen(delta: float) -> void:
    if hp >= MAX_HP or _since_hit < REGEN_DELAY:
        return
    _regen_acc += REGEN_PER_SEC * delta
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
    anim.play("attack", true)
    _pending_attack = HIT_DELAY
    _swing = SWING_TIME
    Events.player_attacked.emit()
    queue_redraw()


## Dipanggil di frame benturan: kena semua musuh dalam jangkauan.
func _apply_attack() -> void:
    var origin := global_position + Vector2(0, -6)
    for e in get_tree().get_nodes_in_group("enemies"):
        var n := e as Node2D
        if origin.distance_to(n.global_position + Vector2(0, -4)) <= ATTACK_RANGE:
            n.take_damage(roundi(Tech.stat("player.damage", float(ATTACK_DAMAGE))))
    queue_redraw()


func take_damage(amount: int) -> void:
    if _invuln > 0.0 or hp <= 0:
        return
    hp -= amount
    _since_hit = 0.0
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
    _pending_harvest = null
    anim.play("idle", true)
    Events.build_feedback.emit("Kamu tumbang! Kembali ke keep")
    Events.player_hp_changed.emit(hp, MAX_HP)


func _try_interact() -> void:
    var origin := global_position + Vector2(0, -4)
    var best: Node2D = null
    var best_dist := INTERACT_RANGE
    for n in get_tree().get_nodes_in_group("harvestable"):
        var node := n as Node2D
        var d := origin.distance_to(node.global_position + Vector2(0, -4))
        if d < best_dist:
            best_dist = d
            best = node
    if best != null:
        _cooldown = HIT_COOLDOWN
        facing = (best.global_position - global_position).normalized()
        anim.face(best.global_position - global_position)
        anim.play("work", true, HARVEST_ANIM_FPS)
        _pending_harvest = best
        _harvest_t = HIT_DELAY
        queue_redraw()
    else:
        for n in get_tree().get_nodes_in_group("ore_locked"):
            if origin.distance_to((n as Node2D).global_position + Vector2(0, -4)) < INTERACT_RANGE:
                _cooldown = 0.8
                Events.build_feedback.emit("Butuh teknologi: " + Tech.tech_name("iron_mining"))
                break


func _draw() -> void:
    anim.draw(self, SPRITE, FW, FH)
    if _swing > 0.0:
        _draw_slash()


## Busur tebasan: menyapu dari belakang ke depan lalu ke sisi lain, dengan ekor memudar.
func _draw_slash() -> void:
    var t := 1.0 - _swing / SWING_TIME
    var base := facing.angle()
    var head := lerpf(-1.9, 1.9, t)
    var center := Vector2(0, -6)
    var fade := 1.0 - maxf(0.0, t - 0.7) / 0.3
    for i in 7:
        var a1 := head - i * 0.26
        var alpha := (1.0 - i / 7.0) * fade
        draw_arc(center, ATTACK_RANGE * 0.85, base + a1 - 0.26, base + a1, 5, Color(1, 1, 1, alpha * 0.9), 2.0 if i < 3 else 1.0)
