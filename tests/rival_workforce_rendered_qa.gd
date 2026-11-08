extends SceneTree
## Deterministic rendered acceptance for the integrated rival workforce.
## Uses the real campaign scene, rival civilization, structures, resource nodes,
## NavGrid and worker actors. Extra completed workplaces/research are controlled
## test fixtures; no production values or gameplay costs are changed.

const OUTPUT_DIR := "/tmp/hold-the-keep-rival-workforce-qa"
var tree_script: Script
var rock_script: Script
var iron_script: Script
const DIRS4: Array[Vector2i] = [
    Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]

var failed := false
var world_config: Node
var game_clock: Node
var main_scene: Node2D
var keep: Node2D
var civilization: RefCounted
var navigation: Node
var world: Node
var territory: Node
var workers: Array[Node2D] = []
var capture_count := 0


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failed = true
    push_error("RIVAL_WORKFORCE_QA_FAIL: " + message)


func _trace(worker: Node2D, stage: String, delivery: String = "not_attempted",
        retirement: String = "none") -> void:
    if worker == null or not is_instance_valid(worker):
        return
    var target: Variant = worker.get("_target")
    var target_cell := Vector2i(-1, -1)
    var target_kind := "none"
    if target != null and is_instance_valid(target):
        target_cell = Vector2i(target.get("resource_cell"))
        target_kind = String(target.get("yield_kind"))
    var route: PackedVector2Array = worker.get("_path")
    var route_state := "no_path"
    if not route.is_empty():
        route_state = "path_%d_of_%d" % [int(worker.get("_path_index")), route.size()]
    var workplace: Variant = worker.get("workplace")
    var workplace_label := String(worker.get("workplace_id"))
    if workplace == null or not is_instance_valid(workplace):
        workplace_label += "_destroyed"
    print("RIVAL_WORKER_TRACE stage=%s id=%d owner=%s workplace=%s task=%s target=%s:%s cargo=%s:%d route=%s delivery=%s retirement=%s" % [
        stage, worker.get_instance_id(), String(keep.get("stronghold_id")),
        workplace_label, str(worker.get("_state")), target_kind, str(target_cell),
        String(worker.get("carry_kind")), int(worker.get("carry")), route_state,
        delivery, retirement
    ])


func _capture(label: String, focus: Vector2, zoom: float) -> void:
    var player: Node2D = main_scene.get("player") as Node2D
    var camera: Camera2D = player.get("camera") as Camera2D
    player.global_position = focus
    camera.position_smoothing_enabled = false
    camera.zoom = Vector2(zoom, zoom)
    camera.reset_smoothing()
    for _frame in range(3):
        await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    if image == null or image.is_empty():
        _check(false, "Rendered viewport must not be empty: " + label)
        return
    var colors: Dictionary = {}
    for y in range(0, image.get_height(), 24):
        for x in range(0, image.get_width(), 24):
            colors[image.get_pixel(x, y)] = true
    _check(colors.size() > 8, "Capture must contain a rendered gameplay scene: " + label)
    var path := "%s/%02d-%s.png" % [OUTPUT_DIR, capture_count + 1, label]
    var error := image.save_png(path)
    _check(error == OK, "Could not save capture: " + path)
    capture_count += 1
    print("RIVAL_WORKER_CAPTURE label=%s path=%s size=%s sampled_colors=%d" % [
        label, path, str(image.get_size()), colors.size()
    ])


func _tick_one(worker: Node2D, steps: int) -> void:
    for _step in range(steps):
        if worker == null or not is_instance_valid(worker):
            return
        worker.call("tick", 0.25)
        await process_frame


func _tick_all(steps: int) -> void:
    for _step in range(steps):
        for worker: Node2D in workers:
            if is_instance_valid(worker):
                worker.call("tick", 0.25)
        await process_frame


func _workers_for(role_id: String) -> Array[Node2D]:
    var found: Array[Node2D] = []
    for value: Node in get_nodes_in_group("enemy_economic_workers"):
        var worker := value as Node2D
        if worker != null and is_instance_valid(worker) and worker.get("civilization") == civilization                 and String(worker.get("role")) == role_id:
            found.append(worker)
    return found


func _find_free_cell(origin: Vector2, reserved: Dictionary) -> Vector2i:
    var origin_cell: Vector2i = navigation.cell_of(origin)
    var owner_region := String(keep.get("region_id"))
    var radius_limit := maxf(float(keep.get("claim_radius")) * 4.0,
        float(keep.get("claim_radius")) + 6.0)
    for radius in range(3, 20):
        for y in range(-radius, radius + 1):
            for x in range(-radius, radius + 1):
                if maxi(absi(x), absi(y)) != radius:
                    continue
                var cell := origin_cell + Vector2i(x, y)
                if not bool(world_config.call("is_valid_cell", cell)) or reserved.has(cell):
                    continue
                if not world.is_buildable(cell) or world.occupied.has(cell):
                    continue
                if String(world.region_id(cell)) != owner_region:
                    continue
                var ownership := String(territory.call("owner_at", cell))
                if ownership == "player" or ownership == "contested":
                    continue
                if keep.position.distance_to(navigation.center_of(cell))                         > radius_limit * float(int(world_config.get("tile_size"))):
                    continue
                return cell
    return Vector2i(-1, -1)


func _spawn_resource(script: Script, origin: Vector2, reserved: Dictionary) -> Node2D:
    var cell := _find_free_cell(origin, reserved)
    if cell.x < 0:
        _check(false, "No legal resource fixture cell near " + str(origin))
        return null
    reserved[cell] = true
    var node := script.new() as Node2D
    node.position = Vector2(
        float(cell.x * int(world_config.get("tile_size"))) + int(world_config.get("tile_size")) / 2.0,
        float((cell.y + 1) * int(world_config.get("tile_size")))
    )
    world.call("_register_resource_node", node, cell)
    await process_frame
    node.set("_hp", 1)
    node.queue_redraw()
    navigation.call("rebuild")
    print("RIVAL_WORKER_RESOURCE_FIXTURE kind=%s cell=%s hp=1" % [
        String(node.get("yield_kind")), str(cell)
    ])
    return node


func _add_workplace(id: String) -> Node2D:
    var anchor: Vector2i = civilization.call("_find_build_site", id)
    _check(anchor.x >= 0, "Need legal placement for test workplace: " + id)
    if anchor.x < 0:
        return null
    var spawned := bool(civilization.call("_spawn_structure", id, anchor))
    _check(spawned, "Rival structure system must spawn completed " + id)
    if not spawned:
        return null
    for value: Node in civilization.get("structures"):
        if is_instance_valid(value) and String(value.get("structure_id")) == id:
            return value as Node2D
    return null


func _refresh_workers() -> void:
    workers.clear()
    for value: Node in get_nodes_in_group("enemy_economic_workers"):
        var worker := value as Node2D
        if worker != null and is_instance_valid(worker) and worker.get("civilization") == civilization:
            workers.append(worker)
    workers.sort_custom(func(a: Node2D, b: Node2D) -> bool:
        return a.get_instance_id() < b.get_instance_id()
    )


func _remove_local_garrison() -> void:
    for guard: Node in get_nodes_in_group("enemy_garrison"):
        if is_instance_valid(guard) and Vector2(guard.get("guard_origin")).distance_to(keep.position) < 1.0:
            guard.queue_free()
    await process_frame
    await process_frame


func _initialize() -> void:
    print("RIVAL_WORKFORCE_RENDER_QA_START seed=1337 profile=classic")
    var directory_error := DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
    _check(directory_error == OK or directory_error == ERR_ALREADY_EXISTS,
        "Rendered QA output directory must be writable")
    OS.set_environment("HTK_AUTO_START_GAME", "1")
    OS.set_environment("HTK_AUTO_RESOLVE_EVENTS", "1")
    world_config = root.get_node_or_null("WorldConfig")
    game_clock = root.get_node_or_null("GameClock")
    _check(world_config != null and game_clock != null,
        "WorldConfig and GameClock autoloads must be available in the running SceneTree")
    if world_config == null or game_clock == null:
        quit(1)
        return
    _check(bool(world_config.call("apply_profile", "classic")), "Classic profile must be available")
    world_config.set("world_seed", 1337)
    await process_frame

    # These entity scripts reference project autoloads such as Events. Load them
    # only after the SceneTree has initialized the project's autoload singletons.
    tree_script = load("res://scripts/entities/resource_tree.gd")
    rock_script = load("res://scripts/entities/rock.gd")
    iron_script = load("res://scripts/entities/iron_ore.gd")
    _check(tree_script != null and rock_script != null and iron_script != null,
        "Resource-node scripts must compile after autoload initialization")
    if tree_script == null or rock_script == null or iron_script == null:
        quit(1)
        return

    main_scene = load("res://scenes/main.tscn").instantiate() as Node2D
    _check(main_scene != null, "Main gameplay scene must instantiate")
    if main_scene == null:
        quit(1)
        return
    root.add_child(main_scene)
    current_scene = main_scene
    for _frame in range(8):
        await process_frame

    var campaign: Node = main_scene.get("campaign")
    keep = campaign.call("current_target_node") as Node2D if campaign != null else null
    _check(keep != null, "Classic campaign must expose its rival stronghold")
    if keep == null:
        quit(1)
        return
    civilization = keep.get("civilization") as RefCounted
    world = main_scene.get("world")
    navigation = main_scene.get("nav")
    territory = main_scene.get("territory")
    _check(civilization != null and world != null and navigation != null and territory != null,
        "Civilization, world, NavGrid and territory must be initialized")
    if civilization == null or world == null or navigation == null or territory == null:
        quit(1)
        return
    keep.set_process(false)
    game_clock.set_process(false)
    navigation.call("rebuild")
    territory.call("rebuild")
    _check(int(navigation.get("version")) > 0, "NavGrid must be initialized")

    # Use the normal AI and paid opening build for the first Lumber Camp.
    for _tick in range(24):
        civilization.call("advance", 1.0)
        await process_frame
    _check(bool(civilization.call("_has_active_structure", "lumber_camp")),
        "Normal rival opening must complete its paid Lumber Camp")
    if not bool(civilization.call("_has_active_structure", "lumber_camp")):
        quit(1)
        return
    var active_construction: Dictionary = civilization.get("construction")
    active_construction.clear()
    await _remove_local_garrison()

    # The test uses real rival workplace entities and the live worker synchronizer.
    # Extra completed structures/research only provide deterministic role coverage.
    var farm := _add_workplace("farm")
    var quarry := _add_workplace("quarry")
    var forge := _add_workplace("forge")
    var lumber: Node2D = null
    for value: Node in civilization.get("structures"):
        if is_instance_valid(value) and String(value.get("structure_id")) == "lumber_camp":
            lumber = value as Node2D
            break
    _check(farm != null and quarry != null and forge != null and lumber != null,
        "All four completed rival workplaces must exist")
    if farm == null or quarry == null or forge == null or lumber == null:
        quit(1)
        return

    var reserved_cells: Dictionary = {}
    var test_tree := await _spawn_resource(tree_script, lumber.position, reserved_cells)
    var test_rock := await _spawn_resource(rock_script, quarry.position, reserved_cells)
    var test_ore := await _spawn_resource(iron_script, forge.position, reserved_cells)
    _check(test_tree != null and test_rock != null and test_ore != null,
        "Deterministic tree, stone and iron nodes must be placed within the rival region")
    navigation.call("rebuild")

    civilization.set("technology_tier", 0)
    var labor: Dictionary = civilization.call("labor_allocation")
    _check(int(labor.get("available", 0)) == 8,
        "Eight citizens must be available in the controlled full-workforce fixture")
    for role_id in ["lumber_camp", "farm", "quarry", "forge"]:
        _check(int(labor.get(role_id, 0)) == 2,
            "Completed " + role_id + " must receive exactly two workers when eight are available")
    civilization.call("_sync_physical_workers", labor)
    await process_frame
    await process_frame
    _refresh_workers()
    _check(workers.size() == 8, "Visible worker count must equal the derived eight-worker allocation")
    for worker: Node2D in workers:
        _check(not worker.is_in_group("villagers") and not worker.is_in_group("enemy_garrison"),
            "Rival workers must remain outside player civilian and army groups")
        _trace(worker, "spawned")

    var woodcutters := _workers_for("lumber_camp")
    var farmers := _workers_for("farm")
    var miners := _workers_for("quarry")
    var forge_workers := _workers_for("forge")
    _check(woodcutters.size() == 2 and farmers.size() == 2 and miners.size() == 2 and forge_workers.size() == 2,
        "Every completed workplace must receive its derived worker count")
    if woodcutters.size() != 2 or farmers.size() != 2 or miners.size() != 2 or forge_workers.size() != 2:
        quit(1)
        return

    var wood_worker: Node2D = woodcutters[0]
    # Save the worker's workplace position before any simulation steps. This
    # baseline proves actual movement instead of comparing two post-arrival frames.
    var wood_start := wood_worker.global_position
    await _tick_all(8)
    var claimed: Dictionary = {}
    var claim_count := 0
    for worker: Node2D in workers:
        var target: Variant = worker.get("_target")
        if target == null or not is_instance_valid(target):
            continue
        var id: int = target.get_instance_id()
        _check(not claimed.has(id), "Workers must reserve different available resource nodes")
        claimed[id] = worker.get_instance_id()
        claim_count += 1
        var path: PackedVector2Array = worker.get("_path")
        _check(bool(worker.call("_path_avoids_player_territory", path)),
            "A rival worker route must avoid player and contested territory")
    _check(claim_count >= 3, "Lumber, quarry and forge workers must establish physical resource claims")
    await _capture("01-settlement-wide", keep.position, 0.58)

    var wood_target: Variant = wood_worker.get("_target")
    if wood_target == null or not is_instance_valid(wood_target):
        wood_worker.call("_tick_idle")
        wood_target = wood_worker.get("_target")
    _check(wood_target != null and is_instance_valid(wood_target),
        "Woodcutter must reserve a real resource tree")
    if wood_target == null or not is_instance_valid(wood_target):
        quit(1)
        return
    var wood_hp_before := int(wood_target.get("_hp"))
    _trace(wood_worker, "travel_to_tree")
    await _capture("02-woodcutter-travel-close", wood_worker.global_position, 1.8)
    var wood_harvested := false
    var wood_cargo := 0
    for _step in range(420):
        wood_worker.call("tick", 0.25)
        await process_frame
        if int(wood_target.get("_hp")) < wood_hp_before:
            wood_harvested = true
        if int(wood_worker.get("carry")) > 0:
            wood_cargo = int(wood_worker.get("carry"))
            break
    _check(wood_worker.global_position.distance_to(wood_start) > 2.0,
        "Woodcutter must physically travel to the resource node")
    _check(wood_harvested, "Woodcutter must damage a real tree node")
    _check(wood_cargo > 0 and wood_cargo <= 12, "Woodcutter cargo must be physical and bounded")
    _trace(wood_worker, "tree_harvested")
    await _capture("03-woodcutter-harvest-close", wood_worker.global_position, 1.8)

    # Trigger the same return transition used at carry capacity; the route and
    # delivery remain the production worker's own state machine.
    var wood_ledger_before := float(civilization.get("resources").get("wood", 0.0))
    wood_worker.call("_begin_return_to_keep")
    var home_path: PackedVector2Array = wood_worker.get("_path")
    _check(int(wood_worker.get("_state")) == 4 and not home_path.is_empty(),
        "Loaded worker must path back to its owning stronghold")
    _trace(wood_worker, "returning_to_owner", "pending")
    await _capture("04-return-to-stronghold-wide", keep.position, 0.68)
    for _step in range(420):
        if int(wood_worker.get("carry")) <= 0:
            break
        wood_worker.call("tick", 0.25)
        await process_frame
    var wood_ledger_after := float(civilization.get("resources").get("wood", 0.0))
    _check(int(wood_worker.get("carry")) == 0, "The owning stronghold must accept delivered cargo")
    _check(wood_ledger_after >= wood_ledger_before + wood_cargo,
        "Delivery must credit the correct rival resource ledger exactly once")
    _trace(wood_worker, "delivered", "credited_to_owner_ledger")

    var farmer: Node2D = farmers[0]
    await _tick_one(farmer, 32)
    _check(String(farmer.get("carry_kind")) == "food" and int(farmer.get("carry")) >= 3,
        "Farmer must visibly work and produce food cargo")
    _trace(farmer, "farm_cycle_completed")
    await _capture("05-farmer-working-close", farmer.global_position, 1.8)

    var miner: Node2D = miners[0]
    var stone_target: Variant = miner.get("_target")
    if stone_target == null or not is_instance_valid(stone_target) or String(stone_target.get("yield_kind")) != "stone":
        miner.call("_release_target")
        miner.call("_tick_idle")
        stone_target = miner.get("_target")
    _check(stone_target != null and is_instance_valid(stone_target)
        and String(stone_target.get("yield_kind")) == "stone",
        "Tier 0 quarry worker must target a real stone node")
    if stone_target != null and is_instance_valid(stone_target):
        var stone_hp_before := int(stone_target.get("_hp"))
        await _tick_one(miner, 120)
        _check(int(stone_target.get("_hp")) < stone_hp_before
            and String(miner.get("carry_kind")) == "stone",
            "Quarry miner must extract stone from the physical node")
        _trace(miner, "stone_harvested")
        await _capture("06-quarry-stone-mining-close", miner.global_position, 1.8)

    civilization.set("technology_tier", 1)
    var resources: Dictionary = civilization.get("resources")
    resources["iron"] = 4.0
    var quarry_kinds: Array = civilization.call("worker_resource_kinds", "quarry")
    _check(quarry_kinds.has("iron") and quarry_kinds.has("stone"),
        "Tier I quarry workers must unlock iron supply for the existing Forge construction cost")
    # Exercise the Quarry progression gate directly: before a Forge exists,
    # a Tier-I Quarry worker must prioritize the ore needed to pay its iron cost.
    var iron_worker: Node2D = miners[1]
    iron_worker.call("_release_target")
    iron_worker.set("_retry_timer", 0.0)
    iron_worker.set("carry_kind", "")
    iron_worker.set("carry", 0)
    iron_worker.set("_state", 0)
    iron_worker.call("_tick_idle")
    var iron_target: Variant = iron_worker.get("_target")
    _check(iron_target != null and is_instance_valid(iron_target)
        and String(iron_target.get("yield_kind")) == "iron",
        "Researched rival miner must reserve an actual iron node")
    if iron_target != null and is_instance_valid(iron_target):
        var iron_hp_before := int(iron_target.get("_hp"))
        await _tick_one(iron_worker, 160)
        _check(int(iron_target.get("_hp")) < iron_hp_before
            and String(iron_worker.get("carry_kind")) == "iron",
            "Researched rival miner must physically harvest iron")
        _trace(iron_worker, "iron_harvested")
        await _capture("07-forge-iron-mining-close", iron_worker.global_position, 1.8)

    # Full stock retains the complete worker cargo. A later retry transfers it once.
    var saved_wood := float(resources.get("wood", 0.0))
    resources["wood"] = float(civilization.call("resource_capacity", "wood"))
    wood_worker.set("carry_kind", "wood")
    wood_worker.set("carry", 4)
    wood_worker.call("_deposit_at_keep")
    _check(int(wood_worker.get("carry")) == 4 and int(wood_worker.get("_state")) == 5,
        "Full destination must retain cargo and use the timed storage-retry state")
    _trace(wood_worker, "destination_full", "retained_no_loss")
    resources["wood"] = saved_wood
    wood_worker.call("_deposit_at_keep")
    _check(int(wood_worker.get("carry")) == 0
        and is_equal_approx(float(resources.get("wood", 0.0)), saved_wood + 4.0),
        "A later delivery retry must credit exactly the retained cargo")
    _trace(wood_worker, "destination_recovered", "credited_once")

    # Close every approach tile around the stronghold to invalidate a return path.
    # Failed A* requests must be throttled; reopening the route must recover it.
    wood_worker.set("carry_kind", "wood")
    wood_worker.set("carry", 4)
    var keep_cells: Array[Vector2i] = keep.call("cells")
    var blocked_cells: Dictionary = {}
    for keep_cell in keep_cells:
        for direction in DIRS4:
            var adjacent := keep_cell + direction
            if bool(world_config.call("is_valid_cell", adjacent)) and not keep_cells.has(adjacent):
                navigation.get("astar").set_point_solid(adjacent, true)
                blocked_cells[adjacent] = true
    navigation.set("version", int(navigation.get("version")) + 1)
    wood_worker.set("position", lumber.position + Vector2(20.0, 0.0))
    wood_worker.call("_begin_return_to_keep")
    wood_worker.call("tick", 0.25)
    var retry_before := float(wood_worker.get("_retry_timer"))
    var blocked_path: PackedVector2Array = wood_worker.get("_path")
    _check(blocked_path.is_empty() and retry_before > 0.0,
        "Blocked route must preserve cargo and enter a timed retry")
    wood_worker.call("tick", 0.25)
    var retry_path: PackedVector2Array = wood_worker.get("_path")
    _check(float(wood_worker.get("_retry_timer")) < retry_before and retry_path.is_empty(),
        "Blocked route must not issue an expensive path request every frame")
    navigation.call("rebuild")
    wood_worker.call("tick", 0.25)
    var recovered_path: PackedVector2Array = wood_worker.get("_path")
    _check(not recovered_path.is_empty(), "Worker must recover a route after the obstruction clears")
    _trace(wood_worker, "route_recovered", "cargo_retained")
    await _capture("08-route-recovery-close", wood_worker.global_position, 1.8)

    # Do not allow final-hit bonuses or farm cycles to be truncated by carry clamp.
    wood_worker.call("_release_target")
    wood_worker.call("_tick_idle")
    var overflow_tree: Variant = wood_worker.get("_target")
    _check(overflow_tree != null and is_instance_valid(overflow_tree),
        "Cargo-bound test requires a reserved resource node")
    if overflow_tree != null and is_instance_valid(overflow_tree):
        var overflow_hp := int(overflow_tree.get("_hp"))
        wood_worker.set("carry_kind", "wood")
        wood_worker.set("carry", 10)
        wood_worker.call("_tick_resource_work", 0.25)
        _check(int(wood_worker.get("carry")) == 10 and int(overflow_tree.get("_hp")) == overflow_hp,
            "Woodcutter must return before harvesting a batch larger than remaining capacity")
        _trace(wood_worker, "cargo_capacity_guard", "no_harvest_loss")
    farmer.set("carry_kind", "food")
    farmer.set("carry", 10)
    farmer.call("_tick_farming", 4.8)
    _check(int(farmer.get("carry")) == 10,
        "Farmer must return before a food cycle exceeds remaining capacity")
    _trace(farmer, "farm_capacity_guard", "no_food_loss")

    # Ownership fixtures are deliberately local and deterministic. Use a
    # legal unoccupied cell inside the rival's own bounded work radius, then
    # toggle player-only and contested ownership to test the same runtime gate.
    var player_cell: Vector2i = _find_free_cell(keep.position, reserved_cells)
    _check(player_cell.x >= 0,
        "A free cell inside the rival region and worker radius must exist for ownership acceptance")
    if player_cell.x >= 0:
        var player_claims: Dictionary = territory.get("claimed_cells")
        var enemy_claims: Dictionary = territory.get("enemy_claimed_cells")
        var was_player_claimed: bool = player_claims.has(player_cell)
        var was_enemy_claimed: bool = enemy_claims.has(player_cell)
        enemy_claims.erase(player_cell)
        player_claims[player_cell] = true

        var player_tree := tree_script.new() as Node2D
        player_tree.position = Vector2(
            float(player_cell.x * int(world_config.get("tile_size"))) + int(world_config.get("tile_size")) / 2.0,
            float((player_cell.y + 1) * int(world_config.get("tile_size")))
        )
        world.call("_register_resource_node", player_tree, player_cell)
        await process_frame
        player_tree.set("worker", wood_worker)
        _check(not bool(wood_worker.call("_resource_cell_is_available", player_cell, player_tree)),
            "Rival worker must reject a resource in player-owned territory")

        enemy_claims[player_cell] = true
        _check(not bool(wood_worker.call("_resource_cell_is_available", player_cell, player_tree)),
            "Rival worker must reject contested territory")

        if not was_player_claimed:
            player_claims.erase(player_cell)
        if was_enemy_claimed:
            enemy_claims[player_cell] = true
        else:
            enemy_claims.erase(player_cell)
        territory.call("rebuild")
        print("RIVAL_WORKER_OWNERSHIP_GUARD cell=%s player_rejected=true contested_rejected=true" % str(player_cell))

    # The player army selector reads only player Villager entries from its own group.
    main_scene.get("army_command").call("clear_selection")
    var selection_rect := Rect2(wood_worker.global_position - Vector2(80.0, 80.0), Vector2(160.0, 160.0))
    main_scene.get("army_command").call("select_units_in_rect", selection_rect)
    var selected_units: Array = main_scene.get("army_command").get("selected_units")
    _check(not selected_units.has(wood_worker),
        "Rival economic workers must never become selectable through army commands")
    _trace(wood_worker, "army_selection_rejected")

    # Destroying the workplace releases its active resource claim and retires workers.
    wood_worker.call("_release_target")
    wood_worker.call("_tick_idle")
    var reserved_before_destroy: Variant = wood_worker.get("_target")
    var lumber_structure: Node2D = wood_worker.get("workplace") as Node2D
    if reserved_before_destroy == null or not is_instance_valid(reserved_before_destroy):
        wood_worker.call("_find_resource_target")
        reserved_before_destroy = wood_worker.get("_target")
    _trace(wood_worker, "workplace_destruction_imminent", "none", "workplace_destroyed")
    lumber_structure.call("take_damage", 9999)
    if reserved_before_destroy != null and is_instance_valid(reserved_before_destroy):
        _check(reserved_before_destroy.get("worker") != wood_worker,
            "Workplace destruction must release the worker's resource-node reservation")
    _check(bool(wood_worker.get("retiring")) or wood_worker.is_queued_for_deletion(),
        "Workers from a destroyed workplace must retire or return their cargo")
    await _capture("09-workplace-retirement-wide", keep.position, 0.68)

    var owned_workers: Array[Node2D] = []
    for worker: Node2D in get_nodes_in_group("enemy_economic_workers"):
        if is_instance_valid(worker) and worker.get("civilization") == civilization:
            owned_workers.append(worker)
    _trace(owned_workers[0] if not owned_workers.is_empty() else null,
        "stronghold_destruction_imminent", "none", "owning_stronghold_destroyed")
    keep.call("take_damage", 9999)
    await process_frame
    await process_frame
    var orphan_count := 0
    for worker: Node in get_nodes_in_group("enemy_economic_workers"):
        if is_instance_valid(worker) and worker.get("civilization") == civilization:
            orphan_count += 1
    _check(orphan_count == 0, "Stronghold destruction must remove all faction-owned runtime workers")
    for cell_value in world.get("resource_nodes_by_cell").keys():
        var node: Variant = world.call("resource_node_at", Vector2i(cell_value))
        if node == null or not is_instance_valid(node):
            continue
        var reserved_by: Variant = node.get("worker")
        if reserved_by != null and is_instance_valid(reserved_by) and workers.has(reserved_by):
            _check(false, "Stronghold destruction must not leave orphan resource reservations")
    print("RIVAL_WORKER_RETIREMENT owner_destroyed=true orphan_workers=%d" % orphan_count)
    print("RIVAL_WORKFORCE_RENDER_QA_SUMMARY seed=1337 captures=%d workers=%d functional_assertions=%s" % [
        capture_count, workers.size(), "FAILED" if failed else "PASSED"
    ])
    print("HUMAN_DESKTOP_PLAYTEST=NOT_PERFORMED")
    main_scene.queue_free()
    await process_frame
    if failed:
        quit(1)
        return
    print("PASS: rendered rival workforce lifecycle, physical harvest/delivery, cargo conservation, road recovery, ownership and retirement")
    quit(0)
