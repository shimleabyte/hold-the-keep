extends RefCounted
## Validates the static JSON contracts before DataDB indexes them.
## Keep this class deterministic and side-effect free so fixtures can be tested.

const RESOURCE_KEYS: Array[String] = ["food", "wood", "stone", "iron"]
const EFFECT_KEYS: Array[String] = ["food", "wood", "stone", "iron", "villagers", "food_pct"]
const REGIONS: Array[String] = ["GREENWOOD", "HIGHLANDS", "FENLANDS", "ASHEN_MARCH"]
const ENEMY_ROLES: Array[String] = ["melee", "ranged", "siege", "pouncer"]
const OBJECTIVE_TYPES: Array[String] = [
	"discovery", "clear_camp", "rescue", "escort", "clear_ruins", "defend"
]
const SOURCE_KEYS: Array[String] = [
	"buildings", "enemies", "enemy_archetypes", "waves", "events",
	"techs", "campaigns", "factions", "frontier_objectives"
]


func validate(sources: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for source_key in SOURCE_KEYS:
		if not sources.has(source_key):
			errors.append("%s source is missing" % source_key)

	var buildings := _records_by_id(sources.get("buildings"), "buildings", errors)
	var enemies := _records_by_id(sources.get("enemies"), "enemies", errors)
	var archetypes := _records_by_id(
		sources.get("enemy_archetypes"), "enemy_archetypes", errors
	)
	var events := _records_by_id(sources.get("events"), "events", errors)
	var techs := _records_by_id(sources.get("techs"), "techs", errors)
	var factions := _records_by_id(sources.get("factions"), "factions", errors)
	var objectives := _records_by_id(
		sources.get("frontier_objectives"), "frontier_objectives", errors
	)

	var all_enemies: Dictionary = enemies.duplicate()
	for enemy_id in archetypes:
		if all_enemies.has(enemy_id):
			errors.append(
				"enemy_archetypes.%s.id duplicates an ID already defined in enemies" % enemy_id
			)
		else:
			all_enemies[enemy_id] = archetypes[enemy_id]

	_validate_buildings(buildings, errors)
	_validate_enemy_records(enemies, "enemies", errors, false)
	_validate_enemy_records(archetypes, "enemy_archetypes", errors, true)
	_validate_waves(sources.get("waves"), all_enemies, errors)
	_validate_events(events, errors)
	_validate_techs(techs, buildings, errors)
	_validate_campaigns(sources.get("campaigns"), all_enemies, errors)
	var faction_regions := _validate_factions(factions, all_enemies, errors)
	_validate_objectives(objectives, faction_regions, errors)

	return errors


func _records_by_id(value: Variant, source_name: String, errors: Array[String]) -> Dictionary:
	var records: Dictionary = {}
	if not value is Array:
		errors.append("%s must be a JSON array" % source_name)
		return records

	var rows: Array = value
	for index in rows.size():
		var record: Variant = rows[index]
		var row_path := "%s[%d]" % [source_name, index]
		if not record is Dictionary:
			errors.append("%s must be an object" % row_path)
			continue
		if not record.has("id") or not record["id"] is String:
			errors.append("%s.id must be a non-empty string" % row_path)
			continue
		var record_id := String(record["id"]).strip_edges()
		if record_id.is_empty():
			errors.append("%s.id must be a non-empty string" % row_path)
			continue
		if records.has(record_id):
			errors.append("%s.id duplicates '%s'" % [row_path, record_id])
			continue
		records[record_id] = record
	return records


func _validate_buildings(records: Dictionary, errors: Array[String]) -> void:
	for record_id in records:
		var record: Dictionary = records[record_id]
		var path := "buildings.%s" % record_id
		_require_text(record, "name", path, errors)
		_validate_int_field(record, "hp", path, errors, true, 1)
		_validate_size(record, path, errors)
		_validate_amount_map(record.get("cost"), path + ".cost", errors)
		if record.has("repair_cost"):
			_validate_amount_map(record["repair_cost"], path + ".repair_cost", errors)
		_validate_optional_bool(record, "buildable", path, errors)
		_validate_optional_bool(record, "locked", path, errors)
		_validate_optional_bool(record, "depot", path, errors)
		_validate_optional_dictionary(record, "visual", path, errors)
		if record.has("accepted_resources"):
			_validate_string_list(
				record["accepted_resources"], path + ".accepted_resources", errors,
				false, RESOURCE_KEYS
			)
		if record.has("workplaces"):
			var workplaces: Variant = record["workplaces"]
			if not workplaces is Dictionary:
				errors.append("%s.workplaces must be an object" % path)
			else:
				for job_id in workplaces:
					var key := String(job_id)
					if key.strip_edges().is_empty():
						errors.append("%s.workplaces contains an empty job ID" % path)
					_validate_integer_value(
						workplaces[job_id], path + ".workplaces." + key, errors, 1
					)
		for numeric_field in [
			"capacity", "stockpile_capacity", "work_radius", "claim_radius",
			"vision_radius", "range", "damage", "fire_interval", "workers",
			"guard_slots", "guard_radius"
		]:
			_validate_optional_number_field(
				record, numeric_field, path, errors, 0.0, false
			)


func _validate_size(record: Dictionary, path: String, errors: Array[String]) -> void:
	if not record.has("size") or not record["size"] is Array:
		errors.append("%s.size must contain exactly two positive integers" % path)
		return
	var dimensions: Array = record["size"]
	if dimensions.size() != 2:
		errors.append("%s.size must contain exactly two positive integers" % path)
		return
	for axis in dimensions.size():
		_validate_integer_value(dimensions[axis], "%s.size[%d]" % [path, axis], errors, 1)


func _validate_enemy_records(
	records: Dictionary, source_name: String, errors: Array[String], require_archetype: bool
) -> void:
	for record_id in records:
		var record: Dictionary = records[record_id]
		var path := "%s.%s" % [source_name, record_id]
		_require_text(record, "name", path, errors)
		_require_text(record, "role", path, errors)
		if require_archetype:
			_require_text(record, "archetype", path, errors)
		_validate_number_field(record, "hp", path, errors, true, 0.0, false)
		_validate_number_field(record, "speed", path, errors, true, 0.0, false)
		_validate_number_field(record, "damage", path, errors, true, 0.0, true)
		_validate_number_field(record, "attack_interval", path, errors, true, 0.0, false)
		var role := String(record.get("role", ""))
		if not role.is_empty() and not ENEMY_ROLES.has(role):
			errors.append("%s.role has unsupported value '%s'" % [path, role])
		for key in record:
			var value: Variant = record[key]
			if _is_number(value):
				_validate_number_value(value, path + "." + String(key), errors, 0.0, true)
		for bounded_field in ["armor", "stagger_resistance"]:
			if record.has(bounded_field):
				_validate_number_value(
					record[bounded_field], path + "." + bounded_field, errors,
					0.0, true, 1.0
				)


func _validate_waves(value: Variant, enemies: Dictionary, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("waves must be a JSON object")
		return
	var data: Dictionary = value
	_validate_int_field(data, "base", "waves", errors, true, 1)
	_validate_int_field(data, "per_day", "waves", errors, true, 0)
	_validate_int_field(data, "max", "waves", errors, true, 1)
	_validate_int_field(data, "final_day", "waves", errors, true, 1)
	_validate_enemy_reference(data.get("boss"), "waves.boss", enemies, errors)
	_validate_wave_types(data.get("types"), enemies, errors)
	_validate_stage_ranges(data.get("stages"), int(data.get("final_day", 0)), "waves.stages", errors)


func _validate_wave_types(value: Variant, enemies: Dictionary, errors: Array[String]) -> void:
	if not value is Array:
		errors.append("waves.types must be a non-empty array")
		return
	var types: Array = value
	if types.is_empty():
		errors.append("waves.types must be a non-empty array")
		return
	var seen: Dictionary = {}
	for index in types.size():
		var item: Variant = types[index]
		var path := "waves.types[%d]" % index
		if not item is Dictionary:
			errors.append("%s must be an object" % path)
			continue
		var enemy_id := String(item.get("id", ""))
		_validate_enemy_reference(enemy_id, path + ".id", enemies, errors)
		if seen.has(enemy_id):
			errors.append("%s.id duplicates '%s'" % [path, enemy_id])
		seen[enemy_id] = true
		_validate_int_field(item, "from_day", path, errors, true, 1)
		_validate_int_field(item, "weight", path, errors, true, 1)


func _validate_events(records: Dictionary, errors: Array[String]) -> void:
	for record_id in records:
		var record: Dictionary = records[record_id]
		var path := "events.%s" % record_id
		_require_text(record, "name", path, errors)
		_require_text(record, "text", path, errors)
		_validate_int_field(record, "weight", path, errors, true, 1)
		_validate_int_field(record, "from_day", path, errors, true, 1)
		if record.has("requires"):
			_validate_amount_map(record["requires"], path + ".requires", errors)
		if not record.has("effects") or not record["effects"] is Dictionary:
			errors.append("%s.effects must be an object" % path)
		else:
			for effect_key in record["effects"]:
				var key := String(effect_key)
				if not EFFECT_KEYS.has(key):
					errors.append("%s.effects.%s is not a supported effect key" % [path, key])
					continue
				_validate_number_value(
					record["effects"][effect_key], path + ".effects." + key, errors,
					-100.0 if key == "food_pct" else -2147483648.0, true,
					100.0 if key == "food_pct" else -1.0
				)
				if key == "villagers":
					_validate_integer_value(
						record["effects"][effect_key], path + ".effects.villagers", errors,
						-2147483648
					)


func _validate_techs(
	records: Dictionary, buildings: Dictionary, errors: Array[String]
) -> void:
	for record_id in records:
		var record: Dictionary = records[record_id]
		var path := "techs.%s" % record_id
		_require_text(record, "name", path, errors)
		_validate_int_field(record, "era", path, errors, true, 1)
		if record.has("era") and _is_number(record["era"]) and int(record["era"]) > 3:
			errors.append("%s.era must not exceed the current three-era progression" % path)
		_validate_amount_map(record.get("cost"), path + ".cost", errors)
		_validate_number_field(record, "time", path, errors, true, 0.0, false)
		var prerequisites := _validate_string_list(
			record.get("requires"), path + ".requires", errors, true
		)
		for prerequisite in prerequisites:
			if not records.has(prerequisite):
				errors.append("%s.requires references unknown technology '%s'" % [path, prerequisite])
			elif prerequisite == record_id:
				errors.append("%s.requires cannot depend on itself" % path)
		if record.has("building"):
			_validate_building_reference(record["building"], path + ".building", buildings, errors)
		_validate_tech_effects(record.get("effects"), path + ".effects", buildings, errors)
	_validate_tech_cycles(records, errors)


func _validate_tech_effects(
	value: Variant, path: String, buildings: Dictionary, errors: Array[String]
) -> void:
	if not value is Dictionary:
		errors.append("%s must be an object" % path)
		return
	var effects: Dictionary = value
	for map_name in ["mult", "add"]:
		if not effects.has(map_name):
			continue
		if not effects[map_name] is Dictionary:
			errors.append("%s.%s must be an object" % [path, map_name])
			continue
		for effect_name in effects[map_name]:
			var field_path := "%s.%s.%s" % [path, map_name, effect_name]
			_validate_number_value(
				effects[map_name][effect_name], field_path, errors,
				0.0, map_name == "add"
			)
	if effects.has("era"):
		_validate_integer_value(effects["era"], path + ".era", errors, 1)
		if _is_number(effects["era"]) and int(effects["era"]) > 3:
			errors.append("%s.era exceeds the current three-era progression" % path)
	if effects.has("unlock_building"):
		var unlocked := _validate_string_list(
			effects["unlock_building"], path + ".unlock_building", errors, false
		)
		for building_id in unlocked:
			_validate_building_reference(
				building_id, path + ".unlock_building", buildings, errors
			)
	if effects.has("flags"):
		_validate_string_list(effects["flags"], path + ".flags", errors, false)


func _validate_tech_cycles(records: Dictionary, errors: Array[String]) -> void:
	var states: Dictionary = {}
	var cycle_reports: Dictionary = {}
	for tech_id in records:
		_visit_tech(String(tech_id), records, states, cycle_reports, errors)


func _visit_tech(
	tech_id: String,
	records: Dictionary,
	states: Dictionary,
	cycle_reports: Dictionary,
	errors: Array[String]
) -> void:
	var state := int(states.get(tech_id, 0))
	if state == 2:
		return
	if state == 1:
		if not cycle_reports.has(tech_id):
			errors.append("techs prerequisite cycle reaches '%s'" % tech_id)
			cycle_reports[tech_id] = true
		return
	states[tech_id] = 1
	var record: Dictionary = records[tech_id]
	var prerequisites: Variant = record.get("requires", [])
	if prerequisites is Array:
		for prerequisite in prerequisites:
			var prerequisite_id := String(prerequisite)
			if records.has(prerequisite_id):
				_visit_tech(prerequisite_id, records, states, cycle_reports, errors)
	states[tech_id] = 2


func _validate_campaigns(
	value: Variant, enemies: Dictionary, errors: Array[String]
) -> void:
	if not value is Dictionary:
		errors.append("campaigns must be a JSON object")
		return
	var modes: Dictionary = value
	for required_mode in ["classic", "frontier"]:
		if not modes.has(required_mode):
			errors.append("campaigns.%s definition is missing" % required_mode)
	for mode_id in modes:
		var mode: Variant = modes[mode_id]
		var path := "campaigns.%s" % String(mode_id)
		if not mode is Dictionary:
			errors.append("%s must be an object" % path)
			continue
		_validate_int_field(mode, "final_day", path, errors, true, 1)
		_validate_int_field(mode, "base", path, errors, true, 1)
		_validate_int_field(mode, "per_day", path, errors, true, 0)
		_validate_int_field(mode, "max", path, errors, true, 1)
		if mode is Dictionary:
			_validate_enemy_reference(mode.get("boss"), path + ".boss", enemies, errors)
			_validate_stage_ranges(
				mode.get("stages"), int(mode.get("final_day", 0)), path + ".stages", errors
			)


func _validate_stage_ranges(
	value: Variant, final_day: int, path: String, errors: Array[String]
) -> void:
	if not value is Array:
		errors.append("%s must be a non-empty array" % path)
		return
	var stages: Array = value
	if stages.is_empty():
		errors.append("%s must be a non-empty array" % path)
		return
	var seen: Dictionary = {}
	var expected_day := 1
	for index in stages.size():
		var stage: Variant = stages[index]
		var stage_path := "%s[%d]" % [path, index]
		if not stage is Dictionary:
			errors.append("%s must be an object" % stage_path)
			continue
		var stage_id := String(stage.get("id", "")).strip_edges()
		if stage_id.is_empty():
			errors.append("%s.id must be a non-empty string" % stage_path)
		elif seen.has(stage_id):
			errors.append("%s.id duplicates '%s'" % [stage_path, stage_id])
		seen[stage_id] = true
		for text_field in ["label", "name", "summary"]:
			_require_text(stage, text_field, stage_path, errors)
		_validate_int_field(stage, "from_day", stage_path, errors, true, 1)
		_validate_int_field(stage, "to_day", stage_path, errors, true, 1)
		if not stage.has("from_day") or not stage.has("to_day"):
			continue
		if not _is_number(stage["from_day"]) or not _is_number(stage["to_day"]):
			continue
		var first_day := int(stage["from_day"])
		var last_day := int(stage["to_day"])
		if first_day != expected_day:
			errors.append(
				"%s.from_day must be %d; stage ranges cannot overlap or leave gaps" %
				[stage_path, expected_day]
			)
		if last_day < first_day:
			errors.append("%s.to_day must not precede from_day" % stage_path)
			continue
		expected_day = last_day + 1
		if final_day > 0 and last_day > final_day:
			errors.append("%s.to_day exceeds final_day %d" % [stage_path, final_day])
	if final_day > 0 and expected_day != final_day + 1:
		errors.append(
			"%s must cover days 1 through %d without gaps" % [path, final_day]
		)


func _validate_factions(
	records: Dictionary, enemies: Dictionary, errors: Array[String]
) -> Dictionary:
	var regions: Dictionary = {}
	for faction_id in records:
		var record: Dictionary = records[faction_id]
		var path := "factions.%s" % faction_id
		_require_text(record, "name", path, errors)
		_require_text(record, "region", path, errors)
		_require_text(record, "doctrine", path, errors)
		var region := String(record.get("region", ""))
		if not region.is_empty():
			if not REGIONS.has(region):
				errors.append("%s.region has unsupported value '%s'" % [path, region])
			elif regions.has(region):
				errors.append("%s.region duplicates faction region '%s'" % [path, region])
			else:
				regions[region] = faction_id
		_validate_enemy_reference(record.get("garrison"), path + ".garrison", enemies, errors)
		_validate_enemy_reference(record.get("patrol_unit"), path + ".patrol_unit", enemies, errors)
		_validate_enemy_reference(record.get("raid_unit"), path + ".raid_unit", enemies, errors)
		var roster := _validate_string_list(record.get("roster"), path + ".roster", errors, true)
		if roster.is_empty():
			errors.append("%s.roster must contain at least one enemy" % path)
		for enemy_id in roster:
			_validate_enemy_reference(enemy_id, path + ".roster", enemies, errors)
		_validate_camp_rules(record.get("camp"), path + ".camp", errors)
		_validate_raid_rules(record.get("raid"), path + ".raid", errors)
		_validate_optional_dictionary(record, "visual", path, errors)
	return regions


func _validate_camp_rules(value: Variant, path: String, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("%s must be an object" % path)
		return
	var camp: Dictionary = value
	_validate_number_field(camp, "patrol_radius", path, errors, true, 0.0, false)
	_validate_int_field(camp, "initial_patrols", path, errors, true, 0)
	_validate_int_field(camp, "active_patrol_cap", path, errors, true, 1)
	_validate_int_field(camp, "reinforcement_budget", path, errors, true, 0)
	_validate_number_field(camp, "reinforcement_cooldown", path, errors, true, 0.0, false)


func _validate_raid_rules(value: Variant, path: String, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("%s must be an object" % path)
		return
	var raid: Dictionary = value
	_validate_int_field(raid, "budget", path, errors, true, 0)
	_validate_number_field(raid, "cooldown", path, errors, true, 0.0, false)
	_validate_int_field(raid, "active_cap", path, errors, true, 1)


func _validate_objectives(
	records: Dictionary, faction_regions: Dictionary, errors: Array[String]
) -> void:
	for objective_id in records:
		var record: Dictionary = records[objective_id]
		var path := "frontier_objectives.%s" % objective_id
		_require_text(record, "name", path, errors)
		_require_text(record, "description", path, errors)
		_require_text(record, "type", path, errors)
		var objective_type := String(record.get("type", ""))
		if not objective_type.is_empty() and not OBJECTIVE_TYPES.has(objective_type):
			errors.append("%s.type has unsupported value '%s'" % [path, objective_type])
		var region := String(record.get("region", ""))
		if not faction_regions.has(region):
			errors.append("%s.region does not resolve to a configured faction" % path)
		_validate_int_field(record, "act", path, errors, true, 1)
		if record.has("act") and _is_number(record["act"]) and int(record["act"]) > 4:
			errors.append("%s.act must be between 1 and 4" % path)
		if not record.has("required") or not record["required"] is bool:
			errors.append("%s.required must be a boolean" % path)
		_validate_amount_map(record.get("reward"), path + ".reward", errors)
		if objective_type != "discovery":
			_validate_number_field(record, "hp", path, errors, true, 0.0, false)
		_validate_optional_int_field(record, "guards", path, errors, 0)
		_validate_optional_int_field(record, "recruits", path, errors, 0)


func _validate_amount_map(
	value: Variant, path: String, errors: Array[String],
	allow_signed: bool = false, allowed_keys: Array = RESOURCE_KEYS
) -> void:
	if not value is Dictionary:
		errors.append("%s must be an object" % path)
		return
	var amounts: Dictionary = value
	for resource in amounts:
		var resource_key := String(resource)
		if not allowed_keys.has(resource_key):
			errors.append("%s.%s is not a supported resource/effect key" % [path, resource_key])
			continue
		_validate_integer_value(
			amounts[resource], path + "." + resource_key, errors,
			-2147483648 if allow_signed else 0
		)


func _validate_string_list(
	value: Variant,
	path: String,
	errors: Array[String],
	required: bool = true,
	allowed_values: Array = []
) -> Array[String]:
	var result: Array[String] = []
	if value == null and not required:
		return result
	if not value is Array:
		errors.append("%s must be an array of strings" % path)
		return result
	var seen: Dictionary = {}
	var values: Array = value
	for index in values.size():
		var item: Variant = values[index]
		if not item is String or String(item).strip_edges().is_empty():
			errors.append("%s[%d] must be a non-empty string" % [path, index])
			continue
		var item_text := String(item)
		if seen.has(item_text):
			errors.append("%s contains duplicate value '%s'" % [path, item_text])
		seen[item_text] = true
		if not allowed_values.is_empty() and not allowed_values.has(item_text):
			errors.append("%s[%d] has unsupported value '%s'" % [path, index, item_text])
		result.append(item_text)
	return result


func _validate_enemy_reference(
	value: Variant, path: String, enemies: Dictionary, errors: Array[String]
) -> void:
	if not value is String or String(value).is_empty():
		errors.append("%s must reference an enemy ID" % path)
	elif not enemies.has(String(value)):
		errors.append("%s references unknown enemy '%s'" % [path, value])


func _validate_building_reference(
	value: Variant, path: String, buildings: Dictionary, errors: Array[String]
) -> void:
	if not value is String or String(value).is_empty():
		errors.append("%s must reference a building ID" % path)
	elif not buildings.has(String(value)):
		errors.append("%s references unknown building '%s'" % [path, value])


func _require_text(
	record: Dictionary, field: String, path: String, errors: Array[String]
) -> void:
	if not record.has(field) or not record[field] is String or String(record[field]).strip_edges().is_empty():
		errors.append("%s.%s must be a non-empty string" % [path, field])


func _validate_optional_bool(
	record: Dictionary, field: String, path: String, errors: Array[String]
) -> void:
	if record.has(field) and not record[field] is bool:
		errors.append("%s.%s must be a boolean" % [path, field])


func _validate_optional_dictionary(
	record: Dictionary, field: String, path: String, errors: Array[String]
) -> void:
	if record.has(field) and not record[field] is Dictionary:
		errors.append("%s.%s must be an object" % [path, field])


func _validate_number_field(
	record: Dictionary,
	field: String,
	path: String,
	errors: Array[String],
	required: bool,
	minimum: float,
	allow_zero: bool,
	maximum: float = -1.0
) -> void:
	if not record.has(field):
		if required:
			errors.append("%s.%s is required" % [path, field])
		return
	_validate_number_value(
		record[field], path + "." + field, errors, minimum, allow_zero, maximum
	)


func _validate_optional_number_field(
	record: Dictionary,
	field: String,
	path: String,
	errors: Array[String],
	minimum: float,
	allow_zero: bool
) -> void:
	if record.has(field):
		_validate_number_value(record[field], path + "." + field, errors, minimum, allow_zero)


func _validate_number_value(
	value: Variant,
	path: String,
	errors: Array[String],
	minimum: float = 0.0,
	allow_zero: bool = true,
	maximum: float = -1.0
) -> void:
	if not _is_number(value):
		errors.append("%s must be numeric" % path)
		return
	var number := float(value)
	if is_nan(number) or is_inf(number):
		errors.append("%s must be finite" % path)
		return
	if (allow_zero and number < minimum) or (not allow_zero and number <= minimum):
		errors.append("%s must be %s %.3f" % [
			path, "at least" if allow_zero else "greater than", minimum
		])
	if maximum >= 0.0 and number > maximum:
		errors.append("%s must not exceed %.3f" % [path, maximum])


func _validate_int_field(
	record: Dictionary,
	field: String,
	path: String,
	errors: Array[String],
	required: bool,
	minimum: int
) -> void:
	if not record.has(field):
		if required:
			errors.append("%s.%s is required" % [path, field])
		return
	_validate_integer_value(record[field], path + "." + field, errors, minimum)


func _validate_optional_int_field(
	record: Dictionary, field: String, path: String, errors: Array[String], minimum: int
) -> void:
	if record.has(field):
		_validate_integer_value(record[field], path + "." + field, errors, minimum)


func _validate_integer_value(
	value: Variant, path: String, errors: Array[String], minimum: int
) -> void:
	if not _is_number(value):
		errors.append("%s must be an integer" % path)
		return
	var number := float(value)
	if is_nan(number) or is_inf(number) or number != float(int(number)):
		errors.append("%s must be a finite integer" % path)
		return
	if int(number) < minimum:
		errors.append("%s must be at least %d" % [path, minimum])


func _is_number(value: Variant) -> bool:
	return value is int or value is float
