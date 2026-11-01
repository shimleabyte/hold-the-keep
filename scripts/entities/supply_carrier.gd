extends Node2D
## Visible physical courier for a player-directed depot shipment.

const SpriteAnim := preload("res://scripts/entities/sprite_anim.gd")
const TEXTURE := preload("res://assets/sprites/villager_idle.svg")
const FRAME_W := 20
const FRAME_H := 20
const WALK_SPEED := 42.0

var supply
var nav
var order_id := 0
var destination
var anim := SpriteAnim.new()
var _path := PackedVector2Array()
var _path_index := 0
var _path_version := -1
var _last_facing := Vector2.DOWN


func configure(network, navigation, shipment_id: int, target_depot, start_position: Vector2) -> bool:
    supply = network
    nav = navigation
    order_id = shipment_id
    destination = target_depot
    position = start_position
    return _repath()


func _ready() -> void:
    add_to_group("supply_carriers")
    anim.play("walk")


func _physics_process(delta: float) -> void:
    if supply == null or not is_instance_valid(supply) or destination == null or not is_instance_valid(destination):
        _report_blocked()
        return
    if not supply.shipment_route_available(order_id):
        _report_blocked()
        return
    if nav.version != _path_version and not _repath():
        _report_blocked()
        return
    if _path.is_empty():
        _report_blocked()
        return

    var remaining := WALK_SPEED * delta
    var moved := false
    while remaining > 0.0 and _path_index < _path.size():
        var target: Vector2 = _path[_path_index]
        var offset := target - position
        var distance := offset.length()
        if distance <= 0.001:
            _path_index += 1
            continue
        if distance <= remaining:
            position = target
            remaining -= distance
            _path_index += 1
        else:
            var direction := offset / distance
            position += direction * remaining
            remaining = 0.0
        if offset.length_squared() > 0.001:
            _last_facing = offset
            anim.face(offset)
        moved = true

    if anim.update(delta) or moved:
        queue_redraw()
    if _path_index >= _path.size():
        supply.carrier_completed(order_id, position)
        queue_free()


func _repath() -> bool:
    if nav == null or destination == null or not is_instance_valid(destination):
        return false
    var path: PackedVector2Array = nav.path_adjacent(position, destination.cells())
    if path.is_empty():
        return false
    _path = path
    _path_index = 0
    _path_version = nav.version
    return true


func _report_blocked() -> void:
    if supply != null and is_instance_valid(supply):
        supply.carrier_blocked(order_id, position)
    queue_free()


func _draw() -> void:
    anim.draw(self, TEXTURE, FRAME_W, FRAME_H)
    # Small parcel silhouette stays readable at the game's native pixel scale.
    draw_rect(Rect2(Vector2(5, -12), Vector2(6, 6)), Color("#d7b477"))
    draw_rect(Rect2(Vector2(5, -12), Vector2(6, 6)), Color("#59432c"), false, 1.0)
    draw_line(Vector2(8, -12), Vector2(8, -6), Color("#80603d"), 1.0)
