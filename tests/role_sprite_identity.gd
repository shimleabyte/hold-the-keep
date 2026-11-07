extends SceneTree

const SpriteAnim := preload("res://scripts/entities/sprite_anim.gd")
const EnemyVisualScale := preload("res://scripts/entities/enemy_visual_scale.gd")
const DIRECTIONS := 3
const FRAME_WIDTH := 20
const FRAME_HEIGHT := 20
const CIVILIAN_SPRITES: Array[String] = [
    "villager_idle",
    "villager_woodcutter",
    "villager_miner",
    "villager_farmer",
    "villager_builder",
    "villager_hunter",
    "villager_scout",
    "villager_healer",
    "villager_blacksmith",
    "villager_soldier",
]
const CLIP_STARTS: Array[int] = [0, 2, 6, 10, 14, 18, 19]
const CLIP_COUNTS: Array[int] = [2, 4, 4, 4, 4, 1, 3]


func _load_sprite(name: String) -> Image:
    var path := "res://assets/sprites/%s.svg" % name
    var source := FileAccess.get_file_as_string(path)
    assert(not source.is_empty(), "Missing sprite asset: %s" % path)
    var image := Image.new()
    var result: Error = image.load_svg_from_string(source)
    assert(result == OK, "Could not decode sprite sheet: %s" % path)
    assert(image.get_width() == SpriteAnim.FRAMES * FRAME_WIDTH,
        "%s must be a 22-frame, 20px-wide atlas" % name)
    assert(image.get_height() == DIRECTIONS * FRAME_HEIGHT,
        "%s must contain front/back/side rows at 20px each" % name)
    assert(image.get_data().size() > 0, "%s must contain rendered pixels" % name)
    return image


func _assert_clip_motion(image: Image, name: String) -> void:
    for direction in DIRECTIONS:
        for clip_index in CLIP_STARTS.size():
            var count := CLIP_COUNTS[clip_index]
            if count <= 1:
                continue
            var seen: Dictionary = {}
            for frame_offset in count:
                var frame_index := CLIP_STARTS[clip_index] + frame_offset
                var region := image.get_region(Rect2i(
                    frame_index * FRAME_WIDTH,
                    direction * FRAME_HEIGHT,
                    FRAME_WIDTH,
                    FRAME_HEIGHT
                ))
                seen[region.get_data().hex_encode()] = true
            assert(seen.size() == count,
                "%s clip at frame %d repeats frames in direction row %d" % [
                    name, CLIP_STARTS[clip_index], direction
                ])


func _initialize() -> void:
    var player_sprite := Image.new()
    var player_source := FileAccess.get_file_as_string("res://assets/sprites/player.svg")
    assert(player_sprite.load_svg_from_string(player_source) == OK, "Player atlas must decode")
    assert(player_sprite.get_width() / SpriteAnim.PLAYER_FRAMES == 24,
        "The blue-mantled player must retain 24px frame width and its 30-frame sequence")
    assert(player_sprite.get_height() / DIRECTIONS == 28,
        "The blue-mantled player must retain 28px frame height")

    var generator_source := FileAccess.get_file_as_string("res://tools/gen_assets.py")
    assert(generator_source.contains('PROTECTED_AUTHORED_ASSETS = {'),
        "Legacy generator must declare explicit authored asset ownership")
    assert(not generator_source.contains('humanoid_sheet("player"'),
        "Legacy 20x20 renderer must not regenerate the 24x28 player atlas")

    var villager_source := FileAccess.get_file_as_string("res://scripts/entities/villager.gd")
    var unique_sheets: Dictionary = {}
    for sprite_name in CIVILIAN_SPRITES:
        var image := _load_sprite(sprite_name)
        _assert_clip_motion(image, sprite_name)
        var signature := image.get_data().hex_encode()
        assert(not unique_sheets.has(signature),
            "%s reuses another civilian's complete sprite atlas" % sprite_name)
        unique_sheets[signature] = sprite_name

        assert(generator_source.contains('"%s"' % sprite_name),
            "%s must be listed in the hand-authored ownership registry" % sprite_name)
        assert(not generator_source.contains('humanoid_sheet("%s"' % sprite_name),
            "%s must not use the generic humanoid generator" % sprite_name)

        var resource_path := "res://assets/sprites/%s.svg" % sprite_name
        if sprite_name == "villager_idle":
            assert(villager_source.contains('"": preload("%s")' % resource_path),
                "Unassigned civilians must use the authored labourer atlas")
        else:
            var job_name := sprite_name.trim_prefix("villager_")
            assert(villager_source.contains('"%s": preload("%s")' % [job_name, resource_path]),
                "%s must remain connected to its profession texture" % job_name)

    var enemy_source := FileAccess.get_file_as_string("res://scripts/entities/enemy.gd")
    assert(enemy_source.contains('"archer": preload("res://assets/sprites/enemy_archer.svg")'),
        "Ranged enemies must retain their dedicated archer sprite")
    assert(enemy_source.contains('"brute": preload("res://assets/sprites/enemy_brute.svg")'),
        "Brutes must retain their dedicated heavy sprite")
    _load_sprite("enemy_archer")
    _load_sprite("enemy_brute")

    var brute_scale := EnemyVisualScale.from_data({"scale": 1.45})
    var default_scale := EnemyVisualScale.from_data({})
    var king_scale := EnemyVisualScale.from_data({"scale": 1.8})
    assert(brute_scale.is_equal_approx(Vector2.ONE * 1.45),
        "Siege brute scale must be applied to the visual transform")
    assert(king_scale.is_equal_approx(Vector2.ONE * 1.8),
        "Boss scale must be applied to the visual transform")
    assert(default_scale.is_equal_approx(Vector2.ONE),
        "Enemies without a scale override must retain unit visual scale")

    print("PASS: 10 distinct civilian silhouettes, directional animation frames, atlas contracts and authored generator ownership")
    quit(0)
