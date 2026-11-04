extends RefCounted
## Contract for a single villager role. Movement, pathing, carrying and lifecycle stay on Villager.

enum ActorState { IDLE, TO_WORK, WORKING, TO_DEPOT, FLEEING, HIDDEN, FIGHT, EXPEDITION, RECALLING, SCOUTING, SCOUT_RETURNING }

var actor: Variant


func configure(owner: Variant) -> void:
    actor = owner


func role_id() -> String:
    return ""


func collect_candidates() -> Array:
    return []


func precedes(left: Variant, right: Variant) -> bool:
    return left.position.distance_squared_to(actor.position) < right.position.distance_squared_to(actor.position)


func target_is_valid() -> bool:
    return true


func invalid_target_retry_seconds() -> float:
    return 0.15


func claim_target(candidate: Variant) -> bool:
    return actor._claim(candidate)


func release_target() -> void:
    var reserved: Variant = actor.target
    if reserved == null or not is_instance_valid(reserved):
        return
    if reserved.has_method("release"):
        reserved.release(actor)
    elif reserved.get("worker") == actor:
        reserved.worker = null


func on_target_arrived() -> void:
    pass


func perform_work(_delta: float) -> bool:
    return false


func tick_idle(_delta: float) -> bool:
    return false


func find_scout_work() -> void:
    pass


func tick_scouting(_delta: float) -> void:
    pass


func scout_target_reserved(_cell: Vector2i) -> bool:
    return false


func return_to_scout_post() -> void:
    pass


func reset_scout_state() -> void:
    pass


func get_scout_target_cell() -> Vector2i:
    return Vector2i(-1, -1)


func set_scout_target_cell(_cell: Vector2i) -> void:
    pass


func get_smith_recipe() -> String:
    return ""


func set_smith_recipe(_recipe: String) -> void:
    pass


func mine_kind() -> String:
    return "stone"


func tick_fight(_delta: float) -> bool:
    return false


func nearest_enemy() -> Variant:
    return null


func fire_archer_arrow(_enemy: Variant) -> void:
    pass
