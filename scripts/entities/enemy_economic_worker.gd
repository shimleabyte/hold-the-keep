extends Node2D
## Autonomous economic labor for one rival stronghold.
## Workers reserve real world resource nodes, gather, and haul cargo to their owner.
## They are deliberately not player villagers or selectable military units.

const SpriteAnim := preload("res://scripts/entities/sprite_anim.gd")
const WORKER_TEXTURES := {
    "lumber_camp": preload("res://assets/sprites/villager_woodcutter.svg"),
    "farm": preload("res://assets/sprites/villager_farmer.svg"),
    "quarry": preload("res://assets/sprites/villager_miner.svg"),
    "forge": preload("res://assets/sprites/villager_miner.svg")
}

enum State { IDLE, TO_RESOURCE, WORKING_RESOURCE, FARMING, TO_KEEP, WAITING_STORAGE, TO_WORKPLACE }

const FRAME_WIDTH := 20
const FRAME_HEIGHT := 20
const MOVE_SPEED := 38.0
const CARRY_CAPACITY := 12
const FARM_CYCLE_SECONDS := 4.8
const FARM_CYCLE_YIELD := 3
const TARGET_RETRY_SECONDS := 2.5
const MAX_PATH_CHECKS := 12
const RESOURCE_WORK_SECONDS := {
    "wood": 3.0,
    "stone": 4.8,
    "iron": 13.5
}
const RESOURCE_BATCH_YIELD := {
    "wood": 5,
    "stone": 6,
    "iron": 9
}

var civilization
var owner_keep: Node2D
var workplace: Node2D
var workplace_id := ""
var nav
var world
var territory
var role := ""
var slot_index := 0
var carry_kind := ""
var carry := 0
var retiring := false

var _state: State = State.IDLE
var _target: Node2D
var _path := PackedVector2Array()
var _path_index := 0
var _path_version := -1
var _work_timer := 0.0
var _retry_timer := 0.0
var _anim = SpriteAnim.new()


func _ready() -> void:
    add_to_group("enemy_economic_workers")
    z_index = 5


func setup(civilization_ref, workplace_ref: Node2D, role_id: String, index: int, main_ref: Node) -> bool:
    civilization = civilization_ref
    owner_keep = civilization_ref.owner_keep
    workplace = workplace_ref
    workplace_id = String(workplace_ref.structure_id) if workplace_ref != null else ""
    role = role_id
    slot_index = maxi(0, index)
    if main_ref == null or owner_keep == null or not is_instance_valid(owner_keep):
        return false
    nav = main_ref.get("nav")
    territory = main_ref.get("territory")
    world = owner_keep.get("world")
    if nav == null or world == null:
        return false

    var horizontal := -5.0 if posmod(slot_index, 2) == 0 else 5.0
    var vertical := float(floori(float(slot_index) / 2.0)) * 3.0
    position = workplace.position + Vector2(horizontal, vertical)
    match role:
        "lumber_camp": _anim.work_style = "woodcutter"
        "quarry", "forge": _anim.work_style = "miner"
        "farm": _anim.work_style = "farmer"
    _anim.face(Vector2.DOWN)
    _anim.play("idle", true)
    queue_redraw()
    return true


func _process(delta: float) -> void:
    tick(delta)


func tick(delta: float) -> void:
    if delta <= 0.0 or owner_keep == null or not is_instance_valid(owner_keep):
        return
    if int(owner_keep.get("hp")) <= 0:
        shutdown()
        return

    if workplace == null or not is_instance_valid(workplace) or int(workplace.get("hp")) <= 0:
        retiring = true
        if carry > 0:
            _begin_return_to_keep()
        else:
            shutdown()
            return

    _retry_timer = maxf(0.0, _retry_timer - delta)
    match _state:
        State.IDLE:
            _tick_idle()
        State.TO_RESOURCE:
            _tick_travel(delta, State.WORKING_RESOURCE)
        State.WORKING_RESOURCE:
            _tick_resource_work(delta)
        State.FARMING:
            _tick_farming(delta)
        State.TO_KEEP:
            _tick_travel(delta, State.WAITING_STORAGE)
        State.WAITING_STORAGE:
            if _retry_timer <= 0.0:
                _deposit_at_keep()
                _retry_timer = 1.0
        State.TO_WORKPLACE:
            _tick_travel(delta, State.FARMING)

    if _anim.update(delta):
        queue_redraw()


func _tick_idle() -> void:
    if carry >= CARRY_CAPACITY:
        _begin_return_to_keep()
        return
    if retiring:
        if carry > 0:
            _begin_return_to_keep()
        else:
            shutdown()
        return
    if _retry_timer > 0.0:
        return
    if role == "farm":
        _state = State.FARMING
        _work_timer = 0.0
        _play_clip("work")
        return
    if not _find_resource_target():
        if carry > 0:
            _begin_return_to_keep()
        else:
            _retry_timer = TARGET_RETRY_SECONDS
            _play_clip("idle")


func _tick_resource_work(delta: float) -> void:
    if not _target_is_claimed_and_harvestable():
        _release_target()
        _state = State.IDLE
        _retry_timer = 0.25
        return

    var kind := String(_target.get("yield_kind"))
    var interval := float(RESOURCE_WORK_SECONDS.get(kind, 4.0))
    if not civilization.can_receive(kind, int(RESOURCE_BATCH_YIELD.get(kind, 1))):
        _begin_return_to_keep()
        return

    _work_timer += delta
    while _work_timer >= interval and _state == State.WORKING_RESOURCE:
        _work_timer -= interval
        if not _target_is_claimed_and_harvestable():
            _release_target()
            _begin_return_to_keep()
            return
        _target.call("hit", self)
        if carry >= CARRY_CAPACITY:
            _begin_return_to_keep()
            return
        if int(_target.get("_hp")) <= 0:
            # Carry capacity represents a full delivery load, not a one-node cap.
            # Chain nearby resource nodes before paying the travel cost to return.
            _release_target()
            _state = State.IDLE
            _retry_timer = 0.1
            return


func _tick_farming(delta: float) -> void:
    if retiring or not civilization.can_receive("food", FARM_CYCLE_YIELD):
        _begin_return_to_keep()
        return
    _work_timer += delta
    while _work_timer >= FARM_CYCLE_SECONDS and _state == State.FARMING:
        _work_timer -= FARM_CYCLE_SECONDS
        receive("food", FARM_CYCLE_YIELD)
        if carry >= CARRY_CAPACITY:
            _begin_return_to_keep()
            return
    _play_clip("work")


func _tick_travel(delta: float, arrival_state: State) -> void:
    if nav == null or not is_instance_valid(nav):
        return
    if _path_version != int(nav.version):
        if not _repath_current_state():
            _path.clear()
            _path_index = 0
            _path_version = int(nav.version)
            _retry_timer = 1.0
            if _state == State.TO_RESOURCE:
                _release_target()
                _state = State.IDLE
            elif _state == State.TO_KEEP:
                _play_clip("idle")
            else:
                _state = State.IDLE
            return
    if _path.is_empty():
        if _retry_timer > 0.0:
            return
        if not _repath_current_state():
            _path_version = int(nav.version)
            _retry_timer = 1.0
            return
    if _move_along_path(delta):
        _path.clear()
        _path_index = 0
        _path_version = int(nav.version)
        _state = arrival_state
        _work_timer = 0.0
        if arrival_state == State.WAITING_STORAGE:
            _deposit_at_keep()
        elif arrival_state == State.FARMING:
            _play_clip("work")
        elif arrival_state == State.WORKING_RESOURCE:
            _play_clip("work")


func _move_along_path(delta: float) -> bool:
    while _path_index < _path.size() and position.distance_to(_path[_path_index]) <= 3.0:
        position = _path[_path_index]
        _path_index += 1
    if _path_index >= _path.size():
        return true

    var destination: Vector2 = _path[_path_index]
    var direction := destination - position
    var distance := direction.length()
    if distance <= 0.001:
        _path_index += 1
        return _path_index >= _path.size()
    _anim.face(direction)
    _play_clip("walk")
    var step := MOVE_SPEED * delta
    if distance <= step:
        position = destination
        _path_index += 1
    else:
        position += direction / distance * step
    return _path_index >= _path.size()


func _repath_current_state() -> bool:
    var next_path := PackedVector2Array()
    match _state:
        State.TO_RESOURCE:
            if _target == null or not is_instance_valid(_target):
                return false
            var target_cells: Array[Vector2i] = [Vector2i(_target.get("resource_cell"))]
            next_path = nav.path_adjacent(position, target_cells)
        State.TO_KEEP, State.WAITING_STORAGE:
            next_path = nav.path_adjacent(position, owner_keep.cells())
        State.TO_WORKPLACE:
            if workplace == null or not is_instance_valid(workplace):
                return false
            next_path = nav.path_adjacent(position, workplace.cells())
    if next_path.is_empty():
        return false
    _path = next_path
    _path_index = 1 if _path.size() > 1 else 0
    _path_version = int(nav.version)
    return true


func _find_resource_target() -> bool:
    if world == null or not is_instance_valid(world) or nav == null:
        return false
    var resource_kinds: Array[String] = civilization.worker_resource_kinds(role)
    if resource_kinds.is_empty():
        return false

    var cells: Array[Vector2i] = []
    for cell_value in world.resource_nodes_by_cell.keys():
        cells.append(Vector2i(cell_value))
    cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
        if a.y != b.y:
            return a.y < b.y
        return a.x < b.x
    )

    for kind in resource_kinds:
        var required_batch := int(RESOURCE_BATCH_YIELD.get(kind, 1))
        if not civilization.can_receive(kind, required_batch):
            continue
        var candidates: Array[Dictionary] = []
        for cell in cells:
            var node: Variant = world.resource_node_at(cell)
            if node == null or not is_instance_valid(node) or not node.has_method("hit"):
                continue
            if String(node.get("yield_kind")) != kind or int(node.get("_hp")) <= 0:
                continue
            # Rival research, not the player's global Iron Mining technology,
            # controls access to this faction's iron supply.
            if kind == "iron" and int(civilization.technology_tier) < 1:
                continue
            if node.has_method("is_available") and kind != "iron" and not bool(node.call("is_available", self)):
                continue
            if node.has_method("is_cleared") and bool(node.call("is_cleared")):
                continue
            var current_worker: Variant = node.get("worker")
            if current_worker != null and is_instance_valid(current_worker) and current_worker != self:
                continue
            if not _resource_cell_is_available(cell, node):
                continue
            var position_distance := position.distance_squared_to(node.global_position)
            candidates.append({
                "node": node,
                "cell": cell,
                "distance": position_distance
            })
        candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
            var da := float(a.get("distance", INF))
            var db := float(b.get("distance", INF))
            if not is_equal_approx(da, db):
                return da < db
            var ca: Vector2i = a.get("cell", Vector2i.ZERO)
            var cb: Vector2i = b.get("cell", Vector2i.ZERO)
            if ca.y != cb.y:
                return ca.y < cb.y
            return ca.x < cb.x
        )

        var path_checks := 0
        for candidate in candidates:
            if path_checks >= MAX_PATH_CHECKS:
                break
            path_checks += 1
            var candidate_node: Node2D = candidate["node"] as Node2D
            var candidate_cells: Array[Vector2i] = [Vector2i(candidate["cell"])]
            var candidate_path: PackedVector2Array = nav.path_adjacent(position, candidate_cells)
            if candidate_path.is_empty() or not _path_avoids_player_territory(candidate_path):
                continue
            var reserved_by: Variant = candidate_node.get("worker")
            if reserved_by != null and is_instance_valid(reserved_by) and reserved_by != self:
                continue
            candidate_node.set("worker", self)
            _target = candidate_node
            _path = candidate_path
            _path_index = 1 if _path.size() > 1 else 0
            _path_version = int(nav.version)
            _state = State.TO_RESOURCE
            _anim.face(candidate_node.global_position - global_position)
            _play_clip("walk")
            return true
    return false


func _resource_cell_is_available(cell: Vector2i, node: Node2D) -> bool:
    if WorldConfig.is_frontier_profile() and String(world.region_id(cell)) != String(owner_keep.get("region_id")):
        return false
    var max_distance := float(owner_keep.get("claim_radius")) + 6.0
    if owner_keep.position.distance_to(node.position) > max_distance * float(WorldConfig.tile_size):
        return false
    if territory != null and is_instance_valid(territory):
        var ownership := String(territory.call("owner_at", cell))
        if ownership == "player" or ownership == "contested":
            return false
    return true


func _path_avoids_player_territory(path: PackedVector2Array) -> bool:
    if territory == null or not is_instance_valid(territory):
        return true
    for path_position in path:
        var cell: Vector2i = nav.cell_of(path_position)
        var ownership := String(territory.call("owner_at", cell))
        if ownership == "player" or ownership == "contested":
            return false
    return true


func _target_is_claimed_and_harvestable() -> bool:
    if _target == null or not is_instance_valid(_target) or int(_target.get("_hp")) <= 0:
        return false
    var node_worker: Variant = _target.get("worker")
    return node_worker == self


func _release_target() -> void:
    if _target != null and is_instance_valid(_target) and _target.get("worker") == self:
        _target.set("worker", null)
    _target = null
    _path.clear()
    _path_index = 0
    _path_version = -1


func _begin_return_to_keep() -> void:
    _release_target()
    if carry <= 0:
        _state = State.IDLE
        _retry_timer = TARGET_RETRY_SECONDS
        return
    _state = State.TO_KEEP
    _path.clear()
    _path_version = -1
    if not _repath_current_state():
        _retry_timer = 1.0
    _play_clip("walk")


func _begin_return_to_workplace() -> void:
    if workplace == null or not is_instance_valid(workplace):
        _state = State.IDLE
        return
    _state = State.TO_WORKPLACE
    _path.clear()
    _path_version = -1
    if not _repath_current_state():
        _state = State.IDLE
        _retry_timer = TARGET_RETRY_SECONDS
    else:
        _play_clip("walk")


func _deposit_at_keep() -> void:
    if carry <= 0 or carry_kind.is_empty():
        _finish_delivery()
        return
    var delivered: int = int(civilization.deliver_resource(carry_kind, carry))
    carry -= delivered
    if carry <= 0:
        carry = 0
        carry_kind = ""
        _finish_delivery()
    else:
        _state = State.WAITING_STORAGE
        _retry_timer = 1.0
        _play_clip("idle")


func _finish_delivery() -> void:
    if retiring or workplace == null or not is_instance_valid(workplace):
        shutdown()
    elif role == "farm":
        _begin_return_to_workplace()
    else:
        _state = State.IDLE
        _retry_timer = 0.1
        _play_clip("idle")


func _target_work_interval(kind: String) -> float:
    return float(RESOURCE_WORK_SECONDS.get(kind, 4.0))


func receive(kind: String, amount: int) -> void:
    if amount <= 0 or (not carry_kind.is_empty() and carry_kind != kind):
        return
    carry_kind = kind
    carry = mini(CARRY_CAPACITY, carry + amount)
    queue_redraw()


func has_cargo() -> bool:
    return carry > 0


func cargo_snapshot() -> Dictionary:
    return {"kind": carry_kind, "amount": carry}


## Saving transfers already-harvested cargo into the persistent stronghold ledger.
func clear_cargo_for_save() -> Dictionary:
    var snapshot := cargo_snapshot()
    carry = 0
    carry_kind = ""
    queue_redraw()
    return snapshot


func recall_to_keep() -> void:
    retiring = true
    if carry > 0:
        _begin_return_to_keep()
    else:
        shutdown()


func shutdown() -> void:
    _release_target()
    remove_from_group("enemy_economic_workers")
    queue_free()


func _play_clip(clip_name: String) -> void:
    if _anim.clip != clip_name:
        _anim.play(clip_name, true)
        queue_redraw()


func _draw() -> void:
    var texture: Texture2D = WORKER_TEXTURES.get(role, WORKER_TEXTURES["lumber_camp"])
    _anim.draw(self, texture, FRAME_WIDTH, FRAME_HEIGHT)
    if carry > 0:
        var cargo_color := Color("#a87545")
        match carry_kind:
            "stone": cargo_color = Color("#aeb4b6")
            "iron": cargo_color = Color("#c07c46")
            "food": cargo_color = Color("#d3b755")
        draw_rect(Rect2(-7, -9, 3, 3), cargo_color)
        draw_rect(Rect2(-7, -9, 3, 1), cargo_color.lightened(0.35))
