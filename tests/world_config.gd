extends SceneTree
## Regression checks for centralized world profile settings and tile indexing.


func _initialize() -> void:
    var world_config = root.get_node("WorldConfig")
    var game_clock = root.get_node("GameClock")
    var save_system = root.get_node("SaveSystem")
    assert(world_config.profile_id == "classic", "The shipped project must keep Classic as its default profile")
    assert(world_config.map_size == 64, "Classic must retain the original 64x64 world")
    assert(world_config.tile_size == 16, "The world tile size must remain 16 pixels")
    assert(world_config.map_cells == 64 * 64, "Map cell count must match the configured dimensions")
    assert(world_config.starting_claim_radius == 10.0, "Classic must preserve the existing Keep claim radius")
    assert(world_config.safe_radius == 8.0, "Classic must preserve the existing spawn clearing")
    assert(world_config.world_seed == 1337, "The default world seed must remain deterministic")
    assert(world_config.world_pixel_size() == Vector2i(1024, 1024),
        "World pixel dimensions must derive from tile count and tile size")

    var sample := Vector2i(17, 29)
    var index: int = world_config.cell_index(sample)
    assert(index == sample.y * world_config.map_size + sample.x,
        "Tile coordinates must map to a stable row-major index")
    assert(world_config.cell_from_index(index) == sample,
        "Tile index conversion must round-trip")
    assert(world_config.cell_index(Vector2i(-1, 0)) == -1,
        "Out-of-bounds cells must not receive valid indices")
    assert(world_config.cell_from_index(world_config.map_cells) == Vector2i(-1, -1),
        "Out-of-bounds indices must not map to valid cells")

    var frontier: Dictionary = world_config.profile_definition("frontier")
    assert(int(frontier.get("map_size", 0)) == 128,
        "The planned Frontier profile must define a 128x128 world")
    assert(is_equal_approx(float(frontier.get("starting_claim_radius", 0.0)), 15.0),
        "The planned Frontier profile must define a 15-tile Keep claim")
    assert(is_equal_approx(float(frontier.get("safe_radius", 0.0)), 12.0),
        "Frontier must provide an appropriately larger starting clearing")
    assert(int(frontier.get("iron_veins", 0)) == 32,
        "Frontier resource density must scale with the fourfold map area")

    var expedition: Dictionary = world_config.profile_definition("frontier_expedition")
    assert(int(expedition.get("map_size", 0)) == 192,
        "Frontier Expedition must define a separate 192x192 world without changing legacy Frontier")
    assert(int(frontier.get("map_size", 0)) == 128,
        "Existing Frontier saves must retain their original 128x128 dimensions")
    assert(int(expedition.get("expedition_core_size", 0)) == 128,
        "The Expedition profile must preserve the original 128x128 heartland as its starting area")
    assert(int(expedition.get("iron_veins", 0)) == 72,
        "Expedition iron supply must scale to the larger map area")
    assert(world_config.is_frontier_profile("frontier_expedition")
        and not world_config.is_frontier_profile("classic"),
        "Both Frontier profiles must use shared campaign systems without changing Classic")

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await process_frame
    await process_frame
    await process_frame
    game_clock.set_process(false)

    var current_save: Dictionary = save_system.collect(main)
    assert(current_save["world"]["profile"] == "classic",
        "New saves must record the active world profile")
    assert(current_save["world"]["map_size"] == 64,
        "New Classic saves must record the original map dimensions")
    assert(save_system._valid_save(current_save),
        "A current v9 save must validate against its matching world configuration")

    var legacy_save := current_save.duplicate(true)
    legacy_save.erase("world")
    legacy_save["quota"].erase("builder")
    legacy_save["quota"].erase("hunter")
    legacy_save["quota"].erase("scout")
    legacy_save["quota"].erase("healer")
    legacy_save["quota"].erase("blacksmith")
    legacy_save.erase("job_priority")
    for villager in legacy_save["villagers"]:
        villager.erase("weapon_equipped")
        villager.erase("armor_equipped")
        if String(villager.get("job", "")) in ["hunter", "scout", "healer", "blacksmith"]:
            villager["job"] = ""
        villager.erase("occupation")
        villager.erase("military_specialization")
    var legacy_resources: Array = []
    for resource in legacy_save["resources"]:
        if String(resource.get("kind", "")) != "food":
            legacy_resources.append(resource)
    legacy_save["resources"] = legacy_resources
    for building_index in range(legacy_save["buildings"].size() - 1, -1, -1):
        if String(legacy_save["buildings"][building_index].get("id", "")) in ["hunting_lodge", "scout_post", "infirmary", "forge"]:
            legacy_save["buildings"].remove_at(building_index)
    for legacy_version in range(1, 7):
        legacy_save["version"] = legacy_version
        assert(save_system._valid_save(legacy_save),
            "A v%d legacy save must remain compatible with Classic Mode" % legacy_version)

    var incompatible_save := current_save.duplicate(true)
    incompatible_save["world"]["profile"] = "frontier"
    incompatible_save["world"]["map_size"] = 128
    assert(not save_system._valid_save(incompatible_save),
        "A save from another profile or map size must be rejected")

    var legacy_profile: String = world_config.profile_id
    world_config.profile_id = "frontier"
    assert(not save_system._valid_save(legacy_save),
        "Legacy 64x64 saves must not load into the Frontier profile")
    assert(save_system._valid_save(legacy_save, false),
        "A structurally valid legacy save must remain retainable as a profile-switch backup")
    assert(not save_system._valid_save(current_save),
        "A Classic v7 save must not load into Frontier")
    assert(save_system._valid_save(current_save, false),
        "A valid Classic v7 save must remain eligible for a cross-profile backup")
    world_config.profile_id = legacy_profile

    print("PASS: world profiles, tile indexing, and save profile compatibility")
    quit()
