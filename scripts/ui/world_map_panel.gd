extends Control
## Exploration-aware strategic map. Unexplored cells stay hidden; all markers use world coordinates.

const MAP_SIZE := 64
const TILE_SIZE := 16
const MAP_PIXELS := 192.0
const MAP_ORIGIN := Vector2(64.0, 20.0)
const PIXEL_FONT := preload("res://scripts/ui/pixel_font.gd")

const UNKNOWN := Color("#101820")
const WATER := Color("#284b67")
const GRASS := Color("#668b4a")
const FOREST := Color("#385f38")
const HIGHLAND := Color("#74796e")
const MARSH := Color("#727a4a")
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
    draw_rect(Rect2(Vector2.ZERO, size), Color("#111319"))
    draw_rect(Rect2(Vector2.ZERO, size), Color("#a88a5e"), false, 1.0)
    if font == null:
        return

    draw_string(font, Vector2(8, 11), "PETA WILAYAH", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#e7c783"))
    draw_string(font, Vector2(size.x - 52.0, 11), "HARI %02d" % GameClock.day, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("#c5bba8"))
    draw_rect(Rect2(size.x - 22.0, 2.0, 18.0, 13.0), Color("#302820"))
    draw_rect(Rect2(size.x - 22.0, 2.0, 18.0, 13.0), Color("#9f7652"), false, 1.0)
    draw_line(Vector2(size.x - 17.0, 5.0), Vector2(size.x - 9.0, 12.0), Color("#e8d8bc"), 1.0)
    draw_line(Vector2(size.x - 9.0, 5.0), Vector2(size.x - 17.0, 12.0), Color("#e8d8bc"), 1.0)

    if world == null or fog == null:
        draw_string(font, Vector2(8, 124), "MEMUAT PETA...", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
        return

    if territory != null:
        territory._ensure_current()

    for y in MAP_SIZE:
        for x in MAP_SIZE:
            var cell := Vector2i(x, y)
            var rect := Rect2(MAP_ORIGIN + Vector2(x, y) * 3.0, Vector2(3.0, 3.0))
            if not fog.is_revealed_cell(cell):
                draw_rect(rect, UNKNOWN)
                continue

            var terrain := world.tile_type_at(cell)
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

    _draw_region_labels()
    _draw_resource_markers()
    _draw_building_markers()
    _draw_campaign_markers()
    _draw_unit_markers()
    _draw_player_marker()

    draw_rect(Rect2(MAP_ORIGIN, Vector2(MAP_PIXELS, MAP_PIXELS)), Color("#d4c09a"), false, 1.0)
    _draw_legend()

func _world_to_map(world_position: Vector2) -> Vector2:
    if world == null:
        return MAP_ORIGIN
    var world_size := Vector2(world.pixel_size)
    return MAP_ORIGIN + Vector2(
        world_position.x / maxf(1.0, world_size.x),
        world_position.y / maxf(1.0, world_size.y)
    ) * MAP_PIXELS


func _position_is_known(world_position: Vector2) -> bool:
    if fog == null:
        return false
    var cell := Vector2i((world_position / float(TILE_SIZE)).floor())
    return fog.is_revealed_cell(cell)


func _marker(world_position: Vector2, color: Color, radius := 1.5) -> void:
    if not _position_is_known(world_position):
        return
    draw_circle(_world_to_map(world_position), radius, color)


func _draw_region_labels() -> void:
    var regions := [
        [Vector2i(32, 8), "GREENWOOD"],
        [Vector2i(53, 32), "HIGHLANDS"],
        [Vector2i(20, 49), "FENLANDS"],
        [Vector2i(32, 32), "HEARTHLAND"]
    ]
    for item in regions:
        var cell: Vector2i = item[0]
        if fog.is_revealed_cell(cell):
            var label_position := MAP_ORIGIN + (Vector2(cell) + Vector2(0.5, 0.5)) * 3.0
            draw_string(font, label_position, String(item[1]), HORIZONTAL_ALIGNMENT_CENTER, 52, 6, Color(1, 1, 1, 0.78))


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
        if not is_instance_valid(building) or not _position_is_known(building.global_position):
            continue
        var color := Color("#c6b49a")
        var radius := 1.5
        if String(building.id) == "keep":
            color = PLAYER_MARKER
            radius = 3.0
        elif String(building.id) == "outpost":
            color = ALLY_MARKER
            radius = 2.2
        draw_circle(_world_to_map(building.global_position), radius, color)


func _draw_campaign_markers() -> void:
    for stronghold in get_tree().get_nodes_in_group("enemy_strongholds"):
        if is_instance_valid(stronghold) and _position_is_known(stronghold.global_position):
            draw_rect(Rect2(_world_to_map(stronghold.global_position) - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), ENEMY_MARKER)


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


func _draw_player_marker() -> void:
    var player = get_tree().get_first_node_in_group("player")
    if player == null:
        return
    var point := _world_to_map(player.global_position)
    draw_circle(point, 3.0, Color("#151515"))
    draw_circle(point, 2.0, PLAYER_MARKER)
    draw_line(point - Vector2(4.0, 0.0), point + Vector2(4.0, 0.0), Color.WHITE, 1.0)
    draw_line(point - Vector2(0.0, 4.0), point + Vector2(0.0, 4.0), Color.WHITE, 1.0)


func _draw_legend() -> void:
    var y := size.y - 14.0
    var items := [
        [PLAYER_TERRITORY, "KITA"],
        [ENEMY_TERRITORY, "MUSUH"],
        [PLAYER_MARKER, "KEEP"],
        [ALLY_MARKER, "PASUKAN"]
    ]
    var x := 8.0
    for item in items:
        draw_rect(Rect2(x, y - 5.0, 5.0, 5.0), item[0])
        draw_string(font, Vector2(x + 8.0, y), String(item[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color("#d4c8b5"))
        x += 76.0
    draw_string(font, Vector2(size.x - 50.0, size.y - 3.0), "TAB / ESC", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color("#9f988d"))
