extends Node
## Ordered regional conquest objectives. Classic keeps its single-stronghold rules.

const FRONTIER_OBJECTIVES := [
    {"id":"greenwood_raiders","region":"GREENWOOD","faction":"greenwood_raiders","reward":{"wood":70,"food":10}},
    {"id":"iron_legion","region":"HIGHLANDS","faction":"iron_legion","reward":{"stone":50,"iron":5}},
    {"id":"fen_cult","region":"FENLANDS","faction":"fen_cult","reward":{"food":60}},
    {"id":"ashen_host","region":"ASHEN_MARCH","faction":"ashen_host","reward":{"iron":15,"stone":35}}
]

var _order: Array[String] = []
var _records: Dictionary = {}
var _nodes: Dictionary = {}
var _completion_emitted := false


func _ready() -> void:
    add_to_group("campaign")
    Events.stronghold_conquered.connect(_on_stronghold_conquered)


func configure_new(profile_id: String) -> void:
    _order.clear()
    _records.clear()
    _nodes.clear()
    _completion_emitted = false
    if profile_id == "frontier":
        for definition in FRONTIER_OBJECTIVES:
            _add_objective(String(definition["id"]), String(definition["region"]), String(definition["faction"]), definition["reward"])
    else:
        _add_objective("classic_enemy_keep", "", "classic_raiders", {})


func configure_legacy(profile_id: String, saved: Dictionary = {}) -> void:
    _order.clear()
    _records.clear()
    _nodes.clear()
    _completion_emitted = false
    var fallback_id := "classic_enemy_keep" if profile_id == "classic" else "legacy_frontier_keep"
    var stronghold_id := String(saved.get("id", fallback_id))
    _add_objective(stronghold_id, String(saved.get("region", "")), String(saved.get("faction", "legacy_raiders")), {})
    var record: Dictionary = _records[stronghold_id]
    for key in ["cx", "cy", "hp", "destroyed", "reinforce_timer", "spawn_index"]:
        if saved.has(key):
            record[key] = saved[key]
    _records[stronghold_id] = record


func _add_objective(stronghold_id: String, region: String, faction: String, reward: Dictionary) -> void:
    _order.append(stronghold_id)
    _records[stronghold_id] = {
        "id": stronghold_id, "region": region, "faction": faction,
        "cx": -1, "cy": -1, "hp": 900, "destroyed": false,
        "reinforce_timer": 105.0, "spawn_index": 0,
        "reward": reward.duplicate(true)
    }


func objectives_in_order() -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    for stronghold_id in _order:
        if _records.has(stronghold_id):
            var record: Dictionary = _records[stronghold_id]
            out.append(record.duplicate(true))
    return out


func set_objective_location(stronghold_id: String, cell: Vector2i, region: String) -> void:
    if not _records.has(stronghold_id):
        return
    var record: Dictionary = _records[stronghold_id]
    record["cx"] = cell.x
    record["cy"] = cell.y
    record["region"] = region
    _records[stronghold_id] = record


func register_stronghold(stronghold: Node) -> void:
    if stronghold == null or not is_instance_valid(stronghold):
        return
    var stronghold_id := String(stronghold.stronghold_id)
    if not _records.has(stronghold_id):
        _add_objective(stronghold_id, String(stronghold.region_id), String(stronghold.faction_id), {})
    _nodes[stronghold_id] = stronghold
    var record: Dictionary = _records[stronghold_id]
    var node_state: Dictionary = stronghold.export_state()
    for key in node_state:
        record[key] = node_state[key]
    record["id"] = stronghold_id
    record["region"] = String(stronghold.region_id)
    record["faction"] = String(stronghold.faction_id)
    _records[stronghold_id] = record
    _sync_primary()


func import_state(data: Dictionary) -> bool:
    if not data.has("order") or not data.has("objectives"):
        return false
    if not (data["order"] is Array) or not (data["objectives"] is Array):
        return false
    _order.clear()
    _records.clear()
    _nodes.clear()
    _completion_emitted = false
    for value in data["objectives"]:
        if not (value is Dictionary) or not value.has("id"):
            return false
        var stronghold_id := String(value["id"])
        if stronghold_id.is_empty() or _records.has(stronghold_id):
            return false
        _records[stronghold_id] = value.duplicate(true)
    for value in data["order"]:
        var stronghold_id := String(value)
        if not _records.has(stronghold_id) or _order.has(stronghold_id):
            return false
        _order.append(stronghold_id)
    return _order.size() == _records.size() and not _order.is_empty()


func current_target_id() -> String:
    for stronghold_id in _order:
        var record: Dictionary = _records.get(stronghold_id, {})
        if not bool(record.get("destroyed", false)):
            return stronghold_id
    return ""


func current_target_node():
    var stronghold_id := current_target_id()
    if stronghold_id.is_empty():
        return null
    var node = _nodes.get(stronghold_id)
    return node if node != null and is_instance_valid(node) else null


func is_current_objective(stronghold_id: String) -> bool:
    return not stronghold_id.is_empty() and current_target_id() == stronghold_id


func export_state() -> Dictionary:
    var objectives: Array[Dictionary] = []
    for stronghold_id in _order:
        var record: Dictionary = _records[stronghold_id].duplicate(true)
        var node = _nodes.get(stronghold_id)
        if node != null and is_instance_valid(node):
            var node_state: Dictionary = node.export_state()
            for key in node_state:
                record[key] = node_state[key]
        objectives.append(record)
    return {"profile": WorldConfig.profile_id, "order": _order.duplicate(), "objectives": objectives}


func export_primary_state() -> Dictionary:
    var stronghold_id := current_target_id()
    if stronghold_id.is_empty():
        return {"destroyed": true}
    var node = _nodes.get(stronghold_id)
    if node != null and is_instance_valid(node):
        return node.export_state()
    var record: Dictionary = _records[stronghold_id]
    return record.duplicate(true)


func restore_conquered_regions() -> void:
    for objective in objectives_in_order():
        if bool(objective.get("destroyed", false)):
            Events.campaign_objective_completed.emit(String(objective.get("id", "")), String(objective.get("region", "")))


func sync_completion() -> void:
    _sync_primary()
    if _order.is_empty():
        return
    for stronghold_id in _order:
        if not bool(_records[stronghold_id].get("destroyed", false)):
            return
    _emit_campaign_completion()


func _on_stronghold_conquered(stronghold_id: String, region: String, _cell: Vector2i) -> void:
    if not _records.has(stronghold_id):
        return
    var record: Dictionary = _records[stronghold_id]
    if bool(record.get("destroyed", false)):
        return
    record["destroyed"] = true
    record["hp"] = 0
    record["region"] = region
    _records[stronghold_id] = record
    _nodes.erase(stronghold_id)
    var reward: Dictionary = record.get("reward", {})
    for resource in reward:
        Inventory.add(String(resource), int(reward[resource]))
    Events.campaign_objective_completed.emit(stronghold_id, region)
    _sync_primary()
    if current_target_id().is_empty():
        _emit_campaign_completion()
    else:
        var next_record: Dictionary = _records[current_target_id()]
        Events.build_feedback.emit("Wilayah %s ditaklukkan. Sasaran berikutnya: %s" % [region, String(next_record.get("faction", current_target_id())).to_upper()])


func _emit_campaign_completion() -> void:
    if _completion_emitted:
        return
    _completion_emitted = true
    _sync_primary()
    Events.campaign_won.emit(GameClock.day)


func _sync_primary() -> void:
    var main = get_tree().get_first_node_in_group("main")
    if main != null and is_instance_valid(main):
        main.enemy_keep = current_target_node()
