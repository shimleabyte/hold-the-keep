extends SceneTree
var crops: Array = []
func ticks(n: int) -> void:
    for i in n:
        await physics_frame
var PLAYER = null
func crop(label: String, w := 128, h := 80) -> void:
    await process_frame
    await RenderingServer.frame_post_draw
    var img := root.get_texture().get_image()
    var pc: Vector2 = PLAYER.get_global_transform_with_canvas().origin + Vector2(10, -8)
    var x := clampi(int(pc.x - w / 2.0), 0, 480 - w)
    var y := clampi(int(pc.y - h / 2.0), 0, 270 - h)
    var c := img.get_region(Rect2i(x, y, w, h))
    c.resize(w * 4, h * 4, Image.INTERPOLATE_NEAREST)
    crops.append([label, c])
func nearest(group: String, from: Vector2) -> Node2D:
    var best: Node2D = null
    var bd := 1e9
    for n in get_nodes_in_group(group):
        var d: float = from.distance_to(n.global_position)
        if d < bd: bd = d; best = n
    return best
func _initialize() -> void:
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(5)
    var clock = root.get_node("GameClock"); clock.set_process(false)
    root.get_node("Inventory").add("wood", 100)
    main.build.player = null
    var p = main.player
    PLAYER = p
    p.camera.position_smoothing_enabled = false
    var fx = null
    for c in main.world.get_children():
        if c.get_script() != null and c.get_script().resource_path.ends_with("fx_layer.gd"): fx = c
    print("FX layer found: ", fx != null)
    # 1. tebas + percikan
    p.global_position = Vector2(520, 580)
    await ticks(5)
    main.spawner.restore_enemy({"id": "bandit", "x": 536, "y": 580, "hp": 60})
    for e in get_nodes_in_group("enemies"): e.set_physics_process(false)
    await ticks(2)
    p._atk_cd = 0.0; p._attack()
    await ticks(4); await crop("tebas: aba-aba")
    await ticks(5); await crop("tebas: benturan + percikan")
    await ticks(5); await crop("tebas: lanjut")
    print("FX partikel setelah tebas: ", fx.count())
    for e in get_nodes_in_group("enemies"): e.retreat()
    # 2. tebang pohon
    var tree = nearest("harvestable", Vector2(300, 520))
    for n in get_nodes_in_group("harvestable"):
        if n.yield_kind == "wood": tree = n; break
    p.global_position = tree.global_position + Vector2(0, 10)
    await ticks(8)
    p._cooldown = 0.0; p._try_interact()
    await ticks(10); await crop("tebang pohon")
    # 3. tambang batu
    var rock = null
    for n in get_nodes_in_group("harvestable"):
        if n.yield_kind == "stone": rock = n; break
    p.global_position = rock.global_position + Vector2(0, 10)
    await ticks(8)
    p._cooldown = 0.0; p._try_interact()
    await ticks(10); await crop("tambang batu")
    # 4. lari berdebu
    p.global_position = Vector2(520, 585)
    await ticks(8)
    Input.action_press("sprint"); Input.action_press("move_right")
    await ticks(25); await crop("lari + debu")
    Input.action_release("move_right"); Input.action_release("sprint")
    # 5. bangunan hancur + guncangan
    p.global_position = Vector2(520, 585)
    await ticks(10)
    main.build.place("house", Vector2i(34, 36))
    await ticks(5)
    var house = null
    for n in get_nodes_in_group("buildings"):
        if n.id == "house": house = n
    house.take_damage(9999)
    await ticks(3)
    print("guncangan aktif: offset kamera=", p.camera.offset, " (shake_t=", snappedf(p._shake_t, 0.01), ")")
    await crop("bangunan hancur", 160, 100)
    await ticks(10); await crop("bangunan hancur +10 tick", 160, 100)
    await ticks(25)
    print("setelah reda: offset=", p.camera.offset)
    # susun
    var cols := 3
    var cw: int = crops[0][1].get_width(); var ch: int = crops[0][1].get_height()
    var rows := int(ceil(crops.size() / float(cols)))
    var sheet := Image.create(cols * (cw + 6), rows * (ch + 6), false, Image.FORMAT_RGBA8)
    sheet.fill(Color("#222"))
    for i in crops.size():
        var c: Image = crops[i][1]
        sheet.blit_rect(c, Rect2i(0, 0, c.get_width(), c.get_height()), Vector2i((i % cols) * (cw + 6), (i / cols) * (ch + 6)))
        print("crop ", i, " ", crops[i][0])
    sheet.save_png("/tmp/shots/fx.png")
    quit()
