extends SceneTree
## Phase 06.2 regression: Saboteur target policy, building disruption and counterplay.

func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func require(condition: bool, message: String) -> void:
    if not condition:
        push_error("FAIL: " + message)
        quit(1)
    assert(condition, message)


func find_building_cell(main, building_id: String, min_radius: int, max_radius: int) -> Vector2i:
    var data: Dictionary = root.get_node("DataDB").buildings[building_id]
    var size_data: Array = data["size"]
    var size := Vector2i(int(size_data[0]), int(size_data[1]))
    var origin: Vector2i = main.nav.cell_of(main.player.global_position)
    for radius in range(min_radius, max_radius + 1):
        for y in range(-radius, radius + 1):
            for x in range(-radius, radius + 1):
                if maxi(absi(x), absi(y)) != radius:
                    continue
                var anchor := origin + Vector2i(x, y)
                var cells: Array[Vector2i] = []
                var valid := true
                for cy in size.y:
                    for cx in size.x:
                        var cell := anchor + Vector2i(cx, cy)
                        if not main.world.is_buildable(cell) or main.world.occupied.has(cell):
                            valid = false
                            break
                        cells.append(cell)
                    if not valid:
                        break
                if valid and not main.nav.path_adjacent(main.player.global_position, cells).is_empty():
                    return anchor
    return Vector2i(-1, -1)


func spawn_saboteur(main, data: Dictionary, at: Vector2):
    var script = load("res://scripts/entities/enemy.gd")
    var enemy = script.new()
    enemy.setup(data, main.world, main.flow, main.player, "ashen_host")
    enemy.global_position = at
    main.world.entities.add_child(enemy)
    enemy.set_physics_process(false)
    return enemy


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var config = root.get_node("WorldConfig")
    var clock = root.get_node("GameClock")
    config.apply_profile("frontier")
    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(8)
    clock.set_process(false)
    main.supply.set_process(false)
    main.spawner.set_process(false)
    main.spawner.set_physics_process(false)
    main.village.set_process(false)

    var data_db = root.get_node("DataDB")
    main.player.global_position = Vector2(820, 820)

    # A farther high-value tower must outrank closer low-value production.
    var tower_cell := find_building_cell(main, "tower", 7, 9)
    require(tower_cell.x >= 0, "Test must find a reachable tower placement")
    var tower = main.build.place_raw("tower", tower_cell)
    main.nav.rebuild()

    var storage_cell := find_building_cell(main, "storage", 4, 6)
    require(storage_cell.x >= 0, "Test must find a reachable Storage placement")
    var storage = main.build.place_raw("storage", storage_cell)
    main.nav.rebuild()

    var farm_cell := find_building_cell(main, "farm", 5, 8)
    require(farm_cell.x >= 0, "Test must find a reachable Farm placement")
    var farm = main.build.place_raw("farm", farm_cell)
    main.nav.rebuild()

    var lumber_cell := find_building_cell(main, "lumber_camp", 5, 9)
    require(lumber_cell.x >= 0, "Test must find a reachable Lumber Camp placement")
    var lumber = main.build.place_raw("lumber_camp", lumber_cell)
    main.nav.rebuild()

    var saboteur = spawn_saboteur(main, data_db.enemies["enemy_saboteur"],
        main.player.global_position + Vector2(0, 120))
    require(saboteur.saboteur_nav == main.nav,
        "Saboteur must acquire the shared navigation grid when it enters the scene")
    var selected = saboteur._select_saboteur_target()
    require(selected == tower,
        "Saboteur must prioritize the reachable tower over closer Storage and production buildings")
    require(not saboteur._saboteur_path.is_empty(),
        "Selected high-value building must have a reachable adjacent path")

    # Complete the telegraphed disruption against the selected tower.
    saboteur.global_position = tower.global_position + Vector2(18, 0)
    var tower_hp_before: int = tower.hp
    saboteur._saboteur_cd = 0.0
    saboteur._tick_saboteur(0.016)
    require(saboteur._saboteur_windup_t > 0.0,
        "Saboteur must telegraph before disabling a structure")
    saboteur._tick_saboteur(saboteur.saboteur_windup_duration + 0.02)
    require(tower.is_sabotaged() and tower.sabotage_seconds_remaining() > 4.8,
        "Successful sabotage must apply a finite disruption window")
    require(tower.hp < tower_hp_before,
        "Saboteur disruption must also deal bounded structural damage")
    tower._fire_cd = 0.4
    tower._physics_process(0.1)
    assert(is_equal_approx(tower._fire_cd, 0.4),
        "A sabotaged tower must stop its firing cycle")

    # Local depots cannot accept or pay out stock while sabotaged, then recover.
    require(storage.store_resource("food", 6), "Storage must accept stock before sabotage")
    require(storage.apply_sabotage(4.0), "Storage must accept a sabotage state")
    require(not storage.store_resource("wood", 1),
        "Sabotaged Storage must reject incoming resources")
    require(not storage.take_resource("food", 1),
        "Sabotaged Storage must reject withdrawals and depot-funded costs")
    storage._process(4.1)
    assert(not storage.is_sabotaged(), "Depot disruption must expire without save state")
    assert(storage.take_resource("food", 1),
        "Depot withdrawals must recover after sabotage expires")

    # Production workplaces reject new claims and expose their capacity again after recovery.
    assert(lumber.free_slots("woodcutter") == 2,
        "Lumber Camp must expose its normal worker capacity before disruption")
    require(lumber.apply_sabotage(3.0), "Lumber Camp must accept sabotage")
    assert(lumber.free_slots("woodcutter") == 0,
        "Sabotaged workplace must stop accepting workers")
    lumber._process(3.1)
    assert(lumber.free_slots("woodcutter") == 2,
        "Workplace capacity must recover when sabotage expires")

    # A player stagger cancels an unfinished sabotage callout.
    var interrupted = spawn_saboteur(main, data_db.enemies["enemy_saboteur"],
        farm.global_position + Vector2(18, 0))
    interrupted._saboteur_target = farm
    interrupted._saboteur_cd = 0.0
    interrupted._tick_saboteur(0.016)
    require(interrupted._saboteur_windup_t > 0.0,
        "Second Saboteur must enter a telegraphed wind-up")
    interrupted.apply_stagger(0.6)
    assert(interrupted._saboteur_windup_t == 0.0,
        "Stagger must interrupt the sabotage wind-up")
    assert(not farm.is_sabotaged(),
        "An interrupted callout must not disable the target")
    assert(interrupted._saboteur_cd > 0.0,
        "An interrupted Saboteur must pay a short recovery cooldown")

    print("PASS: Saboteur priority selection, reachable target path, telegraphed disruption, tower/depot/workplace disable and recovery, stagger interruption")
    main.queue_free()
    quit(0)
