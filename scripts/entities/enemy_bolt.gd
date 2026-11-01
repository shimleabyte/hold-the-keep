extends Node2D
## Homing hostile projectile used by ranged enemies.

const SPEED := 120.0

var target: Node2D
var damage := 6
var speed := SPEED


func setup(target_ref: Node2D, amount: int, flight_speed: float) -> void:
    target = target_ref
    damage = amount
    speed = flight_speed


func _ready() -> void:
    add_to_group("enemy_projectiles")


func _physics_process(delta: float) -> void:
    if target == null or not is_instance_valid(target) or not target.visible:
        queue_free()
        return
    var aim := target.global_position + Vector2(0, -5)
    var to_target := aim - global_position
    var distance := to_target.length()
    if distance <= 6.0:
        if target.has_method("take_damage"):
            target.take_damage(damage)
        Events.fx_burst.emit("spark", global_position, Vector2.ZERO, 0.55)
        queue_free()
        return
    var direction := to_target / distance
    rotation = direction.angle()
    global_position += direction * minf(speed * delta, distance)


func _draw() -> void:
    draw_line(Vector2(-4, 0), Vector2(4, 0), Color("#b86f55"), 2.0)
    draw_line(Vector2(2, -2), Vector2(4, 0), Color("#f1c7a3"), 1.0)
    draw_line(Vector2(2, 2), Vector2(4, 0), Color("#f1c7a3"), 1.0)
