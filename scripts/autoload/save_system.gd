extends Node
## Versioned save/load with rollback backup and resource-node state.

const PATH := "user://save.json"
const TMP := "user://save.tmp"
const BACKUP := "user://save.bak"
const VERSION := 13

var pending: Dictionary = {}


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    Events.day_changed.connect(_on_day_changed)


func has_save() -> bool:
    return _read_valid_save(PATH) != null or _read_valid_save(BACKUP) != null


func _on_day_changed(_day: int) -> void:
    if save_current(true):
        Events.build_feedback.emit("Autosave")


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_F5:
            save_current()
        elif event.keycode == KEY_F9:
            request_load()


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
        "frontier_campaign": main.frontier_campaign.export_state() if main.frontier_campaign != null else {"profile": WorldConfig.profile_id, "objectives": [], "final_boss_defeated": false, "unlocked_act": 1},
    }


func _valid_save(data: Variant, enforce_world_compatibility := true) -> bool:
    if not (data is Dictionary):
        return false
    var version := int(data.get("version", 0))
    if version < 1 or version > VERSION:
        return false

    var inventory = data.get("inventory")
    var clock = data.get("clock")
    var player = data.get("player")
    var buildings = data.get("buildings")
    var villagers = data.get("villagers")
    var enemies = data.get("enemies")
    var quota = data.get("quota", {})
    var spawner = data.get("spawner", {})
    var tech = data.get("tech", {})
    var resources = data.get("resources", [])
    var construction_sites = data.get("construction_sites", [])
    var stronghold = data.get("stronghold", {})
    var fog = data.get("fog", {})
    var save_map_cells := 64 * 64
    if version < 7:
        # Legacy saves use the original 64x64 Classic world.
        if enforce_world_compatibility and (WorldConfig.profile_id != "classic" or WorldConfig.map_size != 64):
            return false
    else:
        var world_data = data.get("world", {})
        if not (world_data is Dictionary):
            return false
        for key in ["profile", "map_size", "tile_size", "seed"]:
            if not world_data.has(key):
                return false
        var saved_profile := String(world_data["profile"])
        var saved_map_size := int(world_data["map_size"])
        var saved_tile_size := int(world_data["tile_size"])
        if not WorldConfig.PROFILES.has(saved_profile) or saved_map_size <= 0 or saved_tile_size <= 0:
            return false
        var saved_profile_data: Dictionary = WorldConfig.profile_definition(saved_profile)
        if saved_map_size != int(saved_profile_data.get("map_size", 0)) or saved_tile_size != WorldConfig.TILE_SIZE:
            return false
        if enforce_world_compatibility:
            if saved_profile != WorldConfig.profile_id:
                return false
            if saved_map_size != WorldConfig.map_size:
                return false
            if saved_tile_size != WorldConfig.tile_size:
                return false
            if int(world_data["seed"]) != WorldConfig.world_seed:
                return false
        save_map_cells = saved_map_size * saved_map_size
    if not (fog is Dictionary):
        return false
    var explored_cells = fog.get("cells", [])
    if not (explored_cells is Array):
        return false
    for index in explored_cells:
        if int(index) < 0 or int(index) >= save_map_cells:
            return false
    if not (stronghold is Dictionary):
        return false
    if not stronghold.is_empty() and not bool(stronghold.get("destroyed", false)):
        if not stronghold.has("cx") or not stronghold.has("cy") or not stronghold.has("hp"):
            return false
    if not (inventory is Dictionary) or not (clock is Dictionary) or not (player is Dictionary):
        return false
    if not (buildings is Array) or not (villagers is Array) or not (enemies is Array):
        return false
    if not (quota is Dictionary) or not (spawner is Dictionary) or not (tech is Dictionary):
        return false
    if not (resources is Array) or not (construction_sites is Array) or construction_sites.size() > 64:
        return false
    var campaign_world_data: Dictionary = data.get("world", {})
    if version >= 8 and not _valid_campaign_state(data.get("campaign", {}), String(campaign_world_data.get("profile", "")), int(campaign_world_data.get("map_size", 0))):
        return false
    if version >= 11 and not _valid_frontier_campaign(data.get("frontier_campaign", {}), String(campaign_world_data.get("profile", "")), int(campaign_world_data.get("map_size", 0))):
        return false
    if version >= 13:
        var supply_state = data.get("supply", null)
        if not (supply_state is Dictionary) or not supply_state.has("next_id") or not (supply_state.get("orders", null) is Array):
            return false
        if supply_state["orders"].size() > 24 or int(supply_state["next_id"]) <= 0:
            return false
        if supply_state.has("cost_source") and supply_state["cost_source"] != null:
            var saved_source: Variant = supply_state["cost_source"]
            if not (saved_source is Dictionary) or not saved_source.has("cx") or not saved_source.has("cy"):
                return false
            var cost_source_cell := Vector2i(int(saved_source["cx"]), int(saved_source["cy"]))
            if not WorldConfig.is_valid_cell(cost_source_cell):
                return false
            var cost_source_exists := false
            for saved_building in buildings:
                if not (saved_building is Dictionary):
                    continue
                var saved_cell := Vector2i(int(saved_building.get("cx", -1)), int(saved_building.get("cy", -1)))
                var saved_id := String(saved_building.get("id", ""))
                if saved_cell == cost_source_cell and ["keep", "storage", "outpost"].has(saved_id):
                    cost_source_exists = true
                    break
            if not cost_source_exists:
                return false
        if supply_state.has("pressure"):
            var pressure_states: Variant = supply_state["pressure"]
            if not (pressure_states is Array) or pressure_states.size() > 64:
                return false
            var seen_pressure_cells: Dictionary = {}
            for pressure_record in pressure_states:
                if not (pressure_record is Dictionary):
                    return false
                for key in ["cx", "cy", "contested_seconds", "warning_sent", "raid_count", "spawn_retry", "status"]:
                    if not pressure_record.has(key):
                        return false
                var pressure_cell := Vector2i(int(pressure_record["cx"]), int(pressure_record["cy"]))
                if not WorldConfig.is_valid_cell(pressure_cell):
                    return false
                var pressure_key := "%d:%d" % [pressure_cell.x, pressure_cell.y]
                if seen_pressure_cells.has(pressure_key):
                    return false
                seen_pressure_cells[pressure_key] = true
                var pressure_depot_exists := false
                for saved_building in buildings:
                    var saved_cell := Vector2i(int(saved_building.get("cx", -1)), int(saved_building.get("cy", -1)))
                    if saved_cell == pressure_cell and ["storage", "outpost", "granary"].has(String(saved_building.get("id", ""))):
                        pressure_depot_exists = true
                        break
                var contested_seconds := float(pressure_record["contested_seconds"])
                var spawn_retry := float(pressure_record["spawn_retry"])
                if not pressure_depot_exists or not is_finite(contested_seconds) or contested_seconds < 0.0 or contested_seconds > 360.0:
                    return false
                if not is_finite(spawn_retry) or spawn_retry < 0.0 or spawn_retry > 30.0:
                    return false
                if int(pressure_record["raid_count"]) < 0 or int(pressure_record["raid_count"]) > 2:
                    return false
                if not ["isolated", "exposed", "vulnerable", "raiding"].has(String(pressure_record["status"])):
                    return false
        var seen_shipment_ids: Dictionary = {}
        var reserved_capacity: Dictionary = {}
        var max_shipment_id := 0
        var active_shipment_count := 0
        for order in supply_state["orders"]:
            if not (order is Dictionary):
                return false
            for key in ["id", "source_x", "source_y", "destination_x", "destination_y", "kind", "amount", "cargo", "status", "x", "y"]:
                if not order.has(key):
                    return false
            var shipment_id := int(order["id"])
            var source_cell := Vector2i(int(order["source_x"]), int(order["source_y"]))
            var destination_cell := Vector2i(int(order["destination_x"]), int(order["destination_y"]))
            var kind := String(order["kind"])
            var amount := int(order["amount"])
            var cargo := int(order["cargo"])
            var status := String(order["status"])
            if shipment_id <= 0 or seen_shipment_ids.has(shipment_id) or source_cell == destination_cell:
                return false
            if not WorldConfig.is_valid_cell(source_cell) or not WorldConfig.is_valid_cell(destination_cell):
                return false
            if not ["wood", "stone", "food", "iron"].has(kind) or amount <= 0 or amount > 60 or cargo < 0 or cargo > amount:
                return false
            if not ["queued", "in_transit", "blocked", "delivered", "cancelled", "recovered"].has(status):
                return false
            if status in ["queued", "in_transit", "blocked"]:
                active_shipment_count += 1
                if cargo != amount:
                    return false
            if status in ["delivered", "cancelled", "recovered"] and cargo != 0:
                return false
            if not is_finite(float(order["x"])) or not is_finite(float(order["y"])):
                return false
            seen_shipment_ids[shipment_id] = true
            max_shipment_id = maxi(max_shipment_id, shipment_id)

            var destination_building: Dictionary = {}
            for saved_building in buildings:
                var saved_cell := Vector2i(int(saved_building["cx"]), int(saved_building["cy"]))
                var saved_id := String(saved_building["id"])
                if saved_cell == destination_cell and ["keep", "storage", "outpost", "granary"].has(saved_id):
                    destination_building = saved_building
            if not destination_building.is_empty() and String(destination_building["id"]) != "keep":
                var accepted_kinds: Array = DataDB.buildings[String(destination_building["id"])].get(
                    "accepted_resources", ["wood", "stone", "food", "iron"]
                )
                if not accepted_kinds.has(kind):
                    return false
            # Cargo is escrowed in the order; the source can be destroyed before delivery.
            if status in ["queued", "in_transit", "blocked"] and not destination_building.is_empty() and String(destination_building["id"]) != "keep":
                var key := "%d:%d" % [destination_cell.x, destination_cell.y]
                reserved_capacity[key] = int(reserved_capacity.get(key, 0)) + cargo

        if active_shipment_count > 8 or int(supply_state["next_id"]) <= max_shipment_id:
            return false
        for key in reserved_capacity:
            var coords := String(key).split(":")
            var destination_cell := Vector2i(int(coords[0]), int(coords[1]))
            for saved_building in buildings:
                if Vector2i(int(saved_building["cx"]), int(saved_building["cy"])) != destination_cell:
                    continue
                var capacity := int(DataDB.buildings[String(saved_building["id"])].get("stockpile_capacity", 0))
                var current_total := 0
                var saved_stockpile: Dictionary = saved_building.get("stockpile", {})
                for stock_amount in saved_stockpile.values():
                    current_total += int(stock_amount)
                if current_total + int(reserved_capacity[key]) > capacity:
                    return false
                break
    if not clock.has("t") or not clock.has("day") or not clock.has("night"):
        return false
    if not player.has("x") or not player.has("y") or not player.has("hp"):
        return false
    if version >= 6:
        var combat = player.get("combat", {})
        if not (combat is Dictionary) or not combat.has("level") or not combat.has("xp"):
            return false
        if int(combat["level"]) < 1 or int(combat["level"]) > 10 or int(combat["xp"]) < 0:
            return false

    for building in buildings:
        if not (building is Dictionary) or not building.has("id") or not building.has("cx") or not building.has("cy") or not building.has("hp"):
            return false
        if not DataDB.buildings.has(String(building["id"])):
            return false
        if version >= 12:
            var stockpile = building.get("stockpile", null)
            if not (stockpile is Dictionary):
                return false
            var stockpile_total := 0
            var stockpile_limit := int(DataDB.buildings[String(building["id"])].get("stockpile_capacity", 0))
            var allowed_stockpile_kinds: Array = DataDB.buildings[String(building["id"])].get(
                "accepted_resources", ["wood", "stone", "food", "iron"]
            )
            for kind in stockpile:
                var amount := int(stockpile[kind])
                if not allowed_stockpile_kinds.has(String(kind)) or amount < 0:
                    return false
                stockpile_total += amount
            if stockpile_total > stockpile_limit or (stockpile_total > 0 and stockpile_limit <= 0):
                return false
    var occupied_cells: Dictionary = {}
    for saved_building in buildings:
        var building_id := String(saved_building.get("id", ""))
        var building_definition: Dictionary = DataDB.buildings.get(building_id, {})
        var footprint: Array = building_definition.get("size", [1, 1])
        for y in int(footprint[1]):
            for x in int(footprint[0]):
                occupied_cells[Vector2i(int(saved_building["cx"]) + x, int(saved_building["cy"]) + y)] = true
    for saved_resource in resources:
        if saved_resource is Dictionary and saved_resource.has("cx") and saved_resource.has("cy"):
            occupied_cells[Vector2i(int(saved_resource["cx"]), int(saved_resource["cy"]))] = true
    var site_cells: Dictionary = {}
    var queue_orders: Dictionary = {}
    for saved_site in construction_sites:
        if not (saved_site is Dictionary):
            return false
        for key in ["id", "cx", "cy", "work_done", "work_required", "source_x", "source_y"]:
            if not saved_site.has(key):
                return false
        var site_id := String(saved_site["id"])
        if not DataDB.buildings.has(site_id) or site_id == "keep":
            return false
        var site_definition: Dictionary = DataDB.buildings[site_id]
        var site_size: Array = site_definition.get("size", [0, 0])
        if site_size.size() != 2 or int(site_size[0]) <= 0 or int(site_size[1]) <= 0:
            return false
        if saved_site.has("queue_order"):
            var queue_order_value: Variant = saved_site["queue_order"]
            if typeof(queue_order_value) != TYPE_INT and typeof(queue_order_value) != TYPE_FLOAT:
                return false
            var queue_order_number := float(queue_order_value)
            if not is_finite(queue_order_number) or not is_equal_approx(queue_order_number, floorf(queue_order_number)):
                return false
            var queue_order := int(queue_order_number)
            if queue_order < 0 or queue_order >= 64 or queue_orders.has(queue_order):
                return false
            queue_orders[queue_order] = true
        var work_done := float(saved_site["work_done"])
        var work_required := float(saved_site["work_required"])
        if not is_finite(work_done) or not is_finite(work_required) or work_done < 0.0 or work_required <= 0.0 or work_done >= work_required or work_required > 120.0:
            return false
        var source_cell := Vector2i(int(saved_site["source_x"]), int(saved_site["source_y"]))
        if source_cell != Vector2i(-1, -1) and not WorldConfig.is_valid_cell(source_cell):
            return false
        var site_anchor := Vector2i(int(saved_site["cx"]), int(saved_site["cy"]))
        for y in int(site_size[1]):
            for x in int(site_size[0]):
                var cell := site_anchor + Vector2i(x, y)
                if not WorldConfig.is_valid_cell(cell) or occupied_cells.has(cell) or site_cells.has(cell):
                    return false
                site_cells[cell] = true
    var outpost_guard_counts: Dictionary = {}
    for villager in villagers:
        if not (villager is Dictionary):
            return false
        for key in ["x", "y", "job", "hp", "carry", "kind"]:
            if not villager.has(key):
                return false
        if version >= 5 and (not villager.has("expedition") or not villager.has("recalling")):
            return false
        if version >= 9:
            if not villager.has("occupation") or not villager.has("military_specialization"):
                return false
            var occupation := String(villager["occupation"])
            var specialization := String(villager["military_specialization"])
            if not ["", "woodcutter", "miner", "farmer", "builder"].has(occupation):
                return false
            if not ["", "soldier"].has(specialization):
                return false
            var legacy_job := specialization if not specialization.is_empty() else occupation
            if String(villager["job"]) != legacy_job or (not occupation.is_empty() and not specialization.is_empty()):
                return false
        var guard_data: Variant = villager.get("guard_outpost", null)
        if guard_data != null:
            if not (guard_data is Dictionary) or not guard_data.has("cx") or not guard_data.has("cy"):
                return false
            if String(villager.get("job", "")) != "soldier" or bool(villager.get("expedition", false)) or bool(villager.get("recalling", false)):
                return false
            var guard_cell := Vector2i(int(guard_data["cx"]), int(guard_data["cy"]))
            var outpost_exists := false
            for saved_building in buildings:
                if String(saved_building.get("id", "")) == "outpost" and int(saved_building.get("cx", -1)) == guard_cell.x and int(saved_building.get("cy", -1)) == guard_cell.y:
                    outpost_exists = true
                    break
            if not outpost_exists:
                return false
            var guard_key := "%d:%d" % [guard_cell.x, guard_cell.y]
            outpost_guard_counts[guard_key] = int(outpost_guard_counts.get(guard_key, 0)) + 1
            var outpost_limit := int(DataDB.buildings["outpost"].get("guard_slots", 0))
            if int(outpost_guard_counts[guard_key]) > outpost_limit:
                return false
    for enemy in enemies:
        if not (enemy is Dictionary) or not enemy.has("id") or not enemy.has("x") or not enemy.has("y") or not enemy.has("hp"):
            return false
        if not DataDB.enemies.has(String(enemy["id"])):
            return false
        if version >= 10:
            var saved_faction := String(enemy.get("faction", ""))
            if not saved_faction.is_empty() and not FactionRegistry.factions.has(saved_faction) and not ["classic_raiders", "legacy_raiders"].has(saved_faction):
                return false
        if bool(enemy.get("garrison", false)) and (not enemy.has("guard_x") or not enemy.has("guard_y")):
            return false
        if enemy.has("patrol"):
            var patrol_state: Variant = enemy["patrol"]
            if not (patrol_state is Dictionary):
                return false
            if not patrol_state.is_empty():
                for key in ["camp_id", "waypoint_index", "returning"]:
                    if not patrol_state.has(key):
                        return false
                var patrol_camp_id := String(patrol_state["camp_id"])
                if not FactionRegistry.factions.has(patrol_camp_id) or not bool(enemy.get("garrison", false)):
                    return false
                var waypoint_index := int(patrol_state["waypoint_index"])
                if waypoint_index < 0 or waypoint_index > 3 or not (patrol_state["returning"] is bool):
                    return false
                var camp_state: Dictionary = data.get("frontier_campaign", {})
                var camps_state: Dictionary = camp_state.get("camps", {})
                var camp_records: Array = camps_state.get("records", [])
                var matching_camp := false
                for camp_record in camp_records:
                    if camp_record is Dictionary and String(camp_record.get("id", "")) == patrol_camp_id:
                        matching_camp = not bool(camp_record.get("destroyed", false))
                        break
                if not matching_camp:
                    return false
        if bool(enemy.get("supply_raid", false)):
            if String(enemy["id"]) != "enemy_saboteur" or not (enemy.get("raid_target", null) is Dictionary):
                return false
            var raid_target: Dictionary = enemy["raid_target"]
            if not raid_target.has("cx") or not raid_target.has("cy"):
                return false
            var raid_cell := Vector2i(int(raid_target["cx"]), int(raid_target["cy"]))
            if not WorldConfig.is_valid_cell(raid_cell) or int(enemy.get("raid_hits", 0)) < 0:
                return false
            var raid_target_exists := false
            for saved_building in buildings:
                var saved_cell := Vector2i(int(saved_building.get("cx", -1)), int(saved_building.get("cy", -1)))
                if saved_cell == raid_cell and ["storage", "outpost", "granary"].has(String(saved_building.get("id", ""))):
                    raid_target_exists = true
                    break
            if not raid_target_exists:
                return false
        if bool(enemy.get("faction_raid", false)):
            if String(campaign_world_data.get("profile", "")) != "frontier":
                return false
            if not bool(enemy.get("garrison", false)) or not (enemy.get("raid_target", null) is Dictionary):
                return false
            var faction_raid_kind := String(enemy.get("raid_kind", ""))
            var faction_raid_camp := String(enemy.get("raid_camp", ""))
            var faction_raid_region := String(enemy.get("raid_region", ""))
            if not ["depot", "road"].has(faction_raid_kind) or not FactionRegistry.factions.has(faction_raid_camp):
                return false
            if String(enemy.get("faction", "")) != faction_raid_camp:
                return false
            var faction_definition: Dictionary = FactionRegistry.factions[faction_raid_camp]
            if faction_raid_region != String(faction_definition.get("region", "")):
                return false
            if String(enemy.get("id", "")) != String(faction_definition.get("raid_unit", "")):
                return false
            var faction_raid_target: Dictionary = enemy["raid_target"]
            if not faction_raid_target.has("cx") or not faction_raid_target.has("cy") or int(enemy.get("raid_hits", 0)) < 0:
                return false
            var faction_raid_cell := Vector2i(int(faction_raid_target["cx"]), int(faction_raid_target["cy"]))
            if not WorldConfig.is_valid_cell(faction_raid_cell):
                return false
            var target_ids: Array = ["storage", "outpost", "granary"] if faction_raid_kind == "depot" else ["road", "bridge"]
            var faction_target_exists := false
            for saved_building in buildings:
                var saved_cell := Vector2i(int(saved_building.get("cx", -1)), int(saved_building.get("cy", -1)))
                if saved_cell == faction_raid_cell and target_ids.has(String(saved_building.get("id", ""))):
                    faction_target_exists = true
                    break
            if not faction_target_exists:
                return false
            var frontier_state: Dictionary = data.get("frontier_campaign", {})
            var camp_state: Dictionary = frontier_state.get("camps", {})
            var camp_records: Array = camp_state.get("records", [])
            var active_camp_found := false
            for camp_record in camp_records:
                if camp_record is Dictionary and String(camp_record.get("id", "")) == faction_raid_camp:
                    active_camp_found = not bool(camp_record.get("destroyed", false))
                    break
            if not active_camp_found:
                return false
    for job in quota:
        var allowed_jobs := ["woodcutter", "miner", "farmer", "soldier"]
        if version >= 9:
            allowed_jobs.append("builder")
        if not allowed_jobs.has(String(job)):
            return false
    if version >= 9:
        var priority = data.get("job_priority", null)
        if not (priority is Array) or priority.size() != 5:
            return false
        var unique_priority: Dictionary = {}
        for value in priority:
            var job_name := String(value)
            if not ["woodcutter", "miner", "farmer", "builder", "soldier"].has(job_name) or unique_priority.has(job_name):
                return false
            unique_priority[job_name] = true
    for resource in resources:
        if not (resource is Dictionary):
            return false
        for key in ["cx", "cy", "kind", "state"]:
            if not resource.has(key):
                return false
        if not ["wood", "stone", "iron"].has(String(resource["kind"])):
            return false
        if not (resource["state"] is Dictionary):
            return false
        if not resource["state"].has("hp") or not resource["state"].has("regrow"):
            return false
    return true


func _valid_campaign_state(value: Variant, expected_profile: String, map_size: int) -> bool:
    if not (value is Dictionary) or String(value.get("profile", "")) != expected_profile:
        return false
    var order = value.get("order", null)
    var objectives = value.get("objectives", null)
    if not (order is Array) or not (objectives is Array):
        return false
    if objectives.is_empty() or order.size() != objectives.size():
        return false
    if expected_profile == "classic" and order.size() != 1:
        return false
    if expected_profile == "frontier" and not [1, 4].has(order.size()):
        return false

    var records: Dictionary = {}
    for objective in objectives:
        if not (objective is Dictionary):
            return false
        for key in ["id", "region", "faction", "cx", "cy", "hp", "destroyed", "reinforce_timer", "spawn_index", "reward"]:
            if not objective.has(key):
                return false
        var stronghold_id := String(objective["id"])
        if stronghold_id.is_empty() or records.has(stronghold_id):
            return false
        if String(objective["region"]).is_empty() or String(objective["faction"]).is_empty():
            return false
        var cx := int(objective["cx"])
        var cy := int(objective["cy"])
        if cx < 1 or cy < 1 or cx > map_size - 4 or cy > map_size - 4:
            return false
        var destroyed := bool(objective["destroyed"])
        var hp := int(objective["hp"])
        if destroyed and hp != 0:
            return false
        if not destroyed and (hp < 1 or hp > 900):
            return false
        if float(objective["reinforce_timer"]) < 0.0 or float(objective["reinforce_timer"]) > 105.0:
            return false
        if int(objective["spawn_index"]) < 0 or int(objective["spawn_index"]) >= 36:
            return false
        if not (objective["reward"] is Dictionary):
            return false
        records[stronghold_id] = true

    var seen: Dictionary = {}
    for value_id in order:
        var stronghold_id := String(value_id)
        if not records.has(stronghold_id) or seen.has(stronghold_id):
            return false
        seen[stronghold_id] = true
    return seen.size() == records.size()




func _valid_frontier_campaign(value: Variant, expected_profile: String, map_size: int) -> bool:
    if not (value is Dictionary) or String(value.get("profile", "")) != expected_profile:
        return false
    var objectives = value.get("objectives", null)
    if not (objectives is Array):
        return false
    if expected_profile == "classic":
        return objectives.is_empty()
    if expected_profile != "frontier" or objectives.size() != DataDB.frontier_objectives.size():
        return false
    if not value.has("final_boss_defeated") or not (value["final_boss_defeated"] is bool):
        return false
    var unlocked_act := int(value.get("unlocked_act", 0))
    if unlocked_act < 1 or unlocked_act > 4:
        return false

    var expected_ids: Dictionary = {}
    for definition in DataDB.frontier_objectives:
        expected_ids[String(definition.get("id", ""))] = true
    var seen: Dictionary = {}
    for record in objectives:
        if not (record is Dictionary):
            return false
        for key in ["id", "completed", "cell_x", "cell_y", "state", "hp", "x", "y", "path_index", "saw_night"]:
            if not record.has(key):
                return false
        var objective_id := String(record["id"])
        if not expected_ids.has(objective_id) or seen.has(objective_id):
            return false
        seen[objective_id] = true
        if not (record["completed"] is bool) or not (record["saw_night"] is bool):
            return false
        var cell := Vector2i(int(record["cell_x"]), int(record["cell_y"]))
        if not ((cell == Vector2i(-1, -1)) or (cell.x >= 0 and cell.y >= 0 and cell.x < map_size and cell.y < map_size)):
            return false
        if not ["waiting", "active", "escorting", "failed", "complete"].has(String(record["state"])):
            return false
        if int(record["hp"]) < 0 or int(record["hp"]) > 500 or int(record["path_index"]) < 0:
            return false
    if seen.size() != expected_ids.size():
        return false

    if value.has("camps"):
        var camp_state: Variant = value["camps"]
        if not (camp_state is Dictionary) or not (camp_state.get("records", null) is Array):
            return false
        var camp_records: Array = camp_state["records"]
        if camp_records.size() > FactionRegistry.factions.size():
            return false
        if expected_profile == "classic" and not camp_records.is_empty():
            return false
        var camp_ids: Dictionary = {}
        for camp_record in camp_records:
            if not (camp_record is Dictionary):
                return false
            for key in ["id", "cx", "cy", "activated", "destroyed", "suppressed", "hp", "budget", "timer", "spawn_index"]:
                if not camp_record.has(key):
                    return false
            var camp_id := String(camp_record["id"])
            if not FactionRegistry.factions.has(camp_id) or camp_ids.has(camp_id):
                return false
            camp_ids[camp_id] = true
            var faction_region := String(FactionRegistry.factions[camp_id].get("region", ""))
            var camp_cell := Vector2i(int(camp_record["cx"]), int(camp_record["cy"]))
            if not WorldConfig.is_valid_cell(camp_cell):
                return false
            if String(camp_record.get("region", faction_region)) != faction_region:
                return false
            if not (camp_record["activated"] is bool) or not (camp_record["destroyed"] is bool) or not (camp_record["suppressed"] is bool):
                return false
            if int(camp_record["hp"]) < 0 or int(camp_record["hp"]) > 220:
                return false
            if bool(camp_record["destroyed"]) and (int(camp_record["hp"]) != 0 or int(camp_record["budget"]) != 0):
                return false
            if int(camp_record["budget"]) < 0 or int(camp_record["budget"]) > 12:
                return false
            if float(camp_record["timer"]) < 0.0 or float(camp_record["timer"]) > 180.0:
                return false
            if camp_record.has("raid_budget") and (int(camp_record["raid_budget"]) < 0 or int(camp_record["raid_budget"]) > 4):
                return false
            if camp_record.has("raid_timer"):
                var raid_timer := float(camp_record["raid_timer"])
                if not is_finite(raid_timer) or raid_timer < 0.0 or raid_timer > 240.0:
                    return false
            if int(camp_record["spawn_index"]) < 0:
                return false
    return true

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
