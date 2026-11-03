extends SceneTree
## Phase 05.3b: food-only Granary storage, population upkeep, Frontier logistics and v15 persistence.

func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func require(condition: bool, message: String) -> void:
    if not condition:
        push_error("FAIL: " + message)
        quit(1)
    assert(condition, message)


func footprint_is_clear(main, anchor: Vector2i, footprint: Vector2i) -> bool:
    var map_size := int(root.get_node("WorldConfig").map_size)
    if anchor.x < 1 or anchor.y < 1 or anchor.x + footprint.x >= map_size - 1 or anchor.y + footprint.y >= map_size - 1:
        return false
    for dy in footprint.y:
        for dx in footprint.x:
            var cell := anchor + Vector2i(dx, dy)
            if not main.world.is_buildable(cell) or main.world.occupied.has(cell):
                return false
    return true


func find_adjacent_site(main, keep, footprint: Vector2i) -> Vector2i:
    var candidates: Array[Vector2i] = [
        keep.cell + Vector2i(keep.size.x, 0),
        keep.cell + Vector2i(-footprint.x, 0),
        keep.cell + Vector2i(0, keep.size.y),
        keep.cell + Vector2i(0, -footprint.y)
    ]
    for candidate in candidates:
        if footprint_is_clear(main, candidate, footprint):
            return candidate
    return Vector2i(-1, -1)


func find_building(building_id: String, cell: Vector2i):
    for building in get_nodes_in_group("buildings"):
        if is_instance_valid(building) and String(building.id) == building_id and building.cell == cell:
            return building
    return null


func option_index_for_cell(option: OptionButton, cell: Vector2i) -> int:
    for index in option.item_count:
        var metadata: Variant = option.get_item_metadata(index)
        if metadata is Dictionary and Vector2i(int(metadata.get("cx", -1)), int(metadata.get("cy", -1))) == cell:
            return index
    return -1


func stop_current_main() -> void:
    var main = get_first_node_in_group("main")
    if main != null and is_instance_valid(main):
        main.queue_free()
    await ticks(5)
    current_scene = null


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var config = root.get_node("WorldConfig")
    var clock = root.get_node("GameClock")
    var tech = root.get_node("Tech")
    var inventory = root.get_node("Inventory")
    var save_system = root.get_node("SaveSystem")
    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)

    # Classic: the Granary is a secondary food reserve after central Inventory.
    config.apply_profile("classic")
    tech.reset()
    inventory.reset()
    var classic = load("res://scenes/main.tscn").instantiate()
    root.add_child(classic)
    current_scene = classic
    await ticks(8)
    clock.set_process(false)
    classic.village.set_process(false)

    var keep = null
    for building in get_nodes_in_group("buildings"):
        if String(building.id) == "keep":
            keep = building
            break
    require(keep != null, "Classic campaign must retain its Keep")
    var granary_cell := find_adjacent_site(classic, keep, Vector2i(3, 2))
    require(granary_cell.x >= 0, "Classic map must provide a Granary site beside the Keep")
    require(not tech.building_unlocked("granary"),
        "Granary must remain locked before its existing Granary research is completed")
    tech.researched.append("granary")
    tech._recompute()
    require(tech.building_unlocked("granary") and tech.available_buildings().has("granary"),
        "The Granary research must unlock the actual buildable facility")
    require(is_equal_approx(tech.stat("farm.workers", 3.0), 4.0),
        "The existing Granary research must retain its +1 farmer slot per farm effect")

    var granary = classic.build.place_raw("granary", granary_cell)
    await ticks(2)
    classic.supply.rebuild()
    require(granary.is_in_group("depots") and granary.is_in_group("granaries"),
        "A Granary must register as a local depot and food-reserve group")
    require(granary.stockpile_capacity == 240,
        "The Granary must expose its configured 240-unit reserve")
    require(classic.supply.is_depot_connected(granary),
        "A Granary placed adjacent to the Keep must join the connected depot network")
    require(granary.can_store_resource("food", 10),
        "A Granary must accept food")
    require(not granary.can_store_resource("wood", 1)
        and not granary.can_store_resource("stone", 1)
        and not granary.can_store_resource("iron", 1),
        "A Granary must reject non-food resources")
    require(not granary.store_resource("wood", 1),
        "Rejected resources must not enter the Granary stockpile")

    inventory.items["food"] = 1
    require(granary.store_resource("food", 10), "The Granary must accept its first food delivery")
    require(classic.village.food_available() == 11,
        "Classic food availability must include central Inventory and Granary reserve exactly once")
    require(classic.village.spend_food(5) == 5,
        "Food spending must draw from Inventory first, then Granary")
    require(inventory.get_amount("food") == 0 and granary.stockpile_amount("food") == 6,
        "Food spending must debit both ledgers without duplication")

    var population_before: int = classic.village.population()
    require(population_before > 0, "Classic test requires the initial population")
    classic.village._on_day_changed(1)
    require(classic.village.population() == population_before,
        "Daily upkeep must be able to feed Classic villagers from the Granary")
    require(granary.stockpile_amount("food") == 6 - population_before * 2,
        "Daily upkeep must debit exactly two food per villager from the reserve")

    var farmer = classic.village.villagers()[0]
    farmer.carry = 4
    farmer.carry_kind = "food"
    farmer._depot = null
    farmer._go_depot()
    require(farmer._depot == granary,
        "A farmer carrying food must prioritize a reachable Granary over the central Keep")
    farmer._deposit()
    require(granary.stockpile_amount("food") == 10 - population_before * 2,
        "Farmer deliveries to a Granary must remain local in Classic")
    require(classic.village.food_available() == granary.stockpile_amount("food"),
        "HUD food availability must reflect the Granary reserve after central food reaches zero")
    var hud = get_first_node_in_group("hud")
    hud._refresh_resources()
    require(hud._food.text == str(granary.stockpile_amount("food")),
        "The top resource bar must display usable Granary food in Classic")

    var classic_food_before_save: int = granary.stockpile_amount("food")
    var classic_snapshot: Dictionary = save_system.collect(classic)
    require(classic_snapshot["version"] == 17 and save_system._valid_save(classic_snapshot),
        "A Classic save containing a food-only Granary must pass v17 validation")
    var saved_granary: Dictionary = {}
    for saved_building in classic_snapshot["buildings"]:
        if String(saved_building.get("id", "")) == "granary" and Vector2i(int(saved_building["cx"]), int(saved_building["cy"])) == granary_cell:
            saved_granary = saved_building
            break
    require(saved_granary.get("stockpile", {}) == {"food": granary.stockpile_amount("food")},
        "Save v17 must serialize the Granary's food reserve")
    var invalid_granary_stock := classic_snapshot.duplicate(true)
    for saved_building in invalid_granary_stock["buildings"]:
        if String(saved_building.get("id", "")) == "granary":
            saved_building["stockpile"]["wood"] = 1
    require(not save_system._valid_save(invalid_granary_stock),
        "Save validation must reject non-food resources inside a Granary")
    var legacy_v13 := classic_snapshot.duplicate(true)
    legacy_v13["version"] = 13
    legacy_v13["quota"].erase("hunter")
    legacy_v13["job_priority"].erase("hunter")
    legacy_v13["quota"].erase("scout")
    legacy_v13["job_priority"].erase("scout")
    legacy_v13["job_priority"].erase("healer")
    legacy_v13["quota"].erase("healer")
    legacy_v13["job_priority"].erase("healer")
    legacy_v13["quota"].erase("blacksmith")
    legacy_v13["job_priority"].erase("blacksmith")
    for villager in legacy_v13["villagers"]:
        villager.erase("weapon_equipped")
        villager.erase("armor_equipped")
        if String(villager.get("occupation", "")) == "blacksmith":
            villager["occupation"] = ""
            villager["job"] = ""
        if String(villager.get("occupation", "")) in ["hunter", "scout", "healer"]:
            villager["occupation"] = ""
            villager["job"] = ""
        elif String(villager.get("job", "")) in ["hunter", "scout", "healer"]:
            villager["job"] = ""
    var old_resources: Array = []
    for resource in legacy_v13["resources"]:
        if String(resource.get("kind", "")) != "food":
            old_resources.append(resource)
    legacy_v13["resources"] = old_resources
    for index in range(legacy_v13["buildings"].size() - 1, -1, -1):
        if String(legacy_v13["buildings"][index].get("id", "")) in ["granary", "hunting_lodge", "scout_post", "infirmary"]:
            legacy_v13["buildings"].remove_at(index)
    require(save_system._valid_save(legacy_v13),
        "Existing v13 saves without a Granary must remain valid")

    require(save_system.save_current(true) and save_system.request_load(),
        "A Classic campaign with stored Granary food must save and reload")
    await ticks(14)
    clock.set_process(false)
    var restored_classic = get_first_node_in_group("main")
    require(restored_classic != null, "Classic reload must recreate the campaign")
    var restored_granary = find_building("granary", granary_cell)
    require(restored_granary != null and restored_granary.stockpile_amount("food") == classic_food_before_save,
        "Classic reload must preserve the Granary stockpile exactly")

    await stop_current_main()

    # Frontier: the Granary participates in depot transfers and physical shipment rules.
    config.apply_profile("frontier")
    tech.reset()
    tech.researched.append("granary")
    tech._recompute()
    inventory.reset()
    var frontier = load("res://scenes/main.tscn").instantiate()
    root.add_child(frontier)
    current_scene = frontier
    await ticks(8)
    clock.set_process(false)
    frontier.village.set_process(false)
    frontier.supply.set_process(false)
    frontier.spawner.set_process(false)
    frontier.spawner.set_physics_process(false)

    keep = null
    for building in get_nodes_in_group("buildings"):
        if String(building.id) == "keep":
            keep = building
            break
    require(keep != null, "Frontier campaign must retain its Keep")
    granary_cell = find_adjacent_site(frontier, keep, Vector2i(3, 2))
    var storage_cell := find_adjacent_site(frontier, keep, Vector2i(3, 2))
    require(granary_cell.x >= 0 and storage_cell.x >= 0,
        "Frontier map must provide adjacent Granary and Storage sites")
    granary = frontier.build.place_raw("granary", granary_cell)
    storage_cell = find_adjacent_site(frontier, keep, Vector2i(3, 2))
    require(storage_cell.x >= 0 and storage_cell != granary_cell,
        "Frontier must reserve a distinct adjacent footprint for Storage")
    var storage = frontier.build.place_raw("storage", storage_cell)
    await ticks(3)
    frontier.supply.rebuild()
    require(frontier.supply.is_depot_connected(granary) and frontier.supply.is_depot_connected(storage),
        "Adjacent Granary and Storage depots must join the Keep-rooted network")
    hud = get_first_node_in_group("hud")
    require(hud != null and hud._shipment_source != null and hud._shipment_destination != null,
        "The logistics panel must expose shipment source and destination controls")
    hud._refresh_outpost_panel()
    var granary_source_index := option_index_for_cell(hud._shipment_source, granary_cell)
    var granary_destination_index := option_index_for_cell(hud._shipment_destination, granary_cell)
    require(granary_source_index >= 0 and granary_destination_index >= 0,
        "Granary must appear as both a source and destination in the shipment selectors")
    require("LUMBUNG" in hud._shipment_source.get_item_text(granary_source_index)
        and "LUMBUNG" in hud._shipment_destination.get_item_text(granary_destination_index),
        "Shipment selectors must identify the food depot as Lumbung, not a generic Storage")
    hud._shipment_source.select(granary_source_index)
    hud._refresh_shipment_controls()
    var food_kind_index := -1
    var wood_kind_index := -1
    for kind_index in hud._shipment_kind.item_count:
        var kind_name := String(hud._shipment_kind.get_item_metadata(kind_index))
        if kind_name == "food":
            food_kind_index = kind_index
        elif kind_name == "wood":
            wood_kind_index = kind_index
    require(food_kind_index >= 0 and wood_kind_index >= 0
        and not hud._shipment_kind.is_item_disabled(food_kind_index)
        and hud._shipment_kind.is_item_disabled(wood_kind_index),
        "A Granary source must enable FOOD and disable non-food shipment types")
    hud._shipment_source.select(0)
    hud._shipment_destination.select(granary_destination_index)
    hud._refresh_shipment_controls()
    require(not hud._shipment_kind.is_item_disabled(food_kind_index)
        and hud._shipment_kind.is_item_disabled(wood_kind_index),
        "A Granary destination must enable FOOD and disable non-food shipment types")
    hud._shipment_destination.select(0)
    hud._refresh_shipment_controls()
    require(granary.store_resource("food", 20) and storage.store_resource("wood", 5),
        "Granary food and Storage materials must be stored in separate local ledgers")

    var central_food_before: int = inventory.get_amount("food")
    var transferred: int = frontier.supply.transfer_local_stockpiles()
    require(transferred == 11,
        "The connected Storage and Granary must each obey the six-unit automatic transfer budget")
    require(granary.stockpile_amount("food") == 14 and storage.stockpile_amount("wood") == 0,
        "The transfer must debit the correct depot resources")
    require(inventory.get_amount("food") == central_food_before + 6,
        "Granary transfer must credit exactly six food to central Inventory")

    require(not frontier.supply.set_cost_source(granary_cell),
        "A food-only Granary must never be selectable as a construction/research cost source")
    require(storage.store_resource("wood", 2),
        "Storage must accept wood for the rejected-shipment test")
    var storage_wood_before: int = storage.stockpile_amount("wood")
    require(frontier.supply.create_shipment(storage_cell, granary_cell, "wood", 1) < 0
        and storage.stockpile_amount("wood") == storage_wood_before,
        "A shipment must not reserve or withdraw non-food cargo for a Granary")

    var granary_food_before: int = granary.stockpile_amount("food")
    var shipment_id: int = frontier.supply.create_shipment(granary_cell, keep.cell, "food", 4)
    require(shipment_id > 0 and granary.stockpile_amount("food") == granary_food_before - 4,
        "A Granary must be a valid food shipment source")
    require(frontier.supply.cancel_shipment(shipment_id)
        and granary.stockpile_amount("food") == granary_food_before,
        "Cancelling a Granary food shipment must restore its escrow to the source")

    require(frontier.supply.raid_steal_from(granary) == "food"
        and granary.stockpile_amount("food") == granary_food_before - 1,
        "A saboteur must be able to steal food from an isolated Granary")
    frontier.supply._depot_connections[granary.get_instance_id()] = false
    var pressure_key := "%d:%d" % [granary_cell.x, granary_cell.y]
    frontier.supply._pressure_records[pressure_key] = {
        "cx": granary_cell.x, "cy": granary_cell.y, "contested_seconds": 30.0,
        "warning_sent": true, "raid_count": 0, "spawn_retry": 0.0, "status": "vulnerable"
    }

    var frontier_food_before_save: int = granary.stockpile_amount("food")
    var frontier_snapshot: Dictionary = save_system.collect(frontier)
    require(frontier_snapshot["version"] == 17 and save_system._valid_save(frontier_snapshot),
        "Frontier Granary stockpile and isolated-depot pressure must pass v17 validation")
    var invalid_shipment := frontier_snapshot.duplicate(true)
    invalid_shipment["supply"]["orders"].append({
        "id": int(invalid_shipment["supply"]["next_id"]),
        "source_x": storage_cell.x, "source_y": storage_cell.y,
        "destination_x": granary_cell.x, "destination_y": granary_cell.y,
        "kind": "wood", "amount": 1, "cargo": 0, "status": "cancelled", "x": 0.0, "y": 0.0
    })
    invalid_shipment["supply"]["next_id"] = int(invalid_shipment["supply"]["next_id"]) + 1
    require(not save_system._valid_save(invalid_shipment),
        "Save validation must reject historical shipment records with resource types the Granary cannot store")
    require(save_system.save_current(true) and save_system.request_load(),
        "A Frontier campaign with Granary stock and pressure state must save and reload")
    await ticks(14)
    clock.set_process(false)
    var restored_frontier = get_first_node_in_group("main")
    require(restored_frontier != null, "Frontier reload must recreate the campaign")
    var loaded_granary = find_building("granary", granary_cell)
    require(loaded_granary != null and loaded_granary.stockpile_amount("food") == frontier_food_before_save,
        "Frontier reload must preserve Granary food without duplication or loss")
    require(restored_frontier.supply._pressure_records.has(pressure_key),
        "Save v17 must restore isolated Granary pressure state")

    print("PASS: Classic food reserve/upkeep, Frontier food-only depot transfers/shipments/raids and v13 migration compatibility")
    quit(0)
