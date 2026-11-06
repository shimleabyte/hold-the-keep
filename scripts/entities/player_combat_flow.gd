extends RefCounted
## Owns the transient player combat loop: combo timing, Resolve and Riposte.
## This component deliberately has no Node, rendering, movement, or damage dependencies.

const COMBO_RESET_TIME := 0.82
const RESOLVE_MAX := 100.0
const RIPOSTE_DURATION := 1.10
const RIPOSTE_DAMAGE_MULTIPLIER := 1.35

const ATTACK_CHAIN := [
    {
        "damage_scale": 0.90,
        "reach": 24.0,
        "arc_min_dot": 0.50,
        "draw_half_angle": 0.78,
        "hit_delay": 0.11,
        "swing_time": 0.24,
        "animation_fps": 17.0,
        "stagger": 0.0,
        "resolve_on_hit": 8.0,
        "visual": "quick"
    },
    {
        "damage_scale": 1.12,
        "reach": 26.0,
        "arc_min_dot": 0.32,
        "draw_half_angle": 1.02,
        "hit_delay": 0.13,
        "swing_time": 0.29,
        "animation_fps": 15.0,
        "stagger": 0.16,
        "resolve_on_hit": 10.0,
        "visual": "cross"
    },
    {
        "damage_scale": 1.62,
        "reach": 29.0,
        "arc_min_dot": 0.0,
        "draw_half_angle": 1.24,
        "hit_delay": 0.19,
        "swing_time": 0.42,
        "animation_fps": 10.0,
        "stagger": 0.52,
        "resolve_on_hit": 14.0,
        "visual": "finisher"
    }
]

var _combo_index := -1
var _combo_timer := 0.0
var _riposte_timer := 0.0
var _resolve := 0.0


func advance(delta: float) -> void:
    _combo_timer = maxf(0.0, _combo_timer - delta)
    _riposte_timer = maxf(0.0, _riposte_timer - delta)

    if _combo_timer <= 0.0:
        _combo_index = -1


func begin_attack() -> Dictionary:
    if _combo_timer <= 0.0 or _combo_index < 0:
        _combo_index = 0
    else:
        _combo_index = (_combo_index + 1) % ATTACK_CHAIN.size()

    _combo_timer = COMBO_RESET_TIME
    var profile: Dictionary = ATTACK_CHAIN[_combo_index].duplicate(true)

    if _riposte_timer > 0.0:
        profile["damage_scale"] = float(profile["damage_scale"]) * RIPOSTE_DAMAGE_MULTIPLIER
        profile["stagger"] = float(profile["stagger"]) + 0.20
        profile["resolve_on_hit"] = float(profile["resolve_on_hit"]) + 6.0
        profile["visual"] = "riposte"
        _riposte_timer = 0.0

    return profile


func add_resolve(amount: float) -> void:
    _resolve = clampf(_resolve + maxf(0.0, amount), 0.0, RESOLVE_MAX)


func try_spend_resolve(amount: float) -> bool:
    if amount < 0.0 or _resolve < amount:
        return false
    _resolve = maxf(0.0, _resolve - amount)
    return true


func register_perfect_dodge() -> void:
    add_resolve(24.0)
    _riposte_timer = RIPOSTE_DURATION


func reset() -> void:
    _combo_index = -1
    _combo_timer = 0.0
    _riposte_timer = 0.0
    _resolve = 0.0


func status() -> Dictionary:
    return {
        "resolve": _resolve,
        "resolve_max": RESOLVE_MAX,
        "combo_step": _combo_index + 1 if _combo_timer > 0.0 else 0,
        "combo_remaining": _combo_timer,
        "riposte_remaining": _riposte_timer,
        "riposte_ready": _riposte_timer > 0.0,
        "cleave_empowered_ready": _resolve >= 60.0
    }
