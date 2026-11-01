extends SceneTree
## Campaign regression: enemy claim, fog reveal, expedition command, save data, dawn garrison, conquest.

func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func _initialize() -> void:
    DirAccess.remove_absolute("user://save.json")
    DirAccess.remove_absolute("user://save.tmp")
    DirAccess.remove_absolute("user://save.bak")

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(4)
    GameClock.set_process(false)

    var stronghold = main.enemy_keep
    assert(stronghold != null and is_instance_valid(stronghold),
        "New campaign must create an enemy stronghold")
    assert(main.territory.owner_at(stronghold.cell) == "enemy",
        "Enemy stronghold footprint must belong to enemy territory")
    assert(not main.fog.is_revealed_cell(stronghold.cell),
        "Enemy stronghold should start hidden by fog")

    assert(not main.territory.can_place("outpost", stronghold.cell, Vector2i(2, 2)),
        "Outposts must not be placed inside hostile territory")
    main.fog.reveal_position(stronghold.global_position, 180.0)
    assert(main.fog.is_revealed_cell(stronghold.cell),
        "Exploration must reveal the enemy stronghold")
    var revealed_index := stronghold.cell.y * 64 + stronghold.cell.x
    var fog_state: Dictionary = main.fog.export_state()
    assert(fog_state["cells"].has(revealed_index),
        "Explored cells must be part of the fog save state")
    main.fog.discovered.fill(0)
    main.fog.import_state(fog_state)
    assert(main.fog.is_revealed_cell(stronghold.cell),
        "Fog import must restore previously explored cells")

    var soldier = main.village.spawn_villager(main.player.position + Vector2(-8, 0))
    soldier.set_job("soldier")
    main.village.command_expedition()
    assert(soldier.is_expeditioning(),
        "G command must assign soldier job villagers to the expedition")

    var guard_count := get_nodes_in_group("enemy_garrison").size()
    assert(guard_count >= 1, "Stronghold must have a defensive garrison")
    main.spawner.end_wave()
    assert(get_nodes_in_group("enemy_garrison").size() == guard_count,
        "Regular dawn cleanup must not despawn stronghold guards")

    var snapshot: Dictionary = SaveSystem.collect(main)
    assert(snapshot["stronghold"]["hp"] == stronghold.hp,
        "Save must preserve stronghold HP and location")
    var saved_expedition := false
    for villager_state in snapshot["villagers"]:
        if villager_state["expedition"]:
            saved_expedition = true
    assert(saved_expedition, "Save must preserve expedition assignment")
    var saved_garrison := false
    for enemy_state in snapshot["enemies"]:
        if enemy_state["garrison"]:
            saved_garrison = true
    assert(saved_garrison, "Save must preserve garrison identity and guard origin")
    assert(snapshot["fog"]["cells"].has(revealed_index),
        "Save payload must include explored territory")
    assert(SaveSystem._valid_save(snapshot),
        "Campaign snapshot must pass save payload validation")

    main.village.command_expedition()
    assert(soldier.is_recalling_expedition(),
        "Second G command must order the expedition soldier back to the Keep")
    var recall_snapshot: Dictionary = SaveSystem.collect(main)
    var saved_recall := false
    for villager_state in recall_snapshot["villagers"]:
        if bool(villager_state.get("recalling", false)):
            saved_recall = true
    assert(saved_recall and SaveSystem._valid_save(recall_snapshot),
        "Save must preserve a soldier who is travelling back to the Keep")

    var enemy_cell := stronghold.cell
    stronghold.take_damage(9999)
    assert(main.campaign_conquered,
        "Destroying the enemy stronghold must end the campaign")
    assert(main.territory.owner_at(enemy_cell) != "enemy",
        "Destroyed stronghold must release enemy territory")
    assert(get_nodes_in_group("enemy_garrison").is_empty(),
        "Stronghold destruction must clear its remaining garrison")
    assert(paused, "Campaign victory must display a paused victory state")

    print("PASS: hostile territory, fog reveal, expedition order, garrison persistence, dawn survival, conquest")
    quit()
