extends Node
## Versioned save/load with rollback backup and resource-node state.

const PATH := "user://save.json"
const TMP := "user://save.tmp"
const BACKUP := "user://save.bak"
const VERSION := 17
const SAVE_VALIDATOR_SCRIPT := preload("res://scripts/persistence/save_validator.gd")
const SAVE_FILE_STORE_SCRIPT := preload("res://scripts/persistence/save_file_store.gd")
const SAVE_MIGRATION_SCRIPT := preload("res://scripts/persistence/save_migration_pipeline.gd")

var pending: Dictionary = {}
var _validator = SAVE_VALIDATOR_SCRIPT.new()
var _file_store = SAVE_FILE_STORE_SCRIPT.new()


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _validator.configure(VERSION)
    _file_store.configure(_validator)
    Events.day_changed.connect(_on_day_changed)


func has_save() -> bool:
    # Continue must remain available for valid saves made on older map dimensions.
    return _read_saved_data(PATH, false) != null or _read_saved_data(BACKUP, false) != null


func _on_day_changed(_day: int) -> void:
    if save_current(true):
        Events.build_feedback.emit("Autosave")


func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey and event.pressed and not event.echo):
        return
    if Input.is_action_just_pressed("save_game"):
        save_current()
        get_viewport().set_input_as_handled()
    elif Input.is_action_just_pressed("load_game"):
        request_load()
        get_viewport().set_input_as_handled()


func _main() -> Node:
    return get_tree().get_first_node_in_group("main")


## Write a complete temporary file before moving the current save to its rollback copy.
func save_current(silent := false) -> bool:
    var main := _main()
    if main == null or not _has_keep():
        if not silent:
            Events.build_feedback.emit("Tidak bisa menyimpan sekarang")
        return false

    var data := collect(main)
    if not _file_store.write_snapshot(data, PATH, TMP, BACKUP):
        if not silent:
            Events.build_feedback.emit("Gagal menyimpan save")
        return false

    if not silent:
        Events.build_feedback.emit("Game disimpan")
    return true

func _has_keep() -> bool:
    for building in get_tree().get_nodes_in_group("buildings"):
        if building.id == "keep":
            return true
    return false


func collect(main: Node) -> Dictionary:
    var buildings: Array = []
    for building in get_tree().get_nodes_in_group("buildings"):
        buildings.append({"id": building.id, "cx": building.cell.x, "cy": building.cell.y, "hp": building.hp, "stockpile": building.export_stockpile()})

    var construction_sites: Array = []
    var queued_sites: Array = get_tree().get_nodes_in_group("construction_sites")
    if main != null and main.build != null and main.build.has_method("construction_queue"):
        queued_sites = main.build.construction_queue()
    for site in queued_sites:
        if is_instance_valid(site):
            construction_sites.append(site.export_state())

    var villagers: Array = []
    for villager in get_tree().get_nodes_in_group("villagers"):
        var guard_outpost: Variant = null
        var guard_garrison: Variant = null
        if villager.is_outpost_guard():
            var guard_building = villager.guard_outpost
            if String(guard_building.id) == "outpost":
                guard_outpost = {"cx": guard_building.cell.x, "cy": guard_building.cell.y}
            else:
                guard_garrison = {"id": String(guard_building.id), "cx": guard_building.cell.x, "cy": guard_building.cell.y}
        villagers.append({"x": villager.position.x, "y": villager.position.y, "job": villager.job,
            "occupation": villager.occupation, "military_specialization": villager.military_specialization,
            "hp": villager.hp, "carry": villager.carry, "kind": villager.carry_kind,
            "weapon_equipped": villager.weapon_equipped, "armor_equipped": villager.armor_equipped,
            "expedition": villager.is_expeditioning(), "recalling": villager.is_recalling_expedition(),
            "guard_outpost": guard_outpost, "guard_garrison": guard_garrison})

    var enemies: Array = []
    for enemy in get_tree().get_nodes_in_group("enemies"):
        enemies.append({
            "id": enemy.id, "x": enemy.position.x, "y": enemy.position.y, "hp": enemy.hp,
            "garrison": enemy.is_garrison,
            "guard_x": enemy.guard_origin.x,
            "guard_y": enemy.guard_origin.y,
            "faction": enemy.faction_id,
            "site_id": enemy.campaign_site_id,
            "supply_raid": enemy.is_supply_raider,
            "faction_raid": enemy.is_faction_raider,
            "raid_kind": enemy.faction_raid_target_kind if enemy.is_faction_raider else "",
            "raid_camp": enemy.faction_raid_camp_id if enemy.is_faction_raider else "",
            "raid_region": enemy.faction_raid_region_id if enemy.is_faction_raider else "",
            "raid_target": {"cx": enemy.raid_target_cell.x, "cy": enemy.raid_target_cell.y}
                if enemy.is_supply_raider or enemy.is_faction_raider else null,
            "raid_hits": enemy.supply_raid_hits,
            "patrol": enemy.export_patrol_state()
        })

    var resources: Array = []
    for resource_cell in main.world.resource_nodes_by_cell:
        var node = main.world.resource_nodes_by_cell[resource_cell]
        if not is_instance_valid(node) or not node.is_in_group("resource_nodes") or not node.has_method("export_state"):
            continue
        var cell: Vector2i = resource_cell
        resources.append({
            "cx": cell.x,
            "cy": cell.y,
            "kind": node.yield_kind,
            "state": node.export_state()
        })

    var stronghold_state: Dictionary = main.campaign.export_primary_state() if main.campaign != null else {"destroyed": true}
    var campaign_state: Dictionary = main.campaign.export_state() if main.campaign != null else {}

    return {
        "version": VERSION,
        "world": {
            "profile": WorldConfig.profile_id,
            "map_size": WorldConfig.map_size,
            "tile_size": WorldConfig.tile_size,
            "seed": main.world.map_seed
        },
        "stronghold": stronghold_state,
        "campaign": campaign_state,
        "fog": main.fog.export_state() if is_instance_valid(main.fog) else {},
        "inventory": Inventory.items,
        "clock": {"t": GameClock.time_of_day, "day": GameClock.day, "night": GameClock.is_night},
        "player": {
            "x": main.player.position.x,
            "y": main.player.position.y,
            "hp": main.player.hp,
            "combat": main.player.export_combat_state()
        },
        "buildings": buildings,
        "construction_sites": construction_sites,
        "villagers": villagers,
        "enemies": enemies,
        "resources": resources,
        "quota": main.village.quota,
        "job_priority": main.village.job_priority.duplicate(),
        "spawner": main.spawner.export_state(),
        "tech": Tech.export_state(),
        "supply": main.supply.export_state(),
        "events": main.events.export_state() if main.events != null else {"pending_event_id": "", "scheduled_consequences": []},
        "frontier_campaign": main.frontier_campaign.export_state() if main.frontier_campaign != null else {"profile": WorldConfig.profile_id, "objectives": [], "final_boss_defeated": false, "unlocked_act": 1},
    }


func _valid_save(data: Variant, enforce_world_compatibility := true) -> bool:
    return _validator.is_valid_save(data, enforce_world_compatibility)


func _read_saved_data(path: String, enforce_world_compatibility := true) -> Variant:
    return _file_store.read_snapshot(path, enforce_world_compatibility)

func _read_valid_save(path: String) -> Variant:
    return _read_saved_data(path, true)


## Return the profile and exact historical/current dimensions from the newest valid save.
func saved_profile_id() -> String:
    for candidate in [PATH, BACKUP]:
        var data: Variant = _read_saved_data(candidate, false)
        if not (data is Dictionary):
            continue
        if int(data.get("version", 0)) < 7:
            return "classic"
        var world_data: Variant = data.get("world", {})
        if world_data is Dictionary:
            var profile_id := String(world_data.get("profile", ""))
            var map_size := int(world_data.get("map_size", 0))
            if WorldConfig.is_supported_map_size(profile_id, map_size):
                return profile_id
    return WorldConfig.profile_id


func saved_map_size() -> int:
    for candidate in [PATH, BACKUP]:
        var data: Variant = _read_saved_data(candidate, false)
        if not (data is Dictionary):
            continue
        if int(data.get("version", 0)) < 7:
            return int(WorldConfig.LEGACY_PROFILES["classic"]["map_size"])
        var world_data: Variant = data.get("world", {})
        if world_data is Dictionary:
            var profile_id := String(world_data.get("profile", ""))
            var map_size := int(world_data.get("map_size", 0))
            if WorldConfig.is_supported_map_size(profile_id, map_size):
                return map_size
    return WorldConfig.map_size


## Load the primary save, falling back to the last known-good copy when necessary.
## Apply the saved profile and dimensions before rebuilding the scene. This preserves
## terrain coordinates, fog indices and resource placement from historical campaigns.
func request_load() -> bool:
    var parsed: Variant = null
    var selected_profile := ""
    var previous_profile := WorldConfig.profile_id
    var previous_size := WorldConfig.map_size

    for candidate in [PATH, BACKUP]:
        var candidate_data: Variant = _read_saved_data(candidate, false)
        if not (candidate_data is Dictionary):
            continue
        var source_version := int(candidate_data.get("version", 0))
        var target_profile := "classic"
        var target_size := int(WorldConfig.LEGACY_PROFILES["classic"]["map_size"])
        if source_version >= 7:
            var world_data: Variant = candidate_data.get("world", {})
            if not (world_data is Dictionary):
                continue
            target_profile = String(world_data.get("profile", ""))
            target_size = int(world_data.get("map_size", 0))

        if not WorldConfig.apply_saved_profile(target_profile, target_size):
            continue
        if not _valid_save(candidate_data, true):
            continue
        parsed = candidate_data
        selected_profile = target_profile
        break

    if parsed == null:
        WorldConfig.apply_saved_profile(previous_profile, previous_size)
        Events.build_feedback.emit("Save rusak, tidak kompatibel, atau seed berbeda")
        return false

    Settings.set_world_profile(selected_profile)
    var source_version := int(parsed.get("version", 0))
    if source_version < VERSION:
        var main := _main()
        var migration = SAVE_MIGRATION_SCRIPT.new()
        var migrated: Variant = migration.migrate_snapshot_to_current(parsed, main, VERSION)
        if migrated is Dictionary and _valid_save(migrated, true):
            if _file_store.write_snapshot(migrated, PATH, TMP, BACKUP):
                parsed = migrated
            else:
                push_warning("Save migration: canonical v%d snapshot was valid but could not be installed; loading the original snapshot" % VERSION)
        else:
            push_warning("Save migration: historical snapshot could not be upgraded losslessly; loading it without rewriting the source file")

    pending = parsed
    get_tree().paused = false
    get_tree().reload_current_scene()
    return true

func take_pending() -> Dictionary:
    var data := pending
    pending = {}
    return data
