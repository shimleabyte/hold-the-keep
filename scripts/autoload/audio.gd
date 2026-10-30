extends Node
## SFX prosedural (tanpa file aset): sintesis sederhana saat startup.
## Ganti dengan sample asli nanti cukup dengan mengisi _sounds[name] = AudioStream.

const RATE := 22050
const POOL := 10
const MIN_GAP_MS := 60

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _last := {}
var _silent_until := 0
var _last_hp := 100


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    for i in POOL:
        var p := AudioStreamPlayer.new()
        add_child(p)
        _players.append(p)
    _build_sounds()

    Events.building_placed.connect(func(id: String, _c: Vector2i) -> void: if id != "keep": play("build"))
    Events.building_removed.connect(func(_id: String, _c: Vector2i) -> void: play("build", 0.7))
    Events.building_destroyed.connect(func(_id: String, _c: Vector2i) -> void: play("crash"))
    Events.enemy_killed.connect(func(_id: String) -> void: play("kill", randf_range(0.9, 1.15)))
    Events.phase_changed.connect(func(night: bool) -> void: play("horn" if night else "dawn"))
    Events.game_over.connect(func(_d: int) -> void: play("lose"))
    Events.game_won.connect(func(_d: int) -> void: play("win"))
    Events.event_triggered.connect(func(_t: String, _x: String) -> void: play("event"))
    Events.tech_started.connect(func(_id: String) -> void: play("build", 1.3))
    Events.player_attacked.connect(func() -> void: play("swing", randf_range(0.9, 1.1)))
    Events.player_harvested.connect(func(kind: String) -> void: play("mine" if kind == "stone" else "chop", randf_range(0.9, 1.1)))
    Events.player_hp_changed.connect(_on_player_hp)


func _on_player_hp(hp: int, _max_hp: int) -> void:
    if hp < _last_hp:
        play("hurt")
    _last_hp = hp


## Bungkam sementara (saat scene baru dibuat/dimuat).
func silence(ms: int) -> void:
    _silent_until = Time.get_ticks_msec() + ms


func has_sound(sound_name: String) -> bool:
    return _sounds.has(sound_name)


func play(sound_name: String, pitch := 1.0, volume_db := 0.0) -> void:
    var now := Time.get_ticks_msec()
    if now < _silent_until or not _sounds.has(sound_name):
        return
    if now - int(_last.get(sound_name, -1000)) < MIN_GAP_MS:
        return
    _last[sound_name] = now
    var chosen: AudioStreamPlayer = _players[0]
    for p in _players:
        if not p.playing:
            chosen = p
            break
    chosen.stream = _sounds[sound_name]
    chosen.pitch_scale = pitch
    chosen.volume_db = volume_db
    chosen.play()


# ---------------------------------------------------------------- sintesis

func _build_sounds() -> void:
    _sounds["chop"] = _wav(_tone(0.10, 160, 70, "sine", 0.7, 0.35, 6.0))
    _sounds["mine"] = _wav(_tone(0.08, 700, 350, "square", 0.3, 0.3, 7.0))
    _sounds["swing"] = _wav(_tone(0.12, 400, 200, "sine", 0.25, 0.9, 5.0))
    _sounds["build"] = _wav(_cat([_tone(0.07, 330, 330, "square", 0.22, 0.0, 3.0), _tone(0.10, 440, 440, "square", 0.22, 0.0, 5.0)]))
    _sounds["crash"] = _wav(_tone(0.40, 120, 40, "saw", 0.5, 0.7, 4.0))
    _sounds["kill"] = _wav(_tone(0.16, 260, 70, "square", 0.28, 0.2, 5.0))
    _sounds["hurt"] = _wav(_tone(0.18, 180, 90, "saw", 0.4, 0.3, 5.0))
    _sounds["horn"] = _wav(_tone(1.0, 110, 98, "saw", 0.45, 0.0, 1.3))
    _sounds["dawn"] = _wav(_arp([523.0, 659.0, 784.0], 0.14, "sine", 0.4))
    _sounds["win"] = _wav(_arp([523.0, 659.0, 784.0, 1047.0], 0.16, "square", 0.25))
    _sounds["lose"] = _wav(_arp([392.0, 330.0, 262.0, 196.0], 0.22, "saw", 0.3))
    _sounds["event"] = _wav(_tone(0.25, 880, 880, "sine", 0.4, 0.0, 6.0))


func _tone(dur: float, f0: float, f1: float, wave: String, vol: float, noise: float, decay: float) -> PackedFloat32Array:
    var n := int(dur * RATE)
    var out := PackedFloat32Array()
    out.resize(n)
    var phase := 0.0
    for i in n:
        var t := float(i) / n
        phase += lerpf(f0, f1, t) / RATE
        var ph := fmod(phase, 1.0)
        var s := sin(ph * TAU)
        if wave == "square":
            s = 1.0 if ph < 0.5 else -1.0
        elif wave == "saw":
            s = ph * 2.0 - 1.0
        s = s * (1.0 - noise) + randf_range(-1.0, 1.0) * noise
        out[i] = s * exp(-decay * t) * minf(1.0, float(i) / 200.0) * vol
    return out


func _cat(parts: Array) -> PackedFloat32Array:
    var out := PackedFloat32Array()
    for p in parts:
        out.append_array(p)
    return out


func _arp(freqs: Array, note_len: float, wave: String, vol: float) -> PackedFloat32Array:
    var parts: Array = []
    for f in freqs:
        parts.append(_tone(note_len, f, f, wave, vol, 0.0, 4.0))
    return _cat(parts)


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
    var bytes := PackedByteArray()
    bytes.resize(samples.size() * 2)
    for i in samples.size():
        bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
    var s := AudioStreamWAV.new()
    s.format = AudioStreamWAV.FORMAT_16_BITS
    s.mix_rate = RATE
    s.stereo = false
    s.data = bytes
    return s
