class_name EnemyKeep
extends Node2D
## Enemy stronghold and its persistent defensive garrison.

const ENEMY_SCRIPT: Script = preload("res://scripts/entities/enemy.gd")
const SPRITE: Texture2D = preload("res://assets/sprites/enemy_keep.svg")
const CIVILIZATION_SCRIPT: Script = preload("res://scripts/systems/enemy_civilization.gd")
const SIZE: Vector2i = Vector2i(3, 3)
const MAX_HP: int = 900
const CLAIM_RADIUS: float = 9.0
const REINFORCE_INTERVAL: float = 105.0
const GUARD_DIRECTIONS: Array[Vector2i] = [
    Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
    Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
    Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(0, 2)
]
const GUARD_RINGS: Array[int] = [3, 4, 5]

var world: WorldMap
var flow: FlowField
var player: Player
var cell: Vector2i = Vector2i.ZERO
var size: Vector2i = SIZE
var hp: int = MAX_HP
var max_hp: int = MAX_HP
var claim_radius: float = CLAIM_RADIUS
var stronghold_id: String = "classic_enemy_keep"
var region_id: String = "HEARTHLAND"
var faction_id: String = "classic_raiders"
var _reinforce_timer: float = REINFORCE_INTERVAL
var _spawn_index: int = 0
var _initial_garrison_pending: bool = false
var civilization: EnemyCivilization
var _saved_civilization_state: Dictionary = {}


func setup(world_ref: WorldMap, flow_ref: FlowField, player_ref: Player, anchor: Vector2i, saved_hp: int = MAX_HP, identity: Dictionary = {}) -> void:
    world = world_ref
    flow = flow_ref
    player = player_ref
    cell = anchor
    size = SIZE
    stronghold_id = String(identity.get("id", "classic_enemy_keep"))
    region_id = String(identity.get("region", "HEARTHLAND"))
    faction_id = String(identity.get("faction", "classic_raiders"))
    max_hp = MAX_HP
    hp = clampi(saved_hp, 1, max_hp)
    position = Vector2((cell.x + size.x / 2.0) * WorldConfig.tile_size, (cell.y + size.y) * WorldConfig.tile_size)


func _ready() -> void:
    add_to_group("enemy_strongholds")
    z_index = 2
    civilization = CIVILIZATION_SCRIPT.new()
    civilization.setup(self, _saved_civilization_state)


func cells() -> Array[Vector2i]:
    var out: Array[Vector2i] = []
    for y in size.y:
        for x in size.x:
            out.append(cell + Vector2i(x, y))
    return out


func export_state() -> Dictionary:
    return {
        "id": stronghold_id,
        "region": region_id,
        "faction": faction_id,
        "cx": cell.x,
        "cy": cell.y,
        "hp": hp,
        "destroyed": false,
        "reinforce_timer": _reinforce_timer,
        "spawn_index": _spawn_index,
        "civilization": civilization.export_state() if civilization != null else _saved_civilization_state.duplicate(true)
    }


func import_state(data: Dictionary) -> void:
    stronghold_id = String(data.get("id", stronghold_id))
    region_id = String(data.get("region", region_id))
    faction_id = String(data.get("faction", faction_id))
    _reinforce_timer = clampf(float(data.get("reinforce_timer", REINFORCE_INTERVAL)), 0.0, REINFORCE_INTERVAL)
    _spawn_index = posmod(int(data.get("spawn_index", 0)), GUARD_DIRECTIONS.size() * GUARD_RINGS.size())
    var saved_civilization: Dictionary = data.get("civilization", {})
    _saved_civilization_state = saved_civilization.duplicate(true) if saved_civilization is Dictionary else {}


func spawn_initial_garrison() -> void:
    if flow != null and flow.has_method("is_current") and not flow.is_current():
        _initial_garrison_pending = true
        var callback: Callable = Callable(self, "_on_flow_field_rebuilt")
        if not flow.rebuilt.is_connected(callback):
            flow.rebuilt.connect(callback)
        return
    _spawn_initial_garrison_now()


func _on_flow_field_rebuilt(_version: int) -> void:
    if not _initial_garrison_pending:
        return
    _initial_garrison_pending = false
    var callback: Callable = Callable(self, "_on_flow_field_rebuilt")
    if flow != null and is_instance_valid(flow) and flow.rebuilt.is_connected(callback):
        flow.rebuilt.disconnect(callback)
    if hp > 0 and is_inside_tree():
        _spawn_initial_garrison_now()


func _spawn_initial_garrison_now() -> void:
    for i: int in 3:
        _spawn_guard()


func _local_garrison() -> Array[Enemy]:
    var guards: Array[Enemy] = []
    for guard_node: Node in get_tree().get_nodes_in_group("enemy_garrison"):
        var guard: Enemy = guard_node as Enemy
        if guard != null and is_instance_valid(guard) and guard.guard_origin.distance_squared_to(position) < 1.0:
            guards.append(guard)
    return guards


func _process(delta: float) -> void:
    if hp <= 0:
        return
    if civilization != null:
        civilization.advance(delta)
    _reinforce_timer -= delta
    if _reinforce_timer > 0.0:
        return
    _reinforce_timer = REINFORCE_INTERVAL
    var garrison_cap: int = civilization.garrison_capacity() if civilization != null else 4
    if _local_garrison().size() >= garrison_cap:
        return
    if civilization == null:
        _spawn_guard()
        return
    if civilization.can_recruit() and _spawn_guard():
        civilization.pay_recruitment()


func _spawn_guard() -> bool:
    var directions: int = GUARD_DIRECTIONS.size()
    var attempts: int = directions * GUARD_RINGS.size()
    var fortress_center: Vector2 = position + Vector2(0, -size.y * WorldConfig.tile_size / 2.0)
    for i: int in attempts:
        var slot: int = (_spawn_index + i) % attempts
        var ring_index: int = floori(float(slot) / float(directions))
        var direction: Vector2 = Vector2(GUARD_DIRECTIONS[slot % directions])
        var spawn_position: Vector2 = fortress_center + direction * float(GUARD_RINGS[ring_index] * WorldConfig.tile_size)
        var spawn_cell: Vector2i = Vector2i((spawn_position / WorldConfig.tile_size).floor())
        if not world.is_buildable(spawn_cell) or world.occupied.has(spawn_cell):
            continue
        if not flow.is_reachable(spawn_cell):
            continue
        var too_close: bool = false
        for existing_guard: Enemy in _local_garrison():
            if existing_guard.position.distance_to(spawn_position) < WorldConfig.tile_size * 1.5:
                too_close = true
                break
        if too_close:
            continue
        _spawn_index = (slot + 1) % attempts
        var guard: Enemy = ENEMY_SCRIPT.new() as Enemy
        var roster: Array[String] = FactionRegistry.roster_for(faction_id)
        var guard_id: String = FactionRegistry.garrison_enemy(faction_id)
        if not roster.is_empty() and not _local_garrison().is_empty():
            guard_id = roster[posmod(_spawn_index, roster.size())]
        guard.setup_guard(DataDB.enemies[guard_id], world, flow, player, position, faction_id)
        guard.position = spawn_position
        world.entities.add_child(guard)
        return true
    return false


func take_damage(amount: int) -> void:
    if hp <= 0:
        return
    var campaign: Campaign = get_tree().get_first_node_in_group("campaign") as Campaign
    if campaign != null and not campaign.is_current_objective(stronghold_id):
        Events.build_feedback.emit("Kalahkan sasaran kampanye sebelumnya terlebih dahulu")
        return
    hp = maxi(0, hp - amount)
    queue_redraw()
    Events.fx_burst.emit("debris", position + Vector2(0, -24), Vector2.ZERO, 1.4)
    Events.screen_shake.emit(1.2, 0.12)
    if hp > 0:
        return

    for occupied_cell: Vector2i in cells():
        if world.occupied.get(occupied_cell) == self:
            world.occupied.erase(occupied_cell)
    for guard: Enemy in _local_garrison():
        guard.retreat()
    if civilization != null:
        civilization.on_keep_destroyed()
    remove_from_group("enemy_strongholds")
    Events.enemy_stronghold_destroyed.emit(cell)
    Events.stronghold_conquered.emit(stronghold_id, region_id, cell)
    Events.fx_burst.emit("puff", position + Vector2(0, -24), Vector2.ZERO, 3.0)
    Events.screen_shake.emit(2.8, 0.45)
    queue_free()


func _draw() -> void:
    draw_texture(SPRITE, Vector2(-SPRITE.get_width() / 2.0, -SPRITE.get_height()))
    var width: float = 46.0
    var y: float = -float(SPRITE.get_height()) - 6.0
    draw_rect(Rect2(-width / 2.0, y, width, 4), Color(0.04, 0.03, 0.03, 0.9))
    draw_rect(Rect2(-width / 2.0, y, width * float(hp) / max_hp, 4), Color("#a63d36"))
    draw_rect(Rect2(-width / 2.0, y, width, 4), Color("#e3ba84"), false, 1.0)
