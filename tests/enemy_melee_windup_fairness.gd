extends SceneTree
## Melee fairness regression: moving behind a committed enemy wind-up avoids the hit.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var world_config = root.get_node("WorldConfig")
    world_config.apply_profile("classic")
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await process_frame
    await process_frame

    var player = main.player
    player.set_process(false)
    player.set_physics_process(false)
    player.hp = player.MAX_HP
    player._invuln = 0.0

    var data_db = root.get_node("DataDB")
    var enemy_script: Script = load("res://scripts/entities/enemy.gd")
    assert(enemy_script != null and data_db.enemies.has("bandit"),
        "The melee fairness fixture requires the current Bandit enemy definition")

    var enemy = enemy_script.new()
    enemy.setup(data_db.enemies["bandit"].duplicate(true), main.world, main.flow, player)
    main.world.entities.add_child(enemy)
    enemy.set_process(false)
    enemy.set_physics_process(false)
    enemy.global_position = player.global_position - Vector2(8.0, 0.0)
    assert(enemy.role != "pouncer", "The Bandit fixture must exercise the normal melee attack path")

    # The target remains inside melee reach, but crosses behind the locked facing.
    player.global_position = enemy.global_position + Vector2(-8.0, 0.0)
    var hp_before_dodge: int = player.hp
    enemy._atk_cd = 0.0
    enemy._begin_attack(player, Vector2.RIGHT)
    enemy.combat_lifecycle.resolve_pending(0.15)
    assert(player.hp == hp_before_dodge,
        "A normal melee wind-up must miss when the target sidesteps behind the attacker")

    # A target that remains in the committed forward arc must still be hit.
    player._invuln = 0.0
    player.global_position = enemy.global_position + Vector2(8.0, 0.0)
    var hp_before_hit: int = player.hp
    enemy._atk_cd = 0.0
    enemy._begin_attack(player, Vector2.RIGHT)
    enemy.combat_lifecycle.resolve_pending(0.15)
    assert(player.hp < hp_before_hit,
        "A target that remains in the forward arc and within reach must take the melee hit")

    enemy.queue_free()
    main.queue_free()
    print("PASS: normal melee wind-ups respect locked facing and retain valid forward hits")
    quit(0)
