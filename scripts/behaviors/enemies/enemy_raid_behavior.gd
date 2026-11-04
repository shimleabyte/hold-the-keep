extends RefCounted
## Owns enemy raid target validation and movement while Enemy retains combat, identity and persistence state.

var _enemy: Variant


func configure(enemy: Variant) -> void:
    _enemy = enemy


func find_raid_depot():
    var enemy: Variant = _enemy
    for depot in enemy.get_tree().get_nodes_in_group("depots"):
        if is_instance_valid(depot) and depot.cell == enemy.raid_target_cell and ["storage", "outpost", "granary"].has(String(depot.id)):
            return depot
    return null


func find_faction_raid_target():
    var enemy: Variant = _enemy
    var group_name := "depots" if enemy.faction_raid_target_kind == "depot" else "roads"
    for candidate in enemy.get_tree().get_nodes_in_group(group_name):
        if not is_instance_valid(candidate) or candidate.cell != enemy.raid_target_cell:
            continue
        var candidate_id := String(candidate.id)
        if enemy.faction_raid_target_kind == "depot" and ["storage", "outpost", "granary"].has(candidate_id):
            return candidate
        if enemy.faction_raid_target_kind == "road" and ["road", "bridge"].has(candidate_id):
            return candidate
    return null


func faction_raid_target_valid(target, supply):
    var enemy: Variant = _enemy
    if target == null or not is_instance_valid(target) or int(target.hp) <= 0:
        return false
    if supply == null or not is_instance_valid(supply) or supply.territory == null:
        return false
    supply._ensure_current()
    if String(supply.world.region_id(target.cell)) != enemy.faction_raid_region_id:
        return false

    var owner := String(supply.territory.owner_at(target.cell))
    var region: Dictionary = supply.territory.get_region_state(enemy.faction_raid_region_id)
    var control := String(region.get("control", "neutral"))
    var exposed := owner == "contested" or (owner == "enemy.player" and control in ["enemy", "contested"])
    if not exposed:
        return false

    if enemy.faction_raid_target_kind == "depot":
        return ["storage", "outpost", "granary"].has(String(target.id)) and supply.is_depot_connected(target)
    if enemy.faction_raid_target_kind == "road":
        if not ["road", "bridge"].has(String(target.id)):
            return false
        for cell in target.cells():
            if supply.connected_road_cells.has(cell):
                return true
    return false


func tick_faction_raid(delta: float):
    var enemy: Variant = _enemy
    var target = _find_faction_raid_target()
    var supply = enemy.get_tree().get_first_node_in_group("supply_network")
    if not _faction_raid_target_valid(target, supply):
        enemy.retreat()
        return

    var reach := maxf(enemy._attack_reach(), 28.0)
    if enemy.player != null and is_instance_valid(enemy.player) and enemy.position.distance_to(enemy.player.position) <= reach:
        if enemy.role == "ranged":
            enemy._begin_ranged_attack(enemy.player)
        else:
            enemy._begin_attack(enemy.player, enemy.player.position - enemy.position)
        return
    for defender in enemy.get_tree().get_nodes_in_group("defenders"):
        if not is_instance_valid(defender) or not defender.visible:
            continue
        if enemy.position.distance_to(defender.position) <= reach:
            if enemy.role == "ranged":
                enemy._begin_ranged_attack(defender)
            else:
                enemy._begin_attack(defender, defender.position - enemy.position)
            return
    if enemy.position.distance_to(target.position) <= reach:
        if enemy.role == "ranged":
            enemy._begin_ranged_attack(target)
        else:
            enemy._begin_attack(target, target.position - enemy.position)
        return

    if enemy.raid_nav == null:
        enemy.retreat()
        return
    enemy._raid_repath_timer = maxf(0.0, enemy._raid_repath_timer - delta)
    if enemy._raid_path_version != enemy.raid_nav.version or enemy._raid_path.is_empty() or enemy._raid_repath_timer <= 0.0:
        var target_cells: Array[Vector2i] = target.cells()
        enemy._raid_path = enemy.raid_nav.path_adjacent(enemy.position, target_cells)
        enemy._raid_path_index = 1 if enemy._raid_path.size() > 1 else 0
        enemy._raid_path_version = enemy.raid_nav.version
        enemy._raid_repath_timer = 1.0
        if enemy._raid_path.is_empty():
            enemy.retreat()
            return
    while enemy._raid_path_index < enemy._raid_path.size() and enemy.position.distance_to(enemy._raid_path[enemy._raid_path_index]) <= 3.0:
        enemy._raid_path_index += 1
    if enemy._raid_path_index < enemy._raid_path.size():
        enemy._move_toward(enemy._raid_path[enemy._raid_path_index], delta)


func tick_supply_raid(delta: float):
    var enemy: Variant = _enemy
    var depot = _find_raid_depot()
    if depot == null:
        enemy.retreat()
        return
    var supply = enemy.get_tree().get_first_node_in_group("supply_network")
    if supply == null or supply.is_depot_connected(depot):
        enemy.retreat()
        return

    var reach := maxf(enemy._attack_reach(), 28.0)
    if enemy.player != null and is_instance_valid(enemy.player) and enemy.position.distance_to(enemy.player.position) <= reach:
        enemy._begin_attack(enemy.player, enemy.player.position - enemy.position)
        return
    for defender in enemy.get_tree().get_nodes_in_group("defenders"):
        if not is_instance_valid(defender) or not defender.visible:
            continue
        if enemy.position.distance_to(defender.position) <= reach:
            enemy._begin_attack(defender, defender.position - enemy.position)
            return
    if enemy.position.distance_to(depot.position) <= reach:
        enemy._begin_attack(depot, depot.position - enemy.position)
        return

    if enemy.raid_nav == null:
        return
    enemy._raid_repath_timer = maxf(0.0, enemy._raid_repath_timer - delta)
    if enemy._raid_path_version != enemy.raid_nav.version or enemy._raid_path.is_empty() or enemy._raid_repath_timer <= 0.0:
        var target_cells: Array[Vector2i] = depot.cells()
        enemy._raid_path = enemy.raid_nav.path_adjacent(enemy.position, target_cells)
        enemy._raid_path_index = 1 if enemy._raid_path.size() > 1 else 0
        enemy._raid_path_version = enemy.raid_nav.version
        enemy._raid_repath_timer = 1.0
    while enemy._raid_path_index < enemy._raid_path.size() and enemy.position.distance_to(enemy._raid_path[enemy._raid_path_index]) <= 3.0:
        enemy._raid_path_index += 1
    if enemy._raid_path_index < enemy._raid_path.size():
        enemy._move_toward(enemy._raid_path[enemy._raid_path_index], delta)
