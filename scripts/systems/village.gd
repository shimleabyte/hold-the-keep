extends Node
## Population, labor occupations, military specializations and workplace assignment.
## Named InputMap job actions change quotas; Alt raises priority and Alt + Shift lowers it.

const VILLAGER_SCRIPT := preload("res://scripts/entities/villager.gd")

const SPAWN_INTERVAL := 12.0
const SPAWN_FOOD := 8
const UPKEEP := 2  # makanan per penduduk per hari
const MAX_QUOTA := 20
const JOBS := ["woodcutter", "miner", "farmer", "builder", "hunter", "scout", "healer", "blacksmith", "soldier"]
const JOB_INPUT_ACTIONS := {
    "woodcutter": "job_woodcutter",
    "miner": "job_miner",
    "farmer": "job_farmer",
    "builder": "job_builder",
    "hunter": "job_hunter",
    "scout": "job_scout",
    "healer": "job_healer",
    "blacksmith": "job_blacksmith",
    "soldier": "job_soldier"
}

var world
var nav
var quota := {"woodcutter": 1, "miner": 0, "farmer": 0, "builder": 0, "hunter": 0, "scout": 0, "healer": 0, "blacksmith": 0, "soldier": 0}
var job_priority: Array[String] = ["woodcutter", "miner", "farmer", "builder", "hunter", "scout", "healer", "blacksmith", "soldier"]

var _spawn_t := 0.0
var _assign_t := 0.0


func _ready() -> void:
    add_to_group("village")
    Events.day_changed.connect(_on_day_changed)
    Events.job_quota_request.connect(adjust_quota)
    Events.job_priority_request.connect(adjust_job_priority)
    Events.building_placed.connect(_on_workplace_changed)
    Events.building_removed.connect(_on_workplace_changed)
    Events.building_destroyed.connect(_on_building_destroyed)
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


func food_available() -> int:
    var amount := Inventory.get_amount("food")
    if WorldConfig.is_frontier_profile():
        return amount
    for granary in get_tree().get_nodes_in_group("granaries"):
        if is_instance_valid(granary):
            amount += granary.stockpile_amount("food")
    return amount


func spend_food(amount: int) -> int:
    var remaining := maxi(0, amount)
    var spent := mini(remaining, Inventory.get_amount("food"))
    if spent > 0:
        Inventory.spend("food", spent)
        remaining -= spent
    if remaining > 0 and WorldConfig.profile_id == "classic":
        var granaries: Array = get_tree().get_nodes_in_group("granaries")
        granaries.sort_custom(func(a, b) -> bool:
            if a.cell.y == b.cell.y:
                return a.cell.x < b.cell.x
            return a.cell.y < b.cell.y
        )
        for granary in granaries:
            if remaining <= 0:
                break
            if not is_instance_valid(granary):
                continue
            var amount_here := mini(remaining, granary.stockpile_amount("food"))
            if amount_here > 0 and granary.take_resource("food", amount_here):
                remaining -= amount_here
                spent += amount_here
    return spent


func try_spawn() -> bool:
    var pop := population()
    if pop >= capacity() or GameClock.is_night or _keep() == null:
        return false
    if food_available() < SPAWN_FOOD + UPKEEP * (pop + 1):
        return false
    if spend_food(SPAWN_FOOD) != SPAWN_FOOD:
        return false
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
    var job_counts: Dictionary = {}
    for job_name in JOBS:
        job_counts[job_name] = 0

    # Validate workplaces and count active occupations in the same population pass.
    for villager in vs:
        if villager.job in ["builder", "hunter", "scout", "healer", "blacksmith"] and not villager.has_valid_workplace():
            villager.set_job("")
        if job_counts.has(villager.job):
            job_counts[villager.job] = int(job_counts[villager.job]) + 1

    # Retain the old policy of releasing the last assigned workers when a quota shrinks.
    for job_name in JOBS:
        var excess := int(job_counts[job_name]) - int(quota.get(job_name, 0))
        if excess <= 0:
            continue
        for villager_index in range(vs.size() - 1, -1, -1):
            if excess <= 0:
                break
            var villager = vs[villager_index]
            if villager.job != job_name:
                continue
            villager.set_job("")
            job_counts[job_name] = int(job_counts[job_name]) - 1
            excess -= 1

    # Maintain local counts instead of rescanning the group for every villager/job pair.
    for villager in vs:
        if villager.job != "":
            continue
        for job_name in job_priority:
            if int(job_counts[job_name]) >= int(quota[job_name]):
                continue
            if villager.set_job(job_name):
                job_counts[job_name] = int(job_counts[job_name]) + 1
                break
    _emit(job_counts)


func restore_job_priority(saved: Variant) -> void:
    var restored: Array[String] = []
    if saved is Array:
        for value in saved:
            var job_name := String(value)
            if JOBS.has(job_name) and not restored.has(job_name):
                restored.append(job_name)
    for job_name in JOBS:
        if not restored.has(job_name):
            restored.append(job_name)
    job_priority = restored


func adjust_job_priority(job_name: String, delta: int) -> void:
    var current_index := job_priority.find(job_name)
    if current_index < 0 or delta == 0:
        return
    var next_index := clampi(current_index + delta, 0, job_priority.size() - 1)
    if next_index == current_index:
        return
    job_priority.remove_at(current_index)
    job_priority.insert(next_index, job_name)
    for villager in villagers():
        if villager.job != "soldier":
            villager.set_job("")
    assign_jobs()


func _on_workplace_changed(_id: String, _cell: Vector2i) -> void:
    assign_jobs()


func _on_building_destroyed(_id: String, _cell: Vector2i) -> void:
    assign_jobs()


func _emit(assigned_counts: Dictionary = {}) -> void:
    var assigned := assigned_counts.duplicate()
    if assigned.is_empty():
        for job_name in JOBS:
            assigned[job_name] = count_job(job_name)
    Events.village_changed.emit(population(), capacity(), quota.duplicate(), assigned)


func adjust_quota(job: String, delta: int) -> void:
    if not quota.has(job):
        return
    quota[job] = clampi(int(quota[job]) + delta, 0, MAX_QUOTA)
    assign_jobs()


func assign_nearest_outpost_guard(outpost) -> bool:
    return assign_nearest_garrison_guard(outpost)


func assign_nearest_garrison_guard(garrison) -> bool:
    if not is_instance_valid(garrison) or int(garrison.guard_capacity) <= 0:
        return false
    if garrison.free_guard_slots() <= 0:
        return false

    var best = null
    var best_path_length := INF
    for soldier in villagers():
        if soldier.job != "soldier" or soldier.is_archer() or soldier.is_outpost_guard() or soldier.is_expeditioning() or soldier.is_recalling_expedition():
            continue
        var path: PackedVector2Array = nav.path_adjacent(soldier.position, garrison.cells())
        if path.is_empty() and soldier.position.distance_to(garrison.position) > 45.0:
            continue
        var route_length := float(path.size()) if not path.is_empty() else 0.0
        if route_length < best_path_length:
            best_path_length = route_length
            best = soldier

    if best == null or not best.assign_garrison_guard(garrison):
        return false
    return true


func assign_nearest_archer(archery_range) -> bool:
    if not is_instance_valid(archery_range) or String(archery_range.id) != "archery_range":
        return false
    if archery_range.free_slots("archer") <= 0:
        return false
    var best = null
    var best_path_length := INF
    for soldier in villagers():
        if soldier.job != "soldier" or soldier.is_archer() or soldier.is_outpost_guard() or soldier.is_expeditioning() or soldier.is_recalling_expedition():
            continue
        if soldier.workplace != null:
            continue
        var path: PackedVector2Array = nav.path_adjacent(soldier.position, archery_range.cells())
        if path.is_empty() and soldier.position.distance_to(archery_range.position) > 45.0:
            continue
        var route_length := float(path.size()) if not path.is_empty() else 0.0
        if route_length < best_path_length:
            best_path_length = route_length
            best = soldier
    return best != null and best.set_job("archer", archery_range)


func release_archer(archery_range) -> bool:
    if not is_instance_valid(archery_range) or String(archery_range.id) != "archery_range":
        return false
    for soldier in villagers():
        if soldier.is_archer() and soldier.workplace == archery_range:
            if soldier.is_expeditioning() or soldier.is_recalling_expedition():
                continue
            return soldier.set_job("soldier")
    return false

func release_outpost_guard(outpost) -> bool:
    return release_garrison_guard(outpost)


func release_garrison_guard(garrison) -> bool:
    if not is_instance_valid(garrison) or int(garrison.guard_capacity) <= 0:
        return false
    garrison.guards = garrison.guards.filter(func(guard): return is_instance_valid(guard))
    if garrison.guards.is_empty():
        return false
    var soldier = garrison.guards.back()
    soldier.release_outpost_guard()
    return true


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
    var assigned_guards := 0
    for villager in villagers():
        if villager.job != "soldier":
            continue
        if villager.is_outpost_guard():
            assigned_guards += 1
            continue
        soldiers.append(villager)
        should_recall = should_recall or villager.is_expeditioning()
    if soldiers.is_empty():
        Events.build_feedback.emit("Semua prajurit sedang menjaga Outpost" if assigned_guards > 0 else "Tetapkan kuota prajurit terlebih dahulu")
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
    if not (event is InputEventKey and event.pressed and not event.echo):
        return
    if Input.is_action_just_pressed("command_expedition"):
        command_expedition()
        get_viewport().set_input_as_handled()
        return
    var alt_held := Input.is_action_pressed("modifier_alt")
    var shift_held := Input.is_action_pressed("modifier_shift")
    for job in JOBS:
        var action := String(JOB_INPUT_ACTIONS.get(job, ""))
        if action.is_empty() or not Input.is_action_just_pressed(action):
            continue
        if alt_held:
            adjust_job_priority(job, -1 if shift_held else 1)
        else:
            adjust_quota(job, -1 if shift_held else 1)
        get_viewport().set_input_as_handled()
        return


## Dipanggil tiap hari baru: makan. Kekurangan makanan = satu penduduk pergi.
func _on_day_changed(_day: int) -> void:
    var pop := population()
    if pop == 0:
        return
    var need := pop * UPKEEP
    var eaten := spend_food(need)
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
