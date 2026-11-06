extends SceneTree

var world_config
var game_clock
var save_system


## Exercise the full four-act Frontier save lifecycle, not only its Act II checkpoint.
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


func first_walkable_cell_in_region(main: Node, region_id: String) -> Vector2i:
    for y in world_config.map_size:
        for x in world_config.map_size:
            var cell := Vector2i(x, y)
            if String(main.world.region_id(cell)) == region_id and main.nav.is_walkable(cell):
                return cell
    return Vector2i(-1, -1)


func commander_unit(main: Node) -> Node2D:
    var units: Array = main.village.villagers()
    assert(not units.is_empty(), "RTS campaign tests require a friendly commandable unit")
    return units[0]


func discover_region(main: Node, region_id: String, objective_id: String) -> void:
    var cell := first_walkable_cell_in_region(main, region_id)
    assert(cell.x >= 0, region_id + " must contain a walkable discovery cell")
    commander_unit(main).position = main.nav.center_of(cell)
    main.frontier_campaign._scan_discovery()
    assert(bool(main.frontier_campaign.objectives[objective_id]["completed"]),
        objective_id + " must complete when the player enters its region")


func complete_escort(main: Node, objective_id: String) -> void:
    var site = main.frontier_campaign.sites.get(objective_id)
    assert(site != null and is_instance_valid(site),
        objective_id + " must have a live escort site")
    if site.site_state != "escorting":
        var escort_unit := commander_unit(main)
        escort_unit.position = site.position
        assert(escort_unit.issue_interaction_order(site),
            objective_id + " must activate through a unit interaction order")
    assert(site.site_state == "escorting" and site._path.size() > 1,
        objective_id + " must enter a path-backed escort state")
    # Route construction and restore are the subject of this test; the separate
    # frontier_campaign regression covers full path traversal and arrival behavior.
    commander_unit(main).position = site.global_position
    site._finish_escort()
    assert(bool(main.frontier_campaign.objectives[objective_id]["completed"]),
        objective_id + " must complete through the escort completion handler")


func conquer_stronghold(main: Node, index: int, expected_id: String) -> void:
    var stronghold_id := String(main.campaign._order[index])
    assert(stronghold_id == expected_id,
        "Campaign order must keep " + expected_id + " at index " + str(index))
    var stronghold = main.campaign._nodes.get(stronghold_id)
    assert(stronghold != null and is_instance_valid(stronghold),
        expected_id + " must have a live stronghold before conquest")
    stronghold.take_damage(999999)
    assert(bool(main.campaign._records[stronghold_id]["destroyed"]),
        expected_id + " must persist as conquered")


func assert_all_frontier_objectives_complete(main: Node) -> void:
    assert(main.frontier_campaign.objectives.size() == 11,
        "Frontier must retain all eleven regional objective records")
    for objective_id in main.frontier_campaign.objectives:
        assert(bool(main.frontier_campaign.objectives[objective_id]["completed"]),
            "Required Frontier objective must be complete: " + String(objective_id))


func assert_first_three_strongholds_destroyed(main: Node) -> void:
    for stronghold_id in ["greenwood_raiders", "iron_legion", "fen_cult"]:
        assert(bool(main.campaign._records[stronghold_id]["destroyed"]),
            "Conquered stronghold must remain destroyed: " + stronghold_id)


func _run() -> void:
    world_config.apply_profile("frontier")
    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(10)
    game_clock.set_process(false)

    # Act I: finish discovery and the camp, then conquer Greenwood.
    var greenwood := first_reachable_cell_in_region(main, "GREENWOOD")
    assert(greenwood.x >= 0, "Greenwood must be reachable for the campaign discovery")
    commander_unit(main).position = main.nav.center_of(greenwood)
    main.frontier_campaign._scan_discovery()
    assert(bool(main.frontier_campaign.objectives["discover_greenwood"]["completed"]),
        "Greenwood discovery must complete before the save")

    var camp = main.frontier_campaign.sites["greenwood_raider_camp"]
    camp.take_damage(9999)
    assert(bool(main.frontier_campaign.objectives["greenwood_raider_camp"]["completed"]),
        "The first required camp objective must be completed")
    conquer_stronghold(main, 0, "greenwood_raiders")
    assert(main.frontier_campaign.unlocked_act == 2,
        "Act II must unlock after Act I objectives and the first stronghold")

    # Save an in-progress Act II escort and a damaged Iron Legion stronghold.
    var escort = main.frontier_campaign.sites["highland_survivors"]
    var escort_unit := commander_unit(main)
    escort_unit.position = escort.position
    assert(escort_unit.issue_interaction_order(escort),
        "The Highlands rescue must activate through an RTS unit interaction order")
    assert(escort.site_state == "escorting" and escort._path.size() > 1,
        "The Highlands rescue must enter an active, path-backed escort state")
    var next_stronghold = main.campaign.current_target_node()
    assert(next_stronghold != null and next_stronghold.stronghold_id == "iron_legion",
        "Act II must expose the Iron Legion stronghold")
    next_stronghold.take_damage(211)
    var expected_iron_hp: int = int(next_stronghold.hp)
    var expected_escort_position: Vector2 = escort.position
    assert(save_system.save_current(true),
        "Frontier save must succeed with a partially damaged stronghold and active escort")
    var act_two_snapshot: Dictionary = save_system.collect(main)
    assert(act_two_snapshot["version"] == 17
        and act_two_snapshot["frontier_campaign"]["profile"] == "frontier",
        "The snapshot must use the current Frontier campaign schema")
    var saved_escort_record: Dictionary = {}
    for objective_record in act_two_snapshot["frontier_campaign"]["objectives"]:
        if String(objective_record.get("id", "")) == "highland_survivors":
            saved_escort_record = objective_record
            break
    assert(not saved_escort_record.is_empty(),
        "An active escort must be present in the RTS campaign snapshot")
    var saved_escort_position := Vector2(
        float(saved_escort_record.get("x", 0.0)),
        float(saved_escort_record.get("y", 0.0))
    )
    assert(saved_escort_position.distance_to(expected_escort_position) < 0.1,
        "Escort coordinates must be serialized exactly at the save boundary")
    assert(save_system.request_load(),
        "The Act II Frontier checkpoint must be accepted for reload")
    await ticks(12)
    main = current_scene
    game_clock.set_process(false)

    assert(main != null and is_instance_valid(main),
        "The Act II reloaded scene must be available")
    assert(bool(main.frontier_campaign.objectives["discover_greenwood"]["completed"]),
        "Completed discovery must survive campaign reload")
    assert(bool(main.frontier_campaign.objectives["greenwood_raider_camp"]["completed"]),
        "Completed camp objective must survive campaign reload")
    assert(main.frontier_campaign.unlocked_act == 2,
        "Unlocked Act II must survive reload")

    var restored_escort = main.frontier_campaign.sites.get("highland_survivors")
    assert(restored_escort != null and is_instance_valid(restored_escort),
        "An active rescue site must be recreated after reload")
    assert(restored_escort.site_state == "escorting" and restored_escort._path.size() > 1,
        "An in-progress rescue must retain an active, rebuilt route")
    assert(restored_escort.position.distance_to(expected_escort_position) < 32.0,
        "The autonomous convoy must resume near its saved position and continue along its route")
    var restored_iron = main.campaign.current_target_node()
    assert(restored_iron != null and restored_iron.stronghold_id == "iron_legion"
        and restored_iron.hp == expected_iron_hp,
        "The damaged Iron Legion stronghold must resume after reload")

    # Complete Act II after restoring the active escort checkpoint.
    discover_region(main, "HIGHLANDS", "discover_highlands")
    complete_escort(main, "highland_survivors")
    complete_escort(main, "highland_caravan")
    conquer_stronghold(main, 1, "iron_legion")
    assert(main.frontier_campaign.unlocked_act == 3,
        "Act III must unlock after all Act II objectives and the second stronghold")

    # Act III: a ruin-clearing objective and a defended night signal.
    discover_region(main, "FENLANDS", "discover_fenlands")
    main.frontier_campaign.sites["fenland_ruins"].take_damage(999999)
    assert(bool(main.frontier_campaign.objectives["fenland_ruins"]["completed"]),
        "Fenlands ruins must be cleared")
    var beacon = main.frontier_campaign.sites["fenland_watch"]
    var beacon_unit := commander_unit(main)
    beacon_unit.position = beacon.global_position
    assert(beacon_unit.issue_interaction_order(beacon),
        "The signal site must activate through an RTS unit interaction order")
    beacon._on_phase_changed(true)
    beacon._on_phase_changed(false)
    assert(bool(main.frontier_campaign.objectives["fenland_watch"]["completed"]),
        "A surviving signal point must complete after one defended night")
    conquer_stronghold(main, 2, "fen_cult")
    assert(main.frontier_campaign.unlocked_act == 4,
        "Act IV must unlock after all Act III objectives and the third stronghold")

    # Act IV: final regional discovery, refugee escort and siege camp.
    discover_region(main, "ASHEN_MARCH", "discover_ashen_march")
    complete_escort(main, "ashen_refugees")
    main.frontier_campaign.sites["ashen_siege_camp"].take_damage(999999)
    assert_all_frontier_objectives_complete(main)

    var ashen = main.campaign.current_target_node()
    assert(ashen != null and ashen.stronghold_id == "ashen_host",
        "The Ashen Host must be the final stronghold")
    ashen.take_damage(211)
    var expected_ashen_hp: int = int(ashen.hp)
    assert(not main.campaign_conquered,
        "Regional objectives and three strongholds must not finish Conquest before the final gate")

    # Save after Act IV: every objective is complete, three strongholds are conquered,
    # and the final stronghold is damaged but still active.
    assert(save_system.save_current(true),
        "The late-campaign Frontier state must save")
    var late_snapshot: Dictionary = save_system.collect(main)
    assert(late_snapshot["version"] == 17
        and int(late_snapshot["frontier_campaign"]["unlocked_act"]) == 4,
        "Late-campaign save must preserve schema v17 and Act IV")
    for objective_record in late_snapshot["frontier_campaign"]["objectives"]:
        assert(bool(objective_record["completed"]),
            "Late-campaign snapshot must preserve every completed objective")
    var saved_strongholds: Dictionary = {}
    for stronghold_record in late_snapshot["campaign"]["objectives"]:
        saved_strongholds[String(stronghold_record["id"])] = stronghold_record
    for stronghold_id in ["greenwood_raiders", "iron_legion", "fen_cult"]:
        assert(bool(saved_strongholds[stronghold_id]["destroyed"]),
            "Late-campaign snapshot must retain conquered " + stronghold_id)
    assert(not bool(saved_strongholds["ashen_host"]["destroyed"])
        and int(saved_strongholds["ashen_host"]["hp"]) == expected_ashen_hp,
        "Late-campaign snapshot must retain the damaged final stronghold")

    assert(save_system.request_load(),
        "The completed Act IV checkpoint must be accepted for reload")
    await ticks(12)
    main = current_scene
    game_clock.set_process(false)
    assert(main != null and is_instance_valid(main),
        "The late-campaign reloaded scene must be available")
    assert(main.frontier_campaign.unlocked_act == 4,
        "Act IV unlock must survive the late-campaign reload")
    assert_all_frontier_objectives_complete(main)
    assert_first_three_strongholds_destroyed(main)
    var restored_ashen = main.campaign.current_target_node()
    assert(restored_ashen != null and restored_ashen.stronghold_id == "ashen_host"
        and restored_ashen.hp == expected_ashen_hp,
        "Reload must restore the final Ashen Host stronghold with its damaged HP")
    assert(not main.frontier_campaign.final_boss_defeated
        and not main.campaign_conquered,
        "The day-20 victory gate must remain closed before the King is defeated")

    # Conquering the last stronghold is necessary but not sufficient for Frontier victory.
    restored_ashen.take_damage(999999)
    assert(main.campaign.current_target_id().is_empty(),
        "The final Ashen Host stronghold must be conquered before the King")
    assert(not main.campaign_conquered,
        "Conquering all four strongholds must not bypass the day-20 King gate")

    # The final boss cannot resolve the campaign before day 20.
    main.frontier_campaign._on_final_boss_defeated(19)
    assert(not main.frontier_campaign.final_boss_defeated,
        "The Conquest King must not be accepted before day 20")
    game_clock.day = 20
    main.spawner.start_wave(20)
    assert(main.spawner._boss_pending,
        "The actual Frontier final wave must schedule the King on day 20")
    var king = load("res://scripts/entities/enemy.gd").new()
    king.setup(root.get_node("DataDB").enemies["king"], main.world, main.flow, main.player, "ashen_host")
    king.position = main.world.keep_center_position() + Vector2(20, 0)
    main.world.entities.add_child(king)
    await ticks(1)
    king.take_damage(999999)
    assert(main.frontier_campaign.final_boss_defeated,
        "Killing the King must trigger Frontier boss completion")
    assert(main.campaign_conquered,
        "Conquest must finish only after all objectives, strongholds and the day-20 King")

    # Persist and restore the actual victory state as a final recovery assertion.
    assert(save_system.save_current(true),
        "The completed Conquest must save")
    var victory_snapshot: Dictionary = save_system.collect(main)
    assert(bool(victory_snapshot["frontier_campaign"]["final_boss_defeated"]),
        "The victory save must retain the final-boss flag")
    assert(save_system.request_load(),
        "The completed Conquest save must be accepted for reload")
    await ticks(12)
    main = current_scene
    game_clock.set_process(false)
    assert(main != null and is_instance_valid(main),
        "The completed-campaign reloaded scene must be available")
    assert(main.frontier_campaign.final_boss_defeated
        and main.campaign.current_target_id().is_empty()
        and main.campaign_conquered,
        "A completed Frontier victory must remain completed after reload")
    assert_all_frontier_objectives_complete(main)
    for stronghold_id in ["greenwood_raiders", "iron_legion", "fen_cult", "ashen_host"]:
        assert(bool(main.campaign._records[stronghold_id]["destroyed"]),
            "Final victory reload must retain conquered " + stronghold_id)

    print("PASS: Frontier Act I–IV reloads preserve objectives, escort state, conquered strongholds, final-boss gate and completed victory")
    quit(0)


func _initialize() -> void:
    world_config = root.get_node("WorldConfig")
    game_clock = root.get_node("GameClock")
    save_system = root.get_node("SaveSystem")
    call_deferred("_run")
