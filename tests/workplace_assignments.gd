extends SceneTree
## Phase 04 slice regression: Builder workplace, repairs, depot range and role persistence.

func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func _find_buildable_near(main, origin: Vector2i, min_radius: int, max_radius: int, map_size: int, require_reachable := false) -> Vector2i:
    for radius in range(min_radius, max_radius + 1):
        for y in range(-radius, radius + 1):
            for x in range(-radius, radius + 1):
                if maxi(absi(x), absi(y)) != radius:
                    continue
                var cell := origin + Vector2i(x, y)
                if cell.x < 1 or cell.y < 1 or cell.x >= map_size - 2 or cell.y >= map_size - 2:
                    continue
                if not main.world.is_buildable(cell) or main.world.occupied.has(cell):
                    continue
                if require_reachable:
                    var target_cells: Array[Vector2i] = [cell]
                    if main.nav.path_adjacent(main.player.position, target_cells).is_empty():
                        continue
                return cell
    return Vector2i(-1, -1)


func _initialize() -> void:
    var clock = root.get_node("GameClock")
    var config = root.get_node("WorldConfig")
    var save_system = root.get_node("SaveSystem")
    var inventory = root.get_node("Inventory")
    config.apply_profile("classic")
    DirAccess.remove_absolute("user://save.json")
    DirAccess.remove_absolute("user://save.tmp")
    DirAccess.remove_absolute("user://save.bak")

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(8)
    clock.set_process(false)
    main.village.set_process(false)
    main.village.quota["builder"] = 0

    var keep = null
    for depot in get_nodes_in_group("depots"):
        if depot.id == "keep":
            keep = depot
            break
    assert(keep != null, "New campaign must create its Keep")

    main.village.adjust_job_priority("builder", -1)
    assert(main.village.job_priority.find("builder") == 2,
        "A priority adjustment must move Builder upward by one position")
    main.village.quota["builder"] = 2

    var builder_a = main.village.spawn_villager(keep.position + Vector2(0, 14))
    var builder_b = main.village.spawn_villager(keep.position + Vector2(10, 14))
    var builder_c = main.village.spawn_villager(keep.position + Vector2(-10, 14))
    assert(builder_a.set_job("builder"), "First Builder must claim a Keep workplace slot")
    assert(builder_b.set_job("builder"), "Second Builder must fit Keep workplace capacity")
    assert(not builder_c.set_job("builder"), "Builder assignment must respect workplace capacity")
    assert(keep.free_slots("builder") == 0, "Keep Builder slots must be fully occupied")
    assert(builder_a.occupation == "builder" and builder_a.military_specialization.is_empty(),
        "Builder is a labor occupation, not a military specialization")

    var wall_cell := _find_buildable_near(main, keep.cell, 2, 7, int(config.map_size), true)
    assert(wall_cell.x >= 0, "Test must find a reachable wall site near the Keep")
    var wall = main.build.place_raw("wall", wall_cell)
    wall.take_damage(30)
    assert(builder_a._is_in_work_radius(wall), "Nearby damaged buildings must be in Keep work radius")

    var distant_cell := _find_buildable_near(main, keep.cell, 22, 25, int(config.map_size), false)
    assert(distant_cell.x >= 0, "Test must find a reachable distant wall site")
    var distant_wall = main.build.place_raw("wall", distant_cell)
    distant_wall.take_damage(30)
    assert(not builder_a._is_in_work_radius(distant_wall),
        "Builder work must not extend beyond its workplace radius")

    builder_a._find_work()
    assert(builder_a.target == wall, "Builder must select a damaged building in its work area")
    assert(not wall.claim_repairer(builder_b), "A repair target cannot be double-booked")
    var hp_before: int = wall.hp
    var wood_before: int = inventory.get_amount("wood")
    builder_a.state = builder_a.State.WORKING
    builder_a._tick_working(2.0)
    assert(wall.hp > hp_before, "Builder work must restore building HP")
    assert(inventory.get_amount("wood") == wood_before - 1,
        "Repair must consume its configured material")

    var gatherer = main.village.spawn_villager(keep.position + Vector2(0, 20))
    assert(gatherer.set_job("woodcutter"), "Woodcutter remains assignable")
    gatherer.receive("wood", 2)
    gatherer._go_depot()
    assert(gatherer._depot == keep, "Carrier must select the reachable connected Keep depot")
    assert(not gatherer._path.is_empty(), "Depot selection must produce a valid path")

    var soldier = main.village.spawn_villager(keep.position + Vector2(0, 26))
    assert(soldier.set_job("soldier"), "Soldier remains assignable")
    assert(soldier.occupation.is_empty() and soldier.military_specialization == "soldier",
        "Soldier must be stored as a military specialization")

    var snapshot: Dictionary = save_system.collect(main)
    assert(snapshot["version"] == 15, "Current campaign, depot and shipment state must use save version 15")
    assert(snapshot["job_priority"][2] == "builder", "Save must persist job priority")
    var has_saved_builder := false
    var has_saved_soldier := false
    for saved_villager in snapshot["villagers"]:
        has_saved_builder = has_saved_builder or String(saved_villager.get("occupation", "")) == "builder"
        has_saved_soldier = has_saved_soldier or String(saved_villager.get("military_specialization", "")) == "soldier"
    assert(has_saved_builder and has_saved_soldier,
        "Save must persist both labor occupation and military specialization")
    assert(save_system._valid_save(snapshot), "Builder/soldier role save must pass v15 validation")

    print("PASS: Builder workplaces, repair material, work radius, reachable depot, role split and priority persistence")
    quit()
