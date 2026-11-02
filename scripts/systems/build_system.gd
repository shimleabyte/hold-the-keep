extends Node2D
## Mode bangun: pilih dengan 1-4, klik kiri pasang (tahan untuk melukis),
## klik kanan batal / bongkar (refund 50%), Esc batal.

const BUILD_RANGE := 120.0
const REFUND_RATE := 0.5
const BUILDING_SCRIPT := preload("res://scripts/entities/building.gd")
const CONSTRUCTION_SITE_SCRIPT := preload("res://scripts/entities/construction_site.gd")

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
    var cost: Dictionary = DataDB.cost_of(id)
    var supply = get_tree().get_first_node_in_group("supply_network")
    var cost_error: String = supply.cost_reason(cost) if supply != null else (
        "" if Inventory.can_afford(cost) else "Bahan kurang di KEEP"
    )
    if cost_error != "":
        return cost_error
    return ""


## Pasang bangunan. Mengembalikan "" jika sukses, atau pesan error.
func place(id: String, c: Vector2i) -> String:
    var err := check(id, c)
    if err != "":
        return err
    var cost: Dictionary = DataDB.cost_of(id)
    var supply = get_tree().get_first_node_in_group("supply_network")
    var source_cell: Vector2i = supply.get_cost_source_cell() if supply != null else Vector2i(-1, -1)
    var paid: bool = supply.pay_cost(cost) if supply != null else Inventory.spend_all(cost)
    if not paid:
        var cost_error: String = supply.cost_reason(cost) if supply != null else "Bahan kurang di KEEP"
        return cost_error if cost_error != "" else "Stok sumber biaya berubah"
    create_construction_site(id, c, source_cell)
    return ""


func create_construction_site(id: String, c: Vector2i, source_cell: Vector2i,
        work_done := 0.0, work_required := -1.0, queue_order := -1) -> Node:
    var site = CONSTRUCTION_SITE_SCRIPT.new()
    site.setup(DataDB.buildings[id], c, source_cell, DataDB.cost_of(id), work_done, work_required)
    site.queue_order = queue_order if queue_order >= 0 else _next_queue_order()
    site.world = world
    site.build_system = self
    world.entities.add_child(site)
    for occupied_cell in site.cells():
        world.occupied[occupied_cell] = site
    Events.building_placed.emit(id, c)
    Events.construction_queue_changed.emit()
    return site


func _next_queue_order() -> int:
    var next_order := 0
    for existing in get_tree().get_nodes_in_group("construction_sites"):
        if is_instance_valid(existing):
            next_order = maxi(next_order, int(existing.queue_order) + 1)
    return next_order


func construction_queue() -> Array:
    var sites: Array = get_tree().get_nodes_in_group("construction_sites")
    sites.sort_custom(func(a, b) -> bool:
        if int(a.queue_order) != int(b.queue_order):
            return int(a.queue_order) < int(b.queue_order)
        if a.cell.y != b.cell.y:
            return a.cell.y < b.cell.y
        return a.cell.x < b.cell.x
    )
    return sites


func move_construction_site(site, direction: int) -> bool:
    if not is_instance_valid(site) or not site.is_in_group("construction_sites") or direction == 0:
        return false
    var sites := construction_queue()
    var current_index := sites.find(site)
    if current_index < 0:
        return false
    var target_index := clampi(current_index + signi(direction), 0, sites.size() - 1)
    if target_index == current_index:
        return false
    var other = sites[target_index]
    var previous_order := int(site.queue_order)
    site.queue_order = int(other.queue_order)
    other.queue_order = previous_order
    _normalize_construction_queue()
    Events.construction_queue_changed.emit()
    return true


func _normalize_construction_queue() -> void:
    var sites := construction_queue()
    for index in sites.size():
        sites[index].queue_order = index


func restore_site(id: String, c: Vector2i, work_done: float, work_required: float,
        source_cell: Vector2i, queue_order := -1) -> Node:
    if not DataDB.buildings.has(id) or id == "keep":
        return null
    var size := _size_of(id)
    for y in size.y:
        for x in size.x:
            var cell := c + Vector2i(x, y)
            if world.occupied.has(cell):
                return null
            if not world.is_buildable(cell) and not (id == "bridge" and world.is_bridgeable(cell)):
                return null
    return create_construction_site(id, c, source_cell, work_done, work_required, queue_order)


func complete_site(site) -> Node:
    if not is_instance_valid(site) or not site.is_in_group("construction_sites"):
        return null
    var id := String(site.id)
    var anchor: Vector2i = site.cell
    site.release_all_workers()
    for occupied_cell in site.cells():
        if world.occupied.get(occupied_cell) == site:
            world.occupied.erase(occupied_cell)
    site.remove_from_group("construction_sites")
    _normalize_construction_queue()
    Events.building_removed.emit(id, anchor)
    site.queue_free()
    Events.construction_queue_changed.emit()
    var completed = place_raw(id, anchor)
    Events.build_feedback.emit("%s selesai dibangun" % String(DataDB.buildings[id].get("name", id)))
    return completed


func cancel_site(site) -> bool:
    if not is_instance_valid(site) or not site.is_in_group("construction_sites"):
        return false
    var id := String(site.id)
    var anchor: Vector2i = site.cell
    var refund: Dictionary = site.refundable_cost()
    var source_cell: Vector2i = site.source_cell
    site.release_all_workers()
    for occupied_cell in site.cells():
        if world.occupied.get(occupied_cell) == site:
            world.occupied.erase(occupied_cell)
    site.remove_from_group("construction_sites")
    _normalize_construction_queue()
    Events.building_removed.emit(id, anchor)
    site.queue_free()
    Events.construction_queue_changed.emit()
    var supply = get_tree().get_first_node_in_group("supply_network")
    if supply != null and supply.has_method("refund_cost_to_source"):
        supply.refund_cost_to_source(source_cell, refund)
    else:
        for kind in refund:
            Inventory.add(String(kind), int(refund[kind]))
    Events.build_feedback.emit("Blueprint dibatalkan; bahan yang belum dipakai dikembalikan")
    return true


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
    if b == null or not is_instance_valid(b) or not b.has_method("cells"):
        return false
    if b.is_in_group("construction_sites"):
        return cancel_site(b)
    if not b.has_method("demolish"):
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
