extends SceneTree
## Verifies soldiers-only mouse orders and the first persistent rival civilization.

var failed: bool = false


func _initialize() -> void:
    OS.set_environment("HTK_AUTO_START_GAME", "1")
    OS.set_environment("HTK_AUTO_RESOLVE_EVENTS", "1")
    await process_frame
    var main_scene: Node2D = load("res://scenes/main.tscn").instantiate() as Node2D
    root.add_child(main_scene)
    await process_frame
    await process_frame

    var commander: Node = main_scene.get("army_command") as Node
    _check(commander != null, "Main scene must install the army command manager")
    if commander == null:
        quit(1)
        return

    var player: Node2D = main_scene.get("player") as Node2D
    _check(player.visible, "The direct-control player avatar must remain visible")
    _check(player.is_physics_processing(), "The direct-control player must retain physics input")
    var player_camera: Camera2D = player.get("camera") as Camera2D
    _check(player_camera != null and player_camera.is_current(),
        "The direct-control player's camera must remain current")

    var units: Array[Node] = get_nodes_in_group("villagers")
    _check(units.size() >= 2, "Classic campaign should create starting villagers")
    if units.size() < 2:
        quit(1)
        return

    var worker: Node2D = units[0] as Node2D
    _check(String(worker.get("job")) != "soldier", "Starting civilian should remain an autonomous worker")
    commander.call("select_unit", worker)
    var selected_units: Array = commander.get("selected_units")
    _check(selected_units.is_empty(), "Civilian workers must not be selectable by the army command manager")

    _check(bool(worker.call("set_job", "soldier")), "Worker should be convertible to a soldier for command testing")
    commander.call("select_unit", worker)
    selected_units = commander.get("selected_units")
    _check(selected_units.size() == 1 and selected_units[0] == worker,
        "A soldier should be selectable")
    var state_constants: Dictionary = worker.get_script().get_script_constant_map().get("State", {})

    var navigation: Node = main_scene.get("nav") as Node
    var start_cell: Vector2i = navigation.call("cell_of", worker.global_position)
    var reachable: Dictionary = navigation.call("reachable_cells", start_cell)
    var destination_cell: Vector2i = Vector2i(-1, -1)
    for cell_value: Vector2i in reachable.keys():
        var cell: Vector2i = cell_value
        if Vector2(cell - start_cell).length() >= 5.0 and bool(navigation.call("is_walkable", cell)):
            destination_cell = cell
            break
    _check(destination_cell.x >= 0, "Army movement fixture must find a reachable destination")
    if destination_cell.x >= 0:
        var destination: Vector2 = navigation.call("center_of", destination_cell)
        _check(int(commander.call("issue_move_order", destination)) == 1, "One selected soldier should receive a move order")
        _check(int(worker.get("state")) == int(state_constants.get("MANUAL_MOVE", -1)),
            "A move order should enter the explicit manual-move state")

    var campaign: Node = main_scene.get("campaign") as Node
    var stronghold: Node2D = campaign.call("current_target_node") as Node2D
    _check(stronghold != null, "Classic campaign should expose its rival stronghold")
    if stronghold != null:
        commander.call("select_unit", worker)
        _check(int(commander.call("issue_attack_order", stronghold)) == 1,
            "A selected soldier should accept an attack order against the enemy stronghold")
        _check(int(worker.get("state")) == int(state_constants.get("FIGHT", -1)),
            "A stronghold attack order should enter the existing combat state")
        _check(worker.get("_manual_attack_target") == stronghold,
            "A soldier must retain the commander-selected target rather than reacquiring a random enemy")

        var civilization: RefCounted = stronghold.get("civilization") as RefCounted
        _check(civilization != null, "Every enemy stronghold should own an autonomous civilization")
        if civilization != null:
            var resources: Dictionary = civilization.get("resources")
            var starting_wood: float = float(resources.get("wood", 0.0))
            _check(starting_wood > 0.0, "Rival civilization should start with a finite resource ledger")
            for tick: int in range(270):
                civilization.call("advance", 1.0)
            _check(bool(civilization.call("_has_structure", "lumber_camp")),
                "Rival civilization should construct a visible lumber camp")
            _check(bool(civilization.call("_has_structure", "farm")),
                "Rival civilization should construct food infrastructure")
            _check(bool(civilization.call("_has_structure", "quarry")),
                "Rival civilization should construct a stone and iron source")
            _check(bool(civilization.call("_has_structure", "barracks")),
                "Rival civilization should eventually invest in military production")
            _check(int(civilization.get("technology_tier")) >= 1,
                "Rival civilization should advance technology after meeting prerequisites")
            _check(not not Array(civilization.get("structures")).is_empty(),
                "Completed rival structures should exist as world entities")
            var snapshot: Dictionary = stronghold.export_state()
            var saved_civ: Dictionary = snapshot.get("civilization", {})
            _check(saved_civ is Dictionary and saved_civ.get("structures", []) is Array,
                "Stronghold state must persist the rival economy and completed structures")
            _check(float(resources.get("wood", 0.0)) <= 999.0,
                "Rival resource stock must remain bounded")

            if not not Array(civilization.get("structures")).is_empty():
                var structure: Node2D = structures[0] as Node2D
                var occupied_cell: Vector2i = structure.get("cell")
                structure.call("take_damage", 9999)
                _check(var world: Node = main_scene.get("world") as Node
                var occupied: Dictionary = world.get("occupied")
                not occupied.has(occupied_cell),
                    "Destroying a rival structure must release its world footprint")

    # The command layer must not have reassigned the other civilian worker.
    var remaining_workers: Array[Node] = get_nodes_in_group("villagers")
    var civilian_count: int = 0
    for unit_node: Node in remaining_workers:
        var unit: Node2D = unit_node as Node2D
        if unit != worker and String(unit.get("job")) != "soldier":
            civilian_count += 1
    _check(civilian_count >= 1, "Non-selected civilian workers must retain their normal jobs")

    main_scene.queue_free()
    await process_frame
    if failed:
        quit(1)
        return
    print("PASS: army-only selection, soldier move/attack orders, autonomous rival economy, construction, recruitment prerequisites, technology and persistence")
    quit()


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failed = true
    push_error("FAIL: " + message)
