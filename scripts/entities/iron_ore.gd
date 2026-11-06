extends StaticBody2D
## Bijih besi: baru bisa ditambang setelah teknologi "Tambang Besi". Sebelum itu node ada di grup
## "ore_locked" (pemain mendapat petunjuk saat mencoba menambang), sesudahnya masuk "harvestable".
## 6 pukulan, bonus saat habis, muncul lagi setelah 150 detik.

const ORE_TEX := preload("res://assets/sprites/iron_ore.svg")
const DEPLETED_TEX := preload("res://assets/sprites/rock_depleted.svg")

const MAX_HP := 6
const IRON_PER_HIT := 1
const IRON_BONUS := 3
const REGROW_SECONDS := 150.0

var yield_kind := "iron"
var worker = null
var resource_cell := Vector2i.ZERO
var world_map: Node
var _collision_shape: CollisionShape2D
var _cleared := false

var _hp := MAX_HP
var _regrow_in := 0.0


func _ready() -> void:
    set_process(false)
    var shape := RectangleShape2D.new()
    shape.size = Vector2(12, 7)
    var col := CollisionShape2D.new()
    col.shape = shape
    col.position = Vector2(0, -3.5)
    add_child(col)
    _collision_shape = col
    add_to_group("resource_nodes")
    Events.tech_researched.connect(_on_tech)
    _update_group()


func _process(delta: float) -> void:
    if _hp <= 0:
        _regrow_in = maxf(0.0, _regrow_in - delta)
        if _regrow_in <= 0.0:
            _regrow()


func export_state() -> Dictionary:
    return {"hp": _hp, "regrow": _regrow_in, "cleared": _cleared}

func import_state(data: Dictionary) -> void:
    _hp = clampi(int(data.get("hp", MAX_HP)), 0, MAX_HP)
    _cleared = bool(data.get("cleared", false))
    if _cleared:
        _hp = 0
    _regrow_in = maxf(0.0, float(data.get("regrow", 0.0))) if _hp <= 0 and not _cleared else 0.0
    set_process(_hp <= 0 and not _cleared and _regrow_in > 0.0)
    worker = null
    _apply_cleared_state()
    _update_group()
    queue_redraw()

func _on_tech(_id: String) -> void:
    _update_group()


func _update_group() -> void:
    remove_from_group("harvestable")
    remove_from_group("ore_locked")
    remove_from_group("clearable_resource_residues")
    if _cleared:
        return
    if _hp <= 0:
        add_to_group("clearable_resource_residues")
    else:
        add_to_group("harvestable" if Tech.has_flag("iron_mining") else "ore_locked")

func is_available(by = null) -> bool:
    return _hp > 0 and Tech.has_flag("iron_mining") and (worker == null or worker == by or not is_instance_valid(worker))


func hit(by = null) -> void:
    if _hp <= 0:
        return
    _hp -= 1
    if by == null:
        Events.fx_burst.emit("stone", global_position + Vector2(0, -5), Vector2.ZERO, 2.0 if _hp == 0 else 1.0)
        modulate = Color(1.8, 1.8, 1.8)
        create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)
    _give(IRON_PER_HIT, by)
    if _hp == 0:
        _give(IRON_BONUS, by)
        worker = null
        _update_group()
        queue_redraw()
        _regrow_in = REGROW_SECONDS
        set_process(true)


func is_cleared() -> bool:
    return _cleared


func clear_residue() -> bool:
    if _cleared or _hp > 0:
        return false
    _cleared = true
    _regrow_in = 0.0
    set_process(false)
    _apply_cleared_state()
    _update_group()
    queue_redraw()
    Events.build_feedback.emit("Sisa resource dibersihkan; area bisa dibangun")
    return true


func _apply_cleared_state() -> void:
    if _cleared:
        visible = false
        collision_layer = 0
        collision_mask = 0
        if _collision_shape != null:
            _collision_shape.set_deferred("disabled", true)
        if is_instance_valid(world_map) and world_map.has_method("clear_resource_occupancy"):
            world_map.clear_resource_occupancy(self)
    else:
        visible = true
        collision_layer = 1
        collision_mask = 1
        if _collision_shape != null:
            _collision_shape.set_deferred("disabled", false)
        if is_instance_valid(world_map) and world_map.has_method("restore_resource_occupancy"):
            world_map.restore_resource_occupancy(self)

func _give(amount: int, by) -> void:
    if by != null and is_instance_valid(by) and by.has_method("receive"):
        by.receive(yield_kind, amount)
    else:
        Inventory.add(yield_kind, amount)


func _regrow() -> void:
    if _cleared:
        return
    _hp = MAX_HP
    _regrow_in = 0.0
    set_process(false)
    _update_group()
    queue_redraw()

func _draw() -> void:
    var tex: Texture2D = ORE_TEX if _hp > 0 else DEPLETED_TEX
    draw_texture(tex, Vector2(-tex.get_width() / 2.0, -tex.get_height()))
