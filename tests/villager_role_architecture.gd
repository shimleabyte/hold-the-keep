extends SceneTree
## DEV-F: role registry, delegation and role-owned transient state contracts.

const VillagerScript := preload("res://scripts/entities/villager.gd")


func _initialize() -> void:
    var worker = VillagerScript.new()
    var roles: Array[String] = [
        "woodcutter",
        "miner",
        "hunter",
        "farmer",
        "builder",
        "soldier",
        "scout",
        "healer",
        "blacksmith"
    ]
    for role in roles:
        var previous: Variant = worker.role_behavior
        worker.job = role
        assert(worker.role_behavior != null, "%s must receive a role behavior" % role)
        assert(worker.role_behavior.actor == worker, "%s behavior must bind to its owning Villager" % role)
        assert(worker.role_behavior.role_id() == role, "%s must resolve to its own behavior identity" % role)
        if previous != null:
            assert(previous != worker.role_behavior, "Changing occupation must replace the previous role component")

    worker.job = "scout"
    var scout_behavior: Variant = worker.role_behavior
    worker._scout_target_cell = Vector2i(13, 21)
    assert(scout_behavior.get_scout_target_cell() == Vector2i(13, 21),
        "Scout target state must be owned by Scout behavior")
    scout_behavior.reset_scout_state()
    assert(worker._scout_target_cell == Vector2i(-1, -1),
        "Scout reset must clear its role-owned target state")

    worker.job = "blacksmith"
    worker._smith_recipe = "armor"
    assert(worker.role_behavior.get_smith_recipe() == "armor",
        "Blacksmith recipe state must be owned by Blacksmith behavior")
    worker.job = "miner"
    assert(worker._smith_recipe.is_empty(),
        "Switching away from Blacksmith must discard its transient recipe state")

    worker.job = "archer"
    assert(worker.job == "soldier" and worker.is_archer(),
        "Archers must remain soldiers at the entity boundary")
    assert(worker.role_behavior.role_id() == "soldier",
        "Archers must reuse the Soldier behavior instead of creating a second lifecycle")
    worker.free()
    print("PASS: Villager role registry, lifecycle replacement, role-owned Scout/Blacksmith state and Archer/Soldier behavior alias")
    quit()
