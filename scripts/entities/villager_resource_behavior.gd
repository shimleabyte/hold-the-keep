extends RefCounted
## Owns the resource occupations' task selection and work cadence.
## Navigation, target claims, carrying and depot delivery remain Villager-owned.

var _villager: Variant


func configure(villager: Variant) -> void:
    _villager = villager


func append_candidates(candidates: Array) -> bool:
    var job := String(_villager.job)
    match job:
        "woodcutter", "miner":
            if not _villager.has_valid_workplace():
                _villager._release_workplace()
                _villager._claim_workplace(job)
            # A specialty worksite owns capacity and radius once one exists.
            # Keep the connected-depot fallback only for legacy/no-worksite play.
            if not _villager.has_valid_workplace() and _villager._has_specialized_workplace(job):
                _villager._set_work_status(
                    "WORKPLACE_UNAVAILABLE",
                    "Matching specialist workplaces are full or unreachable"
                )
                return true
            var kind := "wood" if job == "woodcutter" else _mine_kind()
            for resource in _villager.get_tree().get_nodes_in_group("harvestable"):
                var in_work_area: bool = (
                    _villager._is_in_workplace_radius(resource)
                    if _villager.has_valid_workplace()
                    else _villager._is_in_gather_radius(resource)
                )
                if resource.yield_kind == kind and resource.is_available(_villager) and in_work_area:
                    candidates.append(resource)
            return true
        "farmer":
            for farm in _villager.get_tree().get_nodes_in_group("farms"):
                if farm.free_slots("farmer") > 0 and _villager._is_in_work_radius(farm):
                    candidates.append(farm)
            return true
    return false


func tick(delta: float) -> bool:
    var job := String(_villager.job)
    if job == "farmer":
        _tick_farmer(delta)
        return true
    if job in ["woodcutter", "miner"]:
        _tick_gatherer(delta)
        return true
    return false


## Count the central inventory and usable connected Frontier depot stock.
## Disconnected or sabotaged depots must not suppress local iron production.
func _resource_stock_amount(kind: String) -> int:
    var total := int(Inventory.get_amount(kind))
    if not WorldConfig.is_frontier_profile():
        return total
    var supply = _villager.get_tree().get_first_node_in_group("supply_network")
    if supply == null:
        return total
    for depot in _villager.get_tree().get_nodes_in_group("depots"):
        if not is_instance_valid(depot) or String(depot.id) == "keep":
            continue
        if not supply.is_depot_connected(depot) or _villager._facility_sabotaged(depot):
            continue
        if depot.has_method("stockpile_amount"):
            total += int(depot.stockpile_amount(kind))
    return total


## Prefer iron only when a live, unclaimed ore node is inside this miner's
## actual work area. A remote or reserved vein must not strand the miner.
func _mine_kind() -> String:
    if not Tech.has_flag("iron_mining"):
        return "stone"
    var has_local_iron := false
    for resource in _villager.get_tree().get_nodes_in_group("harvestable"):
        if not is_instance_valid(resource) or String(resource.yield_kind) != "iron":
            continue
        if not resource.is_available(_villager):
            continue
        var in_work_area: bool = (
            _villager._is_in_workplace_radius(resource)
            if _villager.has_valid_workplace()
            else _villager._is_in_gather_radius(resource)
        )
        if in_work_area:
            has_local_iron = true
            break
    if not has_local_iron:
        return "stone"
    var iron_stock := _resource_stock_amount("iron")
    var stone_stock := _resource_stock_amount("stone")
    return "iron" if iron_stock <= stone_stock * 0.5 else "stone"


func _tick_farmer(delta: float) -> void:
    var target = _villager.target
    _villager.anim.face(target.position - _villager.position)
    _villager._work_t += delta
    if _villager._work_t < _villager.FARM_CYCLE:
        _villager._set_work_status("FARMING", "Growing food at the assigned farm")
        return

    _villager._work_t = 0.0
    _villager.receive(
        "food",
        roundi(Tech.stat("farm.yield", float(_villager.FARM_YIELD)))
    )
    _villager._set_work_status("FARMING", "Harvested a food batch")
    if _villager.carry >= _villager._carry_cap():
        _villager._go_depot()


func _tick_gatherer(delta: float) -> void:
    var target = _villager.target
    if not target.is_available(_villager):
        if _villager.carry > 0:
            _villager._go_depot()
        else:
            _villager.resource_behavior_release_target()
        return

    _villager.anim.face(target.position - _villager.position)
    _villager._work_t += delta
    if not _villager._hit_done and _villager._work_t >= _villager._hit_interval() * 0.5:
        _villager._hit_done = true
        target.hit(_villager)
        if _villager.carry >= _villager._carry_cap() or not target.is_available(_villager):
            _villager._hit_done = false
            _villager._work_t = 0.0
            if _villager.carry > 0:
                _villager._go_depot()
            else:
                _villager.resource_behavior_release_target()
            return
    if _villager._work_t >= _villager._hit_interval():
        _villager._work_t = 0.0
        _villager._hit_done = false
    else:
        _villager._set_work_status("GATHERING", "Harvesting the assigned resource node")
