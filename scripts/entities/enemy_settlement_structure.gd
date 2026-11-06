class_name EnemySettlementStructure
extends Node2D
## Destructible faction-owned settlement building. It is separate from player
## buildings so civilian workplace and supply systems never claim it.

const TEXTURES: Dictionary = {
    "lumber_camp": preload("res://assets/sprites/lumber_camp.svg"),
    "farm": preload("res://assets/sprites/farm.svg"),
    "quarry": preload("res://assets/sprites/quarry.svg"),
    "barracks": preload("res://assets/sprites/barracks.svg"),
    "tower": preload("res://assets/sprites/tower.svg"),
    "forge": preload("res://assets/sprites/forge.svg"),
    "storage": preload("res://assets/sprites/storage.svg")
}
const FOOTPRINTS: Dictionary = {
    "lumber_camp": Vector2i(2, 2),
    "farm": Vector2i(2, 2),
    "quarry": Vector2i(2, 2),
    "barracks": Vector2i(2, 2),
    "tower": Vector2i(1, 1),
    "forge": Vector2i(2, 2),
    "storage": Vector2i(2, 2)
}
const HIT_POINTS: Dictionary = {
    "lumber_camp": 180,
    "farm": 140,
    "quarry": 200,
    "barracks": 260,
    "tower": 320,
    "forge": 240,
    "storage": 190
}

var world: WorldMap
var owner_keep: Node2D
var structure_id: String = ""
var faction_id: String = ""
var cell: Vector2i = Vector2i.ZERO
var size: Vector2i = Vector2i.ONE
var hp: int = 100
var max_hp: int = 100


func setup(world_ref: WorldMap, keep_ref: Node2D, id: String, anchor: Vector2i, saved_hp: int = -1) -> void:
    world = world_ref
    owner_keep = keep_ref
    structure_id = id
    faction_id = String(keep_ref.get("faction_id")) if keep_ref != null else ""
    cell = anchor
    size = FOOTPRINTS.get(id, Vector2i.ONE)
    max_hp = int(HIT_POINTS.get(id, 120))
    hp = max_hp if saved_hp < 0 else clampi(saved_hp, 1, max_hp)
    position = Vector2(
        (cell.x + size.x / 2.0) * WorldConfig.tile_size,
        (cell.y + size.y) * WorldConfig.tile_size
    )


func _ready() -> void:
    add_to_group("enemy_buildings")
    add_to_group("campaign_targets")
    z_index = 3
    queue_redraw()


func cells() -> Array[Vector2i]:
    var out: Array[Vector2i] = []
    for y: int in size.y:
        for x: int in size.x:
            out.append(cell + Vector2i(x, y))
    return out


func take_damage(amount: int) -> void:
    if hp <= 0:
        return
    hp = maxi(0, hp - maxi(1, amount))
    if hp <= 0:
        _die()
        return
    queue_redraw()


func on_keep_destroyed() -> void:
    # The prototype does not capture rival infrastructure yet. Release its footprint
    # and remove it cleanly when the owning stronghold is conquered.
    for occupied_cell: Vector2i in cells():
        if world != null and is_instance_valid(world) and world.occupied.get(occupied_cell) == self:
            world.occupied.erase(occupied_cell)
            Events.resource_occupancy_changed.emit(occupied_cell)
    remove_from_group("campaign_targets")
    remove_from_group("enemy_buildings")
    queue_free()


func _die() -> void:
    for occupied_cell: Vector2i in cells():
        if world != null and is_instance_valid(world) and world.occupied.get(occupied_cell) == self:
            world.occupied.erase(occupied_cell)
            Events.resource_occupancy_changed.emit(occupied_cell)
    remove_from_group("campaign_targets")
    remove_from_group("enemy_buildings")
    if owner_keep != null and is_instance_valid(owner_keep):
        var owner_civilization: RefCounted = owner_keep.get("civilization") as RefCounted
        if owner_civilization != null:
            owner_civilization.call("on_structure_destroyed", self)
    Events.fx_burst.emit("debris", global_position + Vector2(0, -12), Vector2.ZERO, 1.4)
    queue_free()


func _draw() -> void:
    var texture: Texture2D = TEXTURES.get(structure_id) as Texture2D
    var footprint_pixels: Vector2 = Vector2(size) * float(WorldConfig.tile_size)
    if texture != null:
        draw_texture(texture, Vector2(-texture.get_width() / 2.0, -texture.get_height()))
    else:
        draw_rect(Rect2(-footprint_pixels.x / 2.0, -footprint_pixels.y, footprint_pixels.x, footprint_pixels.y), Color("#78664c"))

    if hp < max_hp:
        var bar_width: float = minf(footprint_pixels.x, 42.0)
        var bar_y: float = -float(texture.get_height()) - 5.0 if texture != null else -footprint_pixels.y - 5.0
        draw_rect(Rect2(-bar_width / 2.0, bar_y, bar_width, 4.0), Color(0.02, 0.02, 0.02, 0.85))
        draw_rect(Rect2(-bar_width / 2.0, bar_y, bar_width * float(hp) / float(max_hp), 3.0), Color("#b94f43"))
        draw_rect(Rect2(-bar_width / 2.0, bar_y, bar_width, 4.0), Color("#d0b68b"), false, 0.8)
