extends SceneTree

const SpriteAnim := preload("res://scripts/entities/sprite_anim.gd")
const EnemyVisualScale := preload("res://scripts/entities/enemy_visual_scale.gd")
const DIRECTIONS := 3


func _load_sprite(name: String) -> Image:
    var path := "res://assets/sprites/%s.svg" % name
    var source := FileAccess.get_file_as_string(path)
    assert(not source.is_empty(), "Missing sprite asset: %s" % path)
    var image := Image.new()
    var result: Error = image.load_svg_from_string(source)
    assert(result == OK, "Could not decode sprite sheet: %s" % path)
    var expected_frames := SpriteAnim.PLAYER_FRAMES if name == "player" else SpriteAnim.FRAMES
    assert(image.get_width() % expected_frames == 0,
        "%s must preserve its own horizontal animation-frame contract" % name)
    assert(image.get_height() % DIRECTIONS == 0,
        "%s must preserve the three-direction row contract" % name)
    assert(image.get_data().size() > 0, "%s must contain rendered pixels" % name)
    return image


func _assert_distinct(name: String, reference: String) -> void:
    var sprite := _load_sprite(name)
    var original := _load_sprite(reference)
    assert(sprite.get_data() != original.get_data(),
        "%s must not reuse the %s sprite sheet" % [name, reference])


func _initialize() -> void:
    var player_sprite: Image = _load_sprite("player")
    assert(player_sprite.get_width() / SpriteAnim.PLAYER_FRAMES == 30,
        "The hand-authored player atlas must retain its 24px frame width and 30-frame sequence")
    assert(player_sprite.get_height() / DIRECTIONS == 28,
        "The hand-authored player atlas must retain its 28px frame height")
    _assert_distinct("player", "villager_soldier")

    var generator_source := FileAccess.get_file_as_string("res://tools/gen_assets.py")
    assert(generator_source.contains('PROTECTED_AUTHORED_ASSETS = {"player"}'),
        "The legacy asset generator must explicitly protect the hand-authored player atlas")
    assert(not generator_source.contains('humanoid_sheet("player"'),
        "The legacy 20x20 humanoid renderer must not regenerate the 24x28 player atlas")

    _assert_distinct("villager_builder", "villager_miner")
    _assert_distinct("enemy_archer", "enemy_bandit")
    _assert_distinct("enemy_brute", "enemy_soldier")

    var enemy_source := FileAccess.get_file_as_string("res://scripts/entities/enemy.gd")
    var villager_source := FileAccess.get_file_as_string("res://scripts/entities/villager.gd")
    assert(enemy_source.contains('"archer": preload("res://assets/sprites/enemy_archer.svg")'),
        "Ranged enemies must use the dedicated archer silhouette")
    assert(enemy_source.contains('"brute": preload("res://assets/sprites/enemy_brute.svg")'),
        "Siege brutes must use the dedicated heavy silhouette")
    assert(villager_source.contains('"builder": preload("res://assets/sprites/villager_builder.svg")'),
        "Builders must use their dedicated worker silhouette")

    var brute_scale := EnemyVisualScale.from_data({"scale": 1.45})
    var default_scale := EnemyVisualScale.from_data({})
    var king_scale := EnemyVisualScale.from_data({"scale": 1.8})
    assert(brute_scale.is_equal_approx(Vector2.ONE * 1.45),
        "Siege brute scale must be applied to the visual transform")
    assert(king_scale.is_equal_approx(Vector2.ONE * 1.8),
        "Boss scale must be applied to the visual transform")
    assert(default_scale.is_equal_approx(Vector2.ONE),
        "Enemies without a scale override must retain unit visual scale")

    print("PASS: player atlas ownership and dimensions, specialist sprite identity, and data-driven enemy scale")
    quit(0)
