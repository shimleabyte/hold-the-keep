extends SceneTree
## Phase 11.3 regression: rival workers gather real resource nodes and haul cargo home.

var failed := false


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

    var campaign: Node = main_scene.get("campaign")
    var keep: Node2D = campaign.call("current_target_node") as Node2D if campaign != null else null
    _check(keep != null, "Classic campaign must expose the rival stronghold")
    if keep == null:
        main_scene.queue_free()
        await process_frame
        quit(1)
        return

    var civilization: RefCounted = keep.get("civilization") as RefCounted
    _check(civilization != null, "Rival stronghold must own its civilization simulation")
    if civilization == null:
        main_scene.queue_free()
        await process_frame
        quit(1)
        return

    var navigation: Node = main_scene.get("nav")
    _check(navigation != null and int(navigation.get("version")) > 0,
        "Physical rival workers require an initialized navigation grid")
    var world: Node = main_scene.get("world")
    var generated_iron_nodes := 0
    for cell_value in world.get("resource_nodes_by_cell").keys():
        var resource_node: Node = world.call("resource_node_at", Vector2i(cell_value))
        if resource_node != null and is_instance_valid(resource_node) and String(resource_node.get("yield_kind")) == "iron" and int(resource_node.get("_hp")) > 0:
            generated_iron_nodes += 1
    _check(generated_iron_nodes > 0,
        "Classic world generation must instantiate live IronOre nodes for Tier II rival Forges")

    # The opening lumber camp is funded by the existing finite starting stock.
    # Advance the deterministic economy clock until the first workplace completes.
    for _tick in range(24):
        civilization.call("advance", 1.0)
    await process_frame

    _check(bool(civilization.call("_has_active_structure", "lumber_camp")),
        "Rival must complete the first Lumber Camp before assigning woodcutters")
    if not bool(civilization.call("_has_active_structure", "lumber_camp")):
        main_scene.queue_free()
        await process_frame
        quit(1)
        return

    var labor: Dictionary = civilization.call("labor_allocation")
    var assigned_slots := int(labor.get("lumber_camp", 0))
    var economic_workers: Array[Node] = []
    for worker: Node in get_nodes_in_group("enemy_economic_workers"):
        if is_instance_valid(worker) and worker.get("civilization") == civilization:
            economic_workers.append(worker)

    _check(assigned_slots > 0, "A completed Lumber Camp with free workforce must receive workers")
    _check(economic_workers.size() == assigned_slots,
        "Visible rival worker count must match the stronghold's derived labor assignment")

    var woodcutter: Node2D
    for worker: Node in economic_workers:
        if String(worker.get("role")) == "lumber_camp":
            woodcutter = worker as Node2D
            break
    _check(woodcutter != null, "Lumber Camp must spawn a visible woodcutter")
    if woodcutter == null:
        main_scene.queue_free()
        await process_frame
        quit(1)
        return

    _check(
        not woodcutter.is_in_group("villagers") and not woodcutter.is_in_group("enemy_garrison"),
        "Rival economic workers must remain separate from player civilians and military units"
    )

    # Wait for a real NavGrid reservation, then make that same cell player-owned
    # and contested while the worker is still travelling. Neither transition may
    # permit harvesting after the reservation was first accepted.
    var territory: Node = main_scene.get("territory")
    territory.call("rebuild")
    var reserved_target: Node2D
    for step in range(300):
        civilization.call("advance", 0.1)
        await physics_frame
        var candidate: Variant = woodcutter.get("_target")
        if candidate != null and is_instance_valid(candidate):
            reserved_target = candidate as Node2D
            if int(woodcutter.get("_state")) == 1:
                break
    _check(reserved_target != null and woodcutter.get("_target") == reserved_target,
        "A rival worker must reserve a real resource node before ownership-change checks")
    if reserved_target != null:
        _assert_cargo_capacity_guards(woodcutter, reserved_target)
        _assert_worker_rejects_territory(woodcutter, reserved_target, territory, "player")
        _check(bool(woodcutter.call("_find_resource_target")),
            "A worker must be able to retry a resource search after abandoning a newly player-owned target")
        var contested_target: Node2D = woodcutter.get("_target") as Node2D
        _check(contested_target != null,
            "A worker must acquire another valid node before contested-territory validation")
        if contested_target != null:
            _assert_worker_rejects_territory(woodcutter, contested_target, territory, "contested")

    # The same path can become unreachable after a reservation has been made.
    # Block all currently walkable approach cells, invalidate the NavGrid version,
    # and confirm the worker releases the node instead of remaining stuck on it.
    _check(bool(woodcutter.call("_find_resource_target")),
        "Worker must reacquire a valid target before the blocked-path regression")
    var blocked_target: Node2D = woodcutter.get("_target") as Node2D
    if blocked_target != null:
        var nav_astar: AStarGrid2D = navigation.get("astar") as AStarGrid2D
        var blocked_cells: Array[Vector2i] = []
        var blocked_origin: Vector2i = Vector2i(blocked_target.get("resource_cell"))
        for direction: Vector2i in [
            Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
        ]:
            var approach: Vector2i = blocked_origin + direction
            if bool(navigation.call("is_walkable", approach)):
                nav_astar.set_point_solid(approach, true)
                blocked_cells.append(approach)
        navigation.set("version", int(navigation.get("version")) + 1)
        woodcutter.call("tick", 0.1)
        _check(woodcutter.get("_target") == null and blocked_target.get("worker") != woodcutter,
            "An unreachable target must release its reservation and leave the worker retryable")
        for cell: Vector2i in blocked_cells:
            nav_astar.set_point_solid(cell, false)
        navigation.set("version", int(navigation.get("version")) + 1)
        civilization.call("advance", 2.0)
        await physics_frame
        _check(woodcutter.get("_target") != null,
            "A worker must retry target selection after the blocked route becomes reachable")

    var resource_before: float = float(civilization.get("resources").get("wood", 0.0))
    var saw_target_claim := false
    var saw_cargo := false

    # Simulate 120 seconds of worker time in small steps. The node claim is checked
    # while the worker travels and gathers, before cargo is transferred on save.
    for step in range(1200):
        if not is_instance_valid(woodcutter):
            break
        civilization.call("advance", 0.1)

        var target: Variant = woodcutter.get("_target")
        if target != null and is_instance_valid(target):
            saw_target_claim = target.get("worker") == woodcutter

        if int(woodcutter.get("carry")) > 0:
            saw_cargo = true
            break
        if step % 10 == 0:
            await process_frame

    _check(saw_target_claim, "Woodcutter must reserve a real resource node before working")
    _check(saw_cargo, "Woodcutter must collect resource-node yield into physical carried cargo")
    if not saw_cargo:
        main_scene.queue_free()
        await process_frame
        quit(1)
        return

    var carried_before_save := 0
    for worker: Node in economic_workers:
        if is_instance_valid(worker):
            carried_before_save += int(worker.get("carry"))
    _check(carried_before_save > 0, "At least one live worker must hold harvested cargo before save")

    var saved_state: Dictionary = civilization.call("export_state")
    var saved_resources: Dictionary = saved_state.get("resources", {})
    _check(float(saved_resources.get("wood", 0.0)) > resource_before,
        "Saving must atomically reconcile already-harvested cargo into the persistent stronghold ledger")

    var cargo_after_save := 0
    for worker: Node in economic_workers:
        if is_instance_valid(worker):
            cargo_after_save += int(worker.get("carry"))
    _check(cargo_after_save == 0,
        "Save reconciliation must clear transferred worker cargo to prevent duplicate delivery")

    var second_state: Dictionary = civilization.call("export_state")
    _check(
        is_equal_approx(
            float(second_state.get("resources", {}).get("wood", 0.0)),
            float(saved_resources.get("wood", 0.0))
        ),
        "Repeated save snapshots must not credit the same cargo twice"
    )

    # Exercise the normal delivery path separately from save-time reconciliation:
    # harvested cargo must be credited once to this worker's owning rival ledger.
    var delivery_before: float = float(civilization.get("resources").get("wood", 0.0))
    woodcutter.call("receive", "wood", 5)
    woodcutter.call("recall_to_keep")
    for step in range(800):
        civilization.call("advance", 0.1)
        if step % 5 == 0:
            await physics_frame
        if not is_instance_valid(woodcutter):
            break
    _check(not is_instance_valid(woodcutter),
        "A retiring worker must finish its return and leave after successful delivery")
    _check(float(civilization.get("resources").get("wood", 0.0)) >= delivery_before + 5.0,
        "Physical delivery must credit wood to the correct owning stronghold ledger")

    # Destroying a staffed workplace while its worker carries cargo must release
    # the current node reservation, return the cargo and remove the orphan actor.
    var lumber_camp: Node2D
    for structure: Node in civilization.get("structures"):
        if is_instance_valid(structure) and String(structure.get("structure_id")) == "lumber_camp":
            lumber_camp = structure as Node2D
            break
    var retiring_worker: Node2D
    for worker: Node in get_nodes_in_group("enemy_economic_workers"):
        if is_instance_valid(worker) and worker.get("civilization") == civilization and String(worker.get("role")) == "lumber_camp":
            retiring_worker = worker as Node2D
            break
    _check(lumber_camp != null and retiring_worker != null,
        "The workplace-destruction regression requires a live Lumber Camp worker")
    if lumber_camp != null and retiring_worker != null:
        retiring_worker.call("receive", "wood", 5)
        if retiring_worker.get("_target") == null:
            retiring_worker.call("_find_resource_target")
        var reserved_before_destroy: Variant = retiring_worker.get("_target")
        var destruction_delivery_before: float = float(civilization.get("resources").get("wood", 0.0))
        lumber_camp.call("take_damage", 9999)
        _check(bool(retiring_worker.get("retiring")),
            "Destroying a workplace must retire its assigned workers")
        if reserved_before_destroy != null and is_instance_valid(reserved_before_destroy):
            _check(reserved_before_destroy.get("worker") != retiring_worker,
                "Workplace destruction must release the worker's resource reservation immediately")
        for step in range(800):
            civilization.call("advance", 0.1)
            if step % 5 == 0:
                await physics_frame
            if not is_instance_valid(retiring_worker):
                break
        _check(not is_instance_valid(retiring_worker),
            "A worker whose workplace is destroyed must not remain orphaned")
        _check(float(civilization.get("resources").get("wood", 0.0)) >= destruction_delivery_before + 5.0,
            "A worker must deliver its already-carried cargo before retiring after workplace destruction")

    var save_system: Node = root.get_node("SaveSystem")
    var snapshot: Dictionary = save_system.call("collect", main_scene)
    _check(bool(save_system.call("_valid_save", snapshot)),
        "Physical worker cargo must remain compatible with additive v17 rival civilization saves")
    var save_version: int = int(save_system.get_script().get_script_constant_map().get("VERSION", 0))
    _check(save_version == 17,
        "Rival physical worker state must not require a save schema bump")

    main_scene.queue_free()
    await process_frame
    if failed:
        quit(1)
        return
    print("PASS: rival workforce spawning, resource-node reservation, physical harvesting, hauling cargo and v17 save reconciliation")
    quit()


func _assert_cargo_capacity_guards(worker: Node2D, target: Node2D) -> void:
    var original_hp := int(target.get("_hp"))
    var original_state := int(worker.get("_state"))
    var original_carry := int(worker.get("carry"))
    var original_kind := String(worker.get("carry_kind"))
    var original_timer := float(worker.get("_work_timer"))

    # The last wood hit includes the node's depletion bonus. Ten carried units
    # cannot retain that complete three-unit final hit in a twelve-unit load.
    target.set("_hp", 1)
    worker.set("carry", 10)
    worker.set("carry_kind", "wood")
    worker.set("_state", 2)
    worker.set("_work_timer", 3.0)
    worker.call("_tick_resource_work", 3.0)
    _check(int(target.get("_hp")) == 1 and int(worker.get("carry")) == 10,
        "A nearly full woodcutter must return before a final harvest that cannot fit")
    _check(int(worker.get("carry")) <= int(worker.get_script().get_script_constant_map().get("CARRY_CAPACITY", 0)),
        "Resource harvesting must never exceed configured worker cargo capacity")

    # A complete three-food farm cycle is atomic and must not start at ten cargo.
    worker.set("carry", 10)
    worker.set("carry_kind", "food")
    worker.set("_state", 3)
    worker.set("_work_timer", 4.8)
    worker.call("_tick_farming", 4.8)
    _check(int(worker.get("carry")) == 10,
        "A nearly full farmer must return before a farm cycle whose complete yield cannot fit")
    _check(int(worker.get("carry")) <= int(worker.get_script().get_script_constant_map().get("CARRY_CAPACITY", 0)),
        "Farm production must never exceed configured worker cargo capacity")

    # Restore the fixture so the ownership and lifecycle checks remain independent.
    target.set("_hp", original_hp)
    worker.set("carry", original_carry)
    worker.set("carry_kind", original_kind)
    worker.set("_state", original_state)
    worker.set("_work_timer", original_timer)
    worker.call("_release_target")


func _assert_worker_rejects_territory(
    worker: Node2D,
    target: Node2D,
    territory: Node,
    ownership: String
) -> void:
    var cell: Vector2i = Vector2i(target.get("resource_cell"))
    var player_claims: Dictionary = territory.get("claimed_cells")
    var enemy_claims: Dictionary = territory.get("enemy_claimed_cells")
    var had_player_claim := player_claims.has(cell)
    var had_enemy_claim := enemy_claims.has(cell)
    var hp_before: int = int(target.get("_hp"))

    player_claims[cell] = true
    if ownership == "player":
        enemy_claims.erase(cell)
    else:
        enemy_claims[cell] = true

    worker.call("tick", 0.1)
    _check(worker.get("_target") != target and target.get("worker") != worker,
        "A %s resource cell must cause the travelling rival worker to release its reservation" % ownership)
    _check(int(target.get("_hp")) == hp_before,
        "A rival worker must never harvest a %s resource cell" % ownership)

    if had_player_claim:
        player_claims[cell] = true
    else:
        player_claims.erase(cell)
    if had_enemy_claim:
        enemy_claims[cell] = true
    else:
        enemy_claims.erase(cell)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failed = true
    push_error("FAIL: " + message)
