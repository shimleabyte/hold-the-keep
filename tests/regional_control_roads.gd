extends SceneTree
## Region ownership, walkable roads, Keep-connected supply, and road save persistence.

func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func clear_claims(territory: Node) -> void:
    territory.claimed_cells.clear()
    territory.enemy_claimed_cells.clear()


func _initialize() -> void:
    var inventory = root.get_node("Inventory")
    var game_clock = root.get_node("GameClock")
    var save_system = root.get_node("SaveSystem")
    var data_db = root.get_node("DataDB")

    DirAccess.remove_absolute("user://save.json")
    DirAccess.remove_absolute("user://save.tmp")
    DirAccess.remove_absolute("user://save.bak")

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(5)
    game_clock.set_process(false)

    var territory = main.territory
    var world = main.world
    assert(territory.region_ids().size() == 4,
        "Classic should expose its four regional ownership records")
    var hearthland: Dictionary = territory.get_region_state("HEARTHLAND")
    assert(hearthland.has("land_cells") and hearthland.has("player_ratio")
        and hearthland.has("enemy_ratio") and hearthland.has("control"),
        "Regional ownership must report land area, ownership coverage and control")
    assert(String(hearthland["control"]) == "player",
        "The Keep should establish control of the compact Classic Hearthland")

    var greenwood_cells: Array[Vector2i] = []
    for y in world_config_size():
        for x in world_config_size():
            var cell := Vector2i(x, y)
            if world.region_id(cell) == "GREENWOOD" and world.is_buildable(cell):
                greenwood_cells.append(cell)
    assert(greenwood_cells.size() > 100,
        "Classic Greenwood needs enough land for regional control simulation")

    var saved_player_claims: Dictionary = territory.claimed_cells.duplicate()
    var saved_enemy_claims: Dictionary = territory.enemy_claimed_cells.duplicate()
    clear_claims(territory)
    territory._rebuild_region_states()
    assert(String(territory.get_region_state("GREENWOOD")["control"]) == "neutral",
        "Unclaimed regions must remain neutral")

    var contest_count := ceili(float(greenwood_cells.size()) * 0.07)
    for i in contest_count:
        territory.claimed_cells[greenwood_cells[i]] = true
        territory.enemy_claimed_cells[greenwood_cells[i]] = true
    territory._rebuild_region_states()
    assert(String(territory.get_region_state("GREENWOOD")["control"]) == "contested",
        "Overlapping hostile and player claims must mark a region contested")

    clear_claims(territory)
    var ownership_count := ceili(float(greenwood_cells.size()) * 0.36)
    for i in ownership_count:
        territory.claimed_cells[greenwood_cells[i]] = true
    territory._rebuild_region_states()
    assert(String(territory.get_region_state("GREENWOOD")["control"]) == "player",
        "Sufficient player coverage must capture a region")

    clear_claims(territory)
    for i in ownership_count:
        territory.enemy_claimed_cells[greenwood_cells[i]] = true
    territory._rebuild_region_states()
    assert(String(territory.get_region_state("GREENWOOD")["control"]) == "enemy",
        "Sufficient hostile coverage must capture a region")

    territory.claimed_cells = saved_player_claims
    territory.enemy_claimed_cells = saved_enemy_claims
    territory._rebuild_region_states()

    # Road tiles are ordinary claimed construction, but do not block pathfinding.
    inventory.items = {"wood": 1000, "stone": 500, "food": 500, "iron": 0}
    var road_a := Vector2i(32, 32)
    var road_b := Vector2i(32, 33)
    var road_c := Vector2i(31, 33)
    assert(main.build.check("road", road_a) == "",
        "A road should be buildable inside the Keep claim and player range")
    assert(main.build.place("road", road_a) == "", "First road placement must succeed")
    assert(main.build.place("road", road_b) == "", "Second road placement must succeed")
    assert(main.build.place("road", road_c) == "", "Third road placement must succeed")
    await ticks(2)

    var road = world.occupied[road_a]
    assert(road.is_in_group("roads") and road.is_in_group("buildings"),
        "Roads must remain registered as built infrastructure")
    main.nav.rebuild()
    assert(main.nav.is_walkable(road_a),
        "Villagers must be able to walk across road tiles")
    main.flow.rebuild()
    assert(main.flow.is_reachable(road_a),
        "Enemy flow routing must remain valid across road tiles")

    var bridge_cell := Vector2i(-1, -1)
    for y in range(1, world_config_size() - 1):
        for x in range(1, world_config_size() - 1):
            var cell := Vector2i(x, y)
            if world.is_bridgeable(cell) and territory.is_claimed(cell)
                and not world.occupied.has(cell)
                and main.build.check("bridge", cell) == "":
                bridge_cell = cell
                break
        if bridge_cell.x >= 0:
            break
    assert(bridge_cell.x >= 0,
        "The starting claim must expose a safe reachable water cell for bridge construction")
    assert(main.build.place("bridge", bridge_cell) == "",
        "A bridge must be constructible over claimed water")
    await ticks(2)
    main.nav.rebuild()
    assert(main.nav.is_walkable(bridge_cell),
        "Villagers must be able to traverse a bridge over water")
    main.flow.rebuild()
    assert(main.flow.is_reachable(bridge_cell),
        "Enemy route fields must cross a built bridge")
    var storage = main.build.place_raw("storage", Vector2i(29, 34))
    await ticks(2)
    main.supply.rebuild()
    assert(main.supply.connected_road_count() == 3,
        "All contiguous road tiles touching the Keep must enter its supply network")
    assert(main.supply.is_road_connected(road_c),
        "A road at the end of a connected chain must reach the Keep")
    assert(main.supply.is_depot_connected(storage),
        "A storage depot touching the connected road network must be supplied")
    assert(main.supply.connected_depot_count() >= 2,
        "The Keep and linked storage must count as connected depots")
    assert(bool(data_db.buildings["outpost"].get("depot", false)),
        "Forward Outposts must function as local depots")

    main.nav.rebuild()
    var remote_outpost_cell := Vector2i(-1, -1)
    for y in range(34, 44):
        for x in range(36, 48):
            var anchor := Vector2i(x, y)
            var clear := true
            for dy in 2:
                for dx in 2:
                    var cell := anchor + Vector2i(dx, dy)
                    if not world.is_buildable(cell) or world.occupied.has(cell):
                        clear = false
            var approach := Vector2(anchor) * 16.0 + Vector2(8.0, 8.0)
            if clear and not main.nav.path_to(approach, world.starting_keep_cell()).is_empty():
                remote_outpost_cell = anchor
                break
        if remote_outpost_cell.x >= 0:
            break
    assert(remote_outpost_cell.x >= 0,
        "A remote clear footprint must exist for isolated Outpost testing")
    var remote_outpost = main.build.place_raw("outpost", remote_outpost_cell)
    await ticks(2)
    main.supply.rebuild()
    assert(not main.supply.is_depot_connected(remote_outpost),
        "An isolated Outpost must not join the Keep's supply network")
    var courier = main.village.spawn_villager(remote_outpost.global_position + Vector2(32, 0))
    courier._go_depot()
    assert(courier._depot != null and courier._depot != remote_outpost,
        "Workers must select a connected depot, not a closer isolated Outpost")

    courier._depot = remote_outpost
    courier.carry = 3
    courier.carry_kind = "wood"
    var inventory_before: int = inventory.get_amount("wood")
    courier._deposit()
    assert(inventory.get_amount("wood") == inventory_before,
        "A worker must not credit global inventory through a disconnected depot")
    assert(courier._depot != remote_outpost and courier.carry == 3,
        "A worker with a broken route must retain cargo and reroute to a connected depot")

    assert(main.build.demolish_at(road_b),
        "Road infrastructure must be removable")
    main.supply.rebuild()
    assert(not main.supply.is_road_connected(road_c),
        "A disconnected road branch must lose its Keep supply connection")
    assert(not main.supply.is_depot_connected(storage),
        "A depot beyond a broken route must become disconnected")

    var snapshot: Dictionary = save_system.collect(main)
    var saved_road := false
    for building in snapshot["buildings"]:
        if String(building["id"]) == "road" and int(building["cx"]) == road_a.x:
            saved_road = true
    assert(saved_road and save_system._valid_save(snapshot),
        "Road cells must survive in the generic building save payload")

    print("PASS: region neutral/player/enemy/contested states, walkable roads, supply connectivity, depot disconnection and road save")
    quit()


func world_config_size() -> int:
    return int(root.get_node("WorldConfig").map_size)
