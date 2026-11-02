extends Node2D
## Deterministic Frontier faction camps with bounded local patrol reinforcement.

const CAMP_SCRIPT := preload("res://scripts/entities/faction_camp.gd")
const CAMP_SCAN_INTERVAL := 0.5
const CAMP_SITE_CLEARANCE := 10.0
const CAMP_SPACING := 12.0

var main
var camps: Dictionary = {}
var _scan_timer := 0.0


func _ready() -> void:
    add_to_group("faction_camp_manager")
    z_index = 4


func setup(main_ref, saved: Dictionary = {}) -> void:
    main = main_ref
    camps.clear()
    _scan_timer = CAMP_SCAN_INTERVAL
    if WorldConfig.profile_id != "frontier":
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
            "patrol_points": patrol_points
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
            if not reachable.has(cell) or not main.nav.is_walkable(cell):
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


func _patrol_cell_allowed(cell: Vector2i, region_id: String, camp_cell: Vector2i, radius: float) -> bool:
    if not WorldConfig.is_valid_cell(cell) or not main.nav.is_walkable(cell):
        return false
    if main.world.occupied.has(cell) or String(main.world.region_id(cell)) != region_id:
        return false
    if main.territory.owner_at(cell) != "enemy":
        return false
    return Vector2(cell - camp_cell).length() * WorldConfig.tile_size <= radius + WorldConfig.tile_size


func _path_stays_in_camp(path: PackedVector2Array, region_id: String, camp_cell: Vector2i, radius: float) -> bool:
    if path.is_empty():
        return false
    for point in path:
        var cell: Vector2i = main.nav.cell_of(point)
        if not _patrol_cell_allowed(cell, region_id, camp_cell, radius):
            return false
    return true


func _build_patrol_points(camp_cell: Vector2i, region_id: String, radius: float) -> Array[Vector2]:
    var candidates_by_quadrant: Array[Array] = [[], [], [], []]
    var reachable: Dictionary = main.nav.reachable_cells(camp_cell)
    var max_tiles := int(floor(radius / float(WorldConfig.tile_size))) - 1

    # Rank reachable cells first; defer expensive A* requests until a small candidate set is known.
    for candidate_value in reachable.keys():
        var candidate: Vector2i = candidate_value
        var offset := candidate - camp_cell
        var distance := Vector2(offset).length()
        if distance < 2.5 or distance > float(max_tiles):
            continue
        if not _patrol_cell_allowed(candidate, region_id, camp_cell, radius):
            continue

        var quadrant := 0
        if offset.x >= 0 and offset.y < 0:
            quadrant = 0
        elif offset.x >= 0 and offset.y >= 0:
            quadrant = 1
        elif offset.x < 0 and offset.y >= 0:
            quadrant = 2
        else:
            quadrant = 3
        var noise := float(posmod(
            candidate.x * 92821 + candidate.y * 68917 + WorldConfig.world_seed * 31 + quadrant * 997,
            10007
        )) / 10007.0
        var score := absf(distance - 4.4) + noise * 0.35
        candidates_by_quadrant[quadrant].append({"cell": candidate, "score": score})

    var result: Array[Vector2] = []
    for quadrant in 4:
        var values: Array = candidates_by_quadrant[quadrant]
        values.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
            return float(a["score"]) < float(b["score"])
        )
        var attempts := 0
        for entry in values:
            if attempts >= 6:
                break
            attempts += 1
            var candidate_cell: Vector2i = entry["cell"]
            var path: PackedVector2Array = main.nav.path_to(main.nav.center_of(camp_cell), candidate_cell)
            if _path_stays_in_camp(path, region_id, camp_cell, radius):
                result.append(main.nav.center_of(candidate_cell))
                break

    if result.size() < 2:
        var fallback: Array = []
        for quadrant_values in candidates_by_quadrant:
            for entry in quadrant_values:
                fallback.append(entry)
        fallback.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
            return float(a["score"]) < float(b["score"])
        )
        var fallback_attempts := 0
        for entry in fallback:
            var point: Vector2 = main.nav.center_of(entry["cell"])
            if result.has(point):
                continue
            if fallback_attempts >= 12:
                break
            fallback_attempts += 1
            var candidate_cell: Vector2i = entry["cell"]
            var path: PackedVector2Array = main.nav.path_to(main.nav.center_of(camp_cell), candidate_cell)
            if not _path_stays_in_camp(path, region_id, camp_cell, radius):
                continue
            result.append(point)
            if result.size() >= 3:
                break
    return result

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
    camp["hp"] = 0
    _retreat_patrols(camp_id)
    var target = camp.get("target")
    if target != null and is_instance_valid(target):
        target.remove_from_group("campaign_targets")
        target.remove_from_group("faction_camp_targets")
        target.queue_free()
    camps[camp_id] = camp
    Events.build_feedback.emit("Kamp %s dihancurkan. Reinforcement terhenti." % String(FactionRegistry.factions[camp_id]["name"]))
    queue_redraw()


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
    if WorldConfig.profile_id != "frontier" or camps.is_empty():
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

    for camp_id in camps:
        var camp: Dictionary = camps[camp_id]
        if bool(camp.get("destroyed", false)):
            continue

        var cell: Vector2i = camp["cell"]
        var enemy_controlled: bool = main.territory.owner_at(cell) == "enemy"
        if not enemy_controlled:
            if not bool(camp.get("suppressed", false)):
                _retreat_patrols(String(camp_id))
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
        if active_count >= int(camp["patrol_cap"]) or int(camp["budget"]) <= 0:
            continue
        camp["timer"] = maxf(0.0, float(camp["timer"]) - elapsed)
        if float(camp["timer"]) <= 0.0:
            if _spawn_patrol(camp):
                camp["budget"] = maxi(0, int(camp["budget"]) - 1)
                camp["timer"] = float(camp["reinforcement_cooldown"])
                patrol_counts[camp_id] = active_count + 1
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
            "spawn_index": int(camp["spawn_index"])
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
