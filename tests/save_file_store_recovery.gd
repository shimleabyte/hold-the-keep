extends SceneTree
## SaveFileStore: atomic replacement, backup preservation and failed-write safety.

const STORE_SCRIPT := preload("res://scripts/persistence/save_file_store.gd")

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var world_config = root.get_node("WorldConfig")
    var save_system = root.get_node("SaveSystem")
    world_config.apply_profile("classic")

    for path in [
        "user://save_store_primary.json",
        "user://save_store_temp.json",
        "user://save_store_backup.json"
    ]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await _ticks(6)
    root.get_node("GameClock").set_process(false)

    var store = STORE_SCRIPT.new()
    store.configure(save_system._validator)
    var primary := "user://save_store_primary.json"
    var temp := "user://save_store_temp.json"
    var backup := "user://save_store_backup.json"

    var original: Dictionary = save_system.collect(main)
    var replacement: Dictionary = original.duplicate(true)
    replacement["clock"]["day"] = int(original["clock"]["day"]) + 1

    _require(store.write_snapshot(original, primary, temp, backup),
        "A valid initial snapshot must install")
    _require(_snapshot_matches(store.read_snapshot(primary, false), original),
        "The installed primary must contain the initial snapshot")

    _require(store.write_snapshot(replacement, primary, temp, backup),
        "A valid replacement must install")
    _require(_snapshot_matches(store.read_snapshot(primary, false), replacement),
        "The replacement must become the primary snapshot")
    _require(_snapshot_matches(store.read_snapshot(backup, false), original),
        "The previous verified primary must become the rollback backup")
    _require(not FileAccess.file_exists(temp),
        "Successful replacement must not leave a temporary file")

    # A corrupt primary must never cause a known-good backup to be discarded.
    var corrupt := FileAccess.open(primary, FileAccess.WRITE)
    _require(corrupt != null, "The corruption fixture must be writable")
    if corrupt != null:
        corrupt.store_string("{not valid JSON")
        corrupt.close()
    _require(store.read_snapshot(primary, false) == null,
        "A corrupt primary must be rejected")
    _require(_snapshot_matches(store.read_snapshot(backup, false), original),
        "The known-good backup must remain readable beside a corrupt primary")

    var recovered_replacement: Dictionary = replacement.duplicate(true)
    recovered_replacement["clock"]["day"] = int(replacement["clock"]["day"]) + 1
    _require(store.write_snapshot(recovered_replacement, primary, temp, backup),
        "A new valid snapshot must replace a corrupt primary")
    _require(_snapshot_matches(store.read_snapshot(primary, false), recovered_replacement),
        "The new snapshot must become primary after corrupt-primary recovery")
    _require(_snapshot_matches(store.read_snapshot(backup, false), original),
        "Replacing a corrupt primary must preserve the existing verified backup")

    # Invalid serialized data must fail before touching either durable copy.
    var invalid: Dictionary = recovered_replacement.duplicate(true)
    invalid["version"] = save_system.VERSION + 1
    _require(not store.write_snapshot(invalid, primary, temp, backup),
        "A snapshot with an unsupported schema version must not be installed")
    _require(_snapshot_matches(store.read_snapshot(primary, false), recovered_replacement),
        "Rejected data must leave the current primary unchanged")
    _require(_snapshot_matches(store.read_snapshot(backup, false), original),
        "Rejected data must leave the rollback backup unchanged")
    _require(not FileAccess.file_exists(temp),
        "Rejected data must clean up its temporary file")

    # An unavailable temp destination simulates a failure before replacement.
    var impossible_temp := "user://missing_save_store_directory/temp.json"
    _require(not store.write_snapshot(replacement, primary, impossible_temp, backup),
        "Failure to create the temporary file must abort the write")
    _require(_snapshot_matches(store.read_snapshot(primary, false), recovered_replacement),
        "A pre-install write failure must preserve the primary")
    _require(_snapshot_matches(store.read_snapshot(backup, false), original),
        "A pre-install write failure must preserve the rollback backup")

    main.queue_free()
    await _ticks(2)
    for path in [primary, temp, backup]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

    if failures.is_empty():
        print("PASS: SaveFileStore atomic replacement, rollback preservation and failed-write safety")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)



func _snapshot_matches(actual: Variant, expected: Dictionary) -> bool:
    if not actual is Dictionary:
        return false
    var actual_clock: Variant = actual.get("clock", {})
    var expected_clock: Variant = expected.get("clock", {})
    var actual_world: Variant = actual.get("world", {})
    var expected_world: Variant = expected.get("world", {})
    var actual_inventory: Variant = actual.get("inventory", {})
    var expected_inventory: Variant = expected.get("inventory", {})
    if not actual_clock is Dictionary or not expected_clock is Dictionary:
        return false
    if not actual_world is Dictionary or not expected_world is Dictionary:
        return false
    if not actual_inventory is Dictionary or not expected_inventory is Dictionary:
        return false
    if int(actual.get("version", 0)) != int(expected.get("version", 0)):
        return false
    if int(actual_clock.get("day", 0)) != int(expected_clock.get("day", 0)):
        return false
    if not is_equal_approx(float(actual_clock.get("time_of_day", 0.0)),
            float(expected_clock.get("time_of_day", 0.0))):
        return false
    for key in ["profile", "map_size", "tile_size", "seed"]:
        if actual_world.get(key) != expected_world.get(key):
            return false
    for resource in ["wood", "stone", "food", "iron"]:
        if int(actual_inventory.get(resource, 0)) != int(expected_inventory.get(resource, 0)):
            return false
    return true


func _ticks(count: int) -> void:
    for _index in count:
        await physics_frame


func _require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
