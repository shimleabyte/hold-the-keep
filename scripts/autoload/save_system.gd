extends Node
## Save/load ke user://save.json. Satu slot: autosave tiap fajar + manual (F5), muat dengan F9.
## Disimpan: inventori, jam, bangunan (HP), penduduk (job, HP, bawaan), musuh, pemain, kuota job.
## Tidak disimpan: status pohon/batu (semua tumbuh lagi saat dimuat).

const PATH := "user://save.json"
const TMP := "user://save.tmp"
const VERSION := 1

var pending: Dictionary = {}


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    Events.day_changed.connect(_on_day_changed)


func has_save() -> bool:
    return FileAccess.file_exists(PATH)


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


## Kembali true jika berhasil. `silent` = tanpa pesan (autosave).
func save_current(silent := false) -> bool:
    var main := _main()
    if main == null or not _has_keep():
        if not silent:
            Events.build_feedback.emit("Tidak bisa menyimpan sekarang")
        return false
    var data := collect(main)
    DirAccess.remove_absolute(TMP)
    var f := FileAccess.open(TMP, FileAccess.WRITE)
    if f == null:
        if not silent:
            Events.build_feedback.emit("Gagal menulis save")
        return false
    f.store_string(JSON.stringify(data))
    f.close()
    if FileAccess.file_exists(PATH):
        DirAccess.remove_absolute(PATH)
    if DirAccess.rename_absolute(TMP, PATH) != OK:
        if not silent:
            Events.build_feedback.emit("Gagal menulis save")
        return false
    if not silent:
        Events.build_feedback.emit("Game disimpan")
    return true


func _has_keep() -> bool:
    for b in get_tree().get_nodes_in_group("buildings"):
        if b.id == "keep":
            return true
    return false


func collect(main: Node) -> Dictionary:
    var blds: Array = []
    for b in get_tree().get_nodes_in_group("buildings"):
        blds.append({"id": b.id, "cx": b.cell.x, "cy": b.cell.y, "hp": b.hp})
    var vils: Array = []
    for v in get_tree().get_nodes_in_group("villagers"):
        vils.append({"x": v.position.x, "y": v.position.y, "job": v.job, "hp": v.hp,
            "carry": v.carry, "kind": v.carry_kind})
    var foes: Array = []
    for e in get_tree().get_nodes_in_group("enemies"):
        foes.append({"id": e.id, "x": e.position.x, "y": e.position.y, "hp": e.hp})
    return {
        "version": VERSION,
        "inventory": Inventory.items,
        "clock": {"t": GameClock.time_of_day, "day": GameClock.day, "night": GameClock.is_night},
        "player": {"x": main.player.position.x, "y": main.player.position.y, "hp": main.player.hp},
        "buildings": blds,
        "villagers": vils,
        "enemies": foes,
        "quota": main.village.quota,
        "spawner": main.spawner.export_state(),
        "tech": Tech.export_state(),
    }


## Muat ulang scene dengan data dari disk. Kembali false jika tidak ada/rusak.
func request_load() -> bool:
    if not has_save():
        Events.build_feedback.emit("Belum ada save")
        return false
    var f := FileAccess.open(PATH, FileAccess.READ)
    var parsed = null
    if f != null:
        var json := JSON.new()
        if json.parse(f.get_as_text()) == OK:
            parsed = json.data
    if not (parsed is Dictionary) or int(parsed.get("version", 0)) != VERSION or not parsed.has("buildings"):
        Events.build_feedback.emit("Save rusak atau versi tidak cocok")
        return false
    pending = parsed
    get_tree().paused = false
    get_tree().reload_current_scene()
    return true


func take_pending() -> Dictionary:
    var d := pending
    pending = {}
    return d
