extends StaticBody2D
## Batu: 4 pukulan, bonus batu saat habis, muncul lagi setelah 90 detik.

const ROCK_TEX := preload("res://assets/sprites/rock.svg")
const DEPLETED_TEX := preload("res://assets/sprites/rock_depleted.svg")
const HIGHLANDS_TEX := preload("res://assets/sprites/rock_frontier_highlands.svg")
const ASHEN_TEX := preload("res://assets/sprites/rock_frontier_ashen.svg")

const MAX_HP := 4
const STONE_PER_HIT := 1
const STONE_BONUS := 2
const REGROW_SECONDS := 90.0

var yield_kind := "stone"
var regional_style := "classic"
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
    if _hp > 0:
        match regional_style:
            "highlands": tex = HIGHLANDS_TEX
            "ashen_march": tex = ASHEN_TEX
    draw_texture(tex, Vector2(-tex.get_width() / 2.0, -tex.get_height()))
    if _hp > 0 and regional_style != "classic":
        _draw_frontier_rock_dressing()


## Small regional fragments are drawn inside the existing rock node footprint.
## This does not change collision dimensions, occupancy or the harvest lifecycle.
func _draw_frontier_rock_dressing() -> void:
    match regional_style:
        "highlands":
            draw_colored_polygon(PackedVector2Array([
                Vector2(-12, -1), Vector2(-9, -4), Vector2(-6, -1)
            ]), Color("#777b70"))
            draw_colored_polygon(PackedVector2Array([
                Vector2(7, -1), Vector2(10, -3), Vector2(13, 0)
            ]), Color("#626c68"))
            draw_rect(Rect2(-2, -1, 4, 1), Color("#9a927d"))
        "ashen_march":
            draw_colored_polygon(PackedVector2Array([
                Vector2(-12, 0), Vector2(-9, -3), Vector2(-6, -1)
            ]), Color("#59483d"))
            draw_colored_polygon(PackedVector2Array([
                Vector2(7, -1), Vector2(10, -4), Vector2(13, -1)
            ]), Color("#8b5d43"))
            draw_rect(Rect2(-2, -1, 3, 1), Color("#bd8a60"))
        _:
            draw_colored_polygon(PackedVector2Array([
                Vector2(-12, 0), Vector2(-9, -3), Vector2(-6, -1)
            ]), Color("#536247"))
            draw_colored_polygon(PackedVector2Array([
                Vector2(7, -1), Vector2(10, -3), Vector2(13, 0)
            ]), Color("#716c4f"))
