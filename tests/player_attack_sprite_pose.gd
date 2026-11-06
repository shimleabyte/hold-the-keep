extends SceneTree
## Player identity and combat pose regression for the 24x28 top-down atlas.

const FRAME_WIDTH := 24
const FRAME_HEIGHT := 28
const WINDUP_FRAME := 10
const IMPACT_FRAME := 12


func _initialize() -> void:
    var texture := load("res://assets/sprites/player.svg") as Texture2D
    assert(texture != null, "Player sprite sheet must load as a Texture2D")
    var image := texture.get_image()
    assert(image != null, "Player sprite sheet must expose image data")
    assert(image.get_width() == 528 and image.get_height() == 84,
        "Player sprite sheet must remain 22 frames by 3 directions at 24x28")

    for view in range(3):
        var upper_body_changed := false
        var planted_feet_unchanged := true
        for y in range(3, 21):
            for x in range(FRAME_WIDTH):
                var windup := image.get_pixel(WINDUP_FRAME * FRAME_WIDTH + x, view * FRAME_HEIGHT + y)
                var impact := image.get_pixel(IMPACT_FRAME * FRAME_WIDTH + x, view * FRAME_HEIGHT + y)
                if windup != impact:
                    upper_body_changed = true
                    break
            if upper_body_changed:
                break
        for y in range(24, FRAME_HEIGHT):
            for x in range(FRAME_WIDTH):
                var windup := image.get_pixel(WINDUP_FRAME * FRAME_WIDTH + x, view * FRAME_HEIGHT + y)
                var impact := image.get_pixel(IMPACT_FRAME * FRAME_WIDTH + x, view * FRAME_HEIGHT + y)
                if windup != impact:
                    planted_feet_unchanged = false
                    break
            if not planted_feet_unchanged:
                break
        assert(upper_body_changed,
            "Attack wind-up and impact must change upper-body pixels for view %d" % view)
        assert(planted_feet_unchanged,
            "Attack wind-up and impact must preserve the boot baseline for view %d" % view)

    var palette_colors := [
        Color("#1c365a"),
        Color("#285080"),
        Color("#929eaf"),
        Color("#c28b32"),
        Color("#252631"),
    ]
    for color in palette_colors:
        var found := false
        for y in range(FRAME_HEIGHT):
            for x in range(FRAME_WIDTH):
                if image.get_pixel(x, y).is_equal_approx(color):
                    found = true
                    break
            if found:
                break
        assert(found, "Player identity palette color is missing: %s" % color)

    print("PASS: 24x28 player atlas has the new cloak/steel/gold palette, distinct attack poses and planted feet")
    quit(0)
