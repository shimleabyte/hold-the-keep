extends SceneTree
## Deterministic rendered acceptance for the physical rival workforce.
## Produces gameplay captures and a short worker-lifecycle GIF under GL Compatibility.

const OUTPUT_DIR := "/tmp/hold-the-keep-rival-workforce-qa"
const FRAME_DIR := OUTPUT_DIR + "/frames"

var _tree_script: GDScript
var _rock_script: GDScript
var _iron_ore_script: GDScript

var _main: Node2D
var _keep: Node2D
var _civilization: RefCounted
var _worker: Node2D
var _frame_index := 0
var _frame_log: Array[String] = []


func _fail(message: String) -> void:
    push_error("RIVAL_WORKFORCE_RENDER_QA_FAIL: " + message)
    quit(1)


func _capture(name: String, camera_center: Vector2, zoom_value: float, record_frame: bool = false) -> void:
    _main.player.global_position = camera_center
    _main.player.camera.zoom = Vector2.ONE * zoom_value
    await process_frame
    await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    if image == null or image.is_empty():
        _fail("Gameplay viewport returned an empty image for " + name)
        return
    var output_path := "%s/%s.png" % [OUTPUT_DIR, name]
    if image.save_png(output_path) != OK:
        _fail("Could not save rendered capture " + output_path)
        return
    if record_frame:
        _frame_index += 1
        var frame_path := "%s/%02d.png" % [FRAME_DIR, _frame_index]
        if image.save_png(frame_path) != OK:
            _fail("Could not save animation frame " + frame_path)
            return
        _frame_log.append("%s state=%s cargo=%s position=%s" % [
            name, str(_worker.get("_state")), str(_worker.get("carry")), str(_worker.position)
        ])
    print("RIVAL_WORKFORCE_RENDER_CAPTURE ", output_path)


func _advance(seconds: float) -> void:
    _civilization.call("advance", seconds)
    await physics_frame


func _initialize() -> void:
    var output_error := DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
    if output_error != OK and output_error != ERR_ALREADY_EXISTS:
        _fail("Could not create rendered QA output directory")
        return
    var frame_error := DirAccess.make_dir_recursive_absolute(FRAME_DIR)
    if frame_error != OK and frame_error != ERR_ALREADY_EXISTS:
        _fail("Could not create rendered QA frame directory")
        return

    OS.set_environment("HTK_AUTO_START_GAME", "1")
    OS.set_environment("HTK_AUTO_RESOLVE_EVENTS", "1")
    await process_frame

    # These gameplay scripts reference project autoloads. Load them only after
    # the SceneTree has initialized the autoload nodes; preloading them at script
    # parse time causes unresolved Events identifiers and invalid GDScript resources.
    _tree_script = load("res://scripts/entities/resource_tree.gd") as GDScript
    _rock_script = load("res://scripts/entities/rock.gd") as GDScript
    _iron_ore_script = load("res://scripts/entities/iron_ore.gd") as GDScript
    if _tree_script == null or _rock_script == null or _iron_ore_script == null:
        _fail("Could not load gameplay resource scripts after autoload initialization")
        return

    var world_config: Node = root.get_node_or_null("WorldConfig")
    if world_config == null or not bool(world_config.call("apply_profile", "classic")):
        _fail("Could not initialize the deterministic Classic profile")
        return
    world_config.set("world_seed", 1337)

    var main_resource := load("res://scenes/main.tscn") as PackedScene
    if main_resource == null:
        _fail("Could not load the gameplay scene")
        return
    _main = main_resource.instantiate() as Node2D
    root.add_child(_main)
    current_scene = _main
    for _frame in 6:
        await process_frame

    if _main.player == null or _main.world == null or _main.nav == null:
        _fail("Gameplay did not finish initializing")
        return

    var clock: Node = root.get_node_or_null("GameClock")
    if clock != null:
        clock.set_process(false)
    _main.player.hide()
    _main.player.set_process(false)
    _main.player.set_physics_process(false)
    _main.player.camera.position_smoothing_enabled = false
    _main.player.camera.offset = Vector2.ZERO
    # Campaign strongholds can spawn near a map edge. Expand capture-only camera
    # limits so worker close-ups can center on their real world positions.
    var map_pixels: Vector2i = _main.world.get("pixel_size")
    _main.player.camera.limit_left = -map_pixels.x
    _main.player.camera.limit_top = -map_pixels.y
    _main.player.camera.limit_right = map_pixels.x * 2
    _main.player.camera.limit_bottom = map_pixels.y * 2

    # The fixture captures the game world, not HUD coverage. Hide only
    # CanvasLayers; gameplay actors, structures, resources and world rendering
    # remain active and unchanged.
    for child in _main.get_children():
        if child is CanvasLayer:
            child.hide()

    var campaign: Node = _main.get("campaign")
    _keep = campaign.call("current_target_node") as Node2D if campaign != null else null
    if _keep == null:
        _fail("The deterministic Classic campaign did not create a rival stronghold")
        return
    _keep.set_process(false)
    _civilization = _keep.get("civilization") as RefCounted
    if _civilization == null:
        _fail("The rival stronghold does not own its civilization simulation")
        return
    # This is a renderer acceptance fixture, not a player-visibility test.
    # Hiding the overlay exposes the real map and worker sprites without editing
    # explored cells or changing the production fog-of-war rules.
    var fog: CanvasItem = _main.get("fog") as CanvasItem
    if fog != null:
        fog.hide()

    # Complete the first production workplace through the actual rival economy.
    for _second in 24:
        await _advance(1.0)
    if not bool(_civilization.call("_has_active_structure", "lumber_camp")):
        _fail("The deterministic rival opening did not complete its Lumber Camp")
        return

    # Add the other existing workplace entities through the civilization's own
    # placement path so the overview contains the full physical workforce base.
    for workplace_id: String in ["farm", "quarry", "forge"]:
        if not bool(_civilization.call("_has_active_structure", workplace_id)):
            var build_cell: Vector2i = _civilization.call("_find_build_site", workplace_id)
            if build_cell.x < 0 or not bool(_civilization.call("_spawn_structure", workplace_id, build_cell)):
                _fail("Could not place the existing rival workplace " + workplace_id)
                return
    _civilization.set("technology_tier", 1)
    _keep.set("faction_id", "ashen_host")
    var labor: Dictionary = _civilization.call("labor_allocation")
    _civilization.call("_sync_physical_workers", labor)
    await physics_frame

    var rival_workers: Array[Node] = []
    for worker_node: Node in get_nodes_in_group("enemy_economic_workers"):
        if is_instance_valid(worker_node) and worker_node.get("civilization") == _civilization:
            rival_workers.append(worker_node)
    if rival_workers.is_empty():
        _fail("No physical rival workers were spawned for the rendered scenario")
        return
    _check_limits(rival_workers, labor)

    # Pan inward from the Classic map's lower-left rival stronghold so the
    # settlement and its four workplaces share the camera instead of empty map.
    var overview_center: Vector2 = _keep.global_position + Vector2(140, -110)
    await _capture("overview-rival-settlement", overview_center, 0.8)
    print("RIVAL_WORKFORCE_OVERVIEW workplaces=", _civilization.get("structures").size(),
        " workers=", rival_workers.size(), " labor=", labor)

    # Inspect a woodcutter's genuine reservation, travel, work animation, cargo,
    # return trip and ledger delivery in the actual gameplay viewport.
    for worker_node: Node in rival_workers:
        if String(worker_node.get("role")) == "lumber_camp":
            _worker = worker_node as Node2D
            break
    if _worker == null:
        _fail("No lumber-camp worker was assigned in the rendered scenario")
        return

    for _step in 120:
        await _advance(1.0)
        if int(_worker.get("_state")) == 1 and _worker.get("_target") != null:
            break
    if int(_worker.get("_state")) != 1 or _worker.get("_target") == null:
        var wood_created: bool = await _ensure_resource_node("wood", _worker)
        if not wood_created:
            _fail("Could not place a reachable tree for the woodcutter acceptance")
            return
        await _advance(1.0)
    if int(_worker.get("_state")) != 1 or _worker.get("_target") == null:
        _fail("Woodcutter did not enter the reserved-resource travel state after deterministic fallback")
        return
    for frame_index in 4:
        await _advance(1.0)
        var travel_target: Node2D = _worker.get("_target") as Node2D
        var travel_focus := _worker.global_position
        if travel_target != null and is_instance_valid(travel_target):
            travel_focus = (_worker.global_position + travel_target.global_position) * 0.5
        await _capture("woodcutter-travel-%02d" % frame_index, travel_focus, 1.8, true)

    for _step in 80:
        if int(_worker.get("_state")) == 2:
            break
        await _advance(1.0)
    if int(_worker.get("_state")) != 2:
        _fail("Woodcutter did not reach the resource-work state")
        return
    for frame_index in 6:
        await _advance(1.0)
        var harvest_target: Node2D = _worker.get("_target") as Node2D
        var harvest_focus := _worker.global_position
        if harvest_target != null and is_instance_valid(harvest_target):
            harvest_focus = (_worker.global_position + harvest_target.global_position) * 0.5
        await _capture("woodcutter-harvest-%02d" % frame_index, harvest_focus, 1.8, true)
        if int(_worker.get("carry")) > 0:
            break
    if int(_worker.get("carry")) <= 0:
        _fail("Woodcutter did not visibly collect resource cargo")
        return

    var wood_before: float = float(_civilization.get("resources").get("wood", 0.0))
    await _capture("woodcutter-carrying", _worker.global_position, 2.0, true)
    _worker.call("_begin_return_to_keep")
    if int(_worker.get("_state")) != 4:
        _fail("Worker with harvested cargo did not begin its return trip")
        return
    for frame_index in 5:
        await _advance(1.0)
        await _capture("woodcutter-hauling-%02d" % frame_index, _worker.global_position, 2.0, true)

    var delivered := false
    for _step in 80:
        await _advance(1.0)
        if int(_worker.get("carry")) == 0 and float(_civilization.get("resources").get("wood", 0.0)) > wood_before:
            delivered = true
            break
    if not delivered:
        _fail("Woodcutter cargo did not reach the owning stronghold ledger")
        return
    await _capture("woodcutter-delivery", _keep.global_position, 1.6, true)

    # Capture the other visible professions in their real job states.
    _keep.set("faction_id", "fen_cult")
    labor = _civilization.call("labor_allocation")
    _civilization.call("_sync_physical_workers", labor)
    await physics_frame
    var farmer: Node2D
    for worker_node: Node in get_nodes_in_group("enemy_economic_workers"):
        if is_instance_valid(worker_node) and worker_node.get("civilization") == _civilization and String(worker_node.get("role")) == "farm":
            farmer = worker_node as Node2D
            break
    var farmer_state_snapshot := -1
    var farmer_cargo_snapshot := 0
    if farmer != null:
        await _advance(1.0)
        for frame_index in 5:
            await _advance(1.0)
            if not is_instance_valid(farmer):
                break
            await _capture("farmer-work-%02d" % frame_index, farmer.global_position, 2.0)
        if is_instance_valid(farmer):
            farmer_state_snapshot = int(farmer.get("_state"))
            farmer_cargo_snapshot = int(farmer.get("carry"))
    else:
        _fail("Farm workers were not assigned under the farm-first doctrine")
        return

    _keep.set("faction_id", "ashen_host")
    labor = _civilization.call("labor_allocation")
    _civilization.call("_sync_physical_workers", labor)
    await physics_frame
    var miner: Node2D
    var forge_worker: Node2D
    for worker_node: Node in get_nodes_in_group("enemy_economic_workers"):
        if not is_instance_valid(worker_node) or worker_node.get("civilization") != _civilization:
            continue
        if String(worker_node.get("role")) == "quarry" and miner == null:
            miner = worker_node as Node2D
        if String(worker_node.get("role")) == "forge" and forge_worker == null:
            forge_worker = worker_node as Node2D
    if miner == null or forge_worker == null:
        _fail("Tier II rival doctrine did not staff both Quarry and Forge workers")
        return
    # Some deterministic map seeds have no suitable natural node inside the
    # stronghold's allowed local radius. Add a real resource entity in the same
    # region only when the natural search cannot supply this existing workplace.
    for _step in 80:
        await _advance(1.0)
        if forge_worker.get("_target") != null:
            break
    if forge_worker.get("_target") == null:
        var iron_created: bool = await _ensure_resource_node("iron", forge_worker)
        if not iron_created:
            _fail("Could not place a reachable iron node for the Tier II Forge acceptance")
            return
        await _advance(1.0)

    for _step in 80:
        if int(forge_worker.get("_state")) == 2:
            break
        await _advance(1.0)
    var forge_target: Node2D = forge_worker.get("_target") as Node2D
    if int(forge_worker.get("_state")) != 2 or forge_target == null or String(forge_target.get("yield_kind")) != "iron":
        _fail("Tier II Forge worker did not reach and reserve an actual iron resource node")
        return
    var forge_focus: Vector2 = (forge_worker.global_position + forge_target.global_position) * 0.5
    await _capture("tier-two-forge-iron-work", forge_focus, 1.8)
    var forge_harvested := false
    for harvest_step in 16:
        await _advance(1.0)
        if harvest_step % 4 == 0:
            forge_focus = (forge_worker.global_position + forge_target.global_position) * 0.5
            await _capture("tier-two-forge-harvest-%02d" % harvest_step, forge_focus, 1.8)
        if int(forge_worker.get("carry")) > 0:
            forge_harvested = true
            break
    if not forge_harvested or String(forge_worker.get("carry_kind")) != "iron":
        _fail("Tier II Forge worker did not harvest iron into physical cargo")
        return

    for _step in 80:
        if miner.get("_target") != null:
            break
        await _advance(1.0)
    if miner.get("_target") == null:
        var stone_created: bool = await _ensure_resource_node("stone", miner)
        if not stone_created:
            _fail("Could not place a reachable stone node for the Quarry acceptance")
            return
        await _advance(1.0)
    for _step in 80:
        if int(miner.get("_state")) == 2:
            break
        await _advance(1.0)
    var quarry_target: Node2D = miner.get("_target") as Node2D
    if int(miner.get("_state")) != 2 or quarry_target == null or String(quarry_target.get("yield_kind")) != "stone":
        _fail("Quarry miner did not reach and reserve an actual stone resource node")
        return
    var quarry_focus: Vector2 = (miner.global_position + quarry_target.global_position) * 0.5
    await _capture("quarry-stone-work", quarry_focus, 1.8)
    var quarry_harvested := false
    for harvest_step in 8:
        await _advance(1.0)
        if int(miner.get("carry")) > 0:
            quarry_harvested = true
            break
    if not quarry_harvested or String(miner.get("carry_kind")) != "stone":
        _fail("Quarry miner did not harvest stone into physical cargo")
        return

    var manifest := FileAccess.open(OUTPUT_DIR + "/worker-lifecycle.txt", FileAccess.WRITE)
    if manifest != null:
        manifest.store_line("seed=1337 profile=classic")
        manifest.store_line("woodcutter: reserved target -> travel -> work -> cargo -> return -> ledger delivery")
        manifest.store_line("farmer state=%s cargo=%s" % [str(farmer_state_snapshot), str(farmer_cargo_snapshot)])
        manifest.store_line("quarry state=%s target=%s harvested=%s" % [str(miner.get("_state")), str(quarry_target != null), str(quarry_harvested)])
        manifest.store_line("forge tier=%s state=%s target=%s harvested=%s" % [
            str(_civilization.get("technology_tier")), str(forge_worker.get("_state")), str(forge_target != null), str(forge_harvested)
        ])
        for line in _frame_log:
            manifest.store_line(line)
        manifest.close()

    print("PASS: rival workforce rendered lifecycle captures saved to ", OUTPUT_DIR)
    quit(0)


func _ensure_resource_node(kind: String, worker: Node2D) -> bool:
    var world: Node = _main.get("world")
    var nav: Node = _main.get("nav")
    var territory: Node = _main.get("territory")
    var event_bus: Node = root.get_node_or_null("Events")
    var owner_region := String(_keep.get("region_id"))
    var worker_cell: Vector2i = nav.call("cell_of", worker.global_position)
    var claim_radius := float(_keep.get("claim_radius"))
    var local_radius := maxf(claim_radius + 6.0, claim_radius * 4.0) * float(world.get("tile_size"))

    for radius in range(2, 20):
        for y in range(-radius, radius + 1):
            for x in range(-radius, radius + 1):
                if maxi(absi(x), absi(y)) != radius:
                    continue
                var cell := worker_cell + Vector2i(x, y)
                if not bool(world.call("is_buildable", cell)) or world.get("occupied").has(cell):
                    continue
                if String(world.call("region_id", cell)) != owner_region:
                    continue
                if String(territory.call("owner_at", cell)) in ["player", "contested"]:
                    continue
                var node_position: Vector2 = nav.call("center_of", cell)
                if _keep.position.distance_to(node_position) > local_radius:
                    continue
                var approach_cells: Array[Vector2i] = [cell]
                var approach_path: PackedVector2Array = nav.call("path_adjacent", worker.global_position, approach_cells)
                if approach_path.is_empty() or not bool(worker.call("_path_avoids_player_territory", approach_path)):
                    continue

                var resource_node: Node2D
                match kind:
                    "wood":
                        resource_node = _tree_script.new() as Node2D
                    "stone":
                        resource_node = _rock_script.new() as Node2D
                    "iron":
                        resource_node = _iron_ore_script.new() as Node2D
                    _:
                        return false
                if resource_node == null:
                    return false
                resource_node.name = "RivalWorkforceQA_%s_%d_%d" % [kind, cell.x, cell.y]
                resource_node.position = node_position
                world.call("_register_resource_node", resource_node, cell)
                if event_bus != null:
                    event_bus.emit_signal("resource_occupancy_changed", cell)
                await physics_frame
                return true
    return false


func _check_limits(workers: Array[Node], labor: Dictionary) -> void:
    var counts: Dictionary = {}
    for worker: Node in workers:
        var role: String = String(worker.get("role"))
        counts[role] = int(counts.get(role, 0)) + 1
        if worker.is_in_group("villagers") or worker.is_in_group("enemy_garrison"):
            _fail("Rival economic workers leaked into player civilian or military groups")
            return
    for workplace_id: String in ["lumber_camp", "farm", "quarry", "forge"]:
        if int(counts.get(workplace_id, 0)) > 2 or int(counts.get(workplace_id, 0)) != int(labor.get(workplace_id, 0)):
            _fail("Worker staffing does not respect the existing two-per-workplace assignment for " + workplace_id)
            return
    if workers.size() > 8:
        _fail("Rendered workforce exceeded the existing eight-citizen limit")
        return
