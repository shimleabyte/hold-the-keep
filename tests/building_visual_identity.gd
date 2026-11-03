extends SceneTree
## Phase 08.5 regression: building identity profiles and damage-stage thresholds.

const BuildingVisual := preload("res://scripts/entities/building_visual_identity.gd")

const EXPECTED_BUILDINGS := [
    "keep", "house", "wall", "tower", "granary", "storage", "farm", "outpost",
    "stone_wall", "forge", "lumber_camp", "quarry", "hunting_lodge", "scout_post", "road", "bridge"
]


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var data_db = root.get_node("DataDB")
    assert(data_db.buildings.size() == EXPECTED_BUILDINGS.size(),
        "The visual pass must cover every currently shipped building definition")

    var features: Dictionary = {}
    for building_id in EXPECTED_BUILDINGS:
        assert(data_db.buildings.has(building_id),
            "Missing expected shipped building: " + building_id)
        var definition: Dictionary = data_db.buildings[building_id]
        var visual: Variant = definition.get("visual", null)
        assert(visual is Dictionary,
            "Every shipped structure must define a visual identity profile: " + building_id)
        assert(String(visual.get("material", "")).length() >= 4,
            "Every building profile must identify its material: " + building_id)
        for palette_key in ["primary", "accent", "shadow"]:
            var palette_value := String(visual.get(palette_key, ""))
            assert(palette_value.begins_with("#") and palette_value.length() in [7, 9],
                "Building palette must use explicit hex colors: " + building_id + "/" + palette_key)
        var feature := String(visual.get("feature", ""))
        assert(not feature.is_empty() and not features.has(feature),
            "Each building must have a unique visual detail key: " + building_id)
        features[feature] = building_id
        var resolved: Array[String] = BuildingVisual.signature(building_id, visual)
        assert(resolved.size() == 3
            and resolved[0] == building_id
            and resolved[1] == String(visual["material"])
            and resolved[2] == feature,
            "The building visual profile must resolve into a stable signature")

    assert(features.size() == EXPECTED_BUILDINGS.size(),
        "All building feature signatures must be unique")
    assert(BuildingVisual.enabled("frontier", data_db.buildings["keep"]["visual"]),
        "Frontier must enable the visual identity overlay")
    assert(not BuildingVisual.enabled("classic", data_db.buildings["keep"]["visual"]),
        "Classic visuals must remain unchanged by the Frontier identity pass")
    assert(not BuildingVisual.enabled("frontier", {}),
        "Buildings with no visual metadata must safely skip the overlay")

    assert(BuildingVisual.damage_stage(100, 100) == 0,
        "Healthy buildings must not display damage marks")
    assert(BuildingVisual.damage_stage(75, 100) == 0,
        "The first damage threshold must begin below 75 percent health")
    assert(BuildingVisual.damage_stage(74, 100) == 1,
        "Light damage must begin below 75 percent health")
    assert(BuildingVisual.damage_stage(50, 100) == 1,
        "The light damage band must include 50 percent health")
    assert(BuildingVisual.damage_stage(49, 100) == 2,
        "Medium damage must begin below 50 percent health")
    assert(BuildingVisual.damage_stage(25, 100) == 2,
        "The medium damage band must include 25 percent health")
    assert(BuildingVisual.damage_stage(24, 100) == 3,
        "Heavy damage must begin below 25 percent health")
    assert(BuildingVisual.damage_stage(0, 100) == 3,
        "Destroyed buildings must resolve to the heaviest damage stage")
    assert(BuildingVisual.damage_stage(0, 0) == 3,
        "Invalid maximum HP must safely resolve to the heaviest damage stage")

    var building_script := load("res://scripts/entities/building.gd") as GDScript
    assert(building_script != null and building_script.can_instantiate(),
        "Building rendering must compile with the new Frontier visual helper")
    print("PASS: 16 distinct building materials/details, Frontier-only rendering and four deterministic damage states")
    quit(0)
