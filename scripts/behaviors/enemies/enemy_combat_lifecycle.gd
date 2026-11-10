extends RefCounted
## Owns shared enemy attack timing, hit resolution, stagger and death lifecycle.
## Enemy retains identity, archetype state, navigation and persisted combat fields.

const ENEMY_BOLT := preload("res://scripts/entities/enemy_bolt.gd")
const ATTACK_HIT_DELAY := 0.14
const MELEE_HIT_ARC_MIN_DOT := 0.5 # 120-degree forward sector, matching the player's readable melee arc
const Corpse := preload("res://scripts/entities/corpse.gd")

var _enemy: Variant
var _pending_aim_position := Vector2.ZERO
var _pending_melee_direction := Vector2.DOWN


func configure(enemy: Variant) -> void:
    _enemy = enemy


func begin_attack(target, direction: Vector2) -> void:
    var enemy: Variant = _enemy
    if enemy._atk_cd > 0.0:
        return
    enemy._atk_cd = enemy.attack_interval
    enemy._pending = target
    enemy._pending_is_projectile = false
    _pending_melee_direction = (
        direction.normalized()
        if direction.length_squared() > 0.001
        else Vector2.DOWN
    )
    if enemy.anim.face(_pending_melee_direction):
        enemy.queue_redraw()
    enemy.anim.play("attack", true)
    if enemy.role == "pouncer":
        enemy._pending_t = 0.28
        enemy._pounce_dir = direction.normalized()
        enemy._pounce_windup_t = 0.12
        enemy._pounce_t = 0.16
        Events.fx_burst.emit("dust", enemy.position + Vector2(0, -2), -enemy._pounce_dir, 1.3)
    else:
        enemy._pending_t = ATTACK_HIT_DELAY
    enemy.combat_feedback.begin_windup(_pending_melee_direction, enemy._pending_t, false)
    Audio.play("charge" if enemy.role == "pouncer" else "windup", 1.0, -9.0)


func begin_ranged_attack(target: Node2D) -> void:
    var enemy: Variant = _enemy
    if enemy._atk_cd > 0.0:
        return
    enemy._atk_cd = enemy.attack_interval
    enemy._pending = target
    enemy._pending_is_projectile = true
    enemy._pending_t = 0.14
    _pending_aim_position = target.global_position + Vector2(0, -5)
    if enemy.anim.face(_pending_aim_position - enemy.global_position):
        enemy.queue_redraw()
    enemy.anim.play("attack", true)
    enemy.combat_feedback.begin_windup(target.position - enemy.position, enemy._pending_t, true)
    Audio.play("projectile", 1.0, -9.0)


func resolve_pending(delta: float) -> void:
    var enemy: Variant = _enemy
    if enemy._pending == null:
        return
    enemy._pending_t -= delta
    if enemy._pending_t > 0.0:
        return
    var target = enemy._pending
    enemy._pending = null
    var locked_direction := _pending_melee_direction
    _pending_melee_direction = Vector2.DOWN
    enemy.combat_feedback.end_windup()
    if not is_instance_valid(target):
        enemy._pending_is_projectile = false
        return
    if enemy._pending_is_projectile:
        enemy._pending_is_projectile = false
        var bolt := ENEMY_BOLT.new()
        bolt.global_position = enemy.global_position + Vector2(0, -8)
        bolt.setup(target, enemy.damage, enemy.projectile_speed, _pending_aim_position)
        enemy.world.entities.add_child(bolt)
        return
    enemy._pending_is_projectile = false
    if target == enemy.player or target.is_in_group("defenders"):
        var target_still_exposed: bool = bool(target.visible)
        var allowed_reach := maxf(enemy._attack_reach(), 36.0 if enemy.role == "pouncer" else 0.0)
        if not target_still_exposed or enemy.global_position.distance_to(target.global_position) > allowed_reach:
            return
        # A normal melee wind-up is committed to its original facing. A target
        # that crosses behind the attacker can sidestep the hit during telegraph.
        # Pouncers keep their separate leap/range behavior.
        if enemy.role != "pouncer":
            var target_offset: Vector2 = target.global_position - enemy.global_position
            if target_offset.length_squared() > 0.0001:
                if target_offset.normalized().dot(locked_direction) < MELEE_HIT_ARC_MIN_DOT:
                    return
    if (enemy.is_supply_raider or enemy.is_faction_raider) and target.is_in_group("depots"):
        enemy.supply_raid_hits += 1
        if enemy.supply_raid_hits % 2 == 0:
            var supply = enemy.get_tree().get_first_node_in_group("supply_network")
            if supply != null:
                supply.raid_steal_from(target)
    var final_damage: int = enemy.damage
    if target.is_in_group("buildings"):
        final_damage = roundi(float(enemy.damage) * enemy.structure_damage_mult)
    if target.has_method("take_damage_from"):
        target.take_damage_from(final_damage, enemy.global_position)
    else:
        target.take_damage(final_damage)


func apply_stagger(duration: float) -> void:
    var enemy: Variant = _enemy
    var effective_duration: float = duration * (1.0 - enemy.stagger_resistance)
    enemy._stagger_t = maxf(enemy._stagger_t, effective_duration)
    enemy.combat_feedback.register_stagger(effective_duration)
    enemy._pending = null
    enemy._pending_is_projectile = false
    enemy._pending_t = 0.0
    enemy.combat_feedback.end_windup()
    enemy._pounce_windup_t = 0.0
    enemy._pounce_t = 0.0
    if enemy.archetype == "shieldbearer":
        enemy.shield_behavior.interrupt()
    if enemy.archetype == "scout":
        enemy.scout_behavior.interrupt()
    if enemy.archetype == "saboteur":
        enemy.saboteur_behavior.interrupt()
    if enemy.archetype == "siege_engine":
        enemy.siege_behavior.interrupt()
    if enemy.archetype == "beast_rider":
        enemy.beast_behavior.interrupt()
    enemy._hurt_t = maxf(enemy._hurt_t, duration * 0.5)
    enemy.anim.play("hurt", true)
    Audio.play("stagger", 1.0, -8.0)


func receive_healing(amount: int) -> void:
    var enemy: Variant = _enemy
    if enemy.hp <= 0 or amount <= 0:
        return
    var previous_hp: int = enemy.hp
    enemy.hp = mini(enemy.max_hp, enemy.hp + amount)
    if enemy.hp != previous_hp:
        enemy.queue_redraw()


## Direction from the impacted actor back toward the strike source.
## Unknown sources preserve the existing radial hit burst.
static func impact_particle_direction(source_position: Vector2, actor_position: Vector2) -> Vector2:
    if source_position.length_squared() <= 0.001:
        return Vector2.ZERO
    return (source_position - actor_position).normalized()


func take_damage(amount: int) -> void:
    _take_damage_from(amount, Vector2.ZERO)


func take_damage_from(amount: int, source_position: Vector2) -> void:
    _take_damage_from(amount, source_position)


func _take_damage_from(amount: int, source_position: Vector2) -> void:
    var enemy: Variant = _enemy
    if enemy.hp <= 0:
        return
    var damage_multiplier: float = 1.0 - enemy.armor
    var blocked_by_shield: bool = enemy.archetype == "shieldbearer" and enemy.shield_behavior.blocks_hit_from(source_position)
    if blocked_by_shield:
        damage_multiplier *= enemy.shield_behavior.block_damage_multiplier
    var applied := maxi(1, roundi(float(amount) * damage_multiplier))
    enemy.hp -= applied
    if blocked_by_shield:
        Events.fx_burst.emit("stone", enemy.position + Vector2(0, -enemy._fh * 0.4), -enemy.shield_behavior.brace_direction, 0.8)
        Audio.play("block", 1.0, -5.0)
    else:
        var impact_direction := impact_particle_direction(source_position, enemy.global_position)
        Events.fx_burst.emit(
            "impact",
            enemy.position + Vector2(0, -enemy._fh * 0.4),
            impact_direction,
            2.0 if enemy.is_boss else 1.0
        )
        Audio.play("impact_hit", 1.0, -9.0)
    enemy.modulate = Color(1.8, 1.8, 1.8)
    enemy.combat_feedback.register_hit(source_position, enemy.global_position, 2.0 if enemy.is_boss else 1.0)
    enemy.create_tween().tween_property(enemy, "modulate", enemy._faction_tint, 0.12)
    enemy.queue_redraw()
    if enemy.hp <= 0:
        enemy.remove_from_group("enemies")
        enemy.remove_from_group("enemy_garrison")
        enemy.remove_from_group("enemy_patrols")
        enemy.remove_from_group("ranged_enemies")
        enemy.remove_from_group("supply_raiders")
        enemy.remove_from_group("faction_raiders")
        Events.enemy_killed.emit(enemy.id)
        if enemy.is_boss:
            if WorldConfig.is_frontier_profile():
                Events.frontier_final_boss_defeated.emit(GameClock.day)
            else:
                Events.game_won.emit(GameClock.day)
        Events.fx_burst.emit("puff" if enemy.is_boss else "dust", enemy.position + Vector2(0, -2), Vector2.ZERO, 2.0 if enemy.is_boss else 1.5)
        if enemy.is_boss:
            Events.screen_shake.emit(3.0, 0.6)
        Corpse.spawn(enemy.get_parent(), enemy._tex, enemy._fw, enemy._fh, enemy.anim.view, enemy.anim.flip, enemy.position)
        enemy.queue_free()
    elif not enemy.is_boss and not (enemy.anim.clip == "attack" and not enemy.anim.finished):
        enemy._hurt_t = 0.18
