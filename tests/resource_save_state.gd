extends SceneTree
## Resource depletion survives reload; corrupted primary save recovers from backup.

func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func _initialize() -> void:
    var game_clock = root.get_node("GameClock")
    var save_system = root.get_node("SaveSystem")
    DirAccess.remove_absolute("user://save.json")
    DirAccess.remove_absolute("user://save.tmp")
    DirAccess.remove_absolute("user://save.bak")
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(4)
    game_clock.set_process(false)

    var valid_shape := {
        "version": 2,
        "inventory": {"wood": 25},
        "clock": {"t": 0.0, "day": 1, "night": false},
        "player": {"x": 0.0, "y": 0.0, "hp": 100},
        "buildings": [{"id": "keep", "cx": 31, "cy": 29, "hp": 1000}],
        "villagers": [{"x": 0.0, "y": 0.0, "job": "woodcutter", "hp": 100, "carry": 0, "kind": "wood"}],
        "enemies": [],
        "quota": {"woodcutter": 1},
        "spawner": {},
        "tech": {},
        "resources": []
    }
    assert(save_system._valid_save(valid_shape), "A complete save structure should validate")
    var missing_carry := valid_shape.duplicate(true)
    missing_carry["villagers"][0].erase("carry")
    assert(not save_system._valid_save(missing_carry),
        "Save validation must reject villagers missing fields consumed by the loader")
    var invalid_resources := valid_shape.duplicate(true)
    invalid_resources["resources"] = [{"cx": 4, "cy": 5, "kind": "wood", "state": "not a dictionary"}]
    assert(not save_system._valid_save(invalid_resources),
        "Save validation must reject malformed resource state")
    var invalid_cleared_resource := valid_shape.duplicate(true)
    invalid_cleared_resource["resources"] = [{
        "cx": 4, "cy": 5, "kind": "wood",
        "state": {"hp": 0, "regrow": 0.0, "cleared": "yes"}
    }]
    assert(not save_system._valid_save(invalid_cleared_resource),
        "Save validation must reject a non-boolean cleared-resource marker")

    var nodes := {}
    var cells := {}
    for cell in main.world.occupied:
        var candidate = main.world.occupied[cell]
        if not is_instance_valid(candidate) or not candidate.is_in_group("resource_nodes") or not candidate.has_method("export_state"):
            continue
        var kind := String(candidate.yield_kind)
        if not nodes.has(kind):
            nodes[kind] = candidate
            cells[kind] = cell
    assert(nodes.has("wood") and nodes.has("stone") and nodes.has("iron") and nodes.has("food"),
        "Generated map must contain wood, stone, iron and wildlife food resources")

    nodes["wood"].import_state({"hp": 0, "regrow": 17.5})
    nodes["stone"].import_state({"hp": 2, "regrow": 0.0})
    nodes["iron"].import_state({"hp": 0, "regrow": 54.0})
    nodes["food"].import_state({"hp": 0, "regrow": 63.0})
    assert(nodes["wood"].is_processing() and not nodes["stone"].is_processing()
        and nodes["iron"].is_processing() and nodes["food"].is_processing(),
        "Only depleted resource nodes should process their regrowth timers")
    main.nav.rebuild()
    for kind in ["stone", "iron", "food"]:
        var residue = nodes[kind]
        assert(residue.is_in_group("clearable_resource_residues"),
            "%s should expose its depleted remains for player cleanup" % kind)
        assert(residue.clear_residue(), "%s residue should be removable" % kind)
        assert(residue.is_cleared() and not residue.visible and residue.collision_layer == 0,
            "%s cleanup must hide the residue and disable its collision" % kind)
        assert(not main.world.occupied.has(cells[kind]),
            "%s cleanup must free the tile for construction" % kind)
        await ticks(1)
        assert(main.nav.is_walkable(cells[kind]),
            "%s cleanup must release the tile in worker navigation" % kind)
        residue.import_state({"hp": 0, "regrow": 17.0})
        await ticks(1)
        assert(not main.nav.is_walkable(cells[kind]),
            "%s restoration must restore its navigation blocker" % kind)

    # The player uses the normal interact/work animation to clear a depleted tree stump.
    main.player.global_position = nodes["wood"].global_position
    main.player._try_interact()
    assert(main.player._pending_harvest == nodes["wood"],
        "Interact should select a nearby depleted stump as a cleanup target")
    main.player._tick_pending(0.2)
    assert(nodes["wood"].is_cleared() and not main.world.occupied.has(cells["wood"]),
        "Completing the interact action must remove stump collision and free its tile")
    await ticks(1)
    assert(main.nav.is_walkable(cells["wood"]),
        "Player cleanup must also release the stump tile in worker navigation")
    assert(save_system.save_current(true), "Initial resource save must persist a cleared stump")

    # Write another valid save so the first save becomes the rollback copy.
    nodes["wood"].import_state({"hp": 2, "regrow": 0.0})
    nodes["stone"].import_state({"hp": 0, "regrow": 31.0})
    nodes["iron"].import_state({"hp": 3, "regrow": 0.0})
    nodes["food"].import_state({"hp": 2, "regrow": 0.0})
    assert(not nodes["wood"].is_processing() and nodes["stone"].is_processing()
        and not nodes["iron"].is_processing() and not nodes["food"].is_processing(),
        "Every resource type must switch processing off when healthy and on when depleted")
    assert(save_system.save_current(true), "Second resource save must succeed")

    var broken = FileAccess.open("user://save.json", FileAccess.WRITE)
    assert(broken != null, "Primary save should be writable for corruption test")
    broken.store_string("{broken json")
    broken.close()

    assert(save_system.request_load(), "Loader must recover from the valid backup")
    await ticks(4)
    var restored = current_scene
    for kind in ["wood", "stone", "iron", "food"]:
        var cell: Vector2i = cells[kind]
        var node = restored.world.resource_node_at(cell)
        assert(node != null and node.has_method("export_state"),
            "Resource node should be addressable at its deterministic cell: " + kind)
        var state: Dictionary = node.export_state()
        if kind == "wood":
            assert(int(state["hp"]) == 0 and bool(state.get("cleared", false))
                and is_zero_approx(float(state["regrow"])),
                "Cleared stump state must restore from backup without a regrowth timer")
            assert(not node.is_processing() and not node.visible and node.collision_layer == 0,
                "A restored cleared stump must stay invisible and non-blocking")
            assert(not restored.world.occupied.has(cell),
                "A restored cleared stump must leave the tile available for building")
        elif kind == "stone":
            assert(int(state["hp"]) == 2 and is_equal_approx(float(state["regrow"]), 0.0),
                "Partially mined rock must restore from backup")
            assert(not node.is_processing(),
                "A restored healthy rock must not receive idle process callbacks")
        elif kind == "iron":
            assert(int(state["hp"]) == 0 and absf(float(state["regrow"]) - 54.0) < 0.2,
                "Iron vein depletion and regrowth timer must restore from backup")
            assert(node.is_processing(),
                "A restored depleted iron node must resume its regrowth timer")
        else:
            assert(int(state["hp"]) == 0 and absf(float(state["regrow"]) - 63.0) < 0.2,
                "Wildlife depletion and regrowth timer must restore from backup")
            assert(node.is_processing(),
                "A restored depleted wildlife node must resume its regrowth timer")

    print("PASS: tree, rock, iron and wildlife state restore; damaged primary falls back to last good save")
    quit()
