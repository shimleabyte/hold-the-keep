extends Node
## Penduduk: kapasitas (keep + rumah), spawn, upkeep makanan, dan kuota job.
## T/M/K/R = tambah penebang/penambang/petani(kebun)/prajurit, Shift = kurangi. Juga bisa diklik di HUD.

const VILLAGER_SCRIPT := preload("res://scripts/entities/villager.gd")

const SPAWN_INTERVAL := 12.0
const SPAWN_FOOD := 8
const UPKEEP := 2  # makanan per penduduk per hari
const MAX_QUOTA := 20
const JOBS := ["woodcutter", "miner", "farmer", "soldier"]
const KEY_TO_JOB := {KEY_T: "woodcutter", KEY_M: "miner", KEY_K: "farmer", KEY_R: "soldier"}

var world
var nav
var quota := {"woodcutter": 1, "miner": 0, "farmer": 0, "soldier": 0}

var _spawn_t := 0.0
var _assign_t := 0.0


func _ready() -> void:
    add_to_group("village")
    Events.day_changed.connect(_on_day_changed)
    Events.job_quota_request.connect(adjust_quota)
    Events.campaign_objective_completed.connect(_on_campaign_objective_completed)


func villagers() -> Array:
    return get_tree().get_nodes_in_group("villagers")


func population() -> int:
    return villagers().size()


func capacity() -> int:
    var total := 0
    for b in get_tree().get_nodes_in_group("buildings"):
        total += int(b.data.get("capacity", 0))
        if b.id == "house":
            total += roundi(Tech.stat("house.capacity", 0.0))
    return total


func count_job(j: String) -> int:
    var n := 0
    for v in villagers():
        if v.job == j:
            n += 1
    return n


func spawn_villager(pos: Vector2) -> Node:
    var v := VILLAGER_SCRIPT.new()
    v.nav = nav
    v.world = world
    v.position = pos
    world.entities.add_child(v)
    return v


func _keep():
    for b in get_tree().get_nodes_in_group("depots"):
        if b.id == "keep":
            return b
    return null


func spawn_position() -> Vector2:
    var keep = _keep()
    if keep == null:
        return Vector2.ZERO
    return keep.position + Vector2(randf_range(-10.0, 10.0), 10.0)


func try_spawn() -> bool:
    var pop := population()
    if pop >= capacity() or GameClock.is_night or _keep() == null:
        return false
    if Inventory.get_amount("food") < SPAWN_FOOD + UPKEEP * (pop + 1):
        return false
    Inventory.spend("food", SPAWN_FOOD)
    spawn_villager(spawn_position())
    Events.build_feedback.emit("Penduduk baru bergabung")
    return true


func _process(delta: float) -> void:
    _spawn_t += delta
    if _spawn_t >= SPAWN_INTERVAL:
        _spawn_t = 0.0
        try_spawn()
    _assign_t += delta
    if _assign_t >= 1.0:
        _assign_t = 0.0
        assign_jobs()


func assign_jobs() -> void:
    var vs := villagers()
    # Kurangi kelebihan
    for j in JOBS:
        var members: Array = vs.filter(func(v) -> bool: return v.job == j)
        while members.size() > int(quota[j]):
            members.pop_back().set_job("")
    # Isi dari yang menganggur
    for v in vs:
        if v.job != "":
            continue
        for j in JOBS:
            if count_job(j) < int(quota[j]):
                v.set_job(j)
                break
    _emit()


func _emit() -> void:
    var assigned := {}
    for j in JOBS:
        assigned[j] = count_job(j)
    Events.village_changed.emit(population(), capacity(), quota.duplicate(), assigned)


func adjust_quota(job: String, delta: int) -> void:
    if not quota.has(job):
        return
    quota[job] = clampi(int(quota[job]) + delta, 0, MAX_QUOTA)
    assign_jobs()


func command_expedition() -> void:
    var main = get_tree().get_first_node_in_group("main")
    var stronghold = main.campaign.current_target_node() if main != null and main.campaign != null else null
    if stronghold == null or not is_instance_valid(stronghold):
        Events.build_feedback.emit("Benteng lawan sudah tidak ada")
        return
    var fog = get_tree().get_first_node_in_group("fog_of_war")
    if fog != null and not fog.is_revealed_cell(stronghold.cell):
        Events.build_feedback.emit("Jelajahi wilayah lawan sebelum mengirim ekspedisi")
        return

    var soldiers: Array = []
    var should_recall := false
    for villager in villagers():
        if villager.job == "soldier":
            soldiers.append(villager)
            should_recall = should_recall or villager.is_expeditioning()
    if soldiers.is_empty():
        Events.build_feedback.emit("Tetapkan kuota prajurit terlebih dahulu")
        return
    if should_recall:
        for soldier in soldiers:
            soldier.recall_expedition()
        Events.build_feedback.emit("Ekspedisi ditarik. Prajurit kembali bertahan")
        return

    var sent := 0
    for soldier in soldiers:
        if soldier.start_expedition(stronghold):
            sent += 1
    Events.build_feedback.emit("Ekspedisi bergerak: %d prajurit" % sent)


func _on_campaign_objective_completed(_stronghold_id: String, _region_id: String) -> void:
    var main = get_tree().get_first_node_in_group("main")
    if main == null or main.campaign == null:
        return
    var next_target = main.campaign.current_target_node()
    if next_target == null:
        return
    for soldier in villagers():
        if soldier.job == "soldier" and soldier.is_expeditioning():
            soldier.start_expedition(next_target)


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_G:
            command_expedition()
            get_viewport().set_input_as_handled()
        elif KEY_TO_JOB.has(event.keycode):
            adjust_quota(KEY_TO_JOB[event.keycode], -1 if event.shift_pressed else 1)


## Dipanggil tiap hari baru: makan. Kekurangan makanan = satu penduduk pergi.
func _on_day_changed(_day: int) -> void:
    var pop := population()
    if pop == 0:
        return
    var need := pop * UPKEEP
    var eaten := mini(need, Inventory.get_amount("food"))
    if eaten > 0:
        Inventory.spend("food", eaten)
    if eaten < need:
        if remove_one():
            Events.build_feedback.emit("Kelaparan! Seorang penduduk pergi")
    _emit()


## Satu penduduk pergi (non-prajurit lebih dulu). Kembali false jika tidak ada.
func remove_one() -> bool:
    var vs := villagers()
    if vs.is_empty():
        return false
    var leaver = null
    for v in vs:
        if v.job != "soldier":
            leaver = v
            break
    if leaver == null:
        leaver = vs[0]
    leaver.leave()
    return true
