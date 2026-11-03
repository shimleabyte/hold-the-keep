extends SceneTree

var world_config
var game_clock
var save_system

## Release hardening: historical save schemas, interrupted writes and export presets.


func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func _fixture_for_version(source: Dictionary, target_version: int) -> Dictionary:
    var fixture: Dictionary = source.duplicate(true)
    fixture["version"] = target_version

    if target_version < 14:
        fixture["quota"].erase("hunter")
        if fixture.has("job_priority"):
            fixture["job_priority"].erase("hunter")
        for villager in fixture["villagers"]:
            if String(villager.get("job", "")) == "hunter":
                villager["job"] = ""
            if String(villager.get("occupation", "")) == "hunter":
                villager["occupation"] = ""
                villager["job"] = ""
        var legacy_resources: Array = []
        for resource in fixture["resources"]:
            if String(resource.get("kind", "")) != "food":
                legacy_resources.append(resource)
        fixture["resources"] = legacy_resources

    if target_version < 12:
        for building in fixture["buildings"]:
            building.erase("stockpile")
    if target_version < 13:
        fixture.erase("supply")
    if target_version < 11:
        fixture.erase("frontier_campaign")
    if target_version < 10:
        for enemy in fixture["enemies"]:
            enemy.erase("faction")
    if target_version < 9:
        fixture.erase("job_priority")
        fixture["quota"].erase("builder")
        for villager in fixture["villagers"]:
            villager.erase("occupation")
            villager.erase("military_specialization")
    if target_version < 8:
        fixture.erase("campaign")
    if target_version < 7:
        fixture.erase("world")
    if target_version < 6:
        fixture["player"].erase("combat")
    if target_version < 5:
        for villager in fixture["villagers"]:
            villager.erase("expedition")
            villager.erase("recalling")

    return fixture


func _write_text(path: String, value: String) -> bool:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(value)
    file.flush()
    var error := file.get_error()
    file.close()
    return error == OK


func _check_export_presets() -> void:
    var presets := ConfigFile.new()
    assert(presets.load("res://export_presets.cfg") == OK,
        "The release export preset file must parse")

    var sections := presets.get_sections()
    assert(sections.has("preset.0") and sections.has("preset.1"),
        "Both Windows and Linux export presets must be declared")

    assert(String(presets.get_value("preset.0", "name", "")) == "Windows Desktop",
        "Windows export preset name must match the build script")
    assert(String(presets.get_value("preset.0", "platform", "")) == "Windows Desktop",
        "Windows preset must target the desktop platform")
    assert(String(presets.get_value("preset.0", "export_path", "")) == "build/windows/HoldTheKeep.exe",
        "Windows artifact path must match the release build script")

    assert(String(presets.get_value("preset.1", "name", "")) == "Linux",
        "Linux export preset name must match the build script")
    assert(String(presets.get_value("preset.1", "platform", "")) == "Linux",
        "Linux preset must target Linux")
    assert(String(presets.get_value("preset.1", "export_path", "")) == "build/linux/HoldTheKeep.x86_64",
        "Linux artifact path must match the release build script")

    for section in ["preset.0", "preset.1"]:
        assert(String(presets.get_value(section, "export_filter", "")) == "all_resources",
            "Release exports must include all runtime resources")
        assert(String(presets.get_value(section, "include_filter", "")) == "*.json",
            "Data-driven JSON definitions must be included in release exports")
        assert(bool(presets.get_value(section + ".options", "binary_format/embed_pck", false)),
            "Release exports must embed the PCK")


func _run() -> void:
    world_config.apply_profile("classic")
    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)

    var classic_main = load("res://scenes/main.tscn").instantiate()
    root.add_child(classic_main)
    current_scene = classic_main
    await ticks(8)
    game_clock.set_process(false)

    var classic_snapshot: Dictionary = save_system.collect(classic_main)
    assert(classic_snapshot["version"] == 14,
        "Current release hardening must exercise the latest v14 schema")
    for version in range(1, 15):
        var fixture := _fixture_for_version(classic_snapshot, version)
        assert(save_system._valid_save(fixture),
            "Classic migration fixture v%d must remain structurally valid" % version)

    var unsupported := classic_snapshot.duplicate(true)
    unsupported["version"] = 15
    assert(not save_system._valid_save(unsupported),
        "Unknown future save versions must be rejected")
    var invalid_index := classic_snapshot.duplicate(true)
    invalid_index["fog"]["cells"].append(64 * 64)
    assert(not save_system._valid_save(invalid_index),
        "Out-of-range Classic fog indices must be rejected")

    _check_export_presets()

    # Simulate a crash after writing a temporary file but before installing it.
    assert(save_system.save_current(true), "The first primary save must be installed")
    assert(_write_text("user://save.tmp", "{incomplete temporary save"),
        "The interrupted-write fixture must be writable")
    assert(save_system._read_valid_save("user://save.json") != null,
        "A valid primary save must remain loadable while a stale temp file exists")
    assert(save_system.save_current(true),
        "A subsequent save must safely replace stale temp data")
    assert(not FileAccess.file_exists("user://save.tmp"),
        "A successful save must not leave a temporary file behind")
    assert(save_system._read_valid_save("user://save.json") != null,
        "The newly installed primary save must validate")
    assert(save_system._read_valid_save("user://save.bak") != null,
        "The previous valid primary must be retained as a rollback backup")

    assert(_write_text("user://save.json", "{corrupt primary"),
        "The primary corruption fixture must be writable")
    assert(save_system._read_valid_save("user://save.json") == null,
        "A corrupted primary save must be rejected")
    assert(save_system._read_valid_save("user://save.bak") != null,
        "A valid rollback backup must remain eligible after primary corruption")

    classic_main.queue_free()
    await ticks(3)
    world_config.apply_profile("frontier")

    var frontier_main = load("res://scenes/main.tscn").instantiate()
    root.add_child(frontier_main)
    current_scene = frontier_main
    await ticks(10)
    game_clock.set_process(false)

    var frontier_snapshot: Dictionary = save_system.collect(frontier_main)
    assert(frontier_snapshot["world"]["map_size"] == 128,
        "Frontier fixtures must use the 128x128 world")
    for version in range(7, 15):
        var fixture := _fixture_for_version(frontier_snapshot, version)
        assert(save_system._valid_save(fixture),
            "Frontier migration fixture v%d must remain structurally valid" % version)

    var legacy_classic := _fixture_for_version(classic_snapshot, 6)
    assert(not save_system._valid_save(legacy_classic),
        "Legacy Classic saves must not load into Frontier")
    assert(save_system._valid_save(legacy_classic, false),
        "Structurally valid legacy saves must remain available as profile-switch backups")

    var wrong_profile := classic_snapshot.duplicate(true)
    assert(not save_system._valid_save(wrong_profile),
        "A current Classic save must not load into the Frontier world")

    var broken_campaign := frontier_snapshot.duplicate(true)
    broken_campaign["frontier_campaign"]["objectives"].pop_back()
    assert(not save_system._valid_save(broken_campaign),
        "A truncated Frontier objective registry must be rejected")

    print("PASS: Classic save schemas v1-v14, Frontier v7-v14, interrupted writes, backup recovery eligibility and Windows/Linux export presets")
    quit(0)


func _initialize() -> void:
    world_config = root.get_node("WorldConfig")
    game_clock = root.get_node("GameClock")
    save_system = root.get_node("SaveSystem")
    call_deferred("_run")
