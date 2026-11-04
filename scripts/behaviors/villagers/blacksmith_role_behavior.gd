extends "res://scripts/behaviors/villagers/villager_role_behavior.gd"
## Forge equipment target selection, recipes and material transactions.

const WORK_SECONDS := 4.5
const WEAPON_COST := {"iron": 3, "wood": 1}
const ARMOR_COST := {"iron": 4, "wood": 2}

var recipe := ""


func role_id() -> String:
    return "blacksmith"


func get_smith_recipe() -> String:
    return recipe


func set_smith_recipe(value: String) -> void:
    recipe = value


func recipe_for(soldier: Variant) -> String:
    if not is_instance_valid(soldier) or String(soldier.job) != "soldier" or int(soldier.hp) <= 0:
        return ""
    if Tech.is_done("iron_weapons") and not bool(soldier.weapon_equipped):
        return "weapon"
    if Tech.is_done("iron_armor") and not bool(soldier.armor_equipped):
        return "armor"
    return ""


func collect_candidates() -> Array:
    var candidates: Array = []
    if not actor.has_valid_workplace():
        actor._release_workplace()
        if not actor._claim_workplace("blacksmith"):
            return candidates
    if actor._facility_sabotaged(actor.workplace):
        return candidates
    for soldier in actor.get_tree().get_nodes_in_group("villagers"):
        if soldier == actor or not is_instance_valid(soldier) or String(soldier.job) != "soldier":
            continue
        if recipe_for(soldier) == "" or soldier.is_expeditioning() or soldier.is_recalling_expedition() \
                or soldier.state in [ActorState.HIDDEN, ActorState.FLEEING, ActorState.FIGHT]:
            continue
        if not actor._is_in_workplace_radius(soldier) or actor.workplace.is_blacksmith_target_reserved(soldier, actor):
            continue
        candidates.append(soldier)
    return candidates


func invalid_target_retry_seconds() -> float:
    return 0.2


func target_is_valid() -> bool:
    var soldier: Variant = actor.target
    return actor.has_valid_workplace() and soldier != null and is_instance_valid(soldier) \
        and String(soldier.job) == "soldier" and recipe_for(soldier) != "" \
        and recipe_for(soldier) == recipe and not soldier.is_expeditioning() \
        and not soldier.is_recalling_expedition() \
        and soldier.state not in [ActorState.HIDDEN, ActorState.FLEEING, ActorState.FIGHT] \
        and actor._is_in_workplace_radius(soldier)


func claim_target(candidate: Variant) -> bool:
    if not actor.workplace.claim_blacksmith_target(actor, candidate):
        return false
    recipe = recipe_for(candidate)
    if recipe == "":
        actor.workplace.release_blacksmith_target(actor)
        return false
    return true


func release_target() -> void:
    if actor.workplace != null and is_instance_valid(actor.workplace) and actor.workplace.has_method("release_blacksmith_target"):
        actor.workplace.release_blacksmith_target(actor)
    recipe = ""


func perform_work(delta: float) -> bool:
    if not target_is_valid():
        actor._release()
        actor.state = ActorState.IDLE
        actor._decide_t = 0.2
        return true
    actor.anim.face(actor.target.position - actor.position)
    actor._work_t += delta
    if actor._work_t < WORK_SECONDS:
        return true
    var cost: Dictionary = WEAPON_COST if recipe == "weapon" else ARMOR_COST
    var supply = actor.get_tree().get_first_node_in_group("supply_network")
    var paid: bool = supply.pay_cost(cost) if supply != null else Inventory.spend_all(cost)
    if not paid:
        actor._release()
        actor.state = ActorState.IDLE
        actor._decide_t = 4.0
        Events.build_feedback.emit("Bahan tempa tidak cukup")
        return true
    var equipped: bool = actor.target.equip_weapon() if recipe == "weapon" else actor.target.equip_armor()
    if equipped:
        Events.build_feedback.emit("Senjata besi selesai: damage prajurit +20%" if recipe == "weapon"
            else "Zirah besi selesai: HP maksimum prajurit +20%")
    actor._release()
    actor.state = ActorState.IDLE
    actor._decide_t = 0.2
    return true
