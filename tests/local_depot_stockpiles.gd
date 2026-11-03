extends SceneTree
## Frontier local depot stockpiles, bounded capacity and save v14 persistence.

func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func require(condition: bool, message: String) -> void:
    if not condition:
        push_error("FAIL: " + message)
        quit(1)
    assert(condition, message)


func _initialize() -> void:
    var world_config = root.get_node("WorldConfig")
    var game_clock = root.get_node("GameClock")
    var save_system = root.get_node("SaveSystem")
    var inventory = root.get_node("Inventory")
    world_config.apply_profile("frontier")
    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(8)
    game_clock.set_process(false)

    var keep_cell: Vector2i = main.world.starting_keep_cell()
    var storage_cell := keep_cell + Vector2i(3, 0)
    var storage = main.build.place_raw("storage", storage_cell)
    await ticks(2)
    main.supply.rebuild()
    require(main.supply.is_depot_connected(storage),
        "A storage touching the Keep footprint must join its connected supply network")
    require(storage.stockpile_capacity == 180,
        "Storage must expose its configured local capacity")

    var inventory_before: int = inventory.get_amount("wood")
    var courier = main.village.spawn_villager(storage.position + Vector2(0, 22))
    courier.carry = 7
    courier.carry_kind = "wood"
    courier._depot = storage
    courier._deposit()
    require(storage.stockpile_amount("wood") == 7,
        "Frontier worker deposits must increase the destination depot's local stock")
    require(inventory.get_amount("wood") == inventory_before,
        "A remote depot deposit must not silently credit the Keep's central inventory")
    require(courier.carry == 0 and courier.carry_kind.is_empty(),
        "A successful local depot deposit must clear the worker cargo exactly once")

    require(storage.store_resource("stone", 173),
        "Local storage must accept resources up to its remaining capacity")
    require(storage.stockpile_total() == 180,
        "Local stockpile total must equal the accepted capacity")
    require(not storage.store_resource("iron", 1),
        "A full depot must reject additional resource cargo")
    require(not storage.store_resource("gems", 1),
        "Unknown resource kinds must be rejected")
    require(not storage.take_resource("food", 1),
        "A depot must not withdraw more resources than it owns")
    require(storage.take_resource("wood", 2),
        "A depot must allow an exact withdrawal from its local stock")
    require(storage.stockpile_amount("wood") == 5,
        "A partial withdrawal must preserve the remaining local balance")

    var central_wood_before: int = inventory.get_amount("wood")
    var central_stone_before: int = inventory.get_amount("stone")
    var transferred: int = int(main.supply.transfer_local_stockpiles())
    require(transferred == 6,
        "A connected remote depot must transfer no more than its six-unit interval budget")
    require(inventory.get_amount("wood") == central_wood_before + 5
        and inventory.get_amount("stone") == central_stone_before + 1,
        "The bounded transfer must credit exact quantities to central inventory")
    require(storage.stockpile_amount("wood") == 0 and storage.stockpile_amount("stone") == 172,
        "The transfer must remove the same quantities from the source depot")
    require(storage.store_resource("wood", 5),
        "The remaining depot must still accept new local deposits after a shipment")

    var snapshot: Dictionary = save_system.collect(main)
    require(snapshot["version"] == 14, "Local depot and Hunter state must use save schema v14")
    var saved_storage: Dictionary = {}
    for saved_building in snapshot["buildings"]:
        if String(saved_building["id"]) == "storage" and int(saved_building["cx"]) == storage_cell.x:
            saved_storage = saved_building
            break
    require(saved_storage.get("stockpile", {}) == storage.export_stockpile(),
        "Save payload must serialize every local stockpile balance")
    require(save_system._valid_save(snapshot),
        "A save with valid local stockpile state must pass current v14 validation")

    var negative_stock := snapshot.duplicate(true)
    for saved_building in negative_stock["buildings"]:
        if int(saved_building["cx"]) == storage_cell.x and String(saved_building["id"]) == "storage":
            saved_building["stockpile"]["wood"] = -1
    require(not save_system._valid_save(negative_stock),
        "Save validation must reject negative local inventory")

    var over_capacity := snapshot.duplicate(true)
    for saved_building in over_capacity["buildings"]:
        if int(saved_building["cx"]) == storage_cell.x and String(saved_building["id"]) == "storage":
            saved_building["stockpile"] = {"wood": 181}
    require(not save_system._valid_save(over_capacity),
        "Save validation must reject local inventory above depot capacity")

    var legacy_v11 := snapshot.duplicate(true)
    legacy_v11["version"] = 11
    legacy_v11["quota"].erase("hunter")
    legacy_v11["job_priority"].erase("hunter")
    for villager in legacy_v11["villagers"]:
        if String(villager.get("occupation", "")) == "hunter":
            villager["occupation"] = ""
            villager["job"] = ""
        elif String(villager.get("job", "")) == "hunter":
            villager["job"] = ""
    var legacy_resources: Array = []
    for resource in legacy_v11["resources"]:
        if String(resource.get("kind", "")) != "food":
            legacy_resources.append(resource)
    legacy_v11["resources"] = legacy_resources
    for index in range(legacy_v11["buildings"].size() - 1, -1, -1):
        var legacy_building_id := String(legacy_v11["buildings"][index].get("id", ""))
        if legacy_building_id == "hunting_lodge":
            legacy_v11["buildings"].remove_at(index)
        else:
            legacy_v11["buildings"][index].erase("stockpile")
    require(save_system._valid_save(legacy_v11),
        "Existing v11 saves without local stockpile fields must remain migratable")

    require(save_system.save_current(true), "A Frontier save with local depot inventory must succeed")
    require(save_system.request_load(), "A v14 Frontier save with local inventory must reload")
    await ticks(12)
    var restored = current_scene
    game_clock.set_process(false)
    var restored_storage = null
    for building in get_nodes_in_group("buildings"):
        if String(building.id) == "storage" and building.cell == storage_cell:
            restored_storage = building
            break
    require(restored_storage != null, "The saved storage building must be recreated")
    require(restored_storage.stockpile_amount("wood") == 5 and restored_storage.stockpile_amount("stone") == 172,
        "Save/load must preserve local depot balances without duplication or loss")

    print("PASS: Frontier local depot storage, bounded shipments, cargo deposits and v12 save migration/round-trip")
    quit(0)