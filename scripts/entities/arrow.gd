extends Node2D
## Anak panah homing sederhana dari menara.

const SPRITE := preload("res://assets/sprites/arrow.svg")

const SPEED := 220.0

var target: Node2D
var damage := 5


func setup(t: Node2D, dmg: int) -> void:
    target = t
    damage = dmg


func _physics_process(delta: float) -> void:
    if target == null or not is_instance_valid(target) or not target.is_in_group("enemies") and not target.is_in_group("enemy_garrison"):
        queue_free()
        return
    var aim := target.global_position + Vector2(0, -6)
    var to := aim - global_position
    var dist := to.length()
    if dist < 4.0:
        if target.has_method("take_damage_from"):
            target.take_damage_from(damage, global_position)
        else:
            target.take_damage(damage)
        queue_free()
        return
    rotation = to.angle()
    global_position += to / dist * minf(SPEED * delta, dist)


func _draw() -> void:
    draw_texture(SPRITE, Vector2(-8, -1))
