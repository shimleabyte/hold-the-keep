extends RefCounted
## Pixel-aligned faction equipment and archetype identity.
## Drawn over the shared base atlas; gameplay data, collision and animation timing stay untouched.

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
    var ink := Color("#202321")
    var highlight := Color("#c2b99f")

    _draw_faction_silhouette(canvas, layers[0], primary, secondary, emblem, ink, highlight)
    _draw_archetype_equipment(canvas, layers[1], primary, secondary, emblem, ink)


static func _draw_faction_silhouette(
    canvas: CanvasItem,
    motif: String,
    primary: Color,
    secondary: Color,
    emblem: Color,
    ink: Color,
    highlight: Color
) -> void:
    # Equipment is built from stepped planes, not a flat heraldic stripe.
    match motif:
        "thorn":
            # Greenwood: asymmetrical weather mantle, layered leather shoulder and thorn pins.
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-7, -13), Vector2(-3, -14), Vector2(0, -11),
                Vector2(-2, -7), Vector2(-7, -8), Vector2(-9, -11)
            ]), ink)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-7, -13), Vector2(-3, -13), Vector2(-1, -10),
                Vector2(-3, -8), Vector2(-7, -9), Vector2(-8, -11)
            ]), secondary)
            canvas.draw_rect(Rect2(-6, -12, 2, 1), primary)
            canvas.draw_line(Vector2(3, -11), Vector2(7, -15), secondary, 2.0)
            canvas.draw_line(Vector2(5, -13), Vector2(8, -13), emblem, 1.0)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(7, -15), Vector2(10, -17), Vector2(9, -13)
            ]), primary)
            canvas.draw_rect(Rect2(-3, -9, 3, 1), emblem)
        "chevron":
            # Iron Legion: matched plate shoulders, central gorget and a hard V-shaped mark.
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-8, -13), Vector2(-4, -14), Vector2(-2, -11),
                Vector2(-3, -7), Vector2(-8, -8), Vector2(-10, -11)
            ]), ink)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-8, -13), Vector2(-4, -13), Vector2(-3, -10),
                Vector2(-4, -8), Vector2(-8, -9), Vector2(-9, -11)
            ]), primary)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(8, -13), Vector2(4, -13), Vector2(3, -10),
                Vector2(4, -8), Vector2(8, -9), Vector2(9, -11)
            ]), primary)
            canvas.draw_rect(Rect2(-7, -12, 2, 1), highlight)
            canvas.draw_rect(Rect2(5, -12, 2, 1), highlight)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-3, -12), Vector2(0, -10), Vector2(3, -12),
                Vector2(2, -7), Vector2(-2, -7)
            ]), secondary)
            canvas.draw_line(Vector2(-3, -10), Vector2(0, -8), emblem, 1.0)
            canvas.draw_line(Vector2(0, -8), Vector2(3, -10), emblem, 1.0)
        "reed":
            # Fen Cult: layered damp hood-wrap and hanging reed ties.
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-7, -17), Vector2(-4, -19), Vector2(4, -19),
                Vector2(7, -16), Vector2(6, -10), Vector2(3, -8),
                Vector2(-5, -9), Vector2(-8, -12)
            ]), ink)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-6, -16), Vector2(-3, -18), Vector2(3, -18),
                Vector2(6, -15), Vector2(5, -11), Vector2(2, -9),
                Vector2(-4, -10), Vector2(-7, -12)
            ]), secondary)
            canvas.draw_rect(Rect2(-5, -16, 2, 1), primary)
            canvas.draw_rect(Rect2(3, -16, 2, 1), primary)
            canvas.draw_rect(Rect2(-3, -11, 6, 2), ink)
            canvas.draw_line(Vector2(5, -9), Vector2(7, -4), primary, 1.0)
            canvas.draw_line(Vector2(7, -9), Vector2(9, -5), emblem, 1.0)
            canvas.draw_line(Vector2(-5, -9), Vector2(-7, -5), secondary, 1.0)
        "ember":
            # Ashen Host: broken charred mantle with a few heat-scarred metal plates.
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-8, -13), Vector2(-4, -15), Vector2(-1, -12),
                Vector2(-2, -8), Vector2(-6, -7), Vector2(-10, -10)
            ]), ink)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-7, -13), Vector2(-4, -14), Vector2(-2, -11),
                Vector2(-3, -9), Vector2(-6, -8), Vector2(-9, -10)
            ]), secondary)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(4, -13), Vector2(8, -14), Vector2(9, -10),
                Vector2(6, -8), Vector2(3, -10)
            ]), primary)
            canvas.draw_rect(Rect2(-6, -12, 2, 1), emblem)
            canvas.draw_rect(Rect2(5, -12, 2, 1), emblem)
            canvas.draw_line(Vector2(-2, -10), Vector2(1, -8), emblem, 1.0)
            canvas.draw_rect(Rect2(1, -8, 2, 1), primary)


static func _draw_archetype_equipment(
    canvas: CanvasItem,
    archetype: String,
    primary: Color,
    secondary: Color,
    emblem: Color,
    ink: Color
) -> void:
    # Each specialist receives one functional equipment mass that survives faction recoloring.
    match archetype:
        "scout":
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(3, -15), Vector2(7, -18), Vector2(10, -16),
                Vector2(8, -12), Vector2(5, -11)
            ]), ink)
            canvas.draw_line(Vector2(4, -14), Vector2(8, -17), secondary, 2.0)
            canvas.draw_rect(Rect2(5, -12, 3, 2), emblem)
        "shieldbearer":
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-12, -15), Vector2(-8, -14), Vector2(-8, -5),
                Vector2(-11, -3), Vector2(-13, -7)
            ]), ink)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-11, -14), Vector2(-9, -13), Vector2(-9, -6),
                Vector2(-11, -5), Vector2(-12, -8)
            ]), primary)
            canvas.draw_rect(Rect2(-11, -12, 2, 1), emblem)
            canvas.draw_rect(Rect2(-11, -9, 2, 1), secondary)
        "saboteur":
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(4, -9), Vector2(9, -9), Vector2(10, -5),
                Vector2(5, -4), Vector2(3, -6)
            ]), ink)
            canvas.draw_rect(Rect2(5, -8, 4, 3), secondary)
            canvas.draw_rect(Rect2(6, -9, 2, 1), emblem)
            canvas.draw_line(Vector2(8, -9), Vector2(10, -12), primary, 1.0)
        "war_shaman":
            canvas.draw_line(Vector2(-3, -16), Vector2(-7, -20), ink, 3.0)
            canvas.draw_line(Vector2(-7, -20), Vector2(-10, -18), secondary, 2.0)
            canvas.draw_line(Vector2(3, -16), Vector2(7, -20), ink, 3.0)
            canvas.draw_line(Vector2(7, -20), Vector2(10, -18), secondary, 2.0)
            canvas.draw_rect(Rect2(-1, -17, 2, 3), emblem)
            canvas.draw_rect(Rect2(-2, -10, 4, 2), primary)
        "siege_engine":
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-10, -14), Vector2(-6, -16), Vector2(6, -16),
                Vector2(10, -14), Vector2(9, -7), Vector2(-9, -7)
            ]), ink)
            canvas.draw_rect(Rect2(-8, -14, 4, 5), primary)
            canvas.draw_rect(Rect2(4, -14, 4, 5), primary)
            canvas.draw_rect(Rect2(-7, -13, 2, 2), emblem)
            canvas.draw_rect(Rect2(5, -13, 2, 2), emblem)
            canvas.draw_line(Vector2(-5, -8), Vector2(5, -8), secondary, 2.0)
        "beast_rider":
            canvas.draw_line(Vector2(-3, -15), Vector2(-7, -19), ink, 3.0)
            canvas.draw_line(Vector2(-7, -19), Vector2(-10, -18), secondary, 2.0)
            canvas.draw_line(Vector2(3, -15), Vector2(7, -19), ink, 3.0)
            canvas.draw_line(Vector2(7, -19), Vector2(10, -18), secondary, 2.0)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-7, -9), Vector2(-10, -6), Vector2(-5, -5)
            ]), primary)
            canvas.draw_rect(Rect2(4, -10, 3, 3), emblem)
