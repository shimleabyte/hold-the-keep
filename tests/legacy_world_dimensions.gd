extends SceneTree
## A legacy Classic campaign must reopen in its original world dimensions after
## the shipped profile grows. Loading it into the new 128x128 map is not safe.

func ticks(count: int) -> void:
    for _index: int in count:
        await process_frame


func _initialize() -> void:
    await process_frame
    var world_config: Node = root.get_node("WorldConfig")
    var save_system: Node = root.get_node("SaveSystem")
    var game_clock: Node = root.get_node("GameClock")

    for path: String in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)

    assert(bool(world_config.call("apply_saved_profile", "classic", 64)),
        "The old Classic profile dimensions must remain selectable for saves")
    save_system.set("pending_world_profile", "classic")
    save_system.set("pending_world_map_size", 64)
    OS.set_environment("HTK_AUTO_START_GAME", "1")

    var first_main: HoldTheKeepMain = load("res://scenes/main.tscn").instantiate() as HoldTheKeepMain
    root.add_child(first_main)
    current_scene = first_main
    await ticks(8)
    game_clock.set_process(false)
    assert(first_main.world != null and first_main.world.map_size == 64,
        "The fixture must start on the historical 64x64 world")
    assert(bool(save_system.call("save_current", true)),
        "The historical world fixture must produce a valid current-schema save")

    OS.set_environment("HTK_AUTO_START_GAME", "0")
    assert(bool(world_config.call("apply_profile", "classic")) and int(world_config.get("map_size")) == 128,
        "New Classic campaigns must use the enlarged 128x128 profile")
    assert(bool(save_system.call("request_load")),
        "Continue must accept the structurally valid historical Classic save")

    await ticks(8)
    game_clock.set_process(false)
    var restored_main: HoldTheKeepMain = get_first_node_in_group("main") as HoldTheKeepMain
    assert(restored_main != null and restored_main.world != null,
        "Continue must rebuild the main scene")
    assert(String(world_config.get("profile_id")) == "classic" and int(world_config.get("map_size")) == 64,
        "The saved campaign dimensions must override the new-game default during Continue")
    assert(restored_main.world.map_size == 64,
        "The restored terrain must retain its original 64x64 footprint")
    assert(restored_main.world.starting_keep_cell() == Vector2i(31, 29),
        "The saved Classic Keep must remain at its original cell coordinates")
    var restored_snapshot: Dictionary = save_system.call("collect", restored_main)
    assert(bool(save_system.call("_valid_save", restored_snapshot)),
        "The restored historical map must remain saveable without a schema rewrite")

    assert(bool(world_config.call("apply_profile", "classic")) and int(world_config.get("map_size")) == 128,
        "Starting a new Classic campaign after Continue must still use 128x128")
    print("PASS: legacy Classic save resumes on its original 64x64 world; new Classic starts at 128x128")
    quit()
