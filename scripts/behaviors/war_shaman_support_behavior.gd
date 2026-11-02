extends RefCounted
## War Shaman healing policy; intentionally separate from the shared ranged attack loop.

const ENEMY_SUPPORT := preload("res://scripts/systems/enemy_support.gd")

var actor
var radius := 0.0
var amount := 0
var interval := 0.0
var cooldown := 0.0


func configure(owner, data: Dictionary) -> void:
    actor = owner
    radius = maxf(0.0, float(data.get("support_radius", 0.0)))
    amount = maxi(0, int(data.get("support_amount", 0)))
    interval = maxf(0.0, float(data.get("support_interval", 0.0)))
    cooldown = 0.0


func advance_timers(delta: float) -> void:
    cooldown = maxf(0.0, cooldown - delta)


func tick() -> bool:
    if amount <= 0 or radius <= 0.0 or cooldown > 0.0:
        return false
    if not ENEMY_SUPPORT.heal_nearest_ally(actor, radius, amount):
        return false
    cooldown = maxf(0.5, interval)
    return true
