extends SceneTree
## Phase 06.5: simultaneous faction garrisons, patrols and infrastructure raids under a populated Frontier workload.

const FACTION_IDS: Array[String] = [
    "greenwood_raiders",
    "iron_legion",
    "fen_cult",
    "ashen_host"
]
const GARRISONS_PER_FACTION := 12
const PATROLS_PER_CAMP := 2
const VILLAGERS := 48
const EXPECTED_RAIDERS := 4
const GLOBAL_RAID_CAP := 4
const EXPECTED_ARCHETYPES: Array[String] = [
    "scout", "shieldbearer", "saboteur", "war_shaman", "siege_engine", "beast_rider"
]

var world_config
var data_db
var faction_registry
var game_clock
var tech
var save_system
var failures: Array[String] = []


func ticks(count: int) -> void:
    for _index in count:
        await physics_frame


func require(condition: bool, message: String) -> void:
    if condition:
        return
    failures.append(message)
    push_error("FAIL: " + message)


func reachable_region_cells(main: Node, region_id: String, limit: int) -> Array[Vector2i]:
    var reachable: Dictionary = main.nav.reachable_cells(
        main.nav.cell_of(main.player.global_position)
    )
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


func find_raid_road_cell(main: Node, camp: Dictionary, used: Dictionary) -> Vector2i:
    var camp_cell: Vector2i = camp["cell"]
    var region_id := String(camp["region_id"])
    for radius in range(5, 13):
        for y in range(-radius, radius + 1):
            for x in range(-radius, radius + 1):
                if maxi(absi(x), absi(y)) != radius:
                    continue
                var cell := camp_cell + Vector2i(x, y)
                if used.has(cell) or not world_config.is_valid_cell(cell):
                    continue
                if not main.world.is_buildable(cell) or main.world.occupied.has(cell):
                    continue
                if not main.nav.is_walkable(cell) or String(main.world.region_id(cell)) != region_id:
                    continue
                var target_cells: Array[Vector2i] = [cell]
                if main.nav.path_adjacent(Vector2(camp["position"]), target_cells).is_empty():
                    continue
                return cell
    return Vector2i(-1, -1)


func expose_road(main: Node, cell: Vector2i) -> void:
    var region_id := String(main.world.region_id(cell))
    main.territory.claimed_cells[cell] = true
    main.territory.enemy_claimed_cells[cell] = true
    var region_state: Dictionary = main.territory.region_states.get(region_id, {})
    region_state["control"] = "contested"
    main.territory.region_states[region_id] = region_state


func spawn_garrison(main: Node, faction_id: String, enemy_id: String, cell: Vector2i, camp_position: Vector2) -> Node:
    var enemy_script = load("res://scripts/entities/enemy.gd")
    var enemy = enemy_script.new()
    enemy.setup(data_db.enemies[enemy_id], main.world, main.flow, main.player, faction_id)
    enemy.is_garrison = true
    enemy.guard_origin = camp_position
    enemy.position = main.nav.center_of(cell)
    main.world.entities.add_child(enemy)
    return enemy


func faction_raider_count(main: Node) -> int:
    return main.get_tree().get_nodes_in_group("faction_raiders").size()


func _initialize() -> void:
    world_config = root.get_node("WorldConfig")
    data_db = root.get_node("DataDB")
    faction_registry = root.get_node("FactionRegistry")
    game_clock = root.get_node("GameClock")
    tech = root.get_node("Tech")
    save_system = root.get_node("SaveSystem")
    call_deferred("_run")


func _run() -> void:
    world_config.apply_profile("frontier")
    for path in ["user://save.json", "user://save.tmp", "user://save.bak"]:
        DirAccess.remove_absolute(path)

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(10)

    game_clock.set_process(false)
    game_clock.set_physics_process(false)
    tech.set_process(false)
    main.spawner.set_process(false)
    main.spawner.set_physics_process(false)
    main.village.set_process(false)
    main.fog.set_process(false)
    main.fog.set_physics_process(false)
    main.supply.set_process(false)
    main.supply.set_physics_process(false)
    main.territory.set_physics_process(false)
    main.frontier_campaign.faction_camps.set_process(false)
    main.nav.set_physics_process(false)

    var manager = main.frontier_campaign.faction_camps
    require(manager != null and is_instance_valid(manager) and manager.camps.size() == 4,
        "The stress workload must start with exactly four Frontier faction camps")

    main.nav.rebuild()
    main.territory.rebuild()
    main.supply.rebuild()

    var used_road_cells: Dictionary = {}
    var road_targets: Dictionary = {}
    for faction_id in FACTION_IDS:
        require(manager.camps.has(faction_id),
            "Missing faction camp for stress workload: " + faction_id)
        var camp: Dictionary = manager.camps[faction_id]
        require(not bool(camp.get("destroyed", false))
            and main.territory.owner_at(camp["cell"]) == "enemy",
            "Every active stress camp must remain in enemy-controlled territory")

        var road_cell := find_raid_road_cell(main, camp, used_road_cells)
        require(road_cell.x >= 0,
            "Each faction region must provide a reachable free road target: " + faction_id)
        used_road_cells[road_cell] = true
        main.build.place_raw("road", road_cell)
        road_targets[faction_id] = road_cell

    main.nav.rebuild()
    main.supply.rebuild()
    main.territory.rebuild()

    for faction_id in FACTION_IDS:
        var road_cell: Vector2i = road_targets[faction_id]
        expose_road(main, road_cell)
        main.supply.connected_road_cells[road_cell] = true
    main.territory._dirty = false
    main.supply._dirty = false

    var total_garrisons := 0
    var garrisons: Array[Node] = []
    var total_patrols := 0
    var total_raiders := 0
    for faction_id in FACTION_IDS:
        var camp: Dictionary = manager.camps[faction_id]
        var region_id := String(camp["region_id"])
        var cells := reachable_region_cells(main, region_id, GARRISONS_PER_FACTION)
        require(cells.size() == GARRISONS_PER_FACTION,
            "Each faction must provide enough reachable garrison cells: " + faction_id)

        var roster: Array[String] = faction_registry.roster_for(faction_id)
        require(not roster.is_empty(), "Faction roster must not be empty: " + faction_id)
        for index in GARRISONS_PER_FACTION:
            var enemy_id := roster[index % roster.size()]
            require(data_db.enemies.has(enemy_id),
                "Faction roster references missing enemy data: " + enemy_id)
            var garrison := spawn_garrison(main, faction_id, enemy_id, cells[index], Vector2(camp["position"]))
            garrisons.append(garrison)
            total_garrisons += 1

        for patrol_index in PATROLS_PER_CAMP:
            require(manager._spawn_patrol(camp),
                "Each camp must dispatch its bounded patrol fixture: " + faction_id)
            total_patrols += 1

        camp = manager.camps[faction_id]
        camp["activated"] = true
        camp["raid_budget"] = 2
        camp["raid_timer"] = 0.0
        manager.camps[faction_id] = camp
        var target: Dictionary = {
            "cell": road_targets[faction_id],
            "kind": "road"
        }
        require(manager._spawn_faction_raid(camp, target),
            "Each faction must dispatch one infrastructure raider: " + faction_id)
        total_raiders += 1

        var raider = faction_raider_count(main)
        require(raider == total_raiders,
            "Raid dispatch count must increase by one per faction without skipping or duplicating units")

    require(total_garrisons == GARRISONS_PER_FACTION * FACTION_IDS.size(),
        "All four factions must contribute their full garrison load")
    require(total_patrols == PATROLS_PER_CAMP * FACTION_IDS.size(),
        "All four camps must contribute their patrol load")
    require(total_raiders == EXPECTED_RAIDERS and total_raiders == GLOBAL_RAID_CAP
        and faction_raider_count(main) == EXPECTED_RAIDERS,
        "All four camps must run simultaneous faction raids")

    var first_camp: Dictionary = manager.camps[FACTION_IDS[0]]
    var extra_target: Dictionary = {
        "cell": road_targets[FACTION_IDS[0]],
        "kind": "road"
    }
    require(not manager._spawn_faction_raid(first_camp, extra_target),
        "The global raid ceiling must reject a fifth active faction raider")

    # Keep the player outside the camp perimeter so this pathing fixture tests infrastructure approach,
    # not the separate player-interception branch covered by faction_raids.gd.
    main.player.global_position = Vector2(180, 180)

    var raiders: Array = get_nodes_in_group("faction_raiders")
    var defender_nodes: Array = get_nodes_in_group("defenders")
    for defender in defender_nodes:
        defender.remove_from_group("defenders")
    for raider in raiders:
        raider.player = null

    for raider in raiders:
        require(is_instance_valid(raider) and raider.is_faction_raider and raider.is_garrison,
            "Every active raid unit must retain garrison and faction-raid identity")
        var expected_camp := String(raider.faction_raid_camp_id)
        var expected_cell: Vector2i = road_targets[expected_camp]
        require(raider.raid_target_cell == expected_cell and raider.faction_raid_target_kind == "road",
            "Every active raider must retain its own faction-region target")
        var target = raider._find_faction_raid_target()
        require(target != null,
            "Faction raider must resolve the road node assigned to its target cell: " + expected_camp)
        if target != null:
            require(raider._faction_raid_target_valid(target, main.supply),
                "Faction raider target must remain exposed, connected and inside its camp region: " + expected_camp)
            var direct_path: PackedVector2Array = main.nav.path_adjacent(raider.position, target.cells())
            require(not direct_path.is_empty(),
                "Faction raider must have a direct reachable path from its camp: " + expected_camp)
        raider._tick_faction_raid(0.016)
        var route_is_current: bool = not raider._raid_path.is_empty() \
            and raider._raid_path_version == main.nav.version
        var target_in_attack_reach: bool = target != null \
            and raider.position.distance_to(target.position) <= maxf(raider._attack_reach(), 28.0)
        require(route_is_current or target_in_attack_reach,
            "Every simultaneous raider must route or engage its reachable target: " + expected_camp)

    for raider in raiders:
        raider.player = main.player
    for defender in defender_nodes:
        if is_instance_valid(defender):
            defender.add_to_group("defenders")

    var saboteur_probe: Node2D
    var siege_probe: Node2D
    for garrison in garrisons:
        if garrison.archetype == "saboteur" and saboteur_probe == null:
            saboteur_probe = garrison
        elif garrison.archetype == "siege_engine" and siege_probe == null:
            siege_probe = garrison
    require(saboteur_probe != null and siege_probe != null,
        "The workload must include both specialist interception policies")
    if saboteur_probe != null:
        var behavior = saboteur_probe.saboteur_behavior
        behavior._interceptor_scan_timer = 0.0
        behavior._nearest_interceptor()
        var saboteur_scan_timer := behavior._interceptor_scan_timer
        behavior._nearest_interceptor()
        require(is_equal_approx(saboteur_scan_timer, 0.12)
            and is_equal_approx(behavior._interceptor_scan_timer, saboteur_scan_timer),
            "Saboteur defender scans must be throttled to one pass per 120ms")
    if siege_probe != null:
        var behavior = siege_probe.siege_behavior
        behavior._disruptor_scan_timer = 0.0
        behavior._nearest_disruptor()
        var siege_scan_timer := behavior._disruptor_scan_timer
        behavior._nearest_disruptor()
        require(is_equal_approx(siege_scan_timer, 0.12)
            and is_equal_approx(behavior._disruptor_scan_timer, siege_scan_timer),
            "Siege Engine defender scans must be throttled to one pass per 120ms")

    # Exercise every specialist controller while all 48 garrisons coexist.
    require(garrisons.size() == GARRISONS_PER_FACTION * FACTION_IDS.size(),
        "The integrated AI tick must include all 48 specialist and baseline garrisons")

    var observed_archetypes: Dictionary = {}
    var fen_shaman: Node2D
    var fen_ally: Node2D
    for garrison in garrisons:
        var archetype_id := String(garrison.archetype)
        if EXPECTED_ARCHETYPES.has(archetype_id):
            observed_archetypes[archetype_id] = true
        match archetype_id:
            "scout":
                require(garrison.scout_behavior.actor == garrison,
                    "Every Scout garrison must have its own configured marking component")
            "shieldbearer":
                require(garrison.shield_behavior.actor == garrison,
                    "Every Shieldbearer garrison must have its own configured brace component")
            "saboteur":
                require(garrison.saboteur_behavior.actor == garrison
                    and garrison.saboteur_behavior.navigation == main.nav,
                    "Every Saboteur garrison must have configured disruption and navigation state")
            "war_shaman":
                require(garrison.support_behavior.actor == garrison,
                    "Every War Shaman garrison must have its own configured support component")
                if String(garrison.faction_id) == "fen_cult" and fen_shaman == null:
                    fen_shaman = garrison
            "siege_engine":
                require(garrison.siege_behavior.actor == garrison
                    and garrison.siege_behavior.navigation == main.nav,
                    "Every Siege Engine garrison must have configured siege and navigation state")
            "beast_rider":
                require(garrison.beast_behavior.actor == garrison
                    and garrison.beast_behavior.navigation == main.nav,
                    "Every Beast Rider garrison must have configured charge and navigation state")
        if String(garrison.faction_id) == "fen_cult" and archetype_id == "scout" and fen_ally == null:
            fen_ally = garrison

    for archetype_id in EXPECTED_ARCHETYPES:
        require(observed_archetypes.has(archetype_id),
            "Combined faction rosters must contain the " + archetype_id + " behavior")

    require(fen_shaman != null and fen_ally != null,
        "Fen Cult stress roster must contain both a War Shaman and a same-faction ally")
    fen_shaman.position = Vector2(manager.camps["fen_cult"]["position"])
    fen_ally.position = fen_shaman.position + Vector2(12.0, 0.0)
    fen_ally.hp = maxi(1, fen_ally.hp - 5)
    var fen_ally_hp_before: int = fen_ally.hp

    var garrison_ai_ticks := 0
    for garrison in garrisons:
        garrison._physics_process(0.016)
        garrison_ai_ticks += 1
    require(garrison_ai_ticks == total_garrisons,
        "All garrison AI policies must execute once in the concurrent battlefield fixture")
    require(fen_ally.hp > fen_ally_hp_before,
        "War Shaman support must heal a same-faction ally while all six archetypes coexist")

    var initial_villager_count := get_nodes_in_group("villagers").size()
    for index in VILLAGERS:
        var column := (index % 8) - 4
        var row := floori(float(index) / 8.0) - 3
        main.village.spawn_villager(
            main.world.keep_center_position() + Vector2(float(column * 5), float(row * 5))
        )

    var enemy_count := get_nodes_in_group("enemies").size()
    var patrol_count := get_nodes_in_group("enemy_patrols").size()
    var raider_count := faction_raider_count(main)
    var villager_count := get_nodes_in_group("villagers").size()
    require(patrol_count == total_patrols and raider_count == EXPECTED_RAIDERS,
        "Faction patrol and raider group membership must remain consistent under load")
    require(villager_count == initial_villager_count + VILLAGERS,
        "The stress population must retain all newly spawned villagers alongside the initial population")

    var snapshot: Dictionary = save_system.collect(main)
    require(snapshot["world"]["profile"] == "frontier" and snapshot["world"]["map_size"] == 128,
        "Stress snapshot must retain the Frontier world identity")
    require(snapshot["frontier_campaign"]["camps"]["records"].size() == 4,
        "Stress snapshot must persist all four faction camp records")
    require(snapshot["enemies"].size() == enemy_count,
        "Stress snapshot must include the full garrison, patrol and raid population")
    require(save_system._valid_save(snapshot),
        "The combined garrison/patrol/raid snapshot must pass save-v13 validation")

    var saved_raids := 0
    for enemy_state in snapshot["enemies"]:
        if enemy_state is Dictionary and bool(enemy_state.get("faction_raid", false)):
            saved_raids += 1
    require(saved_raids == EXPECTED_RAIDERS,
        "Save v13 must persist every simultaneous faction raid assignment")

    if not failures.is_empty():
        push_error("FAIL: Frontier warfare stress collected %d failed assertions: %s" % [
            failures.size(), "; ".join(failures)
        ])
        quit(1)
        return

    print("PASS: Frontier warfare stress: %d garrison AI ticks across six archetypes, %d patrols, %d simultaneous raids, %d enemies, %d additional villagers (%d total)" % [
        garrison_ai_ticks, total_patrols, total_raiders, enemy_count, VILLAGERS, villager_count
    ])
    quit(0)
