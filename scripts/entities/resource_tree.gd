extends StaticBody2D
## Pohon: 3 pukulan, bonus kayu saat tumbang, tumbuh lagi setelah beberapa saat.
## Origin node = pangkal pohon (untuk Y-sort).

const TREE_TEX := preload("res://assets/sprites/tree.svg")
const STUMP_TEX := preload("res://assets/sprites/stump.svg")
const GREENWOOD_TEX := preload("res://assets/sprites/tree_frontier_greenwood.svg")
const FENLANDS_TEX := preload("res://assets/sprites/tree_frontier_fenlands.svg")
const ASHEN_TEX := preload("res://assets/sprites/tree_frontier_ashen.svg")

const MAX_HP := 3
const WOOD_PER_HIT := 1
const WOOD_BONUS := 2
const REGROW_SECONDS := 45.0

var yield_kind := "wood"
var regional_style := "classic"
var worker = null  # villager yang sedang mengklaim pohon ini

var _hp := MAX_HP
var _regrow_in := 0.0


func _ready() -> void:
    var shape := RectangleShape2D.new()
    shape.size = Vector2(6, 4)
    var col := CollisionShape2D.new()
    col.shape = shape
    col.position = Vector2(0, -2)
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


func _flash() -> void:
    modulate = Color(1.8, 1.8, 1.8)
    create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)


func _draw() -> void:
    if _hp > 0:
        var texture: Texture2D = TREE_TEX
        match regional_style:
            "greenwood": texture = GREENWOOD_TEX
            "fenlands": texture = FENLANDS_TEX
            "ashen_march": texture = ASHEN_TEX
        draw_texture(texture, Vector2(-texture.get_width() / 2.0, -texture.get_height()))
        if regional_style != "classic":
            _draw_frontier_root_dressing()
    else:
        draw_texture(STUMP_TEX, Vector2(-STUMP_TEX.get_width() / 2.0, -STUMP_TEX.get_height()))


## Draw-only ground detail: no extra nodes, occupancy, collision or harvest state.
func _draw_frontier_root_dressing() -> void:
    match regional_style:
        "greenwood":
            draw_colored_polygon(PackedVector2Array([
                Vector2(-10, -1), Vector2(-8, -4), Vector2(-5, -2), Vector2(-7, 0)
            ]), Color("#425b3b"))
            draw_colored_polygon(PackedVector2Array([
                Vector2(5, -1), Vector2(8, -3), Vector2(11, -1), Vector2(8, 0)
            ]), Color("#62704a"))
            draw_rect(Rect2(-2, -1, 4, 1), Color("#786747"))
        "fenlands":
            draw_line(Vector2(-9, 0), Vector2(-11, -5), Color("#777e59"), 1.0)
            draw_line(Vector2(-6, 0), Vector2(-5, -4), Color("#9b8a58"), 1.0)
            draw_line(Vector2(8, 0), Vector2(10, -5), Color("#687653"), 1.0)
        "ashen_march":
            draw_colored_polygon(PackedVector2Array([
                Vector2(-11, 0), Vector2(-9, -3), Vector2(-6, -1)
            ]), Color("#51463e"))
            draw_colored_polygon(PackedVector2Array([
                Vector2(6, -1), Vector2(9, -4), Vector2(12, -1)
            ]), Color("#76513f"))
            draw_rect(Rect2(-2, -1, 3, 1), Color("#a36b49"))
        _:
            draw_colored_polygon(PackedVector2Array([
                Vector2(-10, 0), Vector2(-8, -3), Vector2(-5, -1)
            ]), Color("#756b49"))
            draw_colored_polygon(PackedVector2Array([
                Vector2(6, -1), Vector2(9, -3), Vector2(11, 0)
            ]), Color("#526044"))
