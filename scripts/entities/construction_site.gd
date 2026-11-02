extends Node2D
## A funded blueprint that becomes a normal Building only after Builder labor completes.
const BuildingScript := preload("res://scripts/entities/building.gd")
const MAX_BUILDERS := 2
const EXTRA_BUILDER_EFFICIENCY := 0.65
var build_system
var world
var id := ""
var cell := Vector2i.ZERO
var size := Vector2i.ONE
var data: Dictionary = {}
var source_cell := Vector2i(-1, -1)
var paid_cost: Dictionary = {}
var work_done := 0.0
var work_required := 8.0
var queue_order := 0
var workers: Array = []
var _active_workers: Dictionary = {}
var _completing := false

func setup(building_data: Dictionary, anchor: Vector2i, paid_from: Vector2i,
        cost: Dictionary, restored_work := 0.0, restored_required := -1.0) -> void:
    data = building_data
    id = String(data.get("id", ""))
    cell = anchor
    size = Vector2i(int(data["size"][0]), int(data["size"][1]))
    source_cell = paid_from
    paid_cost = cost.duplicate(true)
    work_done = maxf(0.0, restored_work)
    work_required = restored_required if restored_required > 0.0 else _default_work_required()
    work_done = minf(work_done, work_required)
    position = Vector2((cell.x + size.x / 2.0) * WorldConfig.tile_size,
        (cell.y + size.y) * WorldConfig.tile_size)
    z_index = 1

func _ready() -> void:
    add_to_group("construction_sites")
    set_process(true)
    queue_redraw()

func _default_work_required() -> float:
    var footprint := maxi(1, size.x * size.y)
    var total_cost := 0
    for amount in paid_cost.values():
        total_cost += int(amount)
    return clampf(4.0 + float(footprint) * 1.25 + float(total_cost) * 0.08, 4.0, 30.0)

func cells() -> Array[Vector2i]:
    var out: Array[Vector2i] = []
    for y in size.y:
        for x in size.x:
            out.append(cell + Vector2i(x, y))
    return out

func is_construction_site() -> bool:
    return not _completing and is_inside_tree()

func can_claim(worker: Node) -> bool:
    _prune_workers()
    return not _completing and is_instance_valid(worker) and (workers.has(worker) or workers.size() < MAX_BUILDERS)

func claim(worker: Node) -> bool:
    if not can_claim(worker):
        return false
    if not workers.has(worker):
        workers.append(worker)
    return true

func worker_arrived(worker: Node) -> void:
    if _completing or not workers.has(worker) or not is_instance_valid(worker):
        return
    _active_workers[worker] = true

func release(worker: Node) -> void:
    workers.erase(worker)
    _active_workers.erase(worker)

func free_slots() -> int:
    _prune_workers()
    return maxi(0, MAX_BUILDERS - workers.size())

func _prune_workers() -> void:
    for index in range(workers.size() - 1, -1, -1):
        var worker = workers[index]
        if not is_instance_valid(worker):
            workers.remove_at(index)
            _active_workers.erase(worker)

func _process(delta: float) -> void:
    if _completing:
        return
    _prune_workers()
    var active_count := 0
    for worker in workers:
        if _active_workers.has(worker):
            active_count += 1
    if active_count <= 0:
        return
    var capped_count := mini(active_count, MAX_BUILDERS)
    var efficiency := 1.0 + EXTRA_BUILDER_EFFICIENCY * float(capped_count - 1)
    work_done = minf(work_required, work_done + delta * efficiency)
    queue_redraw()
    if work_done >= work_required:
        _finish()

func progress_ratio() -> float:
    return clampf(work_done / maxf(0.001, work_required), 0.0, 1.0)

func refundable_cost() -> Dictionary:
    var unconsumed := 1.0 - progress_ratio()
    var refund: Dictionary = {}
    for kind in paid_cost:
        var amount := floori(float(int(paid_cost[kind])) * unconsumed)
        if amount > 0:
            refund[String(kind)] = amount
    return refund

func export_state() -> Dictionary:
    return {"id": id, "cx": cell.x, "cy": cell.y, "work_done": work_done,
        "work_required": work_required, "source_x": source_cell.x, "source_y": source_cell.y,
        "queue_order": queue_order}

func release_all_workers() -> void:
    for worker in workers.duplicate():
        if is_instance_valid(worker) and worker.has_method("on_construction_site_lost"):
            worker.on_construction_site_lost(self)
    workers.clear()
    _active_workers.clear()

func _finish() -> void:
    if _completing:
        return
    _completing = true
    release_all_workers()
    if build_system != null and is_instance_valid(build_system):
        build_system.complete_site(self)

func _draw() -> void:
    var footprint := Vector2(size) * WorldConfig.tile_size
    var rect := Rect2(Vector2(-footprint.x / 2.0, -footprint.y), footprint)
    var texture_height := footprint.y
    if BuildingScript.TEXTURES.has(id):
        var texture: Texture2D = BuildingScript.TEXTURES[id]
        texture_height = float(texture.get_height())
        draw_texture(texture, Vector2(-float(texture.get_width()) / 2.0, -texture_height),
            Color(0.72, 0.86, 0.79, 0.42))
    draw_rect(rect, Color(0.24, 0.34, 0.31, 0.16))
    draw_rect(rect, Color("#d4c18a", 0.92), false, 1.0)
    draw_line(rect.position, rect.end, Color("#d4c18a", 0.55), 1.0)
    draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y),
        Color("#d4c18a", 0.55), 1.0)
    var bar_width := maxf(28.0, footprint.x)
    var bar_y := -texture_height - 8.0
    draw_rect(Rect2(Vector2(-bar_width / 2.0, bar_y), Vector2(bar_width, 3.0)),
        Color(0.05, 0.07, 0.07, 0.85))
    draw_rect(Rect2(Vector2(-bar_width / 2.0, bar_y),
        Vector2(bar_width * progress_ratio(), 3.0)), Color("#d6bc78", 0.95))
