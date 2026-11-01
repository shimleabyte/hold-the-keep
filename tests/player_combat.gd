extends SceneTree
## Player combat regression: XP progression, active skills, enemy roles, and save payload.

func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func _initialize() -> void:
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(4)
    GameClock.set_process(false)

    var player = main.player
    var start_position: Vector2 = player.global_position
    assert(player.activate_ability("dash"), "Dash must be available at level 1")
    assert(player._invuln > 0.0, "Dash must grant brief invulnerability")
    await ticks(18)
    assert(player.global_position.distance_to(start_position) > 8.0,
        "Dash must translate the player, not only play an animation")
    assert(player.combat_status()["dash_cd"] > 0.0, "Dash must enter cooldown")

    var initial_status: Dictionary = player.combat_status()
    player.gain_experience(initial_status["next_xp"])
    assert(player.level == 2, "XP threshold must advance the player to level 2")
    assert(player.combat_status()["cleave_unlocked"], "Level 2 must unlock Cleave")
    assert(not player.combat_status()["rally_unlocked"], "Rally must remain locked before level 3")

    var enemy_script = load("res://scripts/entities/enemy.gd")
    var sturdy_bandit: Dictionary = DataDB.enemies["bandit"].duplicate()
    sturdy_bandit["hp"] = 80
    var forward_enemy = enemy_script.new()
    forward_enemy.setup(sturdy_bandit, main.world, main.flow, player)
    forward_enemy.position = player.global_position + Vector2(28, 0)
    main.world.entities.add_child(forward_enemy)
    forward_enemy.set_physics_process(false)

    var rear_enemy = enemy_script.new()
    rear_enemy.setup(sturdy_bandit, main.world, main.flow, player)
    rear_enemy.position = player.global_position + Vector2(-44, 0)
    main.world.entities.add_child(rear_enemy)
    rear_enemy.set_physics_process(false)

    player.facing = Vector2.RIGHT
    var forward_hp := forward_enemy.hp
    var rear_hp := rear_enemy.hp
    assert(player.activate_ability("cleave"), "Cleave should activate after unlocking")
    await ticks(20)
    assert(forward_enemy.hp < forward_hp, "Cleave must damage enemies in its forward arc")
    assert(rear_enemy.hp == rear_hp, "Cleave must not damage enemies behind the player")

    player.gain_experience(player.combat_status()["next_xp"])
    assert(player.level == 3 and player.combat_status()["rally_unlocked"],
        "Level 3 must unlock Rally")
    var soldier = main.village.spawn_villager(player.global_position + Vector2(-8, 0))
    soldier.set_job("soldier")
    assert(player.activate_ability("rally"), "Rally should activate at level 3")
    assert(soldier._rally_t > 0.0, "Rally must reach nearby friendly soldiers")
    assert(soldier._rally_damage_mult > 1.0 and soldier._rally_interval_mult < 1.0,
        "Rally must improve soldier damage and attack cadence")

    var wolf = enemy_script.new()
    wolf.setup(DataDB.enemies["wolf"], main.world, main.flow, player)
    wolf.position = player.global_position + Vector2(20, 0)
    main.world.entities.add_child(wolf)
    wolf.set_physics_process(false)
    assert(wolf.role == "pouncer", "Wolf must use its pounce role")
    wolf._begin_attack(player, Vector2.LEFT)
    assert(wolf._pounce_t > 0.0, "Wolf attack must launch a lunge")
    wolf.apply_stagger(0.3)
    assert(wolf._pounce_t == 0.0 and wolf._stagger_t > 0.0,
        "Stagger must interrupt an active pounce")

    var archer = enemy_script.new()
    archer.setup(DataDB.enemies["archer"], main.world, main.flow, player)
    assert(archer.role == "ranged" and archer.preferred_range > 0.0,
        "Archer must use ranged spacing behavior")
    archer.position = player.global_position + Vector2(90, 0)
    main.world.entities.add_child(archer)
    archer.set_physics_process(false)
    archer._tick_ranged(0.016)
    archer._resolve_pending(1.0)
    assert(get_nodes_in_group("enemy_projectiles").size() > 0,
        "Archer attack must create a hostile projectile")

    var brute = enemy_script.new()
    brute.setup(DataDB.enemies["brute"], main.world, main.flow, player)
    main.world.entities.add_child(brute)
    brute.set_physics_process(false)
    var brute_hp := brute.hp
    brute.take_damage(20)
    assert(brute.hp == brute_hp - 16, "Brute armor must reduce incoming damage")

    var xp_before_kill := player.experience
    brute.take_damage(9999)
    assert(player.experience == xp_before_kill + 32,
        "Enemy kill signal must award the player's XP reward")

    var snapshot: Dictionary = SaveSystem.collect(main)
    assert(snapshot["player"]["combat"]["level"] == 3,
        "Save payload must preserve player level")
    assert(snapshot["player"]["combat"]["xp"] == player.experience,
        "Save payload must preserve player XP")
    assert(SaveSystem._valid_save(snapshot),
        "Combat-enabled save payload must pass validation")

    print("PASS: XP, level unlocks, dash, directional cleave, rally buff, ranged projectile, brute armor, combat save")
    quit()
