extends RefCounted
## Deterministic Frontier terrain atlas generation.
## This stage does not create TileMap cells or entities.
## It intentionally advances the supplied resource RNG by the historical terrain-variation
## draws so the following resource-placement pass retains its existing seeded sequence.

const REGION_GENERATOR := preload("res://scripts/world/generation/frontier_region_generator.gd")

const T_GRASS := 0
const T_GRASS_ALT := 1
const T_WATER := 2
const T_FOREST := 3
const T_HIGHLAND := 4
const T_MARSH := 5
const T_ASHEN := 6


## Returns the row-major atlas tile index for every cell.
## `resource_rng` is passed by reference and advanced exactly as the old combined
## terrain/resource pass advanced it while choosing Hearthland grass variation.
static func generate(
    map_size: int,
    world_seed: int,
    safe_radius: float,
    frontier_regions: PackedByteArray,
    resource_rng: RandomNumberGenerator
) -> PackedByteArray:
    var terrain := PackedByteArray()
    if map_size <= 0 or frontier_regions.size() != map_size * map_size or resource_rng == null:
        return terrain

    terrain.resize(map_size * map_size)

    var water_noise := FastNoiseLite.new()
    water_noise.seed = world_seed + 303
    water_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    water_noise.frequency = 0.043

    var center := Vector2(map_size, map_size) / 2.0
    var clearing_radius := maxf(safe_radius + 7.0, float(map_size) * 0.15)

    for y in map_size:
        for x in map_size:
            var position := Vector2(x, y)
            var edge := x == 0 or y == 0 or x == map_size - 1 or y == map_size - 1
            var home_clearing := position.distance_to(center) < clearing_radius
            var water := edge or (not home_clearing and water_noise.get_noise_2d(x, y) > 0.58)
            var region := int(frontier_regions[y * map_size + x])
            var tile := T_WATER

            if not water:
                match region:
                    REGION_GENERATOR.REGION_GREENWOOD:
                        tile = T_FOREST
                    REGION_GENERATOR.REGION_HIGHLANDS:
                        tile = T_HIGHLAND
                    REGION_GENERATOR.REGION_FENLANDS:
                        tile = T_MARSH
                    REGION_GENERATOR.REGION_ASHEN_MARCH:
                        tile = T_ASHEN
                    _:
                        tile = T_GRASS_ALT if resource_rng.randf() < 0.22 else T_GRASS

            terrain[y * map_size + x] = tile

    return terrain
