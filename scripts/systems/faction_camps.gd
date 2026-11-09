extends Node2D
## Deterministic Frontier faction camps with bounded local patrol reinforcement.

const CAMP_SCRIPT := preload("res://scripts/entities/faction_camp.gd")
const ENEMY_SCRIPT := preload("res://scripts/entities/enemy.gd")
const PATROL_PLANNER_SCRIPT := preload("res://scripts/systems/faction_camp_patrol_planner.gd")
const RAID_SELECTOR_SCRIPT := preload("res://scripts/systems/faction_raid_target_selector.gd")
const CAMP_SCAN_INTERVAL := 0.5
const CAMP_SITE_CLEARANCE := 10.0
const CAMP_SPACING := 12.0
const MAX_ACTIVE_FACTION_RAIDERS := 4
var main
var _patrol_planner
var _raid_selector
var camps: Dictionary = {}
var _scan_timer := 0.0


func _ready() -> void:
    add_to_group("faction_camp_manager")
    z_index = 4


func setup(main_ref, saved: Dictionary = {}) -> void:
    main = main_ref
    _patrol_planner = PATROL_PLANNER_SCRIPT.new()
    _patrol_planner.setup(main)
    _raid_selector = RAID_SELECTOR_SCRIPT.new()
    _raid_selector.setup(main)
    camps.clear()
    _scan_timer = CAMP_SCAN_INTERVAL
    if not WorldConfig.is_frontier_profile():
        return

    main.nav.rebuild()
    main.territory._ensure_current()

    var saved_records: Dictionary = {}
    for record in saved.get("records", []):
        if record is Dictionary:
            saved_records[String(record.get("id", ""))] = record

    var faction_ids: Array = FactionRegistry.factions.keys()
    faction_ids.sort()
    var used_cells: Array[Vector2i] = []
    var reachable: Dictionary = main.nav.reachable_cells(main.nav.cell_of(main.player.global_position))

    for faction_value in faction_ids:
        var faction_id := String(faction_value)
        var faction_data: Dictionary = FactionRegistry.faction_for_stronghold(faction_id)
        var region_id := String(faction_data.get("region", ""))
        var previous: Dictionary = saved_records.get(faction_id, {})
        var cell := Vector2i(int(previous.get("cx", -1)), int(previous.get("cy", -1)))
        if not _camp_cell_valid(cell, region_id, used_cells):
            cell = _find_camp_cell(faction_id, region_id, used_cells, reachable)
        if cell.x < 0:
            push_warning("Faction camps: no reachable enemy-claimed cell for %s" % faction_id)
            continue

        used_cells.append(cell)
        var camp_definition: Dictionary = faction_data.get("camp", {})
        var raid_definition: Dictionary = faction_data.get("raid", {})
        var patrol_radius := clampf(float(camp_definition.get("patrol_radius", 144.0)), 88.0, 190.0)
        var patrol_points := _build_patrol_points(cell, region_id, patrol_radius)
        if patrol_points.is_empty():
            patrol_points.append(main.nav.center_of(cell))

        var camp_destroyed := bool(previous.get("destroyed", false))
        var camp_hp := 0 if camp_destroyed else clampi(int(previous.get("hp", 220)), 1, 220)
        var camp := {
            "id": faction_id,
            "faction_id": faction_id,
            "region_id": region_id,
            "cell": cell,
            "position": main.nav.center_of(cell),
            "activated": bool(previous.get("activated", false)),
            "destroyed": camp_destroyed,
            "suppressed": bool(previous.get("suppressed", false)),
            "hp": camp_hp,
            "budget": clampi(int(previous.get("budget", int(camp_definition.get("reinforcement_budget", 4)))), 0, 12),
            "timer": clampf(float(previous.get("timer", float(camp_definition.get("reinforcement_cooldown", 30.0)))), 0.0, 180.0),
            "spawn_index": maxi(0, int(previous.get("spawn_index", 0))),
            "patrol_radius": patrol_radius,
            "patrol_cap": clampi(int(camp_definition.get("active_patrol_cap", 2)), 1, 3),
            "initial_patrols": clampi(int(camp_definition.get("initial_patrols", 2)), 1, 3),
            "reinforcement_cooldown": clampf(float(camp_definition.get("reinforcement_cooldown", 30.0)), 12.0, 90.0),
            "patrol_unit": String(faction_data.get("patrol_unit", "")),
            "patrol_points": patrol_points,
            "raid_unit": String(faction_data.get("raid_unit", "enemy_saboteur")),
            "raid_budget": clampi(int(previous.get("raid_budget", raid_definition.get("budget", 2))), 0, 4),
            "raid_timer": clampf(float(previous.get("raid_timer", raid_definition.get("cooldown", 90.0))), 0.0, 240.0),
            "raid_cooldown": clampf(float(raid_definition.get("cooldown", 90.0)), 45.0, 180.0),
            "raid_active_cap": clampi(int(raid_definition.get("active_cap", 1)), 1, 2)
        }
        if not bool(camp["destroyed"]):
            var camp_target = CAMP_SCRIPT.new()
            camp_target.setup(faction_id, self, camp["position"], faction_data, {
                "hp": camp["hp"],
                "activated": camp["activated"],
                "suppressed": camp["suppressed"]
            })
            main.world.entities.add_child(camp_target)
            camp["target"] = camp_target
        camps[faction_id] = camp

    _bind_restored_patrols()
    queue_redraw()


func _camp_cell_valid(cell: Vector2i, region_id: String, used_cells: Array[Vector2i]) -> bool:
    if not WorldConfig.is_valid_cell(cell) or not main.nav.is_walkable(cell):
        return false
    if main.world.occupied.has(cell) or String(main.world.region_id(cell)) != region_id:
        return false
    if not used_cells.is_empty():
        for other in used_cells:
            if Vector2(cell - other).length() < CAMP_SPACING:
                return false
    return true


func _stronghold_cell_for_region(region_id: String) -> Vector2i:
    for objective in main.campaign.objectives_in_order():
        if String(objective.get("region", "")) == region_id and not bool(objective.get("destroyed", false)):
            var cell := Vector2i(int(objective.get("cx", -1)), int(objective.get("cy", -1)))
            if WorldConfig.is_valid_cell(cell):
                return cell
    return Vector2i(-1, -1)


func _find_camp_cell(
    faction_id: String,
    region_id: String,
    used_cells: Array[Vector2i],
    reachable: Dictionary
) -> Vector2i:
    var stronghold_cell := _stronghold_cell_for_region(region_id)
    if stronghold_cell.x < 0:
        return Vector2i(-1, -1)

    var site_positions: Array[Vector2] = []
    for site in main.frontier_campaign.sites.values():
        if is_instance_valid(site) and String(site.region_id) == region_id:
            site_positions.append(site.global_position / float(WorldConfig.tile_size))

    var best := Vector2i(-1, -1)
    var best_score := INF
    for y in WorldConfig.map_size:
        for x in WorldConfig.map_size:
            var cell := Vector2i(x, y)
            if (not WorldConfig.is_frontier_expedition() and not reachable.has(cell)) or not main.nav.is_walkable(cell):
                continue
            if WorldConfig.is_frontier_expedition() and not main.world.is_expedition_outer_cell(cell, region_id):
                continue
            if main.world.occupied.has(cell) or String(main.world.region_id(cell)) != region_id:
                continue
            if main.territory.owner_at(cell) != "enemy":
                continue
            if not _camp_cell_valid(cell, region_id, used_cells):
                continue

            var stronghold_distance := Vector2(cell - stronghold_cell).length()
            if stronghold_distance < 3.5 or stronghold_distance > 7.5:
                continue
            var site_clearance := true
            for site_cell in site_positions:
                if Vector2(cell).distance_to(site_cell) < CAMP_SITE_CLEARANCE:
                    site_clearance = false
                    break
            if not site_clearance:
                continue

            var sorted_factions: Array = FactionRegistry.factions.keys()
            sorted_factions.sort()
            var faction_salt := (sorted_factions.find(faction_id) + 1) * 997
            var noise := float(posmod(
                x * 92821 + y * 68917 + WorldConfig.world_seed * 17 + faction_salt,
                10007
            )) / 10007.0
            var score := absf(stronghold_distance - 5.6) * 4.0 - noise
            if score < best_score:
                best_score = score
                best = cell
    return best


func _patrol_cell_allowed(
    cell: Vector2i, region_id: String, camp_cell: Vector2i, radius: float
) -> bool:
    return _patrol_planner._patrol_cell_allowed(cell, region_id, camp_cell, radius)


func _path_stays_in_camp(
    path: PackedVector2Array, region_id: String, camp_cell: Vector2i, radius: float
) -> bool:
    return _patrol_planner._path_stays_in_camp(path, region_id, camp_cell, radius)


func _reachable_patrol_cells(
    camp_cell: Vector2i, region_id: String, radius: float
) -> Dictionary:
    return _patrol_planner._reachable_patrol_cells(camp_cell, region_id, radius)


func _build_patrol_points(
    camp_cell: Vector2i, region_id: String, radius: float
) -> Array[Vector2]:
    return _patrol_planner._build_patrol_points(camp_cell, region_id, radius)



func _camp_patrol_config(camp: Dictionary) -> Dictionary:
    return {
        "camp_id": String(camp["id"]),
        "region_id": String(camp["region_id"]),
        "camp_position": camp["position"],
        "territory": main.territory,
        "patrol_radius": float(camp["patrol_radius"]),
        "patrol_points": camp["patrol_points"]
    }


func _bind_restored_patrols() -> void:
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if not is_instance_valid(enemy) or enemy.pending_patrol_state.is_empty():
            continue
        var camp_id := String(enemy.pending_patrol_state.get("camp_id", ""))
        if not camps.has(camp_id):
            push_warning("Faction camps: patrol enemy references missing camp %s" % camp_id)
            continue
        enemy.configure_patrol(_camp_patrol_config(camps[camp_id]), enemy.pending_patrol_state)


func _patrol_count(camp_id: String) -> int:
    var count := 0
    for enemy in get_tree().get_nodes_in_group("enemy_patrols"):
        if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.patrol_camp_id == camp_id:
            count += 1
    return count


func _retreat_patrols(camp_id: String) -> void:
    for enemy in get_tree().get_nodes_in_group("enemy_patrols"):
        if is_instance_valid(enemy) and enemy.patrol_camp_id == camp_id:
            enemy.retreat()


func update_camp_hp(camp_id: String, hp: int) -> void:
    if not camps.has(camp_id):
        return
    var camp: Dictionary = camps[camp_id]
    if bool(camp.get("destroyed", false)):
        return
    camp["hp"] = clampi(hp, 1, 220)
    camps[camp_id] = camp


func destroy_camp(camp_id: String) -> void:
    if not camps.has(camp_id):
        return
    var camp: Dictionary = camps[camp_id]
    if bool(camp.get("destroyed", false)):
        return
    camp["destroyed"] = true
    camp["activated"] = false
    camp["suppressed"] = true
    camp["budget"] = 0
    camp["raid_budget"] = 0
    camp["hp"] = 0
    _retreat_patrols(camp_id)
    _retreat_faction_raiders(camp_id)
    var target = camp.get("target")
    if target != null and is_instance_valid(target):
        target.remove_from_group("campaign_targets")
        target.remove_from_group("faction_camp_targets")
        target.queue_free()
    camps[camp_id] = camp
    Events.build_feedback.emit("Kamp %s dihancurkan. Reinforcement terhenti." % String(FactionRegistry.factions[camp_id]["name"]))
    queue_redraw()


func _retreat_faction_raiders(camp_id: String) -> void:
    for raider in get_tree().get_nodes_in_group("faction_raiders"):
        if is_instance_valid(raider) and String(raider.faction_raid_camp_id) == camp_id:
            raider.retreat()


func _raid_target_exposed(target, camp: Dictionary) -> bool:
    return _raid_selector._raid_target_exposed(target, camp)


func _find_raid_target(camp: Dictionary) -> Dictionary:
    return _raid_selector._find_raid_target(camp)



func _spawn_faction_raid(camp: Dictionary, target: Dictionary) -> bool:
    if get_tree().get_nodes_in_group("faction_raiders").size() >= MAX_ACTIVE_FACTION_RAIDERS:
        return false
    var enemy_id := String(camp.get("raid_unit", "enemy_saboteur"))
    if not DataDB.enemies.has(enemy_id):
        push_warning("Faction camps: missing raid unit %s" % enemy_id)
        return false
    var raid_origin := Vector2(target.get("origin", camp["position"]))
    var raider = ENEMY_SCRIPT.new()
    raider.setup(DataDB.enemies[enemy_id], main.world, main.flow, main.player, String(camp["faction_id"]))
    raider.setup_faction_raid(
        Vector2i(target["cell"]), String(target["kind"]), main.nav,
        String(camp["id"]), String(camp["region_id"]), raid_origin
    )
    raider.position = raid_origin
    main.world.entities.add_child(raider)
    return true


func _spawn_patrol(camp: Dictionary) -> bool:
    var enemy_id := String(camp.get("patrol_unit", ""))
    if not DataDB.enemies.has(enemy_id):
        push_warning("Faction camps: missing patrol unit %s" % enemy_id)
        return false
    var points: Array = camp.get("patrol_points", [])
    var spawn_index := int(camp["spawn_index"])
    var waypoint_index := posmod(spawn_index, maxi(1, points.size()))
    var spawn_position: Vector2 = camp["position"]
    if not points.is_empty():
        spawn_position = points[waypoint_index]

    var enemy = load("res://scripts/entities/enemy.gd").new()
    enemy.setup_patrol(
        DataDB.enemies[enemy_id], main.world, main.flow, main.player,
        String(camp["faction_id"]), _camp_patrol_config(camp), {"waypoint_index": waypoint_index}
    )
    enemy.position = spawn_position
    main.world.entities.add_child(enemy)
    camp["spawn_index"] = spawn_index + 1
    camps[String(camp["id"])] = camp
    return true


func _process(delta: float) -> void:
    if not WorldConfig.is_frontier_profile() or camps.is_empty():
        return
    _scan_timer -= delta
    if _scan_timer > 0.0:
        return
    var elapsed := CAMP_SCAN_INTERVAL - _scan_timer
    _scan_timer = CAMP_SCAN_INTERVAL

    var patrol_counts: Dictionary = {}
    for enemy in get_tree().get_nodes_in_group("enemy_patrols"):
        if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
            continue
        var camp_id := String(enemy.patrol_camp_id)
        patrol_counts[camp_id] = int(patrol_counts.get(camp_id, 0)) + 1

    var raid_counts: Dictionary = {}
    for raider in get_tree().get_nodes_in_group("faction_raiders"):
        if not is_instance_valid(raider) or raider.is_queued_for_deletion():
            continue
        var camp_id := String(raider.faction_raid_camp_id)
        raid_counts[camp_id] = int(raid_counts.get(camp_id, 0)) + 1

    for camp_id in camps:
        var camp: Dictionary = camps[camp_id]
        if bool(camp.get("destroyed", false)):
            continue

        var cell: Vector2i = camp["cell"]
        var enemy_controlled: bool = main.territory.owner_at(cell) == "enemy"
        if not enemy_controlled:
            if not bool(camp.get("suppressed", false)):
                _retreat_patrols(String(camp_id))
                _retreat_faction_raiders(String(camp_id))
            camp["suppressed"] = true
            var suppressed_target = camp.get("target")
            if suppressed_target != null and is_instance_valid(suppressed_target):
                suppressed_target.set_suppressed(true)
            camps[camp_id] = camp
            continue

        if bool(camp.get("suppressed", false)):
            camp["suppressed"] = false
            var restored_target = camp.get("target")
            if restored_target != null and is_instance_valid(restored_target):
                restored_target.set_suppressed(false)

        if not bool(camp["activated"]):
            if main.fog != null and main.fog.is_revealed_cell(cell):
                camp["activated"] = true
                var camp_target = camp.get("target")
                if camp_target != null and is_instance_valid(camp_target):
                    camp_target.set_discovered(true)
                camps[camp_id] = camp
                var initial_count := mini(int(camp["initial_patrols"]), int(camp["patrol_cap"]))
                for index in initial_count:
                    if _spawn_patrol(camp):
                        patrol_counts[camp_id] = int(patrol_counts.get(camp_id, 0)) + 1
                camp["timer"] = float(camp["reinforcement_cooldown"])
                camps[camp_id] = camp
                Events.build_feedback.emit("Kamp %s ditemukan. Patroli musuh aktif." % String(FactionRegistry.factions[camp_id]["name"]))
                queue_redraw()
            continue

        var active_count := int(patrol_counts.get(camp_id, 0))
        if active_count < int(camp["patrol_cap"]) and int(camp["budget"]) > 0:
            camp["timer"] = maxf(0.0, float(camp["timer"]) - elapsed)
            if float(camp["timer"]) <= 0.0:
                if _spawn_patrol(camp):
                    camp["budget"] = maxi(0, int(camp["budget"]) - 1)
                    camp["timer"] = float(camp["reinforcement_cooldown"])
                    patrol_counts[camp_id] = active_count + 1

        var active_raids := int(raid_counts.get(camp_id, 0))
        if active_raids < int(camp["raid_active_cap"]) and int(camp["raid_budget"]) > 0:
            camp["raid_timer"] = maxf(0.0, float(camp["raid_timer"]) - elapsed)
            if float(camp["raid_timer"]) <= 0.0:
                var raid_target := _find_raid_target(camp)
                if not raid_target.is_empty() and _spawn_faction_raid(camp, raid_target):
                    camp["raid_budget"] = maxi(0, int(camp["raid_budget"]) - 1)
                    camp["raid_timer"] = float(camp["raid_cooldown"])
                    raid_counts[camp_id] = active_raids + 1
                    var faction_name := String(FactionRegistry.factions[camp_id].get("name", camp_id))
                    var target_label := String(raid_target.get("node_id", "infrastruktur")).to_upper()
                    var origin_label := "pos terdepan" if String(raid_target.get("origin_kind", "camp")) == "outpost" else "kamp"
                    Events.event_triggered.emit(
                        "RAID PERBATASAN TERDETEKSI",
                        "%s meluncurkan penyerbu dari %s ke %s di %d,%d. Hadang penyerbu atau rebut kembali kendali wilayah sebelum jalur logistik terputus."
                        % [faction_name, origin_label, target_label, raid_target["cell"].x, raid_target["cell"].y]
                    )
                else:
                    camp["raid_timer"] = 12.0
        camps[camp_id] = camp


func export_state() -> Dictionary:
    var records: Array[Dictionary] = []
    for camp_id in camps:
        var camp: Dictionary = camps[camp_id]
        var cell: Vector2i = camp["cell"]
        records.append({
            "id": String(camp_id),
            "cx": cell.x,
            "cy": cell.y,
            "activated": bool(camp["activated"]),
            "destroyed": bool(camp["destroyed"]),
            "suppressed": bool(camp["suppressed"]),
            "hp": int(camp["hp"]),
            "budget": int(camp["budget"]),
            "timer": float(camp["timer"]),
            "spawn_index": int(camp["spawn_index"]),
            "raid_budget": int(camp.get("raid_budget", 0)),
            "raid_timer": float(camp.get("raid_timer", 0.0))
        })
    return {"records": records}


func _draw() -> void:
    for camp_id in camps:
        var camp: Dictionary = camps[camp_id]
        if not bool(camp["activated"]) or bool(camp.get("destroyed", false)):
            continue
        var center: Vector2 = camp["position"]
        var color := Color(String(FactionRegistry.factions[String(camp["faction_id"])].get("color", "#c58b52")))
        var radius := float(camp["patrol_radius"])
        draw_arc(center, radius, 0.0, TAU, 48, Color(color, 0.22), 1.0)
        draw_arc(center, radius + 3.0, 0.0, TAU, 48, Color(color, 0.08), 1.0)
