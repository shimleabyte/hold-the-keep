extends SceneTree
## Renders the complete Frontier map twice in isolated viewports with one seed.
## Run with a real renderer or Xvfb; this is not a headless data-only test.
## Example:
## xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 --script tests/shot_frontier_seed_compare.gd

const WORLD_MAP_SCRIPT := preload("res://scripts/world/world_map.gd")
const VIEWPORT_SIZE := Vector2i(1024, 1024)
const CAMERA_ZOOM := Vector2(0.5, 0.5)
const FRONTIER_SEED := 1337
const OUTPUT_DIR := "/tmp/hold-the-keep-rendered-qa"


func _capture_frontier(seed: int, label: String) -> Image:
    var world_config = root.get_node("WorldConfig")
    assert(world_config.apply_profile("frontier"),
        "The Frontier profile must be available for rendered generation QA")
    world_config.world_seed = seed

    var container := SubViewportContainer.new()
    container.size = root.get_visible_rect().size
    container.stretch = true
    root.add_child(container)

    var preview := SubViewport.new()
    preview.size = VIEWPORT_SIZE
    preview.own_world_2d = true
    preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    preview.transparent_bg = false
    container.add_child(preview)

    var world_host := Node2D.new()
    preview.add_child(world_host)

    var world := WORLD_MAP_SCRIPT.new() as Node2D
    world_host.add_child(world)

    var camera := Camera2D.new()
    camera.position = Vector2(VIEWPORT_SIZE) * 0.5
    camera.zoom = CAMERA_ZOOM
    camera.position_smoothing_enabled = false
    world_host.add_child(camera)
    camera.make_current()

    # Let TileMapLayer, resource nodes and procedural decorations reach a rendered frame.
    for _frame in 3:
        await process_frame
        await RenderingServer.frame_post_draw

    var image := preview.get_texture().get_image()
    assert(image != null and not image.is_empty(),
        "The Frontier preview viewport must produce a rendered image")
    assert(image.get_size() == VIEWPORT_SIZE,
        "The render must preserve the 1024x1024 full-map capture bounds")

    var sampled_colors: Dictionary = {}
    for y in range(0, VIEWPORT_SIZE.y, 16):
        for x in range(0, VIEWPORT_SIZE.x, 16):
            sampled_colors[image.get_pixel(x, y)] = true
    assert(sampled_colors.size() > 8,
        "The captured viewport must contain varied world pixels, not a blank frame")

    var output_path := "%s/frontier-%d-%s.png" % [OUTPUT_DIR, seed, label]
    var save_error := image.save_png(output_path)
    assert(save_error == OK, "Could not save rendered QA image: %s" % output_path)

    container.queue_free()
    await process_frame
    await RenderingServer.frame_post_draw
    return image


func _write_difference(first: Image, second: Image, seed: int) -> int:
    var difference := Image.create(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, false, Image.FORMAT_RGBA8)
    var different_pixels := 0
    for y in VIEWPORT_SIZE.y:
        for x in VIEWPORT_SIZE.x:
            var a := first.get_pixel(x, y)
            var b := second.get_pixel(x, y)
            if a != b:
                difference.set_pixel(x, y, Color(1.0, 0.0, 1.0, 1.0))
                different_pixels += 1
            else:
                difference.set_pixel(x, y, a)
    var diff_path := "%s/frontier-%d-diff.png" % [OUTPUT_DIR, seed]
    var save_error := difference.save_png(diff_path)
    assert(save_error == OK, "Could not save pixel-difference image: %s" % diff_path)
    return different_pixels


func _initialize() -> void:
    var dir_error := DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
    assert(dir_error == OK or dir_error == ERR_ALREADY_EXISTS,
        "Could not create rendered QA output directory")

    var first := await _capture_frontier(FRONTIER_SEED, "first")
    var repeated := await _capture_frontier(FRONTIER_SEED, "repeat")

    var same_size := first.get_size() == repeated.get_size()
    assert(same_size, "Repeated Frontier captures must have identical dimensions")

    var byte_identical := first.get_data() == repeated.get_data()
    if not byte_identical:
        var difference_count := _write_difference(first, repeated, FRONTIER_SEED)
        push_error("Same-seed Frontier render changed across runs: %d differing pixels. Inspect %s/frontier-%d-diff.png"
            % [difference_count, OUTPUT_DIR, FRONTIER_SEED])
        quit(1)
        return

    print("PASS: Frontier render is pixel-identical for seed %d" % FRONTIER_SEED)
    print("Rendered captures: %s/frontier-%d-first.png and %s/frontier-%d-repeat.png" % [
        OUTPUT_DIR, FRONTIER_SEED, OUTPUT_DIR, FRONTIER_SEED
    ])
    quit(0)
