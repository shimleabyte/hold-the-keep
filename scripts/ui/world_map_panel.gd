extends Control
## Exploration-aware strategic map. Unexplored cells stay hidden; all markers use world coordinates.

var _map_scale := 3.0
var _map_pixels := 192.0
var _map_origin := Vector2(64.0, 20.0)
const PIXEL_FONT := preload("res://scripts/ui/pixel_font.gd")

const UNKNOWN := Color("#101820")
const WATER := Color("#284b67")
const GRASS := Color("#668b4a")
const FOREST := Color("#385f38")
const HIGHLAND := Color("#74796e")
const MARSH := Color("#727a4a")
const ROAD_COLOR := Color("#cfad7a")
const ASHEN := Color("#706052")
const PLAYER_TERRITORY := Color("#d2aa59")
const ENEMY_TERRITORY := Color("#ae5148")
const PLAYER_MARKER := Color("#f5e2a4")
const ALLY_MARKER := Color("#8fc4c2")
const ENEMY_MARKER := Color("#ef7567")

signal close_requested

var world
var fog
var territory
var font: Font
var _refresh_timer := 0.0


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    font = PIXEL_FONT.get_font()


func configure(world_ref, fog_ref, territory_ref, font_ref: Font = null) -> void:
    world = world_ref
    fog = fog_ref
    territory = territory_ref
    if font_ref != null:
        font = font_ref
    queue_redraw()


func configure_layout(viewport_size: Vector2) -> void:
    var available_width := maxf(192.0, viewport_size.x - 150.0)
    var available_height := maxf(192.0, viewport_size.y - 70.0)
    var minimum_tile_scale := 1.0 if WorldConfig.profile_id == "frontier" else 3.0
    _map_scale = clampf(minf(available_width, available_height) / float(WorldConfig.map_size), minimum_tile_scale, 4.5)
    _map_pixels = WorldConfig.map_size * _map_scale
    size = Vector2(_map_pixels + 128.0, _map_pixels + 50.0)
    _map_origin = Vector2((size.x - _map_pixels) * 0.5, 20.0)
    queue_redraw()


func _process(delta: float) -> void:
    if not visible:
        return
    _refresh_timer -= delta
    if _refresh_timer > 0.0:
        return
    _refresh_timer = 0.25
    queue_redraw()


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if Rect2(size.x - 22.0, 2.0, 18.0, 13.0).has_point(event.position):
            close_requested.emit()
        accept_event()


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("#111820"))
    draw_rect(Rect2(Vector2.ZERO, size), Color("#b18a55"), false, 2.0)
    draw_rect(Rect2(1, 1, size.x - 2, 17), Color("#202a2e"))
    draw_rect(Rect2(1, 1, 3, 17), Color("#c99b53"))
    draw_line(Vector2(8, 17), Vector2(size.x - 8, 17), Color("#66553d"), 1.0)
    if font == null:
        return

    draw_string(font, Vector2(10, 12), "PETA WILAYAH", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#f0d39a"))
    draw_string(font, Vector2(size.x - 120.0, 12), "HARI %02d" % GameClock.day, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("#c5bba8"))
    draw_string(font, Vector2(size.x - 68.0, 12), "TAB / ESC", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color("#b4a58c"))
    draw_rect(Rect2(size.x - 22.0, 2.0, 18.0, 13.0), Color("#302820"))
    draw_rect(Rect2(size.x - 22.0, 2.0, 18.0, 13.0), Color("#d2a660"), false, 1.0)
    draw_line(Vector2(size.x - 17.0, 5.0), Vector2(size.x - 9.0, 12.0), Color("#f1dfc2"), 1.0)
    draw_line(Vector2(size.x - 9.0, 5.0), Vector2(size.x - 17.0, 12.0), Color("#f1dfc2"), 1.0)

    if world == null or fog == null:
        draw_string(font, Vector2(8, 124), "MEMUAT PETA...", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
        return

    if territory != null:
        territory._ensure_current()

    for y in WorldConfig.map_size:
        for x in WorldConfig.map_size:
            var cell := Vector2i(x, y)
            var rect := Rect2(_map_origin + Vector2(x, y) * _map_scale, Vector2(_map_scale, _map_scale))
            if not fog.is_revealed_cell(cell):
                draw_rect(rect, UNKNOWN)
                continue

            var terrain: int = int(world.tile_type_at(cell))
            var tint := GRASS
            match terrain:
                2:
                    tint = WATER
                3:
                    tint = FOREST
                4:
                    tint = HIGHLAND
                5:
                    tint = MARSH
                6:
                    tint = ASHEN
                _:
                    tint = GRASS

            if territory != null:
                var player_claimed: bool = territory.claimed_cells.has(cell)
                var enemy_claimed: bool = territory.enemy_claimed_cells.has(cell)
                if player_claimed and enemy_claimed:
                    tint = tint.lerp(Color("#9b6d75"), 0.55)
                elif player_claimed:
                    tint = tint.lerp(PLAYER_TERRITORY, 0.28)
                elif enemy_claimed:
                    tint = tint.lerp(ENEMY_TERRITORY, 0.32)
            draw_rect(rect, tint)

    _draw_road_markers()
    _draw_region_labels()
    _draw_resource_markers()
    _draw_building_markers()
    _draw_campaign_markers()
    _draw_frontier_site_markers()
    _draw_faction_camp_markers()
    _draw_unit_markers()
    _draw_camera_window()
    _draw_player_marker()

    for grid in range(8, WorldConfig.map_size, 8):
        var line_color := Color(0.82, 0.76, 0.62, 0.2)
        var offset := float(grid) * _map_scale
        draw_line(_map_origin + Vector2(offset, 0), _map_origin + Vector2(offset, _map_pixels), line_color, 1.0)
        draw_line(_map_origin + Vector2(0, offset), _map_origin + Vector2(_map_pixels, offset), line_color, 1.0)
    draw_rect(Rect2(_map_origin, Vector2(_map_pixels, _map_pixels)), Color("#e1c99a"), false, 1.0)
    _draw_legend()

func _world_to_map(world_position: Vector2) -> Vector2:
    if world == null:
        return _map_origin
    var world_size := Vector2(world.pixel_size)
    return _map_origin + Vector2(
        world_position.x / maxf(1.0, world_size.x),
        world_position.y / maxf(1.0, world_size.y)
    ) * _map_pixels


func _position_is_known(world_position: Vector2) -> bool:
    if fog == null:
        return false
    var cell := Vector2i((world_position / float(WorldConfig.tile_size)).floor())
    return fog.is_revealed_cell(cell)


func _marker(world_position: Vector2, color: Color, radius := 1.5) -> void:
    if not _position_is_known(world_position):
        return
    draw_circle(_world_to_map(world_position), radius * (_map_scale / 3.0), color)


func _draw_region_labels() -> void:
    var center := WorldConfig.map_size / 2
    var regions: Array = []
    if WorldConfig.profile_id == "frontier":
        regions = [
            [Vector2i(roundi(WorldConfig.map_size * 0.19), roundi(WorldConfig.map_size * 0.20)), "GREENWOOD"],
            [Vector2i(roundi(WorldConfig.map_size * 0.81), roundi(WorldConfig.map_size * 0.20)), "HIGHLANDS"],
            [Vector2i(roundi(WorldConfig.map_size * 0.19), roundi(WorldConfig.map_size * 0.80)), "FENLANDS"],
            [Vector2i(roundi(WorldConfig.map_size * 0.81), roundi(WorldConfig.map_size * 0.80)), "ASHEN MARCH"],
            [Vector2i(center, center), "HEARTHLAND"]
        ]
    else:
        regions = [
            [Vector2i(32, 8), "GREENWOOD"],
            [Vector2i(53, 32), "HIGHLANDS"],
            [Vector2i(20, 49), "FENLANDS"],
            [Vector2i(32, 32), "HEARTHLAND"]
        ]
    for item in regions:
        var cell: Vector2i = item[0]
        if fog.is_revealed_cell(cell):
            var label_position := _map_origin + (Vector2(cell) + Vector2(0.5, 0.5)) * _map_scale
            var font_size := maxi(6, roundi(6.0 * _map_scale / 3.0))
            var label_color := Color(1, 1, 1, 0.84)
            var control := "neutral"
            if territory != null and world != null:
                var region_id: String = world.region_id(cell)
                var state: Dictionary = territory.get_region_state(region_id)
                control = String(state.get("control", "neutral"))
            match control:
                "player":
                    label_color = Color("#f0d39a")
                "enemy":
                    label_color = Color("#ef8a7c")
                "contested":
                    label_color = Color("#d49caa")
            draw_circle(label_position + Vector2(-4.0, -3.0), maxf(1.2, _map_scale * 0.32), label_color)
            draw_string(font, label_position, String(item[1]), HORIZONTAL_ALIGNMENT_CENTER, 60.0 * _map_scale / 3.0, font_size, label_color)


func _draw_road_markers() -> void:
    for road in get_tree().get_nodes_in_group("roads"):
        if not is_instance_valid(road) or not fog.is_revealed_cell(road.cell):
            continue
        var center := _map_origin + (Vector2(road.cell) + Vector2(0.5, 0.5)) * _map_scale
        var half := _map_scale * 0.32
        draw_line(center - Vector2(half, 0.0), center + Vector2(half, 0.0), ROAD_COLOR, maxf(1.0, _map_scale * 0.22))


func _draw_resource_markers() -> void:
    for resource in get_tree().get_nodes_in_group("resource_nodes"):
        if is_instance_valid(resource):
            var marker_color := Color("#a9b09a")
            if String(resource.yield_kind) == "wood":
                marker_color = Color("#8ebd6b")
            elif String(resource.yield_kind) == "iron":
                marker_color = Color("#d58b62")
            _marker(resource.global_position, marker_color, 1.0)


func _draw_building_markers() -> void:
    for building in get_tree().get_nodes_in_group("buildings"):
        if not is_instance_valid(building) or String(building.id) == "road" or not _position_is_known(building.global_position):
            continue
        var color := Color("#c6b49a")
        var radius := 1.5
        if String(building.id) == "keep":
            color = PLAYER_MARKER
            radius = 3.0
        elif String(building.id) == "outpost":
            color = ALLY_MARKER
            radius = 2.2
        draw_circle(_world_to_map(building.global_position), radius * (_map_scale / 3.0), color)


func _draw_campaign_markers() -> void:
    var campaign = get_tree().get_first_node_in_group("campaign")
    for stronghold in get_tree().get_nodes_in_group("enemy_strongholds"):
        if not is_instance_valid(stronghold) or not _position_is_known(stronghold.global_position):
            continue
        var marker_size := 5.0 * _map_scale / 3.0
        var marker_position := _world_to_map(stronghold.global_position)
        var is_active: bool = campaign != null and campaign.is_current_objective(stronghold.stronghold_id)
        var marker_color := ENEMY_MARKER if is_active else ENEMY_TERRITORY.darkened(0.25)
        if is_active:
            draw_circle(marker_position, marker_size * 0.9, Color("#f3bd78"))
        draw_rect(Rect2(marker_position - Vector2.ONE * marker_size * 0.5, Vector2.ONE * marker_size), marker_color)




func _draw_frontier_site_markers() -> void:
    if WorldConfig.profile_id != "frontier":
        return
    for site in get_tree().get_nodes_in_group("frontier_sites"):
        if not is_instance_valid(site) or site.site_state == "complete":
            continue
        if not _position_is_known(site.global_position):
            continue

        var marker_position := _world_to_map(site.global_position)
        var marker_size := maxf(2.0, 5.0 * _map_scale / 3.0)
        var marker_color := Color("#c48d4d")
        match String(site.objective_type):
            "clear_camp":
                marker_color = Color("#d66a59")
            "clear_ruins":
                marker_color = Color("#aab5b8")
            "rescue":
                marker_color = Color("#83c09a")
            "escort":
                marker_color = Color("#e0bd70")
            "defend":
                marker_color = Color("#84a9d2")

        var is_locked: bool = int(site.definition.get("act", 1)) > int(site.manager.unlocked_act)
        if site.site_state == "failed":
            marker_color = Color("#765453")
        elif is_locked:
            marker_color = marker_color.darkened(0.55)

        if not is_locked and (site.site_state == "escorting" or site.site_state == "active"):
            draw_circle(marker_position, marker_size * 1.05, Color("#f4d08a"))
        if String(site.objective_type) in ["rescue", "escort"]:
            draw_circle(marker_position, marker_size * 0.58, marker_color)
        elif String(site.objective_type) == "clear_ruins":
            var half := marker_size * 0.55
            draw_colored_polygon(PackedVector2Array([
                marker_position + Vector2(0, -half),
                marker_position + Vector2(half, 0),
                marker_position + Vector2(0, half),
                marker_position + Vector2(-half, 0)
            ]), marker_color)
        else:
            draw_rect(Rect2(marker_position - Vector2.ONE * marker_size * 0.5,
                Vector2.ONE * marker_size), marker_color)

func _draw_faction_camp_markers() -> void:
    if WorldConfig.profile_id != "frontier":
        return
    var manager = get_tree().get_first_node_in_group("faction_camp_manager")
    if manager == null:
        return
    for camp_id in manager.camps:
        var camp: Dictionary = manager.camps[camp_id]
        if bool(camp.get("destroyed", false)) or not bool(camp.get("activated", false)):
            continue
        var cell: Vector2i = camp["cell"]
        if not fog.is_revealed_cell(cell):
            continue
        var marker_position := _world_to_map(camp["position"])
        var marker_size := maxf(2.5, 6.0 * _map_scale / 3.0)
        var faction_data: Dictionary = FactionRegistry.factions[String(camp["faction_id"])]
        var marker_color := Color(String(faction_data.get("color", "#c58b52")))
        if bool(camp.get("suppressed", false)):
            marker_color = marker_color.darkened(0.55)
        draw_colored_polygon(PackedVector2Array([
            marker_position + Vector2(0, -marker_size),
            marker_position + Vector2(marker_size, marker_size * 0.65),
            marker_position + Vector2(-marker_size, marker_size * 0.65)
        ]), marker_color)
        draw_rect(Rect2(marker_position + Vector2(-marker_size * 0.18, -marker_size * 0.12),
            Vector2(marker_size * 0.36, marker_size * 0.9)), Color("#181918"))


func _is_currently_observed(world_position: Vector2) -> bool:
    var player_node = get_tree().get_first_node_in_group("player")
    if player_node != null and player_node.global_position.distance_to(world_position) <= 112.0:
        return true
    for villager in get_tree().get_nodes_in_group("villagers"):
        if is_instance_valid(villager) and villager.visible and villager.global_position.distance_to(world_position) <= 64.0:
            return true
    for building in get_tree().get_nodes_in_group("buildings"):
        if not is_instance_valid(building):
            continue
        var radius := 160.0 if String(building.id) == "keep" else (144.0 if String(building.id) == "outpost" else 0.0)
        if radius > 0.0 and building.global_position.distance_to(world_position) <= radius:
            return true
    return false


func _draw_unit_markers() -> void:
    for villager in get_tree().get_nodes_in_group("villagers"):
        if is_instance_valid(villager) and villager.visible:
            _marker(villager.global_position, ALLY_MARKER, 1.0)
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if is_instance_valid(enemy) and _is_currently_observed(enemy.global_position):
            _marker(enemy.global_position, ENEMY_MARKER, 1.0)


func _draw_camera_window() -> void:
    var player_node = get_tree().get_first_node_in_group("player")
    if player_node == null or player_node.camera == null:
        return
    var camera: Camera2D = player_node.camera
    var zoom := Vector2(maxf(0.01, camera.zoom.x), maxf(0.01, camera.zoom.y))
    var half_view := get_viewport_rect().size / zoom * 0.5
    var center := camera.get_screen_center_position()
    var top_left := _world_to_map(center - half_view)
    var bottom_right := _world_to_map(center + half_view)
    draw_rect(Rect2(top_left, bottom_right - top_left), Color("#e6d7b7"), false, 1.0)


func _draw_player_marker() -> void:
    var player = get_tree().get_first_node_in_group("player")
    if player == null:
        return
    var point := _world_to_map(player.global_position)
    var radius := _map_scale
    draw_circle(point, radius * 1.05, Color("#151515"))
    draw_circle(point, radius * 0.68, PLAYER_MARKER)
    var arm := _map_scale * 1.5
    draw_line(point - Vector2(arm, 0.0), point + Vector2(arm, 0.0), Color.WHITE, 1.0)
    draw_line(point - Vector2(0.0, arm), point + Vector2(0.0, arm), Color.WHITE, 1.0)


func _draw_legend() -> void:
    var y := size.y - 11.0
    draw_line(Vector2(8, y - 11.0), Vector2(size.x - 8, y - 11.0), Color("#66553d"), 1.0)
    var items := [
        [PLAYER_TERRITORY, "KITA"],
        [ENEMY_TERRITORY, "MUSUH"],
        [PLAYER_MARKER, "KEEP"],
        [ALLY_MARKER, "PASUKAN"],
        [Color("#e0bd70"), "OBJEK"]
    ]
    var x := 9.0
    for item in items:
        draw_rect(Rect2(x, y - 7.0, 6.0, 6.0), item[0])
        draw_string(font, Vector2(x + 9.0, y), String(item[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("#e1d4bd"))
        x += 61.0
