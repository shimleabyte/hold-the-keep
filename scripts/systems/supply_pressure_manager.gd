extends RefCounted
## Owns isolated-depot pressure, warnings, saboteur raids and pressure persistence.
## SupplyNetwork remains the public API and owns depot connectivity and save framing.

const ENEMY_SCRIPT := preload("res://scripts/entities/enemy.gd")
const PRESSURE_WARNING_SECONDS := 30.0
const PRESSURE_RAID_SECONDS := 60.0
const PRESSURE_REPEAT_SECONDS := 150.0
const MAX_RAIDS_PER_ISOLATION := 2
const MAX_ACTIVE_SUPPLY_RAIDERS := 8
const PRESSURE_TICK := 1.0
const MAX_PRESSURE_RECORDS := 64

var pressure_records: Dictionary = {}
var timer := 0.0


func process(network: Variant, delta: float) -> void:
    if not WorldConfig.is_frontier_profile():
        return
    timer += delta
    if timer >= PRESSURE_TICK:
        var pressure_delta := timer
        timer = 0.0
        advance(network, pressure_delta)


## Return the raid exposure state used by the depot panel.
func depot_pressure_state(network: Variant, depot: Node) -> Dictionary:
    if not WorldConfig.is_frontier_profile():
        return {"status": "connected", "label": "NONAKTIF"}
    if depot == null or not is_instance_valid(depot) or String(depot.id) == "keep":
        return {"status": "connected", "label": "TERHUBUNG"}
    if network.is_depot_connected(depot):
        return {"status": "connected", "label": "TERHUBUNG"}
    if not _depot_under_threat(network, depot):
        return {"status": "isolated", "label": "TERPUTUS"}
    if _active_supply_raiders(network, depot.cell) > 0:
        return {"status": "raiding", "label": "DIGEMPUR"}
    var record: Dictionary = pressure_records.get(_pressure_key(depot.cell), {})
    if bool(record.get("warning_sent", false)):
        return {"status": "vulnerable", "label": "ANCAMAN RAID"}
    return {"status": "exposed", "label": "TERPENCIL"}


func _pressure_key(cell: Vector2i) -> String:
    return "%d:%d" % [cell.x, cell.y]


func _depot_under_threat(network: Variant, depot: Node) -> bool:
    if network.territory == null or not is_instance_valid(network.territory):
        return false
    var owner: String = network.territory.owner_at(depot.cell)
    if owner == "enemy" or owner == "contested":
        return true
    var region_id: String = network.world.region_id(depot.cell)
    var region: Dictionary = network.territory.get_region_state(region_id)
    var control := String(region.get("control", "neutral"))
    return control == "enemy" or control == "contested"


func _active_supply_raiders(network: Variant, cell: Vector2i) -> int:
    var count := 0
    for enemy in network.get_tree().get_nodes_in_group("supply_raiders"):
        if is_instance_valid(enemy) and enemy.is_supply_raider and enemy.raid_target_cell == cell:
            count += 1
    return count


func advance(network: Variant, delta: float) -> void:
    if not WorldConfig.is_frontier_profile() or delta <= 0.0:
        return
    network._ensure_current()
    var next_records: Dictionary = {}
    var state_changed := false
    for depot in network.get_tree().get_nodes_in_group("depots"):
        if not is_instance_valid(depot) or not ["storage", "outpost", "granary"].has(String(depot.id)):
            continue
        var key := _pressure_key(depot.cell)
        var record: Dictionary = pressure_records.get(key, {
            "cx": depot.cell.x,
            "cy": depot.cell.y,
            "contested_seconds": 0.0,
            "warning_sent": false,
            "raid_count": 0,
            "spawn_retry": 0.0,
            "status": "isolated"
        }).duplicate(true)
        var previous_status := String(record.get("status", "isolated"))

        if network.is_depot_connected(depot):
            if pressure_records.has(key):
                _recall_supply_raiders(network, depot.cell)
                state_changed = true
            continue

        if not _depot_under_threat(network, depot):
            if float(record.get("contested_seconds", 0.0)) > 0.0 or int(record.get("raid_count", 0)) > 0:
                _recall_supply_raiders(network, depot.cell)
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
            PRESSURE_RAID_SECONDS + PRESSURE_REPEAT_SECONDS * MAX_RAIDS_PER_ISOLATION,
            float(record.get("contested_seconds", 0.0)) + delta
        )
        var contested_seconds := float(record["contested_seconds"])
        if contested_seconds >= PRESSURE_WARNING_SECONDS and not bool(record.get("warning_sent", false)):
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
        var next_raid_at := PRESSURE_RAID_SECONDS + float(raid_count) * PRESSURE_REPEAT_SECONDS
        if raid_count < MAX_RAIDS_PER_ISOLATION and contested_seconds >= next_raid_at and retry_in <= 0.0 and _active_supply_raiders(network, depot.cell) == 0 and network.get_tree().get_nodes_in_group("supply_raiders").size() < MAX_ACTIVE_SUPPLY_RAIDERS:
            if _spawn_supply_raid(network, depot):
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
        if _active_supply_raiders(network, depot.cell) > 0:
            next_status = "raiding"
        elif bool(record.get("warning_sent", false)):
            next_status = "vulnerable"
        record["status"] = next_status
        if previous_status != next_status:
            state_changed = true
        next_records[key] = record

    for old_key in pressure_records:
        if next_records.has(old_key):
            continue
        var old_record: Dictionary = pressure_records[old_key]
        var old_cell := Vector2i(int(old_record.get("cx", -1)), int(old_record.get("cy", -1)))
        if old_cell.x >= 0:
            _recall_supply_raiders(network, old_cell)
        state_changed = true

    pressure_records = next_records
    while pressure_records.size() > MAX_PRESSURE_RECORDS:
        pressure_records.erase(pressure_records.keys()[0])
    if state_changed:
        Events.supply_pressure_changed.emit()


func _spawn_supply_raid(network: Variant, depot: Node) -> bool:
    if network.nav == null or network.world == null or network.flow == null or not DataDB.enemies.has("enemy_saboteur"):
        return false
    var spawn_cell := _find_supply_raid_spawn(network, depot)
    if spawn_cell.x < 0:
        return false
    var enemy = ENEMY_SCRIPT.new()
    var faction_id := FactionRegistry.faction_for_region(network.world.region_id(spawn_cell))
    enemy.setup(DataDB.enemies["enemy_saboteur"], network.world, network.flow, network.player, faction_id)
    enemy.setup_supply_raid(depot.cell, network.nav)
    enemy.position = network.nav.center_of(spawn_cell)
    network.world.entities.add_child(enemy)
    return true


func _find_supply_raid_spawn(network: Variant, depot: Node) -> Vector2i:
    if network.nav == null or network.territory == null:
        return Vector2i(-1, -1)
    var target_cells: Array[Vector2i] = depot.cells()
    for radius in range(4, 10):
        for y in range(-radius, radius + 1):
            for x in range(-radius, radius + 1):
                if maxi(absi(x), absi(y)) != radius:
                    continue
                var candidate: Vector2i = depot.cell + Vector2i(x, y)
                if not network.world.is_buildable(candidate) or not network.nav.is_walkable(candidate):
                    continue
                var owner: String = network.territory.owner_at(candidate)
                var region: Dictionary = network.territory.get_region_state(network.world.region_id(candidate))
                var region_control := String(region.get("control", "neutral"))
                var hostile_cell := owner == "enemy" or owner == "contested" or region_control == "enemy" or region_control == "contested"
                if not hostile_cell:
                    continue
                var path: PackedVector2Array = network.nav.path_adjacent(network.nav.center_of(candidate), target_cells)
                if path.size() >= 2:
                    return candidate
    return Vector2i(-1, -1)


func _recall_supply_raiders(network: Variant, cell: Vector2i) -> void:
    for enemy in network.get_tree().get_nodes_in_group("supply_raiders"):
        if is_instance_valid(enemy) and enemy.is_supply_raider and enemy.raid_target_cell == cell:
            enemy.retreat()


## Saboteurs always take one unit in a fixed priority order every second successful hit.
func raid_steal_from(depot: Node) -> String:
    if depot == null or not is_instance_valid(depot) or not ["storage", "outpost", "granary"].has(String(depot.id)):
        return ""
    for kind in ["food", "iron", "wood", "stone"]:
        if depot.stockpile_amount(kind) <= 0:
            continue
        if depot.take_resource(kind, 1):
            Events.build_feedback.emit(
                "Saboteur merampas 1 %s dari %s %d,%d"
                % [kind.to_upper(), String(depot.id).to_upper(), depot.cell.x, depot.cell.y]
            )
            Events.supply_pressure_changed.emit()
            return kind
    return ""


func export_records() -> Array[Dictionary]:
    var records: Array[Dictionary] = []
    for key in pressure_records:
        var record: Dictionary = pressure_records[key]
        records.append({
            "cx": int(record.get("cx", -1)),
            "cy": int(record.get("cy", -1)),
            "contested_seconds": float(record.get("contested_seconds", 0.0)),
            "warning_sent": bool(record.get("warning_sent", false)),
            "raid_count": int(record.get("raid_count", 0)),
            "spawn_retry": float(record.get("spawn_retry", 0.0)),
            "status": String(record.get("status", "isolated"))
        })
    return records


func restore_records(network: Variant, saved_pressure: Variant) -> void:
    clear_records()
    if not (saved_pressure is Array):
        return
    for saved_record in saved_pressure:
        if not (saved_record is Dictionary):
            continue
        var saved_cell := Vector2i(int(saved_record.get("cx", -1)), int(saved_record.get("cy", -1)))
        var depot = network._find_depot(saved_cell)
        if depot == null or not ["storage", "outpost", "granary"].has(String(depot.id)):
            continue
        pressure_records[_pressure_key(saved_cell)] = {
            "cx": saved_cell.x,
            "cy": saved_cell.y,
            "contested_seconds": clampf(float(saved_record.get("contested_seconds", 0.0)), 0.0, PRESSURE_RAID_SECONDS + PRESSURE_REPEAT_SECONDS * MAX_RAIDS_PER_ISOLATION),
            "warning_sent": bool(saved_record.get("warning_sent", false)),
            "raid_count": clampi(int(saved_record.get("raid_count", 0)), 0, MAX_RAIDS_PER_ISOLATION),
            "spawn_retry": clampf(float(saved_record.get("spawn_retry", 0.0)), 0.0, 30.0),
            "status": String(saved_record.get("status", "isolated"))
        }


func clear_records() -> void:
    pressure_records.clear()
    timer = 0.0
