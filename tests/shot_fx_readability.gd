extends SceneTree
## Captures melee impact, dash wake and directional building debris in the real game viewport.

const OUTPUT_DIR := "res://build/diagnostics/fx-readability"
const CAPTURE_SIZE := Vector2i(640, 360)
const MELEE_DASH_FRAME_COUNT := 8
const BUILDING_FRAME_COUNT := 14
const FRAME_STEP_PHYSICS_TICKS := 3

var _main
var _player
var _fx_layer
var _data_db


func _fail(message: String) -> void:
    push_error("FX_READABILITY_QA_FAIL: " + message)
    quit(1)


func wait_physics_frames(count: int) -> void:
    for _frame in count:
        await physics_frame


func find_fx_layer(node: Node) -> Node2D:
    for child in node.get_children():
        var script := child.get_script() as Script
        if script != null and script.resource_path.ends_with("scripts/entities/fx_layer.gd"):
            return child as Node2D
        var nested := find_fx_layer(child)
        if nested != null:
            return nested
    return null


func find_building(building_id: String):
    for candidate in get_nodes_in_group("buildings"):
        if is_instance_valid(candidate) and String(candidate.get("id")) == building_id:
            return candidate as Node2D
    return null


func capture_frame(prefix: String, frame_index: int) -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    if image == null or image.is_empty():
        _fail("Gameplay viewport returned an empty image for " + prefix)
        return
    if image.get_width() < CAPTURE_SIZE.x or image.get_height() < CAPTURE_SIZE.y:
        _fail("Gameplay viewport is smaller than the expected 640x360 logical capture")
        return

    var region := image.get_region(Rect2i(
        (image.get_width() - CAPTURE_SIZE.x) / 2,
        (image.get_height() - CAPTURE_SIZE.y) / 2,
        CAPTURE_SIZE.x,
        CAPTURE_SIZE.y
    ))
    var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
    var frame_path := output_dir.path_join("%s-%02d.png" % [prefix, frame_index])
    if region.save_png(frame_path) != OK:
        _fail("Could not save frame " + frame_path)
        return

    if frame_index == 2:
        var desktop := region.duplicate()
        desktop.resize(1280, 720, Image.INTERPOLATE_NEAREST)
        var desktop_path := output_dir.path_join("%s-1280x720.png" % prefix)
        if desktop.save_png(desktop_path) != OK:
            _fail("Could not save desktop-scale still " + desktop_path)
            return

    print("FX_READABILITY_CAPTURE ", prefix, " frame=", frame_index,
        " particles=", _fx_layer.count(), " path=", frame_path)


func capture_sequence(prefix: String, frame_count: int) -> void:
    for index in frame_count:
        await capture_frame(prefix, index)
        await wait_physics_frames(FRAME_STEP_PHYSICS_TICKS)


func spawn_enemy(enemy_id: String, position: Vector2, faction_id: String = "greenwood_raiders"):
    if not _data_db.enemies.has(enemy_id):
        _fail("Missing visual fixture enemy: " + enemy_id)
        return null
    var enemy_script := load("res://scripts/entities/enemy.gd") as GDScript
    if enemy_script == null or not enemy_script.can_instantiate():
        _fail("Enemy script did not compile for the FX gameplay capture")
        return null
    var enemy = enemy_script.new()
    enemy.setup(_data_db.enemies[enemy_id], _main.world, _main.flow, _player, faction_id)
    enemy.global_position = position
    _main.world.entities.add_child(enemy)
    enemy.set_physics_process(false)
    return enemy


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
    var dir_error := DirAccess.make_dir_recursive_absolute(output_dir)
    if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
        _fail("Could not create the FX readability output directory")
        return

    await process_frame
    var main_scene := load("res://scenes/main.tscn") as PackedScene
    if main_scene == null:
        _fail("Could not load the production gameplay scene")
        return
    _main = main_scene.instantiate()
    root.add_child(_main)
    current_scene = _main
    await wait_physics_frames(8)

    if _main.player == null or _main.world == null or _main.village == null:
        _fail("Production gameplay scene did not finish initialization")
        return

    _player = _main.player
    _data_db = root.get_node_or_null("DataDB")
    var clock := root.get_node_or_null("GameClock")
    if _data_db == null or clock == null:
        _fail("FX capture requires DataDB and GameClock autoloads")
        return

    # Freeze campaign scheduling only. The player, effects, tweens and building
    # presentation continue to process at normal gameplay scale.
    clock.set_process(false)
    clock.set_physics_process(false)
    _main.spawner.set_process(false)
    _main.spawner.set_physics_process(false)
    _main.village.set_process(false)
    if _main.supply != null:
        _main.supply.set_process(false)

    for child in _main.get_children():
        if child is CanvasLayer:
            var banner = child.get("_banner")
            if banner is CanvasItem:
                banner.hide()
            var message_bubble = child.get("_msg_bubble")
            if message_bubble is CanvasItem:
                message_bubble.hide()

    _fx_layer = find_fx_layer(_main.world)
    if _fx_layer == null:
        _fail("Could not find the production FX renderer attached to the world")
        return

    var keep = find_building("keep")
    if keep == null:
        _fail("Could not find the live Keep")
        return
    var keep_center: Vector2 = _main.world.keep_center_position()

    _player.global_position = keep_center + Vector2(-104, 28)
    _player.velocity = Vector2.ZERO
    _player.camera.position_smoothing_enabled = false
    _player.camera.zoom = Vector2.ONE
    _player.camera.offset = Vector2.ZERO
    _player.camera.make_current()

    # 1. Real player attack against a live enemy. Capture only after the target
    # loses health, so the burst is the actual impact event, not just anticipation.
    var melee_target = spawn_enemy("bandit", _player.global_position + Vector2(18, 2))
    if melee_target == null:
        return
    var target_hp_before := int(melee_target.hp)
    _player.facing = Vector2.RIGHT
    _player.anim.face(Vector2.RIGHT)
    _player._atk_cd = 0.0
    _player._attack()
    var melee_hit := false
    for _frame in 30:
        if int(melee_target.hp) < target_hp_before:
            melee_hit = true
            break
        await physics_frame
    if not melee_hit:
        _fail("The live player attack did not resolve against its fixture target")
        return
    if _fx_layer.count() <= 0:
        _fail("The real melee hit did not emit visible particles")
        return
    print("FX_READABILITY_MELEE target_hp=", melee_target.hp,
        " facing=", _player.facing, " particles=", _fx_layer.count())
    await capture_sequence("melee-impact", MELEE_DASH_FRAME_COUNT)

    # Let short-lived hit and blade particles expire before testing the dash.
    await wait_physics_frames(30)
    _player._dash_cd = 0.0
    _player.facing = Vector2.RIGHT
    _player.anim.face(Vector2.RIGHT)
    var dash_particles_before: int = _fx_layer.count()
    if not _player.activate_ability("dash"):
        _fail("The production dash ability could not be activated")
        return
    if _fx_layer.count() <= dash_particles_before:
        _fail("The production dash ability did not emit its trailing particles")
        return
    print("FX_READABILITY_DASH direction=", _player._dash_dir,
        " remaining=", _player._dash_t, " particles=", _fx_layer.count() - dash_particles_before)
    await capture_sequence("dash-trail", MELEE_DASH_FRAME_COUNT)

    # 3. A real Siege Engine strike calls Building.take_damage with its source-side
    # direction. This checks the complete source -> building -> FX renderer path.
    await wait_physics_frames(24)
    _player.set_physics_process(false)
    _player.global_position = keep.global_position + Vector2(132, 56)
    _player.velocity = Vector2.ZERO
    _player.camera.offset = Vector2(-132, -56)
    var siege = spawn_enemy("enemy_siege_engine", keep.global_position + Vector2(-18, 0), "ashen_host")
    if siege == null:
        return
    siege.siege_behavior.target = keep
    siege.siege_behavior.cooldown = 0.0
    var keep_hp_before: int = keep.hp
    siege.siege_behavior.tick(0.016)
    if siege.siege_behavior.windup_timer <= 0.0:
        _fail("Siege Engine did not enter its structural strike wind-up")
        return
    # Keep the committed attack valid, but move the large siege sprite away from
    # the impact contact point so it cannot hide the debris in the visual review.
    siege.global_position = keep.global_position + Vector2(-40, -24)
    siege.siege_behavior.tick(siege.siege_behavior.windup_duration + 0.02)
    if keep.hp >= keep_hp_before:
        _fail("Siege Engine did not damage the live Keep")
        return
    if _fx_layer.count() <= 0:
        _fail("Structural impact did not emit debris particles")
        return
    var impact_direction := (siege.global_position - keep.global_position).normalized()
    print("FX_READABILITY_BUILDING keep_hp=", keep.hp, "/", keep.max_hp,
        " impact_direction=", impact_direction, " particles=", _fx_layer.count())
    await capture_sequence("building-debris", BUILDING_FRAME_COUNT)

    print("PASS: live melee impact, player dash trail and directional siege debris captured at gameplay scale")
    quit(0)
