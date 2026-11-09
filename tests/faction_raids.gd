extends SceneTree
## Phase 06.4 regression: camps dispatch bounded raids against exposed connected depots and roads.

func ticks(count: int) -> void:
    for _index in count:
        await physics_frame


func require(condition: bool, message: String) -> void:
    if condition:
        return
    push_error("FAIL: " + message)
    quit(1)


func find_storage_cell(main, camp: Dictionary) -> Vector2i:
    var camp_cell: Vector2i = camp["cell"]
    var region_id := String(camp["region_id"])
    for radius in range(12, 25):
        for y in range(-radius, radius + 1):
            for x in range(-radius, radius + 1):
                if maxi(absi(x), absi(y)) != radius:
                    continue
                var anchor: Vector2i = camp_cell + Vector2i(x, y)
                var cells: Array[Vector2i] = []
                var valid := true
                for cy in 2:
                    for cx in 2:
                        var cell := anchor + Vector2i(cx, cy)
                        if not main.world.is_buildable(cell) or main.world.occupied.has(cell):
                            valid = false
                            break
                        if String(main.world.region_id(cell)) != region_id:
                            valid = false
                            break
                        cells.append(cell)
                    if not valid:
                        break
                if not valid:
                    continue
                if main.nav.path_adjacent(Vector2(camp["position"]), cells).is_empty():
                    continue
                return anchor
    return Vector2i(-1, -1)


func find_forward_outpost_anchor(main, keep, camp: Dictionary, target) -> Vector2i:
    var config: Node = root.get_node("WorldConfig")
    var camp_path: PackedVector2Array = main.nav.path_adjacent(Vector2(camp["position"]), target.cells())
    if camp_path.is_empty():
        return Vector2i(-1, -1)
    var best_path_size := camp_path.size()
    var best_anchor := Vector2i(-1, -1)
    var footprint := Vector2i(2, 2)
    for radius in range(1, 28):
        for y in range(-radius, radius + 1):
            for x in range(-radius, radius + 1):
                if maxi(absi(x), absi(y)) != radius:
                    continue
                var anchor: Vector2i = Vector2i(keep.get("cell")) + Vector2i(x, y)
                var valid := true
                for fy in footprint.y:
                    for fx in footprint.x:
                        var cell := anchor + Vector2i(fx, fy)
                        if not main.world.is_buildable(cell) or main.world.occupied.has(cell):
                            valid = false
                            break
                        if String(main.world.region_id(cell)) != String(keep.get("region_id")):
                            valid = false
                            break
                    if not valid:
                        break
                if not valid or not main.territory.can_enemy_place_outpost(anchor, footprint):
                    continue
                var origin := Vector2(
                    (anchor.x + 1.0) * int(config.get("tile_size")),
                    (anchor.y + 2.0) * float(config.get("tile_size"))
                )
                var path: PackedVector2Array = main.nav.path_adjacent(origin, target.cells())
                if not path.is_empty() and path.size() < best_path_size:
                    best_path_size = path.size()
                    best_anchor = anchor
    return best_anchor


func road_cell_passable(main, cell: Vector2i) -> bool:
    if not main.world.is_buildable(cell):
        return false
    var occupant = main.world.occupied.get(cell)
    return occupant == null or (is_instance_valid(occupant) and occupant.is_in_group("roads"))


func find_road_path(main, keep, depot) -> Array[Vector2i]:
    var directions: Array[Vector2i] = [
        Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
    ]
    var queue: Array[Vector2i] = []
    var parents: Dictionary = {}
    for keep_cell in keep.cells():
        for direction in directions:
            var start: Vector2i = keep_cell + direction
            if road_cell_passable(main, start) and not parents.has(start):
                parents[start] = Vector2i(-1, -1)
                queue.append(start)

    var destination_cells: Array[Vector2i] = depot.cells()
    var cursor := 0
    var endpoint := Vector2i(-1, -1)
    while cursor < queue.size():
        var current: Vector2i = queue[cursor]
        cursor += 1
        for direction in directions:
            if destination_cells.has(current + direction):
                endpoint = current
                break
        if endpoint.x >= 0:
            break
        for direction in directions:
            var next: Vector2i = current + direction
            if parents.has(next) or not road_cell_passable(main, next):
                continue
            parents[next] = current
            queue.append(next)

    if endpoint.x < 0:
        return []
    var path: Array[Vector2i] = []
    var current := endpoint
    while current.x >= 0:
        path.append(current)
        current = parents[current]
    path.reverse()
    return path


func expose_cell(main, cell: Vector2i) -> void:
    var region_id := String(main.world.region_id(cell))
    main.territory.claimed_cells[cell] = true
    main.territory.enemy_claimed_cells[cell] = true
    var state: Dictionary = main.territory.region_states.get(region_id, {})
    state["control"] = "contested"
    main.territory.region_states[region_id] = state
    main.territory._dirty = false


func faction_raider_for(raiders: Array, camp_id: String) -> Node:
    var fallback: Node
    for raider in raiders:
        if not is_instance_valid(raider) or String(raider.faction_raid_camp_id) != camp_id:
            continue
        if fallback == null:
            fallback = raider
        if String(raider.faction_raid_role) == "leader":
            return raider
    return fallback


func faction_raiders_for(raiders: Array, camp_id: String) -> Array:
    var members: Array = []
    for raider in raiders:
        if is_instance_valid(raider) and String(raider.faction_raid_camp_id) == camp_id:
            members.append(raider)
    return members


func saved_faction_raid(enemies: Array) -> Dictionary:
    for enemy_state in enemies:
        if enemy_state is Dictionary and bool(enemy_state.get("faction_raid", false)):
            return enemy_state
    return {}


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var config = root.get_node("WorldConfig")
    var clock = root.get_node("GameClock")
    var save_system = root.get_node("SaveSystem")
    config.apply_profile("frontier")
    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(10)
    clock.set_process(false)
    root.get_node("Tech").set_process(false)
    main.spawner.set_process(false)
    main.spawner.set_physics_process(false)
    main.village.set_process(false)
    main.fog.set_process(false)
    main.supply.set_process(false)
    main.nav.set_physics_process(false)
    main.territory.set_physics_process(false)

    var manager = main.frontier_campaign.faction_camps
    require(manager != null and is_instance_valid(manager) and manager.camps.size() == 4,
        "Frontier must provide one live camp manager for each faction")
    require(manager._raid_selector != null and manager._raid_selector.main == main,
        "The manager must configure its isolated raid selector against the active world")
    manager.set_process(false)

    var keep = null
    for building in get_nodes_in_group("buildings"):
        if String(building.id) == "keep":
            keep = building
            break
    require(keep != null, "Frontier campaign must provide a Keep")

    var camp_id := "greenwood_raiders"
    require(manager.camps.has(camp_id),
        "The deterministic Greenwood raid fixture must have a registered faction camp")
    var camp: Dictionary = manager.camps[camp_id]
    require(main.territory.owner_at(camp["cell"]) == "enemy",
        "The Greenwood raid fixture must remain in enemy-controlled territory")

    var storage_cell := find_storage_cell(main, camp)
    require(storage_cell.x >= 0, "A walkable storage site inside the camp's faction region must be available")
    var storage = main.build.place_raw("storage", storage_cell)
    await ticks(3)
    main.nav.rebuild()

    var rival_keep = main.campaign._nodes.get(camp_id)
    require(rival_keep != null and is_instance_valid(rival_keep),
        "The faction camp must resolve its matching regional stronghold")
    var outpost_anchor := find_forward_outpost_anchor(main, rival_keep, camp, storage)
    require(outpost_anchor.x >= 0,
        "A legal outpost site must provide a shorter reachable route to the exposed depot")
    require(bool(rival_keep.civilization.call("_spawn_structure", "outpost", outpost_anchor)),
        "The regional civilization must complete a forward outpost for raid staging")
    await ticks(2)
    main.nav.rebuild()
    main.territory.rebuild()
    var forward_outpost: Node2D
    for structure in rival_keep.civilization.structures:
        if is_instance_valid(structure) and String(structure.structure_id) == "outpost":
            forward_outpost = structure
            break
    require(forward_outpost != null,
        "The faction's completed outpost must be registered as a live enemy building")

    var road_path := find_road_path(main, keep, storage)
    require(not road_path.is_empty(), "A road connection must be routable from the Keep to remote infrastructure")
    for road_cell in road_path:
        if not main.world.occupied.has(road_cell):
            main.build.place_raw("road", road_cell)
    await ticks(3)
    main.nav.rebuild()
    main.supply.rebuild()
    main.territory.rebuild()
    require(main.supply.is_depot_connected(storage),
        "The fixture depot must be genuinely connected to the Keep through placed roads")

    expose_cell(main, storage.cell)
    var exposed_road_count := 0
    for road in get_nodes_in_group("roads"):
        if String(main.world.region_id(road.cell)) == String(camp["region_id"]):
            expose_cell(main, road.cell)
            exposed_road_count += 1
    require(exposed_road_count > 0,
        "The connected road route must cross the selected faction region")
    require(main.territory.owner_at(camp["cell"]) == "enemy",
        "Fixture infrastructure must not accidentally suppress its originating faction camp")

    require(storage.store_resource("food", 2) and storage.store_resource("wood", 4),
        "The connected depot must contain local resources for raid-theft assertions")

    var target: Dictionary = manager._find_raid_target(camp)
    require(not target.is_empty() and String(target.get("kind", "")) == "depot"
        and Vector2i(target.get("cell", Vector2i(-1, -1))) == storage_cell,
        "A faction camp must prioritize reachable, exposed, connected depots")
    require(String(target.get("origin_kind", "")) == "outpost"
        and Vector2(target.get("origin", Vector2.ZERO)).distance_to(forward_outpost.position) < 1.0,
        "A reachable forward outpost with the shorter route must become the faction raid launch point")

    camp["activated"] = true
    camp["raid_budget"] = 2
    camp["raid_timer"] = 0.0
    manager.camps[camp_id] = camp
    manager._scan_timer = 0.0
    manager._process(0.5)
    var raiders := get_nodes_in_group("faction_raiders")
    var assault_group := faction_raiders_for(raiders, camp_id)
    var raider = faction_raider_for(raiders, camp_id)
    require(raider != null and assault_group.size() == 3,
        "A ready camp must dispatch a three-unit coordinated assault within the global squad cap")
    require(raider.is_faction_raider and raider.is_garrison and raider.id == "bandit"
        and raider.raid_target_cell == storage_cell and raider.faction_raid_target_kind == "depot"
        and raider.faction_raid_role == "leader",
        "The assault leader must preserve its faction-native unit, shared target and campaign identity")
    require(raider.position.distance_to(forward_outpost.position) < 1.0
        and raider.guard_origin.distance_to(forward_outpost.position) < 1.0,
        "The assault leader must launch from and retain the forward outpost origin")
    var unique_roles: Dictionary = {}
    for member in assault_group:
        unique_roles[String(member.faction_raid_role)] = true
        require(String(member.faction_raid_group_id) == String(raider.faction_raid_group_id)
            and member.raid_target_cell == storage_cell,
            "All assault members must share one assault identity and the same infrastructure objective")
    require(unique_roles.has("leader") and unique_roles.has("escort") and not unique_roles.has("siege"),
        "Greenwood's assault must field a leader and faction-native escorts without inventing siege equipment")
    require(int(manager.camps[camp_id]["raid_budget"]) == 1,
        "A full three-unit assault must consume one finite raid-budget charge")

    manager._process(0.5)
    require(faction_raiders_for(get_nodes_in_group("faction_raiders"), camp_id).size() == 3
        and int(manager.camps[camp_id]["raid_budget"]) == 1,
        "A camp must count a live squad as one active raid and not spend budget twice")

    raider._tick_faction_raid(0.1)
    require(not raider._raid_path.is_empty() and raider._raid_path_version == main.nav.version,
        "A dispatched raider must build a current nav-grid route toward its explicit infrastructure target")

    var original_player_position: Vector2 = main.player.position
    main.player.position = Vector2(-1000, -1000)
    raider.position = storage.position
    raider._atk_cd = 0.0
    raider._tick_faction_raid(0.1)
    require(raider._pending == storage,
        "A faction raider must attack its explicit depot target after reaching it")
    raider._resolve_pending(0.5)
    var first_hit_hp: int = storage.hp
    require(first_hit_hp < storage.max_hp and storage.stockpile_amount("food") == 2,
        "The first depot strike must damage the building without stealing prematurely")
    raider._atk_cd = 0.0
    raider._tick_faction_raid(0.1)
    raider._resolve_pending(0.5)
    require(storage.stockpile_amount("food") == 1 and storage.hp < first_hit_hp,
        "Every second successful depot strike must steal one local resource")

    main.player.position = original_player_position
    var snapshot: Dictionary = save_system.collect(main)
    var saved_camp_record: Dictionary = {}
    for record in snapshot["frontier_campaign"]["camps"]["records"]:
        if String(record.get("id", "")) == camp_id:
            saved_camp_record = record
            break
    require(not saved_camp_record.is_empty()
        and int(saved_camp_record.get("raid_budget", -1)) == 1
        and float(saved_camp_record.get("raid_timer", -1.0)) >= 0.0,
        "Save v13 must preserve the finite camp raid budget and cooldown")
    var saved_assault_id := String(raider.faction_raid_group_id)
    var saved_assault: Array[Dictionary] = []
    for enemy_state in snapshot["enemies"]:
        if enemy_state is Dictionary and bool(enemy_state.get("faction_raid", false)) \
                and String(enemy_state.get("raid_group", "")) == saved_assault_id:
            saved_assault.append(enemy_state)
    require(saved_assault.size() == 3,
        "Save v17 must persist every member and shared identity of the coordinated assault")
    require(String(saved_assault[0].get("raid_kind", "")) == "depot"
        and String(saved_assault[0].get("raid_camp", "")) == camp_id,
        "The saved squad must retain its faction, depot target and dispatching camp")
    require(save_system._valid_save(snapshot),
        "A live coordinated faction assault must pass save payload validation")

    for member in assault_group:
        member.retreat()
    await ticks(1)
    for saved_member in saved_assault:
        main.spawner.restore_enemy(saved_member)
    await ticks(1)
    var restored_group := faction_raiders_for(get_nodes_in_group("faction_raiders"), camp_id)
    var restored_raider = faction_raider_for(restored_group, camp_id)
    require(restored_group.size() == 3 and restored_raider != null
        and restored_raider.raid_target_cell == storage_cell
        and restored_raider.faction_raid_group_id == saved_assault_id,
        "Save restoration must rehydrate all members under their original shared assault identity")
    require(restored_raider.guard_origin.distance_to(forward_outpost.position) < 1.0,
        "Save restoration must preserve the forward outpost staging origin")

    # Losing the forward staging structure must recall the entire squad to its
    # regional stronghold; the squad must not continue attacking from a dead post.
    forward_outpost.call("take_damage", 99999)
    await ticks(1)
    restored_raider._tick_faction_raid(0.1)
    for member in restored_group:
        require(bool(member.faction_raid_retreating),
            "Destroying the launch outpost must order every assault member to withdraw")
        member.position = rival_keep.position
        member._tick_faction_raid(0.1)
    await ticks(1)
    require(faction_raiders_for(get_nodes_in_group("faction_raiders"), camp_id).is_empty(),
        "The outpost-loss withdrawal must reach the stronghold and clear the active squad")

    # Reclaim the first depot so the raid selector must choose the still-exposed
    # connected road network instead of repeatedly preferring the same storage.
    main.territory.enemy_claimed_cells.erase(storage.cell)
    var reclaimed_region: Dictionary = main.territory.region_states[String(camp["region_id"])]
    reclaimed_region["control"] = "player"
    main.territory.region_states[String(camp["region_id"])] = reclaimed_region
    main.territory._dirty = false

    var road_target: Dictionary = {}
    for _attempt in 12:
        road_target = manager._find_raid_target(camp)
        if String(road_target.get("kind", "")) == "road":
            break
    require(String(road_target.get("kind", "")) == "road",
        "When the depot is reclaimed, a camp may retarget an exposed connected road instead")

    var road_cell: Vector2i = road_target["cell"]
    var target_road = main.world.occupied.get(road_cell)
    require(target_road != null and is_instance_valid(target_road) and target_road.is_in_group("roads"),
        "Road raid targets must resolve to a live road or bridge building")
    require(manager._spawn_faction_raid(camp, road_target),
        "A camp must be able to dispatch a road-targeting assault")
    var road_group := faction_raiders_for(get_nodes_in_group("faction_raiders"), camp_id)
    var road_raider = faction_raider_for(road_group, camp_id)
    require(road_group.size() == 3 and road_raider != null
        and road_raider.faction_raid_target_kind == "road",
        "The road assault must preserve its three-unit composition and shared target type")
    road_raider.position = target_road.position
    road_raider._atk_cd = 0.0
    road_raider._tick_faction_raid(0.1)
    road_raider._resolve_pending(0.5)
    require(target_road.hp < target_road.max_hp,
        "A faction assault must apply structural damage to connected road infrastructure")

    require(main.build.demolish_at(road_cell),
        "The targeted road fixture must be removable through the normal build system")
    road_raider._tick_faction_raid(0.1)
    for member in road_group:
        require(bool(member.faction_raid_retreating),
            "Destroying the assault target must send every surviving unit into coordinated withdrawal")
        member.position = member.guard_origin
        member._tick_faction_raid(0.1)
    await ticks(1)
    require(get_nodes_in_group("faction_raiders").is_empty(),
        "Withdrawn assault members must return to staging and release the active squad slot")

    quit(0)
