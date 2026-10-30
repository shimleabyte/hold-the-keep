extends SceneTree

func ticks(n: int) -> void:
    for i in n:
        await physics_frame

func _initialize() -> void:
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(3)
    var inv = root.get_node("Inventory")
    inv.add("wood", 50)
    root.get_node("GameClock").day = 4
    var keep = null
    for n in get_nodes_in_group("buildings"):
        if n.id == "keep": keep = n
    keep.take_damage(99999)
    await ticks(3)
    var hud = null
    for c in main.get_children():
        if c is CanvasLayer and c.get_script().resource_path.ends_with("hud.gd"): hud = c
    print("game over shown: ", hud._over.visible, " paused=", paused, " text=", hud._over_label.text.replace("\n", " | "))
    var ev := InputEventKey.new()
    ev.keycode = KEY_R
    ev.pressed = true
    hud._unhandled_input(ev)
    await ticks(5)
    var keeps := 0
    for n in get_nodes_in_group("buildings"):
        if n.id == "keep": keeps += 1
    print("after R: paused=", paused, " keeps=", keeps, " wood=", inv.get_amount("wood"), " food=", inv.get_amount("food"), " (expected 25, 12) day=", root.get_node("GameClock").day, " (expected 1)")
    quit()
