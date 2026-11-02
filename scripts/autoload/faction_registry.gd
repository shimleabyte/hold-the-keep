extends Node
## Validated, data-driven faction and archetype definitions.
## Faction identity is stable across saves; missing/legacy IDs resolve safely.

var factions: Dictionary = {}
var archetypes: Dictionary = {}


func _ready() -> void:
    _load_definitions("res://data/factions.json", factions, "faction")
    _load_definitions("res://data/enemy_archetypes.json", archetypes, "enemy archetype")


func _load_definitions(path: String, destination: Dictionary, label: String) -> void:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("FactionRegistry: missing %s data at %s" % [label, path])
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if not (parsed is Array):
        push_error("FactionRegistry: %s must be a JSON array" % label)
        return
    for value in parsed:
        if not (value is Dictionary):
            push_error("FactionRegistry: invalid %s entry" % label)
            continue
        var id := String(value.get("id", ""))
        if id.is_empty() or destination.has(id):
            push_error("FactionRegistry: empty or duplicate %s id '%s'" % [label, id])
            continue
        destination[id] = value.duplicate(true)


func faction_for_region(region_id: String) -> String:
    for faction_id in factions:
        if String(factions[faction_id].get("region", "")) == region_id:
            return String(faction_id)
    return ""


func faction_for_stronghold(faction_id: String) -> Dictionary:
    return factions.get(faction_id, {}).duplicate(true)


func garrison_enemy(faction_id: String) -> String:
    var faction: Dictionary = factions.get(faction_id, {})
    var enemy_id := String(faction.get("garrison", "soldier"))
    return enemy_id if DataDB.enemies.has(enemy_id) else "soldier"


func roster_for(faction_id: String) -> Array[String]:
    var faction: Dictionary = factions.get(faction_id, {})
    var out: Array[String] = []
    for value in faction.get("roster", []):
        var enemy_id := String(value)
        if DataDB.enemies.has(enemy_id):
            out.append(enemy_id)
    return out


func validate() -> Array[String]:
    var errors: Array[String] = []
    var visual_motifs: Dictionary = {}
    for faction_id in factions:
        var faction: Dictionary = factions[faction_id]
        if String(faction.get("region", "")).is_empty():
            errors.append("%s has no region" % faction_id)
        var visual: Variant = faction.get("visual", null)
        if not (visual is Dictionary):
            errors.append("%s has no visual identity profile" % faction_id)
        else:
            for palette_key in ["primary", "secondary", "emblem"]:
                var palette_value := String(visual.get(palette_key, ""))
                if not palette_value.begins_with("#") or palette_value.length() not in [7, 9]:
                    errors.append("%s has an invalid visual color: %s" % [faction_id, palette_key])
            var motif := String(visual.get("motif", ""))
            if motif.is_empty():
                errors.append("%s has no visual motif" % faction_id)
            elif visual_motifs.has(motif):
                errors.append("%s shares visual motif '%s' with %s" % [faction_id, motif, visual_motifs[motif]])
            else:
                visual_motifs[motif] = faction_id
        if not DataDB.enemies.has(String(faction.get("garrison", ""))):
            errors.append("%s references a missing garrison enemy" % faction_id)
        var roster := roster_for(String(faction_id))
        if roster.is_empty():
            errors.append("%s has no valid roster" % faction_id)
        var patrol_unit := String(faction.get("patrol_unit", ""))
        if patrol_unit.is_empty() or not DataDB.enemies.has(patrol_unit):
            errors.append("%s references a missing patrol unit" % faction_id)
        var camp: Variant = faction.get("camp", null)
        if not (camp is Dictionary):
            errors.append("%s has no camp configuration" % faction_id)
        else:
            var patrol_radius := float(camp.get("patrol_radius", 0.0))
            var initial_patrols := int(camp.get("initial_patrols", 0))
            var active_cap := int(camp.get("active_patrol_cap", 0))
            var reinforcement_budget := int(camp.get("reinforcement_budget", -1))
            var reinforcement_cooldown := float(camp.get("reinforcement_cooldown", 0.0))
            if patrol_radius < 88.0 or patrol_radius > 190.0:
                errors.append("%s has an invalid patrol radius" % faction_id)
            if initial_patrols < 1 or initial_patrols > active_cap or active_cap > 3:
                errors.append("%s has an invalid initial patrol/cap" % faction_id)
            if reinforcement_budget < 0 or reinforcement_budget > 12:
                errors.append("%s has an invalid reinforcement budget" % faction_id)
            if reinforcement_cooldown < 12.0 or reinforcement_cooldown > 90.0:
                errors.append("%s has an invalid reinforcement cooldown" % faction_id)
    for enemy_id in archetypes:
        if not DataDB.enemies.has(enemy_id):
            errors.append("archetype %s is not registered in DataDB" % enemy_id)
    return errors
