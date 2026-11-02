extends SceneTree
## Phase 08.7 regression: original ambience/music loops and event cue inventory.

const EXPECTED_REGIONS := [
    "HEARTHLAND", "GREENWOOD", "HIGHLANDS", "FENLANDS", "ASHEN_MARCH"
]
const EXPECTED_CUES := [
    "windup", "projectile", "block", "impact_hit", "shield_raise",
    "stagger", "dash", "cleave", "rally", "charge",
    "siege_windup", "siege_impact", "camp_alarm", "objective"
]


func require(condition: bool, message: String) -> void:
    if not condition:
        push_error("FAIL: " + message)
        quit(1)
    assert(condition, message)


func validate_loop(stream: Variant, expected_rate: int, expected_seconds: float, label: String) -> void:
    require(stream is AudioStreamWAV, label + " must be a generated WAV stream")
    var wav := stream as AudioStreamWAV
    require(wav.mix_rate == expected_rate, label + " must use its documented sample rate")
    require(wav.format == AudioStreamWAV.FORMAT_16_BITS and not wav.stereo,
        label + " must remain mono 16-bit procedural audio")
    require(wav.loop_mode == AudioStreamWAV.LOOP_FORWARD,
        label + " must loop forward")
    require(wav.loop_begin == 0 and wav.loop_end == roundi(expected_rate * expected_seconds),
        label + " must loop across its complete sample buffer")
    require(wav.data.size() == wav.loop_end * 2,
        label + " must contain exactly one 16-bit mono loop buffer")
    require(not wav.data.is_empty(), label + " must not contain an empty sample buffer")


func _initialize() -> void:
    await process_frame
    var audio = root.get_node("Audio")
    var settings = root.get_node("Settings")

    require(audio._ambient_streams.size() == EXPECTED_REGIONS.size() * 2,
        "All five biomes must have separate day and night ambience loops")
    for region in EXPECTED_REGIONS:
        for night in [false, true]:
            var key: String = audio.ambient_key_for(region, night)
            require(audio._ambient_streams.has(key), "Missing regional ambience loop: " + key)
            validate_loop(audio._ambient_streams[key], audio.AMBIENT_RATE,
                audio.AMBIENT_SECONDS, key)
            var first: PackedFloat32Array = audio._ambient_samples(region, night)
            var second: PackedFloat32Array = audio._ambient_samples(region, night)
            require(first == second, "Regional ambience samples must be deterministic: " + key)

    require(audio.ambient_key_for("greenwood", false) == "GREENWOOD_DAY",
        "Ambient region routing must normalize biome IDs")
    require(audio.ambient_key_for("ASHEN_MARCH", true) == "ASHEN_MARCH_NIGHT",
        "Ambient routing must distinguish the night variant")
    require(audio.ambient_key_for("UNKNOWN_REGION", true) == "HEARTHLAND_NIGHT",
        "Unknown region IDs must fall back safely to Hearthland")

    require(audio._music_streams.size() == 2,
        "Menu and campaign must have separate original music themes")
    for key in ["menu", "campaign"]:
        require(audio._music_streams.has(key), "Missing music theme: " + key)
        validate_loop(audio._music_streams[key], audio.MUSIC_RATE,
            audio.MUSIC_SECONDS, key + " music")
        var first_music: PackedFloat32Array = audio._music_samples(key == "menu")
        var second_music: PackedFloat32Array = audio._music_samples(key == "menu")
        require(first_music == second_music, "Music samples must be deterministic: " + key)

    for cue in EXPECTED_CUES:
        require(audio._sounds.has(cue), "Missing combat/campaign sound cue: " + cue)
        var cue_stream = audio._sounds[cue] as AudioStreamWAV
        require(cue_stream != null and not cue_stream.data.is_empty(),
            "Every event cue must contain generated audio: " + cue)

    require(audio._ambient_players.size() == 2 and audio._music_players.size() == 2,
        "Ambience and music must each have a two-player crossfade pool")
    for player in audio._ambient_players:
        require(player.process_mode == Node.PROCESS_MODE_ALWAYS,
            "Regional ambience must continue through game pause and settings")
        require(player.bus == "Master", "Regional ambience must follow the existing master volume")
    for player in audio._music_players:
        require(player.process_mode == Node.PROCESS_MODE_ALWAYS,
            "Music crossfades must continue while the gameplay tree is paused")
        require(player.bus == "Master", "Music must follow the existing master volume")
    for player in audio._players:
        require(player.bus == "Master", "New combat cues must retain the master volume route")

    require(settings.volume >= 0.0 and settings.volume <= 1.0,
        "The existing persisted master volume must remain normalized")
    var master_index := AudioServer.get_bus_index("Master")
    require(master_index >= 0, "The project must retain its master output bus")
    var expected_master_db := linear_to_db(maxf(settings.volume, 0.0001))
    require(is_equal_approx(AudioServer.get_bus_volume_db(master_index), expected_master_db),
        "The persisted volume setting must continue to control the shared Master bus")

    audio.set_ambience_context("GREENWOOD", false)
    require(audio._ambient_key == "GREENWOOD_DAY" and audio._ambient_player_index >= 0,
        "Changing biome context must select the correct day loop")
    var ambient_player: AudioStreamPlayer = audio._ambient_players[audio._ambient_player_index]
    require(ambient_player.stream != null,
        "The selected regional loop must be assigned to an active player")

    audio.set_ambience_context("GREENWOOD", true)
    require(audio._ambient_key == "GREENWOOD_NIGHT",
        "Day-to-night changes must select the corresponding ambience loop")
    audio.set_music_context("menu")
    require(audio._music_key == "menu" and audio._music_player_index >= 0,
        "Pause/menu context must select the original menu music")
    audio.set_music_context("campaign")
    require(audio._music_key == "campaign",
        "Resuming campaign context must select the campaign theme")

    print("PASS: 10 biome/day-night ambience loops, two original music loops, deterministic samples, event cue coverage, master-volume routing and crossfade context")
    quit(0)
