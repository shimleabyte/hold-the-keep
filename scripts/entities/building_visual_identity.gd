extends RefCounted
## Frontier-only building material, silhouette detail and deterministic damage marks.
## This layer is decorative: it never changes footprint, collision, HP or construction logic.

const SUPPORTED_FEATURES := [
    "keep_banner", "house_gable", "wall_stakes", "tower_battlements",
    "storage_shutters", "farm_crop_rows", "stone_mortar", "forge_embers",
    "outpost_signal", "road_ruts", "bridge_planks", "lumber_logs", "quarry_cart", "granary_wheat_sacks",
    "hunting_lodge_trophy_rack", "scout_post_map_board", "infirmary_medicine_rack",
    "barracks_training_yard", "archery_range_target_yard"
]


static func signature(building_id: String, visual: Dictionary) -> Array[String]:
    var material := String(visual.get("material", ""))
    var feature := String(visual.get("feature", ""))
    if material.is_empty() or feature.is_empty() or not SUPPORTED_FEATURES.has(feature):
        return []
    return [building_id, material, feature]


static func enabled(profile_id: String, visual: Dictionary) -> bool:
    return ["classic", "frontier", "frontier_expedition"].has(profile_id) and not signature("", visual).is_empty()


## Four deterministic construction silhouettes driven by the existing work ratio.
static func construction_stage(progress_ratio: float) -> int:
    var ratio := clampf(progress_ratio, 0.0, 1.0)
    if ratio < 0.18:
        return 0
    if ratio < 0.42:
        return 1
    if ratio < 0.78:
        return 2
    return 3


## Stable presentation states for the upgrades that physically affect a building.
static func upgrade_signature(building_id: String, researched: Array) -> Array[String]:
    var features: Array[String] = []
    match building_id:
        "house":
            if researched.has("longhouse"):
                features.append("longhouse_loft")
        "tower":
            if researched.has("stone_towers"):
                features.append("stone_tower_gallery")
            if researched.has("iron_towers"):
                features.append("iron_tower_bracing")
        "wall":
            if researched.has("palisade"):
                features.append("palisade_reinforcement")
            if researched.has("fortress"):
                features.append("fortress_wall_reinforcement")
        "stone_wall":
            if researched.has("fortress"):
                features.append("fortress_masonry")
        "keep":
            if researched.has("fortress"):
                features.append("fortress_gatehouse")
    return features


## Draws the structure while the real ConstructionSite owns the footprint and work progress.
## Low progress is foundation-only; the completed sprite is withheld until the finishing stage.



## A real construction silhouette replaces the old translucent finished-building ghost and X.
static func draw_construction(
    canvas: CanvasItem,
    building_id: String,
    visual: Dictionary,
    footprint: Vector2,
    sprite_size: Vector2,
    base_texture: Texture2D,
    progress_ratio: float
) -> void:
    var stage := construction_stage(progress_ratio)
    var width := maxf(16.0, sprite_size.x)
    var height := maxf(16.0, sprite_size.y)
    var half_width := width * 0.5
    var top := -height
    var left := -half_width
    var right := half_width
    var primary := Color(String(visual.get("primary", "#8b7a62")))
    var accent := Color(String(visual.get("accent", "#c5a16a")))
    var shadow := Color(String(visual.get("shadow", "#392f27")))
    var stone := Color("#777d78") if String(visual.get("material", "")).contains("stone") else primary
    var low_profile := building_id in ["farm", "road", "bridge"]
    var wall_profile := building_id in ["wall", "stone_wall"]
    var vertical_top := top + (height * 0.13 if low_profile else 3.0)

    # Prepared ground and rough footings are present at every construction stage.
    canvas.draw_rect(Rect2(-footprint.x * 0.5, -4.0, footprint.x, 4.0), shadow)
    canvas.draw_line(Vector2(-footprint.x * 0.5 + 2.0, -5.0), Vector2(footprint.x * 0.5 - 2.0, -5.0), accent, 1.0)
    for corner in [-1.0, 1.0]:
        var x := corner * minf(footprint.x * 0.5 - 3.0, half_width * 0.42)
        canvas.draw_rect(Rect2(x - 3.0, -8.0, 6.0, 4.0), stone)
        canvas.draw_rect(Rect2(x - 3.0, -8.0, 6.0, 1.0), accent)
        canvas.draw_line(Vector2(x, -8.0), Vector2(x, -13.0), shadow, 1.0)

    if stage == 0:
        # Foundation: set-out ropes, cut trenches and staged stone or timber.
        canvas.draw_rect(Rect2(left + 3.0, -12.0, width - 6.0, 2.0), Color(shadow, 0.85))
        canvas.draw_line(Vector2(left + 5.0, -14.0), Vector2(right - 5.0, -14.0), accent, 1.0)
        canvas.draw_line(Vector2(left + 5.0, -14.0), Vector2(left + 5.0, -4.0), accent, 1.0)
        canvas.draw_line(Vector2(right - 5.0, -14.0), Vector2(right - 5.0, -4.0), accent, 1.0)
        for index in 3:
            var pile_x := left + 6.0 + float(index) * 4.0
            canvas.draw_rect(Rect2(pile_x, -10.0 - float(index % 2) * 2.0, 3.0, 2.0), stone)
        if low_profile or wall_profile:
            canvas.draw_line(Vector2(left + 4.0, -6.0), Vector2(right - 4.0, -6.0), primary, 2.0)
        return

    if low_profile:
        # Agricultural, road and bridge works grow along the ground, not like a house.
        for row in range(3):
            var y := -8.0 - float(row) * 4.0
            canvas.draw_line(Vector2(left + 5.0, y), Vector2(right - 5.0, y), shadow, 2.0)
            if stage >= 2:
                canvas.draw_line(Vector2(left + 7.0, y - 1.0), Vector2(right - 7.0, y - 1.0), primary, 1.0)
        if building_id == "bridge":
            for x in [-half_width * 0.35, half_width * 0.35]:
                canvas.draw_line(Vector2(x, -5.0), Vector2(x, top + height * 0.32), shadow, 2.0)
                canvas.draw_line(Vector2(x - 2.0, top + height * 0.32), Vector2(x + 2.0, top + height * 0.32), accent, 1.0)
        if building_id == "farm" and stage >= 2:
            for row in range(3):
                var y := -10.0 - float(row) * 5.0
                for plant in 5:
                    var x := left + 8.0 + float(plant) * maxf(4.0, (width - 16.0) / 4.0)
                    canvas.draw_line(Vector2(x, y), Vector2(x, y - 3.0), accent, 1.0)
    elif wall_profile:
        # Fortifications are assembled as a continuous run of posts and rails.
        var post_top := top + (height * 0.58 if stage == 1 else height * 0.22)
        for x in range(0, maxi(2, ceili(width / 8.0))):
            var post_x := left + 3.0 + float(x) * maxf(5.0, (width - 6.0) / maxf(1.0, float(ceili(width / 8.0) - 1)))
            canvas.draw_rect(Rect2(post_x - 1.5, post_top, 3.0, -post_top - 5.0), shadow)
            canvas.draw_rect(Rect2(post_x - 0.5, post_top, 1.0, -post_top - 5.0), primary)
        for y in [-8.0, -14.0]:
            if stage >= 2 or y == -8.0:
                canvas.draw_line(Vector2(left + 1.0, y), Vector2(right - 1.0, y), shadow, 3.0)
                canvas.draw_line(Vector2(left + 1.0, y - 1.0), Vector2(right - 1.0, y - 1.0), accent, 1.0)
    else:
        # Timber posts and lintels outline the actual building mass before any wall infill.
        var post_y := vertical_top if stage >= 2 else top + height * 0.35
        for x in [left + 4.0, -half_width * 0.28, half_width * 0.28, right - 4.0]:
            canvas.draw_rect(Rect2(x - 1.5, post_y, 3.0, -post_y - 5.0), shadow)
            canvas.draw_rect(Rect2(x - 0.5, post_y, 1.0, -post_y - 5.0), accent)
        canvas.draw_rect(Rect2(left + 2.0, post_y - 2.0, width - 4.0, 3.0), shadow)
        canvas.draw_rect(Rect2(left + 3.0, post_y - 2.0, width - 6.0, 1.0), accent)
        # Diagonal braces show the unfinished load-bearing frame.
        canvas.draw_line(Vector2(left + 4.0, -7.0), Vector2(-half_width * 0.2, post_y - 3.0), primary, 2.0)
        canvas.draw_line(Vector2(right - 4.0, -7.0), Vector2(half_width * 0.2, post_y - 3.0), primary, 2.0)
        if stage >= 2:
            # Partially installed wall panels and roof ribs leave the interior visibly open.
            canvas.draw_rect(Rect2(left + 5.0, post_y + 2.0, width * 0.34, -post_y - height * 0.38), Color(primary, 0.92))
            canvas.draw_rect(Rect2(right - width * 0.26, post_y + 2.0, width * 0.2, -post_y - height * 0.38), Color(shadow, 0.9))
            canvas.draw_line(Vector2(left + 4.0, top + height * 0.42), Vector2(0.0, top + 2.0), shadow, 2.0)
            canvas.draw_line(Vector2(0.0, top + 2.0), Vector2(right - 4.0, top + height * 0.42), shadow, 2.0)
            canvas.draw_line(Vector2(left + 7.0, top + height * 0.42), Vector2(0.0, top + 5.0), accent, 1.0)
            if building_id in ["forge", "quarry", "lumber_camp", "granary", "storage"]:
                canvas.draw_rect(Rect2(-half_width * 0.22, -16.0, half_width * 0.44, 7.0), shadow)
                canvas.draw_line(Vector2(-half_width * 0.2, -16.0), Vector2(half_width * 0.2, -16.0), accent, 1.0)

    if stage == 2 and base_texture != null:
        # The finished art is only a faint material guide while the open frame remains dominant.
        canvas.draw_texture(base_texture, Vector2(-base_texture.get_width() * 0.5, -base_texture.get_height()), Color(1.0, 1.0, 1.0, 0.18))
    elif stage == 3 and base_texture != null:
        # Near completion: the built form is nearly solid, with one side still scaffolded.
        var final_alpha := lerpf(0.78, 0.96, inverse_lerp(0.78, 1.0, clampf(progress_ratio, 0.78, 1.0)))
        canvas.draw_texture(base_texture, Vector2(-base_texture.get_width() * 0.5, -base_texture.get_height()), Color(1.0, 1.0, 1.0, final_alpha))
        var scaffold_x := right - 3.0
        canvas.draw_line(Vector2(scaffold_x, top + 2.0), Vector2(scaffold_x, -5.0), shadow, 2.0)
        canvas.draw_line(Vector2(scaffold_x - 8.0, top + height * 0.45), Vector2(scaffold_x + 3.0, top + height * 0.45), accent, 2.0)
        canvas.draw_line(Vector2(scaffold_x - 8.0, top + height * 0.45), Vector2(scaffold_x - 8.0, -5.0), shadow, 2.0)
        canvas.draw_line(Vector2(scaffold_x - 8.0, top + height * 0.45), Vector2(scaffold_x, top + 2.0), primary, 1.5)
        for rung in 3:
            var rung_y := top + height * 0.45 + float(rung) * maxf(4.0, (height * 0.45 - 5.0) / 3.0)
            canvas.draw_line(Vector2(scaffold_x - 8.0, rung_y), Vector2(scaffold_x, rung_y), accent, 1.0)


## Large structural changes from the existing technology tree, not generic stat-only badges.
static func draw_upgrades(canvas: CanvasItem, building_id: String, sprite_size: Vector2, researched: Array) -> void:
    var states := upgrade_signature(building_id, researched)
    if states.is_empty():
        return
    var half_width := maxf(8.0, sprite_size.x * 0.5)
    var top := -sprite_size.y
    var iron := Color("#3a4143")
    var iron_highlight := Color("#a8aaa0")
    var timber := Color("#4b3427")
    var timber_light := Color("#b58b58")
    for state in states:
        match state:
            "longhouse_loft":
                # A raised attic ridge and loft bay visibly add a second storey to the house.
                canvas.draw_colored_polygon(PackedVector2Array([
                    Vector2(-half_width * 0.48, top + 16.0),
                    Vector2(-half_width * 0.34, top + 7.0),
                    Vector2(0.0, top - 2.0),
                    Vector2(half_width * 0.34, top + 7.0),
                    Vector2(half_width * 0.48, top + 16.0),
                    Vector2(half_width * 0.34, top + 18.0),
                    Vector2(-half_width * 0.34, top + 18.0)
                ]), timber)
                canvas.draw_line(Vector2(-half_width * 0.32, top + 10.0), Vector2(0.0, top), timber_light, 2.0)
                canvas.draw_line(Vector2(0.0, top), Vector2(half_width * 0.32, top + 10.0), timber_light, 2.0)
                canvas.draw_rect(Rect2(-4.0, top + 8.0, 8.0, 7.0), iron)
                canvas.draw_rect(Rect2(-2.0, top + 9.0, 4.0, 4.0), Color("#c7a56c"))
            "stone_tower_gallery":
                # Wider stone fighting gallery with a second visible parapet course.
                var y := top + 18.0
                canvas.draw_rect(Rect2(-half_width - 4.0, y, sprite_size.x + 8.0, 5.0), iron)
                canvas.draw_rect(Rect2(-half_width - 3.0, y, sprite_size.x + 6.0, 2.0), iron_highlight)
                for index in 5:
                    var x := -half_width - 2.0 + float(index) * (sprite_size.x + 4.0) / 4.0
                    canvas.draw_rect(Rect2(x - 2.0, y - 5.0, 4.0, 5.0), iron)
                    canvas.draw_rect(Rect2(x - 1.0, y - 5.0, 2.0, 1.0), iron_highlight)
            "iron_tower_bracing":
                # Heavy iron strapping is large enough to survive the battlefield zoom.
                for x in [-half_width * 0.34, half_width * 0.34]:
                    canvas.draw_rect(Rect2(x - 2.0, top + 20.0, 4.0, sprite_size.y * 0.45), iron)
                    canvas.draw_line(Vector2(x - 1.0, top + 21.0), Vector2(x - 1.0, -5.0), iron_highlight, 1.0)
                    for y in [top + 24.0, top + 36.0]:
                        canvas.draw_rect(Rect2(x - 2.0, y, 4.0, 2.0), Color("#c2a66b"))
                canvas.draw_line(Vector2(-half_width * 0.34, top + 29.0), Vector2(half_width * 0.34, top + 39.0), iron, 2.0)
            "palisade_reinforcement":
                # Additional continuous rails and upright stakes reinforce wooden palisade.
                canvas.draw_rect(Rect2(-half_width, top + 4.0, sprite_size.x, 4.0), timber)
                canvas.draw_rect(Rect2(-half_width, top + 4.0, sprite_size.x, 1.0), timber_light)
                canvas.draw_rect(Rect2(-half_width, top + 10.0, sprite_size.x, 3.0), timber)
                for x in [-half_width * 0.5, 0.0, half_width * 0.5]:
                    canvas.draw_line(Vector2(x, top + 2.0), Vector2(x, -3.0), iron, 1.5)
            "fortress_wall_reinforcement":
                canvas.draw_rect(Rect2(-half_width, top + 2.0, sprite_size.x, 4.0), iron)
                canvas.draw_rect(Rect2(-half_width, top + 2.0, sprite_size.x, 1.0), iron_highlight)
                for x in [-half_width * 0.6, half_width * 0.6]:
                    canvas.draw_rect(Rect2(x - 2.0, top + 5.0, 4.0, sprite_size.y * 0.55), iron)
                    canvas.draw_rect(Rect2(x - 1.0, top + 10.0, 2.0, 2.0), Color("#c4aa6c"))
            "fortress_masonry":
                # Heavy dressed capstones and visible iron pins improve the wall profile.
                canvas.draw_rect(Rect2(-half_width, top + 1.0, sprite_size.x, 4.0), iron)
                for x in [-half_width * 0.55, 0.0, half_width * 0.55]:
                    canvas.draw_rect(Rect2(x - 2.0, top + 2.0, 4.0, 2.0), iron_highlight)
            "fortress_gatehouse":
                # Reinforced gate opening and buttresses change the Keep's front mass.
                for x in [-half_width * 0.36, half_width * 0.36]:
                    canvas.draw_rect(Rect2(x - 3.0, top + 24.0, 6.0, sprite_size.y * 0.52), iron)
                    canvas.draw_rect(Rect2(x - 2.0, top + 26.0, 2.0, sprite_size.y * 0.44), iron_highlight)
                canvas.draw_rect(Rect2(-half_width * 0.24, top + sprite_size.y * 0.66, half_width * 0.48, 4.0), iron)
                canvas.draw_line(Vector2(-half_width * 0.22, top + sprite_size.y * 0.72), Vector2(half_width * 0.22, top + sprite_size.y * 0.72), Color("#c8a96b"), 2.0)


## Faction ownership is carried by an actual regional pennant and construction motif.
static func draw_owner_identity(canvas: CanvasItem, visual: Dictionary, sprite_size: Vector2) -> void:
    var motif := String(visual.get("motif", ""))
    if motif.is_empty():
        return
    var primary := Color(String(visual.get("primary", "#a89c78")))
    var secondary := Color(String(visual.get("secondary", "#696c5e")))
    var emblem := Color(String(visual.get("emblem", "#d5bd86")))
    var x := sprite_size.x * 0.34
    var top := -sprite_size.y + 5.0
    var dark := Color("#282b29")
    canvas.draw_line(Vector2(x, top + 2.0), Vector2(x, top + 15.0), dark, 2.0)
    var pennant := PackedVector2Array([
        Vector2(x + 1.0, top + 2.0),
        Vector2(x + 11.0, top + 4.0),
        Vector2(x + 7.0, top + 9.0),
        Vector2(x + 1.0, top + 8.0)
    ])
    canvas.draw_colored_polygon(pennant, secondary)
    match motif:
        "thorn":
            canvas.draw_line(Vector2(x + 2.0, top + 7.0), Vector2(x + 8.0, top + 4.0), emblem, 1.5)
            canvas.draw_line(Vector2(x + 5.0, top + 6.0), Vector2(x + 7.0, top + 9.0), primary, 1.0)
        "chevron":
            canvas.draw_line(Vector2(x + 2.0, top + 4.0), Vector2(x + 6.0, top + 7.0), emblem, 1.5)
            canvas.draw_line(Vector2(x + 6.0, top + 7.0), Vector2(x + 9.0, top + 4.0), emblem, 1.5)
        "reed":
            canvas.draw_line(Vector2(x + 4.0, top + 3.0), Vector2(x + 4.0, top + 8.0), emblem, 1.0)
            canvas.draw_line(Vector2(x + 4.0, top + 4.0), Vector2(x + 2.0, top + 2.0), primary, 1.0)
            canvas.draw_line(Vector2(x + 4.0, top + 5.0), Vector2(x + 7.0, top + 3.0), primary, 1.0)
        "ember":
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(x + 3.0, top + 8.0), Vector2(x + 4.0, top + 3.0),
                Vector2(x + 6.0, top + 6.0), Vector2(x + 8.0, top + 3.0),
                Vector2(x + 8.0, top + 8.0)
            ]), emblem)


## The same structural damage language is used by player buildings and rival strongholds.
static func draw_damage(canvas: CanvasItem, building_id: String, visual: Dictionary, sprite_size: Vector2, hp_ratio: float) -> void:
    var stage := damage_stage(roundi(clampf(hp_ratio, 0.0, 1.0) * 1000.0), 1000)
    if stage <= 0:
        return
    var half_width := maxf(8.0, sprite_size.x * 0.5)
    var top := -maxf(16.0, sprite_size.y)
    _draw_damage(canvas, building_id, visual, half_width, top, sprite_size.y, stage)
    # Material-specific repair and age marks remain deterministic across redraws.


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
        "granary_wheat_sacks":
            for index in 3:
                var x := -half_width + 7.0 + float(index) * 12.0
                canvas.draw_rect(Rect2(x, top + sprite_size.y - 15.0, 9.0, 9.0), shadow)
                canvas.draw_rect(Rect2(x + 1.0, top + sprite_size.y - 14.0, 7.0, 7.0), primary)
                canvas.draw_line(Vector2(x + 2.0, top + sprite_size.y - 11.0), Vector2(x + 7.0, top + sprite_size.y - 11.0), accent, 1.0)
            canvas.draw_line(Vector2(-half_width + 13.0, top + 7.0), Vector2(-half_width + 13.0, top + 2.0), accent, 1.0)
            canvas.draw_line(Vector2(-half_width + 13.0, top + 3.0), Vector2(-half_width + 9.0, top + 5.0), accent, 1.0)
            canvas.draw_line(Vector2(-half_width + 13.0, top + 3.0), Vector2(-half_width + 17.0, top + 5.0), accent, 1.0)
        "hunting_lodge_trophy_rack":
            var rack_y := top + 11.0
            canvas.draw_line(Vector2(-half_width + 5.0, rack_y), Vector2(half_width - 5.0, rack_y), shadow, 2.0)
            for antler_x in [-half_width + 10.0, half_width - 10.0]:
                canvas.draw_line(Vector2(antler_x, rack_y), Vector2(antler_x - 3.0, rack_y - 5.0), accent, 1.5)
                canvas.draw_line(Vector2(antler_x - 3.0, rack_y - 5.0), Vector2(antler_x - 5.0, rack_y - 3.0), accent, 1.0)
                canvas.draw_line(Vector2(antler_x - 3.0, rack_y - 5.0), Vector2(antler_x - 1.0, rack_y - 7.0), accent, 1.0)
            canvas.draw_rect(Rect2(-3.0, rack_y + 2.0, 6.0, 5.0), primary)
        "scout_post_map_board":
            var board_y := top + 12.0
            canvas.draw_rect(Rect2(-half_width + 7.0, board_y, sprite_size.x - 14.0, 12.0), shadow)
            canvas.draw_rect(Rect2(-half_width + 8.0, board_y + 1.0, sprite_size.x - 16.0, 10.0), primary)
            canvas.draw_line(Vector2(-half_width + 10.0, board_y + 8.0), Vector2(half_width - 10.0, board_y + 3.0), accent, 1.0)
            canvas.draw_line(Vector2(-2.0, board_y + 2.0), Vector2(3.0, board_y + 8.0), accent, 1.0)
            canvas.draw_circle(Vector2(0.0, board_y + 5.0), 1.5, Color("#d6c18b"))
            var pennant_x := half_width - 9.0
            canvas.draw_line(Vector2(pennant_x, top + 2.0), Vector2(pennant_x, top + 21.0), shadow, 1.5)
            canvas.draw_colored_polygon(PackedVector2Array([
                Vector2(pennant_x + 1.0, top + 4.0),
                Vector2(pennant_x + 8.0, top + 7.0),
                Vector2(pennant_x + 1.0, top + 11.0)
            ]), accent)
        "infirmary_medicine_rack":
            var shelf_y := top + 12.0
            canvas.draw_line(Vector2(-half_width + 5.0, shelf_y), Vector2(half_width - 5.0, shelf_y), shadow, 2.0)
            for bottle_x in [-half_width + 9.0, -2.0, half_width - 11.0]:
                canvas.draw_rect(Rect2(bottle_x, shelf_y - 7.0, 5.0, 7.0), primary)
                canvas.draw_rect(Rect2(bottle_x + 1.0, shelf_y - 9.0, 3.0, 2.0), accent)
            canvas.draw_rect(Rect2(-2.0, top + 22.0, 4.0, 9.0), shadow)
            canvas.draw_rect(Rect2(-1.0, top + 23.0, 2.0, 7.0), accent)
            canvas.draw_rect(Rect2(-3.0, top + 25.0, 6.0, 2.0), accent)
        "barracks_training_yard":
            var gate_y := top + 15.0
            canvas.draw_rect(Rect2(-half_width + 5.0, gate_y - 10.0, sprite_size.x - 10.0, 18.0), shadow)
            canvas.draw_rect(Rect2(-half_width + 7.0, gate_y - 8.0, sprite_size.x - 14.0, 14.0), primary)
            canvas.draw_rect(Rect2(-7.0, gate_y - 8.0, 14.0, 16.0), shadow)
            canvas.draw_rect(Rect2(-5.0, gate_y - 7.0, 10.0, 15.0), Color("#302821"))
            for target_x in [-half_width + 11.0, half_width - 11.0]:
                canvas.draw_line(Vector2(target_x, gate_y - 18.0), Vector2(target_x, gate_y - 3.0), shadow, 2.0)
                canvas.draw_line(Vector2(target_x - 4.0, gate_y - 12.0), Vector2(target_x + 4.0, gate_y - 12.0), accent, 1.5)
                canvas.draw_circle(Vector2(target_x, gate_y - 20.0), 2.5, accent)
            canvas.draw_line(Vector2(-half_width + 8.0, top + 6.0), Vector2(half_width - 8.0, top + 6.0), accent, 1.0)

        "archery_range_target_yard":
            var target_y := top + 10.0
            for target_x in [-half_width + 12.0, half_width - 12.0]:
                canvas.draw_rect(Rect2(target_x - 5.0, target_y - 3.0, 10.0, 15.0), shadow)
                canvas.draw_circle(Vector2(target_x, target_y + 3.0), 4.5, accent)
                canvas.draw_circle(Vector2(target_x, target_y + 3.0), 2.5, primary)
                canvas.draw_circle(Vector2(target_x, target_y + 3.0), 1.0, shadow)
                canvas.draw_line(Vector2(target_x, target_y + 3.0), Vector2(target_x + 2.0, target_y - 7.0), accent, 1.0)
            canvas.draw_rect(Rect2(-8.0, top + 20.0, 16.0, 7.0), shadow)
            canvas.draw_rect(Rect2(-6.0, top + 21.0, 12.0, 5.0), primary)
            canvas.draw_line(Vector2(-half_width + 7.0, top + 30.0), Vector2(half_width - 7.0, top + 30.0), accent, 1.5)
            canvas.draw_line(Vector2(-half_width + 9.0, top + 33.0), Vector2(half_width - 9.0, top + 33.0), shadow, 2.0)

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
    var primary := Color(String(visual.get("primary", "#8b7a62")))
    var scale_factor := clampf(minf(half_width * 2.0, height) / 32.0, 0.45, 1.5)
    var side := -1.0 if posmod(building_id.hash(), 2) == 0 else 1.0
    var x := side * half_width * 0.43
    var flat_structure := building_id in ["farm", "road", "bridge", "wall", "stone_wall"]
    var y := top + (height * 0.56 if flat_structure else height * 0.34)

    # Light damage: a visible soot patch and split beam/stone course, not just a hairline crack.
    var patch := PackedVector2Array([
        Vector2(x - 4.0 * scale_factor, y - 3.0 * scale_factor),
        Vector2(x + 3.0 * scale_factor, y - 4.0 * scale_factor),
        Vector2(x + 5.0 * scale_factor, y + 1.0 * scale_factor),
        Vector2(x + 1.0 * scale_factor, y + 4.0 * scale_factor),
        Vector2(x - 5.0 * scale_factor, y + 2.0 * scale_factor)
    ])
    canvas.draw_colored_polygon(patch, Color(shadow, 0.92))
    canvas.draw_line(Vector2(x - 2.0 * scale_factor, y - 2.0 * scale_factor),
        Vector2(x + 2.0 * scale_factor, y + 2.0 * scale_factor), accent, maxf(1.0, scale_factor))
    canvas.draw_line(Vector2(x + 2.0 * scale_factor, y + 2.0 * scale_factor),
        Vector2(x - 1.0 * scale_factor, y + 5.0 * scale_factor), primary, maxf(1.0, scale_factor))

    if stage >= 2:
        # A larger missing panel exposes the dark interior and splintered structural edge.
        var breach_y := y + 5.0 * scale_factor
        canvas.draw_colored_polygon(PackedVector2Array([
            Vector2(x - 5.0 * scale_factor, breach_y - 2.0 * scale_factor),
            Vector2(x - 1.0 * scale_factor, breach_y - 5.0 * scale_factor),
            Vector2(x + 5.0 * scale_factor, breach_y - 3.0 * scale_factor),
            Vector2(x + 4.0 * scale_factor, breach_y + 4.0 * scale_factor),
            Vector2(x - 3.0 * scale_factor, breach_y + 5.0 * scale_factor)
        ]), shadow)
        canvas.draw_line(Vector2(x - 5.0 * scale_factor, breach_y - 2.0 * scale_factor),
            Vector2(x - 1.0 * scale_factor, breach_y - 5.0 * scale_factor), accent, maxf(1.0, scale_factor))
        canvas.draw_line(Vector2(x + 3.0 * scale_factor, breach_y - 3.0 * scale_factor),
            Vector2(x + 6.0 * scale_factor, breach_y + 3.0 * scale_factor), primary, maxf(1.0, scale_factor))
        canvas.draw_colored_polygon(PackedVector2Array([
            Vector2(x - 5.0 * scale_factor, -2.0),
            Vector2(x - 1.0 * scale_factor, -2.0),
            Vector2(x - 3.0 * scale_factor, 1.0)
        ]), shadow)

    if stage >= 3:
        # Heavy damage: a second collapsed roof/wall section and fallen masonry at the foot.
        var collapse_x := -x * 0.55
        var collapse_y := top + maxf(8.0, height * 0.22)
        if flat_structure:
            collapse_y = top + height * 0.48
        canvas.draw_colored_polygon(PackedVector2Array([
            Vector2(collapse_x - 6.0 * scale_factor, collapse_y),
            Vector2(collapse_x - 2.0 * scale_factor, collapse_y - 5.0 * scale_factor),
            Vector2(collapse_x + 3.0 * scale_factor, collapse_y - 2.0 * scale_factor),
            Vector2(collapse_x + 6.0 * scale_factor, collapse_y + 3.0 * scale_factor),
            Vector2(collapse_x + 1.0 * scale_factor, collapse_y + 7.0 * scale_factor),
            Vector2(collapse_x - 5.0 * scale_factor, collapse_y + 5.0 * scale_factor)
        ]), shadow)
        canvas.draw_line(Vector2(collapse_x - 4.0 * scale_factor, collapse_y + 1.0 * scale_factor),
            Vector2(collapse_x + 2.0 * scale_factor, collapse_y + 5.0 * scale_factor), accent, maxf(1.0, scale_factor))
        canvas.draw_rect(Rect2(-half_width * 0.34, -3.0, 4.0 * scale_factor, 2.0 * scale_factor), shadow)
        canvas.draw_rect(Rect2(half_width * 0.12, -2.0, 5.0 * scale_factor, 2.0 * scale_factor), primary)
        if building_id in ["keep", "tower", "barracks", "outpost", "stone_wall"]:
            canvas.draw_line(Vector2(collapse_x, collapse_y - 2.0 * scale_factor),
                Vector2(collapse_x + 7.0 * scale_factor, collapse_y + 8.0 * scale_factor), shadow, 2.0 * scale_factor)
