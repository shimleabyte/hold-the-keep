extends SceneTree
## Phase 11.1 regression: rival structures survive occupied-footprint restoration.

var failed: bool = false


func _initialize() -> void:
    OS.set_environment("HTK_AUTO_START_GAME", "1")
    OS.set_environment("HTK_AUTO_RESOLVE_EVENTS", "1")
    await process_frame

    var main_scene := load("res://scenes/main.tscn").instantiate() as Node2D
    if main_scene == null:
        push_error("FAIL: Main scene could not be instantiated")
        quit(1)
        return
    root.add_child(main_scene)
    await process_frame
    await process_frame

    var world: WorldMap = main_scene.get("world") as WorldMap
    var campaign: Node = main_scene.get("campaign") as Node
    var save_system: Node = root.get_node("SaveSystem")
    var player: Node2D = main_scene.get("player") as Node2D
    var keep: EnemyKeep = campaign.call("current_target_node") as EnemyKeep
    _check(world != null and keep != null and player != null,
        "Classic persistence fixture must expose its WorldMap, player and active rival keep")
    if world == null or keep == null or player == null:
        main_scene.queue_free()
        await process_frame
        quit(1)
        return

    var current_civilization: RefCounted = keep.get("civilization") as RefCounted
    _check(current_civilization != null,
        "The active stronghold must expose its initialized civilization script")
    if current_civilization == null:
        main_scene.queue_free()
        await process_frame
        quit(1)
        return
    var civilization_script: Script = current_civilization.get_script()
    keep.set_process(false)
    var candidate_sites: Array[Vector2i] = _find_candidate_sites(world, keep, Vector2i(2, 2), 2)
    _check(candidate_sites.size() >= 2,
        "The rival region must expose two non-overlapping build sites for restore recovery")
    if candidate_sites.size() < 2:
        main_scene.queue_free()
        await process_frame
        quit(1)
        return

    var original_occupancy: Dictionary = world.occupied.duplicate()
    var saved_anchor: Vector2i = candidate_sites[0]
    var saved_record: Dictionary = {"id": "lumber_camp", "cx": saved_anchor.x, "cy": saved_anchor.y, "hp": 123}

    # A player-owned object can occupy a previously valid rival structure footprint
    # before the campaign is reconstructed. The loader must relocate rather than drop it.
    world.occupied[saved_anchor] = player
    var fallback_civilization: RefCounted = civilization_script.new() as RefCounted
    fallback_civilization.call("setup", keep, _saved_civilization_state(saved_record))
    var fallback_structures: Array = fallback_civilization.get("structures")
    _check(fallback_structures.size() == 1,
        "A blocked saved structure must be restored at a deterministic alternate site")
    if fallback_structures.size() == 1:
        var relocated: Node = fallback_structures[0]
        var relocated_cell: Vector2i = relocated.get("cell")
        _check(relocated_cell != saved_anchor,
            "A relocated rival structure must not overwrite the player-owned blocker")
        _check(int(relocated.get("hp")) == 123,
            "Relocation must preserve the saved structure HP")
        var exported_relocation: Dictionary = fallback_civilization.call("export_state")
        var exported_records: Array = exported_relocation.get("structures", [])
        _check(exported_records.size() == 1 and Vector2i(
            int(exported_records[0].get("cx", -1)),
            int(exported_records[0].get("cy", -1))
        ) == relocated_cell, "The relocated coordinates must become the new persisted structure position")
    fallback_civilization.call("on_keep_destroyed")
    world.occupied = original_occupancy.duplicate()

    # Remove every available cell in this rival region. An unplaceable but valid
    # structure must remain serialized as pending state, not disappear.
    for y: int in range(1, world.map_size - 1):
        for x: int in range(1, world.map_size - 1):
            var cell := Vector2i(x, y)
            if world.is_buildable(cell) and String(world.region_id(cell)) == keep.region_id:
                world.occupied[cell] = player

    var pending_civilization: RefCounted = civilization_script.new() as RefCounted
    pending_civilization.call("setup", keep, _saved_civilization_state(saved_record))
    var pending_state: Dictionary = pending_civilization.call("export_state")
    var pending_values: Array = pending_state.get("pending_structures", [])
    _check(pending_values.size() == 1,
        "When no legal site exists, the saved rival structure must remain in pending restore state")
    _check(bool(pending_civilization.call("_has_structure", "lumber_camp")),
        "Pending structures must count as existing so the build plan cannot duplicate them")

    # A second civilization instance simulates a save/load round trip while the
    # original site is still blocked. The pending record must survive unchanged.
    var reloaded_civilization: RefCounted = civilization_script.new() as RefCounted
    reloaded_civilization.call("setup", keep, pending_state)
    var reloaded_state: Dictionary = reloaded_civilization.call("export_state")
    var reloaded_pending: Array = reloaded_state.get("pending_structures", [])
    _check(reloaded_pending.size() == 1,
        "A second restore must preserve rival structures that are still blocked")
    if reloaded_pending.size() == 1:
        _check(reloaded_pending[0] == pending_values[0],
            "Pending structure ID, original cell and HP must survive serialization exactly")

    var snapshot: Dictionary = save_system.call("collect", main_scene)
    var objective_records: Array = snapshot["campaign"]["objectives"]
    var assigned_pending_state := false
    for objective: Dictionary in objective_records:
        if String(objective.get("id", "")) == keep.stronghold_id:
            objective["civilization"] = reloaded_state.duplicate(true)
            assigned_pending_state = true
            break
    _check(assigned_pending_state and bool(save_system.call("_valid_save", snapshot)),
        "The v17 validator must accept a well-formed pending rival structure record")

    var invalid_pending_snapshot: Dictionary = snapshot.duplicate(true)
    for objective: Dictionary in invalid_pending_snapshot["campaign"]["objectives"]:
        if String(objective.get("id", "")) == keep.stronghold_id:
            objective["civilization"]["pending_structures"][0]["hp"] = 999999
            break
    _check(not bool(save_system.call("_valid_save", invalid_pending_snapshot)),
        "The v17 validator must reject malformed pending structure HP")

    # A v17 save created before rival civilization data existed remains valid.
    var legacy_v17: Dictionary = snapshot.duplicate(true)
    for objective: Dictionary in legacy_v17["campaign"]["objectives"]:
        objective.erase("civilization")
    _check(bool(save_system.call("_valid_save", legacy_v17)),
        "Existing v17 campaigns without an additive civilization record must remain valid")

    # Free one legal site and simulate the next bounded economy tick. The pending
    # structure should be restored, retain HP and leave the pending queue.
    world.occupied = original_occupancy.duplicate()
    world.occupied[saved_anchor] = player
    reloaded_civilization.call("_restore_pending_structures")
    var restored_structures: Array = reloaded_civilization.get("structures")
    var remaining_pending: Array = reloaded_civilization.get("pending_structures")
    _check(restored_structures.size() == 1 and remaining_pending.is_empty(),
        "A pending rival structure must retry and restore once a valid site becomes available")
    if restored_structures.size() == 1:
        var restored_structure: Node = restored_structures[0]
        _check(int(restored_structure.get("hp")) == 123,
            "Retry restoration must preserve the original structure HP")
        _check(Vector2i(restored_structure.get("cell")) != saved_anchor,
            "Retry restoration must avoid the still-blocked original footprint")

    fallback_civilization.call("on_keep_destroyed")
    pending_civilization.call("on_keep_destroyed")
    reloaded_civilization.call("on_keep_destroyed")
    await process_frame
    world.occupied = original_occupancy
    main_scene.queue_free()
    await process_frame

    if failed:
        quit(1)
        return
    print("PASS: rival structure relocation, pending restore persistence/retry, v17 validation and legacy compatibility")
    quit()


func _find_candidate_sites(world: WorldMap, keep: EnemyKeep, footprint: Vector2i, desired_count: int) -> Array[Vector2i]:
    var candidates: Array[Vector2i] = []
    for radius: int in range(4, 15):
        for y: int in range(-radius, radius + 1):
            for x: int in range(-radius, radius + 1):
                if maxi(absi(x), absi(y)) != radius:
                    continue
                var anchor: Vector2i = keep.cell + Vector2i(x, y)
                var clear := true
                for fy: int in footprint.y:
                    for fx: int in footprint.x:
                        var cell: Vector2i = anchor + Vector2i(fx, fy)
                        if not world.is_buildable(cell) or world.occupied.has(cell) or String(world.region_id(cell)) != keep.region_id:
                            clear = false
                            break
                    if not clear:
                        break
                if not clear:
                    continue
                var overlaps_existing := false
                for existing: Vector2i in candidates:
                    if anchor.x < existing.x + footprint.x and anchor.x + footprint.x > existing.x and anchor.y < existing.y + footprint.y and anchor.y + footprint.y > existing.y:
                        overlaps_existing = true
                        break
                if overlaps_existing:
                    continue
                candidates.append(anchor)
                if candidates.size() >= desired_count:
                    return candidates
    return candidates


func _saved_civilization_state(structure: Dictionary) -> Dictionary:
    return {
        "resources": {"wood": 100.0, "stone": 42.0, "food": 65.0, "iron": 4.0},
        "structures": [structure.duplicate(true)],
        "technology_tier": 0,
        "research_progress": 0.0,
        "build_order_index": 0,
        "construction": {},
        "tick_accumulator": 0.0,
        "active": true
    }


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failed = true
    push_error("FAIL: " + message)
