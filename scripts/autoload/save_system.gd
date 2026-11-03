extends Node
## Versioned save/load with rollback backup and resource-node state.

const PATH := "user://save.json"
const TMP := "user://save.tmp"
const BACKUP := "user://save.bak"
const VERSION := 17
const SAVE_VALIDATOR_SCRIPT := preload("res://scripts/persistence/save_validator.gd")

var pending: Dictionary = {}
var _validator = SAVE_VALIDATOR_SCRIPT.new()


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _validator.configure(VERSION)
    Events.day_changed.connect(_on_day_changed)


func has_save() -> bool:
    return _read_valid_save(PATH) != null or _read_valid_save(BACKUP) != null


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
    DirAccess.remove_absolute(TMP)
    var file := FileAccess.open(TMP, FileAccess.WRITE)
    if file == null:
        if not silent:
            Events.build_feedback.emit("Gagal menulis save")
        return false

    file.store_string(JSON.stringify(data))
    file.flush()
    var write_error := file.get_error()
    file.close()
    if write_error != OK:
        DirAccess.remove_absolute(TMP)
        if not silent:
            Events.build_feedback.emit("Gagal menulis save")
        return false

    # Only replace the rollback copy with a verified primary save.
    if FileAccess.file_exists(PATH):
        if _read_saved_data(PATH, false) != null:
            DirAccess.remove_absolute(BACKUP)
            var backup_error := DirAccess.rename_absolute(PATH, BACKUP)
            if backup_error != OK:
                DirAccess.remove_absolute(TMP)
                if not silent:
                    Events.build_feedback.emit("Gagal mengamankan save lama")
                return false
        else:
            DirAccess.remove_absolute(PATH)

    var install_error := DirAccess.rename_absolute(TMP, PATH)
    if install_error != OK:
        if FileAccess.file_exists(BACKUP):
            var restore_error := DirAccess.rename_absolute(BACKUP, PATH)
            if restore_error != OK:
                push_error("Save rollback failed; backup remains at " + BACKUP)
        DirAccess.remove_absolute(TMP)
        if not silent:
            Events.build_feedback.emit("Gagal memasang save baru")
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
        if villager.is_outpost_guard():
            guard_outpost = {"cx": villager.guard_outpost.cell.x, "cy": villager.guard_outpost.cell.y}
        villagers.append({"x": villager.position.x, "y": villager.position.y, "job": villager.job,
            "occupation": villager.occupation, "military_specialization": villager.military_specialization,
            "hp": villager.hp, "carry": villager.carry, "kind": villager.carry_kind,
            "weapon_equipped": villager.weapon_equipped, "armor_equipped": villager.armor_equipped,
            "expedition": villager.is_expeditioning(), "recalling": villager.is_recalling_expedition(),
            "guard_outpost": guard_outpost})

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
    for cell in main.world.occupied:
        var node = main.world.occupied[cell]
        if is_instance_valid(node) and node.is_in_group("resource_nodes") and node.has_method("export_state"):
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
    if not FileAccess.file_exists(path):
        return null
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return null
    var json := JSON.new()
    var parse_result := json.parse(file.get_as_text())
    file.close()
    if parse_result != OK or not _valid_save(json.data, enforce_world_compatibility):
        return null
    return json.data


func _read_valid_save(path: String) -> Variant:
    return _read_saved_data(path, true)


## Load the primary save, falling back to the last known-good copy when necessary.
func request_load() -> bool:
    var parsed: Variant = null
    for candidate in [PATH, BACKUP]:
        parsed = _read_valid_save(candidate)
        if parsed != null:
            break

    if parsed == null:
        Events.build_feedback.emit("Save rusak atau versi tidak cocok")
        return false

    pending = parsed
    get_tree().paused = false
    get_tree().reload_current_scene()
    return true


func take_pending() -> Dictionary:
    var data := pending
    pending = {}
    return data
