extends SceneTree

var world_config
var game_clock
var save_system

## End-to-end Frontier reload: completed objectives, an active escort and a damaged stronghold.


func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func first_reachable_cell_in_region(main: Node, region_id: String) -> Vector2i:
    var reachable: Dictionary = main.nav.reachable_cells(
        main.nav.cell_of(main.player.global_position)
    )
    for value in reachable.keys():
        var cell: Vector2i = value
        if String(main.world.region_id(cell)) == region_id and main.nav.is_walkable(cell):
            return cell
    return Vector2i(-1, -1)


func _run() -> void:
    world_config.apply_profile("frontier")
    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(10)
    game_clock.set_process(false)

    var greenwood := first_reachable_cell_in_region(main, "GREENWOOD")
    assert(greenwood.x >= 0, "Greenwood must be reachable for the campaign discovery")
    main.player.position = main.nav.center_of(greenwood)
    main.frontier_campaign._scan_discovery()
    assert(bool(main.frontier_campaign.objectives["discover_greenwood"]["completed"]),
        "Greenwood discovery must complete before the save")

    var camp = main.frontier_campaign.sites["greenwood_raider_camp"]
    camp.take_damage(9999)
    assert(bool(main.frontier_campaign.objectives["greenwood_raider_camp"]["completed"]),
        "The first required camp objective must be completed")
    main.campaign.current_target_node().take_damage(9999)
    assert(main.frontier_campaign.unlocked_act == 2,
        "Completing Act I objectives and the first stronghold must unlock Act II")

    var escort = main.frontier_campaign.sites["highland_survivors"]
    escort.interact()
    assert(escort.site_state == "escorting" and escort._path.size() > 1,
        "The Highlands rescue must enter an active, path-backed escort state")
    main.player.position = escort.position

    var next_stronghold = main.campaign.current_target_node()
    assert(next_stronghold != null, "Act II must expose the next stronghold")
    next_stronghold.take_damage(211)
    var expected_stronghold_hp: int = int(next_stronghold.hp)
    var expected_escort_path_index: int = int(escort._path_index)
    var expected_escort_position: Vector2 = escort.position

    assert(save_system.save_current(true),
        "Frontier save must succeed with a partially damaged stronghold and active escort")
    var snapshot: Dictionary = save_system.collect(main)
    assert(snapshot["version"] == 11 and snapshot["frontier_campaign"]["profile"] == "frontier",
        "The snapshot must use the current Frontier campaign schema")

    assert(save_system.request_load(),
        "The current Frontier campaign snapshot must be accepted for reload")
    await ticks(12)
    var restored = current_scene
    game_clock.set_process(false)

    assert(restored != null and is_instance_valid(restored),
        "The reloaded scene must be available")
    assert(bool(restored.frontier_campaign.objectives["discover_greenwood"]["completed"]),
        "Completed discovery must survive campaign reload")
    assert(bool(restored.frontier_campaign.objectives["greenwood_raider_camp"]["completed"]),
        "Completed camp objective must survive campaign reload")
    assert(restored.frontier_campaign.unlocked_act == 2,
        "Unlocked campaign act must survive reload")

    var restored_escort = restored.frontier_campaign.sites.get("highland_survivors")
    assert(restored_escort != null and is_instance_valid(restored_escort),
        "An active rescue site must be recreated after reload")
    assert(restored_escort.site_state == "escorting",
        "An in-progress escort must not silently reset to waiting")
    assert(restored_escort._path.size() > 1,
        "The active escort route must be rebuilt after reload")
    assert(restored_escort._path_index == expected_escort_path_index,
        "Escort path progress must be preserved")
    assert(restored_escort.position.distance_to(expected_escort_position) <= 8.0,
        "Escort position must be preserved")

    var restored_target = restored.campaign.current_target_node()
    assert(restored_target != null and restored_target.stronghold_id == "iron_legion",
        "Reload must resume the same active stronghold objective")
    assert(restored_target.hp == expected_stronghold_hp,
        "Partial stronghold damage must survive reload")

    print("PASS: Frontier reload preserves completed objectives, unlocked act, active escort route/progress and stronghold HP")
    quit(0)


func _initialize() -> void:
    world_config = root.get_node("WorldConfig")
    game_clock = root.get_node("GameClock")
    save_system = root.get_node("SaveSystem")
    call_deferred("_run")
