extends SceneTree
## Frontier profile integration: deterministic regions, traversal, resources and Keep footprint.

const WORLD_SCRIPT := preload("res://scripts/world/world_map.gd")
const DIRS4: Array[Vector2i] = [
    Vector2i(1, 0), Vector2i(-1, 0),
    Vector2i(0, 1), Vector2i(0, -1)
]


func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func resource_signature(world: Node) -> Array[String]:
    var signature: Array[String] = []
    for cell in world.occupied:
        var node = world.occupied[cell]
        if is_instance_valid(node) and node.is_in_group("resource_nodes"):
            signature.append("%d,%d:%s" % [cell.x, cell.y, String(node.yield_kind)])
    signature.sort()
    return signature


func reachable_cells(nav: Node, start: Vector2i) -> Dictionary:
    var visited: Dictionary = {}
    if not nav.is_walkable(start):
        return visited

    var queue: Array[Vector2i] = [start]
    visited[start] = true
    var cursor := 0
    while cursor < queue.size():
        var current := queue[cursor]
        cursor += 1
        for direction in DIRS4:
            var next := current + direction
            if visited.has(next) or not nav.is_walkable(next):
                continue
            visited[next] = true
            queue.append(next)
    return visited


func _initialize() -> void:
    assert(WorldConfig.apply_profile("frontier"),
        "Frontier must be selectable before creating a new world")
    assert(WorldConfig.profile_id == "frontier"
        and WorldConfig.map_size == 128
        and WorldConfig.map_cells == 128 * 128,
        "Frontier profile must apply all 128x128 dimensions")
    assert(WorldConfig.starting_claim_radius == 15.0
        and WorldConfig.safe_radius == 12.0,
        "Frontier must apply the expanded starting footprint and clearing")

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(6)
    GameClock.set_process(false)

    var world = main.world
    assert(world.map_size == 128 and world.tile_size == 16,
        "Main world must use the Frontier dimensions and existing tile size")
    assert(world.pixel_size == Vector2i(2048, 2048),
        "Frontier camera/world bounds must cover 2048x2048 pixels")
    assert(world.starting_keep_cell() == Vector2i(63, 61),
        "Keep placement must remain centered relative to the expanded map")

    var region_cells := {
        "HEARTHLAND": 0,
        "GREENWOOD": 0,
        "HIGHLANDS": 0,
        "FENLANDS": 0,
        "ASHEN_MARCH": 0
    }
    var tile_types: Dictionary = {}
    for y in WorldConfig.map_size:
        for x in WorldConfig.map_size:
            var cell := Vector2i(x, y)
            var region := world.region_id(cell)
            assert(region_cells.has(region),
                "Frontier generator must not emit an unknown region: " + region)
            region_cells[region] += 1
            var tile_type := world.tile_type_at(cell)
            assert(tile_type >= 0 and tile_type <= 6,
                "Every map cell must reference a registered terrain tile")
            tile_types[tile_type] = int(tile_types.get(tile_type, 0)) + 1

    for region in region_cells:
        assert(int(region_cells[region]) >= 700,
            "Every Frontier biome must occupy a meaningful share of the map: " + region)
    assert(tile_types.has(6) and int(tile_types[6]) > 300,
        "Ashen March must render using its dedicated terrain atlas tile")
    assert(tile_types.has(2) and int(tile_types[2]) > 100,
        "The Frontier must retain natural water obstacles")

    # The entire initial Keep footprint must be inside the generated home clearing.
    var keep_cell: Vector2i = world.starting_keep_cell()
    for y in 3:
        for x in 3:
            var cell := keep_cell + Vector2i(x, y)
            assert(world.is_buildable(cell),
                "The starting Keep footprint must not overlap water")
    main.territory.rebuild()
    assert(main.territory.claimed_cells.size() >= 650,
        "The Frontier Keep must claim the larger 15-tile starting territory")

    var resource_counts := {
        "wood": 0,
        "stone": 0,
        "iron": 0
    }
    var regional_resources := {
        "GREENWOOD": 0,
        "HIGHLANDS": 0,
        "ASHEN_MARCH": 0
    }
    for cell in world.occupied:
        var node = world.occupied[cell]
        if not is_instance_valid(node) or not node.is_in_group("resource_nodes"):
            continue
        var kind := String(node.yield_kind)
        resource_counts[kind] = int(resource_counts.get(kind, 0)) + 1
        var region := world.region_id(cell)
        if regional_resources.has(region):
            regional_resources[region] += 1

    assert(int(resource_counts["wood"]) >= 100,
        "Frontier must generate a substantial renewable wood supply")
    assert(int(resource_counts["stone"]) >= 100,
        "Rock deposits must be available beyond the starting region")
    assert(int(resource_counts["iron"]) >= 64,
        "Frontier must generate at least two nodes per configured iron vein")
    assert(int(regional_resources["GREENWOOD"]) >= 50,
        "Greenwood must contain a meaningful resource concentration")
    assert(int(regional_resources["HIGHLANDS"]) >= 50,
        "Highlands must contain a meaningful resource concentration")
    assert(int(regional_resources["ASHEN_MARCH"]) >= 30,
        "Ashen March must contain a meaningful resource concentration")

    # Validate path connectivity from the Keep's spawn point into every biome.
    main.nav.rebuild()
    var reachable := reachable_cells(main.nav, main.nav.cell_of(main.player.global_position))
    assert(reachable.size() > 2500,
        "The starting settlement must connect to a substantial portion of the world")
    var reachable_regions: Dictionary = {}
    for cell in reachable:
        var region := world.region_id(cell)
        reachable_regions[region] = int(reachable_regions.get(region, 0)) + 1
    for region in region_cells:
        assert(int(reachable_regions.get(region, 0)) > 50,
            "Every Frontier biome must be reachable from the Keep: " + region)

    # Generate the same profile again and compare every terrain cell and resource placement.
    var mirror = WORLD_SCRIPT.new()
    root.add_child(mirror)
    await process_frame
    for y in WorldConfig.map_size:
        for x in WorldConfig.map_size:
            var cell := Vector2i(x, y)
            assert(mirror.tile_type_at(cell) == world.tile_type_at(cell),
                "Terrain generation must be deterministic at %s" % cell)
            assert(mirror.region_id(cell) == world.region_id(cell),
                "Biome assignment must be deterministic at %s" % cell)
    assert(resource_signature(mirror) == resource_signature(world),
        "Resource placement must be deterministic for a matching seed/profile")

    print("PASS: Frontier dimensions, five regions, Ashen terrain, resources, iron veins, Keep claim, reachability and deterministic generation")
    mirror.queue_free()
    main.queue_free()
    quit()
