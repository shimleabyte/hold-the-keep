extends SceneTree

var world_config
var data_db
var faction_registry
var game_clock
var events
var save_system

## Bounded Frontier workload: four factions, mixed rosters, ranged projectile,
## 48 villagers, and the shared particle ceiling.

const MAX_PARTICLES := 500
const VILLAGERS := 48
const ENEMIES_PER_FACTION := 10
const FACTION_IDS := [
    "greenwood_raiders",
    "iron_legion",
    "fen_cult",
    "ashen_host"
]


func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func _reachable_region_cells(main: Node, region_id: String, limit: int) -> Array[Vector2i]:
    var start: Vector2i = main.nav.cell_of(main.player.global_position)
    var reachable: Dictionary = main.nav.reachable_cells(start)
    var cells: Array[Vector2i] = []
    for value in reachable.keys():
        var cell: Vector2i = value
        if String(main.world.region_id(cell)) != region_id:
            continue
        if main.world.occupied.has(cell):
            continue
        cells.append(cell)
        if cells.size() >= limit:
            break
    return cells


func _spawn_faction_enemy(main: Node, faction_id: String, enemy_id: String, cell: Vector2i) -> Node:
    var enemy = load("res://scripts/entities/enemy.gd").new()
    enemy.setup(data_db.enemies[enemy_id], main.world, main.flow, main.player, faction_id)
    enemy.position = Vector2(cell) * world_config.tile_size + Vector2(8.0, 8.0)
    main.world.entities.add_child(enemy)
    return enemy


func _find_fx_layer(main: Node) -> Node:
    for child in main.world.get_children():
        if child.has_method("count") and child.has_method("spawn"):
            return child
    return null


func _run() -> void:
    world_config.apply_profile("frontier")
    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(8)
    game_clock.set_process(false)
    main.nav.rebuild()

    assert(world_config.profile_id == "frontier" and main.world.map_size == 128,
        "Stress workload must execute on the 128x128 Frontier profile")
    assert(faction_registry.factions.size() == 4,
        "All four regional factions must be loaded")

    var seen_factions: Dictionary = {}
    for faction_id in FACTION_IDS:
        assert(faction_registry.factions.has(faction_id),
            "Missing Frontier faction: " + faction_id)
        var faction: Dictionary = faction_registry.factions[faction_id]
        var region_id := String(faction.get("region", ""))
        var roster: Array[String] = faction_registry.roster_for(faction_id)
        assert(not roster.is_empty(), "Faction roster must not be empty: " + faction_id)
        var cells := _reachable_region_cells(main, region_id, ENEMIES_PER_FACTION)
        assert(cells.size() == ENEMIES_PER_FACTION,
            "Faction territory must expose enough reachable stress cells: " + faction_id)

        for i in range(ENEMIES_PER_FACTION):
            var enemy_id := roster[i % roster.size()]
            assert(data_db.enemies.has(enemy_id),
                "Faction roster references an unregistered enemy: " + enemy_id)
            _spawn_faction_enemy(main, faction_id, enemy_id, cells[i])
            seen_factions[faction_id] = true

    assert(seen_factions.size() == 4,
        "Stress workload must include all four faction identities")

    for i in range(VILLAGERS):
        var column := (i % 8) - 4
        var row := floori(float(i) / 8.0) - 3
        main.village.spawn_villager(
            main.world.keep_center_position() + Vector2(float(column * 5), float(row * 5))
        )

    main.village.quota = {
        "woodcutter": 12,
        "miner": 12,
        "farmer": 12,
        "builder": 0,
        "soldier": 12
    }
    main.village.assign_jobs()

    # Trigger a real ranged attack so the projectile node and physics path are exercised.
    assert(data_db.enemies.has("archer"), "The ranged archer definition must exist")
    var archer = load("res://scripts/entities/enemy.gd").new()
    archer.setup(data_db.enemies["archer"], main.world, main.flow, main.player, "iron_legion")
    archer.position = main.player.position + Vector2(128.0, 0.0)
    main.world.entities.add_child(archer)
    archer._begin_ranged_attack(main.player)
    await ticks(14)

    var projectiles := get_nodes_in_group("enemy_projectiles")
    assert(projectiles.size() > 0,
        "A ranged attacker must produce at least one live projectile under load")

    var fx = _find_fx_layer(main)
    assert(fx != null, "The shared FX layer must be present")
    for i in range(70):
        events.fx_burst.emit("impact", main.player.position, Vector2.RIGHT, 2.0)
    for i in range(10):
        events.fx_burst.emit("debris", main.player.position, Vector2.LEFT, 1.0)
    assert(fx.count() == MAX_PARTICLES,
        "The shared particle store must clamp to its configured 500-particle ceiling")

    var enemies := get_nodes_in_group("enemies")
    var villagers := get_nodes_in_group("villagers")
    assert(enemies.size() >= ENEMIES_PER_FACTION * FACTION_IDS.size(),
        "Faction stress enemies must remain registered")
    assert(villagers.size() >= VILLAGERS,
        "The stress population must remain registered")

    var snapshot: Dictionary = save_system.collect(main)
    assert(snapshot["world"]["map_size"] == 128
        and snapshot["world"]["profile"] == "frontier",
        "Stress snapshot must retain Frontier world identity")
    assert(snapshot["enemies"].size() >= ENEMIES_PER_FACTION * FACTION_IDS.size(),
        "Stress snapshot must retain the loaded faction population")
    assert(save_system._valid_save(snapshot),
        "The high-population Frontier snapshot must pass current save validation")

    print("PASS: Frontier stress: 128x128, four factions, %d enemies, %d villagers, %d projectiles, %d particles" % [
        enemies.size(), villagers.size(), projectiles.size(), fx.count()
    ])
    quit(0)


func _initialize() -> void:
    world_config = root.get_node("WorldConfig")
    data_db = root.get_node("DataDB")
    faction_registry = root.get_node("FactionRegistry")
    game_clock = root.get_node("GameClock")
    events = root.get_node("Events")
    save_system = root.get_node("SaveSystem")
    call_deferred("_run")
