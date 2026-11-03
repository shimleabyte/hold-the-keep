extends SceneTree
## Regression tests for static gameplay data contracts and cross-file references.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data_db = root.get_node("DataDB")
	assert(data_db.validation_errors.is_empty(),
		"Shipped gameplay data must validate: %s" % "; ".join(data_db.validation_errors))
	assert(data_db.buildings.has("keep") and data_db.enemies.has("king"),
		"DataDB must only publish indexed data after validation succeeds")
	assert(data_db.cost_of("house").get("wood", -1) == 12,
		"Validated building costs must remain available through the existing API")

	var validator_script = load("res://scripts/autoload/data_schema_validator.gd")
	var validator = validator_script.new()
	var valid_sources: Dictionary = data_db.source_data.duplicate(true)
	assert(validator.validate(valid_sources).is_empty(),
		"An unchanged copy of every shipped data source must remain valid")

	var duplicate_building := valid_sources.duplicate(true)
	duplicate_building["buildings"].append(
		duplicate_building["buildings"][0].duplicate(true)
	)
	var errors: Array[String] = validator.validate(duplicate_building)
	_assert_has_error(errors, "id duplicates 'keep'",
		"Duplicate building IDs must be rejected with a source location")

	var malformed_size := valid_sources.duplicate(true)
	_record_by_id(malformed_size["buildings"], "house")["size"] = [2]
	errors = validator.validate(malformed_size)
	_assert_has_error(errors, "buildings.house.size",
		"Building footprint dimensions must contain exactly two values")

	var negative_cost := valid_sources.duplicate(true)
	_record_by_id(negative_cost["buildings"], "house")["cost"]["wood"] = -1
	errors = validator.validate(negative_cost)
	_assert_has_error(errors, "buildings.house.cost.wood",
		"Negative construction costs must be rejected before indexing")

	var unknown_wave_enemy := valid_sources.duplicate(true)
	unknown_wave_enemy["waves"]["types"][0]["id"] = "missing_enemy"
	errors = validator.validate(unknown_wave_enemy)
	_assert_has_error(errors, "waves.types[0].id references unknown enemy",
		"Wave tables must reference a registered base enemy or archetype")

	var unknown_technology := valid_sources.duplicate(true)
	_record_by_id(unknown_technology["techs"], "tools_wood")["requires"] = ["missing_tech"]
	errors = validator.validate(unknown_technology)
	_assert_has_error(errors, "techs.tools_wood.requires references unknown technology",
		"Technology prerequisites must resolve to known technology IDs")

	var cyclic_technology := valid_sources.duplicate(true)
	_record_by_id(cyclic_technology["techs"], "tools_wood")["requires"] = ["tools_stone"]
	errors = validator.validate(cyclic_technology)
	_assert_has_error(errors, "techs prerequisite cycle",
		"Technology prerequisite cycles must be rejected")

	var broken_faction := valid_sources.duplicate(true)
	broken_faction["factions"][0]["roster"][0] = "missing_enemy"
	errors = validator.validate(broken_faction)
	_assert_has_error(errors, "factions.greenwood_raiders.roster references unknown enemy",
		"Faction rosters must resolve to registered enemies")

	var unsupported_event_effect := valid_sources.duplicate(true)
	unsupported_event_effect["events"][0]["effects"]["gold"] = 10
	errors = validator.validate(unsupported_event_effect)
	_assert_has_error(errors, "events.trader.effects.gold is not a supported effect key",
		"Event effects must use the currently implemented resource/effect contract")

	var campaign_gap := valid_sources.duplicate(true)
	campaign_gap["campaigns"]["frontier"]["stages"][1]["from_day"] = 8
	errors = validator.validate(campaign_gap)
	_assert_has_error(errors, "campaigns.frontier.stages[1].from_day",
		"Campaign chapter ranges must remain contiguous and non-overlapping")

	var malformed_root := valid_sources.duplicate(true)
	malformed_root["events"] = {}
	errors = validator.validate(malformed_root)
	_assert_has_error(errors, "events must be a JSON array",
		"Invalid JSON root types must fail with the source name")

	print("PASS: DataDB schema, uniqueness, numeric bounds, references and campaign progression")
	quit(0)


func _record_by_id(records: Array, target_id: String) -> Dictionary:
	for record in records:
		if record is Dictionary and String(record.get("id", "")) == target_id:
			return record
	return {}


func _assert_has_error(errors: Array[String], fragment: String, message: String) -> void:
	for issue in errors:
		if issue.contains(fragment):
			return
	assert(false, "%s. Expected diagnostic containing '%s'; got: %s" %
		[message, fragment, "; ".join(errors)])
