extends SceneTree
## Phase 06.2 regression: Siege Engine target policy, telegraphed impact and counterplay.

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


func spawn_siege_engine(main, data: Dictionary, at: Vector2):
    var script = load("res://scripts/entities/enemy.gd")
    var enemy = script.new()
    enemy.setup(data, main.world, main.flow, main.player, "iron_legion")
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

    # High-value defensive structures outrank a nearby Keep and production sites.
    var wall_cell := find_building_cell(main, "stone_wall", 3, 4)
    require(wall_cell.x >= 0, "Test must find a reachable stone-wall placement")
    var wall = main.build.place_raw("stone_wall", wall_cell)
    main.nav.rebuild()

    var storage_cell := find_building_cell(main, "storage", 4, 6)
    require(storage_cell.x >= 0, "Test must find reachable Storage placement")
    var storage = main.build.place_raw("storage", storage_cell)
    main.nav.rebuild()

    var house_cell := find_building_cell(main, "house", 5, 7)
    require(house_cell.x >= 0, "Test must find a reachable House placement")
    var house = main.build.place_raw("house", house_cell)
    main.nav.rebuild()

    var siege = spawn_siege_engine(main, data_db.enemies["enemy_siege_engine"],
        main.player.global_position + Vector2(0, 110))
    require(siege.siege_nav == main.nav,
        "Siege Engine must acquire the shared navigation grid")
    var selected = siege._select_siege_target()
    require(selected == wall,
        "Siege Engine must prioritize a reachable stone wall over Storage, House and the Keep")
    require(not siege._siege_path.is_empty(),
        "Selected siege target must have a reachable adjacent path")
    main.player.global_position = Vector2(180, 180)

    # The wind-up must be readable and cause no immediate damage.
    siege.global_position = wall.global_position + Vector2(18, 0)
    var wall_hp_before: int = wall.hp
    siege._siege_cd = 0.0
    siege._tick_siege_engine(0.016)
    require(siege._siege_windup_t > 0.0,
        "Siege Engine must telegraph before its heavy impact")
    assert(wall.hp == wall_hp_before,
        "Siege target must not take damage during the wind-up")
    siege._tick_siege_engine(siege.siege_windup_duration + 0.02)
    assert(wall.hp == wall_hp_before - 72,
        "Siege impact must apply the configured heavy structure damage")
    assert(siege._siege_cd > 0.0,
        "Successful impact must enter a recovery cooldown")
    siege._tick_siege_engine(0.016)
    assert(siege._siege_windup_t == 0.0,
        "Siege Engine must not chain impacts without recovery")

    # Stagger interrupts a second siege wind-up before it damages the target.
    var tower_cell := find_building_cell(main, "tower", 6, 8)
    require(tower_cell.x >= 0, "Test must find a reachable Tower placement")
    var tower = main.build.place_raw("tower", tower_cell)
    main.nav.rebuild()
    var interrupted = spawn_siege_engine(main, data_db.enemies["enemy_siege_engine"],
        tower.global_position + Vector2(18, 0))
    interrupted._siege_target = tower
    interrupted._siege_cd = 0.0
    var tower_hp_before: int = tower.hp
    interrupted._tick_siege_engine(0.016)
    require(interrupted._siege_windup_t > 0.0,
        "Second Siege Engine must enter its wind-up")
    interrupted.apply_stagger(0.6)
    assert(interrupted._siege_windup_t == 0.0,
        "Stagger must cancel the active siege wind-up")
    assert(tower.hp == tower_hp_before,
        "Interrupted siege strike must not deal structural damage")
    assert(interrupted._siege_cd > 0.0,
        "Interrupted Siege Engine must enter a brief recovery window")

    # The Siege Engine never retaliates with its structure strike against nearby people.
    interrupted.global_position = main.player.global_position + Vector2(12, 0)
    var player_hp_before: int = main.player.hp
    interrupted._tick_siege_engine(0.016)
    assert(main.player.hp == player_hp_before,
        "Siege Engine must not use its heavy structure impact against the player")

    print("PASS: Siege Engine priority scan, reachable path, telegraphed heavy impact, recovery cooldown, stagger interrupt and building-only attack preference")
    main.queue_free()
    quit(0)
