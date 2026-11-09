extends RefCounted
## Pemutar animasi untuk sprite sheet karakter: 22 frame x 3 arah pandang.
##   baris 0 = depan (turun), 1 = belakang (naik), 2 = samping (menghadap kanan; kiri = flip)
## Dipakai pemain, villager, musuh, dan mayat.
## Secondary motion tetap berbasis offset piksel agar sprite tidak kehilangan ketajaman.

const FRAMES := 22
## The protagonist has a separately authored 24px-frame atlas; shared role sheets remain 22 frames.
const PLAYER_FRAMES := 46
const FRONT := 0
const BACK := 1
const SIDE := 2
const WORK_FRAME_THRESHOLDS := {
    "default": [0.25, 0.50, 0.75, 1.0],
    "woodcutter": [0.22, 0.49, 0.75, 1.0],
    "miner": [0.24, 0.44, 0.72, 1.0],
    "builder": [0.28, 0.46, 0.70, 1.0],
    "blacksmith": [0.28, 0.46, 0.76, 1.0],
    "farmer": [0.18, 0.44, 0.78, 1.0],
}
const PLAYER_CLIPS := {
    "idle": {"start": 0, "count": 2, "fps": 2.0, "loop": true},
    "walk": {"start": 2, "count": 4, "fps": 8.0, "loop": true},
    "run": {"start": 6, "count": 4, "fps": 12.0, "loop": true},
    "work": {"start": 16, "count": 4, "fps": 14.0, "loop": true},
    "death": {"start": 20, "count": 4, "fps": 8.0, "loop": false},
    "cleave": {"start": 24, "count": 6, "fps": 1.0, "loop": false},
    "dash": {"start": 30, "count": 6, "fps": 27.2727, "loop": false},
    "rally": {"start": 36, "count": 6, "fps": 12.0, "loop": false},
    "hurt": {"start": 42, "count": 4, "fps": 20.0, "loop": false},
}
const PLAYER_ATTACK_FRAMES := [10, 11, 12, 13, 14, 15]
const PLAYER_CLEAVE_FRAMES := [24, 25, 26, 27, 28, 29]

const CLIPS := {
    "idle": {"start": 0, "count": 2, "fps": 2.0, "loop": true},
    "walk": {"start": 2, "count": 4, "fps": 8.0, "loop": true},
    "run": {"start": 6, "count": 4, "fps": 12.0, "loop": true},
    "attack": {"start": 10, "count": 4, "fps": 14.0, "loop": false},
    "work": {"start": 14, "count": 4, "fps": 7.0, "loop": true},
    "hurt": {"start": 18, "count": 1, "fps": 6.0, "loop": false},
    "death": {"start": 19, "count": 3, "fps": 6.0, "loop": false},
}

var clip := "idle"
## True only while the protagonist is using its separately authored locomotion atlas.
var _uses_player_atlas := false
var view := FRONT
var flip := false
var finished := false
var speed_scale := 1.0
## Determines the distinct timing and body mechanics used by the shared work clip.
var work_style := "default"
## >= 0: frame ditentukan dari progres 0..1 (misalnya disinkronkan dengan timer kerja), tidak maju sendiri.
var manual_progress := -1.0

var _t := 0.0
var _motion_t := 0.0
var _motion_phase := 0.0
var _fps := 2.0
# Data klip aktif disalin sekali saat play() agar update() tidak mencari dictionary tiap tick.
var _start := 0
var _n := 2
var _loop := true
var _total := 1.0
# Track the last visual state observed by update(). Manual work progress is
# assigned by the actor before update(), so comparing only pre/post timer
# values misses frame changes made earlier in the same physics tick.
var _last_rendered_clip := ""
var _last_rendered_frame := -1
var _last_rendered_offset := Vector2(999999.0, 999999.0)
var _last_rendered_view := -1
var _last_rendered_flip := false
## Optional deterministic frame timeline for authored player combat sequences.
var _timed_frames := PackedInt32Array()
var _timed_frame_times := PackedFloat32Array()


func _init() -> void:
    # Unit tidak bergerak serempak; variasi hanya memengaruhi idle breathing.
    _motion_phase = randf_range(0.0, TAU)


func play(clip_name: String, restart := false, fps_override := 0.0) -> void:
    if clip_name == clip and not restart and not _uses_player_atlas:
        return
    _uses_player_atlas = false
    clip = clip_name
    _t = 0.0
    finished = false
    _timed_frames = PackedInt32Array()
    _timed_frame_times = PackedFloat32Array()
    var c: Dictionary = CLIPS[clip_name]
    _start = int(c["start"])
    _n = int(c["count"])
    _loop = bool(c["loop"])
    _fps = fps_override if fps_override > 0.0 else float(c["fps"])
    _total = float(_n) / _fps


## Play the protagonist's own atlas clips without changing shared worker/enemy offsets.
func play_player_clip(clip_name: String, restart := false, fps_override := 0.0) -> void:
    var definition: Dictionary = PLAYER_CLIPS.get(clip_name, {})
    if definition.is_empty():
        push_error("Unknown player animation clip: %s" % clip_name)
        return
    if clip_name == clip and not restart and _uses_player_atlas and _timed_frames.is_empty():
        return

    _uses_player_atlas = true
    clip = clip_name
    _t = 0.0
    finished = false
    manual_progress = -1.0
    _timed_frames = PackedInt32Array()
    _timed_frame_times = PackedFloat32Array()
    _start = int(definition["start"])
    _n = int(definition["count"])
    _loop = bool(definition["loop"])
    _fps = fps_override if fps_override > 0.0 else float(definition["fps"])
    _total = float(_n) / _fps


## Play authored key poses against semantic event times. Times are seconds from clip start.
func play_timed_sequence(
    sequence_clip: String,
    frames: PackedInt32Array,
    frame_times: PackedFloat32Array,
    duration: float
) -> void:
    if frames.is_empty() or frames.size() != frame_times.size() or duration <= 0.0:
        push_error("Invalid timed animation sequence: empty/mismatched frames or duration")
        return
    if not is_zero_approx(frame_times[0]):
        push_error("Timed animation sequences must begin at time zero")
        return

    var previous_time := -1.0
    for index in range(frames.size()):
        var frame_time: float = frame_times[index]
        if frames[index] < 0 or frames[index] >= PLAYER_FRAMES:
            push_error("Timed player animation frame is outside its atlas: %d" % frames[index])
            return
        if frame_time < 0.0 or frame_time >= duration or frame_time <= previous_time:
            push_error("Timed animation markers must be strictly increasing and inside the clip")
            return
        previous_time = frame_time

    _uses_player_atlas = true
    clip = sequence_clip
    _t = 0.0
    finished = false
    manual_progress = -1.0
    _timed_frames = frames.duplicate()
    _timed_frame_times = frame_times.duplicate()
    _start = frames[0]
    _n = frames.size()
    _loop = false
    _fps = 1.0
    _total = duration


## Light and heavy player strikes share event timing but use different authored pose ranges.
func _play_player_strike(sequence_clip: String, frame_indices: Array, hit_delay: float, duration: float) -> void:
    var impact_time := maxf(hit_delay, 0.0)
    var total_duration := maxf(duration, impact_time + 0.06)
    if impact_time < 0.04 or impact_time >= total_duration - 0.04:
        push_error("Player strike timing must leave room for anticipation and recovery")
        return

    var follow_through := total_duration - impact_time
    var frame_times := PackedFloat32Array([
        0.0,
        impact_time * 0.58,
        impact_time,
        impact_time + follow_through * 0.18,
        impact_time + follow_through * 0.48,
        impact_time + follow_through * 0.76,
    ])
    play_timed_sequence(sequence_clip, PackedInt32Array(frame_indices), frame_times, total_duration)


## Light attack impact is keyed to PlayerCombatFlow's existing hit delay.
func play_player_attack(hit_delay: float, duration: float) -> void:
    _play_player_strike("attack", PLAYER_ATTACK_FRAMES, hit_delay, duration)


## Cleave has a dedicated six-pose heavy swing and keeps its existing 0.22s hit event.
func play_player_cleave(hit_delay: float, duration: float) -> void:
    _play_player_strike("cleave", PLAYER_CLEAVE_FRAMES, hit_delay, duration)


func is_busy() -> bool:
    return (
        clip == "attack"
        or clip == "cleave"
        or clip == "work"
        or clip == "dash"
        or clip == "rally"
        or clip == "death"
    ) and not finished


## Maju delta detik. Kembali true jika frame atau offset piksel yang terlihat berubah.
func update(delta: float) -> bool:
    _motion_t += delta
    if manual_progress < 0.0:
        _t += delta * speed_scale
        if _t >= _total:
            if _loop:
                _t = fmod(_t, _total)
            else:
                _t = _total - 0.0001
                finished = true

    # Work-cycle progress is written by Villager before this method runs.
    # Compare against the previous rendered state, not a value sampled after
    # that write, otherwise manually advanced frames never invalidate the draw.
    var current_frame := frame_index()
    var current_offset := motion_offset()
    var changed := (
        clip != _last_rendered_clip
        or current_frame != _last_rendered_frame
        or current_offset != _last_rendered_offset
        or view != _last_rendered_view
        or flip != _last_rendered_flip
    )
    _last_rendered_clip = clip
    _last_rendered_frame = current_frame
    _last_rendered_offset = current_offset
    _last_rendered_view = view
    _last_rendered_flip = flip
    return changed


func frame_index() -> int:
    if manual_progress >= 0.0:
        if clip == "work":
            var thresholds: Array = WORK_FRAME_THRESHOLDS.get(work_style, WORK_FRAME_THRESHOLDS["default"])
            var progress := clampf(manual_progress, 0.0, 0.9999)
            for i in thresholds.size():
                if progress < float(thresholds[i]):
                    return _start + mini(i, _n - 1)
            return _start + _n - 1
        return _start + int(clampf(manual_progress, 0.0, 0.9999) * _n)

    if not _timed_frames.is_empty():
        var selected := 0
        for index in range(1, _timed_frames.size()):
            if _t < _timed_frame_times[index]:
                break
            selected = index
        return _timed_frames[selected]

    return _start + mini(int(_t * _fps), _n - 1)


## Offset sekunder dalam piksel bulat. Pivot kaki tetap menjadi titik acuan.
func motion_offset() -> Vector2:
    var progress := _clip_progress()
    var forward := _facing_vector()
    match clip:
        "idle":
            # Napas halus satu piksel, dengan fase awal berbeda per unit.
            return Vector2(0, -roundf(sin(_motion_t * TAU * 0.7 + _motion_phase) * 0.55))
        "walk", "run":
            if _uses_player_atlas:
                # The protagonist's atlas owns contact, compression and recovery.
                # Keep its ground pivot fixed so the planted boot cannot slide.
                return Vector2.ZERO
            # Shared villager/enemy sheets still use runtime lift; their atlas
            # has not yet received the protagonist's authored contact treatment.
            var lift := absf(sin(progress * TAU))
            return Vector2(0, -roundf(lift * (2.0 if clip == "run" else 1.0)))
        "work":
            return _work_motion_offset(progress, forward)
        "hurt":
            # Recoil tajam pada awal hit lalu pulih sepanjang klip.
            var recoil := 1.0 - smoothstep(0.0, 0.8, progress)
            return -forward * roundf(recoil)
    return Vector2.ZERO


func _clip_progress() -> float:
    if manual_progress >= 0.0:
        return clampf(manual_progress, 0.0, 1.0)
    if _total <= 0.0:
        return 0.0
    return clampf(_t / _total, 0.0, 1.0)


func _facing_vector() -> Vector2:
    match view:
        FRONT:
            return Vector2.DOWN
        BACK:
            return Vector2.UP
        _:
            return Vector2.LEFT if flip else Vector2.RIGHT


## Atur arah pandang dari vektor arah. Kembali true jika berubah.
func face(dir: Vector2) -> bool:
    if dir.length_squared() < 0.0001:
        return false
    var v := view
    var f := flip
    # Sedikit histeresis supaya tidak berkedip saat arah hampir diagonal.
    var side_bias := 0.8 if view == SIDE else 1.25
    if absf(dir.x) * side_bias >= absf(dir.y):
        v = SIDE
        f = dir.x < 0.0
    else:
        v = FRONT if dir.y > 0.0 else BACK
    var changed := v != view or (v == SIDE and f != flip)
    view = v
    flip = f
    return changed


func draw(ci: CanvasItem, tex: Texture2D, fw: int, fh: int) -> void:
    var facing_scale := Vector2(-1.0, 1.0) if flip and view == SIDE else Vector2.ONE
    ci.draw_set_transform(motion_offset(), 0.0, facing_scale)
    ci.draw_texture_rect_region(
        tex,
        Rect2(-fw / 2.0, -fh, fw, fh),
        Rect2(frame_index() * fw, view * fh, fw, fh)
    )
    ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Small, pixel-snapped body accents keep each occupation's tool cycle readable.
## The sprite sheet supplies the tool pose; this profile supplies distinct weight transfer.
func _work_motion_offset(progress: float, forward: Vector2) -> Vector2:
    var local_motion := Vector2.ZERO
    match work_style:
        "woodcutter":
            if progress < 0.22:
                local_motion = Vector2(-1, -1)
            elif progress < 0.49:
                local_motion = Vector2(2, -1)
            elif progress < 0.75:
                local_motion = Vector2(1, 0)
        "miner":
            if progress < 0.34:
                local_motion = Vector2(0, -1)
            elif progress < 0.52:
                local_motion = Vector2(0, 2)
            elif progress < 0.76:
                local_motion = Vector2(-1, 1)
        "builder":
            if progress < 0.28:
                local_motion = Vector2(0, -1)
            elif progress < 0.46:
                local_motion = Vector2(1, 2)
            elif progress < 0.70:
                local_motion = Vector2(1, 1)
        "blacksmith":
            if progress < 0.42:
                local_motion = Vector2(-1, 0)
            elif progress < 0.58:
                local_motion = Vector2(0, 1)
            elif progress < 0.82:
                local_motion = Vector2(0, -1)
        "farmer":
            if progress < 0.18:
                local_motion = Vector2(0, -1)
            elif progress < 0.44:
                local_motion = Vector2(-2, 2)
            elif progress < 0.78:
                local_motion = Vector2(-1, 1)
        _:
            var strike := 1.0 - absf(progress - 0.5) * 2.0
            local_motion = Vector2(roundf(clampf(strike, 0.0, 1.0)), 0.0)
    return forward * local_motion.x + Vector2(0.0, local_motion.y)
