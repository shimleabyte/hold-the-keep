extends SceneTree
## Phase 03 regression: four regional objectives, ordered conquest, local garrisons and v8 saves.

func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func _guards_for(stronghold) -> Array:
    var guards: Array = []
    for guard in get_nodes_in_group("enemy_garrison"):
        if is_instance_valid(guard) and guard.guard_origin.distance_squared_to(stronghold.position) < 1.0:
            guards.append(guard)
    return guards


func _initialize() -> void:
    var game_clock = root.get_node("GameClock")
    var world_config = root.get_node("WorldConfig")
    var save_system = root.get_node("SaveSystem")
    world_config.apply_profile("frontier")
    DirAccess.remove_absolute("user://save.json")
    DirAccess.remove_absolute("user://save.tmp")
    DirAccess.remove_absolute("user://save.bak")

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(8)
    game_clock.set_process(false)
    var flow_wait_frames := 0
    while not main.flow.is_current():
        await ticks(1)
        flow_wait_frames += 1
        assert(flow_wait_frames < 600,
            "Initial enemy flow field must publish before stronghold garrison assertions")

    var objectives: Array = main.campaign.objectives_in_order()
    var expected := ["greenwood_raiders", "iron_legion", "fen_cult", "ashen_host"]
    var expected_regions := ["GREENWOOD", "HIGHLANDS", "FENLANDS", "ASHEN_MARCH"]
    assert(objectives.size() == 4, "Frontier campaign must create four stronghold objectives")
    assert(get_nodes_in_group("enemy_strongholds").size() == 4,
        "All four regional strongholds must be present in the world")

    var seen_regions: Dictionary = {}
    for index in objectives.size():
        var objective: Dictionary = objectives[index]
        assert(objective["id"] == expected[index], "Objective order must be deterministic")
        assert(objective["region"] == expected_regions[index], "Faction must own its assigned biome")
        assert(not seen_regions.has(objective["region"]), "Strongholds must occupy distinct regions")
        seen_regions[objective["region"]] = true
        var cell := Vector2i(int(objective["cx"]), int(objective["cy"]))
        assert(main.world.region_id(cell) == objective["region"],
            "Stronghold must be placed inside its assigned region")
        var stronghold = main.campaign._nodes[objective["id"]]
        assert(is_instance_valid(stronghold), "Each objective must have a live stronghold node")
        assert(not main.nav.path_adjacent(main.player.position, stronghold.cells()).is_empty(),
            "Every regional stronghold must be reachable from the homeland")
        assert(_guards_for(stronghold).size() == 3,
            "Each stronghold must spawn its own initial garrison")

    var stronghold_guard_count := 0
    for guard in get_nodes_in_group("enemy_garrison"):
        if is_instance_valid(guard) and String(guard.campaign_site_id).is_empty():
            stronghold_guard_count += 1
    assert(stronghold_guard_count == 12,
        "Four strongholds must maintain twelve local guards, excluding Frontier objective-site guards")
    assert(main.campaign.current_target_id() == expected[0],
        "Greenwood must be the first objective")

    var first = main.campaign.current_target_node()
    var second = main.campaign._nodes[expected[1]]
    var second_guard_count := _guards_for(second).size()
    var snapshot_before: Dictionary = save_system.collect(main)
    assert(snapshot_before["campaign"]["objectives"].size() == 4,
        "Save v8 must include every campaign objective")
    assert(save_system._valid_save(snapshot_before),
        "Fresh multi-stronghold campaign must pass save validation")

    var locked_hp: int = second.hp
    second.take_damage(500)
    assert(second.hp == locked_hp, "Later objectives must remain locked until their turn")

    first.take_damage(9999)
    assert(first.hp == 0, "The active stronghold must be destructible")
    assert(not main.campaign_conquered,
        "Conquering one region must not end a Frontier campaign")
    assert(main.campaign.current_target_id() == expected[1],
        "Conquering Greenwood must unlock the Iron Legion")
    assert(_guards_for(second).size() == second_guard_count,
        "Destroying one stronghold must not retreat another garrison")
    assert(main.territory.owner_at(first.cell) != "enemy",
        "Destroyed stronghold must release its hostile territory")

    var snapshot: Dictionary = save_system.collect(main)
    assert(snapshot["campaign"]["objectives"].size() == 4,
        "Save must retain both defeated and active objectives")
    assert(bool(snapshot["campaign"]["objectives"][0]["destroyed"]),
        "Save must preserve the first conquered stronghold")
    assert(not bool(snapshot["campaign"]["objectives"][1]["destroyed"]),
        "Save must preserve the next active stronghold")
    assert(save_system._valid_save(snapshot),
        "Mid-campaign v8 snapshot must pass validation")

    main.queue_free()
    await process_frame
    save_system.pending = snapshot
    var restored = load("res://scenes/main.tscn").instantiate()
    root.add_child(restored)
    current_scene = restored
    await ticks(8)
    game_clock.set_process(false)

    assert(restored.campaign.current_target_id() == expected[1],
        "Loading must resume the same campaign objective")
    assert(restored.campaign.objectives_in_order().size() == 4,
        "Loading must preserve the full objective registry")
    assert(restored.campaign._nodes.size() == 3,
        "Conquered strongholds must not respawn after loading")
    assert(restored.campaign.current_target_node().hp == int(snapshot["campaign"]["objectives"][1]["hp"]),
        "Loading must restore active stronghold HP")
    assert(_guards_for(restored.campaign.current_target_node()).size() == 3,
        "Loading must restore the active stronghold's local garrison")

    var remaining_order := [expected[1], expected[2], expected[3]]
    for stronghold_id in remaining_order:
        var target = restored.campaign.current_target_node()
        assert(target != null and target.stronghold_id == stronghold_id,
            "Campaign target order must remain deterministic after reload")
        target.take_damage(9999)
        if stronghold_id != expected[3]:
            assert(not restored.campaign_conquered,
                "Campaign must remain active while strongholds remain")

    assert(not restored.campaign_conquered,
        "Stronghold conquest alone must not bypass Phase 07 regional objectives and final King")

    for objective_id in restored.frontier_campaign.objectives:
        assert(restored.frontier_campaign.complete_objective(String(objective_id)),
            "Every required regional objective must be completable: " + String(objective_id))
    restored.frontier_campaign._on_final_boss_defeated(20)

    assert(restored.campaign_conquered,
        "Frontier victory requires all four strongholds, all regional objectives and the day-20 King")
    assert(restored.campaign.current_target_node() == null,
        "Completed campaign must not retain an active target")
    assert(paused, "Final conquest must display the paused victory state")

    print("PASS: ordered strongholds, regional objective gate, day-20 King, local garrisons and save/load")
    quit()
