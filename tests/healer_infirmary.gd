extends SceneTree
## Healer/Infirmary: assignment, treatment, patient reservations, workplace teardown and v16 migration.

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
    var data_db = root.get_node("DataDB")
    var tech = root.get_node("Tech")
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
    require(data_db.techs.has("field_medicine") and data_db.buildings.has("infirmary"),
        "Field Medicine and Infirmary definitions must load through DataDB")
    require(data_db.techs["field_medicine"]["effects"]["unlock_building"].has("infirmary"),
        "Field Medicine must explicitly unlock the Infirmary")
    require(data_db.techs.size() == 21,
        "The technology tree must contain 21 defined technologies")

    var without_infirmary = main.village.spawn_villager(keep.position + Vector2(0, 22))
    require(not without_infirmary.set_job("healer"),
        "Healer assignment must fail until an Infirmary workplace exists")
    require(without_infirmary.job.is_empty(),
        "Failed Healer assignment must not leave a phantom occupation")

    inventory.items = {"wood": 500, "stone": 500, "food": 100, "iron": 100}
    var infirmary_cell := find_build_site(main, keep.cell, Vector2i(3, 2))
    require(infirmary_cell.x >= 0, "A reachable Infirmary footprint must exist")
    var infirmary = main.build.place_raw("infirmary", infirmary_cell)
    await ticks(3)
    main.nav.rebuild()

    require(infirmary.free_slots("healer") == 2,
        "Infirmary must expose exactly two Healer workplace slots")
    require(infirmary.free_slots("soldier") == 0 and infirmary.free_slots("builder") == 0,
        "Infirmary must reject unrelated labor roles")
    require(String(infirmary.data.get("name", "")) == "Balai Perawatan",
        "Infirmary must use its own player-facing building definition")
    require(tech.building_unlocked("infirmary") == false,
        "Infirmary must remain locked before Field Medicine is researched")

    var patient_a = main.village.spawn_villager(keep.position + Vector2(-8, 22))
    var patient_b = main.village.spawn_villager(keep.position + Vector2(8, 22))
    require(patient_a.set_job("soldier") and patient_b.set_job("soldier"),
        "Damaged friendly soldiers must be valid treatment patients")
    patient_a.hp = 20
    patient_b.hp = 30

    var healer_a = main.village.spawn_villager(keep.position + Vector2(0, 26))
    var healer_b = main.village.spawn_villager(keep.position + Vector2(8, 26))
    var healer_c = main.village.spawn_villager(keep.position + Vector2(-8, 26))
    require(healer_a.set_job("healer") and healer_b.set_job("healer"),
        "Two Healers must claim the Infirmary")
    require(not healer_c.set_job("healer"),
        "A third Healer must respect the Infirmary's two-slot capacity")
    require(infirmary.free_slots("healer") == 0,
        "Infirmary capacity must track both assigned Healers")
    require(healer_a.workplace == infirmary and healer_b.workplace == infirmary,
        "Both assigned Healers must retain the Infirmary workplace identity")

    healer_a._find_work()
    require(healer_a.target == patient_a and healer_a.state == healer_a.State.TO_WORK,
        "Healer must select the most wounded reachable soldier and begin pathing")
    require(infirmary.is_heal_target_reserved(patient_a),
        "A selected patient must be reserved at the Infirmary")
    require(healer_a._is_in_workplace_radius(patient_a),
        "Healer must only select patients inside the Infirmary service radius")

    healer_b._find_work()
    require(healer_b.target == patient_b,
        "A second Healer must select another wounded soldier instead of stealing the reserved patient")
    require(infirmary.is_heal_target_reserved(patient_b),
        "The second patient must receive an independent reservation")

    healer_a.state = healer_a.State.WORKING
    healer_a._tick_working(healer_a.HEAL_INTERVAL)
    require(patient_a.hp == 30,
        "One complete treatment interval must restore exactly 10 HP")
    patient_a.hp = patient_a.max_hp - 5
    healer_a._tick_working(healer_a.HEAL_INTERVAL)
    require(patient_a.hp == patient_a.max_hp,
        "Treatment must clamp healing to the patient's maximum HP")
    require(healer_a.target == null and healer_a.state == healer_a.State.IDLE,
        "A fully recovered patient must be discharged and the Healer returned to idle")
    require(not infirmary.is_heal_target_reserved(patient_a),
        "Discharged patients must release their reservation")

    main.village.quota["healer"] = 2
    var snapshot: Dictionary = save_system.collect(main)
    require(snapshot["version"] == 16,
        "Healer occupation and Infirmary must use additive save version 16")
    require(save_system._valid_save(snapshot),
        "A live Infirmary and Healer snapshot must validate")
    var has_healer := false
    var saved_infirmary := false
    for villager in snapshot["villagers"]:
        has_healer = has_healer or String(villager.get("occupation", "")) == "healer"
    for building in snapshot["buildings"]:
        saved_infirmary = saved_infirmary or String(building.get("id", "")) == "infirmary"
    require(has_healer and saved_infirmary,
        "Save must persist Healer occupation and the Infirmary building")

    var legacy_v15: Dictionary = snapshot.duplicate(true)
    legacy_v15["version"] = 15
    legacy_v15["quota"].erase("healer")
    legacy_v15["job_priority"].erase("healer")
    for villager in legacy_v15["villagers"]:
        if String(villager.get("occupation", "")) == "healer":
            villager["occupation"] = ""
            villager["job"] = ""
    for index in range(legacy_v15["buildings"].size() - 1, -1, -1):
        if String(legacy_v15["buildings"][index].get("id", "")) == "infirmary":
            legacy_v15["buildings"].remove_at(index)
    require(save_system._valid_save(legacy_v15),
        "Existing v15 saves must remain valid after the Healer v16 migration")

    infirmary.demolish()
    require(not infirmary.is_heal_target_reserved(patient_b),
        "Demolishing the Infirmary must release any active patient reservation")
    main.village.assign_jobs()
    await ticks(2)
    require(healer_a.workplace == null and healer_b.workplace == null,
        "Removing the Infirmary must release every Healer workplace claim")
    require(healer_a.job.is_empty() and healer_b.job.is_empty(),
        "Healers must return to unassigned status when their Infirmary is removed")

    print("PASS: Healer workplace requirement/capacity, wounded-patient selection, unique reservations, bounded healing, v15 migration and demolition cleanup")
    quit(0)
