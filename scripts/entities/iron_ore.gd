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

var _hp := MAX_HP


func _ready() -> void:
    var shape := RectangleShape2D.new()
    shape.size = Vector2(12, 7)
    var col := CollisionShape2D.new()
    col.shape = shape
    col.position = Vector2(0, -3.5)
    add_child(col)
    Events.tech_researched.connect(_on_tech)
    _update_group()


func _on_tech(_id: String) -> void:
    _update_group()


func _update_group() -> void:
    remove_from_group("harvestable")
    remove_from_group("ore_locked")
    if _hp <= 0:
        return
    add_to_group("harvestable" if Tech.has_flag("iron_mining") else "ore_locked")


func is_available(by = null) -> bool:
    return _hp > 0 and Tech.has_flag("iron_mining") and (worker == null or worker == by or not is_instance_valid(worker))


func hit(by = null) -> void:
    if _hp <= 0:
        return
    _hp -= 1
    Events.fx_burst.emit("stone", global_position + Vector2(0, -5), Vector2.ZERO, 2.0 if _hp == 0 else 1.0)
    _give(IRON_PER_HIT, by)
    modulate = Color(1.8, 1.8, 1.8)
    create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)
    if _hp == 0:
        _give(IRON_BONUS, by)
        worker = null
        _update_group()
        queue_redraw()
        get_tree().create_timer(REGROW_SECONDS).timeout.connect(_regrow)


func _give(amount: int, by) -> void:
    if by != null and is_instance_valid(by) and by.has_method("receive"):
        by.receive(yield_kind, amount)
    else:
        Inventory.add(yield_kind, amount)


func _regrow() -> void:
    _hp = MAX_HP
    _update_group()
    queue_redraw()


func _draw() -> void:
    var tex: Texture2D = ORE_TEX if _hp > 0 else DEPLETED_TEX
    draw_texture(tex, Vector2(-tex.get_width() / 2.0, -tex.get_height()))
