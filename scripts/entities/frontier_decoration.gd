extends Node2D
## Non-blocking regional dressing for the Frontier. Drawn at native 16px tile scale.

var prop_kind := "fern_cluster"
var variant := 0
var is_landmark := false
var _batch_entries: Array[Dictionary] = []
var _ambient_elapsed := 0.0
var _ambient_time := 0.0
var _ambient_phase := 0.0
var _ambient_intensity := 0.5
var _ambient_enabled := false

const AMBIENT_UPDATE_INTERVAL := 1.0 / 12.0


func setup(kind: String, variation: int, landmark: bool = false) -> void:
    prop_kind = kind
    variant = posmod(variation, 3)
    is_landmark = landmark
    _ambient_phase = float(variation) * 0.83
    _ambient_enabled = landmark and (kind == "fen_reeds" or kind == "hearth_shrine")
    _ambient_elapsed = 0.0
    _ambient_time = 0.0
    _ambient_intensity = 0.5
    set_process(_ambient_enabled)
    z_index = 1 if landmark else 0
    add_to_group("frontier_decorations")
    if landmark:
        add_to_group("frontier_landmarks")
    queue_redraw()


## Entries share a world row so their draw calls can be submitted by one CanvasItem.
func setup_batch(entries: Array, landmark: bool) -> void:
    _batch_entries.clear()
    for entry in entries:
        if entry is Dictionary:
            _batch_entries.append(entry.duplicate(true))
    is_landmark = landmark
    _ambient_enabled = false
    _ambient_elapsed = 0.0
    _ambient_time = 0.0
    _ambient_intensity = 0.5
    for entry in _batch_entries:
        var kind := String(entry.get("kind", ""))
        if landmark and (kind == "fen_reeds" or kind == "hearth_shrine"):
            _ambient_enabled = true
            _ambient_phase = float(entry.get("variant", 0)) * 0.83
            break
    set_process(_ambient_enabled)
    z_index = 1 if landmark else 0
    add_to_group("frontier_decorations")
    add_to_group("frontier_decoration_batches")
    if landmark:
        add_to_group("frontier_landmarks")
    queue_redraw()


## Ambient motion is limited to the two regional landmarks that benefit from it.
## Batch drawing keeps one CanvasItem per row while animating only the reeds/ember.
func _process(delta: float) -> void:
    if not _ambient_enabled:
        return
    _ambient_elapsed += delta
    if _ambient_elapsed < AMBIENT_UPDATE_INTERVAL:
        return
    _ambient_time += _ambient_elapsed
    _ambient_elapsed = 0.0
    _ambient_intensity = 0.5 + 0.5 * sin(_ambient_time * 2.2 + _ambient_phase)
    if _batch_entries.is_empty() and prop_kind == "fen_reeds":
        rotation_degrees = sin(_ambient_time * 1.7 + _ambient_phase) * 1.25
    else:
        queue_redraw()


func _draw() -> void:
    if not _batch_entries.is_empty():
        for entry in _batch_entries:
            var offset: Vector2 = entry.get("offset", Vector2.ZERO)
            var kind := String(entry.get("kind", ""))
            var variation := int(entry.get("variant", 0))
            var sway := 0.0
            if _ambient_enabled and kind == "fen_reeds":
                sway = deg_to_rad(sin(_ambient_time * 1.7 + float(variation) * 0.83) * 1.25)
            draw_set_transform(offset, sway, Vector2.ONE)
            _draw_prop(kind, variation)
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
        return
    _draw_prop(prop_kind, variant)


func _draw_prop(kind: String, variation: int) -> void:
    variant = posmod(variation, 3)
    match kind:
        "fern_cluster":
            _draw_fern()
        "fen_reeds":
            _draw_reeds()
        "dead_pine":
            _draw_dead_pine()
        "standing_stone":
            _draw_standing_stone()
        "ash_pillar":
            _draw_ash_pillar()
        "hearth_shrine":
            _draw_hearth_shrine()
        "ruin_marker":
            _draw_ruin_marker()


func _draw_fern() -> void:
    var greens: Array[Color] = [Color("#405b43"), Color("#52684a"), Color("#344b3c")]
    var leaf: Color = greens[variant]
    draw_line(Vector2(0, 0), Vector2(0, -8), Color("#26372e"), 1.2)
    for side in [-1.0, 1.0]:
        for level in 3:
            var y := -3.0 - float(level) * 2.0
            var x: float = float(side) * (3.0 - float(level) * 0.6)
            draw_colored_polygon(PackedVector2Array([
                Vector2(0, y + 1), Vector2(x, y - 2), Vector2(x * 1.7, y - 3),
                Vector2(x * 1.1, y), Vector2(0, y + 1)
            ]), leaf)
    draw_line(Vector2(0, -2), Vector2(0, -8), Color("#a0a16c"), 0.7)


func _draw_reeds() -> void:
    var stem := Color("#78805a") if variant != 2 else Color("#9a8050")
    for i in 3:
        var x := float(i - 1) * 4.0
        var height := 7.0 + float((i + variant) % 3) * 2.0
        draw_line(Vector2(x, 0), Vector2(x + float(i - 1) * 1.5, -height), stem, 1.0)
        draw_line(Vector2(x + float(i - 1) * 1.5, -height), Vector2(x + float(i - 1) * 1.5, -height - 2.0), Color("#b18b55"), 1.4)
    draw_line(Vector2(-7, 0), Vector2(7, 0), Color("#343d32"), 1.0)


func _draw_dead_pine() -> void:
    var bark := Color("#51453a") if variant != 1 else Color("#655044")
    draw_rect(Rect2(-1.5, -13, 3, 13), bark)
    draw_line(Vector2(0, -8), Vector2(-6, -12), bark, 1.8)
    draw_line(Vector2(0, -10), Vector2(6, -15), bark, 1.8)
    draw_line(Vector2(0, -6), Vector2(-5, -8), bark, 1.5)
    draw_line(Vector2(0, -13), Vector2(-2, -17), Color("#8a7055"), 1.0)
    draw_rect(Rect2(-4, -1, 8, 1), Color("#252a25"))


func _draw_standing_stone() -> void:
    var stone: Color = [Color("#777b70"), Color("#8b8170"), Color("#626c68")][variant]
    draw_colored_polygon(PackedVector2Array([
        Vector2(-5, 0), Vector2(-6, -9), Vector2(-3, -15),
        Vector2(3, -14), Vector2(6, -7), Vector2(5, 0)
    ]), stone)
    draw_line(Vector2(-3, -11), Vector2(-1, -3), Color("#b5a98b"), 1.0)
    draw_line(Vector2(2, -12), Vector2(1, -7), Color("#444b46"), 1.0)
    if variant == 1:
        draw_line(Vector2(-2, -8), Vector2(3, -8), Color("#9b7652"), 1.0)


func _draw_ash_pillar() -> void:
    draw_colored_polygon(PackedVector2Array([
        Vector2(-5, 0), Vector2(-4, -12), Vector2(-2, -17),
        Vector2(3, -15), Vector2(5, 0)
    ]), Color("#4d4b48"))
    draw_line(Vector2(-2, -13), Vector2(1, -5), Color("#9a6550"), 1.2)
    draw_line(Vector2(3, -12), Vector2(2, -3), Color("#77716a"), 1.0)
    draw_rect(Rect2(-7, -1, 14, 2), Color("#282a28"))


func _draw_hearth_shrine() -> void:
    draw_rect(Rect2(-8, -3, 16, 4), Color("#39362e"))
    draw_colored_polygon(PackedVector2Array([
        Vector2(-6, -3), Vector2(-5, -11), Vector2(0, -15),
        Vector2(5, -11), Vector2(6, -3)
    ]), Color("#75664c"))
    var ember_alpha := 0.10 + _ambient_intensity * 0.24
    draw_circle(Vector2(0, -7), 3.0, Color(0.83, 0.48, 0.2, ember_alpha))
    draw_line(Vector2(0, -13), Vector2(0, -5), Color("#c39b62"), 1.0)
    draw_line(Vector2(-3, -9), Vector2(3, -9), Color("#c39b62"), 1.0)
    draw_circle(Vector2(0, -7), 1.2, Color("#d0a45f"))


func _draw_ruin_marker() -> void:
    var stone := Color("#6d716a")
    draw_rect(Rect2(-8, -4, 16, 4), Color("#343833"))
    draw_rect(Rect2(-7, -12, 3, 9), stone)
    draw_rect(Rect2(4, -10, 3, 7), stone)
    draw_rect(Rect2(-8, -14, 16, 3), Color("#858273"))
    draw_rect(Rect2(-3, -9, 6, 5), Color("#403f37"))
    draw_line(Vector2(-5, -12), Vector2(-2, -12), Color("#b39b70"), 1.0)
