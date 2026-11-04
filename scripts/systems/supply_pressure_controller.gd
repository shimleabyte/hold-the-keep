extends RefCounted
## Owns Frontier depot isolation, warning, sabotage-raid and recovery pressure.
## SupplyNetwork remains the compatibility façade and retains pressure save data.

const ENEMY_SCRIPT := preload("res://scripts/entities/enemy.gd")

var _network: Node
var records: Dictionary = {}


func configure(network: Node) -> void:
    _network = network


func depot_state(depot: Node) -> Dictionary:
    if not WorldConfig.is_frontier_profile():
        return {"status": "connected", "label": "NONAKTIF"}
    if depot == null or not is_instance_valid(depot) or String(depot.id) == "keep":
        return {"status": "connected", "label": "TERHUBUNG"}
    if _network.is_depot_connected(depot):
        return {"status": "connected", "label": "TERHUBUNG"}
    if not _depot_under_threat(depot):
        return {"status": "isolated", "label": "TERPUTUS"}
    if _active_raiders(depot.cell) > 0:
        return {"status": "raiding", "label": "DIGEMPUR"}
    var record: Dictionary = records.get(_pressure_key(depot.cell), {})
    if bool(record.get("warning_sent", false)):
        return {"status": "vulnerable", "label": "ANCAMAN RAID"}
    return {"status": "exposed", "label": "TERPENCIL"}


func advance(delta: float) -> void:
    if not WorldConfig.is_frontier_profile() or delta <= 0.0:
        return
    _network._ensure_current()
    var next_records: Dictionary = {}
    var state_changed := false
    for depot in _network.get_tree().get_nodes_in_group("depots"):
        if not is_instance_valid(depot) or not ["storage", "outpost", "granary"].has(String(depot.id)):
            continue
        var key := _pressure_key(depot.cell)
        var record: Dictionary = records.get(key, {
            "cx": depot.cell.x,
            "cy": depot.cell.y,
            "contested_seconds": 0.0,
            "warning_sent": false,
            "raid_count": 0,
            "spawn_retry": 0.0,
            "status": "isolated"
        }).duplicate(true)
        var previous_status := String(record.get("status", "isolated"))

        if _network.is_depot_connected(depot):
            if records.has(key):
                _recall_raiders(depot.cell)
                state_changed = true
            continue

        if not _depot_under_threat(depot):
            if float(record.get("contested_seconds", 0.0)) > 0.0 or int(record.get("raid_count", 0)) > 0:
                _recall_raiders(depot.cell)
                state_changed = true
            record["contested_seconds"] = 0.0
            record["warning_sent"] = false
            record["raid_count"] = 0
            record["spawn_retry"] = 0.0
            record["status"] = "isolated"
            next_records[key] = record
            if previous_status != "isolated":
                state_changed = true
            continue

        record["contested_seconds"] = minf(
            _network.PRESSURE_RAID_SECONDS + _network.PRESSURE_REPEAT_SECONDS * _network.MAX_RAIDS_PER_ISOLATION,
            float(record.get("contested_seconds", 0.0)) + delta
        )
        var contested_seconds := float(record["contested_seconds"])
        if contested_seconds >= _network.PRESSURE_WARNING_SECONDS and not bool(record.get("warning_sent", false)):
            record["warning_sent"] = true
            Events.event_triggered.emit(
                "JALUR LOGISTIK TERANCAM",
                "%s di %d,%d terisolasi di wilayah sengketa. Saboteur dapat tiba dalam 30 detik. Sambungkan jalan, rebut kembali wilayah, atau tugaskan penjaga."
                % [String(depot.id).to_upper(), depot.cell.x, depot.cell.y]
            )
            state_changed = true

        var retry_in := maxf(0.0, float(record.get("spawn_retry", 0.0)) - delta)
        record["spawn_retry"] = retry_in
        var raid_count := int(record.get("raid_count", 0))
        var next_raid_at := _network.PRESSURE_RAID_SECONDS + float(raid_count) * _network.PRESSURE_REPEAT_SECONDS
        if raid_count < _network.MAX_RAIDS_PER_ISOLATION and contested_seconds >= next_raid_at and retry_in <= 0.0 and _active_raiders(depot.cell) == 0 and _network.get_tree().get_nodes_in_group("supply_raiders").size() < _network.MAX_ACTIVE_SUPPLY_RAIDERS:
            if _spawn_raid(depot):
                raid_count += 1
                record["raid_count"] = raid_count
                Events.event_triggered.emit(
                    "SABOTEUR MENYERANG",
                    "Saboteur menyerbu %s %d,%d. Penjaga lokal dapat menghadapinya; pulihkan jalan atau perbaiki depot dari Keep."
                    % [String(depot.id).to_upper(), depot.cell.x, depot.cell.y]
                )
                state_changed = true
            else:
                record["spawn_retry"] = 10.0

        var next_status := "exposed"
        if _active_raiders(depot.cell) > 0:
            next_status = "raiding"
        elif bool(record.get("warning_sent", false)):
            next_status = "vulnerable"
        record["status"] = next_status
        if previous_status != next_status:
            state_changed = true
        next_records[key] = record

    for old_key in records:
        if next_records.has(old_key):
            continue
        var old_record: Dictionary = records[old_key]
        var old_cell := Vector2i(int(old_record.get("cx", -1)), int(old_record.get("cy", -1)))
        if old_cell.x >= 0:
            _recall_raiders(old_cell)
        state_changed = true

    records = next_records
    while records.size() > _network.MAX_PRESSURE_RECORDS:
        records.erase(records.keys()[0])
    if state_changed:
        Events.supply_pressure_changed.emit()


func snapshot() -> Array[Dictionary]:
    var pressure: Array[Dictionary] = []
    for key in records:
        var record: Dictionary = records[key]
        pressure.append({
            "cx": int(record.get("cx", -1)),
            "cy": int(record.get("cy", -1)),
            "contested_seconds": float(record.get("contested_seconds", 0.0)),
            "warning_sent": bool(record.get("warning_sent", false)),
            "raid_count": int(record.get("raid_count", 0)),
            "spawn_retry": float(record.get("spawn_retry", 0.0)),
            "status": String(record.get("status", "isolated"))
        })
    return pressure


func restore(saved_pressure: Variant) -> void:
    records.clear()
    if saved_pressure is Array:
        for saved_record in saved_pressure:
            if not (saved_record is Dictionary):
                continue
            var saved_cell := Vector2i(int(saved_record.get("cx", -1)), int(saved_record.get("cy", -1)))
            var depot = _network._find_depot(saved_cell)
            if depot == null or not ["storage", "outpost", "granary"].has(String(depot.id)):
                continue
            records[_pressure_key(saved_cell)] = {
                "cx": saved_cell.x,
                "cy": saved_cell.y,
                "contested_seconds": clampf(float(saved_record.get("contested_seconds", 0.0)), 0.0, _network.PRESSURE_RAID_SECONDS + _network.PRESSURE_REPEAT_SECONDS * _network.MAX_RAIDS_PER_ISOLATION),
                "warning_sent": bool(saved_record.get("warning_sent", false)),
                "raid_count": clampi(int(saved_record.get("raid_count", 0)), 0, _network.MAX_RAIDS_PER_ISOLATION),
                "spawn_retry": clampf(float(saved_record.get("spawn_retry", 0.0)), 0.0, 30.0),
                "status": String(saved_record.get("status", "isolated"))
            }


func _pressure_key(cell: Vector2i) -> String:
    return "%d:%d" % [cell.x, cell.y]


func _depot_under_threat(depot: Node) -> bool:
    if _network.territory == null or not is_instance_valid(_network.territory):
        return false
    var owner: String = _network.territory.owner_at(depot.cell)
    if owner == "enemy" or owner == "contested":
        return true
    var region_id: String = _network.world.region_id(depot.cell)
    var region: Dictionary = _network.territory.get_region_state(region_id)
    var control := String(region.get("control", "neutral"))
    return control == "enemy" or control == "contested"


func _active_raiders(cell: Vector2i) -> int:
    var count := 0
    for enemy in _network.get_tree().get_nodes_in_group("supply_raiders"):
        if is_instance_valid(enemy) and enemy.is_supply_raider and enemy.raid_target_cell == cell:
            count += 1
    return count


func _spawn_raid(depot: Node) -> bool:
    if _network.nav == null or _network.world == null or _network.flow == null or not DataDB.enemies.has("enemy_saboteur"):
        return false
    var spawn_cell := _find_raid_spawn(depot)
    if spawn_cell.x < 0:
        return false
    var enemy = ENEMY_SCRIPT.new()
    var faction_id := FactionRegistry.faction_for_region(_network.world.region_id(spawn_cell))
    enemy.setup(DataDB.enemies["enemy_saboteur"], _network.world, _network.flow, _network.player, faction_id)
    enemy.setup_supply_raid(depot.cell, _network.nav)
    enemy.position = _network.nav.center_of(spawn_cell)
    _network.world.entities.add_child(enemy)
    return true


func _find_raid_spawn(depot: Node) -> Vector2i:
    if _network.nav == null or _network.territory == null:
        return Vector2i(-1, -1)
    var target_cells: Array[Vector2i] = depot.cells()
    for radius in range(4, 10):
        for y in range(-radius, radius + 1):
            for x in range(-radius, radius + 1):
                if maxi(absi(x), absi(y)) != radius:
                    continue
                var candidate: Vector2i = depot.cell + Vector2i(x, y)
                if not _network.world.is_buildable(candidate) or not _network.nav.is_walkable(candidate):
                    continue
                var owner: String = _network.territory.owner_at(candidate)
                var region: Dictionary = _network.territory.get_region_state(_network.world.region_id(candidate))
                var region_control := String(region.get("control", "neutral"))
                var hostile_cell := owner == "enemy" or owner == "contested" or region_control == "enemy" or region_control == "contested"
                if not hostile_cell:
                    continue
                var path: PackedVector2Array = _network.nav.path_adjacent(_network.nav.center_of(candidate), target_cells)
                if path.size() >= 2:
                    return candidate
    return Vector2i(-1, -1)


func _recall_raiders(cell: Vector2i) -> void:
    for enemy in _network.get_tree().get_nodes_in_group("supply_raiders"):
        if is_instance_valid(enemy) and enemy.is_supply_raider and enemy.raid_target_cell == cell:
            enemy.retreat()
