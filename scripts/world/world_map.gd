extends Node2D
## Profile-scaled world terrain, collision water and harvestable resource nodes.
## Classic keeps its original atlas; Frontier uses a dedicated weathered regional palette.

const TREE_CHANCE := 0.07

const TREE_SCRIPT := preload("res://scripts/entities/resource_tree.gd")
const ROCK_SCRIPT := preload("res://scripts/entities/rock.gd")
const ROCK_CHANCE := 0.02
const IRON_SCRIPT := preload("res://scripts/entities/iron_ore.gd")
const WILDLIFE_SCRIPT := preload("res://scripts/entities/wildlife_node.gd")
const FRONTIER_DECORATION_SCRIPT := preload("res://scripts/entities/frontier_decoration.gd")
const FRONTIER_REGION_GENERATOR := preload("res://scripts/world/generation/frontier_region_generator.gd")
const FRONTIER_TERRAIN_GENERATOR := preload("res://scripts/world/generation/frontier_terrain_generator.gd")
const FRONTIER_RESOURCE_GENERATOR := preload("res://scripts/world/generation/frontier_resource_generator.gd")
const FRONTIER_DECORATION_GENERATOR := preload("res://scripts/world/generation/frontier_decoration_generator.gd")

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
var _expedition_outer_reachable: Dictionary = {}
var _expedition_unlocked_regions: Dictionary = {}
var generated_resource_layout: Array[Dictionary] = []
var generated_wildlife_layout: Array[Dictionary] = []
var generated_decoration_layout: Array[Dictionary] = []
var generated_decoration_eligibility := PackedByteArray()
var generate_resource_nodes := true

var map_seed := 1337
var map_size := 64
var tile_size := 16
var safe_radius := 8.0
var pixel_size := Vector2i.ZERO
var entities: Node2D
var occupied: Dictionary = {}  # Vector2i -> Node (resource, blueprint, building)
var resource_nodes_by_cell: Dictionary = {}  # Retains cleared nodes for save/load state.

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

    occupied.clear()
    resource_nodes_by_cell.clear()
    generated_resource_layout.clear()
    generated_wildlife_layout.clear()
    if WorldConfig.is_frontier_profile():
        _generate_frontier()
    else:
        _generate_classic()
    _spawn_iron()
    if WorldConfig.is_frontier_expedition():
        _setup_expedition_barriers()
    _spawn_wildlife()
    if WorldConfig.is_frontier_profile():
        _spawn_frontier_decorations()
    if WorldConfig.is_frontier_expedition():
        _build_expedition_outer_reachability()


func is_buildable(cell: Vector2i) -> bool:
    if cell.x < 1 or cell.y < 1 or cell.x > map_size - 2 or cell.y > map_size - 2:
        return false
    if _expedition_barrier_cells.has(cell):
        return false
    return _layer.get_cell_atlas_coords(cell).x != T_WATER


func _register_resource_node(node: Node2D, cell: Vector2i) -> void:
    node.set("resource_cell", cell)
    node.set("world_map", self)
    entities.add_child(node)
    resource_nodes_by_cell[cell] = node
    occupied[cell] = node


func resource_node_at(cell: Vector2i) -> Node2D:
    var node: Variant = resource_nodes_by_cell.get(cell)
    return node as Node2D if is_instance_valid(node) else null


func clear_resource_occupancy(node: Node2D) -> void:
    var cell: Vector2i = node.get("resource_cell")
    if occupied.get(cell) == node:
        occupied.erase(cell)
        Events.resource_occupancy_changed.emit(cell)


func restore_resource_occupancy(node: Node2D) -> void:
    var cell: Vector2i = node.get("resource_cell")
    var occupant: Variant = occupied.get(cell)
    if occupant == null:
        occupied[cell] = node
        Events.resource_occupancy_changed.emit(cell)


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
                _register_resource_node(tree, cell)
            elif Vector2(x, y).distance_to(center) > 5.5 and rng.randf() < ROCK_CHANCE:
                var rock := ROCK_SCRIPT.new()
                rock.position = foot
                _register_resource_node(rock, cell)


func _generate_frontier() -> void:
    _build_frontier_regions()

    var resource_rng := RandomNumberGenerator.new()
    resource_rng.seed = map_seed + 1001
    var terrain_layout := FRONTIER_TERRAIN_GENERATOR.generate(
        map_size, map_seed, safe_radius, _frontier_regions, resource_rng
    )
    if terrain_layout.size() != map_size * map_size:
        push_error("WorldMap: Frontier terrain generation returned an incomplete layout")
        return

    var resource_layout := FRONTIER_RESOURCE_GENERATOR.generate(
        map_size, map_seed, safe_radius, _frontier_regions, terrain_layout, resource_rng
    )
    var resource_by_cell: Dictionary = {}
    for placement in resource_layout:
        var placement_cell: Vector2i = placement["cell"]
        resource_by_cell[placement_cell] = String(placement["kind"])

    # Keep TileMap mutation and scene-node creation in WorldMap. Applying the
    # returned row-major placements during this loop preserves node creation order.
    for y in map_size:
        for x in map_size:
            var cell := Vector2i(x, y)
            var tile := int(terrain_layout[y * map_size + x])
            _layer.set_cell(cell, 0, Vector2i(tile, 0))
            if not resource_by_cell.has(cell):
                continue

            var kind := String(resource_by_cell[cell])
            var region := int(_frontier_regions[y * map_size + x])
            var foot := Vector2(x * tile_size + tile_size / 2.0, y * tile_size + tile_size)
            generated_resource_layout.append({"cell": cell, "kind": kind})

            if kind == "wood":
                if generate_resource_nodes:
                    var tree := TREE_SCRIPT.new()
                    tree.regional_style = _frontier_tree_style(region)
                    tree.position = foot
                    _register_resource_node(tree, cell)
                else:
                    occupied[cell] = true
            elif kind == "stone":
                if generate_resource_nodes:
                    var rock := ROCK_SCRIPT.new()
                    rock.regional_style = _frontier_rock_style(region)
                    rock.position = foot
                    _register_resource_node(rock, cell)
                else:
                    occupied[cell] = true


## Scatter non-blocking regional props after resource placement so the two never overlap.
## The decoration RNG is independent of terrain/resource RNG to preserve existing generation.
func _spawn_frontier_decorations() -> void:
    generated_decoration_layout.clear()
    generated_decoration_eligibility = _frontier_decoration_eligibility()
    var decoration_layout := FRONTIER_DECORATION_GENERATOR.generate(
        map_size, map_seed, safe_radius, _frontier_regions, generated_decoration_eligibility
    )
    for entry in decoration_layout:
        var cell: Vector2i = entry["cell"]
        _record_frontier_decoration(
            cell, String(entry["kind"]), int(entry["variant"]), bool(entry["landmark"])
        )
    if generate_resource_nodes:
        _spawn_frontier_decoration_batches()


func _spawn_frontier_decoration_batches() -> void:
    # One CanvasItem per world row and z-layer preserves the original Y-sort foot.
    var row_batches: Array = []
    row_batches.resize(map_size * 2)
    for entry in generated_decoration_layout:
        var cell: Vector2i = entry["cell"]
        var landmark := bool(entry["landmark"])
        var batch_index := cell.y * 2 + (1 if landmark else 0)
        if row_batches[batch_index] == null:
            row_batches[batch_index] = []
        var batch_entries: Array = row_batches[batch_index]
        batch_entries.append({
            "kind": String(entry["kind"]),
            "variant": int(entry["variant"]),
            "offset": Vector2(cell.x * tile_size + tile_size / 2.0, 0.0)
        })
        row_batches[batch_index] = batch_entries

    for batch_index in row_batches.size():
        if row_batches[batch_index] == null:
            continue
        var batch_entries: Array = row_batches[batch_index]
        if batch_entries.is_empty():
            continue
        var row := floori(float(batch_index) / 2.0)
        var landmark := batch_index % 2 == 1
        var batch_node = FRONTIER_DECORATION_SCRIPT.new()
        batch_node.setup_batch(batch_entries, landmark)
        batch_node.position = Vector2(0.0, (row + 1) * tile_size)
        entities.add_child(batch_node)


## Snapshot the current map constraints for the pure decoration stage.
## In Expedition this includes sealed crossings and reserved gate approaches/landings.
func _frontier_decoration_eligibility() -> PackedByteArray:
    var eligible := PackedByteArray()
    eligible.resize(map_size * map_size)
    for y in map_size:
        for x in map_size:
            var cell := Vector2i(x, y)
            if not is_buildable(cell) or occupied.has(cell) or _expedition_reserved_cells.has(cell):
                continue
            eligible[y * map_size + x] = 1
    return eligible


func _record_frontier_decoration(cell: Vector2i, kind: String, variation: int, landmark: bool) -> void:
    generated_decoration_layout.append({
        "cell": cell,
        "kind": kind,
        "variant": variation,
        "landmark": landmark
    })
    # Visual creation is deferred until all deterministic records can be batched.


func _build_frontier_regions() -> void:
    _frontier_regions = FRONTIER_REGION_GENERATOR.generate(map_size, map_seed)


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


## Place finite, renewable small-game nodes outside the protected starting clearing.
## A separate seed keeps wood/stone/iron layouts unchanged and reproducible.
func _spawn_wildlife() -> void:
    generated_wildlife_layout.clear()
    var rng := RandomNumberGenerator.new()
    rng.seed = map_seed + 2419
    var center := Vector2(map_size, map_size) * 0.5
    var frontier := WorldConfig.is_frontier_profile()
    var protected_radius := maxf(
        safe_radius + (7.0 if frontier else 4.0),
        float(map_size) * (0.15 if frontier else 0.10)
    )
    var target_count := mini(112, maxi(12, roundi(float(map_size * map_size) / 340.0)))
    # A selected wildlife node blocks at most eight other candidate cells (its 3x3
    # neighborhood). Therefore the first 9 * target_count candidates in score order
    # are sufficient to reproduce the greedy spacing pass; later candidates cannot
    # be visited before the target count is reached.
    var candidate_limit := target_count * 9
    var candidates: Array[Dictionary] = []
    for y in range(2, map_size - 2):
        for x in range(2, map_size - 2):
            var cell := Vector2i(x, y)
            if Vector2(cell).distance_to(center) < protected_radius:
                continue
            if not is_buildable(cell) or occupied.has(cell) or _expedition_reserved_cells.has(cell):
                continue
            var region := region_id(cell)
            if frontier and not ["GREENWOOD", "FENLANDS"].has(region):
                continue
            var score := Vector2(cell).distance_to(center) + rng.randf_range(0.0, 2.0)
            var order := y * map_size + x
            if candidates.size() < candidate_limit:
                _push_wildlife_candidate(candidates, {
                    "cell": cell,
                    "score": score,
                    "order": order
                })
            elif _wildlife_candidate_is_better(score, order, candidates[0]):
                # Reuse the root dictionary; do not allocate one for every heap replacement.
                var worst_candidate: Dictionary = candidates[0]
                worst_candidate["cell"] = cell
                worst_candidate["score"] = score
                worst_candidate["order"] = order
                _sift_wildlife_candidate_heap(candidates, 0)
    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var a_score := float(a["score"])
        var b_score := float(b["score"])
        if a_score == b_score:
            return int(a["order"]) < int(b["order"])
        return a_score < b_score
    )

    var blocked_nearby: Dictionary = {}
    var placed := 0
    for candidate in candidates:
        if placed >= target_count:
            break
        var cell: Vector2i = candidate["cell"]
        if blocked_nearby.has(cell):
            continue
        var region := region_id(cell)
        generated_wildlife_layout.append({"cell": cell, "region": region})
        if generate_resource_nodes:
            var wildlife = WILDLIFE_SCRIPT.new()
            wildlife.regional_style = region.to_lower()
            wildlife.position = Vector2(
                cell.x * tile_size + tile_size / 2.0,
                cell.y * tile_size + tile_size
            )
            _register_resource_node(wildlife, cell)
        else:
            occupied[cell] = true
        for dy in range(-1, 2):
            for dx in range(-1, 2):
                blocked_nearby[cell + Vector2i(dx, dy)] = true
        placed += 1


static func _wildlife_candidate_is_worse(a: Dictionary, b: Dictionary) -> bool:
    var a_score := float(a["score"])
    var b_score := float(b["score"])
    if a_score == b_score:
        return int(a["order"]) > int(b["order"])
    return a_score > b_score


static func _wildlife_candidate_is_better(score: float, order: int, current_worst: Dictionary) -> bool:
    var worst_score := float(current_worst["score"])
    if score == worst_score:
        return order < int(current_worst["order"])
    return score < worst_score


static func _push_wildlife_candidate(heap: Array[Dictionary], candidate: Dictionary) -> void:
    heap.append(candidate)
    var index := heap.size() - 1
    while index > 0:
        var parent := floori(float(index - 1) / 2.0)
        if not _wildlife_candidate_is_worse(heap[index], heap[parent]):
            break
        var swap_value: Dictionary = heap[parent]
        heap[parent] = heap[index]
        heap[index] = swap_value
        index = parent


static func _sift_wildlife_candidate_heap(heap: Array[Dictionary], start_index: int) -> void:
    var index := start_index
    while true:
        var left := index * 2 + 1
        var right := left + 1
        var worst := index
        if left < heap.size() and _wildlife_candidate_is_worse(heap[left], heap[worst]):
            worst = left
        if right < heap.size() and _wildlife_candidate_is_worse(heap[right], heap[worst]):
            worst = right
        if worst == index:
            return
        var swap_value: Dictionary = heap[index]
        heap[index] = heap[worst]
        heap[worst] = swap_value
        index = worst


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
    _register_resource_node(ore, cell)


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
    _expedition_outer_reachable.clear()
    _expedition_unlocked_regions.clear()

    var profile: Dictionary = WorldConfig.profile_definition(WorldConfig.profile_id)
    var core_size := int(profile.get("expedition_core_size", 128))
    var core_min := int((map_size - core_size) / 2)
    var core_max := core_min + core_size
    var center := int(map_size / 2)
    var core_reachable := _expedition_core_reachable_cells(core_min, core_max)
    if core_reachable.is_empty():
        push_error("Frontier Expedition: starting heartland has no reachable survey network")
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
        var gate_cell := _find_expedition_gate_cell(String(region), gate_targets[region], core_min, core_max, center, core_reachable)
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


func _expedition_core_reachable_cells(core_min: int, core_max: int) -> Dictionary:
    var reachable: Dictionary = {}
    var start_cell := Vector2i((spawn_point() / float(tile_size)).floor())
    if start_cell.x < core_min or start_cell.y < core_min or start_cell.x >= core_max or start_cell.y >= core_max:
        return reachable
    if not is_buildable(start_cell) or occupied.has(start_cell):
        return reachable

    var queue: Array[Vector2i] = [start_cell]
    reachable[start_cell] = true
    var cursor := 0
    var directions: Array[Vector2i] = [
        Vector2i(1, 0), Vector2i(-1, 0),
        Vector2i(0, 1), Vector2i(0, -1)
    ]
    while cursor < queue.size():
        var current := queue[cursor]
        cursor += 1
        for direction in directions:
            var next := current + direction
            if next.x < core_min or next.y < core_min or next.x >= core_max or next.y >= core_max:
                continue
            if reachable.has(next) or not is_buildable(next) or occupied.has(next):
                continue
            reachable[next] = true
            queue.append(next)
    return reachable


## Build the walkable outer component from the far side of each sealed gate.
## These cells remain unreachable from the Keep until the corresponding gate opens.
func _build_expedition_outer_reachability() -> void:
    _expedition_outer_reachable.clear()
    var directions: Array[Vector2i] = [
        Vector2i(1, 0), Vector2i(-1, 0),
        Vector2i(0, 1), Vector2i(0, -1)
    ]
    for region in _expedition_gate_cells:
        var gate_cell: Vector2i = _expedition_gate_cells[region]
        var outward := Vector2i(0, -1) if gate_cell.y < map_size / 2 else Vector2i(0, 1)
        var start_cell := gate_cell + outward
        var visited: Dictionary = {}
        if not is_buildable(start_cell) or occupied.has(start_cell) or region_id(start_cell) != String(region):
            push_error("Frontier Expedition: outer landing for %s is not traversable" % String(region))
            _expedition_outer_reachable[String(region)] = visited
            continue
        var queue: Array[Vector2i] = [start_cell]
        visited[start_cell] = true
        var cursor := 0
        while cursor < queue.size():
            var current := queue[cursor]
            cursor += 1
            for direction in directions:
                var next_cell := current + direction
                if visited.has(next_cell) or not is_buildable(next_cell) or occupied.has(next_cell):
                    continue
                if region_id(next_cell) != String(region):
                    continue
                visited[next_cell] = true
                queue.append(next_cell)
        _expedition_outer_reachable[String(region)] = visited


## True only for tiles on the walkable outer component belonging to this march.
func is_expedition_outer_cell(cell: Vector2i, region: String) -> bool:
    if not WorldConfig.is_frontier_expedition() or not WorldConfig.is_valid_cell(cell):
        return false
    if _expedition_reserved_cells.has(cell):
        return false
    var reachable: Dictionary = _expedition_outer_reachable.get(region, {})
    return reachable.has(cell)


func is_expedition_reserved_cell(cell: Vector2i) -> bool:
    return WorldConfig.is_frontier_expedition() and _expedition_reserved_cells.has(cell)


func _find_expedition_gate_cell(
    region: String,
    target: Vector2i,
    core_min: int,
    core_max: int,
    center: int,
    core_reachable: Dictionary
) -> Vector2i:
    var inward := Vector2i(0, 1) if target.y < map_size / 2 else Vector2i(0, -1)
    var outward := -inward
    for radius in range(core_max - core_min):
        for direction in [-1, 1]:
            var candidate := target + Vector2i(radius * direction, 0)
            var approach := candidate + inward
            var landing := candidate + outward
            # Gates must replace a cell on the actual core perimeter, never a
            # nearby tile outside it or the fixed wall dividing adjacent marches.
            if candidate.x < core_min or candidate.x >= core_max or candidate.x == center - 1:
                continue
            if not core_reachable.has(approach):
                continue
            if _frontier_region_name(_frontier_region_at(candidate)) != region:
                continue
            if _frontier_region_name(_frontier_region_at(approach)) != region:
                continue
            if _frontier_region_name(_frontier_region_at(landing)) != region:
                continue
            if tile_type_at(candidate) == T_WATER:
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


func expedition_outer_landing_cell(region: String) -> Vector2i:
    if not _expedition_gate_cells.has(region):
        return Vector2i(-1, -1)
    var gate_cell: Vector2i = _expedition_gate_cells[region]
    var outward := Vector2i(0, -1) if gate_cell.y < map_size / 2 else Vector2i(0, 1)
    return gate_cell + outward


func is_expedition_gate_open(region: String) -> bool:
    return bool(_expedition_unlocked_regions.get(region, false))


func _spawn_iron() -> void:
    if WorldConfig.is_frontier_profile():
        _spawn_frontier_iron()
    else:
        _spawn_classic_iron()


