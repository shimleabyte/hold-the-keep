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


const CAMPAIGN_SCRIPT := preload("res://scripts/systems/campaign.gd")


## Return a complete current-schema snapshot without changing the source dictionary.
## A null result means the old snapshot is valid but cannot be upgraded losslessly.
func migrate_snapshot_to_current(snapshot: Dictionary, main: Node, target_version: int) -> Variant:
    var source_version := int(snapshot.get("version", 0))
    if source_version < 1 or source_version > target_version or main == null or main.world == null:
        return null
    if source_version == target_version:
        return snapshot.duplicate(true)

    var migrated: Dictionary = snapshot.duplicate(true)
    var profile := WorldConfig.profile_id
    if source_version < 7:
        # The pre-v7 format only represented the original 64x64 Classic world.
        profile = "classic"
        migrated["world"] = {
            "profile": "classic",
            "map_size": 64,
            "tile_size": WorldConfig.TILE_SIZE,
            "seed": WorldConfig.world_seed
        }
    else:
        var saved_world: Variant = migrated.get("world", {})
        if not (saved_world is Dictionary):
            return null
        profile = String(saved_world.get("profile", ""))
        if profile != WorldConfig.profile_id:
            return null

    var restore_plan: Dictionary = build_restore_plan(snapshot, main.world, target_version)
    if source_version < 8:
        var legacy_state: Dictionary = restore_plan["legacy_stronghold"].duplicate(true)
        if legacy_state.is_empty():
            # The old loader generated a new target only after restoring buildings.
            # Do not guess a replacement cell in the pre-load world.
            return null
        var legacy_cell := Vector2i(int(legacy_state.get("cx", -1)), int(legacy_state.get("cy", -1)))
        var destroyed := bool(legacy_state.get("destroyed", false))
        if not WorldConfig.is_valid_cell(legacy_cell):
            if not destroyed:
                return null
            legacy_cell = WorldConfig.starting_keep_cell()
        legacy_state["cx"] = legacy_cell.x
        legacy_state["cy"] = legacy_cell.y
        if destroyed:
            legacy_state["hp"] = 0
        else:
            var saved_hp := int(legacy_state.get("hp", 0))
            if saved_hp < 1 or saved_hp > 900:
                return null
        if String(legacy_state.get("id", "")).is_empty():
            legacy_state["id"] = "classic_enemy_keep" if profile == "classic" else "legacy_frontier_keep"
        if String(legacy_state.get("region", "")).is_empty():
            legacy_state["region"] = String(main.world.region_id(legacy_cell))
        if String(legacy_state.get("faction", "")).is_empty():
            if not snapshot.get("stronghold", {}).has("faction"):
                legacy_state["faction"] = "legacy_raiders"
            else:
                return null
        var legacy_campaign = CAMPAIGN_SCRIPT.new()
        legacy_campaign.configure_legacy(profile, legacy_state)
        migrated["campaign"] = legacy_campaign.export_state()
        legacy_campaign.free()

    var player_state: Variant = migrated.get("player", {})
    if not (player_state is Dictionary):
        return null
    if source_version < 6:
        player_state["combat"] = {"level": 1, "xp": 0}
    migrated["player"] = player_state

    var saved_buildings: Variant = migrated.get("buildings", [])
    if not (saved_buildings is Array):
        return null
    for building_value in saved_buildings:
        if not (building_value is Dictionary):
            return null
        if source_version < 12:
            building_value["stockpile"] = {}

    var saved_villagers: Variant = migrated.get("villagers", [])
    if not (saved_villagers is Array):
        return null
    var normalized_villagers: Array = restore_plan["villagers"]
    if normalized_villagers.size() != saved_villagers.size():
        return null
    for index in range(saved_villagers.size()):
        var villager_value: Variant = saved_villagers[index]
        if not (villager_value is Dictionary):
            return null
        var villager: Dictionary = villager_value
        var normalized: Dictionary = normalized_villagers[index]
        var restored_job := String(normalized.get("job", ""))
        villager["job"] = restored_job
        villager["expedition"] = bool(normalized.get("expedition", false))
        villager["recalling"] = bool(normalized.get("recalling", false))
        villager["occupation"] = "" if restored_job == "soldier" else restored_job
        villager["military_specialization"] = "soldier" if restored_job == "soldier" else ""
        if source_version < 17:
            villager["weapon_equipped"] = false
            villager["armor_equipped"] = false
        else:
            villager["weapon_equipped"] = bool(villager.get("weapon_equipped", false))
            villager["armor_equipped"] = bool(villager.get("armor_equipped", false))
        saved_villagers[index] = villager
    migrated["villagers"] = saved_villagers

    var saved_enemies: Variant = migrated.get("enemies", [])
    if not (saved_enemies is Array):
        return null
    if source_version < 10:
        for enemy_value in saved_enemies:
            if not (enemy_value is Dictionary):
                return null
            enemy_value["faction"] = ""
    migrated["enemies"] = saved_enemies

    var quota_value: Variant = migrated.get("quota", {})
    if not (quota_value is Dictionary):
        return null
    var quota: Dictionary = quota_value.duplicate(true)
    var current_jobs := ["woodcutter", "miner", "farmer", "builder", "hunter", "scout", "healer", "blacksmith", "soldier"]
    for job_name in current_jobs:
        if not quota.has(job_name):
            quota[job_name] = 1 if job_name == "woodcutter" else 0
    migrated["quota"] = quota

    var priority_value: Variant = migrated.get("job_priority", [])
    var priority: Array = []
    if priority_value is Array:
        for value in priority_value:
            var job_name := String(value)
            if current_jobs.has(job_name) and not priority.has(job_name):
                priority.append(job_name)
    for job_name in ["woodcutter", "miner", "farmer", "builder", "hunter", "scout", "healer", "blacksmith", "soldier"]:
        if not priority.has(job_name):
            priority.append(job_name)
    migrated["job_priority"] = priority

    if source_version < 11:
        migrated["frontier_campaign"] = _default_frontier_campaign(profile)
    elif not migrated.has("frontier_campaign"):
        return null
    if source_version < 13:
        migrated["supply"] = {
            "next_id": 1,
            "orders": [],
            "cost_source": null,
            "pressure": []
        }
    elif not migrated.has("supply"):
        return null
    if not migrated.has("events"):
        migrated["events"] = {
            "pending_event_id": "",
            "scheduled_consequences": []
        }

    migrated["version"] = target_version
    return migrated


func _default_frontier_campaign(profile: String) -> Dictionary:
    if profile == "classic":
        return {
            "profile": "classic",
            "objectives": [],
            "final_boss_defeated": false,
            "unlocked_act": 1,
            "camps": {"records": []}
        }
    var records: Array[Dictionary] = []
    for definition in DataDB.frontier_objectives:
        records.append({
            "id": String(definition.get("id", "")),
            "completed": false,
            "cell_x": -1,
            "cell_y": -1,
            "state": "waiting",
            "hp": 0,
            "x": 0.0,
            "y": 0.0,
            "path_index": 0,
            "saw_night": false
        })
    return {
        "profile": profile,
        "objectives": records,
        "final_boss_defeated": false,
        "unlocked_act": 1,
        "camps": {"records": []}
    }
