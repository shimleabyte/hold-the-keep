extends RefCounted
## Owns enemy raid target validation and movement while Enemy retains combat, identity and persistence state.

var _enemy: Variant


func configure(enemy: Variant) -> void:
    _enemy = enemy


func _find_raid_depot():
    var enemy: Variant = _enemy
    for depot in enemy.get_tree().get_nodes_in_group("depots"):
        if is_instance_valid(depot) and depot.cell == raid_target_cell and ["storage", "outpost", "granary"].has(String(depot.id)):
            return depot
    return null


func _find_faction_raid_target():
    var enemy: Variant = _enemy
    var group_name := "depots" if faction_raid_target_kind == "depot" else "roads"
    for candidate in enemy.get_tree().get_nodes_in_group(group_name):
        if not is_instance_valid(candidate) or candidate.cell != raid_target_cell:
            continue
        var candidate_id := String(candidate.id)
        if faction_raid_target_kind == "depot" and ["storage", "outpost", "granary"].has(candidate_id):
            return candidate
        if faction_raid_target_kind == "road" and ["road", "bridge"].has(candidate_id):
            return candidate
    return null


func _faction_raid_target_valid(target, supply) -> bool:
    var enemy: Variant = _enemy
    if target == null or not is_instance_valid(target) or int(target.hp) <= 0:
        return false
    if supply == null or not is_instance_valid(supply) or supply.territory == null:
        return false
    supply._ensure_current()
    if String(supply.world.region_id(target.cell)) != faction_raid_region_id:
        return false

    var owner := String(supply.territory.owner_at(target.cell))
    var region: Dictionary = supply.territory.get_region_state(faction_raid_region_id)
    var control := String(region.get("control", "neutral"))
    var exposed := owner == "contested" or (owner == "player" and control in ["enemy", "contested"])
    if not exposed:
        return false

    if faction_raid_target_kind == "depot":
        return ["storage", "outpost", "granary"].has(String(target.id)) and supply.is_depot_connected(target)
    if faction_raid_target_kind == "road":
        if not ["road", "bridge"].has(String(target.id)):
            return false
        for cell in target.cells():
            if supply.connected_road_cells.has(cell):
                return true
    return false


func _tick_faction_raid(delta: float) -> void:
    var enemy: Variant = _enemy
    var target = _find_faction_raid_target()
    var supply = enemy.get_tree().get_first_node_in_group("supply_network")
    if not _faction_raid_target_valid(target, supply):
        retreat()
        return

    var reach := maxf(_attack_reach(), 28.0)
    if player != null and is_instance_valid(player) and position.distance_to(player.position) <= reach:
        if role == "ranged":
            _begin_ranged_attack(player)
        else:
            _begin_attack(player, player.position - position)
        return
    for defender in enemy.get_tree().get_nodes_in_group("defenders"):
        if not is_instance_valid(defender) or not defender.visible:
            continue
        if position.distance_to(defender.position) <= reach:
            if role == "ranged":
                _begin_ranged_attack(defender)
            else:
                _begin_attack(defender, defender.position - position)
            return
    if position.distance_to(target.position) <= reach:
        if role == "ranged":
            _begin_ranged_attack(target)
        else:
            _begin_attack(target, target.position - position)
        return

    if raid_nav == null:
        retreat()
        return
    _raid_repath_timer = maxf(0.0, _raid_repath_timer - delta)
    if _raid_path_version != raid_nav.version or _raid_path.is_empty() or _raid_repath_timer <= 0.0:
        var target_cells: Array[Vector2i] = target.cells()
        _raid_path = raid_nav.path_adjacent(position, target_cells)
        _raid_path_index = 1 if _raid_path.size() > 1 else 0
        _raid_path_version = raid_nav.version
        _raid_repath_timer = 1.0
        if _raid_path.is_empty():
            retreat()
            return
    while _raid_path_index < _raid_path.size() and position.distance_to(_raid_path[_raid_path_index]) <= 3.0:
        _raid_path_index += 1
    if _raid_path_index < _raid_path.size():
        _move_toward(_raid_path[_raid_path_index], delta)


func _tick_supply_raid(delta: float) -> void:
    var enemy: Variant = _enemy
    var depot = _find_raid_depot()
    if depot == null:
        retreat()
        return
    var supply = enemy.get_tree().get_first_node_in_group("supply_network")
    if supply == null or supply.is_depot_connected(depot):
        retreat()
        return

    var reach := maxf(_attack_reach(), 28.0)
    if player != null and is_instance_valid(player) and position.distance_to(player.position) <= reach:
        _begin_attack(player, player.position - position)
        return
    for defender in enemy.get_tree().get_nodes_in_group("defenders"):
        if not is_instance_valid(defender) or not defender.visible:
            continue
        if position.distance_to(defender.position) <= reach:
            _begin_attack(defender, defender.position - position)
            return
    if position.distance_to(depot.position) <= reach:
        _begin_attack(depot, depot.position - position)
        return

    if raid_nav == null:
        return
    _raid_repath_timer = maxf(0.0, _raid_repath_timer - delta)
    if _raid_path_version != raid_nav.version or _raid_path.is_empty() or _raid_repath_timer <= 0.0:
        var target_cells: Array[Vector2i] = depot.cells()
        _raid_path = raid_nav.path_adjacent(position, target_cells)
        _raid_path_index = 1 if _raid_path.size() > 1 else 0
        _raid_path_version = raid_nav.version
        _raid_repath_timer = 1.0
    while _raid_path_index < _raid_path.size() and position.distance_to(_raid_path[_raid_path_index]) <= 3.0:
        _raid_path_index += 1
    if _raid_path_index < _raid_path.size():
        _move_toward(_raid_path[_raid_path_index], delta)
