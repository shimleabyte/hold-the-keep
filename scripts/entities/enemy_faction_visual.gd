extends RefCounted
## Compact, pixel-aligned faction and archetype identity marks.
## Gameplay behavior remains in enemy.gd and the behavior components.

static func signature(visual: Dictionary, archetype: String) -> Array[String]:
    if visual.is_empty() or String(visual.get("motif", "")).is_empty():
        return []
    return [String(visual["motif"]), archetype]


static func draw_identity(canvas: CanvasItem, visual: Dictionary, archetype: String) -> void:
    var layers := signature(visual, archetype)
    if layers.is_empty():
        return

    var primary := Color(String(visual.get("primary", "#b8b3a5")))
    var secondary := Color(String(visual.get("secondary", "#77766d")))
    var emblem := Color(String(visual.get("emblem", "#d7c69b")))

    # A narrow heraldic band and a small chest device remain readable at 20px.
    canvas.draw_rect(Rect2(-4, -9, 8, 2), primary)
    canvas.draw_rect(Rect2(-1, -9, 2, 2), emblem)

    match layers[0]:
        "thorn":
            canvas.draw_line(Vector2(-5, -13), Vector2(-8, -17), secondary, 1.5)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-8, -17), Vector2(-12, -18), Vector2(-10, -14)
            ]), emblem)
            canvas.draw_line(Vector2(4, -10), Vector2(7, -13), primary, 1.0)
        "chevron":
            canvas.draw_line(Vector2(-5, -14), Vector2(0, -18), secondary, 2.0)
            canvas.draw_line(Vector2(0, -18), Vector2(5, -14), secondary, 2.0)
            canvas.draw_rect(Rect2(-6, -11, 2, 2), emblem)
            canvas.draw_rect(Rect2(4, -11, 2, 2), emblem)
        "reed":
            canvas.draw_line(Vector2(5, -11), Vector2(7, -17), secondary, 1.0)
            canvas.draw_line(Vector2(7, -17), Vector2(9, -19), emblem, 1.0)
            canvas.draw_line(Vector2(7, -13), Vector2(10, -16), secondary, 1.0)
            canvas.draw_circle(Vector2(6, -5), 1.5, emblem)
        "ember":
            canvas.draw_line(Vector2(-6, -12), Vector2(-2, -15), secondary, 1.5)
            canvas.draw_line(Vector2(-2, -15), Vector2(1, -12), emblem, 1.5)
            canvas.draw_line(Vector2(1, -12), Vector2(5, -16), secondary, 1.5)
            canvas.draw_rect(Rect2(5, -8, 2, 2), emblem)

    # Archetype equipment is geometric and restrained; no behavior or collision changes.
    match layers[1]:
        "scout":
            canvas.draw_line(Vector2(1, -15), Vector2(5, -19), secondary, 1.5)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(4, -19), Vector2(9, -19), Vector2(6, -16)
            ]), emblem)
        "shieldbearer":
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-12, -14), Vector2(-8, -13), Vector2(-8, -5),
                Vector2(-11, -3), Vector2(-13, -6)
            ]), primary)
            canvas.draw_rect(Rect2(-12, -12, 3, 1), emblem)
            canvas.draw_circle(Vector2(-10, -8), 1.0, secondary)
        "saboteur":
            canvas.draw_rect(Rect2(5, -8, 4, 3), secondary)
            canvas.draw_rect(Rect2(7, -10, 2, 2), emblem)
            canvas.draw_line(Vector2(8, -10), Vector2(10, -13), primary, 1.0)
        "war_shaman":
            canvas.draw_line(Vector2(-3, -15), Vector2(-6, -19), secondary, 1.5)
            canvas.draw_line(Vector2(-6, -19), Vector2(-9, -17), emblem, 1.0)
            canvas.draw_line(Vector2(3, -15), Vector2(6, -19), secondary, 1.5)
            canvas.draw_line(Vector2(6, -19), Vector2(9, -17), emblem, 1.0)
            canvas.draw_line(Vector2(5, -8), Vector2(7, -3), emblem, 1.0)
        "siege_engine":
            canvas.draw_rect(Rect2(-10, -13, 4, 6), primary)
            canvas.draw_rect(Rect2(6, -13, 4, 6), primary)
            canvas.draw_rect(Rect2(-9, -12, 2, 2), emblem)
            canvas.draw_rect(Rect2(7, -12, 2, 2), emblem)
        "beast_rider":
            canvas.draw_line(Vector2(-3, -14), Vector2(-7, -19), secondary, 2.0)
            canvas.draw_line(Vector2(-7, -19), Vector2(-10, -18), emblem, 1.0)
            canvas.draw_line(Vector2(3, -14), Vector2(7, -19), secondary, 2.0)
            canvas.draw_line(Vector2(7, -19), Vector2(10, -18), emblem, 1.0)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-6, -8), Vector2(-9, -5), Vector2(-4, -4)
            ]), secondary)
