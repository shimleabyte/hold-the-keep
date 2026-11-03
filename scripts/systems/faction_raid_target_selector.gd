extends RefCounted
## Selects exposed, connected infrastructure targets for faction raids.
## Dispatch limits, raider lifecycle and campaign events remain in FactionCamps.

const MAX_RAID_TARGET_SCAN := 48
const MAX_RAID_PATH_CHECKS := 8

var main
var _road_target_scan_cursor := 0


func setup(main_ref) -> void:
    main = main_ref



func _raid_target_exposed(target, camp: Dictionary) -> bool:
    if target == null or not is_instance_valid(target) or int(target.hp) <= 0:
        return false
    var target_region := String(main.world.region_id(target.cell))
    if target_region != String(camp["region_id"]):
        return false
    var owner := String(main.territory.owner_at(target.cell))
    var region: Dictionary = main.territory.get_region_state(target_region)
    var control := String(region.get("control", "neutral"))
    return owner == "contested" or (owner == "player" and control in ["enemy", "contested"])


func _find_raid_target(camp: Dictionary) -> Dictionary:
    main.supply._ensure_current()
    main.territory._ensure_current()
    var candidates: Array[Dictionary] = []
    var scanned := 0

    for depot in main.get_tree().get_nodes_in_group("depots"):
        if scanned >= MAX_RAID_TARGET_SCAN:
            break
        scanned += 1
        if not is_instance_valid(depot) or not ["storage", "outpost", "granary"].has(String(depot.id)):
            continue
        if not main.supply.is_depot_connected(depot) or not _raid_target_exposed(depot, camp):
            continue
        var distance := Vector2(camp["position"]).distance_to(depot.position)
        if distance > 760.0:
            continue
        var priority := 7 if String(depot.id) == "outpost" else (6 if String(depot.id) == "granary" else 5)
        candidates.append({
            "node": depot,
            "kind": "depot",
            "node_id": String(depot.id),
            "cell": depot.cell,
            "score": float(priority * 1000) - distance
        })

    var road_nodes: Array = main.get_tree().get_nodes_in_group("roads")
    var road_scan_count := mini(MAX_RAID_TARGET_SCAN - scanned, road_nodes.size())
    for offset in road_scan_count:
        var road = road_nodes[(_road_target_scan_cursor + offset) % road_nodes.size()]
        scanned += 1
        if not is_instance_valid(road) or not ["road", "bridge"].has(String(road.id)):
            continue
        var connected := false
        for road_cell in road.cells():
            if main.supply.connected_road_cells.has(road_cell):
                connected = true
                break
        if not connected or not _raid_target_exposed(road, camp):
            continue
        var distance := Vector2(camp["position"]).distance_to(road.position)
        if distance > 760.0:
            continue
        var priority := 3 if String(road.id) == "bridge" else 2
        candidates.append({
            "node": road,
            "kind": "road",
            "node_id": String(road.id),
            "cell": road.cell,
            "score": float(priority * 1000) - distance
        })
    if not road_nodes.is_empty():
        _road_target_scan_cursor = (_road_target_scan_cursor + road_scan_count) % road_nodes.size()

    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return float(a["score"]) > float(b["score"])
    )
    var path_checks := mini(MAX_RAID_PATH_CHECKS, candidates.size())
    for index in path_checks:
        var candidate: Dictionary = candidates[index]
        var target = candidate["node"]
        var target_cells: Array[Vector2i] = target.cells()
        var path: PackedVector2Array = main.nav.path_adjacent(camp["position"], target_cells)
        if path.is_empty():
            continue
        return {
            "cell": candidate["cell"],
            "kind": candidate["kind"],
            "node_id": candidate["node_id"]
        }
    return {}
