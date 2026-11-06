extends SceneTree
## Regression checks for Keep claims and frontier expansion through Outposts.

func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func reference_land_counts(world: Node) -> Dictionary:
    var counts: Dictionary = {}
    for y in world.map_size:
        for x in world.map_size:
            var cell := Vector2i(x, y)
            if not world.is_buildable(cell):
                continue
            var region := String(world.region_id(cell))
            counts[region] = int(counts.get(region, 0)) + 1
    return counts


func footprint_clear(main, anchor: Vector2i, size: Vector2i) -> bool:
    for y in range(size.y):
        for x in range(size.x):
            var cell := anchor + Vector2i(x, y)
            if not main.world.is_buildable(cell) or main.world.occupied.has(cell):
                return false
    return true


func _initialize() -> void:
    var game_clock = root.get_node("GameClock")
    var inventory = root.get_node("Inventory")
    var world_config: Node = root.get_node("WorldConfig")
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(4)
    game_clock.set_process(false)
    main.build.player = null
    inventory.items = {"wood": 500, "stone": 500, "food": 500, "iron": 0}
    assert(main.world.region_land_counts == reference_land_counts(main.world),
        "Classic regional land counts must match generated buildable terrain")
    var initial_land_counts: Dictionary = main.world.region_land_counts.duplicate(true)
    main.territory.rebuild()

    assert(main.territory.claimed_cells.size() > 250,
        "Keep should claim a meaningful starting area")
    var keep_cell: Vector2i = main.world.starting_keep_cell()
    assert(main.territory.is_claimed(keep_cell),
        "Keep footprint must be claimed")
    assert(not main.territory.can_place("outpost", keep_cell + Vector2i(7, 0), Vector2i(2, 2)),
        "Outposts must not be placed wholly inside already-owned territory")

    var outside := Vector2i(-1, -1)
    for y: int in range(4, int(world_config.get("map_size")) - 4):
        for x: int in range(4, int(world_config.get("map_size")) - 4):
            var c: Vector2i = Vector2i(x, y)
            if not main.territory.is_claimed(c) and footprint_clear(main, c, Vector2i(2, 2)):
                outside = c
                break
        if outside.x >= 0:
            break
    assert(outside.x >= 0, "Test needs a free unclaimed footprint")
    assert(main.build.check("house", outside) == "Di luar wilayah. Bangun Pos Terdepan di perbatasan",
        "Ordinary buildings must be rejected outside owned territory")

    var outpost_cell: Vector2i = Vector2i(-1, -1)
    var expansion_target: Vector2i = Vector2i(-1, -1)
    var keep_center: Vector2 = Vector2(keep_cell) + Vector2(1.5, 1.5)
    var frontier_radius: float = float(world_config.get("starting_claim_radius"))
    var search_min: int = maxi(2, floori(frontier_radius - 3.0))
    var search_max: int = ceili(frontier_radius + 6.0)
    for y: int in range(maxi(2, keep_cell.y - search_max), mini(int(world_config.get("map_size")) - 2, keep_cell.y + search_max)):
        for x: int in range(maxi(2, keep_cell.x - search_max), mini(int(world_config.get("map_size")) - 2, keep_cell.x + search_max)):
            var c := Vector2i(x, y)
            var target: Vector2i = c + Vector2i(8, 0)
            var center: Vector2 = Vector2(c) + Vector2.ONE
            var distance_to_keep: float = center.distance_to(keep_center)
            if distance_to_keep < float(search_min) or distance_to_keep > float(search_max):
                continue
            if main.territory.is_claimed(target) or not footprint_clear(main, c, Vector2i(2, 2)):
                continue
            if not footprint_clear(main, target, Vector2i(2, 2)):
                continue
            if main.territory.can_place("outpost", c, Vector2i(2, 2)):
                outpost_cell = c
                expansion_target = target
                break
        if outpost_cell.x >= 0:
            break
    assert(outpost_cell.x >= 0, "Test needs a clear Outpost position on the frontier")

    var result: String = main.build.place("outpost", outpost_cell)
    assert(result == "", "Outpost placement failed: " + result)
    var outpost_site = main.world.occupied.get(outpost_cell)
    assert(outpost_site != null and outpost_site.is_in_group("construction_sites"),
        "Outpost placement must create a blueprint rather than instant infrastructure")
    var outpost = main.build.complete_site(outpost_site)
    assert(outpost != null and outpost.is_in_group("buildings"),
        "A completed Outpost blueprint must become functional infrastructure")
    main.territory.rebuild()
    assert(main.world.region_land_counts == initial_land_counts,
        "Building an Outpost must not change terrain-only regional land counts")
    assert(main.territory.is_claimed(expansion_target),
        "Outpost must claim tiles beyond the Keep frontier")
    assert(main.territory.can_place("house", expansion_target, Vector2i(2, 2)),
        "Newly claimed land should accept ordinary buildings")

    assert(main.build.demolish_at(outpost_cell), "Outpost should be demolishable")
    main.territory.rebuild()
    assert(main.world.region_land_counts == initial_land_counts,
        "Demolishing an Outpost must not change terrain-only regional land counts")
    assert(not main.territory.is_claimed(expansion_target),
        "Removing Outpost must release its exclusive claim")

    print("PASS: Keep claims, build restriction, Outpost frontier placement, expansion, and claim release")
    quit()
