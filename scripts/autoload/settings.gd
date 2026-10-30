extends Node
## Pengaturan pemain di user://settings.cfg (layar penuh, vsync, volume).

const PATH := "user://settings.cfg"

var fullscreen := false
var vsync := true
var volume := 0.8  # 0..1
var screen_shake := true


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    load_settings()
    apply()
    _log_session_header()


func load_settings() -> void:
    var cf := ConfigFile.new()
    if cf.load(PATH) != OK:
        return
    fullscreen = bool(cf.get_value("display", "fullscreen", fullscreen))
    vsync = bool(cf.get_value("display", "vsync", vsync))
    volume = clampf(float(cf.get_value("audio", "volume", volume)), 0.0, 1.0)
    screen_shake = bool(cf.get_value("display", "screen_shake", screen_shake))


func save_settings() -> void:
    var cf := ConfigFile.new()
    cf.set_value("display", "fullscreen", fullscreen)
    cf.set_value("display", "vsync", vsync)
    cf.set_value("audio", "volume", volume)
    cf.set_value("display", "screen_shake", screen_shake)
    cf.save(PATH)


func apply() -> void:
    DisplayServer.window_set_mode(
        DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
    )
    DisplayServer.window_set_vsync_mode(
        DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
    )
    AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))


func set_fullscreen(v: bool) -> void:
    fullscreen = v
    apply()
    save_settings()


func set_vsync(v: bool) -> void:
    vsync = v
    apply()
    save_settings()


func set_screen_shake(v: bool) -> void:
    screen_shake = v
    save_settings()


func set_volume(v: float) -> void:
    volume = clampf(v, 0.0, 1.0)
    apply()
    save_settings()


## Log sesi ke user://logs/godot.log (file logging aktif di project.godot).
func _log_session_header() -> void:
    print("== Hold the Keep | Godot %s | %s | %s ==" % [
        Engine.get_version_info()["string"], OS.get_name(), OS.get_model_name()])
