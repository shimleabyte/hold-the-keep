extends RefCounted
## Deterministic Frontier region labeling, isolated from TileMap and entity placement.

const REGION_HEARTHLAND := 0
const REGION_GREENWOOD := 1
const REGION_HIGHLANDS := 2
const REGION_FENLANDS := 3
const REGION_ASHEN_MARCH := 4


## Returns one region id per row-major cell for the supplied profile size and seed.
## This stage has no access to scene nodes and cannot consume the resource RNG stream.
static func generate(map_size: int, world_seed: int) -> PackedByteArray:
    var regions := PackedByteArray()
    if map_size <= 0:
        return regions

    regions.resize(map_size * map_size)

    var warp_x := FastNoiseLite.new()
    warp_x.seed = world_seed + 1709
    warp_x.noise_type = FastNoiseLite.TYPE_SIMPLEX
    warp_x.frequency = 0.021

    var warp_y := FastNoiseLite.new()
    warp_y.seed = world_seed + 1721
    warp_y.noise_type = FastNoiseLite.TYPE_SIMPLEX
    warp_y.frequency = 0.021

    var center := Vector2(map_size, map_size) * 0.5
    var anchors: Array[Vector2] = [
        Vector2(map_size * 0.19, map_size * 0.20),
        Vector2(map_size * 0.81, map_size * 0.20),
        Vector2(map_size * 0.19, map_size * 0.80),
        Vector2(map_size * 0.81, map_size * 0.80)
    ]
    var hearthland_radius := float(map_size) * 0.15

    for y in map_size:
        for x in map_size:
            var warped := Vector2(x, y) + Vector2(
                warp_x.get_noise_2d(x, y),
                warp_y.get_noise_2d(x, y)
            ) * 12.0
            var region := REGION_HEARTHLAND
            if warped.distance_to(center) >= hearthland_radius:
                var nearest_distance := INF
                for i in anchors.size():
                    var distance := warped.distance_squared_to(anchors[i])
                    if distance < nearest_distance:
                        nearest_distance = distance
                        region = REGION_GREENWOOD + i
            regions[y * map_size + x] = region

    return regions
