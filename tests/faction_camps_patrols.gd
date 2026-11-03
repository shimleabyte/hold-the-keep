extends SceneTree
## Phase 06.3 regression: deterministic faction camps, fog reveal, patrol leashes and reinforcement budgets.

func ticks(count: int) -> void:
    for i in count:
        await physics_frame


func require(condition: bool, message: String) -> void:
    if condition:
        return
    push_error("FAIL: " + message)
    quit(1)


func patrols_for(camp_id: String) -> Array:
    var result: Array = []
    for enemy in get_nodes_in_group("enemy_patrols"):
        if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.patrol_camp_id == camp_id:
            result.append(enemy)
    return result


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var config = root.get_node("WorldConfig")
    var clock = root.get_node("GameClock")
    var save_system = root.get_node("SaveSystem")
    var faction_registry = root.get_node("FactionRegistry")
    config.apply_profile("frontier")
    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(8)
    clock.set_process(false)
    main.spawner.set_process(false)
    main.spawner.set_physics_process(false)
    main.village.set_process(false)
    main.fog.set_process(false)

    var manager = main.frontier_campaign.faction_camps
    require(manager != null and is_instance_valid(manager),
        "Frontier campaign must own a faction camp manager")
    manager.set_process(false)
    require(manager.camps.size() == 4,
        "Frontier must place exactly one deterministic camp for each faction")

    var reachable: Dictionary = main.nav.reachable_cells(main.nav.cell_of(main.player.global_position))
    var faction_ids: Array = faction_registry.factions.keys()
    faction_ids.sort()
    for faction_id_value in faction_ids:
        var faction_id := String(faction_id_value)
        var camp: Dictionary = manager.camps[faction_id]
        var cell: Vector2i = camp["cell"]
        var faction_data: Dictionary = faction_registry.factions[faction_id]
        var region_id := String(faction_data["region"])
        require(String(main.world.region_id(cell)) == region_id,
            "Camp %s must be placed inside its faction region" % faction_id)
        require(main.territory.owner_at(cell) == "enemy",
            "Camp %s must be placed inside enemy-claimed territory" % faction_id)
        require(reachable.has(cell) and main.nav.is_walkable(cell),
            "Camp %s must be reachable over the navigation grid" % faction_id)
        require(not main.world.occupied.has(cell),
            "Camp %s must not overlap a stronghold, building or resource node" % faction_id)

        var points: Array = camp["patrol_points"]
        require(points.size() >= 2,
            "Camp %s must generate at least two patrol waypoints" % faction_id)
        for point_value in points:
            var point: Vector2 = point_value
            var point_cell: Vector2i = main.nav.cell_of(point)
            require(String(main.world.region_id(point_cell)) == region_id,
                "Patrol waypoint must stay inside its faction region")
            require(main.territory.owner_at(point_cell) == "enemy",
                "Patrol waypoint must stay inside enemy-claimed cells")
            require(Vector2(point_cell - cell).length() * config.tile_size <= float(camp["patrol_radius"]) + config.tile_size,
                "Patrol waypoint must stay inside its camp leash")
            var route: PackedVector2Array = main.nav.path_to(main.nav.center_of(cell), point_cell)
            require(not route.is_empty(), "Camp waypoints must have a reachable A* route")
            for route_point in route:
                var route_cell: Vector2i = main.nav.cell_of(route_point)
                require(String(main.world.region_id(route_cell)) == region_id
                    and main.territory.owner_at(route_cell) == "enemy",
                    "Every precomputed patrol route cell must remain in enemy faction land")

        var target = camp.get("target")
        require(target != null and is_instance_valid(target),
            "Each camp must have a destructible world target")
        require(target.is_in_group("campaign_targets"),
            "Camp targets must receive normal player melee damage")
        require(not target.visible and not bool(camp["activated"]),
            "Unexplored camps must remain hidden until fog-of-war reveals them")

    # Explicitly test that a hidden camp cannot activate, then reveal it.
    var camp_id := String(faction_ids[0])
    var camp: Dictionary = manager.camps[camp_id]
    var camp_cell: Vector2i = camp["cell"]
    var cell_index: int = config.cell_index(camp_cell)
    main.fog.discovered[cell_index] = 0
    manager._process(0.5)
    require(not bool(manager.camps[camp_id]["activated"]),
        "A camp must not activate while its map cell remains unexplored")
    require(patrols_for(camp_id).is_empty(),
        "An unexplored camp must not spawn patrols")

    main.fog.reveal_position(camp["position"], 32.0)
    manager._process(0.5)
    camp = manager.camps[camp_id]
    require(bool(camp["activated"]),
        "A camp must activate when the player permanently reveals it")
    require(camp["target"].visible,
        "The discovered camp target must become visible")
    var patrols := patrols_for(camp_id)
    require(patrols.size() == int(camp["initial_patrols"]),
        "Discovery must deploy the configured initial patrol group")
    require(patrols.size() <= int(camp["patrol_cap"]),
        "Initial patrols must never exceed the active patrol cap")

    # Verify the patrol uses an A* route to its next waypoint, not direct movement.
    var patrol = patrols[0]
    patrol.set_physics_process(false)
    patrol._tick_patrol_route()
    var patrol_goal: Vector2 = patrol.guard_origin
    patrol._move_patrol_toward(patrol_goal, 0.016)
    require(not patrol._patrol_path.is_empty(),
        "Patrol movement must acquire a navigation-grid route")
    for route_point in patrol._patrol_path:
        var route_cell: Vector2i = main.nav.cell_of(route_point)
        require(String(main.world.region_id(route_cell)) == patrol.patrol_region_id,
            "A* patrol route must stay inside its faction region")
        require(main.territory.owner_at(route_cell) == "enemy",
            "A* patrol route must stay inside enemy-controlled territory")
        require(Vector2(route_cell - main.nav.cell_of(patrol.patrol_origin)).length() * config.tile_size
            <= patrol.patrol_radius + config.tile_size,
            "A* patrol route must stay inside the camp's leash")

    # Leaving the radius must force a camp return; a returning patrol ignores bait targets.
    patrol.patrol_radius = 24.0
    patrol.global_position = patrol.patrol_origin + Vector2(40.0, 0.0)
    patrol._tick_patrol_route()
    require(patrol.patrol_returning,
        "A patrol that crosses its leash must enter return mode")
    require(patrol.guard_origin.distance_to(patrol.patrol_origin) < 0.1,
        "Return mode must set the camp as its movement goal")
    require(patrol._nearest_guard_target() == null,
        "A returning patrol must stop pursuing player/defender bait")
    patrol._move_patrol_toward(patrol.patrol_origin, 0.016)
    require(not patrol._patrol_path.is_empty(),
        "A patrol outside its leash must be able to navigate back into the camp")
    for route_point in patrol._patrol_path:
        var return_cell: Vector2i = main.nav.cell_of(route_point)
        require(String(main.world.region_id(return_cell)) == patrol.patrol_region_id
            and main.territory.owner_at(return_cell) == "enemy",
            "A return route may exit the radius but must remain inside faction territory")

    # One vacancy plus an expired cooldown may consume exactly one bounded reinforcement.
    var camp_record: Dictionary = manager.camps[camp_id]
    var previous_budget := int(camp_record["budget"])
    camp_record["timer"] = 0.0
    manager.camps[camp_id] = camp_record
    patrol.retreat()
    manager._process(0.5)
    var reinforced := patrols_for(camp_id)
    require(reinforced.size() == int(camp_record["patrol_cap"]),
        "An available vacancy must receive one reinforcement, up to the active cap")
    var after_reinforcement: Dictionary = manager.camps[camp_id]
    require(int(after_reinforcement["budget"]) == previous_budget - 1,
        "Each reinforcement spawn must consume exactly one budget unit")

    # A full patrol group cannot spawn past its cap or spend its budget.
    after_reinforcement["timer"] = 0.0
    manager.camps[camp_id] = after_reinforcement
    var full_budget: int = int(after_reinforcement["budget"])
    manager._process(0.5)
    require(patrols_for(camp_id).size() == int(after_reinforcement["patrol_cap"]),
        "Active patrol count must never exceed its camp cap")
    require(int(manager.camps[camp_id]["budget"]) == full_budget,
        "A full patrol group must not consume reinforcement budget")

    # Save v13 stores camp cooldown/budget and each patrol's assignment without a schema bump.
    var snapshot: Dictionary = save_system.collect(main)
    require(int(snapshot["version"]) == 14,
        "Faction camps, patrols and Hunter state must use save schema v14")
    require(save_system._valid_save(snapshot),
        "Camp and patrol state must pass structural save validation")
    var saved_camp_records: Array = snapshot["frontier_campaign"]["camps"]["records"]
    require(saved_camp_records.size() == 4,
        "Save must persist the four deterministic camp records")
    var found_saved_patrol := false
    var saved_patrol: Dictionary = {}
    for saved_enemy in snapshot["enemies"]:
        var patrol_state: Dictionary = saved_enemy.get("patrol", {})
        if not patrol_state.is_empty() and String(patrol_state.get("camp_id", "")) == camp_id:
            found_saved_patrol = true
            saved_patrol = saved_enemy
            require(bool(saved_enemy["garrison"]),
                "A saved patrol must remain marked as a garrison unit")
            break
    require(found_saved_patrol,
        "Save must persist active patrol camp assignment and waypoint")
    var invalid_snapshot := snapshot.duplicate(true)
    invalid_snapshot["frontier_campaign"]["camps"]["records"][0]["budget"] = 999
    require(not save_system._valid_save(invalid_snapshot),
        "Save validation must reject unbounded faction reinforcement budgets")

    # Restore one saved patrol assignment through the real enemy restore path.
    var restored_position := Vector2(float(saved_patrol["x"]), float(saved_patrol["y"]))
    var saved_guard_origin := Vector2(float(saved_patrol["guard_x"]), float(saved_patrol["guard_y"]))
    var original_patrol = null
    for candidate in patrols_for(camp_id):
        original_patrol = candidate
        break
    require(original_patrol != null, "A patrol fixture must remain alive for restore testing")
    original_patrol.retreat()
    main.spawner.restore_enemy(saved_patrol)
    manager._bind_restored_patrols()
    var restored_patrols := patrols_for(camp_id)
    require(not restored_patrols.is_empty(),
        "Restoring a saved enemy must rebind it to its owning faction camp")
    var restored_patrol = restored_patrols[0]
    require(restored_patrol.is_patrol and restored_patrol.is_garrison,
        "Restored camp patrol must retain both patrol and garrison policies")
    require(restored_patrol.global_position.distance_to(restored_position) < 0.1,
        "Restored patrol position must remain unchanged")
    require(restored_patrol.patrol_origin.distance_to(camp["position"]) < 0.1,
        "Restored patrol must return to its camp's deterministic position")
    var saved_patrol_state: Dictionary = saved_patrol["patrol"]
    require(restored_patrol.patrol_waypoint_index == int(saved_patrol_state["waypoint_index"]),
        "Restored patrol must preserve its patrol waypoint assignment")
    require(restored_patrol.guard_origin.distance_to(saved_guard_origin) < 0.1
        or restored_patrol.patrol_returning,
        "Restored patrol must restore its patrol/return movement goal")
    require(restored_patrol.patrol_camp_id == camp_id,
        "Restored patrol must retain its faction camp assignment")

    # Destroying the camp must permanently stop its reinforcement and recall every linked patrol.
    var camp_target = manager.camps[camp_id]["target"]
    camp_target.take_damage(9999)
    var destroyed_camp: Dictionary = manager.camps[camp_id]
    require(bool(destroyed_camp["destroyed"]) and int(destroyed_camp["budget"]) == 0,
        "Destroying the camp must clear it and exhaust reinforcement budget")
    require(patrols_for(camp_id).is_empty(),
        "Destroying a camp must immediately recall all of its patrols")
    manager._process(0.5)
    require(patrols_for(camp_id).is_empty(),
        "A destroyed camp must never deploy another patrol")

    print("PASS: deterministic enemy-territory camps, fog discovery, A* bounded patrols, leash return, cap/budget reinforcement, v14 save/restore and camp destruction")
    main.queue_free()
    quit(0)
