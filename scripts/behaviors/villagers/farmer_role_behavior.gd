extends "res://scripts/behaviors/villagers/villager_role_behavior.gd"
## Farm assignment and periodic food production.

const FARM_CYCLE := 12.0
const FARM_YIELD := 3


func role_id() -> String:
    return "farmer"


func collect_candidates() -> Array:
    var candidates: Array = []
    for farm in actor.get_tree().get_nodes_in_group("farms"):
        if farm.free_slots("farmer") > 0 and actor._is_in_work_radius(farm) and not actor._bad.has(farm):
            candidates.append(farm)
    return candidates


func perform_work(delta: float) -> bool:
    actor.anim.face(actor.target.position - actor.position)
    actor._work_t += delta
    if actor._work_t >= FARM_CYCLE:
        actor._work_t = 0.0
        actor.receive("food", roundi(Tech.stat("farm.yield", float(FARM_YIELD))))
        if actor.carry >= actor._carry_cap():
            actor._go_depot()
    return true
