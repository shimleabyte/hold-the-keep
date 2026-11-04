extends RefCounted
## Deterministic Frontier resource placement, isolated from scene/entity creation.
## The supplied RNG is the same stream advanced by FrontierTerrainGenerator, preserving
## the historical row-major wood/stone placement sequence.

const REGION_GENERATOR := preload("res://scripts/world/generation/frontier_region_generator.gd")

const T_WATER := 2


## Returns row-major wood/stone placements for the supplied Frontier terrain.
## Each result contains a Vector2i cell and a kind ("wood" or "stone").
## No nodes, TileMap cells or WorldMap state are accessed by this stage.
static func generate(
    map_size: int,
    world_seed: int,
    safe_radius: float,
    frontier_regions: PackedByteArray,
    terrain_layout: PackedByteArray,
    resource_rng: RandomNumberGenerator
) -> Array[Dictionary]:
    var placements: Array[Dictionary] = []
    var expected_cells := map_size * map_size
    if map_size <= 0:
        return placements
    if frontier_regions.size() != expected_cells or terrain_layout.size() != expected_cells:
        return placements
    if resource_rng == null:
        return placements

    var resource_patch_noise := FastNoiseLite.new()
    resource_patch_noise.seed = world_seed + 1907
    resource_patch_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
    resource_patch_noise.frequency = 0.105

    var center := Vector2(map_size, map_size) / 2.0
    var clearing_radius := maxf(safe_radius + 7.0, float(map_size) * 0.15)

    for y in map_size:
        for x in map_size:
            var index := y * map_size + x
            if int(terrain_layout[index]) == T_WATER:
                continue
            var position := Vector2(x, y)
            if position.distance_to(center) < clearing_radius:
                continue

            var region := int(frontier_regions[index])
            var patch := clampf(
                0.5 + resource_patch_noise.get_noise_2d(x, y) * 0.42,
                0.08,
                0.95
            )
            var tree_density := _tree_density(region) * (0.45 + patch)
            var rock_density := _rock_density(region) * (0.45 + (1.0 - patch) * 0.9)

            if resource_rng.randf() < tree_density:
                placements.append({"cell": Vector2i(x, y), "kind": "wood"})
            elif resource_rng.randf() < rock_density:
                placements.append({"cell": Vector2i(x, y), "kind": "stone"})

    return placements


static func _tree_density(region: int) -> float:
    match region:
        REGION_GENERATOR.REGION_GREENWOOD:
            return 0.082
        REGION_GENERATOR.REGION_FENLANDS:
            return 0.045
        REGION_GENERATOR.REGION_HEARTHLAND:
            return 0.034
        REGION_GENERATOR.REGION_HIGHLANDS:
            return 0.016
        REGION_GENERATOR.REGION_ASHEN_MARCH:
            return 0.009
    return 0.025


static func _rock_density(region: int) -> float:
    match region:
        REGION_GENERATOR.REGION_HIGHLANDS:
            return 0.061
        REGION_GENERATOR.REGION_ASHEN_MARCH:
            return 0.048
        REGION_GENERATOR.REGION_HEARTHLAND:
            return 0.023
        REGION_GENERATOR.REGION_FENLANDS:
            return 0.016
        REGION_GENERATOR.REGION_GREENWOOD:
            return 0.009
    return 0.02
