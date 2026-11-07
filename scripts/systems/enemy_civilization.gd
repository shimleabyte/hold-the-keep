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
## Rival factions now use different economic investment sequences. Each order contains
## the same buildings and costs; doctrine changes opportunity cost, not resource supply.
const DEFAULT_BUILD_ORDER: Array[String] = [
    "lumber_camp", "farm", "quarry", "barracks", "tower", "forge", "storage"
]
const DOCTRINE_BUILD_ORDERS: Dictionary = {
    "ambush": [
        "lumber_camp", "quarry", "barracks", "farm", "tower", "forge", "storage"
    ],
    "fortress": [
        "lumber_camp", "quarry", "tower", "farm", "barracks", "storage", "forge"
    ],
    "attrition": [
        "farm", "lumber_camp", "quarry", "storage", "barracks", "tower", "forge"
    ],
    "siege": [
        "quarry", "lumber_camp", "farm", "barracks", "forge", "tower", "storage"
    ]
}
const WORKFORCE_CAPACITY: int = 8
const MIN_WORKFORCE: int = 2
const WORKERS_PER_WORKPLACE: int = 2
const WORKER_FOOD_UPKEEP: float = 0.04
const SOLDIER_FOOD_UPKEEP: float = 0.06
const DEFAULT_LABOR_ORDER: Array[String] = ["lumber_camp", "quarry", "farm", "forge"]
const DOCTRINE_LABOR_ORDERS: Dictionary = {
    "ambush": ["lumber_camp", "quarry", "farm", "forge"],
    "fortress": ["quarry", "lumber_camp", "farm", "forge"],
    "attrition": ["farm", "lumber_camp", "quarry", "forge"],
    "siege": ["quarry", "forge", "lumber_camp", "farm"]
}
const DEFAULT_RECRUITMENT_ROSTER: Array[String] = ["bandit", "archer", "brute"]
const DEFAULT_RECRUITMENT_WEIGHTS: Dictionary = {
    "bandit": 0.45, "archer": 0.35, "brute": 0.20
}
const DOCTRINE_RECRUITMENT_WEIGHTS: Dictionary = {
    "ambush": {
        "bandit": 0.35, "enemy_scout": 0.25, "enemy_saboteur": 0.20,
        "enemy_beast_rider": 0.20
    },
    "fortress": {
        "enemy_shieldbearer": 0.40, "archer": 0.35, "enemy_siege_engine": 0.25
    },
    "attrition": {
        "wolf": 0.35, "enemy_war_shaman": 0.25,
        "enemy_scout": 0.20, "enemy_beast_rider": 0.20
    },
    "siege": {
        "enemy_siege_engine": 0.40, "enemy_shieldbearer": 0.25,
        "enemy_war_shaman": 0.20, "enemy_saboteur": 0.15
    }
}
const RECRUITMENT_COSTS: Dictionary = {
    "bandit": {"food": 10.0, "wood": 4.0},
    "enemy_scout": {"food": 10.0, "wood": 4.0},
    "enemy_saboteur": {"food": 14.0, "wood": 6.0, "iron": 1.0},
    "enemy_beast_rider": {"food": 18.0, "wood": 8.0, "iron": 2.0},
    "enemy_shieldbearer": {"food": 14.0, "wood": 5.0, "stone": 4.0, "iron": 1.0},
    "archer": {"food": 11.0, "wood": 6.0},
    "enemy_siege_engine": {"food": 20.0, "wood": 10.0, "stone": 12.0, "iron": 3.0},
    "wolf": {"food": 8.0},
    "enemy_war_shaman": {"food": 16.0, "wood": 6.0, "iron": 1.0}
}
const RECRUITMENT_MIN_TECH_TIER: Dictionary = {
    "enemy_saboteur": 1,
    "enemy_war_shaman": 1,
    "enemy_beast_rider": 2,
    "enemy_siege_engine": 2
}
const BASE_STORAGE_CAPACITY: float = 240.0
const STORAGE_BUILDING_BONUS: float = 360.0
const MAX_RESOURCE: float = 999.0
const STARTING_RESOURCES: Dictionary = {"wood": 100.0, "stone": 42.0, "food": 65.0, "iron": 4.0}

var owner_keep: Node2D
var resources: Dictionary = {}
var structures: Array[EnemySettlementStructure] = []
## Saved structures that could not be placed because the reconstructed map is occupied.
var pending_structures: Array[Dictionary] = []
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

    pending_structures.clear()
    var saved_structure_values: Variant = saved.get("structures", [])
    _restore_saved_structure_records(saved_structure_values)
    var saved_pending_values: Variant = saved.get("pending_structures", [])
    _restore_saved_structure_records(saved_pending_values)

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
    _reconcile_build_order_index()


func advance(delta: float) -> void:
    if not active or owner_keep == null or not is_instance_valid(owner_keep) or int(owner_keep.get("hp")) <= 0:
        return
    _tick_accumulator += clampf(delta, 0.0, 5.0)
    var ticks: int = 0
    while _tick_accumulator >= 1.0 and ticks < 5:
        _tick_accumulator -= 1.0
        ticks += 1
        _restore_pending_structures()
        _produce_resources()
        _advance_construction(1.0)
        _advance_research(1.0)
        _try_start_construction()


static func workforce_for_garrison(garrison_count: int) -> int:
    return clampi(WORKFORCE_CAPACITY - maxi(0, garrison_count), MIN_WORKFORCE, WORKFORCE_CAPACITY)


func workforce_size() -> int:
    var garrison_count: int = 0
    if owner_keep != null and is_instance_valid(owner_keep):
        garrison_count = int(owner_keep.call("local_garrison_count"))
    return workforce_for_garrison(garrison_count)


func labor_order() -> Array[String]:
    var faction_id: String = String(owner_keep.get("faction_id")) if owner_keep != null else ""
    var faction: Dictionary = FactionRegistry.factions.get(faction_id, {})
    var doctrine: String = String(faction.get("doctrine", ""))
    var selected_order: Variant = DOCTRINE_LABOR_ORDERS.get(doctrine, DEFAULT_LABOR_ORDER)
    var candidates: Array = DEFAULT_LABOR_ORDER
    if selected_order is Array:
        candidates = selected_order

    var order: Array[String] = []
    for raw_id: Variant in candidates:
        var id: String = String(raw_id)
        if ["lumber_camp", "farm", "quarry", "forge"].has(id) and not order.has(id):
            order.append(id)
    for fallback_id: String in DEFAULT_LABOR_ORDER:
        if not order.has(fallback_id):
            order.append(fallback_id)
    return order


func _has_active_structure(id: String) -> bool:
    for structure: EnemySettlementStructure in structures:
        if is_instance_valid(structure) and String(structure.structure_id) == id:
            return true
    return false


func storage_capacity(has_storage: bool) -> float:
    return BASE_STORAGE_CAPACITY + STORAGE_BUILDING_BONUS if has_storage else BASE_STORAGE_CAPACITY


func resource_capacity(kind: String) -> float:
    if not ["wood", "stone", "food", "iron"].has(kind):
        return 0.0
    return storage_capacity(_has_active_structure("storage"))


func _workplace_has_storage_room(workplace_id: String) -> bool:
    match workplace_id:
        "lumber_camp":
            return float(resources.get("wood", 0.0)) < resource_capacity("wood")
        "farm":
            return float(resources.get("food", 0.0)) < resource_capacity("food")
        "quarry":
            return (
                float(resources.get("stone", 0.0)) < resource_capacity("stone")
                or float(resources.get("iron", 0.0)) < resource_capacity("iron")
            )
        "forge":
            return float(resources.get("iron", 0.0)) < resource_capacity("iron")
    return false


func _credit_income(kind: String, amount: float) -> float:
    var current: float = maxf(0.0, float(resources.get(kind, 0.0)))
    var capacity: float = resource_capacity(kind)
    # Preserve existing v17 over-cap balances; they simply stop receiving income
    # until spending brings the balance under the active storage limit.
    var room: float = maxf(0.0, capacity - current)
    var credited: float = minf(maxf(0.0, amount), room)
    resources[kind] = current + credited
    return credited


func labor_allocation() -> Dictionary:
    var garrison_count: int = 0
    if owner_keep != null and is_instance_valid(owner_keep):
        garrison_count = int(owner_keep.call("local_garrison_count"))
    var remaining: int = workforce_for_garrison(garrison_count)
    var allocation: Dictionary = {
        "available": remaining,
        "garrison": garrison_count,
        "builders": 0,
        "lumber_camp": 0,
        "farm": 0,
        "quarry": 0,
        "forge": 0,
        "idle": 0
    }

    # Construction takes precedence. The same citizens cannot gather and build
    # during the same simulation tick.
    if not construction.is_empty():
        var builders: int = mini(WORKERS_PER_WORKPLACE, remaining)
        allocation["builders"] = builders
        remaining -= builders

    for workplace_id: String in labor_order():
        if remaining <= 0:
            break
        if not _has_active_structure(workplace_id) or not _workplace_has_storage_room(workplace_id):
            continue
        var assigned: int = mini(WORKERS_PER_WORKPLACE, remaining)
        allocation[workplace_id] = assigned
        remaining -= assigned

    allocation["idle"] = remaining
    return allocation


func _produce_resources() -> void:
    var labor: Dictionary = labor_allocation()
    var income: Dictionary = {
        "wood": 0.08 + 0.525 * float(labor["lumber_camp"]),
        "stone": 0.025 + 0.31 * float(labor["quarry"]),
        "food": 0.42 + 0.625 * float(labor["farm"]),
        "iron": 0.04 * float(labor["quarry"]) + 0.11 * float(labor["forge"])
    }
    for kind: String in income:
        _credit_income(kind, float(income[kind]))

    # A fixed population pool makes recruitment an economic trade-off:
    # each living garrison soldier removes one available worker and costs more food.
    var worker_upkeep: float = WORKER_FOOD_UPKEEP * float(labor["available"])
    var soldier_upkeep: float = SOLDIER_FOOD_UPKEEP * float(labor["garrison"])
    resources["food"] = maxf(0.0, float(resources["food"]) - worker_upkeep - soldier_upkeep)


func _try_start_construction() -> void:
    if not construction.is_empty():
        return
    _reconcile_build_order_index()
    var order: Array[String] = development_order()
    if build_order_index >= order.size():
        return

    var id: String = order[build_order_index]
    var plan: Dictionary = _build_plan_for(id)
    if plan.is_empty():
        return
    var anchor: Vector2i = _find_build_site(id)
    if anchor.x < 0:
        return
    var cost: Dictionary = plan["cost"]
    if not _can_pay(cost):
        return
    _pay(cost)
    construction = {
        "id": id,
        "cx": anchor.x,
        "cy": anchor.y,
        "remaining": float(plan["work"])
    }


func _advance_construction(delta: float) -> void:
    if construction.is_empty():
        return
    var labor: Dictionary = labor_allocation()
    var builder_count: int = int(labor.get("builders", 0))
    if builder_count <= 0:
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
    var construction_rate: float = 0.5 * float(builder_count)
    construction["remaining"] = maxf(
        0.0, float(construction.get("remaining", 0.0)) - delta * construction_rate
    )
    if float(construction["remaining"]) > 0.0:
        return
    if _spawn_structure(id, anchor, -1):
        construction.clear()
        _reconcile_build_order_index()
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


func development_order() -> Array[String]:
    var faction_id: String = String(owner_keep.get("faction_id")) if owner_keep != null else ""
    var faction: Dictionary = FactionRegistry.factions.get(faction_id, {})
    var doctrine: String = String(faction.get("doctrine", ""))
    var selected_order: Variant = DOCTRINE_BUILD_ORDERS.get(doctrine, DEFAULT_BUILD_ORDER)
    var candidates: Array = DEFAULT_BUILD_ORDER
    if selected_order is Array:
        candidates = selected_order

    var order: Array[String] = []
    for raw_id: Variant in candidates:
        var id: String = String(raw_id)
        if id.is_empty() or order.has(id) or _build_plan_for(id).is_empty():
            continue
        order.append(id)
    # Defensively append any future building omitted by a doctrine definition.
    for plan: Dictionary in BUILD_PLAN:
        var fallback_id: String = String(plan.get("id", ""))
        if not fallback_id.is_empty() and not order.has(fallback_id):
            order.append(fallback_id)
    return order


func _reconcile_build_order_index() -> void:
    var order: Array[String] = development_order()
    if not construction.is_empty():
        var active_index: int = order.find(String(construction.get("id", "")))
        if active_index >= 0:
            build_order_index = active_index
            return
    for index: int in range(order.size()):
        if not _has_structure(order[index]):
            build_order_index = index
            return
    build_order_index = order.size()


func _has_structure(id: String) -> bool:
    for structure: EnemySettlementStructure in structures:
        if is_instance_valid(structure) and String(structure.structure_id) == id:
            return true
    for record: Dictionary in pending_structures:
        if String(record.get("id", "")) == id:
            return true
    return false


func _restore_saved_structure_records(values: Variant) -> void:
    if not (values is Array):
        return
    for value: Variant in values:
        if not (value is Dictionary):
            continue
        var record: Dictionary = value
        if not _try_restore_saved_structure(record):
            pending_structures.append({
                "id": String(record.get("id", "")),
                "cx": int(record.get("cx", -1)),
                "cy": int(record.get("cy", -1)),
                "hp": int(record.get("hp", -1))
            })


func _restore_pending_structures() -> void:
    if pending_structures.is_empty():
        return
    var still_pending: Array[Dictionary] = []
    for record: Dictionary in pending_structures:
        if not _try_restore_saved_structure(record):
            still_pending.append(record)
    pending_structures = still_pending


func _try_restore_saved_structure(record: Dictionary) -> bool:
    var id: String = String(record.get("id", ""))
    if not STRUCTURE_SCRIPT.FOOTPRINTS.has(id):
        return false
    var saved_cell := Vector2i(int(record.get("cx", -1)), int(record.get("cy", -1)))
    var saved_hp := int(record.get("hp", -1))
    if _spawn_structure(id, saved_cell, saved_hp):
        return true
    # A player building, resource node, or another restored entity may now occupy
    # the old footprint. Preserve the structure by relocating it within its owner region.
    var replacement_cell := _find_build_site(id)
    if replacement_cell.x >= 0 and _spawn_structure(id, replacement_cell, saved_hp):
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
    # A destroyed priority building becomes eligible for reconstruction. If another
    # project is already active, its completion will reconcile the missing structure.
    _reconcile_build_order_index()


func garrison_capacity() -> int:
    var capacity: int = 4
    if _has_structure("barracks"):
        capacity += 2
    capacity += technology_tier
    return clampi(capacity, 4, 8)


func can_recruit(unit_id: String = "") -> bool:
    if not unit_id.is_empty():
        var required_tier: int = int(RECRUITMENT_MIN_TECH_TIER.get(unit_id, 0))
        if technology_tier < required_tier:
            return false
    return _can_pay(_recruitment_cost(unit_id))


func pay_recruitment(unit_id: String = "") -> bool:
    if not can_recruit(unit_id):
        return false
    _pay(_recruitment_cost(unit_id))
    return true


func recruitment_cost_for(unit_id: String) -> Dictionary:
    return _recruitment_cost(unit_id).duplicate(true)


func _recruitment_cost(unit_id: String = "") -> Dictionary:
    if not unit_id.is_empty() and RECRUITMENT_COSTS.has(unit_id):
        var configured_cost: Dictionary = RECRUITMENT_COSTS[unit_id]
        return configured_cost.duplicate(true)
    var cost: Dictionary = {"food": 10.0, "wood": 4.0}
    if technology_tier >= 1:
        cost["iron"] = 1.0
    return cost


func choose_recruitment_unit(existing_unit_ids: Array[String]) -> String:
    var faction_id: String = String(owner_keep.get("faction_id")) if owner_keep != null else ""
    var faction: Dictionary = FactionRegistry.factions.get(faction_id, {})
    var doctrine: String = String(faction.get("doctrine", ""))
    var roster: Array[String] = FactionRegistry.roster_for(faction_id)
    var weights: Dictionary = DOCTRINE_RECRUITMENT_WEIGHTS.get(
        doctrine, DEFAULT_RECRUITMENT_WEIGHTS
    )
    if roster.is_empty():
        for fallback_id: String in DEFAULT_RECRUITMENT_ROSTER:
            roster.append(fallback_id)
        weights = DEFAULT_RECRUITMENT_WEIGHTS

    if roster.is_empty():
        return ""

    var counts: Dictionary = {}
    for unit_id: String in roster:
        counts[unit_id] = 0
    for existing_id: String in existing_unit_ids:
        counts[existing_id] = int(counts.get(existing_id, 0)) + 1

    var total_after_recruitment: float = float(existing_unit_ids.size() + 1)
    var selected_id: String = ""
    var selected_score: float = -INF
    for unit_id: String in roster:
        if not DataDB.enemies.has(unit_id) or not can_recruit(unit_id):
            continue
        var target_share: float = maxf(0.0, float(weights.get(unit_id, 0.0)))
        if target_share <= 0.0:
            continue
        var score: float = target_share * total_after_recruitment - float(counts.get(unit_id, 0))
        if score > selected_score:
            selected_score = score
            selected_id = unit_id
    return selected_id


func on_keep_destroyed() -> void:
    active = false
    construction.clear()
    pending_structures.clear()
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
        "pending_structures": pending_structures.duplicate(true),
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
