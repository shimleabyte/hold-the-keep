extends SceneTree
## Phase 06.2 regression: Shieldbearer brace timing, direction, damage mitigation and interruption.

func ticks(count: int) -> void:
    for i in count:
        await physics_frame


func _initialize() -> void:
    call_deferred("_run")


func _spawn_shieldbearer(main, at: Vector2):
    var script = load("res://scripts/entities/enemy.gd")
    var enemy = script.new()
    var data_db = root.get_node("DataDB")
    enemy.setup(data_db.enemies["enemy_shieldbearer"], main.world, main.flow, main.player)
    enemy.position = at
    main.world.entities.add_child(enemy)
    enemy.set_physics_process(false)
    return enemy


func _run() -> void:
    var config = root.get_node("WorldConfig")
    config.apply_profile("frontier")
    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(8)
    root.get_node("GameClock").set_process(false)

    var player = main.player
    player.global_position = Vector2(820, 820)

    # A visible wind-up starts when the player enters brace range.
    var shield = _spawn_shieldbearer(main, player.global_position + Vector2(52, 0))
    shield._tick_shieldbearer(0.016)
    assert(shield.shield_behavior.windup_timer > 0.0, "Shieldbearer must telegraph before bracing")
    var expected_front: Vector2 = (player.global_position - shield.global_position).normalized()
    assert(shield.shield_behavior.brace_direction.dot(expected_front) > 0.99,
        "Brace must face the nearest valid defender")
    shield._tick_shieldbearer(shield.shield_behavior.windup_duration + 0.01)
    assert(shield.shield_behavior.active_timer > 0.9, "Wind-up must transition into a finite active brace")

    # A front hit is mitigated; side and rear attacks bypass the directional guard.
    var starting_hp: int = shield.hp
    var front_source: Vector2 = shield.global_position + shield.shield_behavior.brace_direction * 32.0
    assert(shield.shield_behavior.blocks_hit_from(front_source),
        "Only an impact inside the frontal brace arc should be blocked")
    assert(not shield.shield_behavior.blocks_hit_from(Vector2.ZERO),
        "Damage without an impact origin must not receive directional brace mitigation")
    shield.take_damage_from(20, front_source)
    var front_loss: int = starting_hp - shield.hp
    assert(front_loss == 7, "Front block should apply passive armor and brace mitigation")

    var side_shield = _spawn_shieldbearer(main, player.global_position + Vector2(-180, 0))
    side_shield.shield_behavior.active_timer = 1.0
    side_shield.shield_behavior.brace_direction = Vector2.RIGHT
    var side_hp: int = side_shield.hp
    side_shield.take_damage_from(20, side_shield.global_position + Vector2(0, 32))
    var side_loss: int = side_hp - side_shield.hp
    assert(side_loss == 16, "Side attack must bypass the frontal shield arc")

    var rear_shield = _spawn_shieldbearer(main, player.global_position + Vector2(-220, 0))
    rear_shield.shield_behavior.active_timer = 1.0
    rear_shield.shield_behavior.brace_direction = Vector2.RIGHT
    var rear_hp: int = rear_shield.hp
    rear_shield.take_damage_from(20, rear_shield.global_position + Vector2(-32, 0))
    var rear_loss: int = rear_hp - rear_shield.hp
    assert(rear_loss == 16, "Rear attack must bypass the frontal shield arc")
    assert(rear_loss > front_loss, "Flanking must be measurably more effective than frontal attacks")

    # A stagger interrupts both the tell and the active guard, creating a punish window.
    var interrupted = _spawn_shieldbearer(main, player.global_position + Vector2(56, 0))
    interrupted._tick_shieldbearer(0.016)
    assert(interrupted.shield_behavior.windup_timer > 0.0, "Second Shieldbearer should enter wind-up")
    interrupted.apply_stagger(0.6)
    assert(interrupted.shield_behavior.windup_timer == 0.0 and interrupted.shield_behavior.active_timer == 0.0,
        "Stagger must cancel the brace immediately")
    assert(interrupted.shield_behavior.cooldown > 0.0, "Interrupted brace must not be immediately retriggered")

    # A player who disengages before the tell completes cancels the brace.
    var baited = _spawn_shieldbearer(main, player.global_position + Vector2(52, 0))
    baited._tick_shieldbearer(0.016)
    assert(baited.shield_behavior.windup_timer > 0.0, "Bait test requires an active tell")
    player.global_position = baited.global_position + Vector2(150, 0)
    baited._tick_shieldbearer(0.016)
    assert(baited.shield_behavior.windup_timer == 0.0, "Brace wind-up must cancel when the target disengages")
    assert(baited.shield_behavior.cooldown <= 0.8, "A cancelled tell must not consume the full brace cycle")

    print("PASS: Shieldbearer brace telegraph, facing lock, frontal mitigation, flank/rear counterplay, stagger interruption and disengage recovery")
    main.queue_free()
    quit(0)
