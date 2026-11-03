extends RefCounted
## Owns selected cost-source reads, validation, payment and refunds.
## SupplyNetwork remains the public gameplay façade and save-state owner.

const RESOURCE_KINDS: Array[String] = ["wood", "stone", "food", "iron"]

var network


func configure(supply_network: Node) -> void:
    network = supply_network


func get_cost_source_cell() -> Vector2i:
    var source = _selected_cost_depot()
    return source.cell if source != null else Vector2i(-1, -1)


func _selected_cost_depot():
    if network == null or not is_instance_valid(network):
        return null
    network._ensure_current()
    if network._cost_source_cell != Vector2i(-1, -1):
        var selected = network._find_depot(network._cost_source_cell)
        if selected != null:
            return selected
    return network._find_keep()


func set_cost_source(cell: Vector2i) -> bool:
    if network == null or not is_instance_valid(network):
        return false
    if not WorldConfig.is_frontier_profile():
        return cell == get_cost_source_cell()
    network._ensure_current()
    var depot = network._find_depot(cell)
    if depot == null or not ["keep", "storage", "outpost"].has(String(depot.id)):
        return false
    if not network.is_depot_connected(depot):
        return false
    if network._cost_source_cell == cell:
        return true
    network._cost_source_cell = cell
    Events.supply_cost_source_changed.emit()
    return true


func cost_source_label() -> String:
    var source = _selected_cost_depot()
    if source == null:
        return "KEEP"
    var label := "KEEP" if String(source.id) == "keep" else (
        "POS %d,%d" % [source.cell.x, source.cell.y] if String(source.id) == "outpost"
        else "GUDANG %d,%d" % [source.cell.x, source.cell.y]
    )
    if WorldConfig.is_frontier_profile() and not network.is_depot_connected(source):
        label += " · JALUR PUTUS"
    return label


func cost_source_amount(kind: String) -> int:
    if not WorldConfig.is_frontier_profile():
        return Inventory.get_amount(kind)
    var source = _selected_cost_depot()
    if source == null or not network.is_depot_connected(source):
        return 0
    return Inventory.get_amount(kind) if String(source.id) == "keep" else source.stockpile_amount(kind)


func cost_reason(cost: Dictionary) -> String:
    if not WorldConfig.is_frontier_profile():
        return "" if Inventory.can_afford(cost) else "Bahan kurang di KEEP"
    var source = _selected_cost_depot()
    if source == null:
        return "Depot sumber biaya tidak tersedia"
    if not network.is_depot_connected(source):
        return "Jalur ke sumber biaya terputus"
    for kind in cost:
        var amount := int(cost[kind])
        if amount < 0:
            return "Biaya bahan tidak valid"
        if amount == 0:
            continue
        if String(source.id) != "keep" and not RESOURCE_KINDS.has(String(kind)):
            return "Jenis bahan tidak tersedia di depot lokal"
        var available: int = Inventory.get_amount(String(kind)) if String(source.id) == "keep" else int(source.stockpile_amount(String(kind)))
        if available < amount:
            return "Bahan kurang di " + cost_source_label()
    return ""


func refund_cost_to_source(source_cell: Vector2i, refund: Dictionary) -> void:
    if network == null or not is_instance_valid(network):
        return
    var source = network._find_depot(source_cell)
    if source == null or not ["keep", "storage", "outpost"].has(String(source.id)):
        source = network._find_keep()
    for kind in refund:
        var amount := int(refund[kind])
        if amount <= 0:
            continue
        if source != null and String(source.id) != "keep":
            if source.store_resource(String(kind), amount):
                continue
        Inventory.add(String(kind), amount)
    Events.supply_stock_changed.emit()


func can_pay_cost(cost: Dictionary) -> bool:
    return cost_reason(cost) == ""


func pay_cost(cost: Dictionary) -> bool:
    if network == null or not is_instance_valid(network) or cost_reason(cost) != "":
        return false
    var source = _selected_cost_depot()
    if not WorldConfig.is_frontier_profile() or source == null or String(source.id) == "keep":
        return Inventory.spend_all(cost)
    var paid: Dictionary = {}
    for kind in cost:
        var resource := String(kind)
        var amount := int(cost[kind])
        if amount <= 0:
            continue
        if not source.take_resource(resource, amount):
            for paid_kind in paid:
                source.store_resource(String(paid_kind), int(paid[paid_kind]))
            return false
        paid[resource] = amount
    Events.supply_stock_changed.emit()
    return true
