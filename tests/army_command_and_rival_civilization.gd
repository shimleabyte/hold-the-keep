extends SceneTree
## Verifies soldiers-only mouse orders and the first persistent rival civilization.

var failed: bool = false


func _initialize() -> void:
    OS.set_environment("HTK_AUTO_START_GAME", "1")
    OS.set_environment("HTK_AUTO_RESOLVE_EVENTS", "1")
    await process_frame
    var main_scene: HoldTheKeepMain = load("res://scenes/main.tscn").instantiate() as HoldTheKeepMain
    root.add_child(main_scene)
    await process_frame
    await process_frame

    var commander: ArmyCommand = main_scene.army_command
    _check(commander != null, "Main scene must install the army command manager")
    if commander == null:
        quit(1)
        return

    _check(main_scene.player.visible, "The direct-control player avatar must remain visible")
    _check(main_scene.player.is_physics_processing(), "The direct-control player must retain physics input")
    _check(main_scene.player.camera != null and main_scene.player.camera.is_current(),
        "The direct-control player's camera must remain current")

    var units: Array[Node] = get_nodes_in_group("villagers")
    _check(units.size() >= 2, "Classic campaign should create starting villagers")
    if units.size() < 2:
        quit(1)
        return

    var worker: Villager = units[0] as Villager
    _check(String(worker.job) != "soldier", "Starting civilian should remain an autonomous worker")
    commander.select_unit(worker)
    _check(commander.selected_units.is_empty(), "Civilian workers must not be selectable by the army command manager")

    _check(worker.set_job("soldier"), "Worker should be convertible to a soldier for command testing")
    commander.select_unit(worker)
    _check(commander.selected_units.size() == 1 and commander.selected_units[0] == worker,
        "A soldier should be selectable")
    var state_constants: Dictionary = worker.get_script().get_script_constant_map().get("State", {})

    var start_cell: Vector2i = main_scene.nav.cell_of(worker.global_position)
    var reachable: Dictionary = main_scene.nav.reachable_cells(start_cell)
    var destination_cell: Vector2i = Vector2i(-1, -1)
    for cell_value: Vector2i in reachable.keys():
        var cell: Vector2i = cell_value
        if Vector2(cell - start_cell).length() >= 5.0 and main_scene.nav.is_walkable(cell):
            destination_cell = cell
            break
    _check(destination_cell.x >= 0, "Army movement fixture must find a reachable destination")
    if destination_cell.x >= 0:
        var destination: Vector2 = main_scene.nav.center_of(destination_cell)
        _check(commander.issue_move_order(destination) == 1, "One selected soldier should receive a move order")
        _check(int(worker.state) == int(state_constants.get("MANUAL_MOVE", -1)),
            "A move order should enter the explicit manual-move state")

    var stronghold: EnemyKeep = main_scene.campaign.current_target_node() as EnemyKeep
    _check(stronghold != null, "Classic campaign should expose its rival stronghold")
    if stronghold != null:
        commander.select_unit(worker)
        _check(commander.issue_attack_order(stronghold) == 1,
            "A selected soldier should accept an attack order against the enemy stronghold")
        _check(int(worker.state) == int(state_constants.get("FIGHT", -1)),
            "A stronghold attack order should enter the existing combat state")
        _check(worker._manual_attack_target == stronghold,
            "A soldier must retain the commander-selected target rather than reacquiring a random enemy")

        var civilization: EnemyCivilization = stronghold.civilization
        _check(civilization != null, "Every enemy stronghold should own an autonomous civilization")
        if civilization != null:
            var starting_wood: float = float(civilization.resources.get("wood", 0.0))
            _check(starting_wood > 0.0, "Rival civilization should start with a finite resource ledger")
            for tick: int in range(270):
                civilization.advance(1.0)
            _check(civilization._has_structure("lumber_camp"),
                "Rival civilization should construct a visible lumber camp")
            _check(civilization._has_structure("farm"),
                "Rival civilization should construct food infrastructure")
            _check(civilization._has_structure("quarry"),
                "Rival civilization should construct a stone and iron source")
            _check(civilization._has_structure("barracks"),
                "Rival civilization should eventually invest in military production")
            _check(civilization.technology_tier >= 1,
                "Rival civilization should advance technology after meeting prerequisites")
            _check(not civilization.structures.is_empty(),
                "Completed rival structures should exist as world entities")
            var snapshot: Dictionary = stronghold.export_state()
            var saved_civ: Dictionary = snapshot.get("civilization", {})
            _check(saved_civ is Dictionary and saved_civ.get("structures", []) is Array,
                "Stronghold state must persist the rival economy and completed structures")
            _check(float(civilization.resources.get("wood", 0.0)) <= 999.0,
                "Rival resource stock must remain bounded")

            if not civilization.structures.is_empty():
                var structure: EnemySettlementStructure = civilization.structures[0]
                var occupied_cell: Vector2i = structure.cell
                structure.take_damage(9999)
                _check(not main_scene.world.occupied.has(occupied_cell),
                    "Destroying a rival structure must release its world footprint")

    # The command layer must not have reassigned the other civilian worker.
    var remaining_workers: Array[Node] = get_nodes_in_group("villagers")
    var civilian_count: int = 0
    for unit_node: Node in remaining_workers:
        var unit: Villager = unit_node as Villager
        if unit != worker and String(unit.job) != "soldier":
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
