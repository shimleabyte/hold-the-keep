extends SceneTree
## Phase 08.6 regression: combat visual cues are deterministic, transient and behavior-neutral.

const CombatVisualFeedback := preload("res://scripts/entities/combat_visual_feedback.gd")


func _initialize() -> void:
    var feedback := CombatVisualFeedback.new()

    feedback.begin_windup(Vector2.RIGHT, 0.2, false)
    assert(feedback.is_active() and feedback.windup_direction == Vector2.RIGHT,
        "Melee anticipation must expose a stable facing direction")
    assert(not feedback.windup_projectile,
        "Melee anticipation must not use the projectile cue")
    assert(feedback.advance(0.1) and is_equal_approx(feedback.windup_remaining, 0.1),
        "Windup should decay by simulation delta")
    feedback.end_windup()
    assert(feedback.windup_remaining == 0.0 and not feedback.windup_projectile,
        "Resolved or cancelled attacks must clear anticipation")
    feedback.begin_windup(Vector2.UP, 0.14, true)
    assert(feedback.windup_projectile,
        "Ranged anticipation must expose the projectile cue")
    feedback.end_windup()

    feedback.register_hit(Vector2(-10.0, 0.0), Vector2.ZERO, 1.8)
    assert(feedback.impact_remaining > 0.0
        and feedback.impact_direction == Vector2.LEFT
        and is_equal_approx(feedback.impact_strength, 1.8),
        "Impact feedback must retain source direction and bounded strength")
    feedback.advance(0.08)
    assert(feedback.impact_remaining > 0.0,
        "Impact burst must remain visible briefly after a hit")
    feedback.advance(0.2)
    assert(feedback.impact_remaining == 0.0,
        "Impact burst must expire without a persistent actor state")

    feedback.register_stagger(0.5)
    feedback.advance(0.1)
    assert(is_equal_approx(feedback.stagger_remaining, 0.4),
        "Stagger marker must track the same transient duration without modifying gameplay timers")
    feedback.register_stagger(0.2)
    assert(is_equal_approx(feedback.stagger_remaining, 0.4),
        "Short repeated stagger cues must not shorten the current feedback window")
    feedback.advance(1.0)
    assert(feedback.stagger_remaining == 0.0,
        "Stagger marks must clear after the control cue expires")

    feedback.register_ability("dash", Vector2.RIGHT, 0.22)
    assert(feedback.ability_kind == "dash" and feedback.is_active(),
        "Dash must resolve to its directional trail cue")
    feedback.register_ability("cleave", Vector2.DOWN, 0.42)
    assert(feedback.ability_kind == "cleave"
        and feedback.ability_direction == Vector2.DOWN,
        "Cleave must retain its locked direction in the ability cue")
    assert(is_equal_approx(CombatVisualFeedback.CLEAVE_HALF_ANGLE, 1.2),
        "Cleave anticipation must use the same half-angle as the damaging player arc")
    feedback.register_ability("rally", Vector2.ZERO, 0.35)
    assert(feedback.ability_kind == "rally",
        "Rally must resolve to its distinct radial cue")
    feedback.advance(0.5)
    assert(not feedback.is_active() and feedback.ability_kind.is_empty(),
        "All feedback must expire deterministically")

    var player_script := load("res://scripts/entities/player.gd") as GDScript
    var enemy_script := load("res://scripts/entities/enemy.gd") as GDScript
    assert(player_script != null and player_script.can_instantiate(),
        "Player must compile with combat feedback integration")
    assert(enemy_script != null and enemy_script.can_instantiate(),
        "Enemy must compile with combat feedback integration")
    print("PASS: melee/ranged anticipation, directional impact, stagger and dash/cleave/rally visual lifetimes")
    quit(0)
