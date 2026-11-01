extends Node2D
## Mode bangun: pilih dengan 1-4, klik kiri pasang (tahan untuk melukis),
## klik kanan batal / bongkar (refund 50%), Esc batal.

const BUILD_RANGE := 120.0
const REFUND_RATE := 0.5
const BUILDING_SCRIPT := preload("res://scripts/entities/building.gd")

var world  # world_map.gd
var player: Node2D
var territory

var active := ""

var _last_painted := Vector2i(-9999, -9999)


func _ready() -> void:
    z_index = 100
    Events.build_request.connect(func(id: String) -> void: _set_active("" if id == active else id))


func _set_active(id: String) -> void:
    active = id
    Events.build_selected.emit(active)
    queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            if active != "":
                _set_active("")
            else:
                Events.menu_requested.emit()
            get_viewport().set_input_as_handled()
            return
        var idx := -1
        if event.keycode == KEY_0:
            idx = 9
        elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
            idx = int(event.keycode) - int(KEY_1)
        var order: Array = Tech.available_buildings()
        if idx >= 0 and idx < order.size():
            var id: String = order[idx]
            _set_active("" if id == active else id)
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
        if active != "":
            _set_active("")
        else:
            demolish_at(_mouse_cell())


func _over_hud() -> bool:
    var hud := get_tree().get_first_node_in_group("hud")
    return hud != null and hud.blocks_mouse(get_viewport().get_mouse_position())


func _process(_delta: float) -> void:
    if active == "":
        return
    queue_redraw()
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not _over_hud():
        var c := _anchor_for(active, get_global_mouse_position())
        if c != _last_painted:
            _last_painted = c
            var err := place(active, c)
            if err != "":
                Events.build_feedback.emit(err)
    else:
        _last_painted = Vector2i(-9999, -9999)


func _mouse_cell() -> Vector2i:
    return Vector2i((get_global_mouse_position() / WorldConfig.tile_size).floor())


func _size_of(id: String) -> Vector2i:
    var s: Array = DataDB.buildings[id]["size"]
    return Vector2i(int(s[0]), int(s[1]))


## Tile kiri-atas footprint supaya bangunan berpusat di kursor.
func _anchor_for(id: String, world_pos: Vector2) -> Vector2i:
    return Vector2i((world_pos / WorldConfig.tile_size - Vector2(_size_of(id)) / 2.0 + Vector2(0.5, 0.5)).floor())


## Mengembalikan "" jika valid, selain itu pesan alasannya.
func check(id: String, c: Vector2i) -> String:
    if not Tech.building_unlocked(id):
        return "Teknologi belum dibuka"
    var size := _size_of(id)
    for y in size.y:
        for x in size.x:
            var cell := c + Vector2i(x, y)
            if not world.is_buildable(cell) and not (id == "bridge" and world.is_bridgeable(cell)):
                return "Tidak bisa dibangun di sini"
            if world.occupied.has(cell):
                return "Terhalang"
    if territory != null and not territory.can_place(id, c, size):
        if id == "outpost":
            return "Pos Terdepan harus terhubung ke wilayah sendiri"
        return "Di luar wilayah. Bangun Pos Terdepan di perbatasan"
    var rect := Rect2(Vector2(c) * WorldConfig.tile_size, Vector2(size) * WorldConfig.tile_size)
    if player != null:
        if rect.grow(6).has_point(player.global_position + Vector2(0, -4)):
            return "Ada pemain di situ"
        if player.global_position.distance_to(rect.get_center()) > BUILD_RANGE:
            return "Terlalu jauh"
    if not Inventory.can_afford(DataDB.cost_of(id)):
        return "Bahan kurang"
    return ""


## Pasang bangunan. Mengembalikan "" jika sukses, atau pesan error.
func place(id: String, c: Vector2i) -> String:
    var err := check(id, c)
    if err != "":
        return err
    Inventory.spend_all(DataDB.cost_of(id))
    place_raw(id, c)
    return ""


## Pasang tanpa cek/biaya (dipakai untuk keep di awal game).
func place_raw(id: String, c: Vector2i) -> Node:
    var b := BUILDING_SCRIPT.new()
    b.setup(DataDB.buildings[id], c)
    b.world = world
    world.entities.add_child(b)
    for cell in b.cells():
        world.occupied[cell] = b
    Events.building_placed.emit(id, c)
    return b


func demolish_at(cell: Vector2i) -> bool:
    var b = world.occupied.get(cell)
    if b == null or not is_instance_valid(b) or not b.has_method("cells") or not b.has_method("demolish"):
        return false
    if b.id == "keep":
        return false
    var cost := DataDB.cost_of(b.id)
    for k in cost:
        Inventory.add(k, int(floor(int(cost[k]) * REFUND_RATE)))
    for c in b.cells():
        world.occupied.erase(c)
    Events.building_removed.emit(b.id, b.cell)
    b.demolish()
    return true


func _draw() -> void:
    if active == "" or _over_hud():
        return
    var c := _anchor_for(active, get_global_mouse_position())
    var size := _size_of(active)
    var ok := check(active, c) == ""
    var col := Color(0.3, 1.0, 0.4, 0.4) if ok else Color(1.0, 0.3, 0.3, 0.4)
    var rect := Rect2(Vector2(c) * WorldConfig.tile_size, Vector2(size) * WorldConfig.tile_size)
    draw_rect(rect, col)
    draw_rect(rect, Color(col, 0.9), false, 1.0)
    var textures: Dictionary = BUILDING_SCRIPT.TEXTURES
    if textures.has(active):
        var tex: Texture2D = textures[active]
        var base := Vector2(rect.position.x + rect.size.x / 2.0, rect.end.y)
        var tint := Color(0.7, 1.0, 0.7, 0.75) if ok else Color(1.0, 0.55, 0.55, 0.75)
        draw_texture(tex, base - Vector2(tex.get_width() / 2.0, tex.get_height()), tint)
