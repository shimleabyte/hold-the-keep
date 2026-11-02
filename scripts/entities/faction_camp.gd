extends Node2D
## Destructible faction camp objective. Player melee attacks campaign_targets.

var camp_id := ""
var manager
var hp := 220
var max_hp := 220
var faction_color := Color("#b46b4c")
var discovered := false
var suppressed := false


func setup(id: String, manager_ref, at: Vector2, faction_data: Dictionary, saved: Dictionary = {}) -> void:
    camp_id = id
    manager = manager_ref
    position = at
    max_hp = 220
    hp = clampi(int(saved.get("hp", max_hp)), 1, max_hp)
    faction_color = Color(String(faction_data.get("color", "#b46b4c")))
    discovered = bool(saved.get("activated", false))
    suppressed = bool(saved.get("suppressed", false))
    visible = discovered
    z_index = 3


func _ready() -> void:
    add_to_group("faction_camp_targets")
    add_to_group("campaign_targets")
    queue_redraw()


func set_discovered(value: bool) -> void:
    discovered = value
    visible = discovered
    queue_redraw()


func set_suppressed(value: bool) -> void:
    suppressed = value
    queue_redraw()


func take_damage(amount: int) -> void:
    if not discovered or hp <= 0:
        return
    hp = maxi(0, hp - maxi(1, amount))
    if hp <= 0:
        manager.destroy_camp(camp_id)
        return
    manager.update_camp_hp(camp_id, hp)
    Events.fx_burst.emit("debris", global_position + Vector2(0, -7), Vector2.ZERO, 0.8)
    queue_redraw()


func interact() -> void:
    if not discovered:
        return
    Events.build_feedback.emit("Hancurkan kamp faksi dengan serangan. Patroli berhenti setelah kamp jatuh.")


func export_state() -> Dictionary:
    return {
        "hp": hp,
        "activated": discovered,
        "suppressed": suppressed
    }


func _draw() -> void:
    var tint := faction_color.darkened(0.55) if suppressed else faction_color
    var canvas := Color("#26251f")
    draw_rect(Rect2(-13, -5, 26, 12), canvas)
    draw_colored_polygon(PackedVector2Array([
        Vector2(-15, -5), Vector2(0, -21), Vector2(15, -5)
    ]), tint.darkened(0.35))
    draw_line(Vector2(-15, -5), Vector2(0, -21), Color("#dec79d"), 1.2)
    draw_line(Vector2(0, -21), Vector2(15, -5), Color("#dec79d"), 1.2)
    draw_line(Vector2(0, -18), Vector2(0, -27), tint, 1.5)
    draw_line(Vector2(0, -27), Vector2(8, -24), tint, 1.5)
    draw_rect(Rect2(-11, -3, 22, 7), Color("#121615"))
    draw_rect(Rect2(-11, -3, 22.0 * float(hp) / float(maxi(1, max_hp)), 2.5), Color("#d45f4d"))
    draw_rect(Rect2(-11, -3, 22, 2.5), Color("#e0c18d"), false, 0.8)
