extends SceneTree
## Phase 06.2 regression: Scout telegraph, faction-only mark sharing and focus-fire priority.

func ticks(count: int) -> void:
    for i in count:
        await physics_frame


func _initialize() -> void:
    call_deferred("_run")


func _spawn_enemy(main, data: Dictionary, faction_id: String, at: Vector2):
    var script = load("res://scripts/entities/enemy.gd")
    var enemy = script.new()
    enemy.setup(data, main.world, main.flow, main.player, faction_id)
    enemy.global_position = at
    main.world.entities.add_child(enemy)
    enemy.set_physics_process(false)
    return enemy


func _run() -> void:
    var config = root.get_node("WorldConfig")
    var data_db = root.get_node("DataDB")
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

    var scout = _spawn_enemy(main, data_db.enemies["enemy_scout"], "greenwood_raiders",
        player.global_position + Vector2(130, 0))
    var ally = _spawn_enemy(main, data_db.enemies["bandit"], "greenwood_raiders",
        player.global_position + Vector2(145, 5))
    var ranged_ally = _spawn_enemy(main, data_db.enemies["archer"], "greenwood_raiders",
        player.global_position + Vector2(140, -10))
    var rival = _spawn_enemy(main, data_db.enemies["bandit"], "iron_legion",
        player.global_position + Vector2(154, -6))

    # Scout exposes a readable wind-up before publishing a shared target.
    scout._tick_scout(0.016)
    assert(scout._scout_windup_t > 0.0, "Scout must telegraph before marking")
    assert(scout._scout_windup_target == player, "Scout must select the nearest visible defender")
    scout._tick_scout(scout.scout_windup_duration + 0.01)
    assert(scout._scout_mark_target == player and scout._scout_mark_t > 0.0,
        "Completed wind-up must mark its target for a finite duration")

    # Only same-faction allies inside the bounded share radius inherit the mark.
    assert(ally._scout_mark_target == player and ally._scout_mark_t > 0.0,
        "Nearby same-faction allies must receive the Scout's target")
    assert(ranged_ally._scout_mark_target == player and ranged_ally._scout_mark_t > 0.0,
        "A nearby same-faction ranged ally must receive the target")
    assert(rival._scout_mark_target == null and rival._scout_mark_t == 0.0,
        "A different faction must not inherit the Scout's mark")

    # Marked targets outrank nearer alternatives; melee focus expires normally.
    var closer_soldier = main.village.spawn_villager(player.global_position + Vector2(146, 8))
    closer_soldier.set_job("soldier")
    assert(ranged_ally._nearest_ranged_target() == player,
        "Ranged allies must prioritize the marked target over a closer defender")
    assert(ally._tick_marked_target(0.1) and ally._moving,
        "Marked melee allies must move to focus the designated target")
    ally._scout_mark_t = 0.0
    ally._scout_mark_target = null
    assert(not ally._tick_marked_target(0.1),
        "Normal melee behavior must resume after mark expiry")
    ranged_ally._scout_mark_t = 0.0
    ranged_ally._scout_mark_target = null
    assert(ranged_ally._nearest_ranged_target() == closer_soldier,
        "Normal ranged target selection must resume after mark expiry")

    # Stagger interrupts an unfinished Scout callout before it reaches allies.
    var interrupted_scout = _spawn_enemy(main, data_db.enemies["enemy_scout"],
        "greenwood_raiders", player.global_position + Vector2(-100, 0))
    interrupted_scout._tick_scout(0.016)
    assert(interrupted_scout._scout_windup_t > 0.0, "Interrupt test must enter wind-up")
    interrupted_scout.apply_stagger(0.6)
    assert(interrupted_scout._scout_windup_t == 0.0
        and interrupted_scout._scout_windup_target == null,
        "Stagger must cancel an unfinished Scout mark")
    assert(interrupted_scout._scout_mark_cd > 0.0,
        "Interrupted Scout must not immediately restart its mark")

    # Moving the selected defender away cancels the wind-up without publishing a mark.
    var baited_scout = _spawn_enemy(main, data_db.enemies["enemy_scout"],
        "greenwood_raiders", player.global_position + Vector2(0, 100))
    baited_scout._tick_scout(0.016)
    assert(baited_scout._scout_windup_t > 0.0, "Disengage test must enter wind-up")
    var bait_target: Node2D = baited_scout._scout_windup_target
    bait_target.global_position += Vector2(500, 0)
    baited_scout._tick_scout(0.016)
    assert(baited_scout._scout_windup_t == 0.0,
        "Scout must cancel the callout when its target leaves marking range")
    assert(baited_scout._scout_mark_target == null,
        "A cancelled callout must not distribute a mark")

    print("PASS: Scout mark telegraph, same-faction sharing, bounded focus priority, expiry, stagger interruption and target disengage")
    main.queue_free()
    quit(0)
