extends RefCounted
## Maps occupations to focused behavior components. Soldier and Archer share military behavior.

const ROLE_SCRIPTS := {
    "woodcutter": preload("res://scripts/behaviors/villagers/gatherer_role_behavior.gd"),
    "miner": preload("res://scripts/behaviors/villagers/gatherer_role_behavior.gd"),
    "hunter": preload("res://scripts/behaviors/villagers/gatherer_role_behavior.gd"),
    "farmer": preload("res://scripts/behaviors/villagers/farmer_role_behavior.gd"),
    "builder": preload("res://scripts/behaviors/villagers/builder_role_behavior.gd"),
    "healer": preload("res://scripts/behaviors/villagers/healer_role_behavior.gd"),
    "blacksmith": preload("res://scripts/behaviors/villagers/blacksmith_role_behavior.gd"),
    "scout": preload("res://scripts/behaviors/villagers/scout_role_behavior.gd"),
    "soldier": preload("res://scripts/behaviors/villagers/soldier_role_behavior.gd"),
    "archer": preload("res://scripts/behaviors/villagers/soldier_role_behavior.gd"),
}


static func create(role: String, owner: Variant) -> Variant:
    var behavior_script: Script = ROLE_SCRIPTS.get(role)
    if behavior_script == null:
        return null
    var behavior: Variant = behavior_script.new()
    behavior.configure(owner)
    return behavior
