extends RefCounted
## Adapts historical save snapshots into the current scene-restoration contract.
## This is an in-memory import pipeline: it never rewrites the source save or its version.

func build_restore_plan(snapshot: Dictionary, world: Node, target_version: int) -> Dictionary:
    var source_version := int(snapshot.get("version", 0))
    var plan: Dictionary = {
        "source_version": source_version,
        "target_version": maxi(1, target_version),
        "campaign_mode": "legacy",
        "campaign_state": {},
        "legacy_stronghold": {},
        "villagers": [],
        "enemies": [],
        "restore_building_stockpiles": false,
        "restore_equipment_state": false,
        "building_stockpiles": [],
        "player_combat_state": {},
        "frontier_campaign_state": {},
        "supply_state": {},
        "events_state": {}
    }

    # Apply compatibility boundaries in schema order. Versions without a
    # scene-restore shape change are intentionally handled by pass-through
    # defaults in the relevant step rather than by rewriting persisted data.
    _migrate_v5_expedition_state(snapshot, plan)
    _migrate_v6_player_combat(snapshot, plan)
    _migrate_v8_campaign_state(snapshot, world, plan)
    _migrate_v9_villager_roles(snapshot, plan)
    _migrate_v10_enemy_faction_state(snapshot, plan)
    _migrate_v11_frontier_campaign(snapshot, plan)
    _migrate_v12_building_stockpiles(snapshot, plan)
    _migrate_v13_supply_state(snapshot, plan)
    _migrate_v17_equipment_and_events(snapshot, plan)
    return plan


func _migrate_v5_expedition_state(snapshot: Dictionary, plan: Dictionary) -> void:
    var source_version := int(plan["source_version"])
    var supports_expeditions := source_version >= 5
    var normalized_villagers: Array[Dictionary] = []
    var saved_villagers: Variant = snapshot.get("villagers", [])
    if saved_villagers is Array:
        for saved_value in saved_villagers:
            if not saved_value is Dictionary:
                continue
            var saved_villager: Dictionary = saved_value
            normalized_villagers.append({
                "job": String(saved_villager.get("job", "")),
                "expedition": supports_expeditions and bool(saved_villager.get("expedition", false)),
                "recalling": supports_expeditions and bool(saved_villager.get("recalling", false)),
                "weapon_equipped": false,
                "armor_equipped": false
            })
    plan["villagers"] = normalized_villagers


func _migrate_v6_player_combat(snapshot: Dictionary, plan: Dictionary) -> void:
    if int(plan["source_version"]) < 6:
        return
    var player_state: Variant = snapshot.get("player", {})
    if player_state is Dictionary:
        plan["player_combat_state"] = player_state.get("combat", {})


func _migrate_v8_campaign_state(snapshot: Dictionary, world: Node, plan: Dictionary) -> void:
    if int(plan["source_version"]) >= 8:
        plan["campaign_mode"] = "campaign"
        plan["campaign_state"] = snapshot.get("campaign", {})
        return

    var legacy_value: Variant = snapshot.get("stronghold", {})
    var legacy_state: Dictionary = legacy_value.duplicate(true) if legacy_value is Dictionary else {}
    if String(legacy_state.get("region", "")).is_empty():
        var legacy_cell := Vector2i(int(legacy_state.get("cx", -1)), int(legacy_state.get("cy", -1)))
        legacy_state["region"] = String(world.call("region_id", legacy_cell)) if legacy_cell.x >= 0 and legacy_cell.y >= 0 else "HEARTHLAND"
    if not legacy_state.has("faction"):
        legacy_state["faction"] = "legacy_raiders"
    plan["legacy_stronghold"] = legacy_state


func _migrate_v9_villager_roles(snapshot: Dictionary, plan: Dictionary) -> void:
    if int(plan["source_version"]) < 9:
        return
    var saved_villagers: Variant = snapshot.get("villagers", [])
    if not (saved_villagers is Array):
        return
    var normalized_villagers: Array = plan["villagers"]
    for index in range(mini(saved_villagers.size(), normalized_villagers.size())):
        var saved_villager: Variant = saved_villagers[index]
        if not (saved_villager is Dictionary):
            continue
        var specialization := String(saved_villager.get("military_specialization", ""))
        normalized_villagers[index]["job"] = specialization if not specialization.is_empty() else String(saved_villager.get("occupation", ""))


func _migrate_v10_enemy_faction_state(snapshot: Dictionary, plan: Dictionary) -> void:
    var saved_enemies: Variant = snapshot.get("enemies", [])
    if not (saved_enemies is Array):
        return
    var normalized_enemies: Array[Dictionary] = []
    for enemy_value in saved_enemies:
        if not enemy_value is Dictionary:
            continue
        var enemy_state: Dictionary = enemy_value.duplicate(true)
        if int(plan["source_version"]) < 10 and not enemy_state.has("faction"):
            enemy_state["faction"] = ""
        normalized_enemies.append(enemy_state)
    plan["enemies"] = normalized_enemies


func _migrate_v11_frontier_campaign(snapshot: Dictionary, plan: Dictionary) -> void:
    if int(plan["source_version"]) >= 11:
        plan["frontier_campaign_state"] = snapshot.get("frontier_campaign", {})


func _migrate_v12_building_stockpiles(snapshot: Dictionary, plan: Dictionary) -> void:
    var source_version := int(plan["source_version"])
    if source_version < 12:
        return
    plan["restore_building_stockpiles"] = true
    var saved_buildings: Variant = snapshot.get("buildings", [])
    if not (saved_buildings is Array):
        return
    var stockpiles: Array[Dictionary] = []
    for building_value in saved_buildings:
        if building_value is Dictionary:
            stockpiles.append(building_value.get("stockpile", {}).duplicate(true))
        else:
            stockpiles.append({})
    plan["building_stockpiles"] = stockpiles


func _migrate_v13_supply_state(snapshot: Dictionary, plan: Dictionary) -> void:
    if int(plan["source_version"]) >= 13:
        plan["supply_state"] = snapshot.get("supply", {})


func _migrate_v17_equipment_and_events(snapshot: Dictionary, plan: Dictionary) -> void:
    var source_version := int(plan["source_version"])
    plan["restore_equipment_state"] = source_version >= 17
    var saved_villagers: Variant = snapshot.get("villagers", [])
    var normalized_villagers: Array = plan["villagers"]
    if saved_villagers is Array:
        for index in range(mini(saved_villagers.size(), normalized_villagers.size())):
            var saved_villager: Variant = saved_villagers[index]
            if not saved_villager is Dictionary or source_version < 17:
                continue
            normalized_villagers[index]["weapon_equipped"] = bool(saved_villager.get("weapon_equipped", false))
            normalized_villagers[index]["armor_equipped"] = bool(saved_villager.get("armor_equipped", false))
    # Decision-event state is additive and optional, including for older saves.
    plan["events_state"] = snapshot.get("events", {})
