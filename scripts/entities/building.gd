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
}
const ARROW_SCRIPT := preload("res://scripts/entities/arrow.gd")

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
    position = Vector2((cell.x + size.x / 2.0) * WorldConfig.tile_size, (cell.y + size.y) * WorldConfig.tile_size)


func cells() -> Array[Vector2i]:
    var out: Array[Vector2i] = []
    for y in size.y:
        for x in size.x:
            out.append(cell + Vector2i(x, y))
    return out


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
    set_physics_process(_range > 0.0)
    if id == "keep":
        Events.keep_hp_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
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
    remove_from_group("buildings")
    remove_from_group("depots")
    remove_from_group("farms")
    remove_from_group("roads")


func free_slots(job: String = "farmer") -> int:
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
    if free_slots(job) <= 0:
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


func can_assign_repairer(v) -> bool:
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
    if amount <= 0 or hp <= 0 or hp >= max_hp:
        return false
    var cost: Dictionary = data.get("repair_cost", {})
    if cost.is_empty() or not Inventory.spend_all(cost):
        return false
    hp = mini(max_hp, hp + amount)
    queue_redraw()
    if id == "keep":
        Events.keep_hp_changed.emit(hp, max_hp)
    return true


func _release_workers() -> void:
    for worker in workers.duplicate():
        if is_instance_valid(worker):
            worker.on_workplace_lost(self)
    workers.clear()
    for worker in repairers.duplicate():
        if is_instance_valid(worker):
            worker.on_repair_target_lost(self)
    repairers.clear()


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
    _release_workers()
    _leave_groups()
    queue_free()


func _draw() -> void:
    var w := float(size.x * WorldConfig.tile_size)
    var h := float(size.y * WorldConfig.tile_size)
    var tex_h := h
    if TEXTURES.has(id):
        var tex: Texture2D = TEXTURES[id]
        tex_h = float(tex.get_height())
        draw_texture(tex, Vector2(-tex.get_width() / 2.0, -tex_h))
    else:
        draw_rect(Rect2(-w / 2, -h, w, h), color)
    if hp < max_hp:
        var by := -tex_h - 5.0
        draw_rect(Rect2(-w / 2, by, w, 3), Color(0, 0, 0, 0.7))
        draw_rect(Rect2(-w / 2, by, w * float(maxi(hp, 0)) / max_hp, 3), Color("#6fcf5a"))
