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

    var scene_resource: PackedScene = load("res://scenes/main.tscn") as PackedScene
    var first_main: Node2D = scene_resource.instantiate() as Node2D
    if first_main == null:
        push_error("FAIL: Main scene could not be instantiated for the legacy save fixture")
        quit(1)
        return
    root.add_child(first_main)
    current_scene = first_main
    await ticks(8)
    game_clock.set_process(false)
    var first_world: Node = first_main.get("world") as Node
    assert(first_world != null and int(first_world.get("map_size")) == 64,
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
    var restored_main: Node2D = get_first_node_in_group("main") as Node2D
    assert(restored_main != null, "Continue must rebuild the main scene")
    if restored_main == null:
        quit(1)
        return
    var restored_world: Node = restored_main.get("world") as Node
    assert(restored_world != null, "Continue must restore its world node")
    if restored_world == null:
        quit(1)
        return
    assert(String(world_config.get("profile_id")) == "classic" and int(world_config.get("map_size")) == 64,
        "The saved campaign dimensions must override the new-game default during Continue")
    assert(int(restored_world.get("map_size")) == 64,
        "The restored terrain must retain its original 64x64 footprint")
    var restored_keep_cell: Vector2i = restored_world.call("starting_keep_cell")
    assert(restored_keep_cell == Vector2i(31, 29),
        "The saved Classic Keep must remain at its original cell coordinates")
    var restored_snapshot: Dictionary = save_system.call("collect", restored_main)
    assert(bool(save_system.call("_valid_save", restored_snapshot)),
        "The restored historical map must remain saveable without a schema rewrite")

    assert(bool(world_config.call("apply_profile", "classic")) and int(world_config.get("map_size")) == 128,
        "Starting a new Classic campaign after Continue must still use 128x128")
    print("PASS: legacy Classic save resumes on its original 64x64 world; new Classic starts at 128x128")
    quit()
