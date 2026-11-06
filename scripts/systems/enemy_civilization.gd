class_name EnemyCivilization
extends RefCounted
## Bounded autonomous economy and development plan for one rival stronghold.
## It uses an abstract workforce for now; visible buildings, resources, recruitment
## and research are persisted. It never creates free units outside recruitment costs.

const STRUCTURE_SCRIPT: Script = preload("res://scripts/entities/enemy_settlement_structure.gd")
const BUILD_PLAN: Array[Dictionary] = [
    {"id": "lumber_camp", "cost": {"wood": 50, "stone": 10}, "work": 16.0},
    {"id": "farm", "cost": {"wood": 45, "stone": 10}, "work": 18.0},
    {"id": "quarry", "cost": {"wood": 55, "stone": 22}, "work": 20.0},
    {"id": "barracks", "cost": {"wood": 80, "stone": 45, "food": 25}, "work": 25.0},
    {"id": "tower", "cost": {"wood": 40, "stone": 50}, "work": 18.0},
    {"id": "forge", "cost": {"wood": 75, "stone": 45, "iron": 12}, "work": 28.0},
    {"id": "storage", "cost": {"wood": 55, "stone": 25}, "work": 18.0}
]
const MAX_RESOURCE: float = 999.0
const STARTING_RESOURCES: Dictionary = {"wood": 100.0, "stone": 42.0, "food": 65.0, "iron": 4.0}

var owner_keep: Node2D
var resources: Dictionary = {}
var structures: Array[EnemySettlementStructure] = []
var technology_tier: int = 0
var research_progress: float = 0.0
var build_order_index: int = 0
var construction: Dictionary = {}
var _tick_accumulator: float = 0.0
var active: bool = true


func setup(keep_ref: Node2D, saved: Dictionary = {}) -> void:
    owner_keep = keep_ref
    resources = STARTING_RESOURCES.duplicate(true)
    technology_tier = clampi(int(saved.get("technology_tier", 0)), 0, 2)
    research_progress = clampf(float(saved.get("research_progress", 0.0)), 0.0, 180.0)
    build_order_index = clampi(int(saved.get("build_order_index", 0)), 0, BUILD_PLAN.size())
    _tick_accumulator = clampf(float(saved.get("tick_accumulator", 0.0)), 0.0, 0.99)
    var saved_resources: Dictionary = saved.get("resources", {})
    for kind: String in ["wood", "stone", "food", "iron"]:
        resources[kind] = clampf(float(saved_resources.get(kind, resources[kind])), 0.0, MAX_RESOURCE)

    var saved_structure_values: Array = saved.get("structures", [])
    var saved_structures: Array[Dictionary] = []
    for structure_index: int in range(saved_structure_values.size()):
        if not (saved_structure_values[structure_index] is Dictionary):
            continue
        var structure_record: Dictionary = saved_structure_values[structure_index]
        saved_structures.append(structure_record)
    for record: Dictionary in saved_structures:
        _spawn_structure(
            String(record.get("id", "")),
            Vector2i(int(record.get("cx", -1)), int(record.get("cy", -1))),
            int(record.get("hp", -1))
        )

    var saved_construction: Dictionary = saved.get("construction", {})
    if not saved_construction.is_empty():
        var saved_id: String = String(saved_construction.get("id", ""))
        var saved_plan: Dictionary = _build_plan_for(saved_id)
        var saved_cell: Vector2i = Vector2i(
            int(saved_construction.get("cx", -1)),
            int(saved_construction.get("cy", -1))
        )
        var saved_remaining: float = float(saved_construction.get("remaining", 0.0))
        if not saved_plan.is_empty() and WorldConfig.is_valid_cell(saved_cell) and is_finite(saved_remaining):
            construction = {
                "id": saved_id,
                "cx": saved_cell.x,
                "cy": saved_cell.y,
                "remaining": clampf(saved_remaining, 0.0, float(saved_plan.get("work", 1.0)))
            }
    active = bool(saved.get("active", true))


func advance(delta: float) -> void:
    if not active or owner_keep == null or not is_instance_valid(owner_keep) or int(owner_keep.get("hp")) <= 0:
        return
    _tick_accumulator += clampf(delta, 0.0, 5.0)
    var ticks: int = 0
    while _tick_accumulator >= 1.0 and ticks < 5:
        _tick_accumulator -= 1.0
        ticks += 1
        _produce_resources()
        _advance_construction(1.0)
        _advance_research(1.0)
        _try_start_construction()


func _produce_resources() -> void:
    var income: Dictionary = {"wood": 0.08, "stone": 0.025, "food": 0.42, "iron": 0.0}
    for structure: EnemySettlementStructure in structures:
        if not is_instance_valid(structure):
            continue
        match String(structure.structure_id):
            "lumber_camp":
                income["wood"] = float(income["wood"]) + 1.05
            "farm":
                income["food"] = float(income["food"]) + 1.25
            "quarry":
                income["stone"] = float(income["stone"]) + 0.62
                income["iron"] = float(income["iron"]) + 0.08
            "forge":
                income["iron"] = float(income["iron"]) + 0.22
    for kind: String in income:
        resources[kind] = clampf(float(resources.get(kind, 0.0)) + float(income[kind]), 0.0, MAX_RESOURCE)

    var garrison_count: int = 0
    if owner_keep != null and is_instance_valid(owner_keep):
        garrison_count = int(owner_keep.call("local_garrison_count"))
    resources["food"] = maxf(0.0, float(resources["food"]) - 0.025 * float(garrison_count))


func _try_start_construction() -> void:
    if not construction.is_empty() or build_order_index >= BUILD_PLAN.size():
        return
    while build_order_index < BUILD_PLAN.size():
        var plan: Dictionary = BUILD_PLAN[build_order_index]
        if _has_structure(String(plan["id"])):
            build_order_index += 1
            continue
        var anchor: Vector2i = _find_build_site(String(plan["id"]))
        if anchor.x < 0:
            return
        var cost: Dictionary = plan["cost"]
        if not _can_pay(cost):
            return
        _pay(cost)
        construction = {
            "id": String(plan["id"]),
            "cx": anchor.x,
            "cy": anchor.y,
            "remaining": float(plan["work"])
        }
        return


func _advance_construction(delta: float) -> void:
    if construction.is_empty():
        return
    var id: String = String(construction.get("id", ""))
    var anchor: Vector2i = Vector2i(int(construction.get("cx", -1)), int(construction.get("cy", -1)))
    if not _placement_valid(id, anchor):
        anchor = _find_build_site(id)
        if anchor.x < 0:
            construction["remaining"] = 5.0
            return
        construction["cx"] = anchor.x
        construction["cy"] = anchor.y
    construction["remaining"] = maxf(0.0, float(construction.get("remaining", 0.0)) - delta)
    if float(construction["remaining"]) > 0.0:
        return
    if _spawn_structure(id, anchor, -1):
        build_order_index = mini(build_order_index + 1, BUILD_PLAN.size())
        construction.clear()
        Events.build_feedback.emit("%s completed construction of %s" % [
            _faction_label(), id.replace("_", " ").to_upper()
        ])
    else:
        construction["remaining"] = 5.0


func _advance_research(delta: float) -> void:
    if technology_tier == 0:
        if not _has_structure("barracks") or not _has_structure("quarry"):
            research_progress = 0.0
            return
        research_progress += delta
        if research_progress >= 60.0 and _can_pay({"food": 50, "stone": 25}):
            _pay({"food": 50, "stone": 25})
            technology_tier = 1
            research_progress = 0.0
            Events.build_feedback.emit("%s has advanced to Military Tier II" % _faction_label())
    elif technology_tier == 1:
        if not _has_structure("forge"):
            return
        research_progress += delta
        if research_progress >= 90.0 and _can_pay({"food": 65, "stone": 45, "iron": 18}):
            _pay({"food": 65, "stone": 45, "iron": 18})
            technology_tier = 2
            research_progress = 0.0
            Events.build_feedback.emit("%s has advanced to Military Tier III" % _faction_label())


func _build_plan_for(id: String) -> Dictionary:
    for plan: Dictionary in BUILD_PLAN:
        if String(plan.get("id", "")) == id:
            return plan
    return {}


func _has_structure(id: String) -> bool:
    for structure: EnemySettlementStructure in structures:
        if is_instance_valid(structure) and String(structure.structure_id) == id:
            return true
    return false


func _can_pay(cost: Dictionary) -> bool:
    for kind: String in cost:
        if float(resources.get(String(kind), 0.0)) < float(cost[kind]):
            return false
    return true


func _pay(cost: Dictionary) -> void:
    for kind: String in cost:
        resources[kind] = maxf(0.0, float(resources.get(String(kind), 0.0)) - float(cost[kind]))


func _find_build_site(id: String) -> Vector2i:
    if owner_keep == null or not is_instance_valid(owner_keep):
        return Vector2i(-1, -1)
    var footprint: Vector2i = STRUCTURE_SCRIPT.FOOTPRINTS.get(id, Vector2i.ONE)
    for radius: int in range(4, 15):
        for y: int in range(-radius, radius + 1):
            for x: int in range(-radius, radius + 1):
                if maxi(absi(x), absi(y)) != radius:
                    continue
                var keep_cell: Vector2i = owner_keep.get("cell")
                var anchor: Vector2i = keep_cell + Vector2i(x, y)
                if _placement_valid(id, anchor, footprint):
                    return anchor
    return Vector2i(-1, -1)


func _placement_valid(id: String, anchor: Vector2i, footprint: Vector2i = Vector2i.ZERO) -> bool:
    if owner_keep == null or not is_instance_valid(owner_keep):
        return false
    var owner_world: WorldMap = owner_keep.get("world") as WorldMap
    if owner_world == null or not is_instance_valid(owner_world):
        return false
    var actual_size: Vector2i = footprint
    if actual_size == Vector2i.ZERO:
        actual_size = STRUCTURE_SCRIPT.FOOTPRINTS.get(id, Vector2i.ONE)
    if not STRUCTURE_SCRIPT.FOOTPRINTS.has(id) or not WorldConfig.is_valid_cell(anchor):
        return false
    for y: int in actual_size.y:
        for x: int in actual_size.x:
            var cell: Vector2i = anchor + Vector2i(x, y)
            if not WorldConfig.is_valid_cell(cell) or not owner_world.is_buildable(cell):
                return false
            if owner_world.occupied.has(cell):
                return false
            if String(owner_world.region_id(cell)) != String(owner_keep.get("region_id")):
                return false
    return true


func _spawn_structure(id: String, anchor: Vector2i, saved_hp: int = -1) -> bool:
    if not _placement_valid(id, anchor):
        return false
    var structure: EnemySettlementStructure = STRUCTURE_SCRIPT.new() as EnemySettlementStructure
    var owner_world: WorldMap = owner_keep.get("world") as WorldMap
    if owner_world == null or not is_instance_valid(owner_world):
        return false
    structure.setup(owner_world, owner_keep, id, anchor, saved_hp)
    owner_world.entities.add_child(structure)
    for occupied_cell: Vector2i in structure.cells():
        owner_world.occupied[occupied_cell] = structure
        Events.resource_occupancy_changed.emit(occupied_cell)
    structures.append(structure)
    return true


func on_structure_destroyed(structure: EnemySettlementStructure) -> void:
    structures.erase(structure)


func garrison_capacity() -> int:
    var capacity: int = 4
    if _has_structure("barracks"):
        capacity += 2
    capacity += technology_tier
    return clampi(capacity, 4, 8)


func can_recruit() -> bool:
    return _can_pay(_recruitment_cost())


func pay_recruitment() -> bool:
    var cost: Dictionary = _recruitment_cost()
    if not _can_pay(cost):
        return false
    _pay(cost)
    return true


func _recruitment_cost() -> Dictionary:
    var cost: Dictionary = {"food": 10.0, "wood": 4.0}
    if technology_tier >= 1:
        cost["iron"] = 1.0
    return cost


func on_keep_destroyed() -> void:
    active = false
    construction.clear()
    for structure: EnemySettlementStructure in structures:
        if is_instance_valid(structure):
            structure.on_keep_destroyed()


func export_state() -> Dictionary:
    var structure_records: Array[Dictionary] = []
    for structure: EnemySettlementStructure in structures:
        if not is_instance_valid(structure):
            continue
        structure_records.append({
            "id": String(structure.structure_id),
            "cx": int(structure.cell.x),
            "cy": int(structure.cell.y),
            "hp": int(structure.hp)
        })
    return {
        "resources": resources.duplicate(true),
        "structures": structure_records,
        "technology_tier": technology_tier,
        "research_progress": research_progress,
        "build_order_index": build_order_index,
        "construction": construction.duplicate(true),
        "tick_accumulator": _tick_accumulator,
        "active": active
    }


func _faction_label() -> String:
    if owner_keep == null or not is_instance_valid(owner_keep):
        return "Rival civilization"
    var faction_id: String = String(owner_keep.get("faction_id"))
    if FactionRegistry.factions.has(faction_id):
        return String(FactionRegistry.factions[faction_id].get("name", faction_id))
    return "Rival civilization"
