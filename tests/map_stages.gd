extends SceneTree
## Strategic map and campaign-stage regression checks.

func ticks(count: int) -> void:
    for i in range(count):
        await physics_frame


func enemy_entry(pool: Array, enemy_id: String) -> Dictionary:
    for value in pool:
        if String(value.get("id", "")) == enemy_id:
            return value
    return {}


func _initialize() -> void:
    DirAccess.remove_absolute("user://save.json")
    DirAccess.remove_absolute("user://save.tmp")
    DirAccess.remove_absolute("user://save.bak")

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await ticks(4)
    GameClock.set_process(false)

    assert(main.world.region_id(Vector2i(32, 32)) == "HEARTHLAND",
        "The central region must be identified as Hearthland")
    assert(main.world.region_id(Vector2i(32, 8)) == "GREENWOOD",
        "The north region must be Greenwood")
    assert(main.world.region_id(Vector2i(53, 32)) == "HIGHLANDS",
        "The east region must be Highlands")
    assert(main.world.region_id(Vector2i(20, 49)) == "FENLANDS",
        "The southern region must be Fenlands")

    for cell in [Vector2i(32, 32), Vector2i(32, 8), Vector2i(53, 32), Vector2i(20, 49)]:
        var terrain_type := main.world.tile_type_at(cell)
        assert(terrain_type >= 0 and terrain_type <= 5,
            "Every generated map cell must use a registered terrain tile")

    assert(main.spawner.stage_info(1)["id"] == "frontier",
        "Days 1-5 must use the Frontier act")
    assert(main.spawner.stage_info(6)["id"] == "black_march",
        "Days 6-10 must use the Black March act")
    assert(main.spawner.stage_info(11)["id"] == "last_siege",
        "Days 11-15 must use the Last Siege act")

    var act_one := main.spawner._pool_for(5)
    assert(enemy_entry(act_one, "archer").is_empty(),
        "Archers must not appear before their day-six unlock")
    var act_two := main.spawner._pool_for(6)
    assert(int(enemy_entry(act_two, "archer").get("weight", 0)) == 3,
        "Act II must increase archer weight")
    var act_three := main.spawner._pool_for(11)
    assert(int(enemy_entry(act_three, "archer").get("weight", 0)) == 3,
        "Act III must retain increased archer pressure")
    assert(int(enemy_entry(act_three, "brute").get("weight", 0)) == 3,
        "Act III must increase brute pressure")

    var hud = get_first_node_in_group("hud")
    assert(hud != null, "The main scene must create the HUD")
    var map_panel = hud.get("_map_panel")
    assert(map_panel is Control, "The HUD must own a strategic map panel")
    assert(not map_panel.visible, "The strategic map must stay closed during normal play")
    assert(map_panel._position_is_known(main.world.spawn_point()),
        "The strategic map must know the player spawn area")
    assert(not map_panel._position_is_known(Vector2(32, 32)),
        "The strategic map must not reveal distant unexplored ground")

    hud._toggle_map()
    assert(map_panel.visible and hud.get("_map_backdrop").visible,
        "The map control must open the map overlay and backdrop")
    var close_click := InputEventMouseButton.new()
    close_click.button_index = MOUSE_BUTTON_LEFT
    close_click.pressed = true
    close_click.position = Vector2(306, 8)
    map_panel._gui_input(close_click)
    assert(not map_panel.visible,
        "The map close control must dismiss the overlay by mouse")
    hud._toggle_map()
    hud._toggle_jobs()
    assert(not map_panel.visible and hud.get("_jobs_panel").visible,
        "Opening the job drawer must close the map")
    hud._toggle_jobs()
    assert(not hud.get("_jobs_panel").visible,
        "The job drawer must close when toggled again")

    print("PASS: regional terrain, exploration-aware map visibility, three campaign acts and enemy weighting")
    quit()
