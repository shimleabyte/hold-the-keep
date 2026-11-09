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
    match motif:
        "thorn":
            # Greenwood: a leaf-cut mantle sweeping back with a thorned branch above the shoulder.
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-8, -15), Vector2(-4, -17), Vector2(0, -14),
                Vector2(-2, -9), Vector2(-6, -6), Vector2(-12, -8),
                Vector2(-15, -12), Vector2(-12, -15)
            ]), ink)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-8, -14), Vector2(-4, -16), Vector2(-1, -14),
                Vector2(-3, -10), Vector2(-7, -8), Vector2(-12, -10),
                Vector2(-13, -12)
            ]), secondary)
            canvas.draw_line(Vector2(-11, -12), Vector2(-6, -10), primary, 1.5)
            canvas.draw_line(Vector2(-8, -14), Vector2(-5, -12), highlight, 1.0)
            canvas.draw_line(Vector2(3, -12), Vector2(7, -18), ink, 3.0)
            canvas.draw_line(Vector2(3, -12), Vector2(7, -18), secondary, 1.5)
            canvas.draw_line(Vector2(7, -18), Vector2(11, -20), ink, 2.0)
            canvas.draw_line(Vector2(7, -18), Vector2(11, -20), primary, 1.0)
            canvas.draw_line(Vector2(7, -18), Vector2(10, -15), emblem, 1.0)
        "chevron":
            # Iron Legion: paired, squared pauldrons and a closed central gorget.
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-13, -15), Vector2(-8, -17), Vector2(-3, -14),
                Vector2(-4, -7), Vector2(-10, -6), Vector2(-14, -10)
            ]), ink)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-12, -14), Vector2(-8, -16), Vector2(-4, -13),
                Vector2(-5, -8), Vector2(-10, -8), Vector2(-13, -10)
            ]), primary)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(13, -15), Vector2(8, -17), Vector2(3, -14),
                Vector2(4, -7), Vector2(10, -6), Vector2(14, -10)
            ]), ink)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(12, -14), Vector2(8, -16), Vector2(4, -13),
                Vector2(5, -8), Vector2(10, -8), Vector2(13, -10)
            ]), primary)
            canvas.draw_line(Vector2(-11, -14), Vector2(-6, -13), highlight, 1.5)
            canvas.draw_line(Vector2(11, -14), Vector2(6, -13), highlight, 1.5)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-4, -14), Vector2(0, -12), Vector2(4, -14),
                Vector2(3, -7), Vector2(-3, -7)
            ]), secondary)
            canvas.draw_line(Vector2(-3, -11), Vector2(0, -9), emblem, 1.5)
            canvas.draw_line(Vector2(0, -9), Vector2(3, -11), emblem, 1.5)
            canvas.draw_rect(Rect2(-8, -11, 2, 1), highlight)
            canvas.draw_rect(Rect2(6, -11, 2, 1), highlight)
        "reed":
            # Fen Cult: a tall wrapped hood, narrow face opening and hanging reed ties.
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-8, -20), Vector2(-5, -23), Vector2(5, -23),
                Vector2(8, -19), Vector2(7, -12), Vector2(4, -8),
                Vector2(-4, -8), Vector2(-8, -12)
            ]), ink)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-6, -19), Vector2(-4, -21), Vector2(4, -21),
                Vector2(6, -18), Vector2(5, -13), Vector2(3, -10),
                Vector2(-3, -10), Vector2(-6, -13)
            ]), secondary)
            canvas.draw_rect(Rect2(-3, -17, 6, 6), ink)
            canvas.draw_rect(Rect2(-2, -16, 4, 1), emblem)
            canvas.draw_rect(Rect2(-2, -12, 4, 1), primary)
            canvas.draw_line(Vector2(-6, -10), Vector2(-9, -4), ink, 2.0)
            canvas.draw_line(Vector2(-6, -10), Vector2(-9, -4), secondary, 1.0)
            canvas.draw_line(Vector2(6, -10), Vector2(9, -3), ink, 2.0)
            canvas.draw_line(Vector2(6, -10), Vector2(9, -3), primary, 1.0)
            canvas.draw_line(Vector2(7, -10), Vector2(12, -6), emblem, 1.0)
        "ember":
            # Ashen Host: a squared visor helm over a torn mantle hanging from the opposite shoulder.
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-6, -21), Vector2(-3, -23), Vector2(4, -22),
                Vector2(7, -18), Vector2(6, -12), Vector2(3, -9),
                Vector2(-5, -9), Vector2(-7, -13)
            ]), ink)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-5, -20), Vector2(-2, -21), Vector2(3, -20),
                Vector2(5, -17), Vector2(4, -13), Vector2(2, -11),
                Vector2(-4, -11), Vector2(-6, -14)
            ]), secondary)
            canvas.draw_rect(Rect2(-5, -17, 10, 2), ink)
            canvas.draw_rect(Rect2(-3, -17, 2, 1), emblem)
            canvas.draw_rect(Rect2(2, -17, 2, 1), emblem)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(3, -13), Vector2(10, -15), Vector2(13, -11),
                Vector2(13, -5), Vector2(10, -2), Vector2(8, -6),
                Vector2(5, -4), Vector2(4, -9)
            ]), ink)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(5, -12), Vector2(10, -14), Vector2(12, -10),
                Vector2(11, -5), Vector2(9, -7), Vector2(6, -6)
            ]), secondary)
            canvas.draw_line(Vector2(6, -11), Vector2(10, -10), primary, 1.5)
            canvas.draw_line(Vector2(8, -8), Vector2(11, -7), emblem, 1.0)


static func _draw_archetype_equipment(
    canvas: CanvasItem,
    archetype: String,
    primary: Color,
    secondary: Color,
    emblem: Color,
    ink: Color
) -> void:
    match archetype:
        "scout":
            # Scout: compact field pack, narrow harness and an exposed arrow bundle.
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-12, -16), Vector2(-8, -18), Vector2(-5, -15),
                Vector2(-6, -9), Vector2(-11, -8), Vector2(-13, -11)
            ]), ink)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-11, -15), Vector2(-8, -17), Vector2(-6, -14),
                Vector2(-7, -10), Vector2(-11, -10), Vector2(-12, -12)
            ]), secondary)
            canvas.draw_line(Vector2(-4, -15), Vector2(4, -8), ink, 2.0)
            canvas.draw_line(Vector2(-4, -15), Vector2(4, -8), primary, 1.0)
            canvas.draw_line(Vector2(5, -18), Vector2(8, -13), ink, 1.5)
            canvas.draw_line(Vector2(7, -19), Vector2(10, -14), secondary, 1.0)
            canvas.draw_rect(Rect2(3, -9, 3, 2), emblem)
        "shieldbearer":
            # Shieldbearer: broad convex shield with a visible rim and central boss.
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-15, -16), Vector2(-7, -15), Vector2(-7, -6),
                Vector2(-11, -2), Vector2(-15, -7)
            ]), ink)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-14, -15), Vector2(-8, -14), Vector2(-8, -7),
                Vector2(-11, -4), Vector2(-14, -8)
            ]), primary)
            canvas.draw_line(Vector2(-13, -14), Vector2(-9, -13), secondary, 1.0)
            canvas.draw_line(Vector2(-9, -13), Vector2(-9, -7), secondary, 1.0)
            canvas.draw_rect(Rect2(-12, -11, 3, 2), emblem)
            canvas.draw_rect(Rect2(-11, -10, 1, 1), ink)
        "saboteur":
            # Saboteur: diagonal harness, hard-edged demolition satchel and visible fuse.
            canvas.draw_line(Vector2(-5, -16), Vector2(8, -7), ink, 3.0)
            canvas.draw_line(Vector2(-5, -16), Vector2(8, -7), primary, 1.0)
            canvas.draw_rect(Rect2(0, -11, 3, 3), ink)
            canvas.draw_rect(Rect2(1, -10, 1, 1), emblem)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(6, -10), Vector2(13, -10), Vector2(14, -4),
                Vector2(8, -3), Vector2(5, -6)
            ]), ink)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(7, -9), Vector2(12, -9), Vector2(13, -5),
                Vector2(8, -4), Vector2(6, -6)
            ]), secondary)
            canvas.draw_rect(Rect2(7, -8, 2, 2), emblem)
            canvas.draw_rect(Rect2(10, -8, 2, 2), primary)
            canvas.draw_line(Vector2(11, -10), Vector2(14, -14), ink, 2.0)
            canvas.draw_line(Vector2(11, -10), Vector2(14, -14), emblem, 1.0)
        "war_shaman":
            # War Shaman: forked field staff and hanging bone/reed tokens.
            canvas.draw_line(Vector2(-11, -4), Vector2(-12, -24), ink, 3.0)
            canvas.draw_line(Vector2(-11, -4), Vector2(-12, -24), secondary, 1.5)
            canvas.draw_line(Vector2(-12, -23), Vector2(-16, -27), ink, 2.5)
            canvas.draw_line(Vector2(-12, -23), Vector2(-8, -27), ink, 2.5)
            canvas.draw_line(Vector2(-12, -23), Vector2(-16, -27), primary, 1.0)
            canvas.draw_line(Vector2(-12, -23), Vector2(-8, -27), emblem, 1.0)
            canvas.draw_line(Vector2(-10, -19), Vector2(-6, -16), ink, 2.0)
            canvas.draw_rect(Rect2(-7, -17, 3, 3), emblem)
            canvas.draw_rect(Rect2(-6, -16, 1, 1), secondary)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(3, -14), Vector2(8, -16), Vector2(10, -12),
                Vector2(7, -8), Vector2(3, -9)
            ]), ink)
            canvas.draw_line(Vector2(5, -13), Vector2(8, -10), primary, 1.0)
        "siege_engine":
            # Siege Engine: back-mounted braced mantlet frame and heavy stacked plates.
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-12, -17), Vector2(-10, -22), Vector2(-7, -19),
                Vector2(7, -19), Vector2(10, -22), Vector2(12, -17),
                Vector2(11, -5), Vector2(-11, -5)
            ]), ink)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-10, -16), Vector2(-8, -20), Vector2(-6, -17),
                Vector2(6, -17), Vector2(8, -20), Vector2(10, -16),
                Vector2(9, -7), Vector2(-9, -7)
            ]), secondary)
            canvas.draw_line(Vector2(-9, -19), Vector2(9, -19), primary, 2.0)
            canvas.draw_line(Vector2(-8, -16), Vector2(-8, -8), ink, 2.0)
            canvas.draw_line(Vector2(8, -16), Vector2(8, -8), ink, 2.0)
            canvas.draw_line(Vector2(-6, -12), Vector2(6, -12), emblem, 1.5)
            canvas.draw_rect(Rect2(-5, -10, 10, 2), primary)
            canvas.draw_rect(Rect2(-2, -10, 4, 2), emblem)
        "beast_rider":
            # Beast Rider: rider over a low, forward-thrusting mount profile with a muzzle and legs.
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-10, -8), Vector2(-6, -11), Vector2(1, -11),
                Vector2(5, -14), Vector2(10, -13), Vector2(14, -10),
                Vector2(15, -6), Vector2(12, -4), Vector2(-5, -4)
            ]), ink)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-8, -8), Vector2(-5, -10), Vector2(1, -10),
                Vector2(6, -12), Vector2(10, -12), Vector2(13, -9),
                Vector2(13, -7), Vector2(10, -6), Vector2(-4, -6)
            ]), secondary)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(7, -13), Vector2(9, -18), Vector2(13, -17),
                Vector2(16, -13), Vector2(15, -9), Vector2(11, -8),
                Vector2(8, -10)
            ]), ink)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(9, -13), Vector2(10, -16), Vector2(13, -15),
                Vector2(15, -12), Vector2(14, -10), Vector2(11, -10)
            ]), primary)
            canvas.draw_line(Vector2(10, -17), Vector2(9, -21), ink, 2.0)
            canvas.draw_line(Vector2(10, -17), Vector2(9, -21), emblem, 1.0)
            canvas.draw_rect(Rect2(13, -12, 1, 1), ink)
            canvas.draw_line(Vector2(-1, -14), Vector2(9, -10), emblem, 1.0)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(-7, -9), Vector2(-3, -12), Vector2(1, -10),
                Vector2(1, -6), Vector2(-5, -5)
            ]), primary)
            canvas.draw_line(Vector2(2, -6), Vector2(1, 1), ink, 2.0)
            canvas.draw_line(Vector2(7, -6), Vector2(7, 1), ink, 2.0)
            canvas.draw_line(Vector2(11, -7), Vector2(12, 0), ink, 2.0)
            canvas.draw_line(Vector2(13, -7), Vector2(15, -1), ink, 2.0)

