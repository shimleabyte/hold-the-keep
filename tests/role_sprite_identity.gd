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
    assert(image.get_width() % SpriteAnim.FRAMES == 0,
        "%s must preserve the 22-frame horizontal animation contract" % name)
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

    print("PASS: builder, archer and brute use distinct animated sprite sheets and data-driven enemy scale")
    quit(0)
