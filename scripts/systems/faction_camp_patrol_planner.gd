extends RefCounted
## Deterministic, region-bounded patrol geometry and waypoint planning.
## No camp lifecycle, reinforcement timers, spawning or persistence lives here.

var main


func setup(main_ref) -> void:
    main = main_ref



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


func _reachable_patrol_cells(camp_cell: Vector2i, region_id: String, radius: float) -> Dictionary:
    var reachable: Dictionary = {}
    if not _patrol_cell_allowed(camp_cell, region_id, camp_cell, radius):
        return reachable
    var queue: Array[Vector2i] = [camp_cell]
    reachable[camp_cell] = true
    var cursor := 0
    var directions: Array[Vector2i] = [
        Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
    ]
    while cursor < queue.size():
        var current: Vector2i = queue[cursor]
        cursor += 1
        for direction in directions:
            var next_cell: Vector2i = current + direction
            if reachable.has(next_cell) or not _patrol_cell_allowed(next_cell, region_id, camp_cell, radius):
                continue
            reachable[next_cell] = true
            queue.append(next_cell)
    return reachable


func _build_patrol_points(camp_cell: Vector2i, region_id: String, radius: float) -> Array[Vector2]:
    var candidates_by_quadrant: Array[Array] = [[], [], [], []]
    var reachable: Dictionary = _reachable_patrol_cells(camp_cell, region_id, radius)
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
    var path_checked: Dictionary = {}
    for quadrant in 4:
        var values: Array = candidates_by_quadrant[quadrant]
        values.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
            return float(a["score"]) < float(b["score"])
        )
        var attempts := 0
        for entry in values:
            if attempts >= 2:
                break
            attempts += 1
            var candidate_cell: Vector2i = entry["cell"]
            path_checked[candidate_cell] = true
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
            if fallback_attempts >= 2:
                break
            var candidate_cell: Vector2i = entry["cell"]
            if path_checked.has(candidate_cell):
                continue
            fallback_attempts += 1
            path_checked[candidate_cell] = true
            var path: PackedVector2Array = main.nav.path_to(main.nav.center_of(camp_cell), candidate_cell)
            if not _path_stays_in_camp(path, region_id, camp_cell, radius):
                continue
            result.append(point)
            if result.size() >= 3:
                break
    return result
