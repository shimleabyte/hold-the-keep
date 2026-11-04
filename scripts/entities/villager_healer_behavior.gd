extends RefCounted
## Owns healer treatment cadence and target eligibility.
## Villager retains target ownership, animation and worker state transitions.

var _villager: Variant
var _treatment_timer := 0.0


func configure(villager: Variant) -> void:
    _villager = villager


func tick(delta: float) -> void:
    if not _target_valid():
        _treatment_timer = 0.0
        _villager.healer_behavior_release(0.15)
        return

    _villager.anim.face(_villager.target.position - _villager.position)
    _treatment_timer += delta
    if _treatment_timer < _villager.HEAL_INTERVAL:
        return

    _treatment_timer = 0.0
    if _villager.target.heal(_villager.HEAL_AMOUNT) <= 0 or int(_villager.target.hp) >= int(_villager.target.max_hp):
        _villager.healer_behavior_release(0.15)


func _target_valid() -> bool:
    var target = _villager.target
    if not _villager.has_valid_workplace() or target == null or not is_instance_valid(target):
        return false
    return String(target.job) == "soldier" and int(target.hp) > 0 \
        and int(target.hp) < int(target.max_hp) and not target.is_expeditioning() \
        and not target.is_recalling_expedition() \
        and not target.is_unavailable_for_healing() \
        and _villager._is_in_workplace_radius(target)
