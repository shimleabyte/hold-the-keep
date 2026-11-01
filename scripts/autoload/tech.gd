extends Node
## Pohon teknologi (data/techs.json): 3 era (Kayu, Batu, Besi). Satu riset berjalan pada satu waktu;
## bahan dibayar di awal, riset selesai setelah `time` detik game.
##
## Efek berupa data, jadi mudah dikembangkan (mis. teknologi wilayah atau invasi nanti):
##   "mult": {kunci: pengali}   "add": {kunci: tambahan}   "era": n
##   "unlock_building": [id]    "flags": [nama]
## Sistem lain bertanya lewat stat(kunci, nilai_dasar) = dasar * produk_pengali + jumlah_tambahan.
## Kunci yang dipakai: villager.gather_speed, villager.carry, farm.yield, farm.workers, house.capacity,
## <bangunan>.hp, tower.damage, tower.range, soldier.hp, soldier.damage, player.damage.

const ERA_NAMES := ["", "KAYU", "BATU", "BESI"]

var researched: Array = []
var current := ""
var progress := 0.0
var era := 1

var _mult := {}
var _add := {}
var _flags := {}
var _buildings := {}


func reset() -> void:
    researched.clear()
    current = ""
    progress = 0.0
    _recompute()


func is_done(id: String) -> bool:
    return researched.has(id)


## Bendera efek, mis. "iron_mining".
func has_flag(flag: String) -> bool:
    return _flags.has(flag)


func stat(key: String, base: float) -> float:
    return base * float(_mult.get(key, 1.0)) + float(_add.get(key, 0.0))


func building_unlocked(id: String) -> bool:
    if not DataDB.buildings.has(id):
        return false
    return not bool(DataDB.buildings[id].get("locked", false)) or _buildings.has(id)


## Bangunan yang bisa dipasang pemain, urutannya = urutan di buildings.json (hotkey 1..n).
func available_buildings() -> Array:
    var out: Array = []
    for id in DataDB.building_order:
        if building_unlocked(id):
            out.append(id)
    return out


func tech_name(id: String) -> String:
    return String(DataDB.techs[id]["name"]) if DataDB.techs.has(id) else id


func has_building(id: String) -> bool:
    for b in get_tree().get_nodes_in_group("buildings"):
        if b.id == id:
            return true
    return false


func cost_of(id: String) -> Dictionary:
    var out := {}
    var raw: Dictionary = DataDB.techs[id]["cost"]
    for k in raw:
        out[k] = int(raw[k])
    return out


func progress_ratio() -> float:
    if current == "":
        return 0.0
    return clampf(progress / float(DataDB.techs[current]["time"]), 0.0, 1.0)


## "" jika boleh dimulai, selain itu alasannya (teks untuk pemain).
func reason(id: String) -> String:
    if not DataDB.techs.has(id):
        return "Teknologi tidak dikenal"
    var t: Dictionary = DataDB.techs[id]
    if is_done(id):
        return "Sudah diteliti"
    if current != "":
        return "Sedang meneliti " + tech_name(current)
    if era < int(t["era"]):
        return "Butuh ERA " + ERA_NAMES[int(t["era"])]
    for req in t["requires"]:
        if not is_done(req):
            return "Butuh: " + tech_name(req)
    var need_b: String = String(t.get("building", ""))
    if need_b != "" and not has_building(need_b):
        return "Butuh bangunan: " + String(DataDB.buildings[need_b]["name"])
    var cost: Dictionary = cost_of(id)
    var supply = get_tree().get_first_node_in_group("supply_network")
    var cost_error: String = supply.cost_reason(cost) if supply != null else (
        "" if Inventory.can_afford(cost) else "Bahan kurang di KEEP"
    )
    if cost_error != "":
        return cost_error
    return ""


## Teknologi yang syarat urutannya terpenuhi (era, prasyarat) tanpa memeriksa bahan/bangunan.
func prerequisites_met(id: String) -> bool:
    var t: Dictionary = DataDB.techs[id]
    if era < int(t["era"]):
        return false
    for req in t["requires"]:
        if not is_done(req):
            return false
    return true


func start(id: String) -> bool:
    var why := reason(id)
    if why != "":
        Events.build_feedback.emit(why)
        return false
    var cost: Dictionary = cost_of(id)
    var supply = get_tree().get_first_node_in_group("supply_network")
    var paid: bool = supply.pay_cost(cost) if supply != null else Inventory.spend_all(cost)
    if not paid:
        var cost_error: String = supply.cost_reason(cost) if supply != null else "Bahan kurang di KEEP"
        Events.build_feedback.emit(cost_error if cost_error != "" else "Stok sumber biaya berubah")
        return false
    current = id
    progress = 0.0
    Events.tech_started.emit(id)
    Events.build_feedback.emit("Riset dimulai: " + tech_name(id))
    return true


func _process(delta: float) -> void:
    if current == "":
        return
    progress += delta
    if progress >= float(DataDB.techs[current]["time"]):
        _finish()


func _finish() -> void:
    var id := current
    current = ""
    progress = 0.0
    researched.append(id)
    _recompute()
    Events.tech_researched.emit(id)
    Events.event_triggered.emit("Riset selesai", tech_name(id))


func _recompute() -> void:
    _mult.clear()
    _add.clear()
    _flags.clear()
    _buildings.clear()
    era = 1
    for id in researched:
        if not DataDB.techs.has(id):
            continue
        var e: Dictionary = DataDB.techs[id]["effects"]
        for k in e.get("mult", {}):
            _mult[k] = float(_mult.get(k, 1.0)) * float(e["mult"][k])
        for k in e.get("add", {}):
            _add[k] = float(_add.get(k, 0.0)) + float(e["add"][k])
        for f in e.get("flags", []):
            _flags[f] = true
        for b in e.get("unlock_building", []):
            _buildings[b] = true
        era = maxi(era, int(e.get("era", 1)))


func export_state() -> Dictionary:
    return {"done": researched.duplicate(), "current": current, "progress": progress}


func import_state(d: Dictionary) -> void:
    researched.clear()
    for id in d.get("done", []):
        if DataDB.techs.has(id):
            researched.append(String(id))
    current = String(d.get("current", ""))
    if current != "" and not DataDB.techs.has(current):
        current = ""
    progress = float(d.get("progress", 0.0)) if current != "" else 0.0
    _recompute()
    Events.tech_researched.emit("")  # segarkan tampilan dan statistik (id kosong = muat save)
