extends Node
## Memuat data statis dari res://data/*.json.

var buildings: Dictionary = {}
var building_order: Array = []  # hanya yang bisa dibangun pemain (urutan hotkey)
var enemies: Dictionary = {}
var enemy_archetypes: Dictionary = {}
var waves: Dictionary = {}
var events: Array = []
var techs: Dictionary = {}
var tech_order: Array = []
var campaign_modes: Dictionary = {}
var frontier_objectives: Array = []


func _ready() -> void:
    var b = _load_json("res://data/buildings.json")
    if b is Array:
        for item in b:
            buildings[item["id"]] = item
            if item.get("buildable", true):
                building_order.append(item["id"])
    var e = _load_json("res://data/enemies.json")
    if e is Array:
        for item in e:
            enemies[item["id"]] = item
    var archetype_data = _load_json("res://data/enemy_archetypes.json")
    if archetype_data is Array:
        for item in archetype_data:
            enemy_archetypes[item["id"]] = item
            enemies[item["id"]] = item
    var ev = _load_json("res://data/events.json")
    if ev is Array:
        events = ev
    var t = _load_json("res://data/techs.json")
    if t is Array:
        for item in t:
            techs[item["id"]] = item
            tech_order.append(item["id"])
    var w = _load_json("res://data/waves.json")
    if w is Dictionary:
        waves = w
    var campaign_data = _load_json("res://data/campaigns.json")
    if campaign_data is Dictionary:
        campaign_modes = campaign_data
    var objective_data = _load_json("res://data/frontier_objectives.json")
    if objective_data is Array:
        frontier_objectives = objective_data


func _load_json(path: String) -> Variant:
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        push_error("DataDB: %s tidak ditemukan" % path)
        return null
    var parsed = JSON.parse_string(f.get_as_text())
    if parsed == null:
        push_error("DataDB: %s tidak valid" % path)
    return parsed


## Cost sebagai Dictionary[String, int] (JSON memberi float).
func cost_of(id: String) -> Dictionary:
    var out := {}
    var raw: Dictionary = buildings[id].get("cost", {})
    for k in raw:
        out[k] = int(raw[k])
    return out
