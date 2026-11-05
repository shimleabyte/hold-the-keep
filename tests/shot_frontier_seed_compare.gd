extends SceneTree
## Renders the complete Frontier map twice in isolated viewports with one seed.
## Run with a real renderer or Xvfb; this is not a headless data-only test.
## Example:
## xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 --script tests/shot_frontier_seed_compare.gd

const VIEWPORT_SIZE := Vector2i(1024, 1024)
const CAMERA_ZOOM := Vector2(0.5, 0.5)
const FRONTIER_SEED := 1337
const MAP_PIXELS := Vector2(128.0 * 16.0, 128.0 * 16.0)
const OUTPUT_DIR := "/tmp/hold-the-keep-rendered-qa"

var _world_map_script: GDScript


func _fail(message: String) -> void:
    push_error("RENDER_QA_FAIL: " + message)
    quit(1)


func _capture_frontier(seed: int, label: String) -> Image:
    print("RENDER_QA_CAPTURE_START ", label, " seed=", seed)
    var world_config = root.get_node_or_null("WorldConfig")
    if world_config == null:
        _fail("WorldConfig autoload is not ready")
        return null
    if not world_config.apply_profile("frontier"):
        _fail("Could not apply Frontier profile")
        return null
    world_config.world_seed = seed

    var container := SubViewportContainer.new()
    container.size = Vector2(VIEWPORT_SIZE)
    container.stretch = true
    root.add_child(container)

    var preview := SubViewport.new()
    preview.size = VIEWPORT_SIZE
    preview.world_2d = World2D.new()
    preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    preview.transparent_bg = false
    container.add_child(preview)

    var world_host := Node2D.new()
    preview.add_child(world_host)

    if _world_map_script == null or not _world_map_script.can_instantiate():
        _fail("WorldMap script did not compile after autoload initialization")
        container.queue_free()
        return null

    var world := _world_map_script.new() as Node2D
    if world == null:
        _fail("Could not instantiate WorldMap")
        container.queue_free()
        return null
    world_host.add_child(world)
    print("RENDER_QA_WORLD_READY ", label,
        " resources=", world.generated_resource_layout.size(),
        " wildlife=", world.generated_wildlife_layout.size(),
        " decorations=", world.generated_decoration_layout.size())

    var camera := Camera2D.new()
    camera.position = MAP_PIXELS * 0.5
    camera.zoom = CAMERA_ZOOM
    camera.position_smoothing_enabled = false
    world_host.add_child(camera)
    camera.make_current()

    # A SubViewportContainer keeps this target visible; process frames update its texture.
    for frame_index in 3:
        await process_frame
        print("RENDER_QA_FRAME ", label, " ", frame_index + 1)
    await RenderingServer.frame_post_draw

    print("RENDER_QA_CAPTURE_TEXTURE ", label)
    var texture := preview.get_texture()
    if texture == null:
        _fail("Frontier preview texture is null")
        container.queue_free()
        return null
    var image := texture.get_image()
    if image == null or image.is_empty():
        _fail("Frontier preview produced an empty image")
        container.queue_free()
        return null
    if image.get_size() != VIEWPORT_SIZE:
        _fail("Render dimensions differ from the required 1024x1024 capture")
        container.queue_free()
        return null

    var sampled_colors: Dictionary = {}
    for y in range(0, VIEWPORT_SIZE.y, 16):
        for x in range(0, VIEWPORT_SIZE.x, 16):
            sampled_colors[image.get_pixel(x, y)] = true
    if sampled_colors.size() <= 8:
        _fail("Captured viewport is blank or has insufficient visual variation")
        container.queue_free()
        return null

    var output_path := "%s/frontier-%d-%s.png" % [OUTPUT_DIR, seed, label]
    var save_error := image.save_png(output_path)
    if save_error != OK:
        _fail("Could not save rendered image: " + output_path)
        container.queue_free()
        return null
    print("RENDER_QA_CAPTURE_SAVED ", label,
        " path=", output_path, " colors=", sampled_colors.size())

    container.queue_free()
    await process_frame
    return image


func _write_difference(first: Image, second: Image, seed: int) -> int:
    var first_bytes := first.get_data()
    var second_bytes := second.get_data()
    if first_bytes.size() != second_bytes.size():
        return -1

    var diff_bytes := PackedByteArray()
    diff_bytes.resize(first_bytes.size())
    var different_pixels := 0
    for index in range(0, first_bytes.size(), 4):
        var pixel_differs := (
            first_bytes[index] != second_bytes[index]
            or first_bytes[index + 1] != second_bytes[index + 1]
            or first_bytes[index + 2] != second_bytes[index + 2]
            or first_bytes[index + 3] != second_bytes[index + 3]
        )
        if pixel_differs:
            diff_bytes[index] = 255
            diff_bytes[index + 1] = 0
            diff_bytes[index + 2] = 255
            diff_bytes[index + 3] = 255
            different_pixels += 1
        else:
            diff_bytes[index] = first_bytes[index]
            diff_bytes[index + 1] = first_bytes[index + 1]
            diff_bytes[index + 2] = first_bytes[index + 2]
            diff_bytes[index + 3] = first_bytes[index + 3]

    var difference := Image.create(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, false, Image.FORMAT_RGBA8)
    difference.set_data(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, false, Image.FORMAT_RGBA8, diff_bytes)
    var diff_path := "%s/frontier-%d-diff.png" % [OUTPUT_DIR, seed]
    var save_error := difference.save_png(diff_path)
    if save_error != OK:
        _fail("Could not save pixel-difference image: " + diff_path)
        return -1
    return different_pixels


func _initialize() -> void:
    print("RENDER_QA_START")
    var dir_error := DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
    if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
        _fail("Could not create rendered QA output directory")
        return

    # WorldMap references project autoloads; compile it only after SceneTree startup.
    await process_frame
    _world_map_script = load("res://scripts/world/world_map.gd") as GDScript
    if _world_map_script == null or not _world_map_script.can_instantiate():
        _fail("WorldMap could not compile with the initialized project autoloads")
        return

    var first := await _capture_frontier(FRONTIER_SEED, "first")
    if first == null:
        return
    print("RENDER_QA_FIRST_COMPLETE")

    var repeated := await _capture_frontier(FRONTIER_SEED, "repeat")
    if repeated == null:
        return
    print("RENDER_QA_REPEAT_COMPLETE")

    if first.get_size() != repeated.get_size():
        _fail("Repeated Frontier captures have different dimensions")
        return

    print("RENDER_QA_COMPARE_START")
    if first.get_data() != repeated.get_data():
        var difference_count := _write_difference(first, repeated, FRONTIER_SEED)
        _fail("Same-seed Frontier renders differ at %d pixels; inspect %s/frontier-%d-diff.png"
            % [difference_count, OUTPUT_DIR, FRONTIER_SEED])
        return

    print("RENDER_QA_DIFFERING_PIXELS 0")
    print("PASS: Frontier render is pixel-identical for seed %d" % FRONTIER_SEED)
    print("Rendered captures: %s/frontier-%d-first.png and %s/frontier-%d-repeat.png" % [
        OUTPUT_DIR, FRONTIER_SEED, OUTPUT_DIR, FRONTIER_SEED
    ])
    quit(0)
