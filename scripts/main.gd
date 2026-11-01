extends Node2D

const WORLD_SCRIPT := preload("res://scripts/world/world_map.gd")
const TERRITORY_SCRIPT := preload("res://scripts/systems/territory.gd")
const ENEMY_KEEP_SCRIPT := preload("res://scripts/entities/enemy_keep.gd")
const CAMPAIGN_SCRIPT := preload("res://scripts/systems/campaign.gd")
const FOG_SCRIPT := preload("res://scripts/systems/fog_of_war.gd")
const PLAYER_SCRIPT := preload("res://scripts/entities/player.gd")
const BUILD_SCRIPT := preload("res://scripts/systems/build_system.gd")
const FLOW_SCRIPT := preload("res://scripts/systems/flow_field.gd")
const NAV_SCRIPT := preload("res://scripts/systems/nav_grid.gd")
const SUPPLY_SCRIPT := preload("res://scripts/systems/supply_network.gd")
const VILLAGE_SCRIPT := preload("res://scripts/systems/village.gd")
const EVENT_SCRIPT := preload("res://scripts/systems/event_manager.gd")
const SPAWNER_SCRIPT := preload("res://scripts/systems/wave_spawner.gd")
const FX_SCRIPT := preload("res://scripts/entities/fx_layer.gd")
const HUD_SCRIPT := preload("res://scripts/ui/hud.gd")
const TECH_PANEL_SCRIPT := preload("res://scripts/ui/tech_panel.gd")
const MENU_SCRIPT := preload("res://scripts/ui/pause_menu.gd")

const NIGHT_TINT := Color(0.45, 0.5, 0.75)
const DIRS4: Array[Vector2i] = [
    Vector2i(1, 0), Vector2i(-1, 0),
    Vector2i(0, 1), Vector2i(0, -1)
]
var world
var territory
var campaign
var enemy_keep
var fog
var campaign_conquered := false
var player
var build
var flow
var spawner
var nav
var supply
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

    campaign = CAMPAIGN_SCRIPT.new()
    add_child(campaign)

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

    supply = SUPPLY_SCRIPT.new()
    supply.world = world
    add_child(supply)

    add_child(HUD_SCRIPT.new())
    add_child(TECH_PANEL_SCRIPT.new())
    add_child(MENU_SCRIPT.new())
    Events.campaign_won.connect(_on_campaign_won)

    # Keep paling akhir, supaya HUD sudah mendengarkan event HP-nya.
    var save := SaveSystem.take_pending()
    if save.is_empty():
        Tech.reset()
        build.place_raw("keep", world.starting_keep_cell())
        campaign.configure_new(WorldConfig.profile_id)
        _spawn_campaign_strongholds()
        # Dua penduduk awal, relative to the configured Keep position.
        var keep_position: Vector2 = world.keep_center_position()
        for i in 2:
            village.spawn_villager(keep_position + Vector2((i * 2 - 1) * 8.0, 10.0))
    else:
        _apply_save(save)

    fog = FOG_SCRIPT.new()
    fog.world = world
    fog.player = player
    world.add_child(fog)
    if not save.is_empty():
        fog.import_state(save.get("fog", {}))


func _on_campaign_won(_day: int) -> void:
    campaign_conquered = true


func set_primary_stronghold(stronghold) -> void:
    enemy_keep = stronghold


func _spawn_campaign_strongholds() -> void:
    for objective in campaign.objectives_in_order():
        var stronghold_id := String(objective["id"])
        var target_region := String(objective.get("region", ""))
        var anchor := _find_enemy_keep_cell(target_region)
        if anchor.x < 0 or anchor.y < 0:
            push_error("Campaign: no reachable stronghold site for %s in %s" % [stronghold_id, target_region])
            continue
        var region := world.region_id(anchor)
        campaign.set_objective_location(stronghold_id, anchor, region)
        var saved: Dictionary = objective.duplicate(true)
        saved["cx"] = anchor.x
        saved["cy"] = anchor.y
        saved["region"] = region
        saved["hp"] = 900
        saved["destroyed"] = false
        _spawn_enemy_keep(saved, true)
    enemy_keep = campaign.current_target_node()


func _enemy_keep_cells(anchor: Vector2i) -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for y in 3:
        for x in 3:
            cells.append(anchor + Vector2i(x, y))
    return cells


func _find_enemy_keep_cell(target_region := "") -> Vector2i:
    nav.rebuild()
    if WorldConfig.profile_id == "frontier":
        return _find_frontier_enemy_keep_cell(target_region)
    var candidates: Array[Dictionary] = []
    var keep_cell: Vector2i = world.starting_keep_cell()
    var keep_center := Vector2(keep_cell) + Vector2(1.5, 1.5)
    var map_size := WorldConfig.map_size
    var min_stronghold_distance := float(map_size) * 0.34375
    for y in range(5, map_size - 5):
        for x in range(5, map_size - 5):
            var anchor := Vector2i(x, y)
            var center := Vector2(anchor) + Vector2(1.5, 1.5)
            var distance := center.distance_to(keep_center)
            if distance < min_stronghold_distance:
                continue
            var clear := true
            for cell in _enemy_keep_cells(anchor):
                if not world.is_buildable(cell) or world.occupied.has(cell):
                    clear = false
                    break
            if clear:
                candidates.append({"cell": anchor, "distance": distance})
    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return float(a["distance"]) > float(b["distance"]))
    var candidate_limit := 160 * maxi(1, int(map_size * map_size / 4096))
    for i in mini(candidates.size(), candidate_limit):
        var anchor: Vector2i = candidates[i]["cell"]
        if not nav.path_adjacent(player.position, _enemy_keep_cells(anchor)).is_empty():
            return anchor
    return Vector2i(-1, -1)


func _find_frontier_enemy_keep_cell(target_region := "") -> Vector2i:
    var start: Vector2i = nav.cell_of(player.global_position)
    var reachable: Dictionary = nav.reachable_cells(start)
    if reachable.is_empty():
        return Vector2i(-1, -1)

    var keep_cell: Vector2i = world.starting_keep_cell()
    var keep_center := Vector2(keep_cell) + Vector2(1.5, 1.5)
    var best_cell := Vector2i(-1, -1)
    var best_distance := -1.0
    var map_size := WorldConfig.map_size

    for y in range(5, map_size - 5):
        for x in range(5, map_size - 5):
            var anchor := Vector2i(x, y)
            var center := Vector2(anchor) + Vector2(1.5, 1.5)
            var distance := center.distance_to(keep_center)
            if distance < float(map_size) * 0.34375 or distance <= best_distance:
                continue
            if not target_region.is_empty() and world.region_id(anchor) != target_region:
                continue

            var accessible := false
            var clear := true
            for cell in _enemy_keep_cells(anchor):
                if not world.is_buildable(cell) or world.occupied.has(cell):
                    clear = false
                    break
                if not target_region.is_empty() and world.region_id(cell) != target_region:
                    clear = false
                    break
                for direction in DIRS4:
                    if reachable.has(cell + direction):
                        accessible = true

            if clear and accessible:
                best_cell = anchor
                best_distance = distance

    return best_cell


func _spawn_enemy_keep(saved: Dictionary = {}, create_garrison := true) -> void:
    if bool(saved.get("destroyed", false)):
        return
    var anchor := Vector2i(int(saved.get("cx", -1)), int(saved.get("cy", -1)))
    var target_region := String(saved.get("region", ""))
    if anchor.x < 0 or anchor.y < 0:
        anchor = _find_enemy_keep_cell(target_region)
    if anchor.x < 0 or anchor.y < 0:
        push_error("Campaign: no reachable site for enemy stronghold %s" % String(saved.get("id", "unknown")))
        return

    var stronghold_id := String(saved.get("id", "classic_enemy_keep"))
    var region := String(saved.get("region", world.region_id(anchor)))
    var faction := String(saved.get("faction", "classic_raiders"))
    var identity := {"id":stronghold_id,"region":region,"faction":faction}
    var stronghold = ENEMY_KEEP_SCRIPT.new()
    stronghold.setup(world, flow, player, anchor, int(saved.get("hp", 900)), identity)
    stronghold.import_state(saved)
    world.entities.add_child(stronghold)
    for cell in stronghold.cells():
        world.occupied[cell] = stronghold
    campaign.register_stronghold(stronghold)
    Events.enemy_stronghold_placed.emit(anchor)
    nav.rebuild()
    flow.rebuild()
    territory.rebuild()
    if create_garrison:
        stronghold.spawn_initial_garrison()
    enemy_keep = campaign.current_target_node()


func add_child_to_world_fx() -> void:
    world.add_child(FX_SCRIPT.new())  # setelah `entities`, jadi tergambar di atas


func _apply_save(d: Dictionary) -> void:
    var inv: Dictionary = {}
    for k in d["inventory"]:
        inv[k] = int(d["inventory"][k])
    Inventory.items = inv
    Tech.import_state(d.get("tech", {}))
    for saved_resource in d.get("resources", []):
        if not (saved_resource is Dictionary):
            continue
        if not saved_resource.has("cx") or not saved_resource.has("cy"):
            continue
        var resource_cell := Vector2i(int(saved_resource["cx"]), int(saved_resource["cy"]))
        var resource_node = world.occupied.get(resource_cell)
        if resource_node != null and is_instance_valid(resource_node) and resource_node.has_method("import_state"):
            if String(saved_resource.get("kind", "")) == String(resource_node.yield_kind):
                resource_node.import_state(saved_resource.get("state", {}))
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

    var save_version := int(d.get("version", 0))
    if save_version >= 8 and d.get("campaign", {}) is Dictionary:
        campaign.import_state(d["campaign"])
        for objective in campaign.objectives_in_order():
            if not bool(objective.get("destroyed", false)):
                _spawn_enemy_keep(objective, false)
        campaign.sync_completion()
    else:
        var stronghold_state: Dictionary = d.get("stronghold", {})
        campaign.configure_legacy(WorldConfig.profile_id, stronghold_state)
        if stronghold_state.is_empty():
            _spawn_enemy_keep()
        elif bool(stronghold_state.get("destroyed", false)):
            campaign.sync_completion()
        else:
            _spawn_enemy_keep(stronghold_state, false)

    var q: Dictionary = d.get("quota", {})
    for j in q:
        village.quota[j] = int(q[j])
    for v in d["villagers"]:
        var n = village.spawn_villager(Vector2(float(v["x"]), float(v["y"])))
        n.set_job(String(v["job"]))
        n.hp = int(v["hp"])
        if int(v["carry"]) > 0:
            n.receive(String(v["kind"]), int(v["carry"]))
        if bool(v.get("expedition", false)) and is_instance_valid(enemy_keep):
            n.start_expedition(enemy_keep)
        elif bool(v.get("recalling", false)):
            n.recall_expedition()

    var pl: Dictionary = d["player"]
    player.position = Vector2(float(pl["x"]), float(pl["y"]))
    player.hp = int(pl["hp"])
    player.import_combat_state(pl.get("combat", {}))
    Events.player_hp_changed.emit(player.hp, player.MAX_HP)

    spawner.import_state(d.get("spawner", {}))
    for e in d["enemies"]:
        spawner.restore_enemy(e)
    village.assign_jobs()
    Events.build_feedback.emit("Game dimuat")


func _process(_delta: float) -> void:
    _tint.color = Color.WHITE.lerp(NIGHT_TINT, GameClock.darkness())
