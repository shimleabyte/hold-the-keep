extends "res://scripts/behaviors/villagers/villager_role_behavior.gd"
## Builder project selection, blueprint claims and building repairs.

const DEFAULT_WORK_RADIUS := 12.0
const REPAIR_INTERVAL := 1.6
const REPAIR_AMOUNT := 12


func role_id() -> String:
    return "builder"


func _is_site(candidate: Variant) -> bool:
    return candidate.has_method("is_construction_site") and candidate.is_construction_site()


func collect_candidates() -> Array:
    var candidates: Array = []
    if not actor.has_valid_workplace():
        actor._release_workplace()
        if not actor._claim_workplace("builder"):
            return candidates
    var radius: float = float(actor.workplace.data.get("work_radius", DEFAULT_WORK_RADIUS)) * WorldConfig.tile_size
    var construction_sites: Array = actor.get_tree().get_nodes_in_group("construction_sites")
    construction_sites.sort_custom(func(a, b) -> bool:
        return int(a.queue_order) < int(b.queue_order)
    )
    for site in construction_sites:
        if site.has_method("can_claim") and site.can_claim(actor) and not actor._bad.has(site) \
                and actor.workplace.position.distance_squared_to(site.position) <= radius * radius:
            candidates.append(site)
    for building in actor.get_tree().get_nodes_in_group("buildings"):
        if building.hp <= 0 or building.hp >= building.max_hp or actor._bad.has(building):
            continue
        if actor.workplace.position.distance_squared_to(building.position) > radius * radius:
            continue
        if building.can_assign_repairer(actor):
            candidates.append(building)
    return candidates


func precedes(left: Variant, right: Variant) -> bool:
    var left_is_site: bool = _is_site(left)
    var right_is_site: bool = _is_site(right)
    if left_is_site != right_is_site:
        return left_is_site
    if left_is_site and right_is_site and int(left.queue_order) != int(right.queue_order):
        return int(left.queue_order) < int(right.queue_order)
    return left.position.distance_squared_to(actor.position) < right.position.distance_squared_to(actor.position)


func claim_target(candidate: Variant) -> bool:
    if _is_site(candidate):
        return candidate.claim(actor)
    return candidate.claim_repairer(actor)


func release_target() -> void:
    var reserved: Variant = actor.target
    if reserved == null or not is_instance_valid(reserved):
        return
    if reserved.has_method("release_repairer") and not _is_site(reserved):
        reserved.release_repairer(actor)
    elif reserved.has_method("release"):
        reserved.release(actor)
    elif reserved.get("worker") == actor:
        reserved.worker = null


func on_target_arrived() -> void:
    if actor.target != null and is_instance_valid(actor.target) and _is_site(actor.target):
        actor.target.worker_arrived(actor)


func perform_work(delta: float) -> bool:
    var building: Variant = actor.target
    if _is_site(building):
        actor.anim.face(building.position - actor.position)
        return true
    if int(building.hp) <= 0 or int(building.hp) >= int(building.max_hp):
        actor._release()
        actor.state = ActorState.IDLE
        return true
    actor.anim.face(building.position - actor.position)
    actor._work_t += delta
    if actor._work_t >= REPAIR_INTERVAL:
        actor._work_t = 0.0
        if not building.repair(REPAIR_AMOUNT):
            actor._release()
            actor.state = ActorState.IDLE
            return true
        if int(building.hp) >= int(building.max_hp):
            actor._release()
            actor.state = ActorState.IDLE
    return true
