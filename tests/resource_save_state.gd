extends SceneTree
## Resource depletion survives reload; corrupted primary save recovers from backup.

func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func _initialize() -> void:
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(4)
    GameClock.set_process(false)

    var nodes := {}
    var cells := {}
    for cell in main.world.occupied:
        var candidate = main.world.occupied[cell]
        if not is_instance_valid(candidate) or not candidate.has_method("export_state"):
            continue
        var kind := String(candidate.yield_kind)
        if not nodes.has(kind):
            nodes[kind] = candidate
            cells[kind] = cell
    assert(nodes.has("wood") and nodes.has("stone") and nodes.has("iron"),
        "Generated map must contain all three resource types")

    nodes["wood"].import_state({"hp": 0, "regrow": 17.5})
    nodes["stone"].import_state({"hp": 2, "regrow": 0.0})
    nodes["iron"].import_state({"hp": 0, "regrow": 54.0})
    assert(SaveSystem.save_current(true), "Initial resource save must succeed")

    # Write another valid save so the first save becomes the rollback copy.
    nodes["wood"].import_state({"hp": 2, "regrow": 0.0})
    nodes["stone"].import_state({"hp": 0, "regrow": 31.0})
    nodes["iron"].import_state({"hp": 3, "regrow": 0.0})
    assert(SaveSystem.save_current(true), "Second resource save must succeed")

    var broken = FileAccess.open("user://save.json", FileAccess.WRITE)
    assert(broken != null, "Primary save should be writable for corruption test")
    broken.store_string("{broken json")
    broken.close()

    assert(SaveSystem.request_load(), "Loader must recover from the valid backup")
    await ticks(4)
    var restored = current_scene
    for kind in ["wood", "stone", "iron"]:
        var cell: Vector2i = cells[kind]
        var node = restored.world.occupied.get(cell)
        assert(node != null and node.has_method("export_state"),
            "Resource node should be regenerated at deterministic cell: " + kind)
        var state: Dictionary = node.export_state()
        if kind == "wood":
            assert(int(state["hp"]) == 0 and is_equal_approx(float(state["regrow"]), 17.5),
                "Tree depletion and regrowth timer must restore from backup")
        elif kind == "stone":
            assert(int(state["hp"]) == 2 and is_equal_approx(float(state["regrow"]), 0.0),
                "Partially mined rock must restore from backup")
        else:
            assert(int(state["hp"]) == 0 and is_equal_approx(float(state["regrow"]), 54.0),
                "Iron vein depletion and regrowth timer must restore from backup")

    print("PASS: tree, rock, and iron resource state restore; damaged primary falls back to last good save")
    quit()
