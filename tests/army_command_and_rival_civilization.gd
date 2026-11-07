extends SceneTree

## Verifies soldiers-only mouse orders and the first persistent rival civilization.

var failed: bool = false


func _initialize() -> void:
    OS.set_environment("HTK_AUTO_START_GAME", "1")
    OS.set_environment("HTK_AUTO_RESOLVE_EVENTS", "1")
    await process_frame

    var scene_resource: PackedScene = load("res://scenes/main.tscn") as PackedScene
    var main_scene: Node2D = scene_resource.instantiate() as Node2D
    if main_scene == null:
        push_error("FAIL: Main scene could not be instantiated")
        quit(1)
        return
    root.add_child(main_scene)
    await process_frame
    await process_frame

    var player: Node2D = main_scene.get("player") as Node2D
    var commander: Node = main_scene.get("army_command") as Node
    _check(player != null, "The direct-control player avatar must exist")
    _check(commander != null, "Main scene must install the army command manager")
    if player == null or commander == null:
        main_scene.queue_free()
        quit(1)
        return

    _check(player.visible, "The direct-control player avatar must remain visible")
    _check(player.is_physics_processing(), "The direct-control player must retain physics input")
    var player_camera: Camera2D = player.get("camera") as Camera2D
    _check(player_camera != null and player_camera.is_current(),
        "The direct-control player's camera must remain current")

    var units: Array[Node] = get_nodes_in_group("villagers")
    _check(units.size() >= 2, "Classic campaign should create starting villagers")
    if units.size() < 2:
        main_scene.queue_free()
        quit(1)
        return

    var worker: Node2D = units[0] as Node2D
    if worker == null:
        _check(false, "The starting villager must be a Node2D")
        main_scene.queue_free()
        quit(1)
        return
    _check(String(worker.get("job")) != "soldier", "Starting civilian should remain an autonomous worker")
    commander.call("select_unit", worker)
    var selected_units: Array = commander.get("selected_units")
    _check(selected_units.is_empty(), "Civilian workers must not be selectable by the army command manager")

    _check(bool(worker.call("set_job", "soldier")), "Worker should be convertible to a soldier for command testing")
    commander.call("select_unit", worker)
    selected_units = commander.get("selected_units")
    _check(selected_units.size() == 1 and selected_units[0] == worker,
        "A soldier should be selectable")
    var state_constants: Dictionary = worker.get_script().get_script_constant_map().get("State", {})

    var navigation: Node = main_scene.get("nav") as Node
    var start_cell: Vector2i = navigation.call("cell_of", worker.global_position)
    var reachable: Dictionary = navigation.call("reachable_cells", start_cell)
    var destination_cell: Vector2i = Vector2i(-1, -1)
    for cell_value: Vector2i in reachable.keys():
        if Vector2(cell_value - start_cell).length() >= 5.0 and bool(navigation.call("is_walkable", cell_value)):
            destination_cell = cell_value
            break
    _check(destination_cell.x >= 0, "Army movement fixture must find a reachable destination")
    if destination_cell.x >= 0:
        var destination: Vector2 = navigation.call("center_of", destination_cell)
        _check(int(commander.call("issue_move_order", destination)) == 1,
            "One selected soldier should receive a move order")
        _check(int(worker.get("state")) == int(state_constants.get("MANUAL_MOVE", -1)),
            "A move order should enter the explicit manual-move state")

    var campaign: Node = main_scene.get("campaign") as Node
    var stronghold: Node2D = campaign.call("current_target_node") as Node2D
    _check(stronghold != null, "Classic campaign should expose its rival stronghold")
    if stronghold != null:
        commander.call("select_unit", worker)
        _check(int(commander.call("issue_attack_order", stronghold)) == 1,
            "A selected soldier should accept an attack order against the enemy stronghold")
        _check(int(worker.get("state")) == int(state_constants.get("FIGHT", -1)),
            "A stronghold attack order should enter the existing combat state")
        _check(worker.get("_manual_attack_target") == stronghold,
            "A soldier must retain the commander-selected target rather than reacquiring a random enemy")

        var civilization: RefCounted = stronghold.get("civilization") as RefCounted
        _check(civilization != null, "Every enemy stronghold should own an autonomous civilization")
        if civilization != null:
            var resources: Dictionary = civilization.get("resources")
            var starting_wood: float = float(resources.get("wood", 0.0))
            _check(starting_wood > 0.0, "Rival civilization should start with a finite resource ledger")
            for tick: int in range(270):
                civilization.call("advance", 1.0)

            _check(bool(civilization.call("_has_structure", "lumber_camp")),
                "Rival civilization should construct a visible lumber camp")
            _check(bool(civilization.call("_has_structure", "farm")),
                "Rival civilization should construct food infrastructure")
            _check(bool(civilization.call("_has_structure", "quarry")),
                "Rival civilization should construct a stone and iron source")
            _check(bool(civilization.call("_has_structure", "barracks")),
                "Rival civilization should eventually invest in military production")
            var technology_tier: int = int(civilization.get("technology_tier"))
            var technology_advanced: bool = technology_tier >= 1
            _check(technology_advanced,
                "Rival civilization should advance technology after meeting prerequisites")

            var structures: Array = civilization.get("structures")
            _check(not structures.is_empty(),
                "Completed rival structures should exist as world entities")
            var labor: Dictionary = civilization.call("labor_allocation")
            var expected_workforce: int = civilization.call(
                "workforce_for_garrison", int(labor.get("garrison", 0))
            )
            _check(int(labor.get("available", -1)) == expected_workforce,
                "Rival workforce must shrink as soldiers are recruited")
            var allocated_workers: int = (
                int(labor.get("builders", 0))
                + int(labor.get("lumber_camp", 0))
                + int(labor.get("farm", 0))
                + int(labor.get("quarry", 0))
                + int(labor.get("forge", 0))
                + int(labor.get("idle", 0))
            )
            _check(allocated_workers == expected_workforce,
                "Rival labor allocation must never assign a citizen to two jobs")
            for workplace_id: String in ["lumber_camp", "farm", "quarry", "forge", "builders"]:
                _check(int(labor.get(workplace_id, 0)) <= 2,
                    "%s must respect its two-worker labor cap" % workplace_id)
            _check(int(civilization.call("workforce_for_garrison", 3)) == 5,
                "Three starting soldiers must leave five citizens available for the economy")
            _check(int(civilization.call("workforce_for_garrison", 8)) == 2,
                "A full garrison must leave only the protected two-worker minimum")

            var stocks_before_production: Dictionary = resources.duplicate(true)
            var active_capacity: float = civilization.call("resource_capacity", "wood")
            var expected_wood: float = float(stocks_before_production.get("wood", 0.0)) + minf(
                0.08 + 0.525 * float(labor.get("lumber_camp", 0)),
                maxf(0.0, active_capacity - float(stocks_before_production.get("wood", 0.0)))
            )
            var stone_capacity: float = civilization.call("resource_capacity", "stone")
            var expected_stone: float = float(stocks_before_production.get("stone", 0.0)) + minf(
                0.025 + 0.31 * float(labor.get("quarry", 0)),
                maxf(0.0, stone_capacity - float(stocks_before_production.get("stone", 0.0)))
            )
            var iron_capacity: float = civilization.call("resource_capacity", "iron")
            var expected_iron: float = float(stocks_before_production.get("iron", 0.0)) + minf(
                0.04 * float(labor.get("quarry", 0))
                    + 0.11 * float(labor.get("forge", 0)),
                maxf(0.0, iron_capacity - float(stocks_before_production.get("iron", 0.0)))
            )
            var food_capacity: float = civilization.call("resource_capacity", "food")
            var expected_food_income: float = 0.42 + 0.625 * float(labor.get("farm", 0))
            var expected_food: float = maxf(
                0.0,
                float(stocks_before_production.get("food", 0.0))
                    + minf(
                        expected_food_income,
                        maxf(0.0, food_capacity - float(stocks_before_production.get("food", 0.0)))
                    )
                    - 0.04 * float(labor.get("available", 0))
                    - 0.06 * float(labor.get("garrison", 0))
            )
            civilization.call("_produce_resources")
            _check(is_equal_approx(float(resources.get("wood", 0.0)), expected_wood),
                "Rival wood production must scale with assigned lumber workers")
            _check(is_equal_approx(float(resources.get("stone", 0.0)), expected_stone),
                "Rival stone production must scale with assigned quarry workers")
            _check(is_equal_approx(float(resources.get("iron", 0.0)), expected_iron),
                "Rival iron production must be staffed by quarry/forge workers")
            _check(is_equal_approx(float(resources.get("food", 0.0)), expected_food),
                "Rival food balance must include farm labor and population upkeep")

            var base_storage_capacity: float = civilization.call("storage_capacity", false)
            var expanded_storage_capacity: float = civilization.call("storage_capacity", true)
            _check(is_equal_approx(base_storage_capacity, 240.0),
                "Rival stockpiles must have a finite base capacity")
            _check(is_equal_approx(expanded_storage_capacity, 600.0),
                "Completing Storage must expand the rival stockpile capacity")
            var original_wood_balance: float = float(resources.get("wood", 0.0))
            var active_wood_capacity: float = civilization.call("resource_capacity", "wood")
            resources["wood"] = active_wood_capacity - 0.25
            civilization.call("_credit_income", "wood", 5.0)
            _check(is_equal_approx(float(resources.get("wood", 0.0)), active_wood_capacity),
                "Rival production must stop exactly at the active stockpile capacity")
            resources["wood"] = active_wood_capacity
            var full_storage_labor: Dictionary = civilization.call("labor_allocation")
            _check(int(full_storage_labor.get("lumber_camp", 0)) == 0,
                "A full wood stockpile must release Lumber Camp labor to another task")
            resources["wood"] = active_wood_capacity + 25.0
            civilization.call("_credit_income", "wood", 5.0)
            _check(is_equal_approx(float(resources.get("wood", 0.0)), active_wood_capacity + 25.0),
                "Loading an over-cap v17 stockpile must not silently delete saved resources")
            resources["wood"] = original_wood_balance

            var snapshot: Dictionary = stronghold.call("export_state")
            var saved_civilization: Dictionary = snapshot.get("civilization", {})
            var saved_structure_values: Variant = saved_civilization.get("structures", null)
            var saved_structures_valid: bool = saved_structure_values is Array
            _check(saved_civilization.has("structures") and saved_structures_valid,
                "Stronghold state must persist the rival economy and completed structures")
            _check(float(resources.get("wood", 0.0)) <= 999.0,
                "Rival resource stock must remain bounded")

            if not structures.is_empty():
                var structure: Node2D = structures[0] as Node2D
                var destroyed_structure_id: String = String(structure.get("structure_id"))
                var occupied_cell: Vector2i = structure.get("cell")
                structure.call("take_damage", 9999)
                var world: Node = main_scene.get("world") as Node
                var occupied: Dictionary = world.get("occupied")
                _check(not occupied.has(occupied_cell),
                    "Destroying a rival structure must release its world footprint")
                if destroyed_structure_id in ["lumber_camp", "farm", "quarry", "forge"]:
                    var labor_after_destruction: Dictionary = civilization.call("labor_allocation")
                    _check(int(labor_after_destruction.get(destroyed_structure_id, -1)) == 0,
                        "Destroyed production buildings must release their assigned workers")


    if stronghold != null:
        var original_faction_id: String = String(stronghold.get("faction_id"))
        var base_civilization: RefCounted = stronghold.get("civilization") as RefCounted
        _check(base_civilization != null, "A live rival civilization instance must exist before testing doctrine strategy")
        var civilization_script: Script = base_civilization.get_script() as Script if base_civilization != null else null
        _check(civilization_script != null, "The live rival civilization must expose its compiled script")
        var expected_labor_orders: Dictionary = {
            "greenwood_raiders": ["lumber_camp", "quarry", "farm", "forge"],
            "iron_legion": ["quarry", "lumber_camp", "farm", "forge"],
            "fen_cult": ["farm", "lumber_camp", "quarry", "forge"],
            "ashen_host": ["quarry", "forge", "lumber_camp", "farm"]
        }
        var expected_orders: Dictionary = {
            "greenwood_raiders": [
                "lumber_camp", "quarry", "barracks", "farm", "tower", "forge", "storage"
            ],
            "iron_legion": [
                "lumber_camp", "quarry", "tower", "farm", "barracks", "storage", "forge"
            ],
            "fen_cult": [
                "farm", "lumber_camp", "quarry", "storage", "barracks", "tower", "forge"
            ],
            "ashen_host": [
                "quarry", "lumber_camp", "farm", "barracks", "forge", "tower", "storage"
            ]
        }
        for faction_key: Variant in expected_orders:
            var faction_id: String = String(faction_key)
            stronghold.set("faction_id", faction_id)
            var strategy_civilization: RefCounted = civilization_script.new() as RefCounted if civilization_script != null else null
            _check(strategy_civilization != null, "A doctrine test civilization must instantiate from the live compiled script")
            if strategy_civilization == null:
                continue
            strategy_civilization.call("setup", stronghold, {})
            var expected_labor_order: Array = expected_labor_orders[faction_id]
            var actual_labor_order: Array[String] = strategy_civilization.call("labor_order")
            _check(actual_labor_order.size() == expected_labor_order.size(),
                "%s doctrine must retain every production job" % faction_id)
            var labor_order_matches: bool = actual_labor_order.size() == expected_labor_order.size()
            if labor_order_matches:
                for labor_index: int in range(expected_labor_order.size()):
                    if actual_labor_order[labor_index] != String(expected_labor_order[labor_index]):
                        labor_order_matches = false
                        break
            _check(labor_order_matches,
                "%s doctrine must prioritize a distinct production workforce" % faction_id)

            var expected_order: Array = expected_orders[faction_id]
            var actual_order: Array[String] = strategy_civilization.call("development_order")
            _check(actual_order.size() == expected_order.size(),
                "%s doctrine must retain every rival building" % faction_id)
            var order_matches: bool = actual_order.size() == expected_order.size()
            if order_matches:
                for index: int in range(expected_order.size()):
                    if actual_order[index] != String(expected_order[index]):
                        order_matches = false
                        break
            _check(order_matches,
                "%s doctrine must produce its own deterministic construction priority" % faction_id)

            var expected_favorite_recruits: Dictionary = {
                "greenwood_raiders": "bandit",
                "iron_legion": "enemy_shieldbearer",
                "fen_cult": "wolf",
                "ashen_host": "enemy_siege_engine"
            }
            var faction_registry: Node = root.get_node_or_null("FactionRegistry")
            _check(faction_registry != null, "Faction registry autoload must be initialized before recruitment strategy tests")
            var faction_roster: Array[String] = faction_registry.call("roster_for", faction_id) if faction_registry != null else []
            var favorite_recruit: String = String(expected_favorite_recruits[faction_id])
            _check(faction_roster.has(favorite_recruit),
                "%s doctrine favorite must belong to its faction roster" % faction_id)
            var empty_garrison: Array[String] = []
            var opening_recruit: String = strategy_civilization.call(
                "choose_recruitment_unit", empty_garrison
            )
            _check(opening_recruit == favorite_recruit,
                "%s doctrine must choose its signature recruitment first" % faction_id)

            var balanced_garrison: Array[String] = []
            for roster_id: String in faction_roster:
                if roster_id != favorite_recruit:
                    balanced_garrison.append(roster_id)
            var composition_recruit: String = strategy_civilization.call(
                "choose_recruitment_unit", balanced_garrison
            )
            _check(composition_recruit == favorite_recruit,
                "%s doctrine must fill the largest composition deficit" % faction_id)

            var unit_cost: Dictionary = strategy_civilization.call(
                "recruitment_cost_for", composition_recruit
            )
            _check(not unit_cost.is_empty(),
                "%s recruit must have an explicit economic cost" % faction_id)
            var recruitment_balance_before: Dictionary = (
                strategy_civilization.get("resources")
            )
            recruitment_balance_before = recruitment_balance_before.duplicate(true)
            _check(bool(strategy_civilization.call("can_recruit", composition_recruit)),
                "%s signature recruit must be affordable from its own ledger" % faction_id)
            _check(bool(strategy_civilization.call("pay_recruitment", composition_recruit)),
                "%s signature recruit must be paid before joining the garrison" % faction_id)
            var recruitment_balance_after: Dictionary = strategy_civilization.get("resources")
            for resource_kind: String in unit_cost:
                _check(
                    is_equal_approx(
                        float(recruitment_balance_after.get(resource_kind, 0.0)),
                        float(recruitment_balance_before.get(resource_kind, 0.0))
                            - float(unit_cost[resource_kind])
                    ),
                    "%s recruitment must debit the correct %s cost" % [faction_id, resource_kind]
                )

            var saved_recruitment_balance: Dictionary = recruitment_balance_after.duplicate(true)
            recruitment_balance_after["food"] = 0.0
            var unaffordable_choice: String = strategy_civilization.call(
                "choose_recruitment_unit", empty_garrison
            )
            _check(unaffordable_choice.is_empty(),
                "%s faction must not recruit when no roster unit can be paid" % faction_id)
            recruitment_balance_after.merge(saved_recruitment_balance, true)

            var first_plan: Dictionary = strategy_civilization.call("_build_plan_for", actual_order[0])
            var first_cost: Dictionary = first_plan.get("cost", {})
            var ledger_before: Dictionary = strategy_civilization.get("resources")
            var wood_before: float = float(ledger_before.get("wood", 0.0))
            var stone_before: float = float(ledger_before.get("stone", 0.0))
            strategy_civilization.call("advance", 1.0)
            var active_construction: Dictionary = strategy_civilization.get("construction")
            _check(String(active_construction.get("id", "")) == actual_order[0],
                "%s doctrine must start its preferred affordable building" % faction_id)
            var ledger_after: Dictionary = strategy_civilization.get("resources")
            var expected_wood: float = wood_before + 0.08 - float(first_cost.get("wood", 0.0))
            var expected_stone: float = stone_before + 0.025 - float(first_cost.get("stone", 0.0))
            _check(is_equal_approx(float(ledger_after.get("wood", 0.0)), expected_wood),
                "%s construction must debit its own wood ledger" % faction_id)
            _check(is_equal_approx(float(ledger_after.get("stone", 0.0)), expected_stone),
                "%s construction must debit its own stone ledger" % faction_id)
        stronghold.set("faction_id", original_faction_id)

    var remaining_workers: Array[Node] = get_nodes_in_group("villagers")
    var civilian_count: int = 0
    for unit_node: Node in remaining_workers:
        var unit: Node2D = unit_node as Node2D
        if unit != worker and String(unit.get("job")) != "soldier":
            civilian_count += 1
    _check(civilian_count >= 1, "Non-selected civilian workers must retain their normal jobs")

    main_scene.queue_free()
    await process_frame
    if failed:
        quit(1)
        return
    print("PASS: army-only commands, staffed rival production, doctrine-specific labor/investment, paid construction, technology and persistence")
    quit()


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    failed = true
    push_error("FAIL: " + message)
