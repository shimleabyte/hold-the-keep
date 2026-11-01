extends Node2D
## Musuh: mengikuti flow field ke keep, menyerang bangunan yang menghalangi
## dan pemain/prajurit yang terlalu dekat. Origin node = kaki (untuk Y-sort).
## Animasi: idle, jalan/lari, serang (damage jatuh di frame benturan), kena pukul, mati.

const SpriteAnim := preload("res://scripts/entities/sprite_anim.gd")
const Corpse := preload("res://scripts/entities/corpse.gd")
const TILE := 16
const TEXTURES := {
    "bandit": preload("res://assets/sprites/enemy_bandit.svg"),
    "wolf": preload("res://assets/sprites/enemy_wolf.svg"),
    "soldier": preload("res://assets/sprites/enemy_soldier.svg"),
    "king": preload("res://assets/sprites/enemy_king.svg"),
}
const PLAYER_REACH := 12.0
const ATTACK_HIT_DELAY := 0.14  # frame ke-3 pada 14 fps
const HURT_TIME := 0.18
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
var guard_origin := Vector2.ZERO

var world
var flow
var player

var anim := SpriteAnim.new()

var _offset := Vector2.ZERO
var _atk_cd := 0.0
var _moving := false
var _step_t := 0.0
var _hurt_t := 0.0
var _pending = null
var _pending_t := 0.0
var _tex: Texture2D
var _fw := 20
var _fh := 20


func setup(data: Dictionary, world_ref, flow_ref, player_ref) -> void:
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
    world = world_ref
    flow = flow_ref
    player = player_ref
    _offset = Vector2(randf_range(-4.0, 4.0), randf_range(-3.0, 3.0))
    _tex = TEXTURES.get(id, TEXTURES["bandit"])
    _fw = int(_tex.get_width() / float(SpriteAnim.FRAMES))
    _fh = int(_tex.get_height() / 3.0)


func setup_guard(data: Dictionary, world_ref, flow_ref, player_ref, origin: Vector2) -> void:
    setup(data, world_ref, flow_ref, player_ref)
    is_garrison = true
    guard_origin = origin


func _ready() -> void:
    add_to_group("enemies")
    if is_garrison:
        add_to_group("enemy_garrison")
    anim.view = SpriteAnim.SIDE


func _physics_process(delta: float) -> void:
    _atk_cd = maxf(0.0, _atk_cd - delta)
    _hurt_t = maxf(0.0, _hurt_t - delta)
    _resolve_pending(delta)
    _update_anim(delta)
    _footsteps(delta)
    _moving = false

    if is_garrison:
        _tick_garrison(delta)
        return

    if player != null and is_instance_valid(player):
        if position.distance_to(player.position) < PLAYER_REACH:
            _begin_attack(player, player.position - position)
            return

    for d in get_tree().get_nodes_in_group("defenders"):
        var dn := d as Node2D
        if dn.visible and position.distance_to(dn.position) < PLAYER_REACH:
            _begin_attack(dn, dn.position - position)
            return

    var cell := Vector2i((position / TILE).floor())
    var nxt: Vector2i = flow.next_cell(cell)

    if nxt == cell:
        # Tidak ada jalur: jalan lurus ke keep sebagai cadangan.
        _move_toward(flow.target_pos, delta)
        return

    var occ = world.occupied.get(nxt)
    if occ != null and is_instance_valid(occ) and occ.is_in_group("buildings"):
        _begin_attack(occ, occ.position - position)
        return

    _move_toward(Vector2(nxt) * TILE + Vector2(TILE / 2.0, TILE / 2.0) + _offset, delta)


## Mulai ayunan jika serangan siap; damage jatuh ATTACK_HIT_DELAY kemudian (frame benturan).
func _tick_garrison(delta: float) -> void:
    var target := _nearest_guard_target()
    if target != null:
        var distance := position.distance_to(target.position)
        if distance <= PLAYER_REACH:
            _begin_attack(target, target.position - position)
            return
        if position.distance_to(guard_origin) <= 150.0:
            _move_toward(target.position, delta)
        else:
            _move_toward(guard_origin, delta)
    elif position.distance_to(guard_origin) > 16.0:
        _move_toward(guard_origin, delta)


func _nearest_guard_target() -> Node2D:
    var best: Node2D = null
    var best_distance := 150.0
    var candidates := get_tree().get_nodes_in_group("defenders")
    if player != null and is_instance_valid(player):
        candidates.append(player)
    for candidate in candidates:
        var node := candidate as Node2D
        if not is_instance_valid(node) or not node.visible:
            continue
        if node.global_position.distance_to(guard_origin) > 175.0:
            continue
        var distance := position.distance_to(node.global_position)
        if distance < best_distance:
            best_distance = distance
            best = node
    return best


func _begin_attack(target, dir: Vector2) -> void:
    if _atk_cd > 0.0:
        return
    _atk_cd = attack_interval
    _pending = target
    _pending_t = ATTACK_HIT_DELAY
    if anim.face(dir):
        queue_redraw()
    anim.play("attack", true)


func _resolve_pending(delta: float) -> void:
    if _pending == null:
        return
    _pending_t -= delta
    if _pending_t > 0.0:
        return
    var t = _pending
    _pending = null
    if is_instance_valid(t):
        t.take_damage(damage)


## Debu di kaki saat berlari (serigala) dan langkah berat raja.
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
        pass  # biarkan ayunan selesai
    elif _hurt_t > 0.0:
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
    var dist := to.length()
    if anim.face(to):
        queue_redraw()
    if dist > 0.5:
        _moving = true
        position += to / dist * minf(speed * delta, dist)


func take_damage(amount: int) -> void:
    if hp <= 0:
        return
    hp -= amount
    Events.fx_burst.emit("spark", position + Vector2(0, -_fh * 0.4), Vector2.ZERO, 2.0 if is_boss else 1.0)
    modulate = Color(1.8, 1.8, 1.8)
    create_tween().tween_property(self, "modulate", Color.WHITE, 0.12)
    queue_redraw()
    if hp <= 0:
        remove_from_group("enemies")
        remove_from_group("enemy_garrison")
        Events.enemy_killed.emit(id)
        if is_boss:
            Events.game_won.emit(GameClock.day)
        Events.fx_burst.emit("puff" if is_boss else "dust", position + Vector2(0, -2), Vector2.ZERO, 2.0 if is_boss else 1.5)
        if is_boss:
            Events.screen_shake.emit(3.0, 0.6)
        Corpse.spawn(get_parent(), _tex, _fw, _fh, anim.view, anim.flip, position)
        queue_free()
    elif not is_boss and not (anim.clip == "attack" and not anim.finished):
        _hurt_t = HURT_TIME


func retreat() -> void:
    if is_boss or is_garrison:
        return  # raja dan penjaga benteng tidak mundur saat fajar
    remove_from_group("enemies")
    queue_free()


func _draw() -> void:
    anim.draw(self, _tex, _fw, _fh)
    if hp < max_hp:
        var w := 10.0 * (3.0 if is_boss else 1.0)
        var y := -(_fh - roundi(0.2 * _fh)) - 4.0
        draw_rect(Rect2(-w / 2, y, w, 2), Color(0, 0, 0, 0.7))
        draw_rect(Rect2(-w / 2, y, w * float(hp) / max_hp, 2), Color("#e8483c"))
