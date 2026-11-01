extends RefCounted
## Support actions shared by healing and future aura archetypes.

static func heal_nearest_ally(source: Node2D, radius: float, amount: int) -> bool:
    if source == null or not is_instance_valid(source) or radius <= 0.0 or amount <= 0:
        return false
    var best = null
    var best_distance := radius
    for candidate in source.get_tree().get_nodes_in_group("enemies"):
        if candidate == source or not is_instance_valid(candidate):
            continue
        if not candidate.has_method("receive_healing"):
            continue
        if int(candidate.hp) >= int(candidate.max_hp):
            continue
        var distance := source.global_position.distance_to(candidate.global_position)
        if distance < best_distance:
            best_distance = distance
            best = candidate
    if best == null:
        return false
    best.receive_healing(amount)
    Events.fx_burst.emit("impact", best.global_position + Vector2(0, -8), Vector2.ZERO, 1.0)
    return true
