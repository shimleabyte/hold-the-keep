extends StaticBody2D
## Renewable small-game resource used by the Hunter workplace.
## Wildlife is deterministic world dressing, not an autonomous animal simulation.

const WILDLIFE_TEX := preload("res://assets/sprites/wildlife_deer.svg")
const MAX_HP := 3
const FOOD_PER_HIT := 1
const FOOD_BONUS := 2
const REGROW_SECONDS := 105.0

var yield_kind := "food"
var regional_style := "greenwood"
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
    shape.size = Vector2(7, 4)
    var col := CollisionShape2D.new()
    col.shape = shape
    col.position = Vector2(0, -2)
    add_child(col)
    _collision_shape = col
    add_to_group("resource_nodes")
    add_to_group("harvestable")
    add_to_group("wildlife")


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
    set_process(_hp <= 0 and not _cleared)
    worker = null
    _apply_cleared_state()
    _update_resource_groups()
    queue_redraw()

func is_available(by = null) -> bool:
    return _hp > 0 and (worker == null or worker == by or not is_instance_valid(worker))


func hit(by = null) -> void:
    if _hp <= 0:
        return
    _hp -= 1
    if by == null:
        Events.fx_burst.emit("food", global_position + Vector2(0, -8), Vector2.ZERO, 1.0)
        modulate = Color(1.8, 1.8, 1.8)
        create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)
    _give(FOOD_PER_HIT, by)
    if _hp == 0:
        _give(FOOD_BONUS, by)
        worker = null
        _update_resource_groups()
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
    _update_resource_groups()
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

func _update_resource_groups() -> void:
    remove_from_group("harvestable")
    remove_from_group("clearable_resource_residues")
    if _cleared:
        return
    if _hp > 0:
        add_to_group("harvestable")
    else:
        add_to_group("clearable_resource_residues")

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
    _update_resource_groups()
    queue_redraw()

func _draw() -> void:
    if _hp > 0:
        draw_texture(WILDLIFE_TEX, Vector2(-WILDLIFE_TEX.get_width() / 2.0, -WILDLIFE_TEX.get_height()))
    else:
        draw_rect(Rect2(-4, -3, 8, 2), Color("#534334"))
        draw_line(Vector2(-3, -2), Vector2(3, -4), Color("#a17a53"), 1.0)
