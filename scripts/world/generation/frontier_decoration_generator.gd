extends RefCounted
## Deterministic Frontier biome dressing and landmark layout.
## This stage selects prop records only; WorldMap remains responsible for node creation.
## It receives a precomputed eligibility mask so Expedition barriers, resources, wildlife
## and the existing buildability rules remain authoritative in the host.

const REGION_GENERATOR := preload("res://scripts/world/generation/frontier_region_generator.gd")

const REGION_HEARTHLAND := REGION_GENERATOR.REGION_HEARTHLAND
const REGION_GREENWOOD := REGION_GENERATOR.REGION_GREENWOOD
const REGION_HIGHLANDS := REGION_GENERATOR.REGION_HIGHLANDS
const REGION_FENLANDS := REGION_GENERATOR.REGION_FENLANDS
const REGION_ASHEN_MARCH := REGION_GENERATOR.REGION_ASHEN_MARCH


## Returns deterministic decoration records in the original creation order:
## random regional props in row-major order, followed by one landmark per region.
## eligible_cells must contain one byte per map cell; 1 means buildable and unoccupied.
static func generate(
    map_size: int,
    world_seed: int,
    safe_radius: float,
    frontier_regions: PackedByteArray,
    eligible_cells: PackedByteArray
) -> Array[Dictionary]:
    var layout: Array[Dictionary] = []
    var expected_cells := map_size * map_size
    if map_size <= 0:
        return layout
    if frontier_regions.size() != expected_cells or eligible_cells.size() != expected_cells:
        return layout

    var rng := RandomNumberGenerator.new()
    rng.seed = world_seed + 8813
    var center := Vector2(map_size, map_size) * 0.5
    var clearing_radius := maxf(safe_radius + 7.0, float(map_size) * 0.15)
    var used_cells: Dictionary = {}

    for y in map_size:
        for x in map_size:
            var index := y * map_size + x
            if int(eligible_cells[index]) == 0:
                continue

            var region := int(frontier_regions[index])
            var minimum_distance := safe_radius + 3.0 if region == REGION_HEARTHLAND else clearing_radius + 2.0
            if Vector2(x, y).distance_to(center) < minimum_distance:
                continue

            if rng.randf() >= _decoration_density(region):
                continue

            var kind := _prop_kind(region, rng)
            var variation := rng.randi_range(0, 2)
            layout.append({
                "cell": Vector2i(x, y),
                "kind": kind,
                "variant": variation,
                "landmark": false
            })
            used_cells[Vector2i(x, y)] = true

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

    # Regions are mutually exclusive, so all five landmark searches can share
    # one row-major scan. Strictly-less comparison preserves the original tie order.
    var best_cells: Array[Vector2i] = []
    var best_distances: Array[float] = []
    for region_index in regions.size():
        best_cells.append(Vector2i(-1, -1))
        best_distances.append(INF)

    for y in map_size:
        for x in map_size:
            var index := y * map_size + x
            var region_index := int(frontier_regions[index])
            if region_index < 0 or region_index >= regions.size():
                continue
            if int(eligible_cells[index]) == 0:
                continue

            var cell := Vector2i(x, y)
            if used_cells.has(cell):
                continue
            var target_region := regions[region_index]
            var distance_from_home := Vector2(cell).distance_to(center)
            var minimum_home_distance := safe_radius + 3.0 if target_region == REGION_HEARTHLAND else clearing_radius + 4.0
            if distance_from_home < minimum_home_distance:
                continue

            var distance_to_target := Vector2(cell).distance_squared_to(targets[region_index])
            if distance_to_target < best_distances[region_index]:
                best_distances[region_index] = distance_to_target
                best_cells[region_index] = cell

    for region_index in regions.size():
        var best_cell := best_cells[region_index]
        if best_cell.x < 0:
            continue
        used_cells[best_cell] = true
        layout.append({
            "cell": best_cell,
            "kind": kinds[region_index],
            "variant": region_index,
            "landmark": true
        })

    return layout


static func _decoration_density(region: int) -> float:
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


static func _prop_kind(region: int, rng: RandomNumberGenerator) -> String:
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
