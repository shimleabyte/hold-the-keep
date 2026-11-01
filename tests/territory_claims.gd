extends SceneTree
## Regression checks for Keep claims and frontier expansion through Outposts.

func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


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
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(4)
    game_clock.set_process(false)
    main.build.player = null
    inventory.items = {"wood": 500, "stone": 500, "food": 500, "iron": 0}
    main.territory.rebuild()

    assert(main.territory.claimed_cells.size() > 250,
        "Keep should claim a meaningful starting area")
    assert(main.territory.is_claimed(Vector2i(31, 29)),
        "Keep footprint must be claimed")
    assert(not main.territory.can_place("outpost", Vector2i(35, 29), Vector2i(2, 2)),
        "Outposts must not be placed wholly inside already-owned territory")

    var outside := Vector2i(-1, -1)
    for y in range(4, 60):
        for x in range(4, 60):
            var c := Vector2i(x, y)
            if not main.territory.is_claimed(c) and footprint_clear(main, c, Vector2i(2, 2)):
                outside = c
                break
        if outside.x >= 0:
            break
    assert(outside.x >= 0, "Test needs a free unclaimed footprint")
    assert(main.build.check("house", outside) == "Di luar wilayah. Bangun Pos Terdepan di perbatasan",
        "Ordinary buildings must be rejected outside owned territory")

    var outpost_cell := Vector2i(-1, -1)
    var expansion_target := Vector2i(-1, -1)
    for y in range(12, 52):
        for x in range(12, 52):
            var c := Vector2i(x, y)
            var target := c + Vector2i(8, 0)
            var center := Vector2(c) + Vector2.ONE
            var keep_center := Vector2(32.5, 30.5)
            if center.distance_to(keep_center) < 7.0 or center.distance_to(keep_center) > 10.5:
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
    main.territory.rebuild()
    assert(main.territory.is_claimed(expansion_target),
        "Outpost must claim tiles beyond the Keep frontier")
    assert(main.territory.can_place("house", expansion_target, Vector2i(2, 2)),
        "Newly claimed land should accept ordinary buildings")

    assert(main.build.demolish_at(outpost_cell), "Outpost should be demolishable")
    main.territory.rebuild()
    assert(not main.territory.is_claimed(expansion_target),
        "Removing Outpost must release its exclusive claim")

    print("PASS: Keep claims, build restriction, Outpost frontier placement, expansion, and claim release")
    quit()
