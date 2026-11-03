extends SceneTree
## Hunter/Hunting Lodge: assignment, workplace, food delivery, persistence and teardown.

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
    assert(keep != null, "Classic campaign must retain its Keep depot")

    var without_lodge = main.village.spawn_villager(keep.position + Vector2(0, 22))
    assert(not without_lodge.set_job("hunter"),
        "Hunter assignment must fail until a Hunting Lodge workplace exists")
    assert(without_lodge.job.is_empty(),
        "Failed Hunter assignment must not leave a phantom occupation")

    assert(main.world.generated_wildlife_layout.size() >= 12,
        "Classic generation must provide a bounded baseline wildlife supply")
    var wildlife_cells: Dictionary = {}
    var clearing_center := Vector2(config.map_size, config.map_size) * 0.5
    var protected_radius := maxf(float(config.safe_radius) + 4.0, float(config.map_size) * 0.10)
    for entry in main.world.generated_wildlife_layout:
        var cell: Vector2i = entry["cell"]
        assert(not wildlife_cells.has(cell), "Wildlife generation must not overlap itself")
        wildlife_cells[cell] = true
        assert(main.world.is_buildable(cell) and not main.world._expedition_reserved_cells.has(cell),
            "Wildlife must occupy walkable, non-sealed terrain")
        assert(Vector2(cell).distance_to(clearing_center) >= protected_radius,
            "Wildlife must remain outside the protected Keep clearing")

    inventory.items = {"wood": 500, "stone": 500, "food": 100, "iron": 0}
    var lodge_cell := find_build_site(main, keep.cell, Vector2i(3, 2))
    assert(lodge_cell.x >= 0, "A reachable Hunting Lodge footprint must exist")
    var lodge = main.build.place_raw("hunting_lodge", lodge_cell)
    await ticks(3)
    main.nav.rebuild()

    assert(lodge.free_slots("hunter") == 2,
        "Hunting Lodge must expose exactly two Hunter workplace slots")
    assert(lodge.free_slots("woodcutter") == 0 and lodge.free_slots("farmer") == 0,
        "Hunting Lodge must reject unrelated labor roles")

    var hunter_a = main.village.spawn_villager(keep.position + Vector2(0, 26))
    var hunter_b = main.village.spawn_villager(keep.position + Vector2(8, 26))
    var hunter_c = main.village.spawn_villager(keep.position + Vector2(-8, 26))
    assert(hunter_a.set_job("hunter") and hunter_b.set_job("hunter"),
        "Two Hunters must claim the Hunting Lodge")
    assert(not hunter_c.set_job("hunter"),
        "A third Hunter must respect the Lodge's two-slot capacity")
    assert(lodge.free_slots("hunter") == 0,
        "Hunting Lodge capacity must track both assigned workers")

    var nearby_animals := 0
    for animal in get_nodes_in_group("wildlife"):
        if animal.is_available(hunter_a) and hunter_a._is_in_workplace_radius(animal):
            nearby_animals += 1
    assert(nearby_animals > 0,
        "At least one available wildlife node must lie inside the Lodge radius")

    hunter_a._find_work()
    assert(hunter_a.target != null and hunter_a.target.is_in_group("wildlife"),
        "Hunter must select wildlife rather than a tree or farm")
    assert(hunter_a._is_in_workplace_radius(hunter_a.target),
        "Hunter must not work beyond the assigned Lodge radius")
    var first_target = hunter_a.target

    hunter_b._find_work()
    assert(hunter_b.target != first_target,
        "A reserved wildlife node must not be assigned to a second Hunter")

    hunter_a.state = hunter_a.State.WORKING
    for hit_index in 3:
        hunter_a._tick_working(1.2)
    assert(int(first_target.export_state()["hp"]) == 0,
        "Three hunting strikes must deplete a wildlife node")
    assert(hunter_a.carry == 5 and hunter_a.carry_kind == "food",
        "A depleted wildlife node must yield three food plus a two-food completion bonus")
    assert(hunter_a._depot == keep and hunter_a.state == hunter_a.State.TO_DEPOT,
        "A Hunter carrying food must route to the connected Keep depot")

    var food_before: int = inventory.get_amount("food")
    hunter_a.position = keep.position
    hunter_a._deposit()
    assert(inventory.get_amount("food") == food_before + 5,
        "Hunter food must enter central Inventory through the existing depot deposit path")

    main.village.quota["hunter"] = 2
    var snapshot: Dictionary = save_system.collect(main)
    assert(snapshot["version"] == 14,
        "Hunter occupation and wildlife state must use additive save version 14")
    assert(save_system._valid_save(snapshot),
        "A live Hunting Lodge and Hunter snapshot must validate")
    var has_hunter := false
    var has_food_resource := false
    for saved_villager in snapshot["villagers"]:
        has_hunter = has_hunter or String(saved_villager.get("occupation", "")) == "hunter"
    for resource in snapshot["resources"]:
        has_food_resource = has_food_resource or String(resource.get("kind", "")) == "food"
    assert(has_hunter and has_food_resource,
        "Save must persist Hunter occupation and wildlife depletion state")

    var legacy_v13: Dictionary = snapshot.duplicate(true)
    legacy_v13["version"] = 13
    legacy_v13["quota"].erase("hunter")
    legacy_v13["job_priority"].erase("hunter")
    for saved_villager in legacy_v13["villagers"]:
        if String(saved_villager.get("occupation", "")) == "hunter":
            saved_villager["occupation"] = ""
            saved_villager["job"] = ""
    var old_resources: Array = []
    for resource in legacy_v13["resources"]:
        if String(resource.get("kind", "")) != "food":
            old_resources.append(resource)
    legacy_v13["resources"] = old_resources
    for index in range(legacy_v13["buildings"].size() - 1, -1, -1):
        if String(legacy_v13["buildings"][index].get("id", "")) == "hunting_lodge":
            legacy_v13["buildings"].remove_at(index)
    assert(save_system._valid_save(legacy_v13),
        "Existing v13 saves must remain valid after the v14 Hunter migration")

    lodge.demolish()
    await ticks(2)
    assert(hunter_a.workplace == null and hunter_b.workplace == null,
        "Removing the Lodge must release all Hunter workplace claims")
    assert(hunter_a.job.is_empty() and hunter_b.job.is_empty(),
        "Hunters must return to unassigned status when their workplace is removed")

    print("PASS: Hunter assignment, Lodge capacity/radius, wildlife reservation/yield, food delivery, v14 save migration and teardown")
    quit(0)
