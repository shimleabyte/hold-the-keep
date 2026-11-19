extends SceneTree
## Protects the shared pixel FX layer from perturbing simulation randomness.

const FXLayer := preload("res://scripts/entities/fx_layer.gd")


func require(condition: bool, message: String) -> bool:
    if condition:
        return true
    push_error("FX_LAYER_FAIL: " + message)
    quit(1)
    return false


func _initialize() -> void:
    var expected_seed := 918273
    seed(expected_seed)
    var expected_next_random := randf()

    seed(expected_seed)
    var isolated := FXLayer.new()
    isolated.spawn("impact", Vector2(32.0, 48.0), Vector2.RIGHT, 1.0)
    var actual_next_random := randf()
    if not require(is_equal_approx(actual_next_random, expected_next_random),
            "FX bursts must not consume or reseed the gameplay global RNG"):
        return

    var first := FXLayer.new()
    var second := FXLayer.new()
    first.spawn("heavy_impact", Vector2(88.0, 144.0), Vector2.LEFT, 1.25)
    second.spawn("heavy_impact", Vector2(88.0, 144.0), Vector2.LEFT, 1.25)
    if not require(first.count() == second.count() and first.count() > 0,
            "Equivalent bursts must create the same number of particles"):
        return
    if not require(first._pos == second._pos and first._vel == second._vel
            and first._life == second._life and first._col == second._col,
            "Equivalent burst inputs and sequence numbers must render deterministically"):
        return

    var test_directions := [
        Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.DOWN,
        Vector2(1.0, -1.0).normalized(), Vector2(-1.0, 1.0).normalized()
    ]
    for direction in test_directions:
        for effect_kind in ["heavy_impact", "structure_debris"]:
            var directed := FXLayer.new()
            directed.spawn(effect_kind, Vector2.ZERO, direction, 1.0)
            var minimum_dot := cos(float(FXLayer.DIRECTIONAL_SPREAD[effect_kind])) - 0.0001
            for velocity in directed._vel:
                if not require(velocity.normalized().dot(direction) >= minimum_dot,
                        "Directional cones must preserve their exact axis for %s, including diagonal and vertical directions" % effect_kind):
                    return
            directed.free()

    var rubble := FXLayer.new()
    rubble.spawn("structure_debris", Vector2.ZERO, Vector2.DOWN, 1.5)
    if not require(rubble.count() == 18,
            "A heavy structural hit should eject a bounded cluster of 18 visible debris pieces"):
        return
    for particle_size in rubble._size:
        if not require(particle_size >= 5.0 and particle_size <= 6.0,
                "Structure debris must read as large outlined material fragments rather than small sparks"):
            return
    rubble.free()

    var capped := FXLayer.new()
    capped.spawn("impact", Vector2.ZERO, Vector2.ZERO, 100.0)
    if not require(capped.count() == 500,
            "A single burst must respect the shared particle budget"):
        return

    var unchanged_count := capped.count()
    capped.spawn("unknown_effect", Vector2.ZERO, Vector2.RIGHT, 1.0)
    capped.spawn("impact", Vector2.ZERO, Vector2.ZERO, 0.0)
    if not require(capped.count() == unchanged_count,
            "Unknown or zero-strength bursts must be no-ops"):
        return

    isolated.free()
    first.free()
    second.free()
    capped.free()
    print("PASS: isolated RNG, repeatable burst frames, directional impact cone and bounded particle count")
    quit(0)
