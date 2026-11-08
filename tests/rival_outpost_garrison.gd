extends SceneTree
## Verifies that rival outposts become defended forward positions without free units.

var failed := false


func _initialize() -> void:
    OS.set_environment("HTK_AUTO_START_GAME", "1")
    OS.set_environment("HTK_AUTO_RESOLVE_EVENTS", "1")
    call_deferred("_run")


func _run() -> void:
    var world_config: Node = root.get_node("WorldConfig")
    world_config.call("apply_profile", "frontier")
    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)

    var main = load("res://scenes/main.tscn").instantiate()
    if main == null:
        _check(false, "Main scene must instantiate for the rival outpost fixture")
        quit(1)
        return
    root.add_child(main)
    current_scene = main
    await _ticks(10)

    var flow_wait := 0
    while not main.flow.is_current() and flow_wait < 600:
        await physics_frame
        flow_wait += 1
    _check(main.flow.is_current(), "The initial Frontier flow field must be ready before the garrison fixture")
    if not main.flow.is_current():
        main.queue_free()
        await process_frame
        quit(1)
        return

    var keep := main.campaign.current_target_node() as Node2D
    _check(keep != null, "The Frontier campaign must expose its current rival stronghold")
    if keep == null:
        main.queue_free()
        await process_frame
        quit(1)
        return

    var civilization = keep.get("civilization")
    _check(civilization != null, "The stronghold must own its rival civilization")
    if civilization == null:
        main.queue_free()
        await process_frame
        quit(1)
        return

    keep.set_process(false)
    main.spawner.set_process(false)
    main.spawner.set_physics_process(false)
    main.territory.rebuild()

    var initial_home_guards: Array = keep.call("_local_garrison")
    _check(initial_home_guards.size() == 3, "A new rival stronghold must begin with its three existing defenders")
    if initial_home_guards.size() < 3:
        main.queue_free()
        await process_frame
        quit(1)
        return

    var outpost_anchor := _find_outpost_anchor(main, keep)
    _check(outpost_anchor.x >= 0, "The stronghold's region must contain a legal neutral frontier outpost site")
    if outpost_anchor.x < 0:
        main.queue_free()
        await process_frame
        quit(1)
        return

    _check(bool(civilization.call("_spawn_structure", "outpost", outpost_anchor)),
        "The rival civilization must register a completed outpost for the forward-defense fixture")
    await _ticks(2)
    main.territory.rebuild()

    var outpost: Node2D
    for structure: Node in civilization.get("structures"):
        if is_instance_valid(structure) and String(structure.get("structure_id")) == "outpost":
            outpost = structure as Node2D
            break
    _check(outpost != null, "The completed outpost must be present in the owning civilization's structure list")
    if outpost == null:
        main.queue_free()
        await process_frame
        quit(1)
        return

    keep.call("_sync_outpost_garrisons")
    var forward_guards: Array = keep.call("_guards_at_origin", outpost.position)
    var home_guards: Array = keep.call("_local_garrison")
    _check(forward_guards.size() == 1, "Each unguarded outpost must receive one existing stronghold defender")
    _check(home_guards.size() == 2, "Outpost deployment must preserve a two-guard home minimum")
    _check(int(keep.call("total_garrison_count")) == 3,
        "Redeploying a guard must not create a free unit or increase the total garrison")
    if forward_guards.size() != 1:
        main.queue_free()
        await process_frame
        quit(1)
        return

    var labor: Dictionary = civilization.call("labor_allocation")
    _check(int(labor.get("garrison", -1)) == 3,
        "Outpost defenders must count toward the same civilian workforce and soldier upkeep")
    _check(int(labor.get("available", -1)) == int(civilization.call("workforce_for_garrison", 3)),
        "A redeployed guard must consume the same workforce position as a home defender")

    var save_system: Node = root.get_node("SaveSystem")
    var snapshot: Dictionary = save_system.call("collect", main)
    var saved_forward_guard: Dictionary = {}
    for enemy_state: Dictionary in snapshot.get("enemies", []):
        if not bool(enemy_state.get("garrison", false)):
            continue
        var saved_origin := Vector2(
            float(enemy_state.get("guard_x", 0.0)),
            float(enemy_state.get("guard_y", 0.0))
        )
        if saved_origin.distance_squared_to(outpost.position) < 1.0:
            saved_forward_guard = enemy_state.duplicate(true)
            break
    _check(not saved_forward_guard.is_empty(),
        "The existing guard-origin save fields must preserve an outpost defender's post")
    _check(bool(save_system.call("_valid_save", snapshot)),
        "A save containing a rival outpost garrison must remain valid under schema v17")

    # Recreate the saved unit through the production restore path. Its post assignment
    # is inferred from its persisted guard origin and the restored outpost structure.
    var original_guard: Node = forward_guards[0]
    original_guard.call("retreat")
    await process_frame
    main.spawner.call("restore_enemy", saved_forward_guard)
    await process_frame
    var restored_forward_guards: Array = keep.call("_guards_at_origin", outpost.position)
    _check(restored_forward_guards.size() == 1,
        "A save/load restore must reattach the guard to its outpost without new save fields")
    if restored_forward_guards.size() == 1:
        _check(String(restored_forward_guards[0].get("id")) == String(saved_forward_guard.get("id")),
            "The restored outpost defender must preserve its faction-native unit type")

    # Destroying the post must send the defender home, not delete it or strand it.
    outpost.call("take_damage", 99999)
    await _ticks(2)
    var returned_guards: Array = keep.call("_local_garrison")
    _check(returned_guards.size() == 3,
        "A destroyed outpost must return its defender to the stronghold garrison")
    _check(int(keep.call("total_garrison_count")) == 3,
        "Outpost destruction must conserve the stronghold's total military population")

    var after_loss: Dictionary = save_system.call("collect", main)
    _check(bool(save_system.call("_valid_save", after_loss)),
        "The post-loss guard position must remain valid in a schema-v17 save")
    var saved_home_guard_count := 0
    for enemy_state: Dictionary in after_loss.get("enemies", []):
        if bool(enemy_state.get("garrison", false)):
            var saved_origin := Vector2(
                float(enemy_state.get("guard_x", 0.0)),
                float(enemy_state.get("guard_y", 0.0))
            )
            if saved_origin.distance_squared_to(keep.position) < 1.0:
                saved_home_guard_count += 1
    _check(saved_home_guard_count == 3,
        "The save must persist returned defenders at the stronghold rather than the destroyed outpost")

    main.queue_free()
    await process_frame
    if failed:
        quit(1)
        return
    print("PASS: rival outpost defense, shared garrison/workforce, fallback and v17 save restoration")
    quit()


func _find_outpost_anchor(main: Variant, keep: Node2D) -> Vector2i:
    var world_config: Node = root.get_node("WorldConfig")
    var footprint := Vector2i(2, 2)
    for radius in range(1, 28):
        for y in range(-radius, radius + 1):
            for x in range(-radius, radius + 1):
                if maxi(absi(x), absi(y)) != radius:
                    continue
                var anchor: Vector2i = Vector2i(keep.get("cell")) + Vector2i(x, y)
                var valid := true
                for fy in footprint.y:
                    for fx in footprint.x:
                        var cell := anchor + Vector2i(fx, fy)
                        if not bool(world_config.call("is_valid_cell", cell)) or not main.world.is_buildable(cell):
                            valid = false
                            break
                        if main.world.occupied.has(cell):
                            valid = false
                            break
                        if String(main.world.region_id(cell)) != String(keep.get("region_id")):
                            valid = false
                            break
                    if not valid:
                        break
                if valid and bool(main.territory.call("can_enemy_place_outpost", anchor, footprint)):
                    return anchor
    return Vector2i(-1, -1)


func _ticks(count: int) -> void:
    for _index in count:
        await physics_frame


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failed = true
    push_error("FAIL: " + message)
