extends Node2D
## Profile-scaled world terrain, collision water and harvestable resource nodes.
## Classic keeps its original atlas; Frontier uses a dedicated weathered regional palette.

const TREE_CHANCE := 0.07

const TREE_SCRIPT := preload("res://scripts/entities/resource_tree.gd")
const ROCK_SCRIPT := preload("res://scripts/entities/rock.gd")
const ROCK_CHANCE := 0.02
const IRON_SCRIPT := preload("res://scripts/entities/iron_ore.gd")

const TILES_TEX := preload("res://assets/sprites/tiles.svg")
const TILES_FRONTIER_TEX := preload("res://assets/sprites/tiles_frontier.svg")

const T_GRASS := 0
const T_GRASS_ALT := 1
const T_WATER := 2
const T_FOREST := 3
const T_HIGHLAND := 4
const T_MARSH := 5
const T_ASHEN := 6

const REGION_HEARTHLAND := 0
const REGION_GREENWOOD := 1
const REGION_HIGHLANDS := 2
const REGION_FENLANDS := 3
const REGION_ASHEN_MARCH := 4

var _frontier_regions := PackedByteArray()
var generated_resource_layout: Array[Dictionary] = []
var generate_resource_nodes := true

var map_seed := 1337
var map_size := 64
var tile_size := 16
var safe_radius := 8.0
var pixel_size := Vector2i.ZERO
var entities: Node2D
var occupied: Dictionary = {}  # Vector2i -> Node (pohon, batu, bangunan)

var _layer: TileMapLayer


func _ready() -> void:
    map_size = WorldConfig.map_size
    tile_size = WorldConfig.tile_size
    safe_radius = WorldConfig.safe_radius
    map_seed = WorldConfig.world_seed
    pixel_size = WorldConfig.world_pixel_size()

    _layer = TileMapLayer.new()
    _layer.tile_set = _build_tileset()
    add_child(_layer)

    entities = Node2D.new()
    entities.y_sort_enabled = true
    add_child(entities)

    generated_resource_layout.clear()
    if WorldConfig.profile_id == "frontier":
        _generate_frontier()
    else:
        _generate_classic()
    _spawn_iron()


func is_buildable(cell: Vector2i) -> bool:
    if cell.x < 1 or cell.y < 1 or cell.x > map_size - 2 or cell.y > map_size - 2:
        return false
    return _layer.get_cell_atlas_coords(cell).x != T_WATER


func is_bridgeable(cell: Vector2i) -> bool:
    if cell.x < 1 or cell.y < 1 or cell.x > map_size - 2 or cell.y > map_size - 2:
        return false
    return _layer.get_cell_atlas_coords(cell).x == T_WATER


func starting_keep_cell() -> Vector2i:
    return WorldConfig.starting_keep_cell()


func keep_center_position() -> Vector2:
    var cell := starting_keep_cell()
    return Vector2((cell.x + 1.5) * tile_size, (cell.y + 3.0) * tile_size)


func spawn_point() -> Vector2:
    return keep_center_position() + Vector2(0.0, 48.0)

## Stable regional labels used by terrain generation and the strategic map.
func region_id(cell: Vector2i) -> String:
    if WorldConfig.profile_id == "frontier":
        return _frontier_region_name(_frontier_region_at(cell))
    return _classic_region_id(cell)


func region_name_at(cell: Vector2i) -> String:
    return region_id(cell)


## Atlas tile index, exposed read-only for the strategic map.
func tile_type_at(cell: Vector2i) -> int:
    if cell.x < 0 or cell.y < 0 or cell.x >= map_size or cell.y >= map_size:
        return T_WATER
    return _layer.get_cell_atlas_coords(cell).x


func _build_tileset() -> TileSet:
    var ts := TileSet.new()
    ts.tile_size = Vector2i(tile_size, tile_size)
    ts.add_physics_layer()
    ts.set_physics_layer_collision_layer(0, 1)

    var src := TileSetAtlasSource.new()
    src.texture = TILES_FRONTIER_TEX if WorldConfig.profile_id == "frontier" else TILES_TEX
    src.texture_region_size = Vector2i(tile_size, tile_size)
    ts.add_source(src, 0)
    for i in 7:
        src.create_tile(Vector2i(i, 0))

    # Air = penghalang
    var data := src.get_tile_data(Vector2i(T_WATER, 0), 0)
    data.add_collision_polygon(0)
    var h := tile_size / 2.0
    data.set_collision_polygon_points(
        0, 0, PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
    )
    return ts


func _generate_classic() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = map_seed
    var noise := FastNoiseLite.new()
    noise.seed = map_seed
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.frequency = 0.07

    var center := Vector2(map_size, map_size) / 2.0
    for y in map_size:
        for x in map_size:
            var edge := x == 0 or y == 0 or x == map_size - 1 or y == map_size - 1
            var safe := Vector2(x, y).distance_to(center) < safe_radius
            var water := edge or (not safe and noise.get_noise_2d(x, y) > 0.3)
            var tile := T_WATER
            var region := _classic_region_id(Vector2i(x, y))
            if not water:
                var variation := rng.randf()
                match region:
                    "GREENWOOD":
                        tile = T_FOREST
                    "HIGHLANDS":
                        tile = T_HIGHLAND
                    "FENLANDS":
                        tile = T_MARSH
                    _:
                        tile = T_GRASS_ALT if variation < 0.2 else T_GRASS
            _layer.set_cell(Vector2i(x, y), 0, Vector2i(tile, 0))

            var cell := Vector2i(x, y)
            var foot := Vector2(x * tile_size + tile_size / 2.0, y * tile_size + tile_size)
            if water:
                continue
            if not safe and rng.randf() < TREE_CHANCE:
                var tree := TREE_SCRIPT.new()
                tree.position = foot
                entities.add_child(tree)
                occupied[cell] = tree
            elif Vector2(x, y).distance_to(center) > 5.5 and rng.randf() < ROCK_CHANCE:
                var rock := ROCK_SCRIPT.new()
                rock.position = foot
                entities.add_child(rock)
                occupied[cell] = rock


func _generate_frontier() -> void:
    _build_frontier_regions()

    var water_noise := FastNoiseLite.new()
    water_noise.seed = map_seed + 303
    water_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    water_noise.frequency = 0.043

    var resource_patch_noise := FastNoiseLite.new()
    resource_patch_noise.seed = map_seed + 1907
    resource_patch_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
    resource_patch_noise.frequency = 0.105

    var resource_rng := RandomNumberGenerator.new()
    resource_rng.seed = map_seed + 1001
    var center := Vector2(map_size, map_size) / 2.0
    var clearing_radius := maxf(safe_radius + 7.0, float(map_size) * 0.15)

    for y in map_size:
        for x in map_size:
            var cell := Vector2i(x, y)
            var position := Vector2(x, y)
            var edge := x == 0 or y == 0 or x == map_size - 1 or y == map_size - 1
            var home_clearing := position.distance_to(center) < clearing_radius
            var water := edge or (not home_clearing and water_noise.get_noise_2d(x, y) > 0.58)
            var region := int(_frontier_regions[y * map_size + x])
            var tile := T_WATER

            if not water:
                match region:
                    REGION_GREENWOOD:
                        tile = T_FOREST
                    REGION_HIGHLANDS:
                        tile = T_HIGHLAND
                    REGION_FENLANDS:
                        tile = T_MARSH
                    REGION_ASHEN_MARCH:
                        tile = T_ASHEN
                    _:
                        tile = T_GRASS_ALT if resource_rng.randf() < 0.22 else T_GRASS

            _layer.set_cell(cell, 0, Vector2i(tile, 0))
            if water or home_clearing:
                continue

            var patch := clampf(0.5 + resource_patch_noise.get_noise_2d(x, y) * 0.42, 0.08, 0.95)
            var tree_density := _frontier_tree_density(region) * (0.45 + patch)
            var rock_density := _frontier_rock_density(region) * (0.45 + (1.0 - patch) * 0.9)
            var foot := Vector2(x * tile_size + tile_size / 2.0, y * tile_size + tile_size)

            if resource_rng.randf() < tree_density:
                generated_resource_layout.append({"cell": cell, "kind": "wood"})
                if generate_resource_nodes:
                    var tree := TREE_SCRIPT.new()
                    tree.position = foot
                    entities.add_child(tree)
                    occupied[cell] = tree
                else:
                    occupied[cell] = true
            elif resource_rng.randf() < rock_density:
                generated_resource_layout.append({"cell": cell, "kind": "stone"})
                if generate_resource_nodes:
                    var rock := ROCK_SCRIPT.new()
                    rock.position = foot
                    entities.add_child(rock)
                    occupied[cell] = rock
                else:
                    occupied[cell] = true


func _build_frontier_regions() -> void:
    _frontier_regions.resize(WorldConfig.map_cells)

    var warp_x := FastNoiseLite.new()
    warp_x.seed = map_seed + 1709
    warp_x.noise_type = FastNoiseLite.TYPE_SIMPLEX
    warp_x.frequency = 0.021

    var warp_y := FastNoiseLite.new()
    warp_y.seed = map_seed + 1721
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
            _frontier_regions[y * map_size + x] = region


func _frontier_tree_density(region: int) -> float:
    match region:
        REGION_GREENWOOD:
            return 0.082
        REGION_FENLANDS:
            return 0.045
        REGION_HEARTHLAND:
            return 0.034
        REGION_HIGHLANDS:
            return 0.016
        REGION_ASHEN_MARCH:
            return 0.009
    return 0.025


func _frontier_rock_density(region: int) -> float:
    match region:
        REGION_HIGHLANDS:
            return 0.061
        REGION_ASHEN_MARCH:
            return 0.048
        REGION_HEARTHLAND:
            return 0.023
        REGION_FENLANDS:
            return 0.016
        REGION_GREENWOOD:
            return 0.009
    return 0.02


func _classic_region_id(cell: Vector2i) -> String:
    var offset := Vector2(cell) - Vector2(map_size, map_size) / 2.0
    if offset.length() < 13.0 * float(map_size) / 64.0:
        return "HEARTHLAND"
    if offset.y < -absf(offset.x) * 0.55:
        return "GREENWOOD"
    if offset.x > absf(offset.y) * 0.55:
        return "HIGHLANDS"
    return "FENLANDS"


func _spawn_classic_iron() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = map_seed + 99
    var center := Vector2(map_size, map_size) / 2.0
    var veins := 0
    var tries := 0
    while veins < WorldConfig.iron_veins and tries < 300:
        tries += 1
        var c := Vector2i(rng.randi_range(4, map_size - 5), rng.randi_range(4, map_size - 5))
        if Vector2(c).distance_to(center) < 16.0:
            continue
        var want := rng.randi_range(3, 5)
        var placed := 0
        for i in 16:
            if placed >= want:
                break
            var cell := c + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
            if not is_buildable(cell) or occupied.has(cell):
                continue
            _place_iron_node(cell)
            placed += 1
        if placed >= 2:
            veins += 1


func _spawn_frontier_iron() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = map_seed + 99
    var center := Vector2(map_size, map_size) * 0.5
    var veins := 0
    var tries := 0
    var target := WorldConfig.iron_veins
    while veins < target and tries < WorldConfig.map_cells:
        tries += 1
        var cell := Vector2i(
            rng.randi_range(4, map_size - 5),
            rng.randi_range(4, map_size - 5)
        )
        if Vector2(cell).distance_to(center) < safe_radius + 8.0:
            continue
        if not is_buildable(cell) or occupied.has(cell):
            continue

        var region := _frontier_region_at(cell)
        var preferred := region == REGION_HIGHLANDS or region == REGION_ASHEN_MARCH
        if not preferred and rng.randf() > 0.28:
            continue

        var wanted := rng.randi_range(3, 5)
        var placed := 0
        for attempt in 24:
            if placed >= wanted:
                break
            var candidate := cell + Vector2i(
                rng.randi_range(-2, 2),
                rng.randi_range(-2, 2)
            )
            if not is_buildable(candidate) or occupied.has(candidate):
                continue
            _place_iron_node(candidate)
            placed += 1
        if placed >= 2:
            veins += 1


func _place_iron_node(cell: Vector2i) -> void:
    generated_resource_layout.append({"cell": cell, "kind": "iron"})
    if not generate_resource_nodes:
        occupied[cell] = true
        return
    var ore := IRON_SCRIPT.new()
    ore.position = Vector2(
        cell.x * tile_size + tile_size / 2.0,
        cell.y * tile_size + tile_size
    )
    entities.add_child(ore)
    occupied[cell] = ore


func _frontier_region_at(cell: Vector2i) -> int:
    if cell.x < 0 or cell.y < 0 or cell.x >= map_size or cell.y >= map_size:
        return REGION_HEARTHLAND
    if _frontier_regions.size() != WorldConfig.map_cells:
        return REGION_HEARTHLAND
    return int(_frontier_regions[cell.y * map_size + cell.x])


func _frontier_region_name(region: int) -> String:
    match region:
        REGION_GREENWOOD:
            return "GREENWOOD"
        REGION_HIGHLANDS:
            return "HIGHLANDS"
        REGION_FENLANDS:
            return "FENLANDS"
        REGION_ASHEN_MARCH:
            return "ASHEN_MARCH"
    return "HEARTHLAND"


func _spawn_iron() -> void:
    if WorldConfig.profile_id == "frontier":
        _spawn_frontier_iron()
    else:
        _spawn_classic_iron()


