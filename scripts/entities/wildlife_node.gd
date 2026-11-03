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
var _hp := MAX_HP
var _regrow_in := 0.0


func _ready() -> void:
    var shape := RectangleShape2D.new()
    shape.size = Vector2(7, 4)
    var col := CollisionShape2D.new()
    col.shape = shape
    col.position = Vector2(0, -2)
    add_child(col)
    add_to_group("resource_nodes")
    add_to_group("harvestable")
    add_to_group("wildlife")


func _process(delta: float) -> void:
    if _hp <= 0:
        _regrow_in = maxf(0.0, _regrow_in - delta)
        if _regrow_in <= 0.0:
            _regrow()


func export_state() -> Dictionary:
    return {"hp": _hp, "regrow": _regrow_in}


func import_state(data: Dictionary) -> void:
    _hp = clampi(int(data.get("hp", MAX_HP)), 0, MAX_HP)
    _regrow_in = maxf(0.0, float(data.get("regrow", 0.0))) if _hp <= 0 else 0.0
    worker = null
    if _hp > 0:
        add_to_group("harvestable")
    else:
        remove_from_group("harvestable")
    queue_redraw()


func is_available(by = null) -> bool:
    return _hp > 0 and (worker == null or worker == by or not is_instance_valid(worker))


func hit(by = null) -> void:
    if _hp <= 0:
        return
    _hp -= 1
    Events.fx_burst.emit("food", global_position + Vector2(0, -8), Vector2.ZERO, 1.0)
    _give(FOOD_PER_HIT, by)
    modulate = Color(1.8, 1.8, 1.8)
    create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)
    if _hp == 0:
        _give(FOOD_BONUS, by)
        worker = null
        remove_from_group("harvestable")
        queue_redraw()
        _regrow_in = REGROW_SECONDS


func _give(amount: int, by) -> void:
    if by != null and is_instance_valid(by) and by.has_method("receive"):
        by.receive(yield_kind, amount)
    else:
        Inventory.add(yield_kind, amount)


func _regrow() -> void:
    _hp = MAX_HP
    _regrow_in = 0.0
    add_to_group("harvestable")
    queue_redraw()


func _draw() -> void:
    if _hp > 0:
        draw_texture(WILDLIFE_TEX, Vector2(-WILDLIFE_TEX.get_width() / 2.0, -WILDLIFE_TEX.get_height()))
    else:
        draw_rect(Rect2(-4, -3, 8, 2), Color("#534334"))
        draw_line(Vector2(-3, -2), Vector2(3, -4), Color("#a17a53"), 1.0)
