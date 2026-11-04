extends Node2D
## Aimed hostile projectile. It travels toward the target's position at fire time,
## so a player who moves after the archer's telegraph can evade the shot.

const SPEED := 120.0
const HIT_RADIUS := 7.0

var target: Node2D
var aim_position := Vector2.ZERO
var damage := 6
var speed := SPEED


func setup(target_ref: Node2D, amount: int, flight_speed: float, locked_aim_position: Vector2) -> void:
    target = target_ref
    aim_position = locked_aim_position
    damage = amount
    speed = flight_speed


func _ready() -> void:
    add_to_group("enemy_projectiles")


func _physics_process(delta: float) -> void:
    if target == null or not is_instance_valid(target) or not target.visible:
        queue_free()
        return
    var to_aim := aim_position - global_position
    var distance := to_aim.length()
    if distance <= 0.001:
        queue_free()
        return
    var direction := to_aim / distance
    var step := minf(speed * delta, distance)
    var next_position := global_position + direction * step
    var segment := next_position - global_position
    var target_position := target.global_position + Vector2(0, -5)
    var segment_length_squared := segment.length_squared()
    var closest_factor := clampf(
        (target_position - global_position).dot(segment) / maxf(segment_length_squared, 0.001),
        0.0,
        1.0
    )
    var closest_point := global_position + segment * closest_factor
    if closest_point.distance_to(target_position) <= HIT_RADIUS:
        if target.has_method("take_damage"):
            target.take_damage(damage)
        Events.fx_burst.emit("spark", closest_point, Vector2.ZERO, 0.55)
        queue_free()
        return
    global_position = next_position
    rotation = direction.angle()
    if step >= distance:
        queue_free()


func _draw() -> void:
    draw_line(Vector2(-4, 0), Vector2(4, 0), Color("#b86f55"), 2.0)
    draw_line(Vector2(2, -2), Vector2(4, 0), Color("#f1c7a3"), 1.0)
    draw_line(Vector2(2, 2), Vector2(4, 0), Color("#f1c7a3"), 1.0)
