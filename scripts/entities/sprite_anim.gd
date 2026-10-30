extends RefCounted
## Pemutar animasi untuk sprite sheet karakter: 22 frame x 3 arah pandang.
##   baris 0 = depan (turun), 1 = belakang (naik), 2 = samping (menghadap kanan; kiri = flip)
## Dipakai pemain, villager, musuh, dan mayat.

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
var _fps := 2.0
# Data klip aktif disalin sekali saat play() agar update() tidak mencari dictionary tiap tick.
var _start := 0
var _n := 2
var _loop := true
var _total := 1.0


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


## Maju `delta` detik. Kembali true jika frame yang terlihat berubah (perlu queue_redraw).
func update(delta: float) -> bool:
    var before := frame_index()
    if manual_progress < 0.0:
        _t += delta * speed_scale
        if _t >= _total:
            if _loop:
                _t = fmod(_t, _total)
            else:
                _t = _total - 0.0001
                finished = true
    return frame_index() != before


func frame_index() -> int:
    if manual_progress >= 0.0:
        return _start + int(clampf(manual_progress, 0.0, 0.9999) * _n)
    return _start + mini(int(_t * _fps), _n - 1)


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
    if flipped:
        ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
    ci.draw_texture_rect_region(tex, Rect2(-fw / 2.0, -fh, fw, fh), Rect2(frame_index() * fw, view * fh, fw, fh))
    if flipped:
        ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
