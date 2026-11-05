extends RefCounted
## Owns blacksmith target eligibility, crafting cadence and equipment transaction.
## Villager retains the selected target, recipe claim, worker timer and state.

var _villager: Variant


func configure(villager: Variant) -> void:
    _villager = villager


func tick(delta: float) -> void:
    if not _target_valid():
        _villager.blacksmith_behavior_release(0.2)
        return

    _villager.anim.face(_villager.workplace.position - _villager.position)
    if not _villager.blacksmith_behavior_advance_work(delta):
        return

    var recipe: String = _villager.blacksmith_behavior_assigned_recipe()
    var cost: Dictionary = _villager.BLACKSMITH_WEAPON_COST if recipe == "weapon" else _villager.BLACKSMITH_ARMOR_COST
    var supply = _villager.get_tree().get_first_node_in_group("supply_network")
    var paid: bool = supply.pay_cost(cost) if supply != null else Inventory.spend_all(cost)
    if not paid:
        _villager.blacksmith_behavior_release(4.0)
        Events.build_feedback.emit("Bahan tempa tidak cukup")
        return

    var equipped: bool = _villager.target.equip_weapon() if recipe == "weapon" else _villager.target.equip_armor()
    if equipped:
        Events.fx_burst.emit("spark", _villager.workplace.global_position + Vector2(0, -7), Vector2.UP, 0.9)
        Events.build_feedback.emit("Senjata besi selesai: damage prajurit +20%" if recipe == "weapon"
            else "Zirah besi selesai: HP maksimum prajurit +20%")
    _villager.blacksmith_behavior_release(0.2)


func _target_valid() -> bool:
    var target = _villager.target
    if not _villager.has_valid_workplace() or target == null or not is_instance_valid(target):
        return false
    var recipe: String = _villager.blacksmith_behavior_recipe_for(target)
    return String(target.job) == "soldier" and recipe != "" \
        and recipe == _villager.blacksmith_behavior_assigned_recipe() \
        and not target.is_expeditioning() and not target.is_recalling_expedition() \
        and not target.is_unavailable_for_blacksmithing() \
        and _villager._is_in_workplace_radius(target)
