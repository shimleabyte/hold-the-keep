extends SceneTree
## Player combat regression: XP progression, active skills, enemy roles, and save payload.

func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func _initialize() -> void:
    var game_clock = root.get_node("GameClock")
    var save_system = root.get_node("SaveSystem")
    var data_db = root.get_node("DataDB")
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(4)
    game_clock.set_process(false)

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
    var sturdy_bandit: Dictionary = data_db.enemies["bandit"].duplicate()
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

    player.facing = Vector2.LEFT
    var forward_hp: int = forward_enemy.hp
    var rear_hp: int = rear_enemy.hp
    assert(player.activate_ability("cleave"), "Cleave should activate after unlocking")
    assert(player._cleave_direction == Vector2.RIGHT,
        "Cleave must lock the nearest target direction before its wind-up")
    assert(player.combat_feedback.ability_direction == Vector2.RIGHT,
        "Cleave's contextual cue must preserve the same locked direction")
    player.facing = Vector2.LEFT
    await ticks(20)
    assert(forward_enemy.hp < forward_hp,
        "Cleave must hit inside its locked forward arc after the player turns")
    assert(rear_enemy.hp == rear_hp, "Cleave must not damage enemies behind the player")

    var normal_front = enemy_script.new()
    normal_front.setup(sturdy_bandit, main.world, main.flow, player)
    normal_front.global_position = player.global_position + Vector2(20, 0)
    main.world.entities.add_child(normal_front)
    normal_front.set_physics_process(false)
    var normal_rear = enemy_script.new()
    normal_rear.setup(sturdy_bandit, main.world, main.flow, player)
    normal_rear.global_position = player.global_position + Vector2(-20, 0)
    main.world.entities.add_child(normal_rear)
    normal_rear.set_physics_process(false)
    var normal_flank = enemy_script.new()
    normal_flank.setup(sturdy_bandit, main.world, main.flow, player)
    normal_flank.global_position = player.global_position + Vector2(0, -20)
    main.world.entities.add_child(normal_flank)
    normal_flank.set_physics_process(false)

    player.facing = Vector2.LEFT
    var normal_front_hp: int = normal_front.hp
    var normal_rear_hp: int = normal_rear.hp
    var normal_flank_hp: int = normal_flank.hp
    player._attack()
    assert(player._attack_direction == Vector2.RIGHT,
        "Normal melee must lock to the selected target before its wind-up")
    assert(player.combat_feedback.windup_direction == Vector2.RIGHT,
        "Normal melee anticipation must use the same locked direction as its hit resolver")
    player.facing = Vector2.LEFT
    await ticks(12)
    assert(normal_front.hp < normal_front_hp,
        "A normal melee swing must damage an enemy inside its forward attack sector")
    assert(normal_rear.hp == normal_rear_hp,
        "A normal melee swing must not damage an enemy directly behind the player")
    assert(normal_flank.hp == normal_flank_hp,
        "A normal melee swing must not damage an enemy outside its visible forward sector")

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
    wolf.setup(data_db.enemies["wolf"], main.world, main.flow, player)
    wolf.position = player.global_position + Vector2(20, 0)
    main.world.entities.add_child(wolf)
    wolf.set_physics_process(false)
    assert(wolf.role == "pouncer", "Wolf must use its pounce role")
    wolf._begin_attack(player, Vector2.LEFT)
    assert(wolf._pounce_windup_t > 0.0 and wolf._pounce_t > 0.0,
        "Wolf attack must telegraph before launching its lunge")
    wolf.apply_stagger(0.3)
    assert(wolf._pounce_t == 0.0 and wolf._stagger_t > 0.0,
        "Stagger must interrupt an active pounce")

    var archer = enemy_script.new()
    archer.setup(data_db.enemies["archer"], main.world, main.flow, player)
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
    brute.setup(data_db.enemies["brute"], main.world, main.flow, player)
    main.world.entities.add_child(brute)
    brute.set_physics_process(false)
    var brute_hp: int = brute.hp
    brute.take_damage(20)
    assert(brute.hp == brute_hp - 16, "Brute armor must reduce incoming damage")
    brute.apply_stagger(0.55)
    assert(brute._stagger_t < 0.55 and brute._stagger_t > 0.0,
        "Brute stagger resistance must reduce control duration")

    var xp_before_kill: int = player.experience
    brute.take_damage(9999)
    assert(player.experience == xp_before_kill + 32,
        "Enemy kill signal must award the player's XP reward")

    var snapshot: Dictionary = save_system.collect(main)
    assert(snapshot["player"]["combat"]["level"] == 3,
        "Save payload must preserve player level")
    assert(snapshot["player"]["combat"]["xp"] == player.experience,
        "Save payload must preserve player XP")
    assert(save_system._valid_save(snapshot),
        "Combat-enabled save payload must pass validation")

    print("PASS: XP, level unlocks, dash, locked directional melee/Cleave, rally buff, ranged projectile, brute armor, combat save")
    quit()
