extends SceneTree
## Scout: workplace assignment, bounded A* survey, local fog reveal, return and v15 migration.

func require(condition: bool, message: String) -> void:
    if not condition:
        push_error("FAIL: " + message)
        quit(1)
    assert(condition, message)


func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func find_build_site(main, origin: Vector2i, footprint: Vector2i) -> Vector2i:
    var map_size := int(root.get_node("WorldConfig").map_size)
    for radius in range(4, 14):
        for y in range(-radius, radius + 1):
            for x in range(-radius, radius + 1):
                if maxi(absi(x), absi(y)) != radius:
                    continue
                var anchor := origin + Vector2i(x, y)
                if anchor.x < 1 or anchor.y < 1 or anchor.x + footprint.x >= map_size - 1 or anchor.y + footprint.y >= map_size - 1:
                    continue
                var cells: Array[Vector2i] = []
                var clear := true
                for dy in footprint.y:
                    for dx in footprint.x:
                        var cell := anchor + Vector2i(dx, dy)
                        cells.append(cell)
                        if not main.world.is_buildable(cell) or main.world.occupied.has(cell):
                            clear = false
                if not clear or main.nav.path_adjacent(main.player.position, cells).is_empty():
                    continue
                return anchor
    return Vector2i(-1, -1)


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var config = root.get_node("WorldConfig")
    var inventory = root.get_node("Inventory")
    var save_system = root.get_node("SaveSystem")
    config.apply_profile("classic")
    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(8)
    root.get_node("GameClock").set_process(false)
    main.village.set_process(false)
    for existing in main.village.villagers():
        existing.leave()

    var keep = null
    for depot in get_nodes_in_group("depots"):
        if depot.id == "keep":
            keep = depot
            break
    require(keep != null, "Classic campaign must retain its Keep depot")

    var without_post = main.village.spawn_villager(keep.position + Vector2(0, 22))
    require(not without_post.set_job("scout"),
        "Scout assignment must fail until a Scout Post workplace exists")
    require(without_post.job.is_empty(),
        "Failed Scout assignment must not leave a phantom occupation")

    inventory.items = {"wood": 500, "stone": 500, "food": 100, "iron": 0}
    var post_cell := find_build_site(main, keep.cell, Vector2i(3, 2))
    require(post_cell.x >= 0, "A reachable Scout Post footprint must exist")
    var post = main.build.place_raw("scout_post", post_cell)
    await ticks(3)
    main.nav.rebuild()

    require(post.free_slots("scout") == 2,
        "Scout Post must expose exactly two Scout workplace slots")
    require(post.free_slots("hunter") == 0 and post.free_slots("woodcutter") == 0,
        "Scout Post must reject unrelated labor roles")
    require(String(post.data.get("name", "")) == "Pondok Pengintai",
        "Scout Post must use its own player-facing building definition")

    var scout_a = main.village.spawn_villager(keep.position + Vector2(0, 26))
    var scout_b = main.village.spawn_villager(keep.position + Vector2(8, 26))
    var scout_c = main.village.spawn_villager(keep.position + Vector2(-8, 26))
    require(scout_a.set_job("scout") and scout_b.set_job("scout"),
        "Two Scouts must claim the Scout Post")
    require(not scout_c.set_job("scout"),
        "A third Scout must respect the Scout Post two-slot capacity")
    require(post.free_slots("scout") == 0,
        "Scout Post capacity must track both assigned workers")

    var fog = get_first_node_in_group("fog_of_war")
    require(fog != null, "The permanent fog system must be active")
    scout_a._find_work()
    require(scout_a.state == scout_a.State.SCOUTING,
        "An assigned Scout must enter the dedicated scouting state")
    require(scout_a._scout_target_cell.x >= 0 and not scout_a._path.is_empty(),
        "Scout must select a reachable survey destination")
    require(scout_a._path.size() <= scout_a.SCOUT_MAX_PATH_CELLS,
        "Scout survey paths must remain within the bounded route budget")
    require(main.nav.is_walkable(scout_a._scout_target_cell),
        "Scout destination must be a walkable cell")
    var scout_radius := float(post.data.get("work_radius", 0.0)) * float(config.tile_size)
    require(post.position.distance_to(main.nav.center_of(scout_a._scout_target_cell)) <= scout_radius,
        "Scout destination must remain inside the Post's configured work radius")
    var first_target: Vector2i = scout_a._scout_target_cell

    scout_b._find_work()
    require(scout_b.state == scout_b.State.SCOUTING,
        "The second assigned Scout must receive an independent survey destination")
    require(scout_b._scout_target_cell != first_target
        and Vector2(scout_b._scout_target_cell).distance_to(Vector2(first_target)) >= 8.0,
        "Two Scouts must not reserve the same nearby survey sector")

    var reveal_cell := Vector2i(-1, -1)
    for y in range(first_target.y - 8, first_target.y + 9):
        for x in range(first_target.x - 8, first_target.x + 9):
            var candidate := Vector2i(x, y)
            if x < 0 or y < 0 or x >= config.map_size or y >= config.map_size:
                continue
            if Vector2(candidate - first_target).length() * float(config.tile_size) > 132.0:
                continue
            if not fog.is_revealed_cell(candidate):
                reveal_cell = candidate
                break
        if reveal_cell.x >= 0:
            break
    require(reveal_cell.x >= 0,
        "Scout destination must have unexplored terrain within its local sight radius")

    var distant_cell := Vector2i(-1, -1)
    for radius in range(11, 17):
        for y in range(-radius, radius + 1):
            for x in range(-radius, radius + 1):
                if Vector2(float(x), float(y)).length() < 11.0:
                    continue
                var candidate := first_target + Vector2i(x, y)
                if candidate.x < 0 or candidate.y < 0 or candidate.x >= config.map_size or candidate.y >= config.map_size:
                    continue
                if not fog.is_revealed_cell(candidate):
                    distant_cell = candidate
                    break
            if distant_cell.x >= 0:
                break
        if distant_cell.x >= 0:
            break
    require(distant_cell.x >= 0,
        "A distant unexplored cell must exist outside the Scout's local vision")

    scout_a.position = main.nav.center_of(first_target)
    scout_a._pi = scout_a._path.size()
    scout_a._tick_scouting(scout_a.SCOUT_SURVEY_SECONDS + 0.1)
    require(fog.is_revealed_cell(reveal_cell),
        "A Scout arriving at a survey point must permanently reveal nearby terrain")
    require(not fog.is_revealed_cell(distant_cell),
        "Scout vision must remain local; it must not reveal distant map cells globally")

    fog.discovered.fill(1)
    scout_a.position = main.nav.center_of(first_target)
    scout_a.state = scout_a.State.IDLE
    scout_a._find_work()
    require(scout_a.state == scout_a.State.SCOUT_RETURNING,
        "When no reachable unexplored sectors remain, Scout must return to its Post")
    require(not scout_a._path.is_empty(),
        "Returning Scout must have a reachable path to the Scout Post")

    main.village.quota["scout"] = 2
    var snapshot: Dictionary = save_system.collect(main)
    require(snapshot["version"] == 17,
        "Scout occupation and priority must remain valid in current save version 17")
    require(save_system._valid_save(snapshot),
        "A live Scout Post and Scout snapshot must validate")
    var has_scout := false
    var saved_post := false
    for villager in snapshot["villagers"]:
        has_scout = has_scout or String(villager.get("occupation", "")) == "scout"
    for building in snapshot["buildings"]:
        saved_post = saved_post or String(building.get("id", "")) == "scout_post"
    require(has_scout and saved_post,
        "Save must persist Scout occupation and its workplace building")

    var legacy_v14: Dictionary = snapshot.duplicate(true)
    legacy_v14["version"] = 14
    legacy_v14["quota"].erase("scout")
    legacy_v14["job_priority"].erase("scout")
    legacy_v14["quota"].erase("healer")
    legacy_v14["job_priority"].erase("healer")
    legacy_v14["quota"].erase("blacksmith")
    legacy_v14["job_priority"].erase("blacksmith")
    for villager in legacy_v14["villagers"]:
        villager.erase("weapon_equipped")
        villager.erase("armor_equipped")
        if String(villager.get("occupation", "")) == "blacksmith":
            villager["occupation"] = ""
            villager["job"] = ""
        if String(villager.get("occupation", "")) == "healer":
            villager["occupation"] = ""
            villager["job"] = ""
        if String(villager.get("occupation", "")) == "scout":
            villager["occupation"] = ""
            villager["job"] = ""
    for index in range(legacy_v14["buildings"].size() - 1, -1, -1):
        if String(legacy_v14["buildings"][index].get("id", "")) == "infirmary":
            legacy_v14["buildings"].remove_at(index)
    for index in range(legacy_v14["buildings"].size() - 1, -1, -1):
        if String(legacy_v14["buildings"][index].get("id", "")) == "scout_post":
            legacy_v14["buildings"].remove_at(index)
    require(save_system._valid_save(legacy_v14),
        "Existing v14 saves must remain valid after the Scout v15 migration")

    post.demolish()
    main.village.assign_jobs()
    await ticks(2)
    require(scout_a.workplace == null and scout_b.workplace == null,
        "Removing the Scout Post must release all assigned workplace claims")
    require(scout_a.job.is_empty() and scout_b.job.is_empty(),
        "Scouts must return to unassigned status when their Post is removed")

    print("PASS: Scout capacity, bounded A* survey, local fog reveal, independent targets, return-to-post, v17 migration and teardown")
    quit(0)
