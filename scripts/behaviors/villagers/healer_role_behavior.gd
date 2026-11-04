extends "res://scripts/behaviors/villagers/villager_role_behavior.gd"
## Infirmary patient selection, reservations and bounded treatment.

const HEAL_INTERVAL := 3.2
const HEAL_AMOUNT := 10


func role_id() -> String:
    return "healer"


func collect_candidates() -> Array:
    var candidates: Array = []
    if not actor.has_valid_workplace():
        actor._release_workplace()
        if not actor._claim_workplace("healer"):
            return candidates
    for patient in actor.get_tree().get_nodes_in_group("villagers"):
        if patient == actor or not is_instance_valid(patient) or String(patient.job) != "soldier":
            continue
        if int(patient.hp) <= 0 or int(patient.hp) >= int(patient.max_hp):
            continue
        if patient.is_expeditioning() or patient.is_recalling_expedition() \
                or patient.state in [ActorState.HIDDEN, ActorState.FLEEING]:
            continue
        if not actor._is_in_workplace_radius(patient) or actor.workplace.is_heal_target_reserved(patient, actor):
            continue
        candidates.append(patient)
    return candidates


func precedes(left: Variant, right: Variant) -> bool:
    var left_ratio: float = float(left.hp) / float(maxi(1, left.max_hp))
    var right_ratio: float = float(right.hp) / float(maxi(1, right.max_hp))
    if not is_equal_approx(left_ratio, right_ratio):
        return left_ratio < right_ratio
    return left.position.distance_squared_to(actor.position) < right.position.distance_squared_to(actor.position)


func invalid_target_retry_seconds() -> float:
    return 0.15


func target_is_valid() -> bool:
    var patient: Variant = actor.target
    return actor.has_valid_workplace() and patient != null and is_instance_valid(patient) \
        and String(patient.job) == "soldier" and int(patient.hp) > 0 \
        and int(patient.hp) < int(patient.max_hp) and not patient.is_expeditioning() \
        and not patient.is_recalling_expedition() \
        and patient.state not in [ActorState.HIDDEN, ActorState.FLEEING] \
        and actor._is_in_workplace_radius(patient)


func claim_target(candidate: Variant) -> bool:
    return actor.workplace.claim_heal_target(actor, candidate)


func release_target() -> void:
    if actor.workplace != null and is_instance_valid(actor.workplace) and actor.workplace.has_method("release_heal_target"):
        actor.workplace.release_heal_target(actor)


func perform_work(delta: float) -> bool:
    if not target_is_valid():
        actor._release()
        actor.state = ActorState.IDLE
        actor._decide_t = 0.15
        return true
    actor.anim.face(actor.target.position - actor.position)
    actor._work_t += delta
    if actor._work_t >= HEAL_INTERVAL:
        actor._work_t = 0.0
        if actor.target.heal(HEAL_AMOUNT) <= 0 or int(actor.target.hp) >= int(actor.target.max_hp):
            actor._release()
            actor.state = ActorState.IDLE
            actor._decide_t = 0.15
    return true
