extends Node
## Event acak di awal hari (data/events.json). Hanya jika syarat terpenuhi.

const CHANCE := 0.6

var village


func _ready() -> void:
    Events.day_changed.connect(_on_day_changed)


func _on_day_changed(day: int) -> void:
    var mode_id := "frontier" if WorldConfig.is_frontier_profile() else "classic"
    var campaign_rules: Dictionary = DataDB.campaign_modes.get(mode_id, {})
    var final_day := int(campaign_rules.get("final_day", DataDB.waves.get("final_day", 999)))
    if day < 2 or day >= final_day:
        return
    if randf() > CHANCE:
        return
    var ev := pick(day)
    if not ev.is_empty():
        apply(ev)


func _eligible(ev: Dictionary, day: int) -> bool:
    if int(ev["from_day"]) > day:
        return false
    var req: Dictionary = ev.get("requires", {})
    for k in req:
        if Inventory.get_amount(k) < int(req[k]):
            return false
    var eff: Dictionary = ev.get("effects", {})
    var dv := int(eff.get("villagers", 0))
    if dv > 0 and village.population() >= village.capacity():
        return false
    if dv < 0 and village.population() <= 1:
        return false
    return true


func pick(day: int) -> Dictionary:
    var pool: Array = []
    var total := 0
    for ev in DataDB.events:
        if _eligible(ev, day):
            pool.append(ev)
            total += int(ev["weight"])
    if pool.is_empty():
        return {}
    var r := randi() % total
    for ev in pool:
        r -= int(ev["weight"])
        if r < 0:
            return ev
    return pool[0]


func trigger(id: String) -> bool:
    for ev in DataDB.events:
        if ev["id"] == id:
            apply(ev)
            return true
    return false


func apply(ev: Dictionary) -> void:
    var eff: Dictionary = ev.get("effects", {})
    for k in ["wood", "stone", "food"]:
        if eff.has(k):
            _change(k, int(eff[k]))
    if eff.has("food_pct"):
        var delta := int(Inventory.get_amount("food") * float(eff["food_pct"]) / 100.0)
        _change("food", delta)
    var dv := int(eff.get("villagers", 0))
    if dv > 0:
        for i in dv:
            village.spawn_villager(village.spawn_position())
    elif dv < 0:
        for i in -dv:
            village.remove_one()
    Events.event_triggered.emit(ev["name"], ev["text"])


func _change(kind: String, delta: int) -> void:
    if delta >= 0:
        Inventory.add(kind, delta)
    else:
        Inventory.spend(kind, mini(-delta, Inventory.get_amount(kind)))
