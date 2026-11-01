extends RefCounted
## Shared target selection policy for enemy archetypes.

static func nearest(
    source: Node2D,
    candidates: Array,
    max_distance: float,
    leash_center: Vector2 = Vector2.ZERO,
    leash_radius: float = 0.0
) -> Node2D:
    if source == null or not is_instance_valid(source):
        return null
    var best: Node2D = null
    var best_distance := max_distance
    for candidate in candidates:
        if not is_instance_valid(candidate) or candidate == source:
            continue
        if not (candidate is Node2D):
            continue
        var target := candidate as Node2D
        if not target.visible:
            continue
        if leash_radius > 0.0 and target.global_position.distance_to(leash_center) > leash_radius:
            continue
        var distance := source.global_position.distance_to(target.global_position)
        if distance < best_distance:
            best_distance = distance
            best = target
    return best
