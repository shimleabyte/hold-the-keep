extends RefCounted
## Owns depot management, cost-source selection and physical shipment UI.

const HUD_WIDGETS := preload("res://scripts/ui/hud_widgets.gd")
const GOLD := Color("#ffd23f")

var _hud: Variant
var _icons: Dictionary


func configure(hud: Variant, icons: Dictionary) -> void:
    _hud = hud
    _icons = icons


func _build_outpost_panel() -> void:
    _hud._outpost_backdrop = ColorRect.new()
    _hud._outpost_backdrop.color = Color(0.015, 0.02, 0.028, 0.84)
    _hud._outpost_backdrop.size = _hud._viewport_size
    _hud._outpost_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    _hud._outpost_backdrop.gui_input.connect(_on_outpost_backdrop_input)
    _hud._outpost_backdrop.visible = false
    _hud.add_child(_hud._outpost_backdrop)
    _hud._blockers.append(_hud._outpost_backdrop)

    _hud._outpost_panel = _hud._panel(Vector2.ZERO, Vector2(356, 238))
    _hud._outpost_panel.visible = false
    var title: Label = _hud._label(_hud._outpost_panel, "LOGISTIK & GARRISON", Vector2(10, 7), GOLD)
    title.add_theme_font_size_override("font_size", 9)

    var close := HUD_WIDGETS.HudChip.new()
    close.label = "X"
    close.font = _hud._font
    close.position = Vector2(330, 4)
    close.size = Vector2(19, 15)
    close.pressed.connect(_toggle_outposts)
    _hud._outpost_panel.add_child(close)

    var source_hint: Label = _hud._label(_hud._outpost_panel, "SUMBER BIAYA", Vector2(10, 22), Color("#c9b99d"))
    source_hint.add_theme_font_size_override("font_size", 6)
    source_hint.size = Vector2(88, 12)

    _hud._cost_source_option = OptionButton.new()
    _hud._cost_source_option.position = Vector2(96, 19)
    _hud._cost_source_option.size = Vector2(252, 18)
    _hud._cost_source_option.add_theme_font_override("font", _hud._font)
    _hud._cost_source_option.add_theme_font_size_override("font_size", 7)
    _hud._cost_source_option.tooltip_text = "Konstruksi dan riset membayar seluruh biaya dari depot ini saja."
    _hud._cost_source_option.item_selected.connect(_on_cost_source_selected)
    _hud._outpost_panel.add_child(_hud._cost_source_option)

    var depot_scroll := ScrollContainer.new()
    depot_scroll.position = Vector2(8, 39)
    depot_scroll.size = Vector2(340, 66)
    depot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    depot_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    _hud._outpost_panel.add_child(depot_scroll)

    _hud._outpost_list = VBoxContainer.new()
    _hud._outpost_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _hud._outpost_list.add_theme_constant_override("separation", 3)
    depot_scroll.add_child(_hud._outpost_list)

    var shipment_title: Label = _hud._label(_hud._outpost_panel, "PERINTAH ANGKUT FISIK", Vector2(10, 105), GOLD)
    shipment_title.add_theme_font_size_override("font_size", 7)
    _hud._label(_hud._outpost_panel, "ASAL", Vector2(10, 116), Color("#c9b99d")).add_theme_font_size_override("font_size", 6)
    _hud._label(_hud._outpost_panel, "TUJUAN", Vector2(183, 116), Color("#c9b99d")).add_theme_font_size_override("font_size", 6)

    _hud._shipment_source = OptionButton.new()
    _hud._shipment_source.position = Vector2(8, 126)
    _hud._shipment_source.size = Vector2(166, 18)
    _hud._shipment_source.add_theme_font_override("font", _hud._font)
    _hud._shipment_source.add_theme_font_size_override("font_size", 7)
    _hud._shipment_source.item_selected.connect(_on_shipment_endpoint_selected)
    _hud._outpost_panel.add_child(_hud._shipment_source)

    _hud._shipment_destination = OptionButton.new()
    _hud._shipment_destination.position = Vector2(180, 126)
    _hud._shipment_destination.size = Vector2(168, 18)
    _hud._shipment_destination.add_theme_font_override("font", _hud._font)
    _hud._shipment_destination.add_theme_font_size_override("font_size", 7)
    _hud._shipment_destination.item_selected.connect(_on_shipment_endpoint_selected)
    _hud._outpost_panel.add_child(_hud._shipment_destination)

    _hud._shipment_kind = OptionButton.new()
    _hud._shipment_kind.position = Vector2(8, 150)
    _hud._shipment_kind.size = Vector2(116, 19)
    _hud._shipment_kind.add_theme_font_override("font", _hud._font)
    _hud._shipment_kind.add_theme_font_size_override("font_size", 7)
    for kind in ["wood", "stone", "food", "iron"]:
        _hud._shipment_kind.add_item(kind.to_upper())
        _hud._shipment_kind.set_item_metadata(_hud._shipment_kind.item_count - 1, kind)
    _hud._shipment_kind.select(0)
    _hud._outpost_panel.add_child(_hud._shipment_kind)

    _hud._shipment_amount = SpinBox.new()
    _hud._shipment_amount.position = Vector2(130, 150)
    _hud._shipment_amount.size = Vector2(76, 19)
    _hud._shipment_amount.min_value = 1
    _hud._shipment_amount.max_value = 60
    _hud._shipment_amount.step = 1
    _hud._shipment_amount.value = 6
    _hud._shipment_amount.add_theme_font_override("font", _hud._font)
    _hud._shipment_amount.add_theme_font_size_override("font_size", 7)
    _hud._outpost_panel.add_child(_hud._shipment_amount)

    _hud._shipment_send_button = Button.new()
    _hud._shipment_send_button.text = "BUAT ORDER"
    _hud._shipment_send_button.position = Vector2(212, 150)
    _hud._shipment_send_button.size = Vector2(136, 19)
    _hud._shipment_send_button.add_theme_font_override("font", _hud._font)
    _hud._shipment_send_button.add_theme_font_size_override("font_size", 7)
    _hud._shipment_send_button.pressed.connect(_create_shipment_order)
    _hud._outpost_panel.add_child(_hud._shipment_send_button)

    _hud._label(_hud._outpost_panel, "STATUS PENGIRIMAN", Vector2(10, 174), Color("#c9b99d")).add_theme_font_size_override("font_size", 6)
    var order_scroll := ScrollContainer.new()
    order_scroll.position = Vector2(8, 184)
    order_scroll.size = Vector2(340, 46)
    order_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    order_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    _hud._outpost_panel.add_child(order_scroll)

    _hud._shipment_orders_list = VBoxContainer.new()
    _hud._shipment_orders_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _hud._shipment_orders_list.add_theme_constant_override("separation", 2)
    order_scroll.add_child(_hud._shipment_orders_list)
    _refresh_outpost_panel()

func _on_outpost_backdrop_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _toggle_outposts()


func _refresh_outpost_panel() -> void:
    if _hud._outpost_list == null:
        return
    for child in _hud._outpost_list.get_children():
        child.free()

    var structures: Array = []
    for depot in _hud.get_tree().get_nodes_in_group("depots"):
        if is_instance_valid(depot) and ["outpost", "storage", "granary"].has(String(depot.id)):
            structures.append(depot)
    for garrison in _hud.get_tree().get_nodes_in_group("garrisons"):
        if is_instance_valid(garrison) and String(garrison.id) == "barracks":
            structures.append(garrison)
    for archery_range in _hud.get_tree().get_nodes_in_group("archery_ranges"):
        if is_instance_valid(archery_range):
            structures.append(archery_range)
    structures.sort_custom(func(a, b) -> bool:
        var priority := {"outpost": 0, "barracks": 1, "archery_range": 2, "storage": 3, "granary": 4}
        if String(a.id) != String(b.id):
            return int(priority.get(String(a.id), 5)) < int(priority.get(String(b.id), 5))
        if a.cell.y != b.cell.y:
            return a.cell.y < b.cell.y
        return a.cell.x < b.cell.x
    )

    if structures.is_empty():
        var empty: Label = _hud._label(_hud._outpost_list, "Belum ada Outpost, Barak, Lapangan Panah, Storage, atau Lumbung.", Vector2.ZERO, Color("#c9b99d"))
        empty.add_theme_font_size_override("font_size", 8)
    else:
        for structure in structures:
            var row := HBoxContainer.new()
            row.custom_minimum_size = Vector2(276, 38)
            row.add_theme_constant_override("separation", 5)
            _hud._outpost_list.add_child(row)

            var details := VBoxContainer.new()
            details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            details.add_theme_constant_override("separation", 1)
            row.add_child(details)

            var structure_id := String(structure.id)
            var is_garrison := ["outpost", "barracks"].has(structure_id)
            var is_archery_range := structure_id == "archery_range"
            var heading := Label.new()
            heading.add_theme_font_override("font", _hud._font)
            heading.add_theme_font_size_override("font_size", 7)
            heading.add_theme_color_override("font_color", Color("#f0d39a"))
            if structure_id == "outpost":
                heading.text = "POS %d,%d  ·  PENJAGA %d/%d" % [structure.cell.x, structure.cell.y, structure.guard_count(), structure.guard_capacity]
            elif structure_id == "barracks":
                heading.text = "BARAK %d,%d  ·  GARRISON %d/%d" % [structure.cell.x, structure.cell.y, structure.guard_count(), structure.guard_capacity]
            elif is_archery_range:
                var workplace_data: Dictionary = structure.data.get("workplaces", {})
                var capacity := int(workplace_data.get("archer", 0))
                var assigned: int = capacity - structure.free_slots("archer")
                heading.text = "LAPANGAN PANAH %d,%d  ·  PEMANAH %d/%d" % [structure.cell.x, structure.cell.y, assigned, capacity]
            elif structure_id == "granary":
                heading.text = "LUMBUNG %d,%d" % [structure.cell.x, structure.cell.y]
            else:
                heading.text = "GUDANG %d,%d" % [structure.cell.x, structure.cell.y]
            var main_node = _hud.get_tree().get_first_node_in_group("main")
            if structure.is_in_group("depots") and main_node != null and main_node.supply != null:
                var pressure: Dictionary = main_node.supply.depot_pressure_state(structure)
                var pressure_status := String(pressure.get("status", "connected"))
                var pressure_label := String(pressure.get("label", ""))
                if pressure_status != "connected":
                    heading.text += " · " + pressure_label
                    heading.add_theme_color_override("font_color", Color("#ef8e73") if pressure_status in ["vulnerable", "raiding"] else Color("#d6b36d"))
                heading.tooltip_text = "Pemulihan: sambungkan jalan ke Keep atau amankan wilayah. Penjaga Outpost dapat menahan saboteur; Builder dapat memperbaiki depot menggunakan sumber biaya aktif."
            details.add_child(heading)

            var stock := Label.new()
            stock.add_theme_font_override("font", _hud._font)
            stock.add_theme_font_size_override("font_size", 6)
            stock.add_theme_color_override("font_color", Color("#c4c0b5"))
            if structure_id == "barracks":
                stock.text = "EMPAT SLOT PENJAGA  ·  RADIUS %d" % int(structure.data.get("guard_radius", 128))
            elif is_archery_range:
                stock.text = "DUA SLOT PEMANAH  ·  JARAK TEMBAK 150"
            elif structure_id == "granary":
                stock.text = "PANGAN %d / %d" % [structure.stockpile_amount("food"), structure.stockpile_capacity]
            else:
                stock.text = "KAYU %d  BATU %d  PANGAN %d  BESI %d  / %d" % [
                    structure.stockpile_amount("wood"), structure.stockpile_amount("stone"),
                    structure.stockpile_amount("food"), structure.stockpile_amount("iron"),
                    structure.stockpile_capacity
                ]
            details.add_child(stock)

            if is_garrison:
                var release := Button.new()
                release.text = "-"
                release.custom_minimum_size = Vector2(25, 22)
                release.disabled = structure.guard_count() <= 0
                release.tooltip_text = "Tarik satu penjaga dari " + ("Barak" if structure_id == "barracks" else "Outpost")
                release.add_theme_font_override("font", _hud._font)
                release.add_theme_font_size_override("font_size", 8)
                release.pressed.connect(_release_outpost_guard.bind(structure))
                row.add_child(release)

                var assign := Button.new()
                assign.text = "+"
                assign.custom_minimum_size = Vector2(25, 22)
                assign.disabled = structure.free_guard_slots() <= 0
                assign.tooltip_text = "Tugaskan prajurit terdekat yang belum menjaga struktur ini"
                assign.add_theme_font_override("font", _hud._font)
                assign.add_theme_font_size_override("font_size", 8)
                assign.pressed.connect(_assign_outpost_guard.bind(structure))
                row.add_child(assign)
            elif is_archery_range:
                var release_archer_button := Button.new()
                release_archer_button.text = "-"
                release_archer_button.custom_minimum_size = Vector2(25, 22)
                release_archer_button.disabled = int(structure.data.get("workplaces", {}).get("archer", 0)) == structure.free_slots("archer")
                release_archer_button.tooltip_text = "Kembalikan satu pemanah ke prajurit biasa"
                release_archer_button.add_theme_font_override("font", _hud._font)
                release_archer_button.add_theme_font_size_override("font_size", 8)
                release_archer_button.pressed.connect(_release_archer.bind(structure))
                row.add_child(release_archer_button)

                var assign_archer_button := Button.new()
                assign_archer_button.text = "+"
                assign_archer_button.custom_minimum_size = Vector2(25, 22)
                assign_archer_button.disabled = structure.free_slots("archer") <= 0
                assign_archer_button.tooltip_text = "Latih prajurit tersedia menjadi pemanah"
                assign_archer_button.add_theme_font_override("font", _hud._font)
                assign_archer_button.add_theme_font_size_override("font_size", 8)
                assign_archer_button.pressed.connect(_assign_archer.bind(structure))
                row.add_child(assign_archer_button)

    _refresh_shipment_controls()

func _depot_option_cell(option: OptionButton) -> Vector2i:
    if option == null or option.get_selected() < 0:
        return Vector2i(-1, -1)
    var metadata: Variant = option.get_item_metadata(option.get_selected())
    if not (metadata is Dictionary):
        return Vector2i(-1, -1)
    return Vector2i(int(metadata.get("cx", -1)), int(metadata.get("cy", -1)))


func _refresh_depot_option(option: OptionButton, depots: Array, preferred: Vector2i, default_index: int) -> void:
    option.clear()
    var selected_index := -1
    for depot in depots:
        var cell: Vector2i = depot.cell
        var label := "KEEP" if String(depot.id) == "keep" else (
            "POS" if String(depot.id) == "outpost" else ("LUMBUNG" if String(depot.id) == "granary" else "GUDANG")
        )
        option.add_item("%s %d,%d" % [label, cell.x, cell.y])
        var index := option.item_count - 1
        option.set_item_metadata(index, {"cx": cell.x, "cy": cell.y})
        if cell == preferred:
            selected_index = index
    if selected_index < 0 and option.item_count > 0:
        selected_index = clampi(default_index, 0, option.item_count - 1)
    if selected_index >= 0:
        option.select(selected_index)
    option.disabled = option.item_count < 2



func _refresh_cost_source_controls(depots: Array) -> void:
    if _hud._cost_source_option == null:
        return
    var main_node = _hud.get_tree().get_first_node_in_group("main")
    if main_node == null or main_node.supply == null:
        _hud._cost_source_option.disabled = true
        return
    var selected_cell: Vector2i = main_node.supply.get_cost_source_cell()
    var selected_index := -1
    var keep_index := -1
    _hud._cost_source_option.clear()
    for depot in depots:
        if not ["keep", "storage", "outpost"].has(String(depot.id)):
            continue
        var cell: Vector2i = depot.cell
        var connected: bool = main_node.supply.is_depot_connected(depot)
        var label := "KEEP" if String(depot.id) == "keep" else (
            "POS %d,%d" % [cell.x, cell.y] if String(depot.id) == "outpost"
            else "GUDANG %d,%d" % [cell.x, cell.y]
        )
        if not connected:
            label += " · PUTUS"
        _hud._cost_source_option.add_item(label)
        var index: int = _hud._cost_source_option.item_count - 1
        _hud._cost_source_option.set_item_metadata(index, {"cx": cell.x, "cy": cell.y})
        if not connected and cell != selected_cell:
            _hud._cost_source_option.set_item_disabled(index, true)
        if String(depot.id) == "keep":
            keep_index = index
        if cell == selected_cell:
            selected_index = index
    if selected_index < 0 and keep_index >= 0:
        for depot in depots:
            if String(depot.id) == "keep":
                main_node.supply.set_cost_source(depot.cell)
                selected_index = keep_index
                break
    if selected_index >= 0:
        _hud._cost_source_option.select(selected_index)
    _hud._cost_source_option.disabled = not WorldConfig.is_frontier_profile() or _hud._cost_source_option.item_count < 2


func _on_cost_source_selected(index: int) -> void:
    if _hud._cost_source_option == null or index < 0:
        return
    var metadata: Variant = _hud._cost_source_option.get_item_metadata(index)
    if not (metadata is Dictionary):
        return
    var cell := Vector2i(int(metadata.get("cx", -1)), int(metadata.get("cy", -1)))
    var main_node = _hud.get_tree().get_first_node_in_group("main")
    if main_node == null or not main_node.supply.set_cost_source(cell):
        _hud._show_message("Depot sumber biaya tidak terhubung")
        _refresh_outpost_panel()
        return
    _hud._show_message("Biaya konstruksi dan riset: " + main_node.supply.cost_source_label())
    _hud._refresh_slots()


func _on_supply_state_changed() -> void:
    _hud._refresh_resources()
    _hud._refresh_slots()
    _refresh_outpost_panel()


func _refresh_shipment_controls() -> void:
    if _hud._shipment_source == null or _hud._shipment_destination == null or _hud._shipment_orders_list == null:
        return
    var previous_source := _depot_option_cell(_hud._shipment_source)
    var previous_destination := _depot_option_cell(_hud._shipment_destination)
    var endpoints: Array = []
    for depot in _hud.get_tree().get_nodes_in_group("depots"):
        if is_instance_valid(depot) and ["keep", "storage", "outpost", "granary"].has(String(depot.id)):
            endpoints.append(depot)
    endpoints.sort_custom(func(a, b) -> bool:
        if String(a.id) == "keep" or String(b.id) == "keep":
            return String(a.id) == "keep"
        if a.cell.y != b.cell.y:
            return a.cell.y < b.cell.y
        return a.cell.x < b.cell.x
    )
    _refresh_cost_source_controls(endpoints)
    _hud._shipment_refreshing = true
    _refresh_depot_option(_hud._shipment_source, endpoints, previous_source, 0)
    _refresh_depot_option(_hud._shipment_destination, endpoints, previous_destination, 1)
    var frontier_enabled := WorldConfig.is_frontier_profile() and endpoints.size() >= 2
    _hud._shipment_source.disabled = not frontier_enabled
    _hud._shipment_destination.disabled = not frontier_enabled
    _hud._shipment_kind.disabled = not WorldConfig.is_frontier_profile()
    _hud._shipment_amount.editable = WorldConfig.is_frontier_profile()
    _hud._shipment_send_button.disabled = not frontier_enabled
    _refresh_shipment_kind_options(endpoints)
    _hud._shipment_refreshing = false

    for child in _hud._shipment_orders_list.get_children():
        child.free()
    var main_node = _hud.get_tree().get_first_node_in_group("main")
    if main_node == null:
        return
    var orders: Array[Dictionary] = main_node.supply.get_shipment_orders()
    if orders.is_empty():
        var empty: Label = _hud._label(_hud._shipment_orders_list, "Belum ada perintah pengiriman.", Vector2.ZERO, Color("#c9b99d"))
        empty.add_theme_font_size_override("font_size", 7)
        return
    var shown := 0
    for order_index in range(orders.size() - 1, -1, -1):
        var order: Dictionary = orders[order_index]
        var row := HBoxContainer.new()
        row.custom_minimum_size = Vector2(328, 17)
        row.add_theme_constant_override("separation", 4)
        _hud._shipment_orders_list.add_child(row)

        var source_name := _shipment_name(Vector2i(int(order["source_x"]), int(order["source_y"])))
        var destination_name := _shipment_name(Vector2i(int(order["destination_x"]), int(order["destination_y"])))
        var state_name: String = main_node.supply.get_shipment_status_label(String(order["status"]))
        var detail := Label.new()
        detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        detail.add_theme_font_override("font", _hud._font)
        detail.add_theme_font_size_override("font_size", 6)
        detail.add_theme_color_override("font_color", Color("#d5c8ae"))
        detail.text = "#%d %d %s  %s → %s  [%s]" % [
            int(order["id"]), int(order["amount"]), String(order["kind"]).to_upper(),
            source_name, destination_name, state_name
        ]
        detail.clip_text = true
        row.add_child(detail)

        var cancel := Button.new()
        cancel.text = "X"
        cancel.custom_minimum_size = Vector2(18, 16)
        cancel.add_theme_font_override("font", _hud._font)
        cancel.add_theme_font_size_override("font_size", 6)
        cancel.disabled = not ["queued", "in_transit", "blocked"].has(String(order["status"]))
        cancel.tooltip_text = "Batalkan dan pulihkan cargo"
        cancel.pressed.connect(_cancel_shipment_order.bind(int(order["id"])))
        row.add_child(cancel)
        shown += 1
        if shown >= 8:
            break


func _refresh_shipment_kind_options(depots: Array) -> void:
    var source_cell := _depot_option_cell(_hud._shipment_source)
    var destination_cell := _depot_option_cell(_hud._shipment_destination)
    var source = null
    var destination = null
    for depot in depots:
        if depot.cell == source_cell:
            source = depot
        if depot.cell == destination_cell:
            destination = depot
    var selected_kind := ""
    if _hud._shipment_kind.get_selected() >= 0:
        selected_kind = String(_hud._shipment_kind.get_item_metadata(_hud._shipment_kind.get_selected()))
    var first_allowed := -1
    var selection_still_valid := false
    for index in _hud._shipment_kind.item_count:
        var kind := String(_hud._shipment_kind.get_item_metadata(index))
        var allowed := true
        if source != null and String(source.id) == "granary" and kind != "food":
            allowed = false
        if destination != null and String(destination.id) == "granary" and kind != "food":
            allowed = false
        _hud._shipment_kind.set_item_disabled(index, not allowed)
        if allowed and first_allowed < 0:
            first_allowed = index
        if allowed and kind == selected_kind:
            selection_still_valid = true
    if not selection_still_valid and first_allowed >= 0:
        _hud._shipment_kind.select(first_allowed)


func _on_shipment_endpoint_selected(_index: int) -> void:
    if _hud._shipment_refreshing:
        return
    _refresh_shipment_controls()


func _shipment_name(cell: Vector2i) -> String:
    var main_node = _hud.get_tree().get_first_node_in_group("main")
    if main_node != null:
        for depot in _hud.get_tree().get_nodes_in_group("depots"):
            if is_instance_valid(depot) and depot.cell == cell:
                return "KEEP" if depot.id == "keep" else ("POS" if depot.id == "outpost" else ("LUMBUNG" if depot.id == "granary" else "GDG"))
    return "HILANG"


func _create_shipment_order() -> void:
    var main_node = _hud.get_tree().get_first_node_in_group("main")
    if main_node == null or _hud._shipment_source.get_selected() < 0 or _hud._shipment_destination.get_selected() < 0:
        _hud._show_message("Pilih depot asal dan tujuan")
        return
    var source_cell := _depot_option_cell(_hud._shipment_source)
    var destination_cell := _depot_option_cell(_hud._shipment_destination)
    var kind: String = String(_hud._shipment_kind.get_item_metadata(_hud._shipment_kind.get_selected()))
    var amount := int(_hud._shipment_amount.value)
    var order_id: int = main_node.supply.create_shipment(source_cell, destination_cell, kind, amount)
    if order_id < 0:
        _hud._show_message("Order ditolak: stok, kapasitas atau jalur tidak cukup")
    else:
        _hud._show_message("Order #%d dibuat; cargo telah dicadangkan" % order_id)
    _refresh_outpost_panel()


func _cancel_shipment_order(order_id: int) -> void:
    var main_node = _hud.get_tree().get_first_node_in_group("main")
    if main_node == null or not main_node.supply.cancel_shipment(order_id):
        _hud._show_message("Order tidak dapat dibatalkan")
    else:
        _hud._show_message("Order dibatalkan; cargo dipulihkan")
    _refresh_outpost_panel()



func _assign_outpost_guard(outpost) -> void:
    var main_node = _hud.get_tree().get_first_node_in_group("main")
    var structure_name := "Barak" if String(outpost.id) == "barracks" else "Outpost"
    if main_node == null or not main_node.village.assign_nearest_garrison_guard(outpost):
        _hud._show_message("Tidak ada prajurit yang tersedia atau slot penjaga penuh")
    else:
        _hud._show_message("Prajurit ditugaskan menjaga " + structure_name)
    _refresh_outpost_panel()


func _release_outpost_guard(outpost) -> void:
    var main_node = _hud.get_tree().get_first_node_in_group("main")
    if main_node == null or not main_node.village.release_garrison_guard(outpost):
        _hud._show_message("Tidak ada penjaga untuk ditarik")
    else:
        _hud._show_message("Penjaga kembali ke pertahanan umum")
    _refresh_outpost_panel()


func _assign_archer(archery_range) -> void:
    var main_node = _hud.get_tree().get_first_node_in_group("main")
    if main_node == null or not main_node.village.assign_nearest_archer(archery_range):
        _hud._show_message("Tidak ada prajurit tersedia atau slot pemanah penuh")
    else:
        _hud._show_message("Prajurit dilatih menjadi pemanah")
    _refresh_outpost_panel()


func _release_archer(archery_range) -> void:
    var main_node = _hud.get_tree().get_first_node_in_group("main")
    if main_node == null or not main_node.village.release_archer(archery_range):
        _hud._show_message("Tidak ada pemanah untuk dikembalikan")
    else:
        _hud._show_message("Pemanah kembali menjadi prajurit biasa")
    _refresh_outpost_panel()


func _toggle_outposts() -> void:
    var opening: bool = not _hud._outpost_panel.visible
    if opening:
        _hud._close_construction_queue()
    _hud._outpost_panel.visible = opening
    _hud._outpost_backdrop.visible = opening
    _hud._outpost_button.active = opening
    _hud._outpost_button.queue_redraw()
    if opening:
        _hud._jobs_panel.visible = false
        _hud._jobs_button.active = false
        _hud._jobs_button.queue_redraw()
        if _hud._map_panel.visible:
            _hud._map_panel.visible = false
            _hud._map_backdrop.visible = false
            _hud._map_button.active = false
            _hud._map_button.queue_redraw()
        _hud._outpost_refresh_t = 0.0
        _refresh_outpost_panel()


