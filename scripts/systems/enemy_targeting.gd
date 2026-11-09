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
    var best_distance_squared := max_distance * max_distance
    var leash_radius_squared := leash_radius * leash_radius
    for candidate in candidates:
        if not is_instance_valid(candidate) or candidate == source:
            continue
        if not (candidate is Node2D):
            continue
        var target := candidate as Node2D
        if not target.visible:
            continue
        if leash_radius > 0.0 and target.global_position.distance_squared_to(leash_center) > leash_radius_squared:
            continue
        var distance_squared := source.global_position.distance_squared_to(target.global_position)
        if distance_squared < best_distance_squared:
            best_distance_squared = distance_squared
            best = target
    return best
