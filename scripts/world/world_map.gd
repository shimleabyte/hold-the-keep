extends Node2D
## Peta 64x64: rumput, kolam (collision), dan pohon yang bisa ditebang.
## Semua visual masih placeholder prosedural; ganti dengan tileset asli nanti.

const TILE := 16
const MAP_SIZE := 64
const TREE_CHANCE := 0.07
const SAFE_RADIUS := 8.0  # area aman di sekitar titik spawn

const TREE_SCRIPT := preload("res://scripts/entities/resource_tree.gd")
const ROCK_SCRIPT := preload("res://scripts/entities/rock.gd")
const ROCK_CHANCE := 0.02
const IRON_SCRIPT := preload("res://scripts/entities/iron_ore.gd")
const IRON_VEINS := 8

const TILES_TEX := preload("res://assets/sprites/tiles.svg")

const T_GRASS := 0
const T_GRASS_ALT := 1
const T_WATER := 2

var map_seed := 1337
var pixel_size := Vector2i(MAP_SIZE * TILE, MAP_SIZE * TILE)
var entities: Node2D
var occupied: Dictionary = {}  # Vector2i -> Node (pohon, batu, bangunan)

var _layer: TileMapLayer


func _ready() -> void:
    _layer = TileMapLayer.new()
    _layer.tile_set = _build_tileset()
    add_child(_layer)

    entities = Node2D.new()
    entities.y_sort_enabled = true
    add_child(entities)

    _generate()
    _spawn_iron()


func is_buildable(cell: Vector2i) -> bool:
    if cell.x < 1 or cell.y < 1 or cell.x > MAP_SIZE - 2 or cell.y > MAP_SIZE - 2:
        return false
    return _layer.get_cell_atlas_coords(cell).x != T_WATER


func spawn_point() -> Vector2:
    # Tepat di bawah keep (keep menempati tile 31-33 x 29-31)
    return Vector2(pixel_size.x / 2.0 + 8.0, pixel_size.y / 2.0 + 48.0)


func _build_tileset() -> TileSet:
    var ts := TileSet.new()
    ts.tile_size = Vector2i(TILE, TILE)
    ts.add_physics_layer()
    ts.set_physics_layer_collision_layer(0, 1)

    var src := TileSetAtlasSource.new()
    src.texture = TILES_TEX
    src.texture_region_size = Vector2i(TILE, TILE)
    ts.add_source(src, 0)
    for i in 3:
        src.create_tile(Vector2i(i, 0))

    # Air = penghalang
    var data := src.get_tile_data(Vector2i(T_WATER, 0), 0)
    data.add_collision_polygon(0)
    var h := TILE / 2.0
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

    var center := Vector2(MAP_SIZE, MAP_SIZE) / 2.0
    for y in MAP_SIZE:
        for x in MAP_SIZE:
            var edge := x == 0 or y == 0 or x == MAP_SIZE - 1 or y == MAP_SIZE - 1
            var safe := Vector2(x, y).distance_to(center) < SAFE_RADIUS
            var water := edge or (not safe and noise.get_noise_2d(x, y) > 0.3)
            var tile := T_WATER
            if not water:
                tile = T_GRASS_ALT if rng.randf() < 0.2 else T_GRASS
            _layer.set_cell(Vector2i(x, y), 0, Vector2i(tile, 0))

            var cell := Vector2i(x, y)
            var foot := Vector2(x * TILE + TILE / 2.0, y * TILE + TILE)
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
    var center := Vector2(MAP_SIZE, MAP_SIZE) / 2.0
    var veins := 0
    var tries := 0
    while veins < IRON_VEINS and tries < 300:
        tries += 1
        var c := Vector2i(rng.randi_range(4, MAP_SIZE - 5), rng.randi_range(4, MAP_SIZE - 5))
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
            ore.position = Vector2(cell.x * TILE + TILE / 2.0, cell.y * TILE + TILE)
            entities.add_child(ore)
            occupied[cell] = ore
            placed += 1
        if placed >= 2:
            veins += 1
