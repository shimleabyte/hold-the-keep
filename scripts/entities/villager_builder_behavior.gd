extends RefCounted
## Owns Builder repair cadence and repair-target completion policy.
## Villager retains the target claim, shared timer, animation and worker state.

var _villager: Variant


func configure(villager: Variant) -> void:
    _villager = villager


func tick(delta: float) -> void:
    var target = _villager.target
    if target.has_method("is_construction_site") and target.is_construction_site():
        _villager.anim.face(target.position - _villager.position)
        if _villager.builder_behavior_advance_construction(delta):
            Events.fx_burst.emit("dust", target.global_position + Vector2(0, -5), Vector2.ZERO, 0.45)
        return
    if int(target.hp) <= 0 or int(target.hp) >= int(target.max_hp):
        _villager.builder_behavior_release()
        return

    _villager.anim.face(target.position - _villager.position)
    if not _villager.builder_behavior_advance_work(delta):
        return
    if not target.repair(_villager.BUILDER_REPAIR_AMOUNT):
        _villager.builder_behavior_release("REPAIR_SUPPLY_UNAVAILABLE")
        return
    Events.fx_burst.emit("impact", target.global_position + Vector2(0, -8), Vector2.UP, 0.45)
    if int(target.hp) >= int(target.max_hp):
        _villager.builder_behavior_release("TARGET_COMPLETE")
