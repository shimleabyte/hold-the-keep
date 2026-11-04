extends "res://scripts/behaviors/villagers/villager_role_behavior.gd"
## Soldier target acquisition and melee/archer combat. Path movement remains owned by Villager.

const ArrowProjectile := preload("res://scripts/entities/arrow.gd")
const RUN_DISTANCE := 70.0
const SPEED := 42.0
const RUN_SPEED := 66.0
const REACH := 11.0
const ATTACK_HIT_DELAY := 0.14
const SOLDIER_SEARCH := 300.0
const ARCHER_SEARCH := 260.0
const ARCHER_ATTACK_RANGE := 150.0
const ARCHER_MIN_RANGE := 52.0
const ARCHER_DAMAGE_MULT := 0.68
const ARCHER_ATTACK_INTERVAL := 1.15
const OUTPOST_GUARD_RADIUS := 128.0


func role_id() -> String:
    return "soldier"


func tick_idle(delta: float) -> bool:
    actor._scan_t -= delta
    if actor._scan_t > 0.0:
        return false
    actor._scan_t = 0.3
    actor._foe = nearest_enemy()
    return actor._foe != null


func nearest_enemy() -> Variant:
    var best: Variant = null
    var best_distance: float = ARCHER_SEARCH if actor.is_archer() else SOLDIER_SEARCH
    var candidates: Array = actor.get_tree().get_nodes_in_group("enemy_garrison") if actor._expeditioning else actor.get_tree().get_nodes_in_group("enemies")
    for candidate in candidates:
        var enemy := candidate as Node2D
        if actor.is_outpost_guard() and enemy.position.distance_to(actor.guard_outpost.position) > float(actor.guard_outpost.data.get("guard_radius", OUTPOST_GUARD_RADIUS)):
            continue
        var distance: float = actor.position.distance_to(enemy.position)
        if distance < best_distance:
            best_distance = distance
            best = candidate
    return best


func tick_fight(delta: float) -> bool:
    actor._scan_t -= delta
    if actor._scan_t <= 0.0:
        actor._scan_t = 0.3
        actor._foe = nearest_enemy()
    var foe: Variant = actor._foe
    if foe == null or not is_instance_valid(foe):
        actor._foe = null
        return false
    var distance: float = actor.position.distance_to(foe.position)
    if actor.is_archer() and distance <= ARCHER_ATTACK_RANGE:
        if actor.anim.face(foe.position - actor.position):
            actor.queue_redraw()
        if distance < ARCHER_MIN_RANGE:
            var retreat: Vector2 = (actor.position - foe.position).normalized()
            if retreat.length_squared() > 0.0:
                actor.position += retreat * SPEED * 0.8 * delta
        if actor._atk_cd <= 0.0:
            var rally_interval: float = actor._rally_interval_mult if actor._rally_t > 0.0 else 1.0
            actor._atk_cd = ARCHER_ATTACK_INTERVAL * rally_interval
            fire_archer_arrow(foe)
            actor.anim.play("attack", true)
        return true
    if not actor.is_archer() and distance < REACH:
        if actor.anim.face(foe.position - actor.position):
            actor.queue_redraw()
        if actor._atk_cd <= 0.0:
            actor._atk_cd = actor._soldier_attack_interval()
            actor._pending_foe = foe
            actor._pending_t = ATTACK_HIT_DELAY
            actor.anim.play("attack", true)
        return true
    actor._pursue_combat_target(foe, delta)
    return true


func fire_archer_arrow(enemy: Variant) -> void:
    if not is_instance_valid(enemy) or actor.world == null or actor.world.entities == null:
        return
    var projectile = ArrowProjectile.new()
    projectile.setup(enemy, maxi(1, roundi(float(actor._soldier_damage()) * ARCHER_DAMAGE_MULT)))
    actor.world.entities.add_child(projectile)
    projectile.global_position = actor.global_position + Vector2(0, -7)
