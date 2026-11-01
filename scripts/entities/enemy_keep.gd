extends Node2D
## Enemy stronghold and its persistent defensive garrison.

const ENEMY_SCRIPT := preload("res://scripts/entities/enemy.gd")
const SPRITE := preload("res://assets/sprites/enemy_keep.svg")
const TILE := 16
const SIZE := Vector2i(3, 3)
const MAX_HP := 900
const CLAIM_RADIUS := 9.0
const REINFORCE_INTERVAL := 105.0
const GUARD_DIRECTIONS: Array[Vector2i] = [
    Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
    Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
    Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(0, 2)
]
const GUARD_RINGS := [3, 4, 5]

var world
var flow
var player
var cell := Vector2i.ZERO
var size := SIZE
var hp := MAX_HP
var max_hp := MAX_HP
var claim_radius := CLAIM_RADIUS
var _reinforce_timer := REINFORCE_INTERVAL
var _spawn_index := 0


func setup(world_ref, flow_ref, player_ref, anchor: Vector2i, saved_hp := MAX_HP) -> void:
    world = world_ref
    flow = flow_ref
    player = player_ref
    cell = anchor
    size = SIZE
    max_hp = MAX_HP
    hp = clampi(saved_hp, 1, max_hp)
    position = Vector2((cell.x + size.x / 2.0) * TILE, (cell.y + size.y) * TILE)


func _ready() -> void:
    add_to_group("enemy_strongholds")
    z_index = 2


func cells() -> Array[Vector2i]:
    var out: Array[Vector2i] = []
    for y in size.y:
        for x in size.x:
            out.append(cell + Vector2i(x, y))
    return out


func export_state() -> Dictionary:
    return {
        "cx": cell.x,
        "cy": cell.y,
        "hp": hp,
        "destroyed": false,
        "reinforce_timer": _reinforce_timer,
        "spawn_index": _spawn_index
    }


func import_state(data: Dictionary) -> void:
    _reinforce_timer = clampf(float(data.get("reinforce_timer", REINFORCE_INTERVAL)), 0.0, REINFORCE_INTERVAL)
    _spawn_index = int(data.get("spawn_index", 0)) % GUARD_DIRECTIONS.size() * GUARD_RINGS.size()


func spawn_initial_garrison() -> void:
    for i in 3:
        _spawn_guard()


func _process(delta: float) -> void:
    if hp <= 0:
        return
    _reinforce_timer -= delta
    if _reinforce_timer > 0.0:
        return
    _reinforce_timer = REINFORCE_INTERVAL
    if get_tree().get_nodes_in_group("enemy_garrison").size() < 4:
        _spawn_guard()


func _spawn_guard() -> bool:
    var directions := GUARD_DIRECTIONS.size()
    var attempts := directions * GUARD_RINGS.size()
    var fortress_center := position + Vector2(0, -size.y * TILE / 2.0)
    for i in attempts:
        var slot := (_spawn_index + i) % attempts
        var ring_index := floori(float(slot) / directions)
        var direction: Vector2 = Vector2(GUARD_DIRECTIONS[slot % directions])
        var spawn_position := fortress_center + direction * float(GUARD_RINGS[ring_index] * TILE)
        var spawn_cell := Vector2i((spawn_position / TILE).floor())
        if not world.is_buildable(spawn_cell) or world.occupied.has(spawn_cell):
            continue
        if not flow.is_reachable(spawn_cell):
            continue
        _spawn_index = (slot + 1) % attempts
        var guard = ENEMY_SCRIPT.new()
        guard.setup_guard(DataDB.enemies["soldier"], world, flow, player, position)
        guard.position = spawn_position
        world.entities.add_child(guard)
        return true
    return false


func take_damage(amount: int) -> void:
    if hp <= 0:
        return
    hp = maxi(0, hp - amount)
    queue_redraw()
    Events.fx_burst.emit("debris", position + Vector2(0, -24), Vector2.ZERO, 1.4)
    Events.screen_shake.emit(1.2, 0.12)
    if hp > 0:
        return

    for occupied_cell in cells():
        if world.occupied.get(occupied_cell) == self:
            world.occupied.erase(occupied_cell)
    for guard in get_tree().get_nodes_in_group("enemy_garrison"):
        guard.retreat()
    remove_from_group("enemy_strongholds")
    Events.enemy_stronghold_destroyed.emit(cell)
    Events.campaign_won.emit(GameClock.day)
    Events.fx_burst.emit("puff", position + Vector2(0, -24), Vector2.ZERO, 3.0)
    Events.screen_shake.emit(2.8, 0.45)
    queue_free()


func _draw() -> void:
    draw_texture(SPRITE, Vector2(-SPRITE.get_width() / 2.0, -SPRITE.get_height()))
    var width := 46.0
    var y := -float(SPRITE.get_height()) - 6.0
    draw_rect(Rect2(-width / 2.0, y, width, 4), Color(0.04, 0.03, 0.03, 0.9))
    draw_rect(Rect2(-width / 2.0, y, width * float(hp) / max_hp, 4), Color("#a63d36"))
    draw_rect(Rect2(-width / 2.0, y, width, 4), Color("#e3ba84"), false, 1.0)
