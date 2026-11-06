extends SceneTree
## Frontier profile integration: deterministic regions, traversal, resources and Keep footprint.

const FRONTIER_REGION_GENERATOR := preload("res://scripts/world/generation/frontier_region_generator.gd")
const FRONTIER_TERRAIN_GENERATOR := preload("res://scripts/world/generation/frontier_terrain_generator.gd")
const FRONTIER_RESOURCE_GENERATOR := preload("res://scripts/world/generation/frontier_resource_generator.gd")
const FRONTIER_DECORATION_GENERATOR := preload("res://scripts/world/generation/frontier_decoration_generator.gd")

const DIRS4: Array[Vector2i] = [
    Vector2i(1, 0), Vector2i(-1, 0),
    Vector2i(0, 1), Vector2i(0, -1)
]


func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func resource_signature(world: Node) -> Array[String]:
    var signature: Array[String] = []
    for entry in world.generated_resource_layout:
        var cell: Vector2i = entry["cell"]
        signature.append("%d,%d:%s" % [cell.x, cell.y, String(entry["kind"])])
    signature.sort()
    return signature



func resource_layout_signature(layout: Array[Dictionary]) -> Array[String]:
    var signature: Array[String] = []
    for entry in layout:
        var cell: Vector2i = entry["cell"]
        signature.append("%d,%d:%s" % [cell.x, cell.y, String(entry["kind"])])
    signature.sort()
    return signature


func wildlife_signature(world: Node) -> Array[String]:
    var signature: Array[String] = []
    for entry in world.generated_wildlife_layout:
        var cell: Vector2i = entry["cell"]
        signature.append("%d,%d:%s" % [cell.x, cell.y, String(entry["region"])])
    signature.sort()
    return signature


## Test-only all-candidate reference for the bounded wildlife selector.
func reference_wildlife_signature(world: Node) -> Array[String]:
    var rng := RandomNumberGenerator.new()
    rng.seed = world.map_seed + 2419
    var center := Vector2(world.map_size, world.map_size) * 0.5
    # SceneTree scripts are loaded before autoload identifiers are bound.
    var world_config = root.get_node("WorldConfig")
    var frontier: bool = bool(world_config.is_frontier_profile())
    var protected_radius := maxf(
        world.safe_radius + (7.0 if frontier else 4.0),
        float(world.map_size) * (0.15 if frontier else 0.10)
    )
    var candidates: Array[Dictionary] = []
    for y in range(2, world.map_size - 2):
        for x in range(2, world.map_size - 2):
            var cell := Vector2i(x, y)
            if Vector2(cell).distance_to(center) < protected_radius:
                continue
            if not world.is_buildable(cell) or world._expedition_reserved_cells.has(cell):
                continue
            var occupant = world.occupied.get(cell)
            var occupied_by_resource: bool = occupant != null and is_instance_valid(occupant) \
                and occupant.is_in_group("resource_nodes") and not occupant.is_in_group("wildlife")
            if occupied_by_resource:
                continue
            var region: String = String(world.region_id(cell))
            if frontier and not ["GREENWOOD", "FENLANDS"].has(region):
                continue
            candidates.append({
                "cell": cell,
                "region": region,
                "score": Vector2(cell).distance_to(center) + rng.randf_range(0.0, 2.0),
                "order": y * world.map_size + x
            })
    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var a_score := float(a["score"])
        var b_score := float(b["score"])
        if a_score == b_score:
            return int(a["order"]) < int(b["order"])
        return a_score < b_score
    )
    var target_count: int = mini(240, maxi(12, roundi(float(world.map_size * world.map_size) / 340.0)))
    var blocked_nearby: Dictionary = {}
    var signature: Array[String] = []
    var placed := 0
    for candidate in candidates:
        if placed >= target_count:
            break
        var cell: Vector2i = candidate["cell"]
        if blocked_nearby.has(cell):
            continue
        signature.append("%d,%d:%s" % [cell.x, cell.y, String(candidate["region"])])
        for dy in range(-1, 2):
            for dx in range(-1, 2):
                blocked_nearby[cell + Vector2i(dx, dy)] = true
        placed += 1
    signature.sort()
    return signature


func decoration_signature(world: Node) -> Array[String]:
    var signature: Array[String] = []
    for entry in world.generated_decoration_layout:
        var cell: Vector2i = entry["cell"]
        signature.append("%d,%d:%s:%d:%s" % [
            cell.x, cell.y, String(entry["kind"]),
            int(entry["variant"]), str(bool(entry["landmark"]))
        ])
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
    # Load after SceneTree startup so this script resolves project autoloads on Godot 4.7.
    await process_frame
    var world_script := load("res://scripts/world/world_map.gd") as GDScript
    assert(world_script != null and world_script.can_instantiate(),
        "World map script must compile after project autoload initialization")
    var world_config = root.get_node("WorldConfig")
    var settings = root.get_node("Settings")
    var save_system = root.get_node("SaveSystem")
    var game_clock = root.get_node("GameClock")

    assert(world_config.apply_profile("frontier"),
        "Frontier must be selectable before creating a new world")
    assert(world_config.profile_id == "frontier"
        and world_config.map_size == 192
        and world_config.map_cells == 192 * 192,
        "Frontier profile must apply all 192x192 dimensions")
    assert(is_equal_approx(world_config.starting_claim_radius, 22.5)
        and world_config.safe_radius == 18.0,
        "Frontier must apply the expanded starting footprint and clearing")

    var region_layout: PackedByteArray = FRONTIER_REGION_GENERATOR.generate(192, world_config.world_seed)
    var repeated_region_layout: PackedByteArray = FRONTIER_REGION_GENERATOR.generate(192, world_config.world_seed)
    assert(region_layout.size() == 192 * 192,
        "The Frontier region stage must return one label per map cell")
    assert(region_layout == repeated_region_layout,
        "The same Frontier profile size and seed must produce identical region labels")
    var region_counts: Array[int] = [0, 0, 0, 0, 0]
    for region_id in region_layout:
        assert(region_id >= 0 and region_id < region_counts.size(),
            "The region stage must emit only the five registered region identifiers")
        region_counts[region_id] += 1
    for region_id in region_counts.size():
        assert(region_counts[region_id] >= 700,
            "Every generated Frontier region must retain meaningful territory")
    var expedition_region_layout: PackedByteArray = FRONTIER_REGION_GENERATOR.generate(256, world_config.world_seed)
    assert(expedition_region_layout.size() == 256 * 256
        and expedition_region_layout == FRONTIER_REGION_GENERATOR.generate(256, world_config.world_seed),
        "The same deterministic region stage must support the 256x256 Expedition profile")

    var terrain_rng := RandomNumberGenerator.new()
    terrain_rng.seed = world_config.world_seed + 1001
    var terrain_layout := FRONTIER_TERRAIN_GENERATOR.generate(
        192, world_config.world_seed, world_config.safe_radius, region_layout, terrain_rng
    )
    var repeated_terrain_rng := RandomNumberGenerator.new()
    repeated_terrain_rng.seed = world_config.world_seed + 1001
    var repeated_terrain_layout := FRONTIER_TERRAIN_GENERATOR.generate(
        192, world_config.world_seed, world_config.safe_radius, region_layout, repeated_terrain_rng
    )
    assert(terrain_layout.size() == 192 * 192
        and terrain_layout == repeated_terrain_layout,
        "The Frontier terrain stage must produce deterministic row-major tile layouts")
    for tile_id in terrain_layout:
        assert(tile_id >= 0 and tile_id <= 6,
            "The Frontier terrain stage must emit only registered terrain atlas ids")
    assert(is_equal_approx(terrain_rng.randf(), repeated_terrain_rng.randf()),
        "The terrain stage must advance its supplied RNG deterministically for legacy resource placement")
    var expedition_terrain_rng := RandomNumberGenerator.new()
    expedition_terrain_rng.seed = world_config.world_seed + 1001
    var expedition_terrain_layout := FRONTIER_TERRAIN_GENERATOR.generate(
        256, world_config.world_seed, world_config.safe_radius, expedition_region_layout, expedition_terrain_rng
    )
    assert(expedition_terrain_layout.size() == 256 * 256,
        "The Frontier terrain stage must support the 256x256 Expedition profile")
    assert(FRONTIER_TERRAIN_GENERATOR.generate(0, world_config.world_seed, world_config.safe_radius, PackedByteArray(), RandomNumberGenerator.new()).is_empty(),
        "Invalid terrain-stage dimensions must return an empty layout")

    var resource_rng := RandomNumberGenerator.new()
    resource_rng.seed = world_config.world_seed + 1001
    var resource_terrain := FRONTIER_TERRAIN_GENERATOR.generate(
        192, world_config.world_seed, world_config.safe_radius, region_layout, resource_rng
    )
    var frontier_resource_layout := FRONTIER_RESOURCE_GENERATOR.generate(
        192, world_config.world_seed, world_config.safe_radius,
        region_layout, resource_terrain, resource_rng
    )
    var repeated_resource_rng := RandomNumberGenerator.new()
    repeated_resource_rng.seed = world_config.world_seed + 1001
    var repeated_resource_terrain := FRONTIER_TERRAIN_GENERATOR.generate(
        192, world_config.world_seed, world_config.safe_radius, region_layout, repeated_resource_rng
    )
    var repeated_resource_layout := FRONTIER_RESOURCE_GENERATOR.generate(
        192, world_config.world_seed, world_config.safe_radius,
        region_layout, repeated_resource_terrain, repeated_resource_rng
    )
    assert(frontier_resource_layout.size() >= 200
        and frontier_resource_layout == repeated_resource_layout,
        "The isolated Frontier resource stage must produce substantial deterministic placements")
    var resource_rng_next := resource_rng.randf()
    var repeated_resource_rng_next := repeated_resource_rng.randf()
    assert(is_equal_approx(resource_rng_next, repeated_resource_rng_next),
        "The resource stage must advance its supplied shared RNG deterministically")

    var generated_kind_counts := {"wood": 0, "stone": 0}
    var generated_resource_cells: Dictionary = {}
    var resource_center: Vector2 = Vector2(192, 192) * 0.5
    var resource_clearing_radius := maxf(
        world_config.safe_radius + 7.0, 192.0 * 0.15
    )
    for placement in frontier_resource_layout:
        var cell: Vector2i = placement["cell"]
        var kind := String(placement["kind"])
        assert(kind == "wood" or kind == "stone",
            "The resource stage must emit only wood and stone placement kinds")
        assert(not generated_resource_cells.has(cell),
            "A resource stage must not place two harvestables on the same cell")
        generated_resource_cells[cell] = true
        assert(int(resource_terrain[cell.y * 192 + cell.x]) != 2,
            "Resources must be placed only on dry Frontier terrain")
        assert(Vector2(cell).distance_to(resource_center) >= resource_clearing_radius,
            "Resources must remain outside the protected starting clearing")
        generated_kind_counts[kind] += 1
    assert(int(generated_kind_counts["wood"]) >= 100
        and int(generated_kind_counts["stone"]) >= 100,
        "The resource stage must retain substantial wood and stone supplies")
    assert(FRONTIER_RESOURCE_GENERATOR.generate(
        0, world_config.world_seed, world_config.safe_radius,
        PackedByteArray(), PackedByteArray(), RandomNumberGenerator.new()
    ).is_empty(),
        "Invalid resource-stage dimensions must return an empty layout")
    assert(FRONTIER_RESOURCE_GENERATOR.generate(
        192, world_config.world_seed, world_config.safe_radius,
        region_layout, PackedByteArray(), RandomNumberGenerator.new()
    ).is_empty(),
        "Mismatched resource-stage terrain buffers must return an empty layout")

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(6)
    game_clock.set_process(false)

    var world = main.world
    assert(world._frontier_regions == region_layout,
        "WorldMap must consume the isolated region generator without changing its output")
    assert(world._layer.get_used_cells().size() == 192 * 192,
        "Frontier terrain stage must assign every logical map cell")
    for y in world_config.map_size:
        for x in world_config.map_size:
            var terrain_cell := Vector2i(x, y)
            assert(world.tile_type_at(terrain_cell) == int(terrain_layout[y * world_config.map_size + x]),
                "WorldMap must consume the isolated Frontier terrain layout at %s" % terrain_cell)
    var integrated_wood_stone_layout: Array[Dictionary] = []
    for entry in world.generated_resource_layout:
        var kind := String(entry["kind"])
        if kind == "wood" or kind == "stone":
            integrated_wood_stone_layout.append(entry)
    assert(resource_layout_signature(integrated_wood_stone_layout)
        == resource_layout_signature(frontier_resource_layout),
        "WorldMap must consume the isolated resource stage without changing placement output")

    var decoration_eligibility: PackedByteArray = world.generated_decoration_eligibility
    var expected_decoration_layout := FRONTIER_DECORATION_GENERATOR.generate(
        world.map_size, world.map_seed, world.safe_radius,
        world._frontier_regions, decoration_eligibility
    )
    assert(expected_decoration_layout == world.generated_decoration_layout,
        "WorldMap must consume the isolated decoration stage without changing its layout or order")
    assert(FRONTIER_DECORATION_GENERATOR.generate(
        world.map_size, world.map_seed, world.safe_radius,
        world._frontier_regions, decoration_eligibility
    ) == expected_decoration_layout,
        "The isolated decoration stage must repeat exactly for the same seed and eligibility mask")
    assert(FRONTIER_DECORATION_GENERATOR.generate(
        0, world.map_seed, world.safe_radius, PackedByteArray(), PackedByteArray()
    ).is_empty(),
        "Invalid decoration-stage dimensions must return an empty layout")
    assert(FRONTIER_DECORATION_GENERATOR.generate(
        world.map_size, world.map_seed, world.safe_radius,
        world._frontier_regions, PackedByteArray()
    ).is_empty(),
        "Mismatched decoration eligibility must return an empty layout")

    var hud = get_first_node_in_group("hud")
    assert(hud != null, "The Frontier scene must create the HUD")
    hud._layout_viewport(Vector2(480, 270))
    await process_frame
    var frontier_map = hud._map_panel
    assert(frontier_map.position.x >= 0.0 and frontier_map.position.y >= 0.0
        and frontier_map.position.x + frontier_map.size.x <= 480.1
        and frontier_map.position.y + frontier_map.size.y <= 270.1,
        "The 192x192 strategic map must fit a compact viewport")
    assert(world.map_size == 192 and world.tile_size == 16,
        "Main world must use the Frontier dimensions and existing tile size")
    assert(world.pixel_size == Vector2i(3072, 3072),
        "Frontier camera/world bounds must cover 3072x3072 pixels")
    var terrain_source := world._layer.tile_set.get_source(0) as TileSetAtlasSource
    assert(terrain_source != null
        and terrain_source.texture.resource_path.ends_with("tiles_frontier.svg")
        and terrain_source.texture.get_size() == Vector2(112, 16),
        "Frontier must use the dedicated seven-cell weathered biome atlas")
    assert(world.starting_keep_cell() == Vector2i(95, 93),
        "Keep placement must remain centered relative to the expanded map")

    var region_cells := {
        "HEARTHLAND": 0,
        "GREENWOOD": 0,
        "HIGHLANDS": 0,
        "FENLANDS": 0,
        "ASHEN_MARCH": 0
    }
    var tile_types: Dictionary = {}
    for y in world_config.map_size:
        for x in world_config.map_size:
            var cell := Vector2i(x, y)
            var region: String = world.region_id(cell)
            assert(region_cells.has(region),
                "Frontier generator must not emit an unknown region: " + region)
            region_cells[region] += 1
            var tile_type: int = world.tile_type_at(cell)
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


    var decoration_regions := {
        "HEARTHLAND": 0,
        "GREENWOOD": 0,
        "HIGHLANDS": 0,
        "FENLANDS": 0,
        "ASHEN_MARCH": 0
    }
    var landmark_regions := {}
    assert(world.generated_decoration_layout.size() >= 100,
        "Frontier must receive a meaningful amount of non-blocking regional dressing")
    var decoration_batches: Array = get_nodes_in_group("frontier_decoration_batches")
    assert(decoration_batches.size() < world.generated_decoration_layout.size()
        and decoration_batches.size() <= world.map_size * 2,
        "Regional decoration visuals must be batched by world row and z-layer")
    var batched_decoration_count := 0
    for decoration_batch in decoration_batches:
        batched_decoration_count += decoration_batch._batch_entries.size()
    assert(batched_decoration_count == world.generated_decoration_layout.size(),
        "Every deterministic decoration record must be represented in the row batches")
    var resource_cells: Dictionary = {}
    for resource_entry in world.generated_resource_layout:
        resource_cells[resource_entry["cell"]] = true
    for entry in world.generated_decoration_layout:
        var cell: Vector2i = entry["cell"]
        assert(not resource_cells.has(cell),
            "Decorative props must not overlap generated harvestable or iron resource cells")
        var region: String = world.region_id(cell)
        decoration_regions[region] += 1
        if bool(entry["landmark"]):
            landmark_regions[region] = true
    assert(landmark_regions.size() == 5,
        "Each Frontier biome must receive one deterministic regional landmark")
    for region in decoration_regions:
        assert(int(decoration_regions[region]) >= 5,
            "Every Frontier biome must receive visible regional dressing: " + String(region))
    for region in landmark_regions:
        assert(bool(landmark_regions[region]),
            "Landmark placement must be recorded for " + String(region))

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

    var far_cell: Vector2i = Vector2i(world_config.map_size - 1, world_config.map_size - 1)
    var far_index: int = world_config.cell_index(far_cell)
    main.fog.import_state({"cells": [far_index]})
    assert(main.fog.is_revealed_cell(far_cell),
        "Frontier fog data must accept the final valid row-major map index")
    var expected_fog_chunks := ceili(float(world_config.map_size) / 16.0)
    expected_fog_chunks *= expected_fog_chunks
    assert(main.fog._fog_chunks.size() == expected_fog_chunks,
        "Fog must be split into 16x16 chunks instead of one full-map draw item")
    var original_fog_state: Dictionary = main.fog.export_state()
    main.fog.discovered.fill(0)
    main.fog._dirty_chunk_indices.clear()
    var local_reveal := Vector2(6 * world_config.tile_size + 8, 6 * world_config.tile_size + 8)
    assert(main.fog.reveal_position(local_reveal, 1.0),
        "A newly explored tile must change the fog state")
    assert(main.fog._dirty_chunk_indices.size() == 1,
        "Exploring one tile must invalidate only its containing fog chunk")
    main.fog._flush_dirty_chunks()
    var boundary_reveal := Vector2(16 * world_config.tile_size + 8, 16 * world_config.tile_size + 8)
    assert(main.fog.reveal_position(boundary_reveal, 24.0),
        "Exploring a chunk boundary must reveal new neighboring cells")
    assert(main.fog._dirty_chunk_indices.size() == 4,
        "Exploring across a four-chunk corner must invalidate exactly those four chunks")
    main.fog._flush_dirty_chunks()
    assert(main.fog._dirty_chunk_indices.is_empty(),
        "Fog dirty-chunk tracking must clear after invalidation")
    main.fog.import_state(original_fog_state)
    var frontier_save: Dictionary = save_system.collect(main)
    assert(frontier_save["world"]["profile"] == "frontier"
        and int(frontier_save["world"]["map_size"]) == 192
        and save_system._valid_save(frontier_save),
        "A 192x192 Frontier save must retain valid world and fog metadata")
    var invalid_frontier_save := frontier_save.duplicate(true)
    invalid_frontier_save["fog"]["cells"].append(world_config.map_cells)
    assert(not save_system._valid_save(invalid_frontier_save),
        "Frontier save validation must reject fog indices outside the 192x192 map")

    var clearing_center := Vector2(world_config.map_size, world_config.map_size) * 0.5
    var clearing_radius := maxf(world_config.safe_radius + 7.0, float(world_config.map_size) * 0.15)
    for cell in world.occupied:
        var occupant = world.occupied[cell]
        if is_instance_valid(occupant) and occupant.is_in_group("resource_nodes"):
            assert(Vector2(cell).distance_to(clearing_center) >= clearing_radius,
                "Resource nodes must not clutter the protected starting clearing")

    var campaign_menu := get_first_node_in_group("pause_menu")
    assert(campaign_menu != null and campaign_menu._campaign_profile.get_item_count() == 3,
        "The pause menu must expose Classic and Frontier as separate new-campaign choices")
    assert(campaign_menu._campaign_profile.selected == 1,
        "New-campaign selector must reflect the currently active Frontier profile")
    campaign_menu._open_campaign_panel()
    assert(campaign_menu._campaign_center.visible,
        "The new-campaign panel must open from the pause menu")
    campaign_menu._close_campaign_panel()
    assert(not campaign_menu._campaign_center.visible,
        "The new-campaign panel must provide a working return path")

    var previous_profile: String = settings.world_profile
    assert(settings.set_world_profile("frontier"),
        "Frontier profile preference must be persistable")
    var preference_file := ConfigFile.new()
    assert(preference_file.load(settings.PATH) == OK
        and String(preference_file.get_value("world", "profile", "")) == "frontier",
        "The selected campaign profile must persist in the settings file")
    assert(settings.set_world_profile(previous_profile),
        "The previous profile preference must be restorable after this test")

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
    var regional_prop_styles := {
        "greenwood": 0,
        "fenlands": 0,
        "ashen_march": 0,
        "highlands": 0
    }
    for cell in world.occupied:
        var node = world.occupied[cell]
        if not is_instance_valid(node) or not node.is_in_group("resource_nodes"):
            continue
        var kind := String(node.yield_kind)
        resource_counts[kind] = int(resource_counts.get(kind, 0)) + 1
        var region: String = world.region_id(cell)
        if regional_resources.has(region):
            regional_resources[region] += 1
        if kind != "iron":
            var style := String(node.regional_style)
            if regional_prop_styles.has(style):
                regional_prop_styles[style] += 1

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
    for style in regional_prop_styles:
        assert(int(regional_prop_styles[style]) > 0,
            "Frontier must generate resource props with the regional visual style: " + style)

    # Validate path connectivity from the Keep's spawn point into every biome.
    main.nav.rebuild()
    var reachable: Dictionary = main.nav.reachable_cells(main.nav.cell_of(main.player.global_position))
    assert(reachable.size() > 2500,
        "The starting settlement must connect to a substantial portion of the world")
    var reachable_regions: Dictionary = {}
    for cell in reachable:
        var region: String = world.region_id(cell)
        reachable_regions[region] = int(reachable_regions.get(region, 0)) + 1
    for region in region_cells:
        assert(int(reachable_regions.get(region, 0)) > 50,
            "Every Frontier biome must be reachable from the Keep: " + region)

    var navigation_probe_cell := Vector2i(-1, -1)
    for y in world_config.map_size:
        if navigation_probe_cell.x >= 0:
            break
        for x in world_config.map_size:
            var candidate_cell := Vector2i(x, y)
            if reachable.has(candidate_cell) and world.is_buildable(candidate_cell) and not world.occupied.has(candidate_cell):
                navigation_probe_cell = candidate_cell
                break
    assert(navigation_probe_cell.x >= 0,
        "The incremental navigation test must find an empty walkable cell")
    main.territory.rebuild()
    main.supply.rebuild()
    var navigation_version: int = int(main.nav.version)
    var probe_wall = main.build.place_raw("wall", navigation_probe_cell)
    assert(not main.territory._dirty,
        "Placing a wall with no claim radius must not trigger a full territory rebuild")
    assert(not main.supply._dirty,
        "Placing a wall must not rebuild Keep-rooted road/depot connectivity")
    assert(main.nav._dirty_cells.size() == 1 and not main.nav._dirty,
        "Placing a one-cell wall must queue one cell instead of a full-grid rebuild")
    # physics_frame resumes before node _physics_process callbacks; wait through the update frame.
    await ticks(2)
    assert(main.nav.astar.is_point_solid(navigation_probe_cell)
        and main.nav.version == navigation_version + 1,
        "The incremental navigation update must make the placed wall solid")
    assert(main.build.demolish_at(navigation_probe_cell),
        "The navigation probe wall must be removable after the first update")
    await ticks(2)
    assert(not main.territory._dirty and not main.supply._dirty,
        "Removing an ordinary wall must not trigger unrelated territory or depot-graph rebuilds")
    assert(not main.nav.astar.is_point_solid(navigation_probe_cell)
        and main.nav.version == navigation_version + 2,
        "Removing the wall must restore walkability with another local update")

    main.nav.rebuild()
    main.flow.rebuild()
    main.supply.rebuild()
    var flow_snapshot_wait := 0
    while not main.flow.is_current():
        await ticks(1)
        flow_snapshot_wait += 1
        assert(flow_snapshot_wait < 180,
            "The asynchronous FlowField must publish before road invalidation is measured")
    var road_nav_version: int = int(main.nav.version)
    var road = main.build.place_raw("road", navigation_probe_cell)
    assert(not main.nav._dirty and main.nav._dirty_cells.is_empty()
        and main.nav.version == road_nav_version,
        "Placing a non-blocking road must not invalidate the navigation grid")
    assert(not main.flow._dirty,
        "Placing a road must not trigger a full enemy flow-field rebuild")
    assert(main.supply._dirty,
        "Placing a road must still invalidate Keep-rooted logistics connectivity")
    await ticks(2)
    assert(not main.supply._dirty,
        "The logistics graph must rebuild after a road is placed")
    assert(main.build.demolish_at(navigation_probe_cell),
        "The non-blocking road probe must be removable")
    assert(not main.nav._dirty and main.nav._dirty_cells.is_empty()
        and not main.flow._dirty and main.supply._dirty,
        "Removing a road must invalidate logistics only, not pathfinding")

    assert(main.enemy_keep != null and is_instance_valid(main.enemy_keep),
        "Frontier must place its campaign stronghold")
    var stronghold_has_reachable_approach := false
    for cell in main.enemy_keep.cells():
        for direction in DIRS4:
            if reachable.has(cell + direction):
                stronghold_has_reachable_approach = true
                break
        if stronghold_has_reachable_approach:
            break
    assert(stronghold_has_reachable_approach,
        "The Frontier stronghold must border the starting settlement's reachable terrain")

    # Generate the same profile again and compare every terrain cell and resource placement.
    var mirror = world_script.new()
    mirror.generate_resource_nodes = false
    root.add_child(mirror)
    await process_frame
    for y in world_config.map_size:
        for x in world_config.map_size:
            var cell := Vector2i(x, y)
            assert(mirror.tile_type_at(cell) == world.tile_type_at(cell),
                "Terrain generation must be deterministic at %s" % cell)
            assert(mirror.region_id(cell) == world.region_id(cell),
                "Biome assignment must be deterministic at %s" % cell)
    assert(resource_signature(mirror) == resource_signature(world),
        "Resource placement must be deterministic for a matching seed/profile")
    assert(wildlife_signature(mirror) == wildlife_signature(world),
        "Wildlife distribution must be deterministic for a matching seed/profile")
    assert(wildlife_signature(world) == reference_wildlife_signature(world),
        "Bounded wildlife selection must preserve the sorted greedy placement result")
    assert(decoration_signature(mirror) == decoration_signature(world),
        "Biome decoration and landmark placement must be deterministic for a matching seed/profile")

    print("PASS: Frontier dimensions, five regions, biome dressing, five landmarks, resources, iron veins, Keep claim, reachability and deterministic generation")
    mirror.queue_free()
    main.queue_free()
    quit()
