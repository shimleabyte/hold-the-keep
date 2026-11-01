extends SceneTree
## Phase 02: explicit source-depot payment for construction and research.

func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func require(condition: bool, message: String) -> void:
    if not condition:
        push_error("FAIL: " + message)
        quit(1)
    assert(condition, message)


func find_house_cell(main, keep_cell: Vector2i) -> Vector2i:
    for radius in range(4, 14):
        for y in range(-radius, radius + 1):
            for x in range(-radius, radius + 1):
                if maxi(absi(x), absi(y)) != radius:
                    continue
                var cell := keep_cell + Vector2i(x, y)
                if main.build.check("house", cell) == "":
                    return cell
    return Vector2i(-1, -1)


func _initialize() -> void:
    var world_config = root.get_node("WorldConfig")
    var game_clock = root.get_node("GameClock")
    var inventory = root.get_node("Inventory")
    var tech = root.get_node("Tech")
    var save_system = root.get_node("SaveSystem")
    world_config.apply_profile("frontier")
    inventory.items = {"wood": 0, "stone": 0, "food": 0, "iron": 0}
    tech.reset()
    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(10)
    game_clock.set_process(false)
    tech.set_process(false)
    main.supply.set_process(false)
    main.build.player = null

    var keep_cell: Vector2i = main.world.starting_keep_cell()
    var first_cell := keep_cell + Vector2i(3, 0)
    var second_cell := keep_cell + Vector2i(-3, 0)
    var first = main.build.place_raw("storage", first_cell)
    var second = main.build.place_raw("storage", second_cell)
    await ticks(2)
    main.nav.rebuild()
    main.supply.rebuild()

    require(main.supply.is_depot_connected(first) and main.supply.is_depot_connected(second),
        "Adjacent Storage depots must be eligible sources through the Keep-rooted network")
    require(main.supply.get_cost_source_cell() == keep_cell,
        "New Frontier campaigns must default to the central Keep as cost source")

    require(first.store_resource("wood", 12),
        "The selected Storage must accept the construction budget")
    require(main.supply.set_cost_source(first_cell),
        "A connected Storage must be selectable as the active cost source")
    var stock_before_atomic_failure: int = first.stockpile_amount("wood")
    require(not main.supply.pay_cost({"wood": 12, "stone": 1})
        and first.stockpile_amount("wood") == stock_before_atomic_failure,
        "A multi-resource payment must reject atomically without partially debiting wood")
    require(main.supply.can_pay_cost({"wood": 12}),
        "Cost availability must read the selected depot's local stock")
    require(not inventory.can_afford({"wood": 12}),
        "Local affordability must not be fabricated in the central Inventory")

    var hud = get_first_node_in_group("hud")
    require(hud != null and hud._cost_source_option != null,
        "JOBS → POS must expose the shared construction/research source selector")
    hud._refresh_outpost_panel()
    require(hud._cost_source_option.item_count >= 3,
        "The cost selector must list Keep and both remote depots")

    var house_cell := find_house_cell(main, keep_cell)
    require(house_cell != Vector2i(-1, -1),
        "The test must find a valid buildable house footprint inside Keep territory")
    require(main.build.place("house", house_cell) == "",
        "Construction must accept a cost funded by the selected Storage")
    require(first.stockpile_amount("wood") == 0 and inventory.get_amount("wood") == 0,
        "Construction must debit the selected depot directly without crediting/debiting Keep Inventory")

    require(first.store_resource("wood", 15),
        "The selected Storage must accept the technology research budget")
    require(tech.start("tools_wood"),
        "Research must start when its exact cost exists at the selected depot")
    require(first.stockpile_amount("wood") == 0 and inventory.get_amount("wood") == 0,
        "Research must debit the selected depot at start, not the central Inventory")

    require(first.store_resource("wood", 5) and second.store_resource("wood", 7),
        "Separate depots must be able to hold independent partial quantities")
    require(not main.supply.can_pay_cost({"wood": 12}),
        "Cost checks must not pool partial balances from two depots")
    require(main.supply.set_cost_source(second_cell),
        "The player must be able to switch the source to another connected depot")
    require(not main.supply.can_pay_cost({"wood": 12}),
        "A second depot with only seven units must not cover a twelve-unit cost")
    require(main.supply.set_cost_source(first_cell),
        "The source selector must be able to return to the first depot")

    var first_before: int = first.stockpile_amount("wood")
    main.supply._depot_connections[first.get_instance_id()] = false
    require(main.supply.cost_reason({"wood": 1}) == "Jalur ke sumber biaya terputus",
        "A disconnected selected depot must explicitly block spending")
    require(not main.supply.pay_cost({"wood": 1}) and first.stockpile_amount("wood") == first_before,
        "A failed route check must not withdraw any local stock")
    main.supply._depot_connections[first.get_instance_id()] = true

    var snapshot: Dictionary = save_system.collect(main)
    require(snapshot["version"] == 13,
        "The cost-source preference must remain an additive v13 supply field")
    require(snapshot["supply"]["cost_source"] == {"cx": first_cell.x, "cy": first_cell.y},
        "The selected cost depot must persist in the supply save state")
    require(save_system._valid_save(snapshot),
        "A valid save with a selected Storage cost source must pass validation")
    var legacy_v13 := snapshot.duplicate(true)
    legacy_v13["supply"].erase("cost_source")
    require(save_system._valid_save(legacy_v13),
        "Existing v13 saves without the additive source field must remain valid")
    var invalid_source := snapshot.duplicate(true)
    invalid_source["supply"]["cost_source"] = {"cx": 999, "cy": keep_cell.y}
    require(not save_system._valid_save(invalid_source),
        "Save validation must reject a cost source outside map bounds")

    require(save_system.save_current(true),
        "A campaign with a selected depot cost source must save")
    require(main.supply.set_cost_source(keep_cell),
        "The active cost source must be changeable before reload")
    require(save_system.request_load(),
        "A v13 campaign with the selected depot must reload")
    await ticks(14)
    var restored_main = get_first_node_in_group("main")
    require(restored_main != null,
        "Save reload must recreate the campaign")
    restored_main.supply.set_process(false)
    tech.set_process(false)
    require(restored_main.supply.get_cost_source_cell() == first_cell,
        "Save/load must restore the explicitly selected cost source")

    print("PASS: explicit Keep/Storage/Outpost payment source, atomic local spending, no cross-depot pooling, disconnection rejection, UI selection and v13 persistence")
    quit(0)
