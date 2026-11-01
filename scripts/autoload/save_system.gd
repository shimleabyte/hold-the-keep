extends Node
## Versioned save/load with rollback backup and resource-node state.

const PATH := "user://save.json"
const TMP := "user://save.tmp"
const BACKUP := "user://save.bak"
const VERSION := 4

var pending: Dictionary = {}


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    Events.day_changed.connect(_on_day_changed)


func has_save() -> bool:
    return FileAccess.file_exists(PATH) or FileAccess.file_exists(BACKUP)


func _on_day_changed(_day: int) -> void:
    if save_current(true):
        Events.build_feedback.emit("Autosave")


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_F5:
            save_current()
        elif event.keycode == KEY_F9:
            request_load()


func _main() -> Node:
    return get_tree().get_first_node_in_group("main")


## Write a complete temporary file before moving the current save to its rollback copy.
func save_current(silent := false) -> bool:
    var main := _main()
    if main == null or not _has_keep():
        if not silent:
            Events.build_feedback.emit("Tidak bisa menyimpan sekarang")
        return false

    var data := collect(main)
    DirAccess.remove_absolute(TMP)
    var file := FileAccess.open(TMP, FileAccess.WRITE)
    if file == null:
        if not silent:
            Events.build_feedback.emit("Gagal menulis save")
        return false

    file.store_string(JSON.stringify(data))
    file.flush()
    var write_error := file.get_error()
    file.close()
    if write_error != OK:
        DirAccess.remove_absolute(TMP)
        if not silent:
            Events.build_feedback.emit("Gagal menulis save")
        return false

    # Only replace the rollback copy with a verified primary save.
    if FileAccess.file_exists(PATH):
        if _read_valid_save(PATH) != null:
            DirAccess.remove_absolute(BACKUP)
            var backup_error := DirAccess.rename_absolute(PATH, BACKUP)
            if backup_error != OK:
                DirAccess.remove_absolute(TMP)
                if not silent:
                    Events.build_feedback.emit("Gagal mengamankan save lama")
                return false
        else:
            DirAccess.remove_absolute(PATH)

    var install_error := DirAccess.rename_absolute(TMP, PATH)
    if install_error != OK:
        if FileAccess.file_exists(BACKUP):
            var restore_error := DirAccess.rename_absolute(BACKUP, PATH)
            if restore_error != OK:
                push_error("Save rollback failed; backup remains at " + BACKUP)
        DirAccess.remove_absolute(TMP)
        if not silent:
            Events.build_feedback.emit("Gagal memasang save baru")
        return false

    if not silent:
        Events.build_feedback.emit("Game disimpan")
    return true


func _has_keep() -> bool:
    for building in get_tree().get_nodes_in_group("buildings"):
        if building.id == "keep":
            return true
    return false


func collect(main: Node) -> Dictionary:
    var buildings: Array = []
    for building in get_tree().get_nodes_in_group("buildings"):
        buildings.append({"id": building.id, "cx": building.cell.x, "cy": building.cell.y, "hp": building.hp})

    var villagers: Array = []
    for villager in get_tree().get_nodes_in_group("villagers"):
        villagers.append({"x": villager.position.x, "y": villager.position.y, "job": villager.job, "hp": villager.hp,
            "carry": villager.carry, "kind": villager.carry_kind, "expedition": villager.is_expeditioning()})

    var enemies: Array = []
    for enemy in get_tree().get_nodes_in_group("enemies"):
        enemies.append({
            "id": enemy.id, "x": enemy.position.x, "y": enemy.position.y, "hp": enemy.hp,
            "garrison": enemy.is_garrison,
            "guard_x": enemy.guard_origin.x,
            "guard_y": enemy.guard_origin.y
        })

    var resources: Array = []
    for cell in main.world.occupied:
        var node = main.world.occupied[cell]
        if is_instance_valid(node) and node.has_method("export_state"):
            resources.append({
                "cx": cell.x,
                "cy": cell.y,
                "kind": node.yield_kind,
                "state": node.export_state()
            })

    var stronghold_state: Dictionary = {}
    if main.campaign_conquered or not is_instance_valid(main.enemy_keep):
        stronghold_state = {"destroyed": true}
    else:
        stronghold_state = main.enemy_keep.export_state()

    return {
        "version": VERSION,
        "stronghold": stronghold_state,
        "fog": main.fog.export_state() if is_instance_valid(main.fog) else {},
        "inventory": Inventory.items,
        "clock": {"t": GameClock.time_of_day, "day": GameClock.day, "night": GameClock.is_night},
        "player": {"x": main.player.position.x, "y": main.player.position.y, "hp": main.player.hp},
        "buildings": buildings,
        "villagers": villagers,
        "enemies": enemies,
        "resources": resources,
        "quota": main.village.quota,
        "spawner": main.spawner.export_state(),
        "tech": Tech.export_state(),
    }


func _valid_save(data: Variant) -> bool:
    if not (data is Dictionary):
        return false
    var version := int(data.get("version", 0))
    if version < 1 or version > VERSION:
        return false

    var inventory = data.get("inventory")
    var clock = data.get("clock")
    var player = data.get("player")
    var buildings = data.get("buildings")
    var villagers = data.get("villagers")
    var enemies = data.get("enemies")
    var quota = data.get("quota", {})
    var spawner = data.get("spawner", {})
    var tech = data.get("tech", {})
    var resources = data.get("resources", [])
    var stronghold = data.get("stronghold", {})
    var fog = data.get("fog", {})
    if not (fog is Dictionary):
        return false
    var explored_cells = fog.get("cells", [])
    if not (explored_cells is Array):
        return false
    for index in explored_cells:
        if int(index) < 0 or int(index) >= 64 * 64:
            return false
    if not (stronghold is Dictionary):
        return false
    if not stronghold.is_empty() and not bool(stronghold.get("destroyed", false)):
        if not stronghold.has("cx") or not stronghold.has("cy") or not stronghold.has("hp"):
            return false
    if not (inventory is Dictionary) or not (clock is Dictionary) or not (player is Dictionary):
        return false
    if not (buildings is Array) or not (villagers is Array) or not (enemies is Array):
        return false
    if not (quota is Dictionary) or not (spawner is Dictionary) or not (tech is Dictionary):
        return false
    if not (resources is Array):
        return false
    if not clock.has("t") or not clock.has("day") or not clock.has("night"):
        return false
    if not player.has("x") or not player.has("y") or not player.has("hp"):
        return false

    for building in buildings:
        if not (building is Dictionary) or not building.has("id") or not building.has("cx") or not building.has("cy") or not building.has("hp"):
            return false
        if not DataDB.buildings.has(String(building["id"])):
            return false
    for villager in villagers:
        if not (villager is Dictionary):
            return false
        for key in ["x", "y", "job", "hp", "carry", "kind"]:
            if not villager.has(key):
                return false
    for enemy in enemies:
        if not (enemy is Dictionary) or not enemy.has("id") or not enemy.has("x") or not enemy.has("y") or not enemy.has("hp"):
            return false
        if not DataDB.enemies.has(String(enemy["id"])):
            return false
        if bool(enemy.get("garrison", false)) and (not enemy.has("guard_x") or not enemy.has("guard_y")):
            return false
    for job in quota:
        if not ["woodcutter", "miner", "farmer", "soldier"].has(String(job)):
            return false
    for resource in resources:
        if not (resource is Dictionary):
            return false
        for key in ["cx", "cy", "kind", "state"]:
            if not resource.has(key):
                return false
        if not ["wood", "stone", "iron"].has(String(resource["kind"])):
            return false
        if not (resource["state"] is Dictionary):
            return false
        if not resource["state"].has("hp") or not resource["state"].has("regrow"):
            return false
    return true


func _read_valid_save(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        return null
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return null
    var json := JSON.new()
    var parse_result := json.parse(file.get_as_text())
    file.close()
    if parse_result != OK or not _valid_save(json.data):
        return null
    return json.data


## Load the primary save, falling back to the last known-good copy when necessary.
func request_load() -> bool:
    var parsed: Variant = null
    for candidate in [PATH, BACKUP]:
        parsed = _read_valid_save(candidate)
        if parsed != null:
            break

    if parsed == null:
        Events.build_feedback.emit("Save rusak atau versi tidak cocok")
        return false

    pending = parsed
    get_tree().paused = false
    get_tree().reload_current_scene()
    return true


func take_pending() -> Dictionary:
    var data := pending
    pending = {}
    return data
