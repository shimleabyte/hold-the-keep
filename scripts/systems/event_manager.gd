extends Node
## Weighted, data-driven events with player decisions and backward-compatible triggers.

const CHANCE := 0.6
const RESOURCE_KEYS: Array[String] = ["wood", "stone", "food", "iron"]

var village
var pending_event: Dictionary = {}
var scheduled_consequences: Array[Dictionary] = []
var auto_resolve_random_events := OS.get_environment("HTK_AUTO_RESOLVE_EVENTS") == "1"


func _ready() -> void:
    Events.day_changed.connect(_on_day_changed)


func _on_day_changed(day: int) -> void:
    _resolve_due_consequences(day)
    if not pending_event.is_empty():
        return
    var mode_id := "frontier" if WorldConfig.is_frontier_profile() else "classic"
    var campaign_rules: Dictionary = DataDB.campaign_modes.get(mode_id, {})
    var final_day := int(campaign_rules.get("final_day", DataDB.waves.get("final_day", 999)))
    if day < 2 or day >= final_day:
        return
    if randf() > CHANCE:
        return
    var ev := pick(day)
    if ev.is_empty():
        return
    var choices: Variant = ev.get("choices", [])
    if auto_resolve_random_events or not choices is Array or choices.is_empty():
        apply(ev)
    else:
        request_decision(ev)


func _eligible(ev: Dictionary, day: int) -> bool:
    if int(ev.get("from_day", 1)) > day:
        return false
    var choices: Variant = ev.get("choices", [])
    if choices is Array and not choices.is_empty():
        for choice_value in choices:
            if choice_value is Dictionary and can_choose(choice_value):
                return true
        return false
    var req: Variant = ev.get("requires", {})
    if not req is Dictionary:
        return false
    for key in req:
        if Inventory.get_amount(String(key)) < int(req[key]):
            return false
    var effects: Variant = ev.get("effects", {})
    if not effects is Dictionary:
        return false
    var villagers_delta := int(effects.get("villagers", 0))
    if village != null and villagers_delta > 0 and village.population() + villagers_delta > village.capacity():
        return false
    if village != null and villagers_delta < 0 and village.population() + villagers_delta < 1:
        return false
    return true


func can_choose(choice: Dictionary) -> bool:
    var requirements: Variant = choice.get("requires", {})
    var effects: Variant = choice.get("effects", {})
    if not requirements is Dictionary or not effects is Dictionary:
        return false
    for resource_value in requirements:
        var resource := String(resource_value)
        var amount := int(requirements[resource_value])
        if not RESOURCE_KEYS.has(resource) or amount < 0:
            return false
        if Inventory.get_amount(resource) < amount:
            return false
    for resource in RESOURCE_KEYS:
        var delta := int(effects.get(resource, 0))
        if delta < 0 and Inventory.get_amount(resource) < -delta:
            return false
    if effects.has("food_pct"):
        var food_delta := int(float(Inventory.get_amount("food")) * float(effects["food_pct"]) / 100.0)
        if food_delta < 0 and Inventory.get_amount("food") < -food_delta:
            return false
    var villagers_delta := int(effects.get("villagers", 0))
    if village != null:
        if villagers_delta > 0 and village.population() + villagers_delta > village.capacity():
            return false
        if villagers_delta < 0 and village.population() + villagers_delta < 1:
            return false
    return true


func pick(day: int) -> Dictionary:
    var pool: Array[Dictionary] = []
    var total := 0
    for event_value in DataDB.events:
        if event_value is Dictionary and _eligible(event_value, day):
            pool.append(event_value)
            total += int(event_value.get("weight", 0))
    if pool.is_empty() or total <= 0:
        return {}
    var roll := randi() % total
    for ev in pool:
        roll -= int(ev.get("weight", 0))
        if roll < 0:
            return ev
    return pool[0]


func request_decision(ev: Dictionary) -> bool:
    if not pending_event.is_empty():
        return false
    var choices: Variant = ev.get("choices", [])
    if not choices is Array or choices.is_empty():
        return false
    var has_eligible_choice := false
    for choice_value in choices:
        if choice_value is Dictionary and can_choose(choice_value):
            has_eligible_choice = true
            break
    if not has_eligible_choice:
        return false
    pending_event = ev.duplicate(true)
    Events.event_decision_requested.emit(pending_event.duplicate(true))
    SaveSystem.save_current(true)
    return true


func resolve_choice(choice_id: String) -> bool:
    if pending_event.is_empty():
        return false
    var choices: Array = pending_event.get("choices", [])
    for choice_value in choices:
        if not choice_value is Dictionary or String(choice_value.get("id", "")) != choice_id:
            continue
        var choice: Dictionary = choice_value
        if not can_choose(choice):
            Events.build_feedback.emit("Pilihan tidak lagi memenuhi biaya atau syarat")
            return false
        var resolved_event := pending_event.duplicate(true)
        _apply_effects(choice.get("effects", {}))
        _schedule_delayed_consequences(resolved_event, choice)
        pending_event.clear()
        Events.event_decision_resolved.emit(String(resolved_event.get("id", "")), choice_id)
        var event_title := String(resolved_event.get("name", "Peristiwa"))
        var choice_label := String(choice.get("label", choice_id))
        var result_text := String(choice.get("result", choice.get("description", "")))
        Events.event_triggered.emit("%s — %s" % [event_title, choice_label], result_text)
        SaveSystem.save_current(true)
        return true
    return false


func cancel_pending_event() -> bool:
    if pending_event.is_empty():
        return false
    var event_id := String(pending_event.get("id", ""))
    pending_event.clear()
    Events.event_decision_resolved.emit(event_id, "cancelled")
    Events.event_triggered.emit("Peristiwa dilewati", "Tidak ada tindakan yang diambil.")
    SaveSystem.save_current(true)
    return true


func export_state() -> Dictionary:
    return {
        "pending_event_id": String(pending_event.get("id", "")),
        "scheduled_consequences": scheduled_consequences.duplicate(true)
    }


func import_state(state: Dictionary) -> void:
    pending_event.clear()
    scheduled_consequences.clear()
    var saved_consequences: Variant = state.get("scheduled_consequences", [])
    if saved_consequences is Array:
        for saved_value in saved_consequences:
            if not saved_value is Dictionary:
                continue
            var saved_entry: Dictionary = saved_value
            var event_id := String(saved_entry.get("event_id", ""))
            var choice_id := String(saved_entry.get("choice_id", ""))
            var consequence_id := String(saved_entry.get("consequence_id", ""))
            var due_day_value: Variant = saved_entry.get("due_day", null)
            if event_id.is_empty() or choice_id.is_empty() or consequence_id.is_empty():
                continue
            if not due_day_value is int or int(due_day_value) < 1:
                continue
            if _find_consequence(event_id, choice_id, consequence_id).is_empty():
                push_warning("EventManager: saved consequence '%s/%s/%s' no longer exists" % [
                    event_id, choice_id, consequence_id
                ])
                continue
            scheduled_consequences.append({
                "event_id": event_id,
                "choice_id": choice_id,
                "consequence_id": consequence_id,
                "due_day": int(due_day_value)
            })
    var pending_id := String(state.get("pending_event_id", ""))
    if pending_id.is_empty():
        return
    for event_value in DataDB.events:
        if not event_value is Dictionary or String(event_value.get("id", "")) != pending_id:
            continue
        var choices: Variant = event_value.get("choices", [])
        if not choices is Array or choices.is_empty():
            push_warning("EventManager: saved decision '%s' has no choices" % pending_id)
            return
        var has_eligible_choice := false
        for choice_value in choices:
            if choice_value is Dictionary and can_choose(choice_value):
                has_eligible_choice = true
                break
        if not has_eligible_choice:
            push_warning("EventManager: saved decision '%s' has no affordable choice" % pending_id)
            return
        pending_event = event_value.duplicate(true)
        Events.event_decision_requested.emit(pending_event.duplicate(true))
        return
    push_warning("EventManager: saved decision '%s' no longer exists" % pending_id)


func _schedule_delayed_consequences(event_value: Dictionary, choice: Dictionary) -> void:
    var definitions: Variant = choice.get("consequences", [])
    if not definitions is Array:
        return
    var event_id := String(event_value.get("id", ""))
    var choice_id := String(choice.get("id", ""))
    for definition_value in definitions:
        if not definition_value is Dictionary:
            continue
        var definition: Dictionary = definition_value
        var consequence_id := String(definition.get("id", ""))
        var delay_value: Variant = definition.get("after_days", 0)
        var effects: Variant = definition.get("effects", {})
        if consequence_id.is_empty() or not delay_value is int or int(delay_value) < 1:
            push_warning("EventManager: invalid delayed consequence in %s/%s" % [event_id, choice_id])
            continue
        if not effects is Dictionary or effects.is_empty():
            push_warning("EventManager: delayed consequence %s has no effects" % consequence_id)
            continue
        scheduled_consequences.append({
            "event_id": event_id,
            "choice_id": choice_id,
            "consequence_id": consequence_id,
            "due_day": int(GameClock.day) + int(delay_value)
        })


func _find_consequence(event_id: String, choice_id: String, consequence_id: String) -> Dictionary:
    for event_value in DataDB.events:
        if not event_value is Dictionary or String(event_value.get("id", "")) != event_id:
            continue
        var choices: Variant = event_value.get("choices", [])
        if not choices is Array:
            return {}
        for choice_value in choices:
            if not choice_value is Dictionary or String(choice_value.get("id", "")) != choice_id:
                continue
            var definitions: Variant = choice_value.get("consequences", [])
            if not definitions is Array:
                return {}
            for definition_value in definitions:
                if definition_value is Dictionary and String(definition_value.get("id", "")) == consequence_id:
                    return definition_value.duplicate(true)
            return {}
    return {}


func _resolve_due_consequences(day: int) -> int:
    var remaining: Array[Dictionary] = []
    var due: Array[Dictionary] = []
    for scheduled_value in scheduled_consequences:
        if int(scheduled_value.get("due_day", 2147483647)) <= day:
            due.append(scheduled_value)
        else:
            remaining.append(scheduled_value)
    if due.is_empty():
        return 0

    # Remove due entries before effects are applied. The resulting resource state
    # and reduced queue are then persisted together by the normal atomic save path.
    scheduled_consequences = remaining
    var applied_count := 0
    for scheduled in due:
        var event_id := String(scheduled.get("event_id", ""))
        var choice_id := String(scheduled.get("choice_id", ""))
        var consequence_id := String(scheduled.get("consequence_id", ""))
        var definition := _find_consequence(event_id, choice_id, consequence_id)
        if definition.is_empty():
            push_warning("EventManager: cannot resolve delayed consequence %s/%s/%s" % [
                event_id, choice_id, consequence_id
            ])
            continue
        _apply_effects(definition.get("effects", {}))
        var event_name := event_id
        for event_value in DataDB.events:
            if event_value is Dictionary and String(event_value.get("id", "")) == event_id:
                event_name = String(event_value.get("name", event_id))
                break
        Events.event_triggered.emit(
            "Akibat keputusan — %s" % event_name,
            String(definition.get("result", definition.get("description", "Akibat keputusan telah terjadi.")))
        )
        applied_count += 1

    SaveSystem.save_current(true)
    return applied_count


## Compatibility entry point used by diagnostics and scripted campaign events.
func trigger(id: String) -> bool:
    for ev in DataDB.events:
        if String(ev.get("id", "")) == id:
            apply(ev)
            return true
    return false


## Legacy event resolution remains automatic for explicit trigger/apply callers.
func apply(ev: Dictionary) -> void:
    _apply_effects(ev.get("effects", {}))
    Events.event_triggered.emit(String(ev.get("name", "Peristiwa")), String(ev.get("text", "")))


func _apply_effects(value: Variant) -> void:
    if not value is Dictionary:
        return
    var effects: Dictionary = value
    for kind in RESOURCE_KEYS:
        if effects.has(kind):
            _change(kind, int(effects[kind]))
    if effects.has("food_pct"):
        var delta := int(float(Inventory.get_amount("food")) * float(effects["food_pct"]) / 100.0)
        _change("food", delta)
    var villagers_delta := int(effects.get("villagers", 0))
    if village != null and villagers_delta > 0:
        for _index in villagers_delta:
            if village.population() >= village.capacity():
                break
            village.spawn_villager(village.spawn_position())
    elif village != null and villagers_delta < 0:
        for _index in -villagers_delta:
            if village.population() <= 1:
                break
            village.remove_one()


func _change(kind: String, delta: int) -> void:
    if delta >= 0:
        Inventory.add(kind, delta)
    else:
        Inventory.spend(kind, mini(-delta, Inventory.get_amount(kind)))
