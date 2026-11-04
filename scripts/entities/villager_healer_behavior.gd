extends RefCounted
## Owns healer treatment cadence and target eligibility.
## Villager retains target ownership, animation and worker state transitions.

var _villager: Variant
var _treatment_timer := 0.0


func configure(villager: Variant) -> void:
    _villager = villager


func tick(delta: float) -> void:
    if not _villager.healer_behavior_target_valid():
        _treatment_timer = 0.0
        _villager.healer_behavior_release(0.15)
        return

    _villager.healer_behavior_face_target()
    _treatment_timer += delta
    if _treatment_timer < _villager.HEAL_INTERVAL:
        return

    _treatment_timer = 0.0
    if not _villager.healer_behavior_apply_heal(_villager.HEAL_AMOUNT):
        _villager.healer_behavior_release(0.15)
