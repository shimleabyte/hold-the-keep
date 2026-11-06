extends SceneTree
## A legacy Classic campaign must reopen in its original world dimensions after
## the shipped profile grows. Loading it into the new 128x128 map is not safe.

func ticks(count: int) -> void:
    for _index in count:
        await process_frame


func _initialize() -> void:
    await process_frame
    var world_config = root.get_node("WorldConfig")
    var save_system = root.get_node("SaveSystem")
    var game_clock = root.get_node("GameClock")

    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)

    assert(world_config.apply_saved_profile("classic", 64),
        "The old Classic profile dimensions must remain selectable for saves")
    save_system.pending_world_profile = "classic"
    save_system.pending_world_map_size = 64
    OS.set_environment("HTK_AUTO_START_GAME", "1")

    var first_main = load("res://scenes/main.tscn").instantiate()
    root.add_child(first_main)
    current_scene = first_main
    await ticks(8)
    game_clock.set_process(false)
    assert(first_main.world != null and first_main.world.map_size == 64,
        "The fixture must start on the historical 64x64 world")
    assert(save_system.save_current(true),
        "The historical world fixture must produce a valid current-schema save")

    OS.set_environment("HTK_AUTO_START_GAME", "0")
    assert(world_config.apply_profile("classic") and world_config.map_size == 128,
        "New Classic campaigns must use the enlarged 128x128 profile")
    assert(save_system.request_load(),
        "Continue must accept the structurally valid historical Classic save")

    await ticks(8)
    game_clock.set_process(false)
    var restored_main := root.get_first_node_in_group("main")
    assert(restored_main != null and restored_main.world != null,
        "Continue must rebuild the main scene")
    assert(world_config.profile_id == "classic" and world_config.map_size == 64,
        "The saved campaign dimensions must override the new-game default during Continue")
    assert(restored_main.world.map_size == 64,
        "The restored terrain must retain its original 64x64 footprint")
    assert(restored_main.world.starting_keep_cell() == Vector2i(31, 29),
        "The saved Classic Keep must remain at its original cell coordinates")
    assert(save_system._valid_save(save_system.collect(restored_main)),
        "The restored historical map must remain saveable without a schema rewrite")

    assert(world_config.apply_profile("classic") and world_config.map_size == 128,
        "Starting a new Classic campaign after Continue must still use 128x128")
    print("PASS: legacy Classic save resumes on its original 64x64 world; new Classic starts at 128x128")
    quit()
