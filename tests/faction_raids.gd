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
    for raider in raiders:
        if is_instance_valid(raider) and String(raider.faction_raid_camp_id) == camp_id:
            return raider
    return null


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
    manager.set_process(false)

    var keep = null
    for building in get_nodes_in_group("buildings"):
        if String(building.id) == "keep":
            keep = building
            break
    require(keep != null, "Frontier campaign must provide a Keep")

    var camp_id := ""
    var camp: Dictionary = {}
    for faction_id_value in manager.camps.keys():
        var candidate_id := String(faction_id_value)
        var candidate: Dictionary = manager.camps[candidate_id]
        if main.territory.owner_at(candidate["cell"]) == "enemy":
            camp_id = candidate_id
            camp = candidate
            break
    require(not camp_id.is_empty(), "At least one faction camp must remain in enemy-controlled territory")

    var storage_cell := find_storage_cell(main, camp)
    require(storage_cell.x >= 0, "A walkable storage site inside the camp's faction region must be available")
    var storage = main.build.place_raw("storage", storage_cell)
    await ticks(3)
    main.nav.rebuild()
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

    camp["activated"] = true
    camp["raid_budget"] = 2
    camp["raid_timer"] = 0.0
    manager.camps[camp_id] = camp
    manager._scan_timer = 0.0
    manager._process(0.5)
    var raiders := get_nodes_in_group("faction_raiders")
    var raider = faction_raider_for(raiders, camp_id)
    require(raider != null and raiders.size() == 1,
        "A ready camp must dispatch one targeted raider within the global active cap")
    require(raider.is_faction_raider and raider.is_garrison
        and raider.raid_target_cell == storage_cell and raider.faction_raid_target_kind == "depot",
        "The raider must preserve its camp, depot target, and garrison assignment")
    require(int(manager.camps[camp_id]["raid_budget"]) == 1,
        "A successful dispatch must consume exactly one finite raid-budget charge")

    manager._process(0.5)
    require(get_nodes_in_group("faction_raiders").size() == 1
        and int(manager.camps[camp_id]["raid_budget"]) == 1,
        "A camp must not exceed one active raider or consume budget while its raider is alive")

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

    var snapshot: Dictionary = save_system.collect(main)
    var saved_raider := saved_faction_raid(snapshot["enemies"])
    require(not saved_raider.is_empty()
        and String(saved_raider.get("raid_kind", "")) == "depot"
        and String(saved_raider.get("raid_camp", "")) == camp_id,
        "Save v13 must persist the faction raid kind and dispatching camp")
    require(save_system._valid_save(snapshot),
        "A live faction raid with its camp and target must pass save validation")

    raider.retreat()
    await ticks(1)
    main.spawner.restore_enemy(saved_raider)
    await ticks(1)
    var restored_raider = faction_raider_for(get_nodes_in_group("faction_raiders"), camp_id)
    require(restored_raider != null and restored_raider.raid_target_cell == storage_cell
        and restored_raider.faction_raid_target_kind == "depot",
        "Save restoration must rehydrate the active faction raid assignment")

    main.territory.enemy_claimed_cells.erase(storage.cell)
    var reclaimed_region: Dictionary = main.territory.region_states[String(camp["region_id"])]
    reclaimed_region["control"] = "player"
    main.territory.region_states[String(camp["region_id"])] = reclaimed_region
    main.territory._dirty = false
    restored_raider._tick_faction_raid(0.1)
    require(restored_raider.is_queued_for_deletion(),
        "A faction raider must withdraw immediately when its target region is reclaimed")

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
        "A camp must be able to dispatch a road-targeting raider")
    var road_raider = faction_raider_for(get_nodes_in_group("faction_raiders"), camp_id)
    require(road_raider != null and road_raider.faction_raid_target_kind == "road",
        "The road raider must preserve the road target type")
    road_raider.position = target_road.position
    road_raider._atk_cd = 0.0
    road_raider._tick_faction_raid(0.1)
    road_raider._resolve_pending(0.5)
    require(target_road.hp < target_road.max_hp,
        "A faction raider must apply structural damage to connected road infrastructure")

    require(main.build.demolish_at(road_cell),
        "The targeted road fixture must be removable through the normal build system")
    road_raider._tick_faction_raid(0.1)
    require(road_raider.is_queued_for_deletion(),
        "A raider must abandon a target as soon as its building is removed")

    road_raider.retreat()
    await ticks(1)
    require(get_nodes_in_group("faction_raiders").is_empty(),
        "Withdrawn faction raiders must release their active group slot")

    quit(0)
