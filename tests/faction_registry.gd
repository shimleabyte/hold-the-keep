extends SceneTree
## Phase 06 regression: faction data, regional identity, garrisons, support and persistence.

func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func guards_for(stronghold) -> Array:
    var guards: Array = []
    for guard in get_nodes_in_group("enemy_garrison"):
        if is_instance_valid(guard) and guard.guard_origin.distance_squared_to(stronghold.position) < 1.0:
            guards.append(guard)
    return guards


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var config = root.get_node("WorldConfig")
    var save_system = root.get_node("SaveSystem")
    var registry = root.get_node("FactionRegistry")
    var data_db = root.get_node("DataDB")
    config.apply_profile("frontier")
    DirAccess.remove_absolute("user://save.json")
    DirAccess.remove_absolute("user://save.tmp")
    DirAccess.remove_absolute("user://save.bak")

    var errors: Array[String] = registry.validate()
    assert(errors.is_empty(), "Invalid faction definitions: %s" % "; ".join(errors))
    assert(registry.factions.size() == 4, "Expected four Frontier factions")
    assert(registry.archetypes.size() == 6, "Expected six new enemy archetypes")

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(8)
    root.get_node("GameClock").set_process(false)

    var expected_regions := ["GREENWOOD", "HIGHLANDS", "FENLANDS", "ASHEN_MARCH"]
    var expected_factions := ["greenwood_raiders", "iron_legion", "fen_cult", "ashen_host"]
    for index in expected_regions.size():
        var faction_id: String = String(registry.faction_for_region(expected_regions[index]))
        assert(faction_id == expected_factions[index], "Region-to-faction mapping must be deterministic")
        var stronghold = main.campaign._nodes[faction_id]
        assert(is_instance_valid(stronghold), "Each faction must own its regional stronghold")
        var guards := guards_for(stronghold)
        assert(guards.size() == 3, "Each stronghold must spawn three guards")
        var roster: Array[String] = registry.roster_for(faction_id)
        for guard in guards:
            assert(guard.faction_id == faction_id, "Garrison must retain its faction identity")
            assert(roster.has(guard.id), "Garrison unit must belong to its faction roster")
            assert(guard.modulate == Color(String(registry.factions[faction_id]["color"])),
                "Enemy visual tint must reflect faction identity")

    var enemy_script = load("res://scripts/entities/enemy.gd")
    var shaman = enemy_script.new()
    shaman.setup(data_db.enemies["enemy_war_shaman"], main.world, main.flow, main.player, "fen_cult")
    shaman.position = main.player.position + Vector2(180, 0)
    main.world.entities.add_child(shaman)
    shaman.set_physics_process(false)

    var ally = enemy_script.new()
    ally.setup(data_db.enemies["enemy_scout"], main.world, main.flow, main.player, "fen_cult")
    ally.position = shaman.position + Vector2(20, 0)
    main.world.entities.add_child(ally)
    ally.set_physics_process(false)
    ally.hp -= 12
    var ally_hp: int = int(ally.hp)

    var rival = enemy_script.new()
    rival.setup(data_db.enemies["enemy_scout"], main.world, main.flow, main.player, "greenwood_raiders")
    rival.position = shaman.position + Vector2(5, 0)
    main.world.entities.add_child(rival)
    rival.set_physics_process(false)
    rival.hp -= 12
    var rival_hp: int = int(rival.hp)

    assert(shaman._tick_shaman_support(), "War Shaman must activate support when an ally is injured")
    assert(ally.hp > ally_hp, "War Shaman must restore same-faction ally health")
    assert(rival.hp == rival_hp, "War Shaman must not heal a rival faction unit")

    var snapshot: Dictionary = save_system.collect(main)
    assert(snapshot["version"] == 13, "Current campaign, depot and shipment state must use save format v13")
    var found_faction_save := false
    for saved_enemy in snapshot["enemies"]:
        if String(saved_enemy.get("faction", "")).is_empty():
            continue
        found_faction_save = true
        assert(registry.factions.has(String(saved_enemy["faction"])),
            "Saved faction IDs must resolve to known faction definitions")
    assert(found_faction_save, "Save must retain faction identity for spawned enemies")
    assert(save_system._valid_save(snapshot), "Faction-enabled save must pass structural validation")

    print("PASS: faction data, regional mapping, garrison rosters, faction tint, shaman support and v13 persistence")
    quit(0)
