extends SceneTree
## Unit regression for combo timing, Resolve bounds and Riposte consumption.

const PlayerCombatFlow := preload("res://scripts/entities/player_combat_flow.gd")


func _initialize() -> void:
    var flow = PlayerCombatFlow.new()

    var first: Dictionary = flow.begin_attack()
    assert(first["visual"] == "quick" and is_equal_approx(float(first["damage_scale"]), 0.90),
        "The combo must begin with a quick first strike")

    flow.advance(0.40)
    var second: Dictionary = flow.begin_attack()
    assert(second["visual"] == "cross" and float(second["reach"]) > float(first["reach"]),
        "The second strike must chain within the timing window and widen its reach")

    flow.advance(0.40)
    var third: Dictionary = flow.begin_attack()
    assert(third["visual"] == "finisher" and float(third["stagger"]) > float(second["stagger"]),
        "The third strike must be a heavier finisher with stronger stagger")

    flow.advance(PlayerCombatFlow.COMBO_RESET_TIME + 0.01)
    var reset_strike: Dictionary = flow.begin_attack()
    assert(reset_strike["visual"] == "quick",
        "Letting the combo window expire must reset the next attack to the first strike")

    flow.add_resolve(150.0)
    assert(is_equal_approx(float(flow.status()["resolve"]), PlayerCombatFlow.RESOLVE_MAX),
        "Resolve must clamp to its maximum")
    assert(not flow.try_spend_resolve(101.0),
        "Resolve spending must fail without consuming an insufficient balance")
    assert(flow.try_spend_resolve(60.0),
        "Empowered Cleave must be affordable with at least 60 Resolve")
    assert(is_equal_approx(float(flow.status()["resolve"]), 40.0),
        "Resolve spending must deduct the requested amount")

    flow.register_perfect_dodge()
    var dodge_status: Dictionary = flow.status()
    assert(dodge_status["riposte_ready"] and float(dodge_status["resolve"]) == 64.0,
        "Perfect Dodge must grant Resolve and open a Riposte window")

    var riposte: Dictionary = flow.begin_attack()
    assert(riposte["visual"] == "riposte"
        and float(riposte["damage_scale"]) > float(reset_strike["damage_scale"])
        and float(riposte["stagger"]) > float(reset_strike["stagger"]),
        "The next basic attack must consume Riposte and gain damage and stagger")
    assert(not flow.status()["riposte_ready"],
        "Riposte must be consumed by the next basic attack")

    flow.advance(PlayerCombatFlow.RIPOSTE_DURATION + 0.01)
    assert(not flow.status()["riposte_ready"],
        "Riposte must expire deterministically when unused")

    flow.reset()
    assert(is_equal_approx(float(flow.status()["resolve"]), 0.0)
        and int(flow.status()["combo_step"]) == 0,
        "Death/reset cleanup must clear transient combat state")

    print("PASS: three-hit combo, timeout reset, Resolve cap/spending, perfect-dodge Riposte and reset")
    quit(0)
