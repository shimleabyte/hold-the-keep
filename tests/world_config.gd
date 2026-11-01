extends SceneTree
## Regression checks for centralized world profile settings and tile indexing.


func _initialize() -> void:
    assert(WorldConfig.profile_id == "classic", "The shipped project must keep Classic as its default profile")
    assert(WorldConfig.map_size == 64, "Classic must retain the original 64x64 world")
    assert(WorldConfig.tile_size == 16, "The world tile size must remain 16 pixels")
    assert(WorldConfig.map_cells == 64 * 64, "Map cell count must match the configured dimensions")
    assert(WorldConfig.starting_claim_radius == 10.0, "Classic must preserve the existing Keep claim radius")
    assert(WorldConfig.world_seed == 1337, "The default world seed must remain deterministic")
    assert(WorldConfig.world_pixel_size() == Vector2i(1024, 1024),
        "World pixel dimensions must derive from tile count and tile size")

    var sample := Vector2i(17, 29)
    var index := WorldConfig.cell_index(sample)
    assert(index == sample.y * WorldConfig.map_size + sample.x,
        "Tile coordinates must map to a stable row-major index")
    assert(WorldConfig.cell_from_index(index) == sample,
        "Tile index conversion must round-trip")
    assert(WorldConfig.cell_index(Vector2i(-1, 0)) == -1,
        "Out-of-bounds cells must not receive valid indices")
    assert(WorldConfig.cell_from_index(WorldConfig.map_cells) == Vector2i(-1, -1),
        "Out-of-bounds indices must not map to valid cells")

    var frontier := WorldConfig.profile_definition("frontier")
    assert(int(frontier.get("map_size", 0)) == 128,
        "The planned Frontier profile must define a 128x128 world")
    assert(is_equal_approx(float(frontier.get("starting_claim_radius", 0.0)), 15.0),
        "The planned Frontier profile must define a 15-tile Keep claim")
    assert(int(frontier.get("iron_veins", 0)) == 32,
        "Frontier resource density must scale with the fourfold map area")

    print("PASS: centralized Classic/Frontier world profiles and tile indexing")
    quit()
