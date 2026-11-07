extends SceneTree
## Player identity and combat pose regression for the 24x28 top-down atlas.

const FRAME_WIDTH := 24
const FRAME_HEIGHT := 28
const WINDUP_FRAME := 10
const IMPACT_FRAME := 12


func _initialize() -> void:
    var texture := load("res://assets/sprites/player.svg") as Texture2D
    if texture == null:
        _fail("Player sprite sheet must load as a Texture2D")
        return
    var image := texture.get_image()
    if image == null:
        _fail("Player sprite sheet must expose image data")
        return
    if image.get_width() != 1104 or image.get_height() != 84:
        _fail("Player sprite sheet must remain 46 frames by 3 directions at 24x28")
        return

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

        # Test only the boot contact pixels, not the entire bottom row where
        # weapon tips or cape details may legitimately overlap.
        var left_boot := Vector2i(6, 11)
        var right_boot := Vector2i(12 if view == 2 else 13, 17 if view == 2 else 18)
        for x in range(left_boot.x, left_boot.y):
            var windup := image.get_pixel(WINDUP_FRAME * FRAME_WIDTH + x, view * FRAME_HEIGHT + 27)
            var impact := image.get_pixel(IMPACT_FRAME * FRAME_WIDTH + x, view * FRAME_HEIGHT + 27)
            if windup != impact:
                planted_feet_unchanged = false
        for x in range(right_boot.x, right_boot.y):
            var windup := image.get_pixel(WINDUP_FRAME * FRAME_WIDTH + x, view * FRAME_HEIGHT + 27)
            var impact := image.get_pixel(IMPACT_FRAME * FRAME_WIDTH + x, view * FRAME_HEIGHT + 27)
            if windup != impact:
                planted_feet_unchanged = false

        if not upper_body_changed:
            _fail("Attack upper-body pixels did not change for view %d" % view)
            return
        if not planted_feet_unchanged:
            _fail("Attack wind-up and impact moved the boot contact pixels for view %d" % view)
            return

        var previous_attack_frame := WINDUP_FRAME
        for frame in range(WINDUP_FRAME + 1, 16):
            var pose_changed := false
            for y in range(FRAME_HEIGHT - 1):
                for x in range(FRAME_WIDTH):
                    var previous := image.get_pixel(previous_attack_frame * FRAME_WIDTH + x, view * FRAME_HEIGHT + y)
                    var current := image.get_pixel(frame * FRAME_WIDTH + x, view * FRAME_HEIGHT + y)
                    if previous != current:
                        pose_changed = true
                        break
                if pose_changed:
                    break
            if not pose_changed:
                _fail("Adjacent player attack poses %d and %d are identical for view %d" % [previous_attack_frame, frame, view])
                return
            previous_attack_frame = frame

        for frame in range(WINDUP_FRAME, 16):
            for x in range(left_boot.x, left_boot.y):
                var reference_boot := image.get_pixel(WINDUP_FRAME * FRAME_WIDTH + x, view * FRAME_HEIGHT + 27)
                var observed_boot := image.get_pixel(frame * FRAME_WIDTH + x, view * FRAME_HEIGHT + 27)
                if reference_boot != observed_boot:
                    _fail("Player attack moved planted left-boot contact in frame %d for view %d" % [frame, view])
                    return
            for x in range(right_boot.x, right_boot.y):
                var reference_boot := image.get_pixel(WINDUP_FRAME * FRAME_WIDTH + x, view * FRAME_HEIGHT + 27)
                var observed_boot := image.get_pixel(frame * FRAME_WIDTH + x, view * FRAME_HEIGHT + 27)
                if reference_boot != observed_boot:
                    _fail("Player attack moved planted right-boot contact in frame %d for view %d" % [frame, view])
                    return

        var previous_cleave_frame := 24
        for frame in range(25, 30):
            var pose_changed := false
            for y in range(FRAME_HEIGHT - 1):
                for x in range(FRAME_WIDTH):
                    var previous := image.get_pixel(previous_cleave_frame * FRAME_WIDTH + x, view * FRAME_HEIGHT + y)
                    var current := image.get_pixel(frame * FRAME_WIDTH + x, view * FRAME_HEIGHT + y)
                    if previous != current:
                        pose_changed = true
                        break
                if pose_changed:
                    break
            if not pose_changed:
                _fail("Adjacent heavy Cleave poses %d and %d are identical for view %d" % [previous_cleave_frame, frame, view])
                return
            previous_cleave_frame = frame

        for frame in range(24, 30):
            for x in range(left_boot.x, left_boot.y):
                var reference_boot := image.get_pixel(24 * FRAME_WIDTH + x, view * FRAME_HEIGHT + 27)
                var observed_boot := image.get_pixel(frame * FRAME_WIDTH + x, view * FRAME_HEIGHT + 27)
                if reference_boot != observed_boot:
                    _fail("Heavy Cleave moved planted left-boot contact in frame %d for view %d" % [frame, view])
                    return
            for x in range(right_boot.x, right_boot.y):
                var reference_boot := image.get_pixel(24 * FRAME_WIDTH + x, view * FRAME_HEIGHT + 27)
                var observed_boot := image.get_pixel(frame * FRAME_WIDTH + x, view * FRAME_HEIGHT + 27)
                if reference_boot != observed_boot:
                    _fail("Heavy Cleave moved planted right-boot contact in frame %d for view %d" % [frame, view])
                    return

        for frame_range in [
            Vector2i(20, 24), Vector2i(30, 36), Vector2i(36, 42), Vector2i(42, 46)
        ]:
            var previous_frame: int = frame_range.x
            for frame in range(frame_range.x + 1, frame_range.y):
                var changed := false
                for y in range(FRAME_HEIGHT):
                    for x in range(FRAME_WIDTH):
                        var previous := image.get_pixel(previous_frame * FRAME_WIDTH + x, view * FRAME_HEIGHT + y)
                        var current := image.get_pixel(frame * FRAME_WIDTH + x, view * FRAME_HEIGHT + y)
                        if previous != current:
                            changed = true
                            break
                    if changed:
                        break
                if not changed:
                    _fail("Adjacent player action poses %d and %d are identical for view %d" % [previous_frame, frame, view])
                    return
                previous_frame = frame

    var palette_colors := [
        Color("#1c365a"),
        Color("#285080"),
        Color("#929eaf"),
        Color("#c28b32"),
        Color("#252631"),
    ]
    for color in palette_colors:
        var found := false
        for y in range(image.get_height()):
            for x in range(image.get_width()):
                var observed := image.get_pixel(x, y)
                if observed.is_equal_approx(color) or observed.is_equal_approx(color.srgb_to_linear()):
                    found = true
                    break
            if found:
                break
        if not found:
            _fail("Player identity palette color is missing: %s" % color)
            return

    print("PASS: 24x28 player atlas has distinct light/heavy attack poses, tool poses and planted boots")
    quit(0)


func _fail(message: String) -> void:
    push_error(message)
    quit(1)
