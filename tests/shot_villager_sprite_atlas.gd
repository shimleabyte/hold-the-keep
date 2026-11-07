extends SceneTree
## Godot-native contact sheet for all hand-authored civilian atlases.
## This validates SVG decoding and gives reviewers the real 22x3 sheets at 1x/3x.

const ROLE_NAMES: Array[String] = [
    "villager_woodcutter",
    "villager_miner",
    "villager_farmer",
    "villager_builder",
    "villager_blacksmith",
    "villager_hunter",
    "villager_scout",
    "villager_healer",
    "villager_soldier",
    "villager_idle",
]
const SHEET_WIDTH := 440
const SHEET_HEIGHT := 60
const OUTPUT_DIR := "/tmp/hold-the-keep-villager-visual-qa"


func _initialize() -> void:
    var dir_error := DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
    if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
        push_error("Could not create villager visual QA output directory")
        quit(1)
        return

    var contact := Image.create(SHEET_WIDTH, SHEET_HEIGHT * ROLE_NAMES.size(), false, Image.FORMAT_RGBA8)
    contact.fill(Color("#171b1d"))

    for index in ROLE_NAMES.size():
        var name := ROLE_NAMES[index]
        var path := "res://assets/sprites/%s.svg" % name
        var source := FileAccess.get_file_as_string(path)
        if source.is_empty():
            push_error("Missing authored civilian SVG: " + path)
            quit(1)
            return
        var atlas := Image.new()
        var parse_error := atlas.load_svg_from_string(source)
        if parse_error != OK:
            push_error("Godot could not import civilian SVG: " + name)
            quit(1)
            return
        if atlas.get_width() != SHEET_WIDTH or atlas.get_height() != SHEET_HEIGHT:
            push_error("Wrong civilian atlas dimensions: " + name)
            quit(1)
            return
        contact.blit_rect(
            atlas,
            Rect2i(0, 0, SHEET_WIDTH, SHEET_HEIGHT),
            Vector2i(0, index * SHEET_HEIGHT)
        )

    var one_x_path := "%s/villager-atlases-1x.png" % OUTPUT_DIR
    if contact.save_png(one_x_path) != OK:
        push_error("Could not save 1x civilian atlas contact sheet")
        quit(1)
        return

    contact.resize(SHEET_WIDTH * 3, SHEET_HEIGHT * ROLE_NAMES.size() * 3, Image.INTERPOLATE_NEAREST)
    var three_x_path := "%s/villager-atlases-3x.png" % OUTPUT_DIR
    if contact.save_png(three_x_path) != OK:
        push_error("Could not save 3x civilian atlas contact sheet")
        quit(1)
        return

    print("VILLAGER_ATLAS_CONTACT_1X ", one_x_path)
    print("VILLAGER_ATLAS_CONTACT_3X ", three_x_path)
    print("PASS: all ten civilian atlases imported into Godot 4.7")
    quit(0)
