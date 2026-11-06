extends SceneTree
## Smoke-tests the first RTS command layer in the real main scene.

var failed := false


func _initialize() -> void:
    await process_frame
    var main_scene: Variant = load("res://scenes/main.tscn").instantiate()
    root.add_child(main_scene)
    await process_frame
    await process_frame

    var commander = main_scene.get_node_or_null("RTSCommand")
    _check(commander != null, "Main scene should install the RTS command controller")
    if commander == null:
        quit(1)
        return

    _check(commander.camera != null and commander.camera.is_current(),
        "RTS camera should be current and independent of the legacy player")
    _check(not main_scene.player.visible, "Legacy player avatar should be hidden in RTS mode")
    _check(not main_scene.player.is_physics_processing(),
        "Legacy direct movement should be disabled in RTS mode")

    var units := get_nodes_in_group("villagers")
    _check(not units.is_empty(), "New campaign should create selectable villagers")
    if units.is_empty():
        quit(1)
        return

    var unit = units[0]
    var state_constants: Dictionary = unit.get_script().get_script_constant_map().get("State", {})
    commander.select_unit(unit)
    _check(commander.selected_units.size() == 1 and commander.selected_units[0] == unit,
        "Single-unit selection should update the current selection")

    var reachable: Dictionary = main_scene.nav.reachable_cells(main_scene.nav.cell_of(unit.global_position))
    var goal_cell := Vector2i(-1, -1)
    for cell_value in reachable:
        var cell: Vector2i = cell_value
        if Vector2(cell - main_scene.nav.cell_of(unit.global_position)).length() >= 5.0:
            goal_cell = cell
            break
    _check(goal_cell.x >= 0, "Test fixture should find a reachable movement destination")
    if goal_cell.x >= 0:
        var goal: Vector2 = main_scene.nav.center_of(goal_cell)
        var issued: int = commander.issue_move_order(goal)
        _check(issued == 1, "Selected villager should accept a reachable move order")
        _check(int(unit.state) == int(state_constants.get("MANUAL_MOVE", -1)),
            "A move order should enter the explicit manual movement state")
        var origin: Vector2 = unit.global_position
        await create_timer(0.35).timeout
        _check(unit.global_position.distance_to(origin) > 0.1,
            "Villager should move after receiving a move order")

    _check(commander.issue_move_order(Vector2(-1000.0, -1000.0)) == 0 and commander.selected_units.size() == 1,
        "An order outside the map should not crash or clear selection")

    var resource_target: Node2D = null
    for value in get_nodes_in_group("harvestable"):
        if not is_instance_valid(value) or not value.visible or not value.is_available(unit):
            continue
        var resource_cells: Array[Vector2i] = [main_scene.nav.cell_of(value.global_position)]
        if main_scene.nav.path_adjacent(unit.global_position, resource_cells).is_empty():
            continue
        resource_target = value as Node2D
        break
    _check(resource_target != null, "New campaign should expose a reachable harvestable resource")
    if resource_target != null:
        _check(unit.issue_gather_order(resource_target),
            "A villager should accept a direct resource-gathering order")
        var to_work_state: int = int(state_constants.get("TO_WORK", -1))
        _check(unit.target == resource_target and int(unit.state) == to_work_state,
            "A direct gathering order should claim the resource and enter its work route")

    var soldier = units[0]
    _check(soldier.set_job("soldier"), "A villager should be convertible to a soldier")
    var stronghold = main_scene.campaign.current_target_node()
    _check(stronghold != null, "The campaign should expose a current enemy stronghold")
    if stronghold != null:
        _check(soldier.issue_attack_order(stronghold),
            "A selected soldier should accept a direct stronghold attack order")
        var fight_state: int = int(state_constants.get("FIGHT", -1))
        _check(int(soldier.state) == fight_state,
            "A direct attack order should enter the combat state")

    main_scene.queue_free()
    await process_frame
    if failed:
        quit(1)
        return
    print("PASS: RTS camera, villager selection, movement, gathering and soldier attack orders")
    quit()


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failed = true
    push_error("FAIL: " + message)
