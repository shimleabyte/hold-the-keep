extends SceneTree
## Decision event regressions: affordability, atomic costs, cancellation and save/restore.

var failures: Array[String] = []
var _inventory
var _clock
var _save_system
var _data_db
var _world_config


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    _inventory = root.get_node("Inventory")
    _clock = root.get_node("GameClock")
    _save_system = root.get_node("SaveSystem")
    _data_db = root.get_node("DataDB")
    _world_config = root.get_node("WorldConfig")
    for path in [_save_system.PATH, _save_system.TMP, _save_system.BACKUP]:
        DirAccess.remove_absolute(path)

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    await _ticks(4)
    var manager = main.events
    manager.auto_resolve_random_events = true
    _inventory.reset()

    var trader := _event_by_id("trader")
    var trade := _choice_by_id(trader, "trade")
    var decline := _choice_by_id(trader, "decline")
    _inventory.items["wood"] = 5
    _require(not manager.can_choose(trade), "Trade must be unavailable when its resource requirement is unaffordable")
    _require(manager.can_choose(decline), "A no-cost alternative must remain available")

    _inventory.items["wood"] = 15
    _inventory.items["food"] = 0
    _require(manager.request_decision(trader), "An eligible event should become pending")
    _require(manager.pending_event.get("id", "") == "trader", "The requested event must be retained as pending")
    _require(paused, "A pending decision must pause simulation")

    var decision_panel = _find_decision_panel(main)
    _require(decision_panel != null and decision_panel.visible, "The HUD must show the decision panel")
    var saved_snapshot: Dictionary = _save_system.collect(main)
    var saved_events: Dictionary = saved_snapshot.get("events", {})
    _require(saved_events.get("pending_event_id", "") == "trader", "Save collection must persist the unresolved event ID")
    _require(_save_system._valid_save(saved_snapshot), "A save containing a pending event must remain valid")
    var legacy_snapshot: Dictionary = saved_snapshot.duplicate(true)
    legacy_snapshot.erase("events")
    _require(_save_system._valid_save(legacy_snapshot),
        "Existing v17 saves without an event-state extension must remain valid")

    _require(manager.resolve_choice("trade"), "An affordable choice should resolve")
    _require(_inventory.get_amount("wood") == 5, "Trade cost must be paid exactly once")
    _require(_inventory.get_amount("food") == 15, "Trade reward must be granted exactly once")
    _require(manager.scheduled_consequences.size() == 1,
        "A selected trade must schedule exactly one delayed supplier delivery")
    var scheduled_delivery: Dictionary = {}
    if not manager.scheduled_consequences.is_empty():
        scheduled_delivery = manager.scheduled_consequences[0]
    else:
        _require(false, "A valid delayed consequence must be present before inspecting its fields")
    var expected_delivery_day := int(_clock.day) + 2
    _require(int(scheduled_delivery.get("due_day", -1)) == expected_delivery_day,
        "Delayed delivery must use an absolute campaign day, not a frame timer")
    _require(scheduled_delivery.get("event_id", "") == "trader"
        and scheduled_delivery.get("choice_id", "") == "trade"
        and scheduled_delivery.get("consequence_id", "") == "supplier_delivery",
        "Scheduled consequences must reference their immutable static definition")

    var consequence_snapshot: Dictionary = _save_system.collect(main)
    var consequence_state: Dictionary = consequence_snapshot.get("events", {})
    _require(consequence_state.get("scheduled_consequences", []).size() == 1,
        "Save collection must persist the unresolved delayed consequence")
    _require(_save_system._valid_save(consequence_snapshot),
        "A save containing a valid delayed consequence must pass validation")

    var json_snapshot: Variant = JSON.parse_string(JSON.stringify(consequence_snapshot))
    _require(json_snapshot is Dictionary and _save_system._valid_save(json_snapshot),
        "JSON round-trip must preserve valid delayed consequence numbers for save validation")
    var exported_event_state: Dictionary = manager.export_state()
    var json_event_state: Variant = JSON.parse_string(JSON.stringify(exported_event_state))
    _require(json_event_state is Dictionary,
        "Exported event state must survive JSON serialization")
    manager.scheduled_consequences.clear()
    manager.import_state(json_event_state if json_event_state is Dictionary else {})
    _require(manager.scheduled_consequences.size() == 1,
        "Import must restore a delayed consequence by resolving its static event reference")

    var invalid_consequence_snapshot: Dictionary = consequence_snapshot.duplicate(true)
    invalid_consequence_snapshot["events"]["scheduled_consequences"][0]["consequence_id"] = "missing_delivery"
    _require(not _save_system._valid_save(invalid_consequence_snapshot),
        "Save validation must reject a scheduled consequence whose static definition is missing")

    var food_before_delivery := int(_inventory.get_amount("food"))
    _require(manager._resolve_due_consequences(expected_delivery_day) == 1,
        "The due-day resolver must apply one scheduled consequence")
    _require(_inventory.get_amount("food") == food_before_delivery + 8,
        "The supplier delivery must apply its eight-food reward on the due day")
    _require(manager.scheduled_consequences.is_empty(),
        "A resolved delayed consequence must be removed from the pending queue")
    _require(manager._resolve_due_consequences(expected_delivery_day) == 0
        and _inventory.get_amount("food") == food_before_delivery + 8,
        "Resolving the same day twice must not apply the same consequence twice")

    _require(manager.pending_event.is_empty(), "A resolved event must no longer be pending")
    _require(not paused, "Resolving a decision must resume simulation")

    _inventory.items["wood"] = 10
    _inventory.items["food"] = 0
    _require(manager.request_decision(trader), "The event can be offered again after resolution")
    _inventory.items["wood"] = 0
    _require(not manager.resolve_choice("trade"), "A choice must fail when resources change after the offer")
    _require(manager.pending_event.get("id", "") == "trader", "A failed choice must keep the decision open")
    _require(_inventory.get_amount("food") == 0, "A failed choice must not partially grant rewards")
    _require(manager.cancel_pending_event(), "The player must be able to explicitly cancel an event")
    _require(manager.pending_event.is_empty() and not paused,
        "Cancellation must clear the pending event and resume the game")

    _inventory.items["wood"] = 10
    _require(manager.request_decision(trader), "A pending event should be requestable for reload coverage")
    var unresolved_state: Dictionary = manager.export_state()
    _require(unresolved_state.get("pending_event_id", "") == "trader",
        "Exported event state must contain the unresolved event ID")
    _require(manager.cancel_pending_event(), "Test setup should clear the first pending copy")
    manager.import_state(unresolved_state)
    _require(manager.pending_event.get("id", "") == "trader",
        "Import must restore a valid unresolved event from its static definition")
    _require(paused and decision_panel.visible,
        "Restoring an unresolved event must reopen its modal decision surface")
    _require(manager.resolve_choice("decline"), "Restored decisions must remain resolvable")
    _require(manager.pending_event.is_empty() and not paused,
        "Resolving a restored decision must close its modal")

    var invalid_snapshot: Dictionary = _save_system.collect(main)
    invalid_snapshot["events"] = {"pending_event_id": "missing_event"}
    _require(not _save_system._valid_save(invalid_snapshot),
        "Save validation must reject pending event IDs that no longer exist")

    var refugee_event := _event_by_id("refugees")
    var shelter := _choice_by_id(refugee_event, "shelter")
    var turn_away := _choice_by_id(refugee_event, "turn_away")
    _inventory.items["food"] = 0
    _require(not manager.can_choose(shelter), "Refugee shelter must be unavailable without its food cost")
    _require(manager.can_choose(turn_away), "Refusing refugees must remain possible without supplies")

    var original_profile: String = String(_world_config.profile_id)
    _world_config.profile_id = "frontier"
    _require(manager._eligible(trader, 2), "Decision events must remain eligible in Frontier")
    _world_config.profile_id = original_profile
    _require(manager._eligible(trader, 2), "Decision events must remain eligible in Classic")

    main.queue_free()
    await _ticks(2)
    for path in [_save_system.PATH, _save_system.TMP, _save_system.BACKUP]:
        DirAccess.remove_absolute(path)

    if failures.is_empty():
        print("PASS: decision event eligibility, costs, atomic resolution, cancellation, pause state, save/restore, Classic and Frontier")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        quit(1)


func _ticks(count: int) -> void:
    for _index in count:
        await physics_frame


func _find_decision_panel(main_node: Node) -> Control:
    for child in main_node.get_children():
        if child is CanvasLayer:
            for ui_child in child.get_children():
                if ui_child.get_script() != null and ui_child.get_script().resource_path.ends_with("event_decision_panel.gd"):
                    return ui_child as Control
    return null


func _event_by_id(event_id: String) -> Dictionary:
    for event_value in _data_db.events:
        if String(event_value.get("id", "")) == event_id:
            return event_value
    return {}


func _choice_by_id(event_value: Dictionary, choice_id: String) -> Dictionary:
    for choice_value in event_value.get("choices", []):
        if choice_value is Dictionary and String(choice_value.get("id", "")) == choice_id:
            return choice_value
    return {}


func _require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
