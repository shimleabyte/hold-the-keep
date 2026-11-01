extends Node2D
## Peta 64x64: rumput, kolam (collision), dan pohon yang bisa ditebang.
## Semua visual masih placeholder prosedural; ganti dengan tileset asli nanti.

const TREE_CHANCE := 0.07

const TREE_SCRIPT := preload("res://scripts/entities/resource_tree.gd")
const ROCK_SCRIPT := preload("res://scripts/entities/rock.gd")
const ROCK_CHANCE := 0.02
const IRON_SCRIPT := preload("res://scripts/entities/iron_ore.gd")

const TILES_TEX := preload("res://assets/sprites/tiles.svg")

const T_GRASS := 0
const T_GRASS_ALT := 1
const T_WATER := 2
const T_FOREST := 3
const T_HIGHLAND := 4
const T_MARSH := 5

var map_seed := 1337
var map_size := 64
var tile_size := 16
var safe_radius := 8.0
var pixel_size := Vector2i.ZERO
var entities: Node2D
var occupied: Dictionary = {}  # Vector2i -> Node (pohon, batu, bangunan)

var _layer: TileMapLayer


func _ready() -> void:
    map_size = WorldConfig.map_size
    tile_size = WorldConfig.tile_size
    safe_radius = WorldConfig.safe_radius
    map_seed = WorldConfig.world_seed
    pixel_size = WorldConfig.world_pixel_size()

    _layer = TileMapLayer.new()
    _layer.tile_set = _build_tileset()
    add_child(_layer)

    entities = Node2D.new()
    entities.y_sort_enabled = true
    add_child(entities)

    _generate()
    _spawn_iron()


func is_buildable(cell: Vector2i) -> bool:
    if cell.x < 1 or cell.y < 1 or cell.x > map_size - 2 or cell.y > map_size - 2:
        return false
    return _layer.get_cell_atlas_coords(cell).x != T_WATER


func starting_keep_cell() -> Vector2i:
    return WorldConfig.starting_keep_cell()


func keep_center_position() -> Vector2:
    var cell := starting_keep_cell()
    return Vector2((cell.x + 1.5) * tile_size, (cell.y + 3.0) * tile_size)


func spawn_point() -> Vector2:
    return keep_center_position() + Vector2(0.0, 48.0)

## Stable regional labels used by terrain generation and the strategic map.
func region_id(cell: Vector2i) -> String:
    var offset := Vector2(cell) - Vector2(map_size, map_size) / 2.0
    if offset.length() < 13.0 * float(map_size) / 64.0:
        return "HEARTHLAND"
    if offset.y < -absf(offset.x) * 0.55:
        return "GREENWOOD"
    if offset.x > absf(offset.y) * 0.55:
        return "HIGHLANDS"
    return "FENLANDS"


func region_name_at(cell: Vector2i) -> String:
    return region_id(cell)


## Atlas tile index, exposed read-only for the strategic map.
func tile_type_at(cell: Vector2i) -> int:
    if cell.x < 0 or cell.y < 0 or cell.x >= map_size or cell.y >= map_size:
        return T_WATER
    return _layer.get_cell_atlas_coords(cell).x


func _build_tileset() -> TileSet:
    var ts := TileSet.new()
    ts.tile_size = Vector2i(tile_size, tile_size)
    ts.add_physics_layer()
    ts.set_physics_layer_collision_layer(0, 1)

    var src := TileSetAtlasSource.new()
    src.texture = TILES_TEX
    src.texture_region_size = Vector2i(tile_size, tile_size)
    ts.add_source(src, 0)
    for i in 6:
        src.create_tile(Vector2i(i, 0))

    # Air = penghalang
    var data := src.get_tile_data(Vector2i(T_WATER, 0), 0)
    data.add_collision_polygon(0)
    var h := tile_size / 2.0
    data.set_collision_polygon_points(
        0, 0, PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
    )
    return ts


func _generate() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = map_seed
    var noise := FastNoiseLite.new()
    noise.seed = map_seed
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    noise.frequency = 0.07

    var center := Vector2(map_size, map_size) / 2.0
    for y in map_size:
        for x in map_size:
            var edge := x == 0 or y == 0 or x == map_size - 1 or y == map_size - 1
            var safe := Vector2(x, y).distance_to(center) < safe_radius
            var water := edge or (not safe and noise.get_noise_2d(x, y) > 0.3)
            var tile := T_WATER
            var region := region_id(Vector2i(x, y))
            if not water:
                var variation := rng.randf()
                match region:
                    "GREENWOOD":
                        tile = T_FOREST
                    "HIGHLANDS":
                        tile = T_HIGHLAND
                    "FENLANDS":
                        tile = T_MARSH
                    _:
                        tile = T_GRASS_ALT if variation < 0.2 else T_GRASS
            _layer.set_cell(Vector2i(x, y), 0, Vector2i(tile, 0))

            var cell := Vector2i(x, y)
            var foot := Vector2(x * tile_size + tile_size / 2.0, y * tile_size + tile_size)
            if water:
                continue
            if not safe and rng.randf() < TREE_CHANCE:
                var tree := TREE_SCRIPT.new()
                tree.position = foot
                entities.add_child(tree)
                occupied[cell] = tree
            elif Vector2(x, y).distance_to(center) > 5.5 and rng.randf() < ROCK_CHANCE:
                var rock := ROCK_SCRIPT.new()
                rock.position = foot
                entities.add_child(rock)
                occupied[cell] = rock


## Urat bijih besi: kelompok 3-5 node, jauh dari keep (mendorong pemain menjelajah).
## Memakai RNG terpisah supaya tata letak pohon/batu tidak berubah.
func _spawn_iron() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = map_seed + 99
    var center := Vector2(map_size, map_size) / 2.0
    var veins := 0
    var tries := 0
    while veins < WorldConfig.iron_veins and tries < 300:
        tries += 1
        var c := Vector2i(rng.randi_range(4, map_size - 5), rng.randi_range(4, map_size - 5))
        if Vector2(c).distance_to(center) < 16.0:
            continue
        var want := rng.randi_range(3, 5)
        var placed := 0
        for i in 16:
            if placed >= want:
                break
            var cell := c + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
            if not is_buildable(cell) or occupied.has(cell):
                continue
            var ore := IRON_SCRIPT.new()
            ore.position = Vector2(cell.x * tile_size + tile_size / 2.0, cell.y * tile_size + tile_size)
            entities.add_child(ore)
            occupied[cell] = ore
            placed += 1
        if placed >= 2:
            veins += 1
