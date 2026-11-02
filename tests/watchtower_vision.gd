extends SceneTree
## Phase 05.3a: the existing defensive tower also reveals and observes its local area.

func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func footprint_is_clear(main, config, anchor: Vector2i, size: Vector2i) -> bool:
    for y in size.y:
        for x in size.x:
            var cell := anchor + Vector2i(x, y)
            if not config.is_valid_cell(cell):
                return false
            if not main.world.is_buildable(cell) or main.world.occupied.has(cell):
                return false
    return true


func world_cell_center(cell: Vector2i, tile_size: int) -> Vector2:
    return (Vector2(cell) + Vector2(0.5, 0.5)) * tile_size


func _initialize() -> void:
    var config = root.get_node("WorldConfig")
    var tile_size: int = int(config.tile_size)
    var game_clock = root.get_node("GameClock")
    assert(config.apply_profile("classic"), "Watchtower regression must start in Classic")

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(8)
    game_clock.set_process(false)

    var hud = get_first_node_in_group("hud")
    assert(hud != null and hud._map_panel != null,
        "The strategic map must exist for current enemy-observation checks")
    var tower_size := Vector2i(2, 2)
    var keep_cell: Vector2i = main.world.starting_keep_cell()
    var tower_cell := Vector2i(-1, -1)
    var observed_cell := Vector2i(-1, -1)
    var outside_cell := Vector2i(-1, -1)

    # Search outward from the Keep so the test never overwrites a resource or terrain blocker.
    for radius in range(10, 18):
        var candidate := keep_cell + Vector2i(radius, 0)
        var target := candidate + Vector2i(7, 0)
        var outside := candidate + Vector2i(11, 0)
        if not footprint_is_clear(main, config, candidate, tower_size):
            continue
        if not config.is_valid_cell(target) or not config.is_valid_cell(outside):
            continue
        var target_position := world_cell_center(target, tile_size)
        var outside_position := world_cell_center(outside, tile_size)
        if target_position.distance_to(main.player.global_position) <= 112.0:
            continue
        if target_position.distance_to(main.world.occupied[keep_cell].global_position) <= 160.0:
            continue
        tower_cell = candidate
        observed_cell = target
        outside_cell = outside
        break

    assert(tower_cell.x >= 0,
        "The generated Classic map must contain an open tower footprint beyond Keep/player vision")
    var target_position := world_cell_center(observed_cell, tile_size)
    var outside_position := world_cell_center(outside_cell, tile_size)

    main.fog.discovered.fill(0)
    main.fog._scan_sources()
    assert(not main.fog.is_revealed_cell(observed_cell),
        "The distant observation target must remain unexplored before building a tower")
    assert(not hud._map_panel._is_currently_observed(target_position),
        "No existing unit or building should currently observe the distant target")

    var tower = main.build.place_raw("tower", tower_cell)
    await ticks(2)
    main.fog._scan_sources()

    assert(is_equal_approx(float(tower.data.get("vision_radius", 0.0)), 128.0),
        "The existing defensive tower must declare its Watchtower vision radius in building data")
    assert(main.fog.is_revealed_cell(observed_cell),
        "A completed tower must permanently reveal cells inside its 128px vision radius")
    assert(not main.fog.is_revealed_cell(outside_cell),
        "A tower must not reveal cells outside its configured vision radius")
    assert(hud._map_panel._is_currently_observed(target_position),
        "The strategic map must treat enemies inside tower vision as currently observed")
    assert(not hud._map_panel._is_currently_observed(outside_position),
        "The strategic map must not expose enemy markers beyond tower vision")

    assert(float(tower._range) > 0.0 and int(tower._damage) > 0,
        "Watchtower vision must preserve the existing defensive turret behavior")

    assert(main.build.demolish_at(tower_cell),
        "The test tower must be removable through the existing building lifecycle")
    await ticks(2)
    assert(main.fog.is_revealed_cell(observed_cell),
        "Explored Watchtower terrain must remain permanently discovered after demolition")
    assert(not hud._map_panel._is_currently_observed(target_position),
        "Destroying a Watchtower must remove its live enemy-observation coverage")

    print("PASS: tower exploration radius, live strategic-map observation, out-of-range concealment, persistent discovery and turret compatibility")
    quit()
