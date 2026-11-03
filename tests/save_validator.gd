extends SceneTree
## SaveValidator contract: facade parity, schema bounds, optional v17 state and purity.

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var world_config = root.get_node("WorldConfig")
    var game_clock = root.get_node("GameClock")
    var save_system = root.get_node("SaveSystem")
    world_config.apply_profile("classic")

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await _ticks(6)
    game_clock.set_process(false)

    var validator = save_system._validator
    _require(validator != null, "SaveSystem must own a dedicated SaveValidator instance")
    var snapshot: Dictionary = save_system.collect(main)
    _require(int(snapshot.get("version", 0)) == save_system.VERSION,
        "Collected snapshots must use the SaveSystem-owned schema version")
    _require(validator.is_valid_save(snapshot),
        "The dedicated validator must accept a current Classic snapshot")
    _require(save_system._valid_save(snapshot) == validator.is_valid_save(snapshot),
        "The existing SaveSystem validation entry point must delegate without changing behavior")

    var encoded_snapshot := JSON.stringify(snapshot)
    var decoded_snapshot: Variant = JSON.parse_string(encoded_snapshot)
    _require(decoded_snapshot is Dictionary and validator.is_valid_save(decoded_snapshot),
        "The validator must accept a JSON encode/decode round-trip of a current snapshot")

    var legacy_v17 := snapshot.duplicate(true)
    legacy_v17.erase("events")
    _require(validator.is_valid_save(legacy_v17),
        "The additive decision-event state must remain optional for existing v17 saves")

    var unsupported_version := snapshot.duplicate(true)
    unsupported_version["version"] = save_system.VERSION + 1
    _require(not validator.is_valid_save(unsupported_version),
        "Unknown future schema versions must be rejected")

    var invalid_version := snapshot.duplicate(true)
    invalid_version["version"] = 0
    _require(not validator.is_valid_save(invalid_version),
        "A missing/zero schema version must be rejected")

    var invalid_inventory := snapshot.duplicate(true)
    invalid_inventory["inventory"] = []
    _require(not validator.is_valid_save(invalid_inventory),
        "The validator must reject a snapshot with the wrong inventory root type")

    var invalid_world := snapshot.duplicate(true)
    invalid_world["world"]["profile"] = "unknown_profile"
    _require(not validator.is_valid_save(invalid_world),
        "The validator must reject unknown world profile identifiers")

    var invalid_campaign := snapshot.duplicate(true)
    invalid_campaign["campaign"].erase("order")
    _require(not validator.is_valid_save(invalid_campaign),
        "The validator must reject a campaign snapshot missing its required objective order")

    var invalid_events := snapshot.duplicate(true)
    invalid_events["events"]["pending_event_id"] = "missing_event_definition"
    _require(not validator.is_valid_save(invalid_events),
        "The validator must reject event-state references that cannot be resolved")

    var invalid_fog := snapshot.duplicate(true)
    invalid_fog["fog"]["cells"].append(int(snapshot["world"]["map_size"]) * int(snapshot["world"]["map_size"]))
    _require(not validator.is_valid_save(invalid_fog),
        "The validator must reject fog indices outside the saved world bounds")

    _require(JSON.stringify(snapshot) == encoded_snapshot,
        "Validation must not mutate the supplied snapshot")

    main.queue_free()
    await _ticks(2)
    if failures.is_empty():
        print("PASS: SaveValidator facade parity, v17 optional state, schema bounds, nested contracts and non-mutating validation")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)


func _ticks(count: int) -> void:
    for _index in count:
        await physics_frame


func _require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
