extends SceneTree
## Chunk 06 regression: visible structure stages, research-driven architecture, and renderer compatibility.

const BuildingVisual := preload("res://scripts/entities/building_visual_identity.gd")
const EXPECTED_BUILDINGS := [
    "keep", "house", "wall", "tower", "granary", "storage", "farm", "outpost",
    "stone_wall", "forge", "lumber_camp", "quarry", "hunting_lodge", "scout_post",
    "infirmary", "road", "bridge", "barracks", "archery_range"
]


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var data_db = root.get_node("DataDB")
    assert(data_db.buildings.size() == EXPECTED_BUILDINGS.size(),
        "The architectural pass must not add or remove catalog entries")

    for building_id in EXPECTED_BUILDINGS:
        assert(data_db.buildings.has(building_id), "Missing building definition: " + building_id)
        var visual: Variant = data_db.buildings[building_id].get("visual", null)
        assert(visual is Dictionary, "Every shipped structure keeps its visual profile: " + building_id)
        assert(BuildingVisual.signature(building_id, visual).size() == 3,
            "Existing material and feature signatures remain valid: " + building_id)
        for profile in ["classic", "frontier", "frontier_expedition"]:
            assert(BuildingVisual.enabled(profile, visual),
                "Architectural details must remain available in every shipped world profile")

    # Work ratios map to distinctly authored physical construction states.
    assert(BuildingVisual.construction_stage(0.0) == 0, "Zero work must show only the prepared foundation")
    assert(BuildingVisual.construction_stage(0.08) == 0, "Early site must remain at foundation stage")
    assert(BuildingVisual.construction_stage(0.34) == 1, "One-third progress must show structural framing")
    assert(BuildingVisual.construction_stage(0.63) == 2, "Mid progress must show partial walls and roof structure")
    assert(BuildingVisual.construction_stage(0.91) == 3, "Late progress must show the nearly finished building")
    assert(BuildingVisual.construction_stage(1.0) == 3, "Complete work ratio remains in the finishing state")
    assert(BuildingVisual.construction_stage(-1.0) == 0, "Construction ratio clamps below zero")
    assert(BuildingVisual.construction_stage(2.0) == 3, "Construction ratio clamps above one")

    # These are the structural upgrades currently shipped in the technology catalog.
    assert(BuildingVisual.upgrade_signature("house", ["longhouse"]) == ["longhouse_loft"],
        "Longhouse research must add a visible upper storey")
    assert(BuildingVisual.upgrade_signature("tower", ["stone_towers"]) == ["stone_tower_gallery"],
        "Stone Towers must add a wider stone fighting gallery")
    assert(BuildingVisual.upgrade_signature("tower", ["stone_towers", "iron_towers"]) == [
        "stone_tower_gallery", "iron_tower_bracing"
    ], "Iron Towers must add reinforcement on top of the stone gallery")
    assert(BuildingVisual.upgrade_signature("wall", ["palisade"]) == ["palisade_reinforcement"],
        "Palisade research must visibly reinforce wooden walls")
    assert(BuildingVisual.upgrade_signature("keep", ["fortress"]) == ["fortress_gatehouse"],
        "Fortress research must visibly reinforce the Keep gatehouse")
    assert(BuildingVisual.upgrade_signature("stone_wall", ["fortress"]) == ["fortress_masonry"],
        "Fortress research must visibly reinforce stone wall capstones")
    assert(BuildingVisual.upgrade_signature("forge", ["fortress"]).is_empty(),
        "Unrelated buildings must not receive decorative upgrade marks")

    # Progressive damage thresholds are unchanged; stronger marks are presentation-only.
    assert(BuildingVisual.damage_stage(100, 100) == 0, "Healthy structure has no damage")
    assert(BuildingVisual.damage_stage(74, 100) == 1, "Light structural damage begins below 75% HP")
    assert(BuildingVisual.damage_stage(49, 100) == 2, "Major structural damage begins below 50% HP")
    assert(BuildingVisual.damage_stage(24, 100) == 3, "Collapse stage begins below 25% HP")
    assert(BuildingVisual.damage_stage(0, 100) == 3, "Zero HP resolves to the heavy damage state")

    # Shared renderer consumers must still compile with the existing static-body architecture.
    for path in [
        "res://scripts/entities/building.gd",
        "res://scripts/entities/construction_site.gd",
        "res://scripts/entities/enemy_keep.gd",
        "res://scripts/entities/enemy_settlement_structure.gd"
    ]:
        var script := load(path) as GDScript
        assert(script != null and script.can_instantiate(), "Renderer failed to compile: " + path)

    print("PASS: 19 building profiles, 4 construction stages, 6 structural upgrade states, 4 damage stages, and all renderer consumers")
    quit(0)
