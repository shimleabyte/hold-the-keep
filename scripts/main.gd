extends Node2D

const WORLD_SCRIPT := preload("res://scripts/world/world_map.gd")
const TERRITORY_SCRIPT := preload("res://scripts/systems/territory.gd")
const PLAYER_SCRIPT := preload("res://scripts/entities/player.gd")
const BUILD_SCRIPT := preload("res://scripts/systems/build_system.gd")
const FLOW_SCRIPT := preload("res://scripts/systems/flow_field.gd")
const NAV_SCRIPT := preload("res://scripts/systems/nav_grid.gd")
const VILLAGE_SCRIPT := preload("res://scripts/systems/village.gd")
const EVENT_SCRIPT := preload("res://scripts/systems/event_manager.gd")
const SPAWNER_SCRIPT := preload("res://scripts/systems/wave_spawner.gd")
const FX_SCRIPT := preload("res://scripts/entities/fx_layer.gd")
const HUD_SCRIPT := preload("res://scripts/ui/hud.gd")
const TECH_PANEL_SCRIPT := preload("res://scripts/ui/tech_panel.gd")
const MENU_SCRIPT := preload("res://scripts/ui/pause_menu.gd")

const NIGHT_TINT := Color(0.45, 0.5, 0.75)
const KEEP_CELL := Vector2i(31, 29)

var world
var territory
var player
var build
var flow
var spawner
var nav
var village
var events

var _tint: CanvasModulate


func _ready() -> void:
    add_to_group("main")
    Audio.silence(1000)
    _tint = CanvasModulate.new()
    add_child(_tint)

    world = WORLD_SCRIPT.new()
    add_child(world)

    territory = TERRITORY_SCRIPT.new()
    territory.world = world
    world.add_child(territory)

    add_child_to_world_fx()
    player = PLAYER_SCRIPT.new()
    player.position = world.spawn_point()
    player.spawn_pos = player.position
    world.entities.add_child(player)
    player.set_camera_limits(Rect2i(Vector2i.ZERO, world.pixel_size))

    flow = FLOW_SCRIPT.new()
    flow.world = world
    add_child(flow)

    nav = NAV_SCRIPT.new()
    nav.world = world
    add_child(nav)

    village = VILLAGE_SCRIPT.new()
    village.world = world
    village.nav = nav
    add_child(village)

    events = EVENT_SCRIPT.new()
    events.village = village
    add_child(events)

    spawner = SPAWNER_SCRIPT.new()
    spawner.world = world
    spawner.flow = flow
    spawner.player = player
    add_child(spawner)

    build = BUILD_SCRIPT.new()
    build.world = world
    build.player = player
    build.territory = territory
    add_child(build)

    add_child(HUD_SCRIPT.new())
    add_child(TECH_PANEL_SCRIPT.new())
    add_child(MENU_SCRIPT.new())

    # Keep paling akhir, supaya HUD sudah mendengarkan event HP-nya.
    var save := SaveSystem.take_pending()
    if save.is_empty():
        Tech.reset()
        build.place_raw("keep", KEEP_CELL)
        # Dua penduduk awal
        for i in 2:
            village.spawn_villager(Vector2(520.0 + (i * 2 - 1) * 8.0, 522.0))
    else:
        _apply_save(save)


func add_child_to_world_fx() -> void:
    world.add_child(FX_SCRIPT.new())  # setelah `entities`, jadi tergambar di atas


func _apply_save(d: Dictionary) -> void:
    var inv: Dictionary = {}
    for k in d["inventory"]:
        inv[k] = int(d["inventory"][k])
    Inventory.items = inv
    Tech.import_state(d.get("tech", {}))
    var c: Dictionary = d["clock"]
    GameClock.time_of_day = float(c["t"])
    GameClock.day = int(c["day"])
    GameClock.is_night = bool(c["night"])

    for b in d["buildings"]:
        var node = build.place_raw(b["id"], Vector2i(int(b["cx"]), int(b["cy"])))
        node.hp = int(b["hp"])
        node.queue_redraw()
        if node.id == "keep":
            Events.keep_hp_changed.emit(node.hp, node.max_hp)

    var q: Dictionary = d.get("quota", {})
    for j in q:
        village.quota[j] = int(q[j])
    for v in d["villagers"]:
        var n = village.spawn_villager(Vector2(float(v["x"]), float(v["y"])))
        n.set_job(String(v["job"]))
        n.hp = int(v["hp"])
        if int(v["carry"]) > 0:
            n.receive(String(v["kind"]), int(v["carry"]))

    var pl: Dictionary = d["player"]
    player.position = Vector2(float(pl["x"]), float(pl["y"]))
    player.hp = int(pl["hp"])
    Events.player_hp_changed.emit(player.hp, player.MAX_HP)

    spawner.import_state(d.get("spawner", {}))
    for e in d["enemies"]:
        spawner.restore_enemy(e)
    village.assign_jobs()
    Events.build_feedback.emit("Game dimuat")


func _process(_delta: float) -> void:
    _tint.color = Color.WHITE.lerp(NIGHT_TINT, GameClock.darkness())
