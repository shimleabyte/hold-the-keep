extends SceneTree
## Frontier Expedition: larger world, discovery-gated marches, permanent fog and v13 save validation.

func ticks(count: int) -> void:
    for _index in range(count):
        await physics_frame


func _initialize() -> void:
    await process_frame
    var world_config = root.get_node("WorldConfig")
    var settings = root.get_node("Settings")
    var game_clock = root.get_node("GameClock")
    var save_system = root.get_node("SaveSystem")

    DirAccess.remove_absolute("user://save.json")
    DirAccess.remove_absolute("user://save.tmp")
    DirAccess.remove_absolute("user://save.bak")

    var previous_profile: String = settings.world_profile
    assert(world_config.apply_profile("frontier_expedition"),
        "Frontier Expedition must be selectable as a new world profile")
    assert(settings.set_world_profile("frontier_expedition"),
        "Frontier Expedition selection must persist through settings")

    assert(world_config.profile_id == "frontier_expedition"
        and world_config.map_size == 192
        and world_config.map_cells == 192 * 192,
        "Expedition must create a 192x192 map")
    assert(world_config.world_pixel_size() == Vector2i(3072, 3072),
        "Expedition world bounds must scale from 192 tiles at 16px")
    assert(world_config.starting_keep_cell() == Vector2i(95, 93),
        "Keep placement must remain centered in the expanded world")
    assert(world_config.profile_definition("frontier").get("map_size", 0) == 128,
        "The original Frontier save profile must remain 128x128")

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(6)
    game_clock.set_process(false)

    assert(main.world.map_size == 192 and main.world.pixel_size == Vector2i(3072, 3072),
        "Main scene must use the Expedition world dimensions")
    assert(main.world._expedition_gate_cells.size() == 4,
        "The expanded map must create one crossing for each outer march")
    assert(main.frontier_campaign.objectives.size() == 11,
        "The larger map must retain the existing four-act regional campaign")

    var region_cells := {
        "HEARTHLAND": 0,
        "GREENWOOD": 0,
        "HIGHLANDS": 0,
        "FENLANDS": 0,
        "ASHEN_MARCH": 0
    }
    for y in world_config.map_size:
        for x in world_config.map_size:
            var region := String(main.world.region_id(Vector2i(x, y)))
            assert(region_cells.has(region), "Expedition produced an unknown region: " + region)
            region_cells[region] += 1
    for region in region_cells:
        assert(int(region_cells[region]) >= 1400,
            "Each existing biome must retain meaningful territory on the larger map: " + region)

    var locked_regions: Array[String] = ["GREENWOOD", "HIGHLANDS", "FENLANDS", "ASHEN_MARCH"]
    for region in locked_regions:
        assert(not main.world.is_expedition_gate_open(region),
            "Outer sector must start locked until its matching discovery: " + region)
        var gate_cell: Vector2i = main.world._expedition_gate_cells[region]
        assert(main.world.tile_type_at(gate_cell) == 2,
            "An undiscovered sector crossing must be physically sealed by water: " + region)
        assert(not main.world.is_buildable(gate_cell)
            and not main.world.is_bridgeable(gate_cell)
            and not main.nav.is_walkable(gate_cell),
            "Roads, bridges and pathfinding must not bypass the sealed crossing: " + region)

    var hud = get_first_node_in_group("hud")
    assert(hud != null, "Expedition must create the normal HUD")
    hud._layout_viewport(Vector2(480, 270))
    await process_frame
    var map_panel = hud._map_panel
    assert(map_panel.position.x >= 0.0 and map_panel.position.y >= 0.0
        and map_panel.position.x + map_panel.size.x <= 480.1
        and map_panel.position.y + map_panel.size.y <= 270.1,
        "The 192x192 strategic map must remain usable at the minimum logical viewport")
    var unexplored := Vector2i(8, 8)
    assert(not main.fog.is_revealed_cell(unexplored)
        and not map_panel._position_is_known(Vector2(unexplored) * 16.0),
        "The expanded outer world must remain hidden until the player explores it")

    var discoveries := {
        "GREENWOOD": "discover_greenwood",
        "HIGHLANDS": "discover_highlands",
        "FENLANDS": "discover_fenlands",
        "ASHEN_MARCH": "discover_ashen_march"
    }
    # Allow all four stages in this isolated probe; each discovery still completes
    # only when the player reaches the inner-side approach to its own sealed gate.
    main.frontier_campaign.unlocked_act = 4
    for region in locked_regions:
        var objective_id := String(discoveries[region])
        var gate_cell: Vector2i = main.world._expedition_gate_cells[region]
        var approach_cell := gate_cell + (Vector2i(0, 1) if gate_cell.y < world_config.map_size / 2 else Vector2i(0, -1))
        assert(main.world.region_id(approach_cell) == region,
            "The inside approach must carry the matching discovery region: " + region)
        assert(main.nav.is_walkable(approach_cell),
            "The expedition must be able to reach the survey side of the sealed gate: " + region)
        main.player.global_position = main.nav.center_of(approach_cell)
        main.frontier_campaign._scan_discovery()
        assert(bool(main.frontier_campaign.objectives[objective_id]["completed"]),
            "Entering the surveyed approach region must complete discovery: " + region)
        assert(main.world.is_expedition_gate_open(region),
            "Matching discovery must persistently open its sector: " + region)
        assert(main.world.tile_type_at(gate_cell) != 2
            and main.world.is_buildable(gate_cell)
            and main.nav.is_walkable(gate_cell),
            "An opened crossing must restore terrain collision and navigation: " + region)
        var outward := Vector2i(0, -1) if gate_cell.y < world_config.map_size / 2 else Vector2i(0, 1)
        var landing_cell := gate_cell + outward
        assert(main.world.is_buildable(landing_cell) and main.nav.is_walkable(landing_cell),
            "An opened crossing must lead onto an unobstructed tile in its outer march: " + region)

    # Rebuild the gate state from completed discovery objectives, as happens after loading a save.
    main.world.apply_expedition_sector_unlocks({})
    main.nav.rebuild()
    main.frontier_campaign._sync_expedition_gates()
    for region in locked_regions:
        assert(main.world.is_expedition_gate_open(region),
            "Completed exploration objectives must restore open crossings: " + region)

    var greenwood_gate: Vector2i = main.world._expedition_gate_cells["GREENWOOD"]
    var beyond_gate := greenwood_gate + Vector2i(0, -1)
    assert(main.nav.is_walkable(beyond_gate),
        "The outer side of an unlocked survey gate must be reachable")
    var explored_position: Vector2 = main.nav.center_of(beyond_gate)
    main.player.global_position = explored_position
    main.fog._scan_sources()
    assert(main.fog.is_revealed_cell(beyond_gate),
        "Player exploration beyond an opened gate must reveal the outer march")
    assert(not main.fog.is_revealed_cell(unexplored),
        "Exploring one outer march must not reveal the entire 192x192 map")

    var far_index: int = world_config.cell_index(Vector2i(191, 191))
    assert(far_index == 192 * 192 - 1
        and world_config.cell_from_index(far_index) == Vector2i(191, 191),
        "The largest Expedition row-major index must round-trip")
    var expedition_save: Dictionary = save_system.collect(main)
    assert(String(expedition_save["world"]["profile"]) == "frontier_expedition"
        and int(expedition_save["world"]["map_size"]) == 192
        and save_system._valid_save(expedition_save),
        "192x192 Expedition worlds, fog and completed discovery state must validate in v13")
    var invalid_save := expedition_save.duplicate(true)
    invalid_save["fog"]["cells"].append(world_config.map_cells)
    assert(not save_system._valid_save(invalid_save),
        "Expedition save validation must reject fog indices outside 192x192 bounds")
    var saved_discoveries: Dictionary = {}
    for record in expedition_save["frontier_campaign"]["objectives"]:
        if String(record.get("id", "")).begins_with("discover_"):
            saved_discoveries[String(record["id"])] = bool(record.get("completed", false))
    var completed_discovery_count := 0
    for objective_id in saved_discoveries:
        if bool(saved_discoveries[objective_id]):
            completed_discovery_count += 1
    assert(saved_discoveries.size() == 4 and completed_discovery_count == 4,
        "All four gate unlocks must be represented by existing saved discovery objectives")

    var pause = get_first_node_in_group("pause_menu")
    assert(pause != null and pause._campaign_profile.get_item_count() == 3
        and pause._campaign_profile.selected == 2,
        "The new-campaign menu must select the active 192x192 Expedition profile")

    assert(settings.set_world_profile(previous_profile),
        "The test must restore the previous profile preference")
    print("PASS: 192x192 Expedition, four discovery-gated marches, permanent exploration fog and v13 save compatibility")
    quit(0)
