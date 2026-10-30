extends StaticBody2D
## Pohon: 3 pukulan, bonus kayu saat tumbang, tumbuh lagi setelah beberapa saat.
## Origin node = pangkal pohon (untuk Y-sort).

const TREE_TEX := preload("res://assets/sprites/tree.svg")
const STUMP_TEX := preload("res://assets/sprites/stump.svg")

const MAX_HP := 3
const WOOD_PER_HIT := 1
const WOOD_BONUS := 2
const REGROW_SECONDS := 45.0

var yield_kind := "wood"
var worker = null  # villager yang sedang mengklaim pohon ini

var _hp := MAX_HP


func _ready() -> void:
    var shape := RectangleShape2D.new()
    shape.size = Vector2(6, 4)
    var col := CollisionShape2D.new()
    col.shape = shape
    col.position = Vector2(0, -2)
    add_child(col)
    add_to_group("harvestable")


func is_available(by = null) -> bool:
    return _hp > 0 and (worker == null or worker == by or not is_instance_valid(worker))


## `by` = villager (hasil masuk ke bawaannya). null = pemain (langsung ke inventori).
func hit(by = null) -> void:
    if _hp <= 0:
        return
    _hp -= 1
    Events.fx_burst.emit("wood", global_position + Vector2(0, -8), Vector2.ZERO, 2.0 if _hp == 0 else 1.0)
    _give(WOOD_PER_HIT, by)
    _flash()
    if _hp == 0:
        _give(WOOD_BONUS, by)
        worker = null
        remove_from_group("harvestable")
        queue_redraw()
        get_tree().create_timer(REGROW_SECONDS).timeout.connect(_regrow)


func _give(amount: int, by) -> void:
    if by != null and is_instance_valid(by) and by.has_method("receive"):
        by.receive(yield_kind, amount)
    else:
        Inventory.add(yield_kind, amount)


func _regrow() -> void:
    _hp = MAX_HP
    add_to_group("harvestable")
    queue_redraw()


func _flash() -> void:
    modulate = Color(1.8, 1.8, 1.8)
    create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)


func _draw() -> void:
    if _hp > 0:
        draw_texture(TREE_TEX, Vector2(-TREE_TEX.get_width() / 2.0, -TREE_TEX.get_height()))
    else:
        draw_texture(STUMP_TEX, Vector2(-STUMP_TEX.get_width() / 2.0, -STUMP_TEX.get_height()))
