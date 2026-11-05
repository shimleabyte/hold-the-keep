extends SceneTree

const SpriteAnim := preload("res://scripts/entities/sprite_anim.gd")
const EnemyScript := preload("res://scripts/entities/enemy.gd")
const VillagerScript := preload("res://scripts/entities/villager.gd")
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

    var enemy_textures: Dictionary = EnemyScript.TEXTURES
    var villager_textures: Dictionary = VillagerScript.TEXTURES
    assert(enemy_textures["archer"].resource_path.ends_with("enemy_archer.svg"),
        "Ranged enemies must use the dedicated archer silhouette")
    assert(enemy_textures["brute"].resource_path.ends_with("enemy_brute.svg"),
        "Siege brutes must use the dedicated heavy silhouette")
    assert(villager_textures["builder"].resource_path.ends_with("villager_builder.svg"),
        "Builders must use their dedicated worker silhouette")

    var brute_scale := EnemyScript.visual_scale_for({"scale": 1.45})
    var default_scale := EnemyScript.visual_scale_for({})
    assert(brute_scale.is_equal_approx(Vector2.ONE * 1.45),
        "Siege brute scale must be applied to the visual transform")
    assert(default_scale.is_equal_approx(Vector2.ONE),
        "Enemies without a scale override must retain unit visual scale")

    print("PASS: builder, archer and brute use distinct animated sprite sheets and data-driven enemy scale")
    quit(0)
