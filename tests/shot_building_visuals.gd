extends SceneTree
## Render the existing settlement at real gameplay zoom before and after visual progression work.
## The fixture changes presentation state only; it does not change placement or simulation rules.

const OUTPUT_DIR := "/tmp/hold-the-keep-building-visual-qa"
const CAPTURE_SIZE := Vector2i(640, 360)

var game


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("BUILDING_VISUAL_QA_FAIL: " + message)
    quit(1)


func _capture(name: String) -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    if image == null or image.is_empty():
        _fail("Gameplay viewport returned an empty image for " + name)
        return
    if image.get_width() < CAPTURE_SIZE.x or image.get_height() < CAPTURE_SIZE.y:
        _fail("Gameplay viewport is smaller than the expected 640x360 capture")
        return
    var output := image.get_region(Rect2i(
        (image.get_width() - CAPTURE_SIZE.x) / 2,
        (image.get_height() - CAPTURE_SIZE.y) / 2,
        CAPTURE_SIZE.x,
        CAPTURE_SIZE.y
    ))
    var path := "%s/%s.png" % [OUTPUT_DIR, name]
    var error := output.save_png(path)
    if error != OK:
        _fail("Could not save gameplay capture: " + path)
        return
    print("BUILDING_VISUAL_CAPTURE ", path)


func _place(id: String, cell: Vector2i) -> Node:
    if not DataDB.buildings.has(id):
        _fail("Unknown building definition: " + id)
        return null
    var node = game.build.place_raw(id, cell)
    if node == null:
        _fail("Could not instantiate building: " + id)
        return null
    return node


func _building(id: String) -> Node:
    for node in get_nodes_in_group("buildings"):
        if is_instance_valid(node) and String(node.id) == id:
            return node
    return null


func _add_construction_site(id: String, cell: Vector2i, ratio: float) -> Node:
    var site_script := load("res://scripts/entities/construction_site.gd") as GDScript
    if site_script == null or not site_script.can_instantiate():
        _fail("ConstructionSite renderer did not compile")
        return null
    var site = site_script.new()
    var required := 100.0
    site.setup(DataDB.buildings[id], cell, cell, DataDB.cost_of(id), required * ratio, required)
    site.world = game.world
    site.build_system = game.build
    site.set_process(false)
    game.world.entities.add_child(site)
    site.queue_redraw()
    return site


func _add_rival_stronghold() -> Node:
    var script := load("res://scripts/entities/enemy_keep.gd") as GDScript
    if script == null or not script.can_instantiate():
        _fail("EnemyKeep renderer did not compile")
        return null
    var anchor := Vector2i(110, 89)
    var found := false
    for y in range(87, 93):
        for x in range(108, 116):
            var candidate := Vector2i(x, y)
            var clear := true
            for row in 3:
                for column in 3:
                    if game.world.occupied.has(candidate + Vector2i(column, row)):
                        clear = false
            if clear:
                anchor = candidate
                found = true
                break
        if found:
            break
    var rival = script.new()
    rival.setup(
        game.world,
        game.flow,
        game.player,
        anchor,
        900,
        {"id": "visual_review_iron_legion", "region": "HIGHLANDS", "faction": "iron_legion"}
    )
    rival.set_process(false)
    game.world.entities.add_child(rival)
    return rival


func _run() -> void:
    var dir_error := DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
    if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
        _fail("Could not create visual QA output directory")
        return

    if not WorldConfig.apply_profile("frontier"):
        _fail("Could not select Frontier for the gameplay review")
        return

    var scene := load("res://scenes/main.tscn") as PackedScene
    if scene == null:
        _fail("Could not load the gameplay scene")
        return
    game = scene.instantiate()
    root.add_child(game)
    current_scene = game

    for _frame in 10:
        await process_frame
    if game.player == null or game.world == null or game.build == null:
        _fail("Gameplay did not finish initializing")
        return

    var enemy_renderer := load("res://scripts/entities/enemy_keep.gd") as GDScript
    var building_renderer := load("res://scripts/entities/building.gd") as GDScript
    if enemy_renderer == null or not enemy_renderer.can_instantiate():
        _fail("Rival stronghold renderer is unavailable")
        return
    if building_renderer == null or not building_renderer.can_instantiate():
        _fail("Player building renderer is unavailable")
        return

    GameClock.set_process(false)
    game.player.camera.position_smoothing_enabled = false
    game.player.camera.zoom = Vector2.ONE
    game.player.global_position = Vector2(98 * WorldConfig.tile_size, 99 * WorldConfig.tile_size)
    game.player.hide()

    # Ordinary settlement composition: housing, logistics, extraction, production,
    # military, medical and defensive structures occupy a compact visible district.
    var building_layout := [
        ["house", Vector2i(88, 91)],
        ["lumber_camp", Vector2i(91, 91)],
        ["granary", Vector2i(99, 91)],
        ["storage", Vector2i(103, 91)],
        ["outpost", Vector2i(107, 91)],
        ["hunting_lodge", Vector2i(88, 96)],
        ["quarry", Vector2i(92, 96)],
        ["forge", Vector2i(100, 96)],
        ["barracks", Vector2i(103, 96)],
        ["archery_range", Vector2i(106, 96)],
        ["tower", Vector2i(88, 100)],
        ["scout_post", Vector2i(91, 100)],
        ["infirmary", Vector2i(95, 100)],
        ["farm", Vector2i(100, 100)],
        ["wall", Vector2i(104, 100)],
        ["stone_wall", Vector2i(105, 100)]
    ]
    for entry in building_layout:
        if _place(String(entry[0]), entry[1]) == null:
            return

    var rival := _add_rival_stronghold()
    if rival == null:
        return

    var settlement_script := load("res://scripts/entities/enemy_settlement_structure.gd") as GDScript
    if settlement_script != null and settlement_script.can_instantiate():
        var rival_outpost = settlement_script.new()
        rival_outpost.setup(game.world, rival, "outpost", Vector2i(110, 95))
        rival_outpost.set_process(false)
        game.world.entities.add_child(rival_outpost)
        rival_outpost.queue_redraw()

    for _frame in 3:
        await process_frame
    await _capture("before-settlement")

    # Same placement and camera: four real construction sites at four work ratios.
    _add_construction_site("house", Vector2i(109, 91), 0.08)
    _add_construction_site("storage", Vector2i(112, 91), 0.34)
    _add_construction_site("forge", Vector2i(109, 96), 0.63)
    _add_construction_site("barracks", Vector2i(112, 96), 0.91)
    for _frame in 2:
        await process_frame
    await _capture("before-construction-progression")

    # Research the existing visual upgrade paths without advancing time or changing
    # costs, work rates, building completion, health calculations or save state.
    Tech.researched = ["longhouse", "palisade", "stone_towers", "iron_towers", "fortress"]
    Tech._recompute()
    Events.tech_researched.emit("")

    var damage := {
        "house": 0.68,
        "granary": 0.42,
        "barracks": 0.18,
        "tower": 0.47,
        "keep": 0.54,
        "wall": 0.22,
        "stone_wall": 0.36
    }
    for id in damage:
        var node := _building(String(id))
        if node != null:
            node.hp = roundi(float(node.max_hp) * float(damage[id]))
            node.queue_redraw()
    rival.hp = roundi(float(rival.max_hp) * 0.54)
    rival.queue_redraw()

    for _frame in 2:
        await process_frame
    await _capture("before-upgrades-and-damage")

    print("PASS: settlement, four construction ratios, five upgrade paths and seven damage ratios rendered in gameplay")
    quit(0)
