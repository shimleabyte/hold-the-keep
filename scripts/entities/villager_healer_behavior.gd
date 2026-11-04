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
