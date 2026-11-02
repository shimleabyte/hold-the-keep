extends RefCounted
## Frontier-only building material, silhouette detail and deterministic damage marks.
## This layer is decorative: it never changes footprint, collision, HP or construction logic.

static func signature(building_id: String, visual: Dictionary) -> Array[String]:
    var material := String(visual.get("material", ""))
    var feature := String(visual.get("feature", ""))
    if material.is_empty() or feature.is_empty():
        return []
    return [building_id, material, feature]


static func enabled(profile_id: String, visual: Dictionary) -> bool:
    return profile_id == "frontier" and not signature("", visual).is_empty()


static func damage_stage(hp: int, max_hp: int) -> int:
    if max_hp <= 0:
        return 3
    var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
    if ratio >= 0.75:
        return 0
    if ratio >= 0.50:
        return 1
    if ratio >= 0.25:
        return 2
    return 3


static func draw_identity(
    canvas: CanvasItem,
    building_id: String,
    visual: Dictionary,
    sprite_size: Vector2,
    hp_ratio: float
) -> void:
    if signature(building_id, visual).is_empty():
        return

    var primary := Color(String(visual.get("primary", "#8b7a62")))
    var accent := Color(String(visual.get("accent", "#c5a16a")))
    var shadow := Color(String(visual.get("shadow", "#392f27")))
    var half_width := maxf(8.0, sprite_size.x * 0.5)
    var top := -maxf(16.0, sprite_size.y)
    var stage := damage_stage(roundi(clampf(hp_ratio, 0.0, 1.0) * 1000.0), 1000)

    match String(visual["feature"]):
        "keep_banner":
            var pole_x := half_width - 10.0
            canvas.draw_line(Vector2(pole_x, top + 5.0), Vector2(pole_x, top + 27.0), shadow, 2.0)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(pole_x + 1.0, top + 7.0),
                Vector2(pole_x + 11.0, top + 10.0),
                Vector2(pole_x + 1.0, top + 16.0)
            ]), accent)
            canvas.draw_rect(Rect2(pole_x + 3.0, top + 10.0, 2.0, 2.0), primary)
        "house_gable":
            canvas.draw_line(Vector2(-half_width + 5.0, top + 17.0), Vector2(0, top + 5.0), shadow, 2.0)
            canvas.draw_line(Vector2(0, top + 5.0), Vector2(half_width - 5.0, top + 17.0), shadow, 2.0)
            canvas.draw_rect(Rect2(-2.0, top + 22.0, 4.0, 9.0), primary)
            canvas.draw_circle(Vector2(1.0, top + 27.0), 0.8, accent)
        "wall_stakes":
            for index in 3:
                var x := float(index - 1) * 5.0
                canvas.draw_colored_polygon(PackedVector2Array([
                    Vector2(x - 2.0, top + 8.0), Vector2(x, top + 2.0), Vector2(x + 2.0, top + 8.0)
                ]), primary)
                canvas.draw_rect(Rect2(x - 1.0, top + 8.0, 2.0, 3.0), shadow)
        "tower_battlements":
            for index in 4:
                var x := -half_width + 5.0 + float(index) * maxf(4.0, (sprite_size.x - 10.0) / 3.0)
                canvas.draw_rect(Rect2(x - 2.0, top + 5.0, 4.0, 5.0), accent)
            canvas.draw_rect(Rect2(-2.0, top + 19.0, 4.0, 9.0), shadow)
            canvas.draw_rect(Rect2(-1.0, top + 20.0, 2.0, 5.0), primary)
        "storage_shutters":
            canvas.draw_rect(Rect2(-half_width + 6.0, top + 10.0, 7.0, 8.0), shadow)
            canvas.draw_rect(Rect2(half_width - 13.0, top + 10.0, 7.0, 8.0), shadow)
            for x in [-half_width + 7.0, half_width - 12.0]:
                canvas.draw_line(Vector2(x, top + 11.0), Vector2(x + 5.0, top + 17.0), accent, 1.0)
            canvas.draw_line(Vector2(-3.0, top + 20.0), Vector2(3.0, top + 20.0), primary, 1.0)
        "farm_crop_rows":
            for row in 3:
                var y := top + 12.0 + float(row) * 5.0
                canvas.draw_line(Vector2(-half_width + 5.0, y), Vector2(half_width - 5.0, y + 1.0), shadow, 1.0)
                for plant in 4:
                    var x := -half_width + 9.0 + float(plant) * maxf(4.0, (sprite_size.x - 18.0) / 3.0)
                    canvas.draw_line(Vector2(x, y), Vector2(x - 1.0, y - 3.0), accent, 1.0)
        "stone_mortar":
            for row in 3:
                var y := top + 7.0 + float(row) * 4.0
                canvas.draw_line(Vector2(-half_width + 1.0, y), Vector2(half_width - 1.0, y), shadow, 1.0)
            canvas.draw_line(Vector2(-half_width * 0.35, top + 7.0), Vector2(-half_width * 0.35, top + 11.0), accent, 1.0)
            canvas.draw_line(Vector2(half_width * 0.35, top + 11.0), Vector2(half_width * 0.35, top + 15.0), accent, 1.0)
        "forge_embers":
            canvas.draw_rect(Rect2(-5.0, top + 18.0, 10.0, 8.0), shadow)
            canvas.draw_rect(Rect2(-3.0, top + 21.0, 6.0, 3.0), accent)
            canvas.draw_circle(Vector2(0, top + 19.0), 2.0, primary)
        "outpost_signal":
            var flag_x := half_width - 9.0
            canvas.draw_line(Vector2(flag_x, top + 4.0), Vector2(flag_x, top + 24.0), shadow, 2.0)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(flag_x + 1.0, top + 6.0),
                Vector2(flag_x + 9.0, top + 9.0),
                Vector2(flag_x + 1.0, top + 13.0)
            ]), accent)
            canvas.draw_rect(Rect2(flag_x + 3.0, top + 9.0, 2.0, 2.0), primary)
        "road_ruts":
            canvas.draw_line(Vector2(-half_width + 2.0, top + 5.0), Vector2(-half_width + 2.0, top + sprite_size.y - 4.0), shadow, 1.0)
            canvas.draw_line(Vector2(half_width - 2.0, top + 5.0), Vector2(half_width - 2.0, top + sprite_size.y - 4.0), shadow, 1.0)
            canvas.draw_circle(Vector2(0, top + sprite_size.y * 0.55), 1.0, accent)
        "bridge_planks":
            for plank in 3:
                var y := top + 5.0 + float(plank) * 4.0
                canvas.draw_line(Vector2(-half_width + 1.0, y), Vector2(half_width - 1.0, y), accent, 1.0)
            canvas.draw_line(Vector2(-half_width + 2.0, top + 3.0), Vector2(-half_width + 2.0, top + sprite_size.y - 2.0), shadow, 1.0)
            canvas.draw_line(Vector2(half_width - 2.0, top + 3.0), Vector2(half_width - 2.0, top + sprite_size.y - 2.0), shadow, 1.0)
        "lumber_logs":
            for index in 4:
                var x := -half_width + 8.0 + float(index) * 5.0
                canvas.draw_circle(Vector2(x, top + sprite_size.y - 8.0), 2.0, primary)
                canvas.draw_circle(Vector2(x, top + sprite_size.y - 8.0), 0.8, accent)
        "quarry_cart":
            canvas.draw_rect(Rect2(-half_width + 5.0, top + sprite_size.y - 14.0, 13.0, 6.0), shadow)
            canvas.draw_line(Vector2(-half_width + 4.0, top + sprite_size.y - 14.0), Vector2(-half_width + 19.0, top + sprite_size.y - 14.0), accent, 1.0)
            canvas.draw_circle(Vector2(-half_width + 7.0, top + sprite_size.y - 6.0), 2.0, shadow)
            canvas.draw_circle(Vector2(-half_width + 17.0, top + sprite_size.y - 6.0), 2.0, shadow)

    _draw_damage(canvas, building_id, visual, half_width, top, sprite_size.y, stage)


static func _draw_damage(
    canvas: CanvasItem,
    building_id: String,
    visual: Dictionary,
    half_width: float,
    top: float,
    height: float,
    stage: int
) -> void:
    if stage <= 0:
        return
    var shadow := Color(String(visual.get("shadow", "#392f27")))
    var accent := Color(String(visual.get("accent", "#c5a16a")))
    var x := half_width * 0.28
    var y := top + maxf(12.0, height * 0.42)
    canvas.draw_line(Vector2(-x, y), Vector2(-x + 3.0, y + 3.0), shadow, 1.5)
    canvas.draw_line(Vector2(-x + 3.0, y + 3.0), Vector2(-x + 1.0, y + 7.0), shadow, 1.0)
    if stage >= 2:
        canvas.draw_line(Vector2(x, y - 3.0), Vector2(x - 3.0, y + 1.0), shadow, 1.5)
        canvas.draw_line(Vector2(x - 3.0, y + 1.0), Vector2(x + 1.0, y + 5.0), accent, 1.0)
    if stage >= 3:
        canvas.draw_colored_polygon(PackedVector2Array([
            Vector2(half_width - 2.0, top + 8.0),
            Vector2(half_width - 8.0, top + 11.0),
            Vector2(half_width - 3.0, top + 17.0)
        ]), shadow)
        if building_id in ["wall", "house", "storage", "outpost", "lumber_camp", "bridge"]:
            canvas.draw_line(Vector2(-half_width + 3.0, top + 10.0), Vector2(-half_width + 8.0, top + 14.0), accent, 1.5)
