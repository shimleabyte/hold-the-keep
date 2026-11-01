extends RefCounted
## Pemutar animasi untuk sprite sheet karakter: 22 frame x 3 arah pandang.
##   baris 0 = depan (turun), 1 = belakang (naik), 2 = samping (menghadap kanan; kiri = flip)
## Dipakai pemain, villager, musuh, dan mayat.
## Secondary motion tetap berbasis offset piksel agar sprite tidak kehilangan ketajaman.

const FRAMES := 22
const FRONT := 0
const BACK := 1
const SIDE := 2
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
var view := FRONT
var flip := false
var finished := false
var speed_scale := 1.0
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


func _init() -> void:
    # Unit tidak bergerak serempak; variasi hanya memengaruhi idle breathing.
    _motion_phase = randf_range(0.0, TAU)


func play(clip_name: String, restart := false, fps_override := 0.0) -> void:
    if clip_name == clip and not restart:
        return
    clip = clip_name
    _t = 0.0
    finished = false
    var c: Dictionary = CLIPS[clip_name]
    _start = int(c["start"])
    _n = int(c["count"])
    _loop = bool(c["loop"])
    _fps = fps_override if fps_override > 0.0 else float(c["fps"])
    _total = float(_n) / _fps


func is_busy() -> bool:
    return (clip == "attack" or clip == "work") and not finished


## Maju delta detik. Kembali true jika frame atau offset piksel yang terlihat berubah.
func update(delta: float) -> bool:
    var before_frame := frame_index()
    var before_offset := motion_offset()
    _motion_t += delta
    if manual_progress < 0.0:
        _t += delta * speed_scale
        if _t >= _total:
            if _loop:
                _t = fmod(_t, _total)
            else:
                _t = _total - 0.0001
                finished = true
    return frame_index() != before_frame or motion_offset() != before_offset


func frame_index() -> int:
    if manual_progress >= 0.0:
        return _start + int(clampf(manual_progress, 0.0, 0.9999) * _n)
    return _start + mini(int(_t * _fps), _n - 1)


## Offset sekunder dalam piksel bulat. Pivot kaki tetap menjadi titik acuan.
func motion_offset() -> Vector2:
    var progress := _clip_progress()
    var forward := _facing_vector()
    match clip:
        "idle":
            # Napas halus satu piksel, dengan fase awal berbeda per unit.
            return Vector2(0, -roundf(sin(_motion_t * TAU * 0.7 + _motion_phase) * 0.55))
        "walk":
            var walk_lift := absf(sin(progress * TAU))
            return Vector2(0, -roundf(walk_lift))
        "run":
            var run_lift := absf(sin(progress * TAU))
            return Vector2(0, -roundf(run_lift * 2.0))
        "work":
            # Bobot badan bergerak maju tepat di sekitar titik pukulan.
            var strike := 1.0 - absf(progress - 0.5) * 2.0
            return forward * roundf(clampf(strike, 0.0, 1.0))
        "attack":
            # Tarik badan sebentar, dorong saat ayunan, lalu kembali ke stance.
            var push := 0.0
            if progress < 0.24:
                push = -smoothstep(0.0, 0.24, progress)
            elif progress < 0.68:
                push = lerpf(-1.0, 1.5, smoothstep(0.24, 0.68, progress))
            else:
                push = lerpf(1.5, 0.0, smoothstep(0.68, 1.0, progress))
            return forward * roundf(push)
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
    var flipped := flip and view == SIDE
    # Translation is kept separate from mirroring so recoil/lunge always follows facing.
    ci.draw_set_transform(motion_offset(), 0.0, Vector2(-1, 1) if flipped else Vector2.ONE)
    ci.draw_texture_rect_region(tex, Rect2(-fw / 2.0, -fh, fw, fh), Rect2(frame_index() * fw, view * fh, fw, fh))
    ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
