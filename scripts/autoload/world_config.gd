extends Node
## Single source of truth for world dimensions and profile-level generation settings.
## Classic remains the default until the expanded Frontier profile is implemented and tested.

const TILE_SIZE := 16
const DEFAULT_SEED := 1337
const PROFILES: Dictionary = {
    "classic": {
        "map_size": 64,
        "starting_claim_radius": 10.0,
        "safe_radius": 8.0,
        "iron_veins": 8
    },
    "frontier": {
        "map_size": 128,
        "starting_claim_radius": 15.0,
        "safe_radius": 12.0,
        "iron_veins": 32
    }
}

var profile_id := "classic"
var map_size := 64
var tile_size := TILE_SIZE
var map_cells := 64 * 64
var starting_claim_radius := 10.0
var safe_radius := 8.0
var iron_veins := 8
var world_seed := DEFAULT_SEED


func _ready() -> void:
    var requested_profile := String(ProjectSettings.get_setting("world/profile", "classic"))
    # The last selected world profile is a player preference. Read it here because
    # WorldConfig is initialized before the Settings autoload.
    var preferences := ConfigFile.new()
    if preferences.load("user://settings.cfg") == OK:
        requested_profile = String(preferences.get_value("world", "profile", requested_profile))
    if not PROFILES.has(requested_profile):
        push_error("WorldConfig: unknown world profile '%s'; falling back to Classic" % requested_profile)
        requested_profile = "classic"

    _apply_profile_values(requested_profile)
    world_seed = int(ProjectSettings.get_setting("world/seed", DEFAULT_SEED))


## Switches the profile before the main scene is rebuilt. Never call this mid-world.
func apply_profile(id: String) -> bool:
    if not PROFILES.has(id):
        push_error("WorldConfig: cannot apply unknown profile '%s'" % id)
        return false
    _apply_profile_values(id)
    ProjectSettings.set_setting("world/profile", id)
    return true


func _apply_profile_values(id: String) -> void:
    profile_id = id
    var profile: Dictionary = PROFILES[profile_id]
    map_size = int(profile["map_size"])
    tile_size = TILE_SIZE
    map_cells = map_size * map_size
    starting_claim_radius = float(profile["starting_claim_radius"])
    safe_radius = float(profile["safe_radius"])
    iron_veins = int(profile["iron_veins"])


func profile_definition(id: String) -> Dictionary:
    if not PROFILES.has(id):
        return {}
    return PROFILES[id].duplicate(true)


func world_pixel_size() -> Vector2i:
    return Vector2i(map_size * tile_size, map_size * tile_size)


func starting_keep_cell() -> Vector2i:
    return Vector2i(map_size / 2 - 1, map_size / 2 - 3)


func is_valid_cell(cell: Vector2i) -> bool:
    return cell.x >= 0 and cell.y >= 0 and cell.x < map_size and cell.y < map_size


func cell_index(cell: Vector2i) -> int:
    if not is_valid_cell(cell):
        return -1
    return cell.y * map_size + cell.x


func cell_from_index(index: int) -> Vector2i:
    if index < 0 or index >= map_cells:
        return Vector2i(-1, -1)
    return Vector2i(index % map_size, floori(float(index) / float(map_size)))
