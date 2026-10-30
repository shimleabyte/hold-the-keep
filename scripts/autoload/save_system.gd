extends Node
## Versioned save/load with rollback backup and resource-node state.

const PATH := "user://save.json"
const TMP := "user://save.tmp"
const BACKUP := "user://save.bak"
const VERSION := 2

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

    # Preserve the last good save until the new file has been installed.
    if FileAccess.file_exists(PATH):
        DirAccess.remove_absolute(BACKUP)
        var backup_error := DirAccess.rename_absolute(PATH, BACKUP)
        if backup_error != OK:
            DirAccess.remove_absolute(TMP)
            if not silent:
                Events.build_feedback.emit("Gagal mengamankan save lama")
            return false

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
            "carry": villager.carry, "kind": villager.carry_kind})

    var enemies: Array = []
    for enemy in get_tree().get_nodes_in_group("enemies"):
        enemies.append({"id": enemy.id, "x": enemy.position.x, "y": enemy.position.y, "hp": enemy.hp})

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

    return {
        "version": VERSION,
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
    if not (inventory is Dictionary) or not (clock is Dictionary) or not (player is Dictionary):
        return false
    if not (buildings is Array) or not (villagers is Array) or not (enemies is Array):
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
        if not (villager is Dictionary) or not villager.has("x") or not villager.has("y") or not villager.has("job"):
            return false
    for enemy in enemies:
        if not (enemy is Dictionary) or not enemy.has("id") or not enemy.has("x") or not enemy.has("y") or not enemy.has("hp"):
            return false
        if not DataDB.enemies.has(String(enemy["id"])):
            return false
    return true


## Load the primary save, falling back to the last known-good copy when necessary.
func request_load() -> bool:
    var parsed: Variant = null
    for candidate in [PATH, BACKUP]:
        if not FileAccess.file_exists(candidate):
            continue
        var file := FileAccess.open(candidate, FileAccess.READ)
        if file == null:
            continue
        var json := JSON.new()
        var parse_result := json.parse(file.get_as_text())
        file.close()
        if parse_result == OK and _valid_save(json.data):
            parsed = json.data
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
