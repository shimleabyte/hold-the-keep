extends SceneTree
## Blacksmith/Forge: capacity, target reservation, recipes, equipment stats, save migration and teardown.

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
    var tech = root.get_node("Tech")
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
    require(keep != null, "Classic campaign must retain its Keep")

    var without_forge = main.village.spawn_villager(keep.position + Vector2(0, 20))
    require(not without_forge.set_job("blacksmith"),
        "Blacksmith assignment must fail without a Forge")
    require(without_forge.job.is_empty(),
        "A failed Forge assignment must not leave a phantom Blacksmith occupation")

    tech.import_state({"done": ["masonry", "leather", "drill", "iron_mining", "iron_weapons", "iron_armor"]})
    require(tech.building_unlocked("forge"),
        "Iron Mining must unlock Forge placement")
    inventory.items = {"wood": 500, "stone": 500, "food": 100, "iron": 100}
    var forge_cell := find_build_site(main, keep.cell, Vector2i(2, 2))
    require(forge_cell.x >= 0, "A reachable Forge footprint must exist")
    var forge = main.build.place_raw("forge", forge_cell)
    await ticks(3)
    main.nav.rebuild()

    require(forge.free_slots("blacksmith") == 2,
        "Forge must provide exactly two Blacksmith slots")
    require(forge.free_slots("soldier") == 0 and forge.free_slots("healer") == 0,
        "Forge must reject unrelated workplace roles")

    var soldier_a = main.village.spawn_villager(forge.position + Vector2(-16, 30))
    var soldier_b = main.village.spawn_villager(forge.position + Vector2(16, 30))
    require(soldier_a.set_job("soldier") and soldier_b.set_job("soldier"),
        "Forge equipment targets must be active friendly soldiers")

    var smith_a = main.village.spawn_villager(forge.position + Vector2(-10, 34))
    var smith_b = main.village.spawn_villager(forge.position + Vector2(10, 34))
    var smith_c = main.village.spawn_villager(forge.position + Vector2(0, 38))
    require(smith_a.set_job("blacksmith") and smith_b.set_job("blacksmith"),
        "Two Blacksmiths must claim Forge workplaces")
    require(not smith_c.set_job("blacksmith"),
        "A third Blacksmith must respect Forge capacity")
    require(smith_a.workplace == forge and smith_b.workplace == forge,
        "Both Blacksmiths must retain the Forge workplace identity")
    require(forge.free_slots("blacksmith") == 0,
        "Forge capacity must account for both assigned Blacksmiths")

    smith_a._find_work()
    require(smith_a.target != null and smith_a.state == smith_a.State.TO_WORK,
        "Blacksmith must select an eligible soldier and begin pathing")
    var first_target = smith_a.target
    require(forge.is_blacksmith_target_reserved(first_target),
        "Selected soldier must be reserved at the Forge")
    smith_b._find_work()
    require(smith_b.target != null and smith_b.target != first_target,
        "A second Blacksmith must not select the first smith's reserved soldier")
    var second_target = smith_b.target
    require(forge.is_blacksmith_target_reserved(second_target),
        "Second soldier must receive an independent reservation")

    var iron_before_weapon := inventory.get_amount("iron")
    var wood_before_weapon := inventory.get_amount("wood")
    smith_a.state = smith_a.State.WORKING
    smith_a._tick_working(smith_a.SMITH_WORK_SECONDS)
    require(first_target.weapon_equipped,
        "A complete Weapon recipe must equip the reserved soldier")
    require(inventory.get_amount("iron") == iron_before_weapon - 3
            and inventory.get_amount("wood") == wood_before_weapon - 1,
        "Iron Weapon must consume exactly 3 iron and 1 wood")
    require(first_target._soldier_damage() == roundi(tech.stat("soldier.damage", 8.0) * 1.2),
        "Individual Iron Weapon must add a bounded 20 percent soldier damage bonus")
    require(not forge.is_blacksmith_target_reserved(first_target),
        "A completed weapon recipe must release its soldier reservation")

    var old_max_hp: int = first_target.max_hp
    first_target.hp = maxi(1, old_max_hp - 10)
    smith_a._find_work()
    require(smith_a.target == first_target and smith_a._smith_recipe == "armor",
        "After weapon completion, the same soldier must become eligible for its missing armor")
    var iron_before_armor := inventory.get_amount("iron")
    var wood_before_armor := inventory.get_amount("wood")
    smith_a.state = smith_a.State.WORKING
    smith_a._tick_working(smith_a.SMITH_WORK_SECONDS)
    require(first_target.armor_equipped and first_target.max_hp > old_max_hp,
        "Iron Armor must increase the soldier's maximum HP")
    require(inventory.get_amount("iron") == iron_before_armor - 4
            and inventory.get_amount("wood") == wood_before_armor - 2,
        "Iron Armor must consume exactly 4 iron and 2 wood")
    require(first_target.hp <= first_target.max_hp,
        "Armor installation must keep current HP within the increased maximum")

    main.village.quota["blacksmith"] = 2
    var snapshot: Dictionary = save_system.collect(main)
    require(snapshot["version"] == 17,
        "Blacksmith equipment and occupation must use additive save version 17")
    require(save_system._valid_save(snapshot),
        "A live Forge, Blacksmith occupation and equipped soldier snapshot must validate")
    var saved_smith := false
    var saved_weapon := false
    var saved_armor := false
    for villager in snapshot["villagers"]:
        saved_smith = saved_smith or String(villager.get("occupation", "")) == "blacksmith"
        saved_weapon = saved_weapon or bool(villager.get("weapon_equipped", false))
        saved_armor = saved_armor or bool(villager.get("armor_equipped", false))
    require(saved_smith and saved_weapon and saved_armor,
        "Save must persist Blacksmith occupation and both individual equipment flags")

    var legacy_v16: Dictionary = snapshot.duplicate(true)
    legacy_v16["version"] = 16
    legacy_v16["quota"].erase("blacksmith")
    legacy_v16["job_priority"].erase("blacksmith")
    for villager in legacy_v16["villagers"]:
        if String(villager.get("occupation", "")) == "blacksmith":
            villager["occupation"] = ""
            villager["job"] = ""
        villager.erase("weapon_equipped")
        villager.erase("armor_equipped")
    require(save_system._valid_save(legacy_v16),
        "Existing v16 saves must remain valid after the Blacksmith v17 migration")

    smith_b._physics_process(0.1)
    require(smith_b.target == second_target,
        "The second Blacksmith must retain its own in-transit soldier reservation")
    forge.demolish()
    require(smith_a.workplace == null and smith_b.workplace == null,
        "Forge demolition must release both Blacksmith workplace claims")
    require(not forge.is_blacksmith_target_reserved(second_target),
        "Forge demolition must release any in-progress soldier target reservation")
    main.village.quota["woodcutter"] = 0
    main.village.assign_jobs()
    require(smith_a.job.is_empty() and smith_b.job.is_empty(),
        "Blacksmiths must return to unassigned status when their Forge is removed")

    print("PASS: Blacksmith Forge capacity, soldier reservations, weapon/armor costs and effects, v16 migration and workplace teardown")
    quit(0)
