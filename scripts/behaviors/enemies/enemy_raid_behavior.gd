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
    var exposed := owner == "contested" or (owner == "player" and control in ["enemy", "contested"])
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


func begin_faction_assault_retreat() -> void:
    var enemy: Variant = _enemy
    _begin_assault_retreat(enemy)


func _assault_members(enemy: Variant) -> Array:
    var members: Array = []
    var group_id := String(enemy.faction_raid_group_id)
    for candidate in enemy.get_tree().get_nodes_in_group("faction_raiders"):
        if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
            continue
        if String(candidate.faction_raid_group_id) == group_id:
            members.append(candidate)
    return members


func _begin_assault_retreat(enemy: Variant) -> void:
    var members := _assault_members(enemy)
    if members.is_empty():
        members.append(enemy)
    for member in members:
        if bool(member.faction_raid_retreating):
            continue
        member.faction_raid_retreating = true
        member._pending = null
        member._pending_t = 0.0
        member._pending_is_projectile = false
        member.siege_behavior.interrupt()
        member._raid_path.clear()
        member._raid_path_index = 0
        member._raid_path_version = -1
        member._raid_repath_timer = 0.0


func _assault_needs_retreat(enemy: Variant) -> bool:
    if int(enemy.faction_raid_group_size) <= 1:
        return false
    var members := _assault_members(enemy)
    var siege_alive := false
    for member in members:
        if String(member.faction_raid_role) == "siege":
            siege_alive = true
            break
    if bool(enemy.faction_raid_siege_required) and not siege_alive:
        return true
    var retreat_threshold := maxi(1, floori(float(enemy.faction_raid_group_size) * 0.5))
    return members.size() <= retreat_threshold


func _assault_origin_is_live(enemy: Variant) -> bool:
    var origin := Vector2(enemy.guard_origin)
    for candidate in enemy.get_tree().get_nodes_in_group("enemy_buildings"):
        if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
            continue
        if String(candidate.get("structure_id")) != "outpost":
            continue
        if String(candidate.get("faction_id")) != String(enemy.faction_id):
            continue
        if Vector2(candidate.position).distance_squared_to(origin) <= 1.0:
            return true

    for candidate in enemy.get_tree().get_nodes_in_group("faction_camp_targets"):
        if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
            continue
        if String(candidate.get("camp_id")) == String(enemy.faction_raid_camp_id) \
                and Vector2(candidate.position).distance_squared_to(origin) <= 1.0:
            return true
    return false


func _find_assault_return_target(enemy: Variant) -> Dictionary:
    var origin := Vector2(enemy.guard_origin)
    for candidate in enemy.get_tree().get_nodes_in_group("enemy_buildings"):
        if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
            continue
        if String(candidate.get("structure_id")) != "outpost":
            continue
        if String(candidate.get("faction_id")) != String(enemy.faction_id):
            continue
        if Vector2(candidate.position).distance_squared_to(origin) > 1.0:
            continue
        var outpost_cells: Array[Vector2i] = []
        for cell_value in candidate.call("cells"):
            outpost_cells.append(Vector2i(cell_value))
        return {"node": candidate, "cells": outpost_cells}

    for candidate in enemy.get_tree().get_nodes_in_group("faction_camp_targets"):
        if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
            continue
        if String(candidate.get("camp_id")) != String(enemy.faction_raid_camp_id):
            continue
        if Vector2(candidate.position).distance_squared_to(origin) > 1.0:
            continue
        var camp_cell := Vector2i((candidate.position / float(WorldConfig.tile_size)).floor())
        var camp_cells: Array[Vector2i] = [camp_cell]
        return {"node": candidate, "cells": camp_cells}

    for candidate in enemy.get_tree().get_nodes_in_group("enemy_strongholds"):
        if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
            continue
        if String(candidate.get("faction_id")) != String(enemy.faction_id):
            continue
        if String(candidate.get("region_id")) != String(enemy.faction_raid_region_id):
            continue
        var keep_cells: Array[Vector2i] = []
        for cell_value in candidate.call("cells"):
            keep_cells.append(Vector2i(cell_value))
        return {"node": candidate, "cells": keep_cells}
    return {}


func _tick_assault_retreat(enemy: Variant, delta: float) -> void:
    var return_target := _find_assault_return_target(enemy)
    if return_target.is_empty():
        enemy.retreat()
        return
    var target_node: Node2D = return_target["node"]
    var target_cells: Array[Vector2i] = return_target["cells"]
    if enemy.position.distance_to(target_node.position) <= 30.0:
        enemy.retreat()
        return
    if enemy.raid_nav == null or not is_instance_valid(enemy.raid_nav):
        enemy.retreat()
        return

    enemy._raid_repath_timer = maxf(0.0, enemy._raid_repath_timer - delta)
    if enemy._raid_path_version != enemy.raid_nav.version or enemy._raid_path.is_empty() or enemy._raid_repath_timer <= 0.0:
        enemy._raid_path = enemy.raid_nav.path_adjacent(enemy.position, target_cells)
        enemy._raid_path_index = 1 if enemy._raid_path.size() > 1 else 0
        enemy._raid_path_version = enemy.raid_nav.version
        enemy._raid_repath_timer = 1.0
        if enemy._raid_path.is_empty():
            # A blocked return route is not a reason to despawn a surviving
            # assault member. Keep the withdrawal order active and retry after
            # navigation changes or a later route refresh.
            enemy._raid_repath_timer = 0.5
            return
    while enemy._raid_path_index < enemy._raid_path.size() and enemy.position.distance_to(enemy._raid_path[enemy._raid_path_index]) <= 3.0:
        enemy._raid_path_index += 1
    if enemy._raid_path_index < enemy._raid_path.size():
        enemy._move_toward(enemy._raid_path[enemy._raid_path_index], delta)


func tick_faction_raid(delta: float):
    var enemy: Variant = _enemy
    if bool(enemy.faction_raid_retreating):
        _tick_assault_retreat(enemy, delta)
        return

    enemy.faction_raid_strength_scan_timer = maxf(0.0, float(enemy.faction_raid_strength_scan_timer) - delta)
    if enemy.faction_raid_strength_scan_timer <= 0.0:
        enemy.faction_raid_strength_scan_timer = 0.4
        if _assault_needs_retreat(enemy):
            _begin_assault_retreat(enemy)
            _tick_assault_retreat(enemy, delta)
            return

    if not _assault_origin_is_live(enemy):
        _begin_assault_retreat(enemy)
        _tick_assault_retreat(enemy, delta)
        return

    var return_target := _find_assault_return_target(enemy)
    if return_target.is_empty():
        _begin_assault_retreat(enemy)
        _tick_assault_retreat(enemy, delta)
        return

    var target = find_faction_raid_target()
    var supply = enemy.get_tree().get_first_node_in_group("supply_network")
    if not faction_raid_target_valid(target, supply):
        _begin_assault_retreat(enemy)
        _tick_assault_retreat(enemy, delta)
        return

    if String(enemy.faction_raid_role) == "siege":
        enemy.siege_behavior.tick_faction_assault_target(target as Node2D, delta)
        return
    if enemy.archetype == "war_shaman" and enemy._tick_shaman_support():
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
        _begin_assault_retreat(enemy)
        _tick_assault_retreat(enemy, delta)
        return
    enemy._raid_repath_timer = maxf(0.0, enemy._raid_repath_timer - delta)
    if enemy._raid_path_version != enemy.raid_nav.version or enemy._raid_path.is_empty() or enemy._raid_repath_timer <= 0.0:
        var target_cells: Array[Vector2i] = target.cells()
        enemy._raid_path = enemy.raid_nav.path_adjacent(enemy.position, target_cells)
        enemy._raid_path_index = 1 if enemy._raid_path.size() > 1 else 0
        enemy._raid_path_version = enemy.raid_nav.version
        enemy._raid_repath_timer = 1.0
        if enemy._raid_path.is_empty():
            _begin_assault_retreat(enemy)
            _tick_assault_retreat(enemy, delta)
            return
    while enemy._raid_path_index < enemy._raid_path.size() and enemy.position.distance_to(enemy._raid_path[enemy._raid_path_index]) <= 3.0:
        enemy._raid_path_index += 1
    if enemy._raid_path_index < enemy._raid_path.size():
        enemy._move_toward(enemy._raid_path[enemy._raid_path_index], delta)


func tick_supply_raid(delta: float):
    var enemy: Variant = _enemy
    var depot = find_raid_depot()
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
