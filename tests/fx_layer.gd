extends SceneTree
## Protects the shared pixel FX layer from perturbing simulation randomness.

const FXLayer := preload("res://scripts/entities/fx_layer.gd")


func _initialize() -> void:
    var expected_seed := 918273
    seed(expected_seed)
    var expected_next_random := randf()

    seed(expected_seed)
    var isolated := FXLayer.new()
    isolated.spawn("impact", Vector2(32.0, 48.0), Vector2.RIGHT, 1.0)
    var actual_next_random := randf()
    assert(is_equal_approx(actual_next_random, expected_next_random),
        "FX bursts must not consume or reseed the gameplay global RNG")

    var first := FXLayer.new()
    var second := FXLayer.new()
    first.spawn("heavy_impact", Vector2(88.0, 144.0), Vector2.LEFT, 1.25)
    second.spawn("heavy_impact", Vector2(88.0, 144.0), Vector2.LEFT, 1.25)
    assert(first.count() == second.count() and first.count() > 0,
        "Equivalent bursts must create the same number of particles")
    assert(first._pos == second._pos and first._vel == second._vel
        and first._life == second._life and first._col == second._col,
        "Equivalent burst inputs and sequence numbers must render deterministically")

    for velocity in first._vel:
        assert(velocity.normalized().dot(Vector2.LEFT) >= 0.90,
            "Directed impact particles must stay inside the authored forward cone")

    var capped := FXLayer.new()
    capped.spawn("impact", Vector2.ZERO, Vector2.ZERO, 100.0)
    assert(capped.count() == 500,
        "A single burst must respect the shared particle budget")

    var unchanged_count := capped.count()
    capped.spawn("unknown_effect", Vector2.ZERO, Vector2.RIGHT, 1.0)
    capped.spawn("impact", Vector2.ZERO, Vector2.ZERO, 0.0)
    assert(capped.count() == unchanged_count,
        "Unknown or zero-strength bursts must be no-ops")

    isolated.free()
    first.free()
    second.free()
    capped.free()
    print("PASS: isolated RNG, repeatable burst frames, directional impact cone and bounded particle count")
    quit(0)
