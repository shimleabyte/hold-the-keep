extends SceneTree
## Phase 07 integration: technology compatibility, four-act calendar, objectives, rewards and final victory.

func ticks(count: int) -> void:
    for i in count:
        await physics_frame


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var config = root.get_node("WorldConfig")
    var clock = root.get_node("GameClock")
    var save_system = root.get_node("SaveSystem")
    var data_db = root.get_node("DataDB")
    var inventory = root.get_node("Inventory")
    var tech = root.get_node("Tech")
    config.apply_profile("frontier")
    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)

    var legacy_ids := [
        "tools_wood", "farming", "palisade", "longhouse", "fletching", "masonry",
        "tools_stone", "granary", "stone_towers", "leather", "drill", "iron_mining",
        "iron_tools", "iron_weapons", "iron_armor", "iron_towers", "fortress"
    ]
    for tech_id in legacy_ids:
        assert(data_db.techs.has(tech_id), "Existing technology ID lost: " + tech_id)
    assert(data_db.tech_order.size() == 20, "Technology tree must contain twenty nodes")
    assert(data_db.campaign_modes["classic"]["final_day"] == 15, "Classic must remain 15 days")
    assert(data_db.campaign_modes["frontier"]["final_day"] == 20, "Frontier must last 20 days")
    assert(data_db.campaign_modes["frontier"]["stages"].size() == 4, "Frontier must have four acts")

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(10)
    clock.set_process(false)

    assert(main.frontier_campaign.objectives.size() == 11, "Frontier must register all regional objectives")
    assert(main.frontier_campaign.sites.size() == 7, "Seven camp, ruin, escort and defense sites must be placed")
    assert(main.spawner.stage_info(1)["id"] == "act_1", "Day 1 must start Act I")
    assert(main.spawner.stage_info(6)["id"] == "act_2", "Day 6 must start Act II")
    assert(main.spawner.stage_info(11)["id"] == "act_3", "Day 11 must start Act III")
    assert(main.spawner.stage_info(16)["id"] == "act_4", "Day 16 must start Act IV")
    assert(main.spawner.stage_info(20)["to_day"] == 20, "Act IV must include day 20")
    assert(main.spawner.wave_size(1) == 8, "Frontier should use its own opening wave size")

    var reachable: Dictionary = main.nav.reachable_cells(main.nav.cell_of(main.player.global_position))
    var greenwood_cell := Vector2i(-1, -1)
    for cell in reachable:
        if String(main.world.region_id(cell)) == "GREENWOOD":
            greenwood_cell = cell
            break
    assert(greenwood_cell.x >= 0, "Greenwood must be reachable from the starting region")
    main.player.position = main.nav.center_of(greenwood_cell)
    main.frontier_campaign._scan_discovery()
    assert(bool(main.frontier_campaign.objectives["discover_greenwood"]["completed"]),
        "Entering Greenwood must complete its discovery objective")
    assert(inventory.get_amount("wood") >= 60, "Discovery must grant its configured resource reward")

    var camp = main.frontier_campaign.sites["greenwood_raider_camp"]
    camp.take_damage(9999)
    assert(bool(main.frontier_campaign.objectives["greenwood_raider_camp"]["completed"]),
        "Destroying the Greenwood camp must complete its objective")

    var snapshot: Dictionary = save_system.collect(main)
    assert(snapshot["version"] == 11, "Phase 07 must write save version 11")
    assert(snapshot["frontier_campaign"]["objectives"].size() == 11, "Save must retain every objective")
    assert(save_system._valid_save(snapshot), "Fresh Frontier objective state must validate")
    var legacy_snapshot: Dictionary = snapshot.duplicate(true)
    legacy_snapshot["version"] = 10
    legacy_snapshot.erase("frontier_campaign")
    assert(save_system._valid_save(legacy_snapshot), "Version 10 Frontier saves must remain compatible")

    var old_done := tech.researched.duplicate()
    tech.researched = ["tools_wood", "masonry", "surveying"]
    tech._recompute()
    assert(tech.is_done("tools_wood") and tech.is_done("masonry"), "Existing researched IDs must still resolve")
    assert(tech.has_flag("frontier_surveying"), "Surveying must activate its exploration flag")
    assert(not tech.is_done("cartography"), "New research must not unlock automatically")
    tech.researched = old_done
    tech._recompute()

    # Act I: complete the first regional objectives and conquer Greenwood.
    var first_id: String = main.campaign._order[0]
    main.campaign._nodes[first_id].take_damage(9999)
    assert(main.frontier_campaign.unlocked_act == 2, "Act II must unlock after Act I objectives and stronghold")

    # Act II: discovery plus two escorted groups.
    var highland_cell := Vector2i(-1, -1)
    for y in config.map_size:
        for x in config.map_size:
            var candidate := Vector2i(x, y)
            if String(main.world.region_id(candidate)) == "HIGHLANDS" and main.nav.is_walkable(candidate):
                highland_cell = candidate
                break
        if highland_cell.x >= 0:
            break
    assert(highland_cell.x >= 0, "Highlands must exist in the Frontier world")
    main.player.position = main.nav.center_of(highland_cell)
    main.frontier_campaign._scan_discovery()
    assert(bool(main.frontier_campaign.objectives["discover_highlands"]["completed"]),
        "Highlands discovery must reward entry after Act II unlock")
    for objective_id in ["highland_survivors", "highland_caravan"]:
        var escort = main.frontier_campaign.sites[objective_id]
        escort.interact()
        assert(escort.site_state == "escorting" and escort._path.size() > 1,
            "Rescue/escort must start a valid route back to the Keep")
        for step in escort._path.size() + 2:
            if not is_instance_valid(escort) or escort.site_state != "escorting":
                break
            main.player.position = escort.position
            escort._tick_escort(1.0)
        assert(bool(main.frontier_campaign.objectives[objective_id]["completed"]),
            "Escorted survivor/caravan must complete at the Keep")
    main.campaign._nodes[String(main.campaign._order[1])].take_damage(9999)
    assert(main.frontier_campaign.unlocked_act == 3, "Act III must unlock after Act II")

    # Act III: ruins and a defended signal point.
    var fenland_cell := Vector2i(-1, -1)
    for y in config.map_size:
        for x in config.map_size:
            var candidate := Vector2i(x, y)
            if String(main.world.region_id(candidate)) == "FENLANDS" and main.nav.is_walkable(candidate):
                fenland_cell = candidate
                break
        if fenland_cell.x >= 0:
            break
    assert(fenland_cell.x >= 0, "Fenlands must exist in the Frontier world")
    main.player.position = main.nav.center_of(fenland_cell)
    main.frontier_campaign._scan_discovery()
    assert(bool(main.frontier_campaign.objectives["discover_fenlands"]["completed"]),
        "Fenlands discovery must complete during Act III")
    main.frontier_campaign.sites["fenland_ruins"].take_damage(9999)
    var beacon = main.frontier_campaign.sites["fenland_watch"]
    beacon.interact()
    beacon._on_phase_changed(true)
    beacon._on_phase_changed(false)
    assert(bool(main.frontier_campaign.objectives["fenland_watch"]["completed"]),
        "A surviving signal point must complete after one defended night")
    main.campaign._nodes[String(main.campaign._order[2])].take_damage(9999)
    assert(main.frontier_campaign.unlocked_act == 4, "Act IV must unlock after Act III")

    # Act IV: final discovery, refugee escort and Ashen siege camp.
    var ashen_cell := Vector2i(-1, -1)
    for y in config.map_size:
        for x in config.map_size:
            var candidate := Vector2i(x, y)
            if String(main.world.region_id(candidate)) == "ASHEN_MARCH" and main.nav.is_walkable(candidate):
                ashen_cell = candidate
                break
        if ashen_cell.x >= 0:
            break
    assert(ashen_cell.x >= 0, "Ashen March must exist in the Frontier world")
    main.player.position = main.nav.center_of(ashen_cell)
    main.frontier_campaign._scan_discovery()
    assert(bool(main.frontier_campaign.objectives["discover_ashen_march"]["completed"]),
        "Ashen March discovery must complete during Act IV")
    var refugees = main.frontier_campaign.sites["ashen_refugees"]
    refugees.interact()
    assert(refugees.site_state == "escorting", "Refugees must start an escort")
    for step in refugees._path.size() + 2:
        if not is_instance_valid(refugees) or refugees.site_state != "escorting":
            break
        main.player.position = refugees.position
        refugees._tick_escort(1.0)
    assert(bool(main.frontier_campaign.objectives["ashen_refugees"]["completed"]),
        "Refugees must reach the Keep")
    main.frontier_campaign.sites["ashen_siege_camp"].take_damage(9999)
    main.campaign._nodes[String(main.campaign._order[3])].take_damage(9999)
    assert(not main.campaign_conquered, "Strongholds and regional objectives alone must not finish Conquest")

    main.frontier_campaign._on_final_boss_defeated(19)
    assert(not main.frontier_campaign.final_boss_defeated, "Conquest King must not be accepted before day 20")
    main.frontier_campaign._on_final_boss_defeated(20)
    assert(main.campaign_conquered, "Conquest must finish after all objectives, strongholds and day-20 King")

    print("PASS: 20-day/four-act Conquest, all objective types, rewards, technology compatibility, v11/legacy saves and final victory gate")
    quit(0)
