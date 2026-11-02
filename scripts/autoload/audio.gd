extends Node
## SFX prosedural (tanpa file aset): sintesis sederhana saat startup.
## Ganti dengan sample asli nanti cukup dengan mengisi _sounds[name] = AudioStream.

const RATE := 22050
const POOL := 10
const MIN_GAP_MS := 60
const AMBIENT_RATE := 11025
const AMBIENT_SECONDS := 8.0
const MUSIC_RATE := 11025
const MUSIC_SECONDS := 16.0
const AMBIENT_REGIONS := ["HEARTHLAND", "GREENWOOD", "HIGHLANDS", "FENLANDS", "ASHEN_MARCH"]
const AMBIENCE_VOLUME_DB := -27.0
const CAMPAIGN_MUSIC_VOLUME_DB := -34.0
const MENU_MUSIC_VOLUME_DB := -38.0
const AMBIENCE_CROSSFADE := 1.25
const MUSIC_CROSSFADE := 1.8

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _last := {}
var _silent_until := 0
var _last_hp := 100
var _ambient_streams: Dictionary = {}
var _music_streams: Dictionary = {}
var _ambient_players: Array[AudioStreamPlayer] = []
var _music_players: Array[AudioStreamPlayer] = []
var _ambient_player_index := -1
var _music_player_index := -1
var _ambient_key := ""
var _music_key := ""
var _context_scan_timer := 0.0
var _ambient_tween: Tween
var _music_tween: Tween


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    for i in POOL:
        var p := AudioStreamPlayer.new()
        p.process_mode = Node.PROCESS_MODE_ALWAYS
        add_child(p)
        _players.append(p)
    for i in 2:
        var ambience_player := AudioStreamPlayer.new()
        ambience_player.process_mode = Node.PROCESS_MODE_ALWAYS
        ambience_player.volume_db = -80.0
        add_child(ambience_player)
        _ambient_players.append(ambience_player)
        var music_player := AudioStreamPlayer.new()
        music_player.process_mode = Node.PROCESS_MODE_ALWAYS
        music_player.volume_db = -80.0
        add_child(music_player)
        _music_players.append(music_player)

    _build_sounds()
    _build_ambient_streams()
    _build_music_streams()

    Events.building_placed.connect(func(id: String, _c: Vector2i) -> void: if id != "keep": play("build"))
    Events.building_removed.connect(func(_id: String, _c: Vector2i) -> void: play("build", 0.7))
    Events.building_destroyed.connect(func(_id: String, _c: Vector2i) -> void: play("crash"))
    Events.enemy_killed.connect(func(_id: String) -> void: play("kill", 1.0, -2.0))
    Events.phase_changed.connect(func(night: bool) -> void: play("horn" if night else "dawn"))
    Events.wave_started.connect(func(_day: int, _count: int) -> void: play("camp_alarm", 1.0, -7.0))
    Events.campaign_objective_completed.connect(func(_id: String, _region: String) -> void: play("objective", 1.0, -3.0))
    Events.frontier_objective_changed.connect(func(_id: String, completed: bool) -> void: if completed: play("objective", 0.96, -5.0))
    Events.frontier_act_unlocked.connect(func(_act: int) -> void: play("objective", 1.12, -1.0))
    Events.frontier_final_boss_defeated.connect(func(_day: int) -> void: play("win"))
    Events.game_over.connect(func(_d: int) -> void: play("lose"))
    Events.game_won.connect(func(_d: int) -> void: play("win"))
    Events.event_triggered.connect(func(_t: String, _x: String) -> void: play("event"))
    Events.tech_started.connect(func(_id: String) -> void: play("build", 1.3))
    Events.player_attacked.connect(func() -> void: play("swing", randf_range(0.9, 1.1)))
    Events.player_harvested.connect(func(kind: String) -> void: play("mine" if kind == "stone" else "chop", randf_range(0.9, 1.1)))
    Events.player_hp_changed.connect(_on_player_hp)


func _process(delta: float) -> void:
    _context_scan_timer = maxf(0.0, _context_scan_timer - delta)
    if _context_scan_timer <= 0.0:
        _context_scan_timer = 0.65
        _sync_world_ambience()
    _sync_music_context()


func _sync_world_ambience() -> void:
    var main = get_tree().get_first_node_in_group("main")
    if main == null or not is_instance_valid(main.player) or not is_instance_valid(main.world):
        return
    var cell := Vector2i(
        floori(main.player.global_position.x / float(WorldConfig.tile_size)),
        floori(main.player.global_position.y / float(WorldConfig.tile_size))
    )
    var region := String(main.world.region_id(cell))
    set_ambience_context(region, bool(GameClock.is_night))


func ambient_key_for(region: String, night: bool) -> String:
    var normalized := region.strip_edges().to_upper()
    if not AMBIENT_REGIONS.has(normalized):
        normalized = "HEARTHLAND"
    return normalized + ("_NIGHT" if night else "_DAY")


func set_ambience_context(region: String, night: bool) -> void:
    var key := ambient_key_for(region, night)
    if key == _ambient_key and _ambient_player_index >= 0:
        var current: AudioStreamPlayer = _ambient_players[_ambient_player_index]
        if current.playing:
            return
    if not _ambient_streams.has(key):
        return
    if _ambient_tween != null and _ambient_tween.is_valid():
        _ambient_tween.kill()

    var next_index := 0 if _ambient_player_index != 0 else 1
    var incoming: AudioStreamPlayer = _ambient_players[next_index]
    var outgoing: AudioStreamPlayer = _ambient_players[_ambient_player_index] if _ambient_player_index >= 0 else null
    incoming.stop()
    incoming.stream = _ambient_streams[key]
    incoming.volume_db = -80.0
    incoming.play()
    _ambient_key = key
    _ambient_player_index = next_index

    _ambient_tween = create_tween()
    _ambient_tween.set_parallel(true)
    _ambient_tween.tween_property(incoming, "volume_db", AMBIENCE_VOLUME_DB, AMBIENCE_CROSSFADE)
    if outgoing != null and is_instance_valid(outgoing):
        _ambient_tween.tween_property(outgoing, "volume_db", -80.0, AMBIENCE_CROSSFADE)
        _ambient_tween.finished.connect(func() -> void:
            if is_instance_valid(outgoing):
                outgoing.stop()
        )


func _sync_music_context() -> void:
    var main = get_tree().get_first_node_in_group("main")
    if main == null:
        return
    set_music_context("menu" if get_tree().paused else "campaign")


func set_music_context(context: String) -> void:
    var key := "menu" if context == "menu" else "campaign"
    if key == _music_key and _music_player_index >= 0:
        var current: AudioStreamPlayer = _music_players[_music_player_index]
        if current.playing:
            return
    if not _music_streams.has(key):
        return
    if _music_tween != null and _music_tween.is_valid():
        _music_tween.kill()

    var next_index := 0 if _music_player_index != 0 else 1
    var incoming: AudioStreamPlayer = _music_players[next_index]
    var outgoing: AudioStreamPlayer = _music_players[_music_player_index] if _music_player_index >= 0 else null
    incoming.stop()
    incoming.stream = _music_streams[key]
    incoming.volume_db = -80.0
    incoming.play()
    _music_key = key
    _music_player_index = next_index

    _music_tween = create_tween()
    _music_tween.set_parallel(true)
    _music_tween.tween_property(incoming, "volume_db", MENU_MUSIC_VOLUME_DB if key == "menu" else CAMPAIGN_MUSIC_VOLUME_DB, MUSIC_CROSSFADE)
    if outgoing != null and is_instance_valid(outgoing):
        _music_tween.tween_property(outgoing, "volume_db", -80.0, MUSIC_CROSSFADE)
        _music_tween.finished.connect(func() -> void:
            if is_instance_valid(outgoing):
                outgoing.stop()
        )


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
    _sounds["windup"] = _wav(_arp_deterministic([196.0, 247.0], 0.065, "sine", 0.18))
    _sounds["projectile"] = _wav(_tone_deterministic(0.19, 920.0, 470.0, "sine", 0.2, 0.0, 4.5))
    _sounds["block"] = _wav(_tone_deterministic(0.17, 780.0, 170.0, "square", 0.22, 0.0, 7.0))
    _sounds["impact_hit"] = _wav(_tone_deterministic(0.105, 620.0, 230.0, "square", 0.13, 0.0, 8.0))
    _sounds["shield_raise"] = _wav(_tone_deterministic(0.22, 260.0, 640.0, "sine", 0.17, 0.0, 3.5))
    _sounds["stagger"] = _wav(_arp_deterministic([392.0, 293.66], 0.075, "saw", 0.14))
    _sounds["dash"] = _wav(_tone_deterministic(0.16, 240.0, 740.0, "sine", 0.18, 0.0, 5.0))
    _sounds["cleave"] = _wav(_tone_deterministic(0.23, 540.0, 125.0, "saw", 0.16, 0.0, 5.0))
    _sounds["rally"] = _wav(_arp_deterministic([392.0, 523.25, 659.25], 0.11, "sine", 0.16))
    _sounds["charge"] = _wav(_tone_deterministic(0.28, 155.0, 68.0, "saw", 0.2, 0.0, 3.5))
    _sounds["siege_windup"] = _wav(_tone_deterministic(0.42, 72.0, 50.0, "sine", 0.24, 0.0, 2.0))
    _sounds["siege_impact"] = _wav(_tone_deterministic(0.55, 110.0, 32.0, "saw", 0.34, 0.0, 3.2))
    _sounds["camp_alarm"] = _wav(_arp_deterministic([220.0, 311.13, 220.0], 0.15, "saw", 0.17))
    _sounds["objective"] = _wav(_arp_deterministic([523.25, 659.25, 783.99, 1046.5], 0.13, "sine", 0.2))


func _build_ambient_streams() -> void:
    _ambient_streams.clear()
    for region in AMBIENT_REGIONS:
        for night in [false, true]:
            var key := ambient_key_for(region, night)
            _ambient_streams[key] = _loop_stream(_ambient_samples(region, night), AMBIENT_RATE)


func _ambient_samples(region: String, night: bool) -> PackedFloat32Array:
    var sample_count := roundi(AMBIENT_RATE * AMBIENT_SECONDS)
    var samples := PackedFloat32Array()
    samples.resize(sample_count)
    for i in sample_count:
        var t := float(i) / float(AMBIENT_RATE)
        var slow_wind := sin(TAU * 0.125 * t) * 0.045 + sin(TAU * 0.375 * t + 0.7) * 0.018
        var breath := 0.55 + 0.45 * sin(TAU * 0.25 * t - 0.4)
        var value := slow_wind * breath
        match region:
            "HEARTHLAND":
                value += sin(TAU * 196.0 * t) * 0.012
                value += sin(TAU * 880.0 * t) * pow(maxf(0.0, sin(TAU * 0.25 * t)), 18.0) * 0.018
                value += sin(TAU * 1320.0 * t) * pow(maxf(0.0, sin(TAU * 0.125 * t + 0.8)), 14.0) * 0.012
            "GREENWOOD":
                value += sin(TAU * 1480.0 * t) * pow(maxf(0.0, sin(TAU * 0.25 * t + 0.5)), 20.0) * 0.028
                value += sin(TAU * 1870.0 * t) * pow(maxf(0.0, sin(TAU * 0.375 * t + 1.4)), 24.0) * 0.018
                value += sin(TAU * 3100.0 * t) * (0.35 + breath * 0.65) * 0.006
            "HIGHLANDS":
                value += sin(TAU * 164.75 * t) * 0.018
                value += sin(TAU * 247.0 * t) * 0.014
                value += sin(TAU * 493.875 * t) * (0.35 + breath * 0.65) * 0.009
            "FENLANDS":
                var bubble := pow(maxf(0.0, sin(TAU * 0.5 * t + 0.3)), 16.0)
                value += sin(TAU * 92.5 * t) * 0.025
                value += sin(TAU * 138.625 * t) * bubble * 0.035
                value += sin(TAU * 520.0 * t) * pow(maxf(0.0, sin(TAU * 0.375 * t)), 12.0) * 0.018
            "ASHEN_MARCH":
                value += sin(TAU * 55.0 * t) * 0.032
                value += sin(TAU * 82.375 * t) * 0.02
                value += sin(TAU * 270.0 * t) * (0.3 + breath * 0.7) * 0.012
                value += sin(TAU * 1700.0 * t) * pow(maxf(0.0, sin(TAU * 0.125 * t + 1.0)), 8.0) * 0.008

        if night:
            var insect_pulse := pow(maxf(0.0, sin(TAU * 1.5 * t + 0.2)), 7.0)
            value += sin(TAU * 2480.0 * t) * insect_pulse * 0.018
            value += sin(TAU * 3280.0 * t) * pow(maxf(0.0, sin(TAU * 0.75 * t + 1.0)), 9.0) * 0.009
            value -= sin(TAU * 110.0 * t) * 0.008
        else:
            value += sin(TAU * 720.0 * t) * pow(maxf(0.0, sin(TAU * 0.25 * t + 1.1)), 16.0) * 0.008

        samples[i] = clampf(value, -0.24, 0.24)
    return samples


func _build_music_streams() -> void:
    _music_streams.clear()
    _music_streams["campaign"] = _loop_stream(_music_samples(false), MUSIC_RATE)
    _music_streams["menu"] = _loop_stream(_music_samples(true), MUSIC_RATE)


func _music_samples(menu_theme: bool) -> PackedFloat32Array:
    var campaign_notes := [146.83, 220.0, 196.0, 164.81, 146.83, 174.61, 196.0, 110.0]
    var menu_notes := [293.66, 349.23, 392.0, 440.0, 392.0, 349.23, 293.66, 220.0]
    var notes: Array = menu_notes if menu_theme else campaign_notes
    var sample_count := roundi(MUSIC_RATE * MUSIC_SECONDS)
    var samples := PackedFloat32Array()
    samples.resize(sample_count)
    var note_duration := MUSIC_SECONDS / float(notes.size())
    for i in sample_count:
        var t := float(i) / float(MUSIC_RATE)
        var note_index := mini(notes.size() - 1, floori(t / note_duration))
        var note_time := fposmod(t, note_duration)
        var attack := clampf(note_time / 0.24, 0.0, 1.0)
        var release := clampf((note_duration - note_time) / 0.38, 0.0, 1.0)
        var envelope := minf(attack, release)
        var frequency := float(notes[note_index])
        var tone := sin(TAU * frequency * t) * 0.62
        tone += sin(TAU * frequency * 1.5 * t) * 0.18
        tone += sin(TAU * frequency * 0.5 * t) * 0.2
        var loop_fade := minf(1.0, minf(t / 0.6, (MUSIC_SECONDS - t) / 0.6))
        var drone := sin(TAU * 73.42 * t) * 0.018 * loop_fade
        var volume := 0.062 if menu_theme else 0.082
        samples[i] = clampf(tone * envelope * volume * loop_fade + drone, -0.2, 0.2)
    return samples


func _loop_stream(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
    var stream := _wav(samples)
    stream.mix_rate = rate
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_begin = 0
    stream.loop_end = samples.size()
    return stream


func _tone_deterministic(dur: float, f0: float, f1: float, wave: String, vol: float, noise: float, decay: float) -> PackedFloat32Array:
    var n := int(dur * RATE)
    var out := PackedFloat32Array()
    out.resize(n)
    var phase := 0.0
    var local_rng := RandomNumberGenerator.new()
    local_rng.seed = roundi(f0 * 31.0 + f1 * 17.0 + dur * 10000.0)
    for i in n:
        var t := float(i) / float(n)
        phase += lerpf(f0, f1, t) / float(RATE)
        var ph := fposmod(phase, 1.0)
        var sample := sin(ph * TAU)
        if wave == "square":
            sample = 1.0 if ph < 0.5 else -1.0
        elif wave == "saw":
            sample = ph * 2.0 - 1.0
        if noise > 0.0:
            sample = sample * (1.0 - noise) + local_rng.randf_range(-1.0, 1.0) * noise
        out[i] = sample * exp(-decay * t) * minf(1.0, float(i) / 200.0) * vol
    return out


func _arp_deterministic(freqs: Array, note_len: float, wave: String, vol: float) -> PackedFloat32Array:
    var parts: Array = []
    for frequency in freqs:
        parts.append(_tone_deterministic(note_len, float(frequency), float(frequency), wave, vol, 0.0, 4.0))
    return _cat(parts)


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
