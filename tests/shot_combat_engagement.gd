extends SceneTree
## Captures active mixed-unit combat in the real gameplay viewport.
## Actors keep their normal physics and combat ticks; only world-time spawning is frozen.

const OUTPUT_DIR := "/tmp/hold-the-keep-combat-visual-qa"
const CAPTURE_SIZE := Vector2i(640, 360)


func _fail(message: String) -> void:
    push_error("COMBAT_VISUAL_QA_FAIL: " + message)
    quit(1)


func wait_seconds(seconds: float) -> void:
    var frames := ceili(maxf(0.0, seconds) * 60.0)
    for _frame in frames:
        await physics_frame


func capture(main: Node, file_name: String, note: String) -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    if image == null or image.is_empty():
        _fail("Gameplay viewport returned an empty combat capture: " + file_name)
        return
    if image.get_width() < CAPTURE_SIZE.x or image.get_height() < CAPTURE_SIZE.y:
        _fail("Gameplay viewport is smaller than 640x360")
        return
    var region := image.get_region(Rect2i(
        (image.get_width() - CAPTURE_SIZE.x) / 2,
        (image.get_height() - CAPTURE_SIZE.y) / 2,
        CAPTURE_SIZE.x,
        CAPTURE_SIZE.y
    ))
    var output_path := OUTPUT_DIR.path_join(file_name)
    if region.save_png(output_path) != OK:
        _fail("Could not save combat screenshot: " + output_path)
        return
    # The project renders a 640x360 logical viewport at a 2x desktop window scale.
    # Preserve that actual nearest-neighbour presentation for easy gameplay review.
    var desktop_image := region.duplicate()
    desktop_image.resize(1280, 720, Image.INTERPOLATE_NEAREST)
    var desktop_path := OUTPUT_DIR.path_join(file_name.get_basename() + "-1280x720.png")
    if desktop_image.save_png(desktop_path) != OK:
        _fail("Could not save the desktop-scale combat screenshot: " + desktop_path)
        return
    print("COMBAT_VISUAL_CAPTURE ", output_path, " | ", note)
    print("COMBAT_VISUAL_CAPTURE_DESKTOP ", desktop_path)
    print("COMBAT_VISUAL_ACTORS enemies=", get_nodes_in_group("enemies").size(),
        " defenders=", get_nodes_in_group("defenders").size(),
        " projectiles=", get_nodes_in_group("enemy_projectiles").size())


func find_active_melee_swing():
    for group_name in ["defenders", "enemies"]:
        for combatant in get_nodes_in_group(group_name):
            var feedback = combatant.get("combat_feedback")
            if feedback != null and float(feedback.get("swing_remaining")) > 0.15:
                return combatant
    return null


func spawn_enemy(main, data_db, enemy_script: Script, enemy_id: String,
        position: Vector2, faction_id: String = "greenwood_raiders"):
    if not data_db.enemies.has(enemy_id):
        _fail("Missing combat fixture enemy definition: " + enemy_id)
        return null
    var enemy = enemy_script.new()
    enemy.setup(data_db.enemies[enemy_id], main.world, main.flow, main.player, faction_id)
    enemy.global_position = position
    main.world.entities.add_child(enemy)
    return enemy


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var dir_error := DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
    if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
        _fail("Could not create combat visual QA output directory")
        return

    var main_scene := load("res://scenes/main.tscn") as PackedScene
    var enemy_script := load("res://scripts/entities/enemy.gd") as GDScript
    if main_scene == null or enemy_script == null or not enemy_script.can_instantiate():
        _fail("Gameplay scene or Enemy script failed to load")
        return

    var main = main_scene.instantiate()
    root.add_child(main)
    current_scene = main
    for _frame in 8:
        await process_frame

    if main.player == null or main.world == null or main.flow == null or main.village == null:
        _fail("Gameplay did not finish initializing")
        return

    var data_db = root.get_node_or_null("DataDB")
    var clock := root.get_node_or_null("GameClock")
    if data_db == null or clock == null:
        _fail("Combat capture requires DataDB and GameClock autoloads")
        return

    # Freeze only day/night and wave scheduling. Actor physics and combat remain live.
    clock.set_process(false)
    clock.set_physics_process(false)
    main.spawner.set_process(false)
    main.spawner.set_physics_process(false)
    main.village.set_process(false)
    if main.supply != null:
        main.supply.set_process(false)

    for child in main.get_children():
        if child is CanvasLayer:
            var banner = child.get("_banner")
            if banner is CanvasItem:
                banner.hide()
            var message_bubble = child.get("_msg_bubble")
            if message_bubble is CanvasItem:
                message_bubble.hide()

    var keep_center: Vector2 = main.world.keep_center_position()
    # Put the player on the actual frontline. A neutral camera keeps the Keep,
    # shieldbearer, infantry and incoming raiders visible in one gameplay-scale frame.
    main.player.global_position = keep_center + Vector2(-95, 55)
    main.player.velocity = Vector2.ZERO
    main.player.camera.position_smoothing_enabled = false
    main.player.camera.offset = Vector2.ZERO
    main.player.camera.zoom = Vector2.ONE
    main.player.camera.make_current()

    # Friendly infantry holds a visible line south-west of the Keep.
    for offset in [Vector2(-42, 32), Vector2(-28, 54), Vector2(-10, 34)]:
        var soldier = main.village.spawn_villager(keep_center + offset)
        if soldier == null or not soldier.set_job("soldier"):
            _fail("Could not create a working friendly soldier for the battle fixture")
            return

    # Live opposing melee, ranged, shield and siege actors. No actor is frozen or
    # manually advanced: the capture is a naturally ticking engagement.
    spawn_enemy(main, data_db, enemy_script, "bandit",
        keep_center + Vector2(-146, -18), "greenwood_raiders")
    spawn_enemy(main, data_db, enemy_script, "bandit",
        keep_center + Vector2(-138, 34), "ashen_host")
    spawn_enemy(main, data_db, enemy_script, "bandit",
        keep_center + Vector2(-112, -62), "iron_legion")
    var shield = spawn_enemy(main, data_db, enemy_script, "enemy_shieldbearer",
        keep_center + Vector2(-82, 15), "iron_legion")
    spawn_enemy(main, data_db, enemy_script, "archer",
        keep_center + Vector2(-175, -55), "fen_cult")

    # Place the siege unit within its existing 52px impact range of the Keep.
    # Its target and all attack timing remain governed by SiegeEngineBehavior.
    var keep: Node2D
    for building in get_nodes_in_group("buildings"):
        if String(building.get("id")) == "keep":
            keep = building as Node2D
            break
    if keep == null:
        _fail("Could not find the live Keep for siege interaction")
        return
    var siege = spawn_enemy(main, data_db, enemy_script, "enemy_siege_engine",
        keep.global_position + Vector2(-50, 5), "ashen_host")
    siege.siege_behavior.target = keep
    # Delay only this fixture's first shot so the melee frame is captured
    # before any structure impact. The engine then uses its normal attack cycle.
    siege.siege_behavior.cooldown = 3.5

    if shield == null or siege == null:
        _fail("Combat fixture failed to create its defensive or siege specialist")
        return

    # Ensure all actors have entered the scene tree. Capture the first natural
    # shield brace as soon as the behavior enters it, before the crowded melee resolves.
    var shield_braced := false
    for _frame in 180:
        if not is_instance_valid(shield):
            _fail("Shieldbearer died before its defensive state could be inspected")
            return
        if shield.shield_behavior.active_timer > 0.0:
            shield_braced = true
            break
        await physics_frame
    if not shield_braced:
        _fail("Shieldbearer did not enter its natural brace state during the live encounter")
        return
    print("COMBAT_VISUAL_SHIELD_STATE windup=", shield.shield_behavior.windup_timer,
        " active=", shield.shield_behavior.active_timer, " hp=", shield.hp)
    await capture(main, "battlefield-shield-and-projectiles.png",
        "shieldbearer captured during its natural defensive brace with live ranged fire")

    await wait_seconds(2.2)
    # Sample a real attack animation window, rather than hoping a 0.28s sweep
    # happens to overlap a fixed screenshot timestamp.
    var swinging_combatant = null
    for _frame in 600:
        swinging_combatant = find_active_melee_swing()
        if swinging_combatant != null:
            break
        await physics_frame
    if swinging_combatant == null:
        _fail("No live melee combatant entered its directional swing window")
        return
    var swing_feedback = swinging_combatant.get("combat_feedback")
    print("COMBAT_VISUAL_MELEE_SWING actor=", swinging_combatant.name,
        " direction=", swing_feedback.swing_direction,
        " remaining=", swing_feedback.swing_remaining,
        " total=", swing_feedback.swing_total)
    await capture(main, "battlefield-melee-contact.png",
        "live melee swing sampled while its directional weapon-contact sweep is active")

    # Capture when the real siege transaction has damaged the Keep and its directional
    # impact mark is still active. This proves structure contact rather than proximity.
    var siege_contact := false
    for _frame in 900:
        if keep.hp < keep.max_hp and keep._combat_impact_remaining > 0.0:
            siege_contact = true
            break
        await physics_frame
    if not siege_contact:
        _fail("Live siege engine did not produce a visible directional Keep impact")
        return
    print("COMBAT_VISUAL_SIEGE_CONTACT keep_hp=", keep.hp, "/", keep.max_hp,
        " impact_remaining=", keep._combat_impact_remaining)
    await capture(main, "battlefield-siege-structure-impact.png",
        "live siege damage confirmed on the Keep; directional fracture mark still active")

    print("PASS: three actual gameplay captures recorded with active enemy, soldier, projectile and siege simulation")
    quit(0)
