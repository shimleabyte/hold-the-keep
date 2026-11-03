extends Node2D
## Profile-scaled world terrain, collision water and harvestable resource nodes.
## Classic keeps its original atlas; Frontier uses a dedicated weathered regional palette.

const TREE_CHANCE := 0.07

const TREE_SCRIPT := preload("res://scripts/entities/resource_tree.gd")
const ROCK_SCRIPT := preload("res://scripts/entities/rock.gd")
const ROCK_CHANCE := 0.02
const IRON_SCRIPT := preload("res://scripts/entities/iron_ore.gd")
const FRONTIER_DECORATION_SCRIPT := preload("res://scripts/entities/frontier_decoration.gd")

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
var _expedition_barrier_cells: Dictionary = {}
var _expedition_gate_cells: Dictionary = {}
var _expedition_gate_original_tiles: Dictionary = {}
var _expedition_reserved_cells: Dictionary = {}
var _expedition_unlocked_regions: Dictionary = {}
var generated_resource_layout: Array[Dictionary] = []
var generated_decoration_layout: Array[Dictionary] = []
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
    if WorldConfig.is_frontier_profile():
        _generate_frontier()
    else:
        _generate_classic()
    if WorldConfig.is_frontier_expedition():
        _setup_expedition_barriers()
    _spawn_iron()
    if WorldConfig.is_frontier_profile():
        _spawn_frontier_decorations()


func is_buildable(cell: Vector2i) -> bool:
    if cell.x < 1 or cell.y < 1 or cell.x > map_size - 2 or cell.y > map_size - 2:
        return false
    if _expedition_barrier_cells.has(cell):
        return false
    return _layer.get_cell_atlas_coords(cell).x != T_WATER


func is_bridgeable(cell: Vector2i) -> bool:
    if cell.x < 1 or cell.y < 1 or cell.x > map_size - 2 or cell.y > map_size - 2:
        return false
    return _layer.get_cell_atlas_coords(cell).x == T_WATER and not _expedition_barrier_cells.has(cell)


func starting_keep_cell() -> Vector2i:
    return WorldConfig.starting_keep_cell()


func keep_center_position() -> Vector2:
    var cell := starting_keep_cell()
    return Vector2((cell.x + 1.5) * tile_size, (cell.y + 3.0) * tile_size)


func spawn_point() -> Vector2:
    return keep_center_position() + Vector2(0.0, 48.0)

## Stable regional labels used by terrain generation and the strategic map.
func region_id(cell: Vector2i) -> String:
    if WorldConfig.is_frontier_profile():
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
    src.texture = TILES_FRONTIER_TEX if WorldConfig.is_frontier_profile() else TILES_TEX
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
                    tree.regional_style = _frontier_tree_style(region)
                    tree.position = foot
                    entities.add_child(tree)
                    occupied[cell] = tree
                else:
                    occupied[cell] = true
            elif resource_rng.randf() < rock_density:
                generated_resource_layout.append({"cell": cell, "kind": "stone"})
                if generate_resource_nodes:
                    var rock := ROCK_SCRIPT.new()
                    rock.regional_style = _frontier_rock_style(region)
                    rock.position = foot
                    entities.add_child(rock)
                    occupied[cell] = rock
                else:
                    occupied[cell] = true


## Scatter non-blocking regional props after resource placement so the two never overlap.
## The decoration RNG is independent of terrain/resource RNG to preserve existing generation.
func _spawn_frontier_decorations() -> void:
    generated_decoration_layout.clear()
    var rng := RandomNumberGenerator.new()
    rng.seed = map_seed + 8813
    var center := Vector2(map_size, map_size) * 0.5
    var clearing_radius := maxf(safe_radius + 7.0, float(map_size) * 0.15)
    var decoration_cells: Dictionary = {}

    for y in map_size:
        for x in map_size:
            var cell := Vector2i(x, y)
            if not is_buildable(cell) or occupied.has(cell) or _expedition_reserved_cells.has(cell):
                continue
            var region := _frontier_region_at(cell)
            var minimum_distance := safe_radius + 3.0 if region == REGION_HEARTHLAND else clearing_radius + 2.0
            if Vector2(x, y).distance_to(center) < minimum_distance:
                continue
            var density := _frontier_decoration_density(region)
            if rng.randf() >= density:
                continue
            var kind := _frontier_prop_kind(region, rng)
            var variation := rng.randi_range(0, 2)
            _record_frontier_decoration(cell, kind, variation, false)
            decoration_cells[cell] = true

    _place_frontier_landmarks(decoration_cells, center, clearing_radius)


func _frontier_decoration_density(region: int) -> float:
    match region:
        REGION_GREENWOOD:
            return 0.026
        REGION_FENLANDS:
            return 0.023
        REGION_HIGHLANDS:
            return 0.016
        REGION_ASHEN_MARCH:
            return 0.014
        REGION_HEARTHLAND:
            return 0.045
    return 0.012


func _frontier_prop_kind(region: int, rng: RandomNumberGenerator) -> String:
    match region:
        REGION_GREENWOOD:
            return "dead_pine" if rng.randf() < 0.24 else "fern_cluster"
        REGION_HIGHLANDS:
            return "standing_stone" if rng.randf() < 0.72 else "dead_pine"
        REGION_FENLANDS:
            return "fen_reeds" if rng.randf() < 0.78 else "standing_stone"
        REGION_ASHEN_MARCH:
            return "ash_pillar" if rng.randf() < 0.72 else "standing_stone"
        REGION_HEARTHLAND:
            return "ruin_marker" if rng.randf() < 0.45 else "fern_cluster"
    return "fern_cluster"


func _place_frontier_landmarks(used_cells: Dictionary, center: Vector2, clearing_radius: float) -> void:
    var regions: Array[int] = [
        REGION_HEARTHLAND, REGION_GREENWOOD, REGION_HIGHLANDS,
        REGION_FENLANDS, REGION_ASHEN_MARCH
    ]
    var targets: Array[Vector2] = [
        center + Vector2(0, -15),
        Vector2(map_size * 0.19, map_size * 0.20),
        Vector2(map_size * 0.81, map_size * 0.20),
        Vector2(map_size * 0.19, map_size * 0.80),
        Vector2(map_size * 0.81, map_size * 0.80)
    ]
    var kinds: Array[String] = [
        "hearth_shrine", "ruin_marker", "standing_stone", "fen_reeds", "ash_pillar"
    ]

    for index in regions.size():
        var best_cell := Vector2i(-1, -1)
        var best_distance := INF
        for y in map_size:
            for x in map_size:
                var cell := Vector2i(x, y)
                if _frontier_region_at(cell) != regions[index] or not is_buildable(cell):
                    continue
                if occupied.has(cell) or used_cells.has(cell) or _expedition_reserved_cells.has(cell):
                    continue
                var distance_from_home := Vector2(cell).distance_to(center)
                var minimum_home_distance := safe_radius + 3.0 if regions[index] == REGION_HEARTHLAND else clearing_radius + 4.0
                if distance_from_home < minimum_home_distance:
                    continue
                var distance_to_target := Vector2(cell).distance_squared_to(targets[index])
                if distance_to_target < best_distance:
                    best_distance = distance_to_target
                    best_cell = cell
        if best_cell.x < 0:
            continue
        used_cells[best_cell] = true
        _record_frontier_decoration(best_cell, kinds[index], index, true)


func _record_frontier_decoration(cell: Vector2i, kind: String, variation: int, landmark: bool) -> void:
    generated_decoration_layout.append({
        "cell": cell,
        "kind": kind,
        "variant": variation,
        "landmark": landmark
    })
    if not generate_resource_nodes:
        return
    var prop = FRONTIER_DECORATION_SCRIPT.new()
    prop.setup(kind, variation, landmark)
    prop.position = Vector2(
        cell.x * tile_size + tile_size / 2.0,
        cell.y * tile_size + tile_size
    )
    entities.add_child(prop)


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


func _frontier_tree_style(region: int) -> String:
    match region:
        REGION_GREENWOOD:
            return "greenwood"
        REGION_FENLANDS:
            return "fenlands"
        REGION_ASHEN_MARCH:
            return "ashen_march"
    return "hearthland"


func _frontier_rock_style(region: int) -> String:
    match region:
        REGION_HIGHLANDS:
            return "highlands"
        REGION_ASHEN_MARCH:
            return "ashen_march"
    return "hearthland"


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
        if not is_buildable(cell) or occupied.has(cell) or _expedition_reserved_cells.has(cell):
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
            if not is_buildable(candidate) or occupied.has(candidate) or _expedition_reserved_cells.has(candidate):
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


## Frontier Expedition keeps the established 128x128 heartland accessible first.
## Four water-sealed crossings open only after the matching regional discovery objective.
## The full 192x192 terrain is generated once; this is exploration gating, not chunk streaming.
func _setup_expedition_barriers() -> void:
    _expedition_barrier_cells.clear()
    _expedition_gate_cells.clear()
    _expedition_gate_original_tiles.clear()
    _expedition_reserved_cells.clear()
    _expedition_unlocked_regions.clear()

    var profile: Dictionary = WorldConfig.profile_definition(WorldConfig.profile_id)
    var core_size := int(profile.get("expedition_core_size", 128))
    var core_min := int((map_size - core_size) / 2)
    var core_max := core_min + core_size
    var center := int(map_size / 2)
    var barriers: Dictionary = {}

    # Seal the four sides of the initial heartland.
    for x in range(core_min, core_max):
        barriers[Vector2i(x, core_min - 1)] = true
        barriers[Vector2i(x, core_max)] = true
    for y in range(core_min, core_max):
        barriers[Vector2i(core_min - 1, y)] = true
        barriers[Vector2i(core_max, y)] = true

    # Keep the four outer marches separate until their own crossing is surveyed.
    for y in range(0, core_min):
        barriers[Vector2i(center - 1, y)] = true
    for y in range(core_max, map_size):
        barriers[Vector2i(center - 1, y)] = true
    for x in range(0, core_min):
        barriers[Vector2i(x, center - 1)] = true
    for x in range(core_max, map_size):
        barriers[Vector2i(x, center - 1)] = true

    var gate_targets: Dictionary = {
        "GREENWOOD": Vector2i(core_min + int(core_size * 0.25), core_min - 1),
        "HIGHLANDS": Vector2i(core_min + int(core_size * 0.75), core_min - 1),
        "FENLANDS": Vector2i(core_min + int(core_size * 0.25), core_max),
        "ASHEN_MARCH": Vector2i(core_min + int(core_size * 0.75), core_max)
    }
    for region in gate_targets:
        var gate_cell := _find_expedition_gate_cell(String(region), gate_targets[region])
        if gate_cell.x < 0:
            push_error("Frontier Expedition: could not place the %s survey gate" % String(region))
            continue
        barriers.erase(gate_cell)
        _expedition_gate_cells[String(region)] = gate_cell
        var original_tile := tile_type_at(gate_cell)
        if original_tile == T_WATER:
            original_tile = _frontier_gate_terrain(String(region))
        _expedition_gate_original_tiles[String(region)] = original_tile

    for value in barriers:
        _seal_expedition_cell(value)
    for region in _expedition_gate_cells:
        _seal_expedition_cell(_expedition_gate_cells[region])


func _find_expedition_gate_cell(region: String, target: Vector2i) -> Vector2i:
    var core_size := int(WorldConfig.profile_definition(WorldConfig.profile_id).get("expedition_core_size", 128))
    var inward := Vector2i(0, 1) if target.y < map_size / 2 else Vector2i(0, -1)
    var outward := -inward
    for radius in range(core_size):
        for direction in [-1, 1]:
            var candidate := target + Vector2i(radius * direction, 0)
            var approach := candidate + inward
            var landing := candidate + outward
            if candidate.x < 1 or candidate.x >= map_size - 1:
                continue
            if _frontier_region_name(_frontier_region_at(candidate)) != region:
                continue
            if _frontier_region_name(_frontier_region_at(approach)) != region:
                continue
            if _frontier_region_name(_frontier_region_at(landing)) != region:
                continue
            if tile_type_at(candidate) == T_WATER or not is_buildable(approach) or occupied.has(approach):
                continue
            if not is_buildable(landing) or occupied.has(landing):
                continue
            _expedition_reserved_cells[approach] = true
            _expedition_reserved_cells[landing] = true
            return candidate
    return Vector2i(-1, -1)


func _frontier_gate_terrain(region: String) -> int:
    match region:
        "GREENWOOD":
            return T_FOREST
        "HIGHLANDS":
            return T_HIGHLAND
        "FENLANDS":
            return T_MARSH
        "ASHEN_MARCH":
            return T_ASHEN
    return T_GRASS


func _seal_expedition_cell(cell: Vector2i) -> void:
    var occupant: Variant = occupied.get(cell, null)
    if occupant is Node and is_instance_valid(occupant):
        occupant.queue_free()
    occupied.erase(cell)
    _expedition_barrier_cells[cell] = true
    _layer.set_cell(cell, 0, Vector2i(T_WATER, 0))


## Returns the regions newly opened by a completed discovery objective.
func apply_expedition_sector_unlocks(discovered_regions: Dictionary) -> Array[String]:
    var opened: Array[String] = []
    if not WorldConfig.is_frontier_expedition():
        return opened
    for region in _expedition_gate_cells:
        var should_open := bool(discovered_regions.get(String(region), false))
        var is_open := bool(_expedition_unlocked_regions.get(String(region), false))
        if should_open == is_open:
            continue
        var cell: Vector2i = _expedition_gate_cells[region]
        if should_open:
            var terrain := int(_expedition_gate_original_tiles.get(String(region), T_GRASS))
            _layer.set_cell(cell, 0, Vector2i(terrain, 0))
            _expedition_barrier_cells.erase(cell)
            _expedition_unlocked_regions[String(region)] = true
            opened.append(String(region))
        else:
            _seal_expedition_cell(cell)
            _expedition_unlocked_regions[String(region)] = false
    if not opened.is_empty():
        queue_redraw()
    return opened


func is_expedition_survey_site_reached(region: String, player_position: Vector2) -> bool:
    if not _expedition_gate_cells.has(region):
        return false
    var gate_cell: Vector2i = _expedition_gate_cells[region]
    var inward := Vector2i(0, 1) if gate_cell.y < map_size / 2 else Vector2i(0, -1)
    var approach := gate_cell + inward
    var player_cell := Vector2i((player_position / float(tile_size)).floor())
    if _frontier_region_name(_frontier_region_at(player_cell)) != region:
        return false
    return Vector2(player_cell - approach).length_squared() <= 25.0


func is_expedition_gate_open(region: String) -> bool:
    return bool(_expedition_unlocked_regions.get(region, false))


func _spawn_iron() -> void:
    if WorldConfig.is_frontier_profile():
        _spawn_frontier_iron()
    else:
        _spawn_classic_iron()


