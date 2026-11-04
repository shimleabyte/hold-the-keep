extends SceneTree
## Phase 02.3: player shipment orders, visible carriers, interruptions and recoverable cargo.

func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func require(condition: bool, message: String) -> void:
    if not condition:
        push_error("FAIL: " + message)
        quit(1)
    assert(condition, message)


func order_for(orders: Array[Dictionary], order_id: int) -> Dictionary:
    for order in orders:
        if int(order.get("id", -1)) == order_id:
            return order
    return {}


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
    main.supply.set_process(false)

    var keep_cell: Vector2i = main.world.starting_keep_cell()
    var source_cell := keep_cell + Vector2i(3, 0)
    var destination_cell := keep_cell + Vector2i(-3, 0)
    var source = main.build.place_raw("storage", source_cell)
    var destination = main.build.place_raw("storage", destination_cell)
    await ticks(2)
    main.nav.rebuild()
    main.supply.rebuild()
    require(main.supply.is_depot_connected(source) and main.supply.is_depot_connected(destination),
        "Both adjacent depots must connect to the Keep-rooted road network")
    require(source.store_resource("wood", 18),
        "The source depot must accept stock before the shipment is ordered")

    var source_before: int = source.stockpile_amount("wood")
    var shipment_id: int = main.supply.create_shipment(source_cell, destination_cell, "wood", 10)
    require(shipment_id > 0, "A valid connected-depot shipment order must be accepted")
    require(source.stockpile_amount("wood") == source_before - 10,
        "Shipment cargo must be reserved atomically at order creation")
    var queued_order := order_for(main.supply.get_shipment_orders(), shipment_id)
    require(String(queued_order.get("status", "")) == "in_transit",
        "An available route must dispatch a physical courier immediately")
    var exposed_orders := main.supply.get_shipment_orders()
    exposed_orders[0]["cargo"] = 999
    require(int(order_for(main.supply.get_shipment_orders(), shipment_id)["cargo"]) == 10,
        "Shipment history snapshots must not allow callers to mutate reserved ledger cargo")
    require(get_nodes_in_group("supply_carriers").size() == 1,
        "A visible carrier entity must exist while the shipment is moving")

    var hud = get_first_node_in_group("hud")
    require(hud != null and hud._shipment_source != null and hud._shipment_destination != null,
        "The JOBS → POS panel must expose source and destination shipment selectors")
    require(hud._shipment_orders_list != null,
        "The shipment order history must be displayed in the depot panel")

    await ticks(300)
    var delivered_order := order_for(main.supply.get_shipment_orders(), shipment_id)
    require(String(delivered_order.get("status", "")) == "delivered" and int(delivered_order.get("cargo", -1)) == 0,
        "A carrier reaching its destination must settle the order exactly once")
    require(destination.stockpile_amount("wood") == 10 and source.stockpile_amount("wood") == 8,
        "Physical delivery must credit the destination and preserve the source remainder")

    var central_before: int = inventory.get_amount("wood")
    var withdrawal_id: int = main.supply.create_shipment(source_cell, keep_cell, "wood", 4)
    require(withdrawal_id > 0 and source.stockpile_amount("wood") == 4,
        "A player shipment back to Keep must withdraw local stock")
    await ticks(220)
    require(inventory.get_amount("wood") == central_before + 4,
        "A delivered Keep-bound shipment must credit central Inventory")
    require(String(order_for(main.supply.get_shipment_orders(), withdrawal_id)["status"]) == "delivered",
        "The Keep-bound physical withdrawal must complete")

    var cancel_source_before: int = source.stockpile_amount("wood")
    var cancel_id: int = main.supply.create_shipment(source_cell, destination_cell, "wood", 2)
    require(cancel_id > 0, "A cancellable shipment must be accepted")
    require(main.supply.cancel_shipment(cancel_id),
        "An active shipment must be cancellable")
    var cancelled := order_for(main.supply.get_shipment_orders(), cancel_id)
    require(String(cancelled["status"]) == "cancelled" and int(cancelled["cargo"]) == 0,
        "Cancellation must close the order and clear its escrowed cargo")
    require(source.stockpile_amount("wood") == cancel_source_before,
        "Cancellation must refund the full reserved amount to its source")

    require(destination.store_resource("stone", 170),
        "The destination must accept stock up to its remaining capacity")
    var stock_before_rejected_order: int = source.stockpile_amount("wood")
    require(main.supply.create_shipment(source_cell, destination_cell, "wood", 1) < 0,
        "A shipment exceeding reserved destination capacity must be rejected")
    require(source.stockpile_amount("wood") == stock_before_rejected_order,
        "A rejected shipment must not debit its source")

    require(destination.take_resource("stone", 170) and destination.take_resource("wood", 10),
        "Test stock must be cleared before the interrupted shipment")
    require(source.store_resource("wood", 6),
        "The source must accept cargo for the interrupted shipment")
    var interrupted_id: int = main.supply.create_shipment(source_cell, destination_cell, "wood", 6)
    require(interrupted_id > 0, "The interruption test shipment must dispatch")
    await ticks(12)

    main.supply._depot_connections[destination.get_instance_id()] = false
    main.supply.advance_shipment_orders()
    var blocked := order_for(main.supply.get_shipment_orders(), interrupted_id)
    require(String(blocked.get("status", "")) == "blocked" and int(blocked.get("cargo", 0)) == 6,
        "A disconnected route must pause the courier without losing its in-transit cargo")
    require(Vector2(float(blocked["x"]), float(blocked["y"])).distance_to(source.position) > 0.5,
        "The interrupted order must retain the physical carrier's last position")

    var snapshot: Dictionary = save_system.collect(main)
    require(snapshot["version"] == 17,
        "Physical shipment and Hunter state must be stored in save schema v17")
    require(save_system._valid_save(snapshot),
        "A save with recoverable in-transit cargo must pass v17 validation")
    var saved_order := order_for(snapshot["supply"]["orders"], interrupted_id)
    require(String(saved_order["status"]) == "blocked" and int(saved_order["cargo"]) == 6,
        "Save export must turn a moving courier into a resumable blocked shipment")
    var legacy_v12 := snapshot.duplicate(true)
    legacy_v12["version"] = 12
    legacy_v12["quota"].erase("hunter")
    legacy_v12["job_priority"].erase("hunter")
    legacy_v12["quota"].erase("scout")
    legacy_v12["job_priority"].erase("scout")
    legacy_v12["quota"].erase("healer")
    legacy_v12["job_priority"].erase("healer")
    legacy_v12["quota"].erase("blacksmith")
    legacy_v12["job_priority"].erase("blacksmith")
    for saved_villager in legacy_v12["villagers"]:
        saved_villager.erase("weapon_equipped")
        saved_villager.erase("armor_equipped")
        if String(saved_villager.get("occupation", "")) == "scout":
            saved_villager["occupation"] = ""
            saved_villager["job"] = ""
        if String(saved_villager.get("occupation", "")) in ["hunter", "scout", "healer", "blacksmith"]:
            saved_villager["occupation"] = ""
            saved_villager["job"] = ""
        elif String(saved_villager.get("job", "")) in ["hunter", "scout", "healer", "blacksmith"]:
            saved_villager["job"] = ""
    for legacy_building_index in range(legacy_v12["buildings"].size() - 1, -1, -1):
        if String(legacy_v12["buildings"][legacy_building_index].get("id", "")) in ["hunting_lodge", "scout_post", "infirmary", "forge"]:
            legacy_v12["buildings"].remove_at(legacy_building_index)
    var legacy_resources: Array = []
    for resource in legacy_v12["resources"]:
        if String(resource.get("kind", "")) != "food":
            legacy_resources.append(resource)
    legacy_v12["resources"] = legacy_resources
    legacy_v12.erase("supply")
    require(save_system._valid_save(legacy_v12),
        "Legacy v12 saves without shipment records must remain loadable")
    var invalid_cargo := snapshot.duplicate(true)
    for saved_order_record in invalid_cargo["supply"]["orders"]:
        if int(saved_order_record["id"]) == interrupted_id:
            saved_order_record["cargo"] = 7
    require(not save_system._valid_save(invalid_cargo),
        "Save validation must reject shipment cargo greater than its reserved amount")

    require(save_system.save_current(true),
        "A campaign with interrupted shipment cargo must save")
    require(save_system.request_load(),
        "A v13 campaign with pending shipment cargo must reload")
    await ticks(12)
    var restored_main = get_first_node_in_group("main")
    require(restored_main != null, "Save reload must recreate the campaign")
    restored_main.supply.set_process(false)
    var restored_destination = null
    for depot in get_nodes_in_group("depots"):
        if depot.id == "storage" and depot.cell == destination_cell:
            restored_destination = depot
            break
    require(restored_destination != null,
        "The destination storage must be recreated on load")
    var restored_order := order_for(restored_main.supply.get_shipment_orders(), interrupted_id)
    require(int(restored_order.get("cargo", 0)) == 6,
        "Reload must preserve reserved cargo without duplication or loss")
    require(String(restored_order.get("status", "")) in ["blocked", "in_transit"],
        "A saved interrupted order must be resumable after load")

    restored_main.supply._depot_connections[restored_destination.get_instance_id()] = true
    restored_main.supply.advance_shipment_orders()
    await ticks(300)
    var resumed_order := order_for(restored_main.supply.get_shipment_orders(), interrupted_id)
    require(String(resumed_order.get("status", "")) == "delivered"
        and restored_destination.stockpile_amount("wood") >= 6,
        "Restored cargo must resume its physical route and arrive exactly once")

    print("PASS: player shipment orders, physical carriers, Keep withdrawals, capacity reservations, cancellation, route recovery and v15 persistence")
    quit(0)
