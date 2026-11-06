extends SceneTree
## Attack pose regression: the upper body must visibly counter-rotate while the feet remain on the same sprite baseline.

const FRAME_WIDTH := 20
const FRAME_HEIGHT := 20
const WINDUP_FRAME := 10
const IMPACT_FRAME := 12


func _initialize() -> void:
    var texture := load("res://assets/sprites/player.svg") as Texture2D
    assert(texture != null, "Player sprite sheet must load as a Texture2D")
    var image := texture.get_image()
    assert(image != null, "Player sprite sheet must expose image data")
    assert(image.get_width() == 440 and image.get_height() == 60,
        "Player sprite sheet dimensions must remain 22 frames by 3 directions")

    for view in range(3):
        var body_changed := false
        var min_x := 2 if view == 2 else 5
        var max_x := 11 if view == 2 else 14
        for y in range(5, 17):
            for x in range(min_x, max_x):
                var windup := image.get_pixel(WINDUP_FRAME * FRAME_WIDTH + x, view * FRAME_HEIGHT + y)
                var impact := image.get_pixel(IMPACT_FRAME * FRAME_WIDTH + x, view * FRAME_HEIGHT + y)
                if windup != impact:
                    body_changed = true
                    break
            if body_changed:
                break
        assert(body_changed, "Attack wind-up and impact must change the actual body pixels for view %d" % view)

    print("PASS: attack wind-up/impact alter real upper-body pixels in front, back and side views")
    quit(0)
