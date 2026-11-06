extends Node2D
## RTS command foundation: detached strategy camera, villager selection and move orders.
## The legacy player avatar is retained for save compatibility but is no longer the input focus.

const PAN_SPEED := 360.0
const EDGE_PAN_PIXELS := 14.0
const MIN_ZOOM := 0.7
const MAX_ZOOM := 1.85
const ZOOM_STEP := 0.1
const CLICK_SELECT_RADIUS := 20.0
const DRAG_THRESHOLD := 8.0
const FORMATION_SPACING := 18.0

var world
var nav
var player
var build_system
var camera: Camera2D
var selected_units: Array[Node2D] = []

var _selection_started := false
var _selection_start_screen := Vector2.ZERO
var _selection_start_world := Vector2.ZERO
var _selection_end_world := Vector2.ZERO
var _middle_panning := false
var _command_marker := Vector2.ZERO
var _command_marker_time := 0.0


func _ready() -> void:
    add_to_group("rts_commander")
    z_index = 90
    camera = Camera2D.new()
    camera.position_smoothing_enabled = true
    camera.position_smoothing_speed = 9.0
    camera.zoom = Vector2.ONE
    add_child(camera)
    camera.global_position = world.keep_center_position()
    camera.make_current()

    # Keep the legacy node in place for old saves and system references.
    # The strategy camera replaces its attached camera and direct movement.
    if player != null and is_instance_valid(player):
        if player.camera != null:
            player.camera.enabled = false
        player.velocity = Vector2.ZERO
        player.visible = false
        player.set_physics_process(false)
        player.set_process(false)

    queue_redraw()


func _process(delta: float) -> void:
    if camera == null or get_tree().paused:
        return
    if _selection_started:
        _selection_end_world = get_global_mouse_position()
    _move_camera(delta)
    _prune_selection()
    _command_marker_time = maxf(0.0, _command_marker_time - delta)
    if _selection_started or not selected_units.is_empty() or _command_marker_time > 0.0:
        queue_redraw()


func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        _handle_mouse_button(event)
    elif event is InputEventMouseMotion and _middle_panning:
        camera.global_position -= event.relative / maxf(camera.zoom.x, 0.01)
        _clamp_camera()
        get_viewport().set_input_as_handled()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
    if event.button_index == MOUSE_BUTTON_MIDDLE:
        if _ui_blocks_mouse(event.position):
            return
        _middle_panning = event.pressed
        get_viewport().set_input_as_handled()
        return

    if event.button_index == MOUSE_BUTTON_LEFT:
        if _build_mode_active():
            return
        if event.pressed:
            if _ui_blocks_mouse(event.position):
                return
            _selection_started = true
            _selection_start_screen = event.position
            _selection_start_world = get_global_mouse_position()
            _selection_end_world = _selection_start_world
            get_viewport().set_input_as_handled()
        elif _selection_started:
            _selection_end_world = get_global_mouse_position()
            _finish_selection(event.shift_pressed)
            _selection_started = false
            get_viewport().set_input_as_handled()
        return

    if not event.pressed:
        return

    if event.button_index == MOUSE_BUTTON_RIGHT:
        if _build_mode_active() or _ui_blocks_mouse(event.position):
            return
        if not selected_units.is_empty():
            var destination := get_global_mouse_position()
            var ordered := 0
            var site := _nearest_frontier_site(destination)
            if site != null and not String(site.objective_type) in ["clear_camp", "clear_ruins"]:
                var lead: Node2D = selected_units[0]
                if lead.has_method("issue_interaction_order") and lead.issue_interaction_order(site):
                    ordered = 1
                    for index in range(1, selected_units.size()):
                        var offset := Vector2(float(index % 3) * FORMATION_SPACING, float(index / 3) * FORMATION_SPACING)
                        if selected_units[index].has_method("issue_move_order"):
                            selected_units[index].issue_move_order(destination + offset)
            else:
                var attack_target := _nearest_attack_target(destination)
                if attack_target != null:
                    for unit in selected_units:
                        if unit.has_method("issue_attack_order") and unit.issue_attack_order(attack_target):
                            ordered += 1
                if ordered == 0:
                    ordered = issue_move_order(destination)
            if ordered > 0:
                _command_marker = destination
                _command_marker_time = 0.85
                Events.build_feedback.emit("Perintah dikirim: %d unit" % ordered)
        # Consume the right click even with no selection. It must not fall
        # through to the legacy right-click demolition behavior.
        get_viewport().set_input_as_handled()
        return

    if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
        if _build_mode_active() or _ui_blocks_mouse(event.position):
            return
        var direction := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
        var next_zoom := clampf(camera.zoom.x + direction * ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
        camera.zoom = Vector2.ONE * next_zoom
        _clamp_camera()
        get_viewport().set_input_as_handled()


func _move_camera(delta: float) -> void:
    var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if direction.length_squared() > 0.001:
        camera.global_position += direction.normalized() * PAN_SPEED * delta / maxf(camera.zoom.x, 0.01)
        _clamp_camera()
        return

    var mouse := get_viewport().get_mouse_position()
    var viewport := get_viewport_rect().size
    if _ui_blocks_mouse(mouse):
        return
    var edge_direction := Vector2.ZERO
    if mouse.x <= EDGE_PAN_PIXELS:
        edge_direction.x -= 1.0
    elif mouse.x >= viewport.x - EDGE_PAN_PIXELS:
        edge_direction.x += 1.0
    if mouse.y <= EDGE_PAN_PIXELS:
        edge_direction.y -= 1.0
    elif mouse.y >= viewport.y - EDGE_PAN_PIXELS:
        edge_direction.y += 1.0
    if edge_direction != Vector2.ZERO:
        camera.global_position += edge_direction.normalized() * PAN_SPEED * delta / maxf(camera.zoom.x, 0.01)
        _clamp_camera()


func _clamp_camera() -> void:
    if world == null or camera == null:
        return
    var half_view := get_viewport_rect().size / camera.zoom * 0.5
    var bounds := Vector2(world.pixel_size)
    var min_x := minf(half_view.x, bounds.x * 0.5)
    var min_y := minf(half_view.y, bounds.y * 0.5)
    var max_x := maxf(bounds.x - half_view.x, bounds.x * 0.5)
    var max_y := maxf(bounds.y - half_view.y, bounds.y * 0.5)
    camera.global_position = Vector2(
        clampf(camera.global_position.x, min_x, max_x),
        clampf(camera.global_position.y, min_y, max_y)
    )


func _finish_selection(additive: bool) -> void:
    var screen_distance := _selection_start_screen.distance_to(get_viewport().get_mouse_position())
    if screen_distance >= DRAG_THRESHOLD:
        var rect := Rect2(_selection_start_world, _selection_end_world - _selection_start_world).abs()
        select_units_in_rect(rect, additive)
        return

    var clicked := _nearest_selectable(_selection_end_world)
    if clicked == null:
        if not additive:
            clear_selection()
        return
    select_unit(clicked, additive)


func _nearest_frontier_site(world_position: Vector2) -> Node2D:
    var best: Node2D = null
    var best_distance := 30.0
    for value in get_tree().get_nodes_in_group("frontier_sites"):
        if not is_instance_valid(value) or not value.visible or not (value is Node2D):
            continue
        var site := value as Node2D
        var distance := site.global_position.distance_to(world_position)
        if distance < best_distance:
            best_distance = distance
            best = site
    return best


func _nearest_attack_target(world_position: Vector2) -> Node2D:
    var best: Node2D = null
    var best_distance := 34.0
    var candidates: Array = []
    for group_name in ["enemies", "campaign_targets", "enemy_strongholds"]:
        for value in get_tree().get_nodes_in_group(group_name):
            if not candidates.has(value):
                candidates.append(value)
    for value in candidates:
        if not is_instance_valid(value) or not value.visible or not (value is Node2D):
            continue
        var target := value as Node2D
        var hp_value: Variant = target.get("hp")
        if hp_value is int and int(hp_value) <= 0:
            continue
        var distance := target.global_position.distance_to(world_position)
        if distance < best_distance:
            best_distance = distance
            best = target
    return best


func _nearest_selectable(world_position: Vector2) -> Node2D:
    var best: Node2D = null
    var best_distance := CLICK_SELECT_RADIUS
    for value in get_tree().get_nodes_in_group("villagers"):
        if not is_instance_valid(value) or not value.visible or not (value is Node2D):
            continue
        var unit := value as Node2D
        var distance := unit.global_position.distance_to(world_position)
        if distance < best_distance:
            best_distance = distance
            best = unit
    return best


func select_units_in_rect(rect: Rect2, additive := false) -> void:
    if not additive:
        selected_units.clear()
    for value in get_tree().get_nodes_in_group("villagers"):
        if not is_instance_valid(value) or not value.visible or not (value is Node2D):
            continue
        var unit := value as Node2D
        if rect.has_point(unit.global_position) and not selected_units.has(unit):
            selected_units.append(unit)
    queue_redraw()


func select_unit(unit: Node2D, additive := false) -> void:
    if unit == null or not is_instance_valid(unit) or not unit.visible:
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
    if selected_units.is_empty():
        return 0

    var count := selected_units.size()
    var columns := maxi(1, ceili(sqrt(float(count))))
    var rows := ceili(float(count) / float(columns))
    var issued := 0
    for index in count:
        var column := index % columns
        var row := floori(float(index) / float(columns))
        var offset := Vector2(
            (float(column) - float(columns - 1) * 0.5) * FORMATION_SPACING,
            (float(row) - float(rows - 1) * 0.5) * FORMATION_SPACING
        )
        if selected_units[index].has_method("issue_move_order"):
            if selected_units[index].issue_move_order(destination + offset):
                issued += 1
    return issued


func _prune_selection() -> void:
    for index in range(selected_units.size() - 1, -1, -1):
        var unit := selected_units[index]
        if not is_instance_valid(unit) or not unit.visible or not unit.is_in_group("villagers"):
            selected_units.remove_at(index)


func _build_mode_active() -> bool:
    return build_system != null and String(build_system.active) != ""


func _ui_blocks_mouse(position: Vector2) -> bool:
    var hud := get_tree().get_first_node_in_group("hud")
    return hud != null and hud.blocks_mouse(position)


func _draw() -> void:
    for unit in selected_units:
        if not is_instance_valid(unit) or not unit.visible:
            continue
        draw_arc(unit.global_position + Vector2(0, -2), 10.5, 0.0, TAU, 24, Color("#e5c77d"), 1.35, true)
        draw_arc(unit.global_position + Vector2(0, -2), 8.0, 0.0, TAU, 24, Color(0.08, 0.07, 0.05, 0.48), 0.8, true)

    if _selection_started:
        var rect := Rect2(_selection_start_world, _selection_end_world - _selection_start_world).abs()
        draw_rect(rect, Color(0.78, 0.85, 0.72, 0.12), true)
        draw_rect(rect, Color("#d7c58e"), false, 1.0, true)

    if _command_marker_time > 0.0:
        var progress := 1.0 - _command_marker_time / 0.85
        var radius := lerpf(5.0, 13.0, progress)
        draw_arc(_command_marker, radius, 0.0, TAU, 20, Color(0.9, 0.82, 0.58, 1.0 - progress), 1.5, true)
