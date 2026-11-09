extends StaticBody2D
## Bangunan. Origin node = tengah-bawah footprint (untuk Y-sort).

const TEXTURES := {
    "keep": preload("res://assets/sprites/keep.svg"),
    "house": preload("res://assets/sprites/house.svg"),
    "wall": preload("res://assets/sprites/wall.svg"),
    "tower": preload("res://assets/sprites/tower.svg"),
    "storage": preload("res://assets/sprites/storage.svg"),
    "farm": preload("res://assets/sprites/farm.svg"),
    "stone_wall": preload("res://assets/sprites/stone_wall.svg"),
    "forge": preload("res://assets/sprites/forge.svg"),
    "outpost": preload("res://assets/sprites/outpost.svg"),
    "road": preload("res://assets/sprites/road.svg"),
    "bridge": preload("res://assets/sprites/bridge.svg"),
    "lumber_camp": preload("res://assets/sprites/lumber_camp.svg"),
    "quarry": preload("res://assets/sprites/quarry.svg"),
    "granary": preload("res://assets/sprites/granary.svg"),
    "hunting_lodge": preload("res://assets/sprites/hunting_lodge.svg"),
    "scout_post": preload("res://assets/sprites/scout_post.svg"),
    "infirmary": preload("res://assets/sprites/infirmary.svg"),
    "barracks": preload("res://assets/sprites/barracks.svg"),
    "archery_range": preload("res://assets/sprites/archery_range.svg"),
}
const ARROW_SCRIPT := preload("res://scripts/entities/arrow.gd")
const BuildingVisual := preload("res://scripts/entities/building_visual_identity.gd")

var id := ""
var cell := Vector2i.ZERO  # tile kiri-atas footprint
var size := Vector2i.ONE
var color := Color.GRAY
var hp := 100
var max_hp := 100
var world
var data: Dictionary = {}
var workers: Array = []
var repairers: Array = []
var guards: Array = []
var guard_capacity := 0
var _healer_targets: Dictionary = {}
var _healer_assignments: Dictionary = {}
var _blacksmith_targets: Dictionary = {}
var _blacksmith_assignments: Dictionary = {}
var local_stockpile: Dictionary = {}
var stockpile_capacity := 0
var _sabotage_remaining := 0.0
var _combat_impact_remaining := 0.0
var _combat_impact_total := 0.0
var _combat_impact_direction := Vector2.LEFT
var _combat_impact_strength := 1.0

var _range := 0.0
var _damage := 0
var _interval := 1.0
var _fire_cd := 0.0


func setup(d: Dictionary, anchor: Vector2i) -> void:
    data = d
    id = data["id"]
    cell = anchor
    size = Vector2i(int(data["size"][0]), int(data["size"][1]))
    color = Color(data["color"])
    max_hp = roundi(Tech.stat(id + ".hp", float(data["hp"])))
    hp = max_hp
    _range = float(data.get("range", 0.0))
    _damage = int(data.get("damage", 0))
    _interval = float(data.get("fire_interval", 1.0))
    stockpile_capacity = int(data.get("stockpile_capacity", 0))
    guard_capacity = int(data.get("guard_slots", 0))
    position = Vector2((cell.x + size.x / 2.0) * WorldConfig.tile_size, (cell.y + size.y) * WorldConfig.tile_size)


func cells() -> Array[Vector2i]:
    var out: Array[Vector2i] = []
    for y in size.y:
        for x in size.x:
            out.append(cell + Vector2i(x, y))
    return out

## Local Frontier depot storage. The Keep remains the central Inventory ledger.
func stockpile_total() -> int:
    var total := 0
    for amount in local_stockpile.values():
        total += int(amount)
    return total


func stockpile_amount(kind: String) -> int:
    return int(local_stockpile.get(kind, 0))


func is_sabotaged() -> bool:
    return _sabotage_remaining > 0.0


func sabotage_seconds_remaining() -> float:
    return _sabotage_remaining


func apply_sabotage(duration: float) -> bool:
    if hp <= 0 or id in ["keep", "road", "bridge", "wall", "stone_wall"]:
        return false
    _sabotage_remaining = maxf(_sabotage_remaining, clampf(duration, 1.0, 12.0))
    set_process(true)
    queue_redraw()
    Events.fx_burst.emit("debris", global_position + Vector2(0, -size.y * 6.0), Vector2.ZERO, 0.9)
    Events.build_feedback.emit(
        "SABOTASE: %s terganggu selama %d detik" % [String(id).to_upper(), ceili(_sabotage_remaining)]
    )
    return true


func _process(delta: float) -> void:
    if _sabotage_remaining > 0.0:
        _sabotage_remaining = maxf(0.0, _sabotage_remaining - delta)
        if _sabotage_remaining <= 0.0:
            queue_redraw()
            Events.build_feedback.emit("%s kembali berfungsi" % String(id).to_upper())

    if _combat_impact_remaining > 0.0:
        _combat_impact_remaining = maxf(0.0, _combat_impact_remaining - delta)
        queue_redraw()

    if _sabotage_remaining <= 0.0 and _combat_impact_remaining <= 0.0:
        set_process(false)


func accepts_resource(kind: String) -> bool:
    if stockpile_capacity <= 0:
        return false
    var accepted_resources: Array = data.get("accepted_resources", ["wood", "stone", "food", "iron"])
    return accepted_resources.has(kind)


func can_store_resource(kind: String, amount: int) -> bool:
    if is_sabotaged() or amount <= 0 or not accepts_resource(kind):
        return false
    return stockpile_total() + amount <= stockpile_capacity


func store_resource(kind: String, amount: int) -> bool:
    if not can_store_resource(kind, amount):
        return false
    local_stockpile[kind] = stockpile_amount(kind) + amount
    Events.supply_stock_changed.emit()
    return true


func take_resource(kind: String, amount: int) -> bool:
    if is_sabotaged() or amount <= 0 or stockpile_amount(kind) < amount:
        return false
    var remaining := stockpile_amount(kind) - amount
    if remaining == 0:
        local_stockpile.erase(kind)
    else:
        local_stockpile[kind] = remaining
    Events.supply_stock_changed.emit()
    return true


func export_stockpile() -> Dictionary:
    return local_stockpile.duplicate(true)


func import_stockpile(value: Variant) -> bool:
    if not (value is Dictionary):
        return false
    var restored: Dictionary = {}
    var total := 0
    for kind in value:
        var amount := int(value[kind])
        if not accepts_resource(String(kind)) or amount < 0:
            return false
        if amount > 0:
            restored[String(kind)] = amount
            total += amount
    if total > stockpile_capacity or (total > 0 and stockpile_capacity <= 0):
        return false
    local_stockpile = restored
    Events.supply_stock_changed.emit()
    return true

func _ready() -> void:
    if id != "road" and id != "bridge":
        var w := size.x * WorldConfig.tile_size
        var h := size.y * WorldConfig.tile_size
        var shape := RectangleShape2D.new()
        shape.size = Vector2(w, h)
        var col := CollisionShape2D.new()
        col.shape = shape
        col.position = Vector2(0, -h / 2.0)
        add_child(col)
    else:
        add_to_group("roads")
    add_to_group("buildings")
    Events.tech_researched.connect(_on_tech)
    if data.get("depot", false):
        add_to_group("depots")
    if id == "farm":
        add_to_group("farms")
    if id == "granary":
        add_to_group("granaries")
    if guard_capacity > 0:
        add_to_group("garrisons")
    if id == "archery_range":
        add_to_group("archery_ranges")
    set_physics_process(_range > 0.0)
    set_process(false)
    if id == "keep":
        Events.keep_hp_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
    if is_sabotaged():
        return
    _fire_cd -= delta
    if _fire_cd > 0.0:
        return
    var from := global_position + Vector2(0, -size.y * WorldConfig.tile_size * 1.2)
    var best: Node2D = null
    var best_d := _range * Tech.stat("tower.range", 1.0)
    for e in get_tree().get_nodes_in_group("enemies"):
        var n := e as Node2D
        var d := from.distance_to(n.global_position + Vector2(0, -6))
        if d < best_d:
            best_d = d
            best = n
    if best == null:
        _fire_cd = 0.15
        return
    _fire_cd = _interval
    var a := ARROW_SCRIPT.new()
    a.global_position = from
    a.setup(best, roundi(Tech.stat("tower.damage", float(_damage))))
    world.add_child(a)


## Riset baru mengubah HP maksimum (mis. Menara Batu); HP sekarang ikut diskalakan.
func _on_tech(_tech_id: String) -> void:
    var new_max := roundi(Tech.stat(id + ".hp", float(data["hp"])))
    if new_max == max_hp:
        return
    hp = clampi(roundi(float(hp) * new_max / max_hp), 1, new_max)
    max_hp = new_max
    queue_redraw()
    if id == "keep":
        Events.keep_hp_changed.emit(hp, max_hp)


func take_damage_from(amount: int, source_position: Vector2) -> void:
    if hp <= 0:
        return
    var incoming := source_position - global_position
    _combat_impact_direction = incoming.normalized() if incoming.length_squared() > 0.001 else Vector2.LEFT
    _combat_impact_strength = clampf(float(amount) / 36.0, 0.75, 1.8)
    _combat_impact_total = 0.42
    _combat_impact_remaining = _combat_impact_total
    take_damage(amount)
    if hp > 0:
        set_process(true)
        queue_redraw()


func take_damage(amount: int) -> void:
    if hp <= 0:
        return
    hp -= amount
    modulate = Color(1.6, 0.8, 0.8)
    Events.fx_burst.emit("debris", global_position + Vector2(randf_range(-size.x * 6.0, size.x * 6.0), -randf_range(4.0, size.y * 12.0)), Vector2.ZERO, 0.5)
    if amount >= 12:
        Events.screen_shake.emit(1.2, 0.12)
    create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)
    queue_redraw()
    if id == "keep":
        Events.keep_hp_changed.emit(maxi(hp, 0), max_hp)
    if hp <= 0:
        _die()


func _leave_groups() -> void:
    for guard in guards.duplicate():
        if is_instance_valid(guard) and guard.has_method("on_guard_outpost_lost"):
            guard.on_guard_outpost_lost(self)
    guards.clear()
    remove_from_group("buildings")
    remove_from_group("depots")
    remove_from_group("farms")
    remove_from_group("granaries")
    remove_from_group("garrisons")
    remove_from_group("archery_ranges")
    remove_from_group("roads")


func free_slots(job: String = "farmer") -> int:
    if is_sabotaged():
        return 0
    workers = workers.filter(func(w): return is_instance_valid(w))
    var workplace_data: Dictionary = data.get("workplaces", {})
    var default_slots := int(data.get("workers", 0)) if job == "farmer" else 0
    var slots := int(workplace_data.get(job, default_slots))
    if id == "farm" and job == "farmer":
        slots = roundi(Tech.stat("farm.workers", float(slots)))
    var occupied_slots := 0
    for worker in workers:
        if String(worker.workplace_job) == job:
            occupied_slots += 1
    return maxi(0, slots - occupied_slots)


func claim(v, job: String = "farmer") -> bool:
    if is_sabotaged() or free_slots(job) <= 0:
        return false
    if not workers.has(v):
        workers.append(v)
    v.workplace = self
    v.workplace_job = job
    return true


func release(v) -> void:
    workers.erase(v)
    if is_instance_valid(v) and v.workplace == self:
        v.workplace = null
        v.workplace_job = ""


func claim_heal_target(healer, patient) -> bool:
    if id != "infirmary" or is_sabotaged() or not is_instance_valid(healer) or not is_instance_valid(patient):
        return false
    var healer_id: int = healer.get_instance_id()
    var patient_id: int = patient.get_instance_id()
    if int(_healer_assignments.get(healer_id, -1)) == patient_id:
        return true
    release_heal_target(healer)
    var current = _healer_targets.get(patient_id, null)
    if current != null and is_instance_valid(current) and current != healer:
        return false
    _healer_targets[patient_id] = healer
    _healer_assignments[healer_id] = patient_id
    return true


func is_heal_target_reserved(patient, except_healer = null) -> bool:
    if not is_instance_valid(patient):
        return false
    var patient_id: int = patient.get_instance_id()
    var current = _healer_targets.get(patient_id, null)
    if current == null or not is_instance_valid(current):
        _healer_targets.erase(patient_id)
        return false
    return current != except_healer


func release_heal_target(healer) -> void:
    if not is_instance_valid(healer):
        return
    var healer_id: int = healer.get_instance_id()
    if not _healer_assignments.has(healer_id):
        return
    var patient_id := int(_healer_assignments[healer_id])
    var current = _healer_targets.get(patient_id, null)
    if current == healer:
        _healer_targets.erase(patient_id)
    _healer_assignments.erase(healer_id)


func claim_blacksmith_target(smith, soldier) -> bool:
    if id != "forge" or is_sabotaged() or not is_instance_valid(smith) or not is_instance_valid(soldier):
        return false
    if String(smith.job) != "blacksmith" or String(soldier.job) != "soldier":
        return false
    var smith_id: int = smith.get_instance_id()
    var soldier_id: int = soldier.get_instance_id()
    if int(_blacksmith_assignments.get(smith_id, -1)) == soldier_id:
        return true
    release_blacksmith_target(smith)
    var current = _blacksmith_targets.get(soldier_id, null)
    if current != null and is_instance_valid(current) and current != smith:
        return false
    _blacksmith_targets[soldier_id] = smith
    _blacksmith_assignments[smith_id] = soldier_id
    return true


func is_blacksmith_target_reserved(soldier, except_smith = null) -> bool:
    if not is_instance_valid(soldier):
        return false
    var soldier_id: int = soldier.get_instance_id()
    var current = _blacksmith_targets.get(soldier_id, null)
    if current == null or not is_instance_valid(current):
        _blacksmith_targets.erase(soldier_id)
        return false
    return current != except_smith


func release_blacksmith_target(smith) -> void:
    if not is_instance_valid(smith):
        return
    var smith_id: int = smith.get_instance_id()
    if not _blacksmith_assignments.has(smith_id):
        return
    var soldier_id := int(_blacksmith_assignments[smith_id])
    var current = _blacksmith_targets.get(soldier_id, null)
    if current == smith:
        _blacksmith_targets.erase(soldier_id)
    _blacksmith_assignments.erase(smith_id)


func can_assign_repairer(v) -> bool:
    if is_sabotaged():
        return false
    repairers = repairers.filter(func(worker): return is_instance_valid(worker))
    return hp > 0 and hp < max_hp and (repairers.is_empty() or repairers.has(v))


func claim_repairer(v) -> bool:
    if not can_assign_repairer(v):
        return false
    if not repairers.has(v):
        repairers.append(v)
    return true


func release_repairer(v) -> void:
    repairers.erase(v)


func repair(amount: int) -> bool:
    if is_sabotaged() or amount <= 0 or hp <= 0 or hp >= max_hp:
        return false
    var cost: Dictionary = data.get("repair_cost", {})
    if cost.is_empty():
        return false
    var supply = get_tree().get_first_node_in_group("supply_network")
    var paid: bool = supply.pay_cost(cost) if supply != null else Inventory.spend_all(cost)
    if not paid:
        return false
    hp = mini(max_hp, hp + amount)
    queue_redraw()
    if id == "keep":
        Events.keep_hp_changed.emit(hp, max_hp)
    return true


func guard_count() -> int:
    guards = guards.filter(func(guard): return is_instance_valid(guard))
    return guards.size()


func free_guard_slots() -> int:
    return maxi(0, guard_capacity - guard_count())


func claim_guard(soldier) -> bool:
    if is_sabotaged() or guard_capacity <= 0 or not is_instance_valid(soldier):
        return false
    if String(soldier.job) != "soldier":
        return false
    if guards.has(soldier):
        return true
    if free_guard_slots() <= 0:
        return false
    guards.append(soldier)
    return true


func release_guard(soldier) -> void:
    guards.erase(soldier)


func _release_workers() -> void:
    for worker in workers.duplicate():
        if is_instance_valid(worker):
            worker.on_workplace_lost(self)
    workers.clear()
    for worker in repairers.duplicate():
        if is_instance_valid(worker):
            worker.on_repair_target_lost(self)
    repairers.clear()
    for guard in guards.duplicate():
        if is_instance_valid(guard) and guard.has_method("on_guard_outpost_lost"):
            guard.on_guard_outpost_lost(self)
    guards.clear()


func _die() -> void:
    for c in cells():
        if world.occupied.get(c) == self:
            world.occupied.erase(c)
    _release_workers()
    _leave_groups()
    Events.fx_burst.emit("puff", global_position + Vector2(0, -size.y * 8.0), Vector2.ZERO, 1.0 + size.x * 0.5)
    Events.fx_burst.emit("debris", global_position + Vector2(0, -size.y * 8.0), Vector2.ZERO, 2.0 + size.x * 0.5)
    Events.screen_shake.emit(2.0, 0.25)
    Events.building_destroyed.emit(id, cell)
    if id == "keep":
        Events.game_over.emit(GameClock.day)
    queue_free()


## Dibongkar pemain (tanpa memicu event kehancuran).
func demolish() -> void:
    # Player demolition returns local goods to the central pool; destruction does not.
    for kind in local_stockpile:
        Inventory.add(String(kind), int(local_stockpile[kind]))
    local_stockpile.clear()
    _release_workers()
    _leave_groups()
    queue_free()


func _draw() -> void:
    var w := float(size.x * WorldConfig.tile_size)
    var h := float(size.y * WorldConfig.tile_size)
    var tex_h := h
    var visual_size := Vector2(w, h)
    if TEXTURES.has(id):
        var tex: Texture2D = TEXTURES[id]
        tex_h = float(tex.get_height())
        visual_size = Vector2(tex.get_width(), tex.get_height())
        draw_texture(tex, Vector2(-tex.get_width() / 2.0, -tex_h))
    else:
        draw_rect(Rect2(-w / 2, -h, w, h), color)

    var visual_profile: Variant = data.get("visual", {})
    if visual_profile is Dictionary and BuildingVisual.enabled(WorldConfig.profile_id, visual_profile):
        BuildingVisual.draw_identity(
            self, id, visual_profile, visual_size,
            float(hp) / float(maxi(1, max_hp))
        )

    if hp < max_hp:
        var by := -tex_h - 5.0
        draw_rect(Rect2(-w / 2, by, w, 3), Color(0, 0, 0, 0.7))
        draw_rect(Rect2(-w / 2, by, w * float(maxi(hp, 0)) / max_hp, 3), Color("#6fcf5a"))
    if is_sabotaged():
        var mark_y := -tex_h - 15.0
        draw_rect(Rect2(-9.0, mark_y, 18.0, 7.0), Color("#5f2626"))
        draw_line(Vector2(-6.0, mark_y + 1.0), Vector2(6.0, mark_y + 6.0), Color("#e8b76d"), 1.5)
        draw_line(Vector2(6.0, mark_y + 1.0), Vector2(-6.0, mark_y + 6.0), Color("#e8b76d"), 1.5)

    if _combat_impact_remaining > 0.0:
        var progress := 1.0 - _combat_impact_remaining / maxf(0.001, _combat_impact_total)
        var alpha := 1.0 - smoothstep(0.18, 1.0, progress)
        var source := _combat_impact_direction
        var inward := -source
        var tangent := source.rotated(PI * 0.5)
        var strike_center := Vector2(
            roundf(source.x * minf(w * 0.34, 22.0)),
            roundf(-tex_h * 0.55 + source.y * minf(tex_h * 0.22, 12.0))
        )
        var reach := 4.0 + _combat_impact_strength * 2.5
        var crack_ink := Color(0.12, 0.13, 0.12, alpha * 0.92)
        var hot_edge := Color(0.88, 0.66, 0.42, alpha * 0.82)
        draw_circle(strike_center, 2.0 + _combat_impact_strength * 0.6, crack_ink)
        draw_line(strike_center, strike_center + inward * reach, crack_ink, 1.4)
        draw_line(strike_center + inward * 2.0, strike_center + inward * reach + tangent * 3.0,
            crack_ink, 1.0)
        draw_line(strike_center + inward * 2.0, strike_center + inward * reach - tangent * 3.0,
            crack_ink, 1.0)
        draw_line(strike_center - tangent * 2.0, strike_center + tangent * 2.0,
            hot_edge, 1.0)

