extends SceneTree
## Region ownership, walkable roads, Keep-connected supply, and road save persistence.

func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func clear_claims(territory: Node) -> void:
    territory.claimed_cells.clear()
    territory.enemy_claimed_cells.clear()


func reference_region_ownership(territory: Node, world: Node, region_id: String) -> Dictionary:
    var counts := {
        "land_cells": 0,
        "player_cells": 0,
        "enemy_cells": 0,
        "contested_cells": 0
    }
    for y in world.map_size:
        for x in world.map_size:
            var cell := Vector2i(x, y)
            if not world.is_buildable(cell) or String(world.region_id(cell)) != region_id:
                continue
            counts["land_cells"] = int(counts["land_cells"]) + 1
            var player_owns: bool = territory.claimed_cells.has(cell)
            var enemy_owns: bool = territory.enemy_claimed_cells.has(cell)
            if player_owns:
                counts["player_cells"] = int(counts["player_cells"]) + 1
            if enemy_owns:
                counts["enemy_cells"] = int(counts["enemy_cells"]) + 1
            if player_owns and enemy_owns:
                counts["contested_cells"] = int(counts["contested_cells"]) + 1
    return counts


func reachable_cells(nav: Node, start: Vector2i) -> Dictionary:
    var visited: Dictionary = {}
    if not nav.is_walkable(start):
        return visited
    var queue: Array[Vector2i] = [start]
    visited[start] = true
    var cursor := 0
    while cursor < queue.size():
        var current := queue[cursor]
        cursor += 1
        for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
            var next: Vector2i = current + direction
            if visited.has(next) or not nav.is_walkable(next):
                continue
            visited[next] = true
            queue.append(next)
    return visited


func require(condition: bool, message: String) -> void:
    if not condition:
        push_error("FAIL: " + message)
        quit(1)
    assert(condition, message)


func require_flow_current(flow: Node, maximum_frames: int = 600) -> bool:
    var waited: int = 0
    while not flow.is_current() and waited < maximum_frames:
        await physics_frame
        waited += 1
    return flow.is_current()


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
    require(territory.region_ids().size() == 4,
        "Classic should expose its four regional ownership records")
    var hearthland: Dictionary = territory.get_region_state("HEARTHLAND")
    require(hearthland.has("land_cells") and hearthland.has("player_ratio")
        and hearthland.has("enemy_ratio") and hearthland.has("control"),
        "Regional ownership must report land area, ownership coverage and control")
    require(String(hearthland["control"]) == "player",
        "The Keep should establish control of the compact Classic Hearthland")
    var expected_hearthland: Dictionary = reference_region_ownership(territory, world, "HEARTHLAND")
    require(int(hearthland["land_cells"]) == int(expected_hearthland["land_cells"]),
        "Cached Hearthland land count must match an independent full-map count")

    var greenwood_cells: Array[Vector2i] = []
    for y in world_config_size():
        for x in world_config_size():
            var cell := Vector2i(x, y)
            if world.region_id(cell) == "GREENWOOD" and world.is_buildable(cell):
                greenwood_cells.append(cell)
    require(greenwood_cells.size() > 100,
        "Classic Greenwood needs enough land for regional control simulation")

    var saved_player_claims: Dictionary = territory.claimed_cells.duplicate()
    var saved_enemy_claims: Dictionary = territory.enemy_claimed_cells.duplicate()
    clear_claims(territory)
    territory._rebuild_region_states()
    require(String(territory.get_region_state("GREENWOOD")["control"]) == "neutral",
        "Unclaimed regions must remain neutral")

    var contest_count := ceili(float(greenwood_cells.size()) * 0.07)
    for i in contest_count:
        territory.claimed_cells[greenwood_cells[i]] = true
        territory.enemy_claimed_cells[greenwood_cells[i]] = true
    territory._rebuild_region_states()
    var contested_state: Dictionary = territory.get_region_state("GREENWOOD")
    require(String(contested_state["control"]) == "contested",
        "Overlapping hostile and player claims must mark a region contested")
    var expected_contested: Dictionary = reference_region_ownership(territory, world, "GREENWOOD")
    for count_key in ["land_cells", "player_cells", "enemy_cells", "contested_cells"]:
        require(int(contested_state[count_key]) == int(expected_contested[count_key]),
            "Cached regional %s must preserve player/enemy overlap accounting" % count_key)

    clear_claims(territory)
    var ownership_count := ceili(float(greenwood_cells.size()) * 0.36)
    for i in ownership_count:
        territory.claimed_cells[greenwood_cells[i]] = true
    territory._rebuild_region_states()
    require(String(territory.get_region_state("GREENWOOD")["control"]) == "player",
        "Sufficient player coverage must capture a region")

    clear_claims(territory)
    for i in ownership_count:
        territory.enemy_claimed_cells[greenwood_cells[i]] = true
    territory._rebuild_region_states()
    require(String(territory.get_region_state("GREENWOOD")["control"]) == "enemy",
        "Sufficient hostile coverage must capture a region")

    territory.claimed_cells = saved_player_claims
    territory.enemy_claimed_cells = saved_enemy_claims
    territory._rebuild_region_states()

    # Road tiles are ordinary claimed construction, but do not block pathfinding.
    inventory.items = {"wood": 1000, "stone": 500, "food": 500, "iron": 0}
    var keep_cell: Vector2i = world.starting_keep_cell()
    var road_a: Vector2i = keep_cell + Vector2i(2, 3)
    var road_b: Vector2i = road_a + Vector2i(0, 1)
    var road_c: Vector2i = road_a + Vector2i(-1, 1)
    require(main.build.check("road", road_a) == "",
        "A road should be buildable inside the Keep claim and player range")
    require(main.build.place("road", road_a) == "", "First road placement must succeed")
    require(main.build.place("road", road_b) == "", "Second road placement must succeed")
    require(main.build.place("road", road_c) == "", "Third road placement must succeed")
    for road_cell in [road_a, road_b, road_c]:
        var road_site = world.occupied[road_cell]
        require(road_site != null and road_site.is_in_group("construction_sites"),
            "Road orders must first create explicit blueprints")
        main.build.complete_site(road_site)
    await ticks(2)

    var road = world.occupied[road_a]
    require(road.is_in_group("roads") and road.is_in_group("buildings"),
        "Roads must remain registered as built infrastructure")
    main.nav.rebuild()
    require(main.nav.is_walkable(road_a),
        "Villagers must be able to walk across road tiles")
    main.flow.rebuild()
    require(await require_flow_current(main.flow),
        "The flow field must finish its expanded-map rebuild")
    require(main.flow.is_reachable(road_a),
        "Enemy flow routing must remain valid across road tiles")

    main.flow.rebuild()
    require(await require_flow_current(main.flow),
        "The flow field must be current before bridge-bank selection")
    var bridge_cell := Vector2i(-1, -1)
    var claimed_cells: Array = territory.claimed_cells.keys()
    var player_cell: Vector2i = main.nav.cell_of(main.player.global_position)
    var reachable_from_keep: Dictionary = reachable_cells(main.nav, player_cell)
    claimed_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
        var distance_a: float = Vector2(a - player_cell).length_squared()
        var distance_b: float = Vector2(b - player_cell).length_squared()
        return distance_a < distance_b
    )
    for candidate in claimed_cells:
        if not world.is_buildable(candidate) or world.occupied.has(candidate):
            continue
        var reachable_bank: Vector2i = Vector2i(-1, -1)
        for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
            var neighbor: Vector2i = candidate + direction
            if world.is_buildable(neighbor) and reachable_from_keep.has(neighbor) and main.flow.is_reachable(neighbor):
                reachable_bank = neighbor
                break
        if reachable_bank.x < 0:
            continue
        var original_tile: int = int(world.tile_type_at(candidate))
        world._layer.set_cell(candidate, 0, Vector2i(2, 0))
        # The enlarged Keep claim extends beyond the normal build radius. Move the
        # player to the reachable bank, then test the real bridge placement rules.
        main.player.global_position = main.nav.center_of(reachable_bank)
        if main.build.check("bridge", candidate) == "":
            bridge_cell = candidate
            break
        # This tile fails the real placement rules (for example, it overlaps the
        # player's footprint); restore it and continue to the next bank candidate.
        world._layer.set_cell(candidate, 0, Vector2i(original_tile, 0))
    require(bridge_cell.x >= 0,
        "The Keep claim must provide a water-bridge candidate accepted by the real build validator")
    require(world.is_bridgeable(bridge_cell),
        "Bridge fixtures must be water cells inside the map bounds")
    main.nav.rebuild()
    main.flow.rebuild()
    require(main.build.place("bridge", bridge_cell) == "",
        "A bridge must be constructible over claimed water")
    var bridge_site = world.occupied[bridge_cell]
    require(bridge_site != null and bridge_site.is_in_group("construction_sites"),
        "Bridge placement must create a blueprint before the bridge becomes traversable")
    main.build.complete_site(bridge_site)
    await ticks(2)
    main.nav.rebuild()
    require(main.nav.is_walkable(bridge_cell),
        "Villagers must be able to traverse a bridge over water")
    main.flow.rebuild()
    require(await require_flow_current(main.flow),
        "The flow field must finish rebuilding after bridge completion")
    require(main.flow.is_reachable(bridge_cell),
        "Enemy route fields must cross a built bridge")
    var storage: Node = main.build.place_raw("storage", road_c + Vector2i(-1, 0))
    await ticks(2)
    main.supply.rebuild()
    require(main.supply.connected_road_count() == 3,
        "All contiguous road tiles touching the Keep must enter its supply network")
    require(main.supply.is_road_connected(road_c),
        "A road at the end of a connected chain must reach the Keep")
    require(main.supply.is_depot_connected(storage),
        "A storage depot touching the connected road network must be supplied")
    require(main.supply.connected_depot_count() >= 2,
        "The Keep and linked storage must count as connected depots")
    require(bool(data_db.buildings["outpost"].get("depot", false)),
        "Forward Outposts must function as local depots")

    main.nav.rebuild()
    var reachable := reachable_cells(main.nav, main.nav.cell_of(main.player.global_position))
    var keep_center := Vector2(world.starting_keep_cell()) + Vector2(1.5, 1.5)
    var remote_outpost_cell := Vector2i(-1, -1)
    for y in range(2, world_config_size() - 3):
        for x in range(2, world_config_size() - 3):
            var anchor := Vector2i(x, y)
            if (Vector2(anchor) + Vector2.ONE).distance_to(keep_center) < 13.0:
                continue
            var clear := true
            for dy in 2:
                for dx in 2:
                    var cell := anchor + Vector2i(dx, dy)
                    if not world.is_buildable(cell) or world.occupied.has(cell):
                        clear = false
            if clear and reachable.has(anchor):
                remote_outpost_cell = anchor
                break
        if remote_outpost_cell.x >= 0:
            break
    require(remote_outpost_cell.x >= 0,
        "A remote clear footprint must exist for isolated Outpost testing")
    var remote_outpost = main.build.place_raw("outpost", remote_outpost_cell)
    await ticks(2)
    main.supply.rebuild()
    require(not main.supply.is_depot_connected(remote_outpost),
        "An isolated Outpost must not join the Keep's supply network")
    var courier = main.village.spawn_villager(remote_outpost.global_position + Vector2(32, 0))
    courier._go_depot()
    require(courier._depot != null and courier._depot != remote_outpost,
        "Workers must select a connected depot, not a closer isolated Outpost")

    courier._depot = remote_outpost
    courier.carry = 3
    courier.carry_kind = "wood"
    var inventory_before: int = inventory.get_amount("wood")
    courier._deposit()
    require(inventory.get_amount("wood") == inventory_before,
        "A worker must not credit global inventory through a disconnected depot")
    require(courier._depot != remote_outpost and courier.carry == 3,
        "A worker with a broken route must retain cargo and reroute to a connected depot")

    require(main.build.demolish_at(road_b),
        "Road infrastructure must be removable")
    main.supply.rebuild()
    require(not main.supply.is_road_connected(road_c),
        "A disconnected road branch must lose its Keep supply connection")
    require(not main.supply.is_depot_connected(storage),
        "A depot beyond a broken route must become disconnected")

    var snapshot: Dictionary = save_system.collect(main)
    var saved_road := false
    for building in snapshot["buildings"]:
        if String(building["id"]) == "road" and int(building["cx"]) == road_a.x:
            saved_road = true
    require(saved_road and save_system._valid_save(snapshot),
        "Road cells must survive in the generic building save payload")

    print("PASS: region neutral/player/enemy/contested states, walkable roads, supply connectivity, depot disconnection and road save")
    quit()


func world_config_size() -> int:
    return int(root.get_node("WorldConfig").map_size)
