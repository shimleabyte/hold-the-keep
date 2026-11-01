extends SceneTree
## Frontier profile integration: deterministic regions, traversal, resources and Keep footprint.

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
        and world_config.map_size == 128
        and world_config.map_cells == 128 * 128,
        "Frontier profile must apply all 128x128 dimensions")
    assert(world_config.starting_claim_radius == 15.0
        and world_config.safe_radius == 12.0,
        "Frontier must apply the expanded starting footprint and clearing")

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(6)
    game_clock.set_process(false)

    var world = main.world
    var hud = get_first_node_in_group("hud")
    assert(hud != null, "The Frontier scene must create the HUD")
    hud._layout_viewport(Vector2(480, 270))
    await process_frame
    var frontier_map = hud._map_panel
    assert(frontier_map.position.x >= 0.0 and frontier_map.position.y >= 0.0
        and frontier_map.position.x + frontier_map.size.x <= 480.1
        and frontier_map.position.y + frontier_map.size.y <= 270.1,
        "The 128x128 strategic map must fit a compact viewport")
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

    var far_cell := Vector2i(127, 127)
    var far_index: int = world_config.cell_index(far_cell)
    main.fog.import_state({"cells": [far_index]})
    assert(main.fog.is_revealed_cell(far_cell),
        "Frontier fog data must accept the final valid row-major map index")
    var frontier_save: Dictionary = save_system.collect(main)
    assert(frontier_save["world"]["profile"] == "frontier"
        and int(frontier_save["world"]["map_size"]) == 128
        and save_system._valid_save(frontier_save),
        "A 128x128 Frontier save must retain valid world and fog metadata")
    var invalid_frontier_save := frontier_save.duplicate(true)
    invalid_frontier_save["fog"]["cells"].append(world_config.map_cells)
    assert(not save_system._valid_save(invalid_frontier_save),
        "Frontier save validation must reject fog indices outside the 128x128 map")

    var clearing_center := Vector2(world_config.map_size, world_config.map_size) * 0.5
    var clearing_radius := maxf(world_config.safe_radius + 7.0, float(world_config.map_size) * 0.15)
    for cell in world.occupied:
        var occupant = world.occupied[cell]
        if is_instance_valid(occupant) and occupant.is_in_group("resource_nodes"):
            assert(Vector2(cell).distance_to(clearing_center) >= clearing_radius,
                "Resource nodes must not clutter the protected starting clearing")

    var campaign_menu := get_first_node_in_group("pause_menu")
    assert(campaign_menu != null and campaign_menu._campaign_profile.get_item_count() == 2,
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
    for cell in world.occupied:
        var node = world.occupied[cell]
        if not is_instance_valid(node) or not node.is_in_group("resource_nodes"):
            continue
        var kind := String(node.yield_kind)
        resource_counts[kind] = int(resource_counts.get(kind, 0)) + 1
        var region: String = world.region_id(cell)
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

    print("PASS: Frontier dimensions, five regions, Ashen terrain, resources, iron veins, Keep claim, reachability and deterministic generation")
    mirror.queue_free()
    main.queue_free()
    quit()
