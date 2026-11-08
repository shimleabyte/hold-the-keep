extends SceneTree
## Phase 08.4 regression: faction palettes/motifs and six archetype signatures.

const FactionVisual := preload("res://scripts/entities/enemy_faction_visual.gd")

const EXPECTED_MOTIFS := {
    "greenwood_raiders": "thorn",
    "iron_legion": "chevron",
    "fen_cult": "reed",
    "ashen_host": "ember"
}


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var registry = root.get_node("FactionRegistry")
    var data_db = root.get_node("DataDB")
    var errors: Array[String] = registry.validate()
    assert(errors.is_empty(), "Faction visual profiles must pass registry validation: %s" % "; ".join(errors))
    assert(registry.factions.size() == 4, "Frontier must retain four distinct factions")
    assert(registry.archetypes.size() == 6, "Frontier must retain six specialist archetypes")

    var seen_motifs: Dictionary = {}
    var enemy_script := load("res://scripts/entities/enemy.gd") as GDScript
    assert(enemy_script != null and enemy_script.can_instantiate(),
        "Enemy host must compile with the visual identity helper")

    for faction_id in EXPECTED_MOTIFS:
        var faction: Dictionary = registry.faction_for_stronghold(faction_id)
        var visual: Dictionary = faction.get("visual", {})
        assert(visual.size() == 4, "Each faction must define a complete visual palette and motif")
        assert(String(visual.get("motif", "")) == String(EXPECTED_MOTIFS[faction_id]),
            "Each faction must retain its distinct heraldic motif")
        assert(not seen_motifs.has(String(visual["motif"])),
            "No two factions may share the same visual motif")
        seen_motifs[String(visual["motif"])] = true
        for key in ["primary", "secondary", "emblem"]:
            assert(String(visual.get(key, "")).begins_with("#"),
                "Faction palette entries must be explicit hex colors")

        for archetype_id in registry.archetypes:
            var archetype_data: Dictionary = registry.archetypes[archetype_id]
            var archetype_kind := String(archetype_data.get("archetype", ""))
            var enemy = enemy_script.new()
            enemy.setup(data_db.enemies[archetype_id], null, null, null, faction_id)
            assert(enemy.faction_visual == visual,
                "Enemy setup must attach its faction visual data without changing combat identity")
            var layers: Array[String] = FactionVisual.signature(enemy.faction_visual, archetype_kind)
            assert(layers.size() == 2
                and layers[0] == String(visual["motif"])
                and layers[1] == archetype_kind,
                "Every faction/archetype pair must resolve both heraldic and specialist visual layers")
            enemy.free()

    var stronghold_script := load("res://scripts/entities/enemy_keep.gd") as GDScript
    assert(stronghold_script != null and stronghold_script.can_instantiate(),
        "Rival stronghold renderer must compile with faction-specific architecture")
    var stronghold_constants: Dictionary = stronghold_script.get_script_constant_map()
    var stronghold_sprites: Dictionary = stronghold_constants.get("FACTION_SPRITES", {})
    assert(stronghold_sprites.size() == EXPECTED_MOTIFS.size(),
        "Each Frontier faction must have its own stronghold sprite")
    var seen_stronghold_sprites: Dictionary = {}
    for faction_id in EXPECTED_MOTIFS:
        var stronghold_texture: Texture2D = stronghold_sprites.get(faction_id) as Texture2D
        assert(stronghold_texture != null
            and stronghold_texture.get_width() == 48
            and stronghold_texture.get_height() == 56,
            "Faction stronghold art must preserve the shared 3x3 footprint silhouette: " + faction_id)
        assert(not seen_stronghold_sprites.has(stronghold_texture.get_instance_id()),
            "Faction strongholds must not alias a shared placeholder sprite")
        seen_stronghold_sprites[stronghold_texture.get_instance_id()] = faction_id
    var fallback_stronghold: Texture2D = stronghold_constants.get("SPRITE") as Texture2D
    assert(fallback_stronghold != null
        and fallback_stronghold.get_width() == 48
        and fallback_stronghold.get_height() == 56,
        "Classic/legacy rival keeps must retain the neutral fallback sprite")

    var classic_enemy = enemy_script.new()
    classic_enemy.setup(data_db.enemies["bandit"], null, null, null, "")
    assert(classic_enemy.faction_visual.is_empty(),
        "Classic and legacy enemies without a faction ID must not receive Frontier heraldry")
    classic_enemy.free()

    print("PASS: four unique faction motifs, three-color palettes, six archetype equipment signatures and Classic visual isolation")
    quit(0)
