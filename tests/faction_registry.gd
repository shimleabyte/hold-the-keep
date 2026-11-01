extends SceneTree
## Data contract checks for faction identities, rosters and archetype coverage.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var errors: Array[String] = FactionRegistry.validate()
    assert(errors.is_empty(), "Invalid faction definitions: %s" % "; ".join(errors))
    assert(FactionRegistry.factions.size() == 4, "Expected exactly four Frontier factions")
    assert(FactionRegistry.archetypes.size() == 6, "Expected six new enemy archetypes")

    var expected_regions := ["GREENWOOD", "HIGHLANDS", "FENLANDS", "ASHEN_MARCH"]
    for region_id in expected_regions:
        var faction_id := FactionRegistry.faction_for_region(region_id)
        assert(not faction_id.is_empty(), "Missing faction for region %s" % region_id)
        assert(not FactionRegistry.roster_for(faction_id).is_empty(), "Empty roster for %s" % faction_id)

    assert(FactionRegistry.garrison_enemy("greenwood_raiders") == "enemy_scout")
    assert(FactionRegistry.garrison_enemy("iron_legion") == "enemy_shieldbearer")
    assert(FactionRegistry.garrison_enemy("fen_cult") == "enemy_war_shaman")
    assert(FactionRegistry.garrison_enemy("ashen_host") == "enemy_siege_engine")
    assert(FactionRegistry.garrison_enemy("legacy_raiders") == "soldier")
    print("faction_registry: PASS")
    quit(0)
