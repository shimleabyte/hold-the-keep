extends SceneTree
## Motion regression: body transforms must be visibly distinct through each combat phase.

const PlayerCombatMotion := preload("res://scripts/entities/player_combat_motion.gd")


func _initialize() -> void:
    var motion = PlayerCombatMotion.new()
    var neutral: Dictionary = motion.pose()
    assert(neutral["offset"] == Vector2.ZERO and neutral["scale"] == Vector2.ONE,
        "Inactive combat motion must not alter the player pose")

    motion.play("quick", Vector2.RIGHT, 0.24)
    motion.advance(0.03)
    var quick_windup: Dictionary = motion.pose()
    assert(float(quick_windup["offset"].x) < -1.0
        and float(quick_windup["scale"].y) < 0.95,
        "Quick Slash must visibly pull the body back and compress before impact")

    motion.advance(0.11)
    var quick_strike: Dictionary = motion.pose()
    assert(float(quick_strike["offset"].x) > 4.0
        and float(quick_strike["rotation"]) > 0.05
        and float(quick_strike["scale"].y) > 1.05,
        "Quick Slash must drive the body forward with follow-through stretch")

    motion.advance(0.08)
    var quick_recovery: Dictionary = motion.pose()
    assert(float(quick_recovery["offset"].length()) < float(quick_strike["offset"].length()),
        "Quick Slash must visibly recover toward the neutral stance")

    motion.play("quick", Vector2.LEFT, 0.24)
    motion.advance(0.14)
    var left_quick: Dictionary = motion.pose()
    assert(float(left_quick["offset"].x) < -4.0
        and float(left_quick["rotation"]) < -0.05,
        "Mirrored left attacks must move and twist left, not reuse right-facing motion")

    motion.play("cross", Vector2.RIGHT, 0.29)
    motion.advance(0.14)
    var cross_pose: Dictionary = motion.pose()
    assert(float(cross_pose["offset"].y) < -1.0,
        "Cross Slash must transfer body weight laterally instead of reusing Quick Slash")

    motion.play("finisher", Vector2.RIGHT, 0.42)
    motion.advance(0.12)
    var finisher_load: Dictionary = motion.pose()
    assert(float(finisher_load["scale"].y) < 0.85
        and float(finisher_load["offset"].x) < -2.0,
        "Finisher must crouch and load weight before the heavy strike")
    motion.advance(0.19)
    var finisher_impact: Dictionary = motion.pose()
    assert(float(finisher_impact["offset"].x) > 5.0
        and float(finisher_impact["scale"].y) > 1.1,
        "Finisher must commit to a large forward body drive")

    motion.play("riposte", Vector2.UP, 0.3)
    motion.advance(0.15)
    var riposte_pose: Dictionary = motion.pose()
    assert(float(riposte_pose["offset"].y) < -5.0,
        "Riposte must have a distinct forward counter-lunge")

    motion.play("cleave_empowered", Vector2.DOWN, 0.46)
    motion.advance(0.31)
    var empowered_pose: Dictionary = motion.pose()
    assert(float(empowered_pose["offset"].y) > 5.0
        and float(empowered_pose["scale"].y) > 1.1,
        "Empowered Cleave must use a stronger committed body follow-through")

    motion.play("rally", Vector2.UP, 0.62)
    motion.advance(0.40)
    var rally_pose: Dictionary = motion.pose()
    assert(float(rally_pose["offset"].y) < -1.0
        and float(rally_pose["scale"].y) > 1.0,
        "Rally must animate the player into a raised command stance")

    motion.play("dash", Vector2.RIGHT, 0.22)
    motion.advance(0.06)
    var dash_pose: Dictionary = motion.pose()
    assert(float(dash_pose["scale"].x) > 1.0
        and float(dash_pose["scale"].y) < 0.9,
        "Dash must lean and compress the body into its movement direction")

    motion.clear()
    assert(motion.pose()["offset"] == Vector2.ZERO and not motion.is_active(),
        "Clearing combat motion must restore the exact neutral pose")

    print("PASS: directional attack wind-up, lunge, follow-through, recovery, finisher, riposte, cleave, rally and dash poses")
    quit(0)
