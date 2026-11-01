extends StaticBody2D
## Batu: 4 pukulan, bonus batu saat habis, muncul lagi setelah 90 detik.

const ROCK_TEX := preload("res://assets/sprites/rock.svg")
const DEPLETED_TEX := preload("res://assets/sprites/rock_depleted.svg")

const MAX_HP := 4
const STONE_PER_HIT := 1
const STONE_BONUS := 2
const REGROW_SECONDS := 90.0

var yield_kind := "stone"
var worker = null

var _hp := MAX_HP
var _regrow_in := 0.0


func _ready() -> void:
    var shape := RectangleShape2D.new()
    shape.size = Vector2(12, 7)
    var col := CollisionShape2D.new()
    col.shape = shape
    col.position = Vector2(0, -3.5)
    add_child(col)
    add_to_group("resource_nodes")
    add_to_group("harvestable")


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
    Events.fx_burst.emit("stone", global_position + Vector2(0, -5), Vector2.ZERO, 2.0 if _hp == 0 else 1.0)
    _give(STONE_PER_HIT, by)
    modulate = Color(1.8, 1.8, 1.8)
    create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)
    if _hp == 0:
        _give(STONE_BONUS, by)
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
    if _hp > 0:
        add_to_group("harvestable")
    else:
        remove_from_group("harvestable")
    queue_redraw()


func _draw() -> void:
    var tex: Texture2D = ROCK_TEX if _hp > 0 else DEPLETED_TEX
    draw_texture(tex, Vector2(-tex.get_width() / 2.0, -tex.get_height()))
