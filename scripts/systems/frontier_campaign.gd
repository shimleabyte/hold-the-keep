extends Node

const SITE_SCRIPT := preload("res://scripts/entities/frontier_site.gd")

var main
var objectives: Dictionary = {}
var sites: Dictionary = {}
var final_boss_defeated := false
var unlocked_act := 1
var _scan_timer := 0.0


func _ready() -> void:
    add_to_group("frontier_campaign")
    Events.stronghold_conquered.connect(_on_stronghold_conquered)
    Events.frontier_final_boss_defeated.connect(_on_final_boss_defeated)


func setup(main_ref, saved: Dictionary = {}) -> void:
    main = main_ref
    if WorldConfig.profile_id != "frontier":
        return
    final_boss_defeated = bool(saved.get("final_boss_defeated", false))
    unlocked_act = clampi(int(saved.get("unlocked_act", 1)), 1, 4)
    var saved_records: Dictionary = {}
    for record in saved.get("objectives", []):
        if record is Dictionary:
            saved_records[String(record.get("id", ""))] = record

    main.nav.rebuild()
    var used_cells: Array[Vector2i] = []
    for definition in DataDB.frontier_objectives:
        var objective_id := String(definition["id"])
        var previous: Dictionary = saved_records.get(objective_id, {})
        var cell := Vector2i(int(previous.get("cell_x", -1)), int(previous.get("cell_y", -1)))
        if cell.x < 0 or cell.y < 0 or not WorldConfig.is_valid_cell(cell):
            if String(definition["type"]) != "discovery":
                cell = _find_site_cell(String(definition["region"]), used_cells)
        if cell.x >= 0:
            used_cells.append(cell)
        var record := {
            "definition": definition.duplicate(true),
            "completed": bool(previous.get("completed", false)),
            "cell": cell
        }
        objectives[objective_id] = record
        if String(definition["type"]) == "discovery" or bool(record["completed"]):
            continue
        if cell.x < 0:
            push_error("Frontier campaign: no reachable cell for " + objective_id)
            continue
        var site := SITE_SCRIPT.new()
        site.setup(definition, self, main.world, main.nav, main.player, cell, previous)
        main.world.entities.add_child(site)
        sites[objective_id] = site

    _update_unlocked_acts()
    _try_finish()


func _find_site_cell(region: String, used: Array[Vector2i]) -> Vector2i:
    var reachable := main.nav.reachable_cells(main.nav.cell_of(main.player.global_position))
    var keep_cell := WorldConfig.starting_keep_cell()
    var best := Vector2i(-1, -1)
    var best_score := -INF
    for y in WorldConfig.map_size:
        for x in WorldConfig.map_size:
            var cell := Vector2i(x, y)
            if String(main.world.region_id(cell)) != region or not reachable.has(cell):
                continue
            if not main.nav.is_walkable(cell) or main.world.occupied.has(cell):
                continue
            var separated := true
            for other in used:
                if Vector2(cell - other).length() < 12.0:
                    separated = false
                    break
            if not separated:
                continue
            var distance := Vector2(cell - keep_cell).length()
            var noise := float(posmod(x * 92821 + y * 68917 + WorldConfig.world_seed * 17, 10007)) / 10007.0
            var score := distance + noise * 10.0
            if score > best_score:
                best_score = score
                best = cell
    return best


func _process(delta: float) -> void:
    if WorldConfig.profile_id != "frontier":
        return
    _scan_timer -= delta
    if _scan_timer <= 0.0:
        _scan_timer = 0.5
        _scan_discovery()


func _scan_discovery() -> void:
    var region := String(main.world.region_id(main.nav.cell_of(main.player.global_position)))
    if region.is_empty():
        return
    for objective_id in objectives:
        var record: Dictionary = objectives[objective_id]
        var definition: Dictionary = record["definition"]
        if String(definition["type"]) == "discovery" and int(definition.get("act", 1)) <= unlocked_act and String(definition["region"]) == region and not bool(record["completed"]):
            complete_objective(String(objective_id))


func complete_objective(objective_id: String) -> bool:
    if not objectives.has(objective_id):
        return false
    var record: Dictionary = objectives[objective_id]
    if bool(record["completed"]):
        return false
    var definition: Dictionary = record["definition"]
    record["completed"] = true
    objectives[objective_id] = record

    var reward: Dictionary = definition.get("reward", {})
    var multiplier := Tech.stat("campaign.discovery_reward", 1.0) if String(definition["type"]) == "discovery" else 1.0
    for resource in reward:
        Inventory.add(String(resource), roundi(float(reward[resource]) * multiplier))
    for index in int(definition.get("recruits", 0)):
        main.village.spawn_villager(main.village.spawn_position())

    Events.frontier_objective_changed.emit(objective_id, true)
    Events.build_feedback.emit("Objektif selesai: " + String(definition["name"]))
    _update_unlocked_acts()
    _try_finish()
    return true


func _update_unlocked_acts() -> void:
    var previous := unlocked_act
    while unlocked_act < 4 and _act_requirements_met(unlocked_act):
        unlocked_act += 1
    if unlocked_act != previous:
        Events.frontier_act_unlocked.emit(unlocked_act)


func _act_requirements_met(act: int) -> bool:
    for objective_id in objectives:
        var record: Dictionary = objectives[objective_id]
        var definition: Dictionary = record["definition"]
        if int(definition.get("act", 1)) == act and bool(definition.get("required", false)) and not bool(record["completed"]):
            return false
    if main.campaign._order.size() < act:
        return false
    var stronghold_id := String(main.campaign._order[act - 1])
    return bool(main.campaign._records.get(stronghold_id, {}).get("destroyed", false))


func is_victory_ready() -> bool:
    if WorldConfig.profile_id != "frontier" or not final_boss_defeated:
        return false
    for objective_id in objectives:
        var record: Dictionary = objectives[objective_id]
        if bool(record["definition"].get("required", false)) and not bool(record["completed"]):
            return false
    return true


func _on_stronghold_conquered(_id: String, _region: String, _cell: Vector2i) -> void:
    _update_unlocked_acts()
    _try_finish()


func _on_final_boss_defeated(day: int) -> void:
    if day < 20:
        Events.build_feedback.emit("Raja Conquest baru dapat dikalahkan pada hari ke-20")
        return
    final_boss_defeated = true
    Events.build_feedback.emit("Raja dikalahkan. Selesaikan seluruh objektif regional untuk menutup Conquest.")
    _try_finish()


func _try_finish() -> void:
    if not is_victory_ready():
        return
    for stronghold_id in main.campaign._order:
        if not bool(main.campaign._records.get(stronghold_id, {}).get("destroyed", false)):
            return
    main.campaign.sync_completion()


func objective_summary() -> String:
    if WorldConfig.profile_id != "frontier":
        return "Objektif regional hanya tersedia pada Frontier / Conquest."
    var stage := main.spawner.stage_info(GameClock.day)
    var lines: Array[String] = [
        String(stage.get("label", "ACT")) + "  " + String(stage.get("name", "")),
        "HARI %02d / 20   ACT TERBUKA %d/4" % [GameClock.day, unlocked_act],
        ""
    ]
    for objective_id in objectives:
        var record: Dictionary = objectives[objective_id]
        var definition: Dictionary = record["definition"]
        var marker := "[X]" if bool(record["completed"]) else "[ ]"
        if sites.has(objective_id) and is_instance_valid(sites[objective_id]):
            var state := String(sites[objective_id].site_state)
            if state == "escorting":
                marker = "[>]"
            elif state == "active" and String(definition["type"]) == "defend":
                marker = "[!]"
        lines.append("%s A%d %s" % [marker, int(definition.get("act", 1)), String(definition["name"])])
    if final_boss_defeated:
        lines.append("")
        lines.append("RAJA: DIKALAHKAN")
    return "\n".join(lines)


func export_state() -> Dictionary:
    if WorldConfig.profile_id != "frontier":
        return {"profile":"classic","objectives":[],"final_boss_defeated":false,"unlocked_act":1}
    var records: Array[Dictionary] = []
    for objective_id in objectives:
        var record: Dictionary = objectives[objective_id]
        var cell: Vector2i = record["cell"]
        var state := {
            "state": "complete" if bool(record["completed"]) else "waiting",
            "hp": 0, "x": 0.0, "y": 0.0, "path_index": 0, "saw_night": false
        }
        if sites.has(objective_id) and is_instance_valid(sites[objective_id]):
            state = sites[objective_id].export_state()
        records.append({
            "id": objective_id, "completed": bool(record["completed"]),
            "cell_x": cell.x, "cell_y": cell.y, "state": state["state"],
            "hp": int(state["hp"]), "x": float(state["x"]), "y": float(state["y"]),
            "path_index": int(state["path_index"]), "saw_night": bool(state["saw_night"])
        })
    return {
        "profile":"frontier", "objectives":records,
        "final_boss_defeated":final_boss_defeated, "unlocked_act":unlocked_act
    }
