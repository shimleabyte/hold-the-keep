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
    var resource_before: float = float(civilization.get("resources").get("wood", 0.0))
    var saw_target_claim := false
    var saw_cargo := false

    # Simulate 120 seconds of worker time in small steps. The node claim is checked
    # while the worker travels and gathers, before cargo is transferred on save.
    for step in range(1200):
        if not is_instance_valid(woodcutter):
            break
        woodcutter.call("tick", 0.1)

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


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failed = true
    push_error("FAIL: " + message)
