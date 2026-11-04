extends "res://scripts/behaviors/villagers/villager_role_behavior.gd"
## Shared harvesting behavior for Woodcutters, Miners and Hunters.

func role_id() -> String:
    return String(actor.job)


func collect_candidates() -> Array:
    var candidates: Array = []
    if actor.job in ["woodcutter", "miner"]:
        if not actor.has_valid_workplace():
            actor._release_workplace()
            actor._claim_workplace(actor.job)
        # A specialty workplace is authoritative when one exists; do not bypass
        # its capacity by falling back to the Keep's broader work radius.
        if not actor.has_valid_workplace() and actor._has_specialized_workplace(actor.job):
            return candidates
        var kind: String = "wood" if actor.job == "woodcutter" else mine_kind()
        for resource in actor.get_tree().get_nodes_in_group("harvestable"):
            var in_work_area: bool = actor._is_in_workplace_radius(resource) if actor.has_valid_workplace() else actor._is_in_work_radius(resource)
            if resource.yield_kind == kind and resource.is_available(actor) and in_work_area and not actor._bad.has(resource):
                candidates.append(resource)
    elif actor.job == "hunter":
        if not actor.has_valid_workplace():
            actor._release_workplace()
            if not actor._claim_workplace("hunter"):
                return candidates
        for wildlife in actor.get_tree().get_nodes_in_group("wildlife"):
            if wildlife.yield_kind == "food" and wildlife.is_available(actor) \
                    and actor._is_in_workplace_radius(wildlife) and not actor._bad.has(wildlife):
                candidates.append(wildlife)
    return candidates


func mine_kind() -> String:
    if Tech.has_flag("iron_mining") and Inventory.get_amount("iron") <= Inventory.get_amount("stone") * 0.5:
        for node in actor.get_tree().get_nodes_in_group("harvestable"):
            if node.yield_kind == "iron":
                return "iron"
    return "stone"


func perform_work(delta: float) -> bool:
    var resource: Variant = actor.target
    if not resource.is_available(actor):
        if actor.carry > 0:
            actor._go_depot()
        else:
            actor._release()
            actor.state = ActorState.IDLE
        return true
    actor.anim.face(resource.position - actor.position)
    actor._work_t += delta
    if not actor._hit_done and actor._work_t >= actor._hit_interval() * 0.5:
        actor._hit_done = true
        resource.hit(actor)
        if actor.carry >= actor._carry_cap() or not resource.is_available(actor):
            actor._hit_done = false
            actor._work_t = 0.0
            if actor.carry > 0:
                actor._go_depot()
            else:
                actor._release()
                actor.state = ActorState.IDLE
            return true
    if actor._work_t >= actor._hit_interval():
        actor._work_t = 0.0
        actor._hit_done = false
    return true
