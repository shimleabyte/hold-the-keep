extends RefCounted
## Ranged combat policy for archer-specialized villagers.
## The villager remains the owner of state, cooldowns, rally buffs and animation.

const ArrowProjectile := preload("res://scripts/entities/arrow.gd")

const ATTACK_RANGE := 150.0
const MIN_RANGE := 52.0
const DAMAGE_MULTIPLIER := 0.68
const ATTACK_INTERVAL := 1.15
const RETREAT_SPEED := 42.0 * 0.8


## Returns true when this helper owns the current combat tick.
func tick(villager: Node2D, enemy: Node2D, delta: float) -> bool:
    if not bool(villager.call("is_archer")) or not is_instance_valid(enemy):
        return false

    var distance := villager.position.distance_to(enemy.position)
    if distance > ATTACK_RANGE:
        return false

    var animation: Variant = villager.get("anim")
    if animation.face(enemy.position - villager.position):
        villager.queue_redraw()

    if distance < MIN_RANGE:
        var retreat: Vector2 = (villager.position - enemy.position).normalized()
        if retreat.length_squared() > 0.0:
            villager.position += retreat * RETREAT_SPEED * delta

    if float(villager.get("_atk_cd")) <= 0.0:
        var rally_time := float(villager.get("_rally_t"))
        var rally_interval := float(villager.get("_rally_interval_mult"))
        villager.set("_atk_cd", ATTACK_INTERVAL * (rally_interval if rally_time > 0.0 else 1.0))
        _fire_arrow(villager, enemy)
        animation.play("attack", true)
    return true


func _fire_arrow(villager: Node2D, enemy: Node2D) -> void:
    var world: Variant = villager.get("world")
    if not is_instance_valid(enemy) or world == null:
        return
    var entities: Variant = world.get("entities")
    if not is_instance_valid(entities):
        return

    var base_damage := int(villager.call("_soldier_damage"))
    var damage := maxi(1, roundi(float(base_damage) * DAMAGE_MULTIPLIER))
    var projectile = ArrowProjectile.new()
    projectile.setup(enemy, damage)
    entities.add_child(projectile)
    projectile.global_position = villager.global_position + Vector2(0, -7)
