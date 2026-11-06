extends Node2D

const ENEMY_SCRIPT := preload("res://scripts/entities/enemy.gd")

var definition: Dictionary = {}
var objective_id := ""
var objective_type := ""
var region_id := ""
var manager
var world
var nav
var player
var start_position := Vector2.ZERO
var hp := 100
var max_hp := 100
var site_state := "waiting"
var _path := PackedVector2Array()
var _path_index := 0
var _saw_night := false
var _faction_id := ""


func setup(data: Dictionary, manager_ref, world_ref, nav_ref, player_ref, cell: Vector2i, saved: Dictionary = {}) -> void:
    definition = data.duplicate(true)
    objective_id = String(data["id"])
    objective_type = String(data["type"])
    region_id = String(data["region"])
    manager = manager_ref
    world = world_ref
    nav = nav_ref
    player = player_ref
    start_position = nav.center_of(cell)
    position = start_position
    max_hp = int(data.get("hp", 100))
    hp = max_hp
    _faction_id = FactionRegistry.faction_for_region(region_id)

    if not saved.is_empty():
        site_state = String(saved.get("state", "waiting"))
        hp = clampi(int(saved.get("hp", max_hp)), 0, max_hp)
        position = Vector2(float(saved.get("x", start_position.x)), float(saved.get("y", start_position.y)))
        _path_index = maxi(0, int(saved.get("path_index", 0)))
        _saw_night = bool(saved.get("saw_night", false))
    elif objective_type in ["clear_camp", "clear_ruins"]:
        site_state = "active"

    if objective_type in ["clear_camp", "clear_ruins"]:
        add_to_group("campaign_targets")
        if saved.is_empty():
            _spawn_guards()
    elif objective_type == "defend" and site_state == "active":
        add_to_group("defenders")
    elif objective_type in ["rescue", "escort"] and site_state == "escorting":
        add_to_group("defenders")
        _build_escort_path()


func _ready() -> void:
    add_to_group("frontier_sites")
    z_index = 4
    Events.phase_changed.connect(_on_phase_changed)
    queue_redraw()


func interact() -> void:
    if site_state == "complete":
        return
    if int(definition.get("act", 1)) > manager.unlocked_act:
        Events.build_feedback.emit("Objektif ini terbuka pada ACT %d." % int(definition.get("act", 1)))
        return
    match objective_type:
        "clear_camp", "clear_ruins":
            Events.build_feedback.emit("Hancurkan sasaran: " + String(definition["name"]))
        "rescue", "escort":
            if site_state in ["waiting", "failed"]:
                hp = max_hp
                position = start_position
                site_state = "escorting"
                _path_index = 1
                _build_escort_path()
                if _path.is_empty():
                    site_state = "waiting"
                    Events.build_feedback.emit("Jalur ke Keep belum dapat dilalui")
                    return
                add_to_group("defenders")
                Events.build_feedback.emit("Kawal " + String(definition["name"]) + " menuju Keep. Jangan tinggalkan terlalu jauh.")
            else:
                Events.build_feedback.emit("Tetap dekat. Karavan bergerak saat kamu mengawalnya.")
        "defend":
            if site_state in ["waiting", "failed"]:
                hp = max_hp
                site_state = "active"
                _saw_night = GameClock.is_night
                add_to_group("defenders")
                Events.build_feedback.emit("Sinyal aktif. Pertahankan titik ini sampai fajar.")
            else:
                Events.build_feedback.emit("Pertahanan sudah aktif. Bertahan sampai fajar.")


func _build_escort_path() -> void:
    # The path is recalculated from the saved world position, so the previous
    # path's index is no longer meaningful after a save/load.
    _path = nav.path_to(position, WorldConfig.starting_keep_cell())
    _path_index = 1 if _path.size() > 1 else 0


func _process(delta: float) -> void:
    if site_state == "escorting":
        _tick_escort(delta)
    queue_redraw()


func _tick_escort(delta: float) -> void:
    # Keep the escort moving only while at least one visible friendly unit is nearby.
    # This replaces the retired hero-leash with a commander-managed escort presence.
    var escort_present := false
    if player != null and is_instance_valid(player) and player.visible:
        escort_present = player.global_position.distance_to(global_position) <= 136.0
    if not escort_present:
        for villager in get_tree().get_nodes_in_group("villagers"):
            if not is_instance_valid(villager) or not villager.visible:
                continue
            if villager.global_position.distance_to(global_position) <= 136.0:
                escort_present = true
                break
    if not escort_present:
        return
    if _path.is_empty():
        _build_escort_path()
    if _path.is_empty():
        return
    if _path_index >= _path.size():
        _finish_escort()
        return
    var target := _path[_path_index]
    position = position.move_toward(target, 30.0 * delta)
    if position.distance_to(target) <= 2.0:
        _path_index += 1
    if position.distance_to(_path[_path.size() - 1]) <= 24.0:
        _finish_escort()


func _finish_escort() -> void:
    site_state = "complete"
    remove_from_group("defenders")
    manager.complete_objective(objective_id)
    queue_free()


func _on_phase_changed(is_night: bool) -> void:
    if objective_type != "defend" or site_state != "active":
        return
    if is_night:
        _saw_night = true
    elif _saw_night:
        if hp > 0:
            site_state = "complete"
            remove_from_group("defenders")
            manager.complete_objective(objective_id)
            queue_free()
        else:
            site_state = "failed"
            remove_from_group("defenders")
            Events.build_feedback.emit("Titik pertahanan jatuh. Aktifkan kembali sebelum fajar berikutnya.")


func take_damage(amount: int) -> void:
    if hp <= 0 or site_state in ["complete", "failed", "waiting"]:
        return
    if int(definition.get("act", 1)) > manager.unlocked_act:
        Events.build_feedback.emit("Objektif ini belum terbuka.")
        return
    hp = maxi(0, hp - maxi(1, amount))
    if hp > 0:
        queue_redraw()
        return
    if objective_type in ["clear_camp", "clear_ruins"]:
        site_state = "complete"
        _retreat_guards()
        remove_from_group("campaign_targets")
        remove_from_group("defenders")
        manager.complete_objective(objective_id)
        queue_free()
    elif objective_type in ["rescue", "escort"]:
        site_state = "failed"
        remove_from_group("defenders")
        position = start_position
        Events.build_feedback.emit("Pengawalan gagal. Temukan kembali titik awal dan mulai lagi.")
    else:
        site_state = "failed"
        remove_from_group("defenders")
        Events.build_feedback.emit("Titik pertahanan hancur. Coba aktifkan kembali.")


func _spawn_guards() -> void:
    var roster := FactionRegistry.roster_for(_faction_id)
    if roster.is_empty():
        return
    var count := int(definition.get("guards", 2))
    for index in count:
        var enemy_id: String = roster[index % roster.size()]
        if not DataDB.enemies.has(enemy_id):
            continue
        var guard = ENEMY_SCRIPT.new()
        guard.setup_guard(DataDB.enemies[enemy_id], world, manager.main.flow, player, position, _faction_id)
        guard.campaign_site_id = objective_id
        var angle := TAU * float(index) / float(maxi(1, count))
        guard.position = position + Vector2(cos(angle), sin(angle)) * 38.0
        world.entities.add_child(guard)


func _retreat_guards() -> void:
    for guard in get_tree().get_nodes_in_group("enemy_garrison"):
        if is_instance_valid(guard) and guard.campaign_site_id == objective_id:
            guard.retreat()


func export_state() -> Dictionary:
    return {"state":site_state,"hp":hp,"x":position.x,"y":position.y,"path_index":_path_index,"saw_night":_saw_night}


func _draw() -> void:
    var color := Color("#c48d4d")
    match objective_type:
        "clear_camp": color = Color("#ad5945")
        "clear_ruins": color = Color("#8c9a9e")
        "rescue": color = Color("#79b68a")
        "escort": color = Color("#d5b86c")
        "defend": color = Color("#80a6cf")
    if site_state == "failed":
        color = Color("#6d5555")
    draw_rect(Rect2(-7, -12, 14, 14), Color("#171b1b"))
    draw_rect(Rect2(-6, -11, 12, 12), color)
    draw_rect(Rect2(-6, -11, 12, 12), Color("#ead7ad"), false, 1.0)
    if objective_type in ["clear_camp", "clear_ruins", "defend"]:
        draw_rect(Rect2(-10, -17, 20, 3), Color("#171313"))
        draw_rect(Rect2(-10, -17, 20.0 * float(hp) / float(maxi(1, max_hp)), 3), Color("#d85b4c"))
    if site_state == "escorting":
        draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 16, Color("#f2d37a"), 1.0)
