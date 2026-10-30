extends SceneTree
func _initialize() -> void:
    var names = OS.get_environment("NAMES").split(",")
    var S = int(OS.get_environment("SCALE"))
    var imgs = []
    var W = 0
    var H = 0
    for n in names:
        var img := Image.new()
        img.load_svg_from_string(FileAccess.get_file_as_string("res://assets/sprites/%s.svg" % n), 1.0)
        img.resize(img.get_width() * S, img.get_height() * S, Image.INTERPOLATE_NEAREST)
        imgs.append(img)
        W = maxi(W, img.get_width()); H += img.get_height() + 6
    var sheet := Image.create(W, H, false, Image.FORMAT_RGBA8)
    sheet.fill(Color("#5c9a45"))
    var y := 0
    for img in imgs:
        sheet.blend_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(0, y))
        y += img.get_height() + 6
    sheet.save_png("/tmp/prev.png")
    print("ok ", W, "x", H)
    quit()
