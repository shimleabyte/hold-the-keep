class_name ArmyCommand
extends Node2D
## Mouse command layer for military units only. Workers and the player avatar
## keep their existing autonomous and direct-control behavior.

const CLICK_SELECT_RADIUS: float = 18.0
const DRAG_THRESHOLD: float = 8.0
const FORMATION_SPACING: float = 22.0
const COMMAND_MARKER_SECONDS: float = 0.75

var world: WorldMap
var nav: NavGrid
var build_system: BuildSystem
var selected_units: Array[Villager] = []

var _selection_started: bool = false
var _selection_start_screen: Vector2 = Vector2.ZERO
var _selection_start_world: Vector2 = Vector2.ZERO
var _selection_end_world: Vector2 = Vector2.ZERO
var _command_marker: Vector2 = Vector2.ZERO
var _command_marker_time: float = 0.0


func _ready() -> void:
    add_to_group("army_command_manager")
    z_index = 90
    queue_redraw()


func _process(delta: float) -> void:
    if get_tree().paused:
        return
    if _selection_started:
        _selection_end_world = get_global_mouse_position()
    _command_marker_time = maxf(0.0, _command_marker_time - delta)
    _prune_selection()
    if _selection_started or not selected_units.is_empty() or _command_marker_time > 0.0:
        queue_redraw()


func _input(event: InputEvent) -> void:
    if get_tree().paused or not (event is InputEventMouseButton):
        return
    var mouse_event: InputEventMouseButton = event as InputEventMouseButton
    if _mouse_blocked(mouse_event.position) or _build_mode_active():
        return

    if mouse_event.button_index == MOUSE_BUTTON_LEFT:
        if mouse_event.pressed:
            # Clicking a hostile entity remains the player's direct melee attack.
            if _nearest_attack_target(get_global_mouse_position()) != null:
                return
            _selection_started = true
            _selection_start_screen = mouse_event.position
            _selection_start_world = get_global_mouse_position()
            _selection_end_world = _selection_start_world
        elif _selection_started:
            _selection_end_world = get_global_mouse_position()
            _finish_selection(mouse_event.shift_pressed)
            _selection_started = false
        else:
            return
        get_viewport().set_input_as_handled()
        return

    if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
        if selected_units.is_empty():
            return
        var destination: Vector2 = get_global_mouse_position()
        var target: Node2D = _nearest_attack_target(destination)
        var issued: int = issue_attack_order(target) if target != null else issue_move_order(destination)
        if issued > 0:
            _command_marker = destination
            _command_marker_time = COMMAND_MARKER_SECONDS
            Events.build_feedback.emit("Army order issued to %d unit(s)" % issued)
        get_viewport().set_input_as_handled()


func blocks_player_attack() -> bool:
    return _selection_started


func _mouse_blocked(screen_position: Vector2) -> bool:
    var hud: Node = get_tree().get_first_node_in_group("hud")
    return hud != null and hud.has_method("blocks_mouse") and bool(hud.call("blocks_mouse", screen_position))


func _build_mode_active() -> bool:
    return build_system != null and not String(build_system.get("active")).is_empty()


func is_selectable(unit: Villager) -> bool:
    if unit == null or not is_instance_valid(unit) or not (unit is Node2D):
        return false
    if not unit.is_in_group("villagers") or not unit.visible:
        return false
    if String(unit.job) != "soldier" or int(unit.hp) <= 0:
        return false
    return true


func _finish_selection(additive: bool) -> void:
    var distance: float = _selection_start_screen.distance_to(get_viewport().get_mouse_position())
    if distance >= DRAG_THRESHOLD:
        var rect: Rect2 = Rect2(_selection_start_world, _selection_end_world - _selection_start_world).abs()
        select_units_in_rect(rect, additive)
        return
    var clicked: Villager = _nearest_selectable(_selection_end_world)
    if clicked == null:
        if not additive:
            clear_selection()
        return
    select_unit(clicked, additive)


func _nearest_selectable(world_position: Vector2) -> Villager:
    var best: Villager = null
    var best_distance: float = CLICK_SELECT_RADIUS
    for value: Node in get_tree().get_nodes_in_group("villagers"):
        var unit: Villager = value as Villager
        if not is_selectable(unit):
            continue
        var distance: float = unit.global_position.distance_to(world_position)
        if distance < best_distance:
            best_distance = distance
            best = unit
    return best


func select_units_in_rect(rect: Rect2, additive: bool = false) -> void:
    if not additive:
        selected_units.clear()
    for value: Node in get_tree().get_nodes_in_group("villagers"):
        var unit: Villager = value as Villager
        if not is_selectable(unit):
            continue
        if rect.has_point(unit.global_position) and not selected_units.has(unit):
            selected_units.append(unit)
    queue_redraw()


func select_unit(unit: Villager, additive: bool = false) -> void:
    if not is_selectable(unit):
        return
    if not additive:
        selected_units.clear()
        selected_units.append(unit)
    elif selected_units.has(unit):
        selected_units.erase(unit)
    else:
        selected_units.append(unit)
    queue_redraw()


func clear_selection() -> void:
    selected_units.clear()
    queue_redraw()


func issue_move_order(destination: Vector2) -> int:
    _prune_selection()
    if selected_units.is_empty() or nav == null:
        return 0
    var count: int = selected_units.size()
    var columns: int = maxi(1, ceili(sqrt(float(count))))
    var rows: int = ceili(float(count) / float(columns))
    var issued: int = 0
    for index: int in count:
        var column: int = index % columns
        var row: int = floori(float(index) / float(columns))
        var offset: Vector2 = Vector2(
            (float(column) - float(columns - 1) * 0.5) * FORMATION_SPACING,
            (float(row) - float(rows - 1) * 0.5) * FORMATION_SPACING
        )
        var unit: Villager = selected_units[index]
        if is_instance_valid(unit) and unit.issue_army_move_order(destination + offset):
            issued += 1
    return issued


func issue_attack_order(target: Node2D) -> int:
    _prune_selection()
    if target == null or not is_instance_valid(target):
        return 0
    var issued: int = 0
    for unit: Villager in selected_units:
        if is_instance_valid(unit) and unit.issue_army_attack_order(target):
            issued += 1
    return issued


func _nearest_attack_target(world_position: Vector2) -> Node2D:
    var best: Node2D = null
    var best_distance: float = 34.0
    var candidates: Array[Node2D] = []
    for group_name: String in ["enemies", "enemy_strongholds", "enemy_buildings", "faction_camp_targets", "campaign_targets"]:
        for candidate: Node in get_tree().get_nodes_in_group(group_name):
            var candidate_2d: Node2D = candidate as Node2D
            if candidate_2d != null and not candidates.has(candidate_2d):
                candidates.append(candidate_2d)
    for target: Node2D in candidates:
        if not is_instance_valid(target) or not target.visible:
            continue
        var target_hp: int = int(target.get("hp"))
        if target_hp <= 0:
            continue
        var distance: float = target.global_position.distance_to(world_position)
        if distance < best_distance:
            best_distance = distance
            best = target
    return best


func _prune_selection() -> void:
    for index: int in range(selected_units.size() - 1, -1, -1):
        if not is_selectable(selected_units[index]):
            selected_units.remove_at(index)


func _draw() -> void:
    for unit: Villager in selected_units:
        if not is_instance_valid(unit) or not unit.visible:
            continue
        var anchor: Vector2 = to_local(unit.global_position) + Vector2(0, -2)
        draw_arc(anchor, 11.0, 0.0, TAU, 24, Color("#e6c985"), 1.4, true)
        draw_arc(anchor, 8.5, 0.0, TAU, 24, Color(0.04, 0.04, 0.03, 0.62), 0.8, true)

    if _selection_started:
        var rect: Rect2 = Rect2(_selection_start_world, _selection_end_world - _selection_start_world).abs()
        var local_rect: Rect2 = Rect2(to_local(rect.position), rect.size)
        draw_rect(local_rect, Color(0.78, 0.85, 0.72, 0.12), true)
        draw_rect(local_rect, Color("#d7c58e"), false, 1.0, true)

    if _command_marker_time > 0.0:
        var progress: float = 1.0 - _command_marker_time / COMMAND_MARKER_SECONDS
        var radius: float = lerpf(5.0, 13.0, progress)
        draw_arc(to_local(_command_marker), radius, 0.0, TAU, 20, Color(0.9, 0.82, 0.58, 1.0 - progress), 1.5, true)
