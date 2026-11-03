extends Node
## Memuat dan memvalidasi data statis dari res://data/*.json sebelum membuat indeks.

const DATA_SCHEMA_VALIDATOR = preload("res://scripts/autoload/data_schema_validator.gd")

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
var source_data: Dictionary = {}
var validation_errors: Array[String] = []


func _ready() -> void:
	source_data = {
		"buildings": _load_json("res://data/buildings.json"),
		"enemies": _load_json("res://data/enemies.json"),
		"enemy_archetypes": _load_json("res://data/enemy_archetypes.json"),
		"waves": _load_json("res://data/waves.json"),
		"events": _load_json("res://data/events.json"),
		"techs": _load_json("res://data/techs.json"),
		"campaigns": _load_json("res://data/campaigns.json"),
		"factions": _load_json("res://data/factions.json"),
		"frontier_objectives": _load_json("res://data/frontier_objectives.json")
	}

	var validator = DATA_SCHEMA_VALIDATOR.new()
	validation_errors = validator.validate(source_data)
	if not validation_errors.is_empty():
		for issue in validation_errors:
			push_error("DataDB validation: " + issue)
		return

	var building_records: Array = source_data["buildings"]
	for item in building_records:
		buildings[String(item["id"])] = item
		if item.get("buildable", true):
			building_order.append(String(item["id"]))

	var enemy_records: Array = source_data["enemies"]
	for item in enemy_records:
		enemies[String(item["id"])] = item

	var archetype_records: Array = source_data["enemy_archetypes"]
	for item in archetype_records:
		enemy_archetypes[String(item["id"])] = item
		enemies[String(item["id"])] = item

	events = source_data["events"]
	var tech_records: Array = source_data["techs"]
	for item in tech_records:
		techs[String(item["id"])] = item
		tech_order.append(String(item["id"]))

	waves = source_data["waves"]
	campaign_modes = source_data["campaigns"]
	frontier_objectives = source_data["frontier_objectives"]


func _load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataDB: %s tidak ditemukan" % path)
		return null

	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var parse_error = parser.parse(text)
	if parse_error != OK:
		push_error(
			"DataDB: %s JSON parse error at line %d: %s" %
			[path, parser.get_error_line(), parser.get_error_message()]
		)
		return null
	return parser.data


## Cost sebagai Dictionary[String, int] (JSON memberi float).
## Return an empty dictionary for an unknown building instead of indexing a missing key.
func cost_of(id: String) -> Dictionary:
	if not buildings.has(id):
		push_error("DataDB: cost_of received unknown building ID '%s'" % id)
		return {}
	var out: Dictionary = {}
	var raw: Dictionary = buildings[id].get("cost", {})
	for key in raw:
		out[String(key)] = int(raw[key])
	return out
