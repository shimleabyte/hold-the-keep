extends Node2D
## Efek partikel ringan: satu node menyimpan dan menggambar semua partikel (tanpa node per partikel).
## Partikel punya tinggi semu agar serpihan terlempar ke atas lalu jatuh di tampilan top-down.

const MAX_PARTICLES := 500
const KINDS := {
    "spark": {"n": 5, "speed": [25.0, 75.0], "up": [20.0, 55.0], "g": 240.0, "life": [0.16, 0.34], "size": [1, 1],
        "colors": ["#fff3b0", "#ffd23f", "#ffffff"]},
    "impact": {"n": 8, "speed": [42.0, 105.0], "up": [28.0, 62.0], "g": 360.0, "life": [0.13, 0.27], "size": [1, 2],
        "colors": ["#fffbe0", "#ffe08a", "#f3a64d", "#ffffff"]},
    "hurt": {"n": 5, "speed": [20.0, 60.0], "up": [20.0, 50.0], "g": 240.0, "life": [0.2, 0.4], "size": [1, 2],
        "colors": ["#ff8a7a", "#d63a3a", "#ffd9d0"]},
    "wood": {"n": 5, "speed": [15.0, 50.0], "up": [30.0, 75.0], "g": 280.0, "life": [0.35, 0.6], "size": [1, 2],
        "colors": ["#a77a45", "#8a6338", "#c9a06a", "#4a9a57"]},
    "stone": {"n": 5, "speed": [20.0, 60.0], "up": [25.0, 65.0], "g": 280.0, "life": [0.3, 0.5], "size": [1, 2],
        "colors": ["#aeb3b9", "#8d9298", "#cfd6e2", "#ffd23f"]},
    "dust": {"n": 3, "speed": [5.0, 18.0], "up": [4.0, 14.0], "g": 14.0, "life": [0.3, 0.55], "size": [1, 2],
        "colors": ["#d9c9a3", "#c4b48a", "#e8dcb8"], "alpha": 0.7},
    "puff": {"n": 6, "speed": [8.0, 28.0], "up": [6.0, 20.0], "g": 10.0, "life": [0.45, 0.85], "size": [3, 5],
        "colors": ["#d9d2c3", "#c4bba8", "#e8e2d0", "#b3ab9a"], "alpha": 0.8},
    "debris": {"n": 6, "speed": [20.0, 65.0], "up": [25.0, 70.0], "g": 280.0, "life": [0.4, 0.7], "size": [1, 2],
        "colors": ["#8b6b43", "#6b4a2b", "#8a8f98", "#6e737b", "#b08a5a"]},
    "rally": {"n": 9, "speed": [5.0, 22.0], "up": [8.0, 25.0], "g": 20.0, "life": [0.45, 0.8], "size": [1, 2],
        "colors": ["#ffd23f", "#f08e3c", "#fff2b2"], "alpha": 0.9},
}

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _z := PackedFloat32Array()
var _vz := PackedFloat32Array()
var _life := PackedFloat32Array()
var _max := PackedFloat32Array()
var _size := PackedFloat32Array()
var _g := PackedFloat32Array()
var _col := PackedColorArray()


func _ready() -> void:
    z_index = 5
    Events.fx_burst.connect(_on_burst)


func count() -> int:
    return _pos.size()


func _on_burst(kind: String, at: Vector2, dir: Vector2, amount: float) -> void:
    spawn(kind, at, dir, amount)


## dir: arah dorongan; nol = menyebar ke segala arah.
func spawn(kind: String, at: Vector2, dir := Vector2.ZERO, amount := 1.0) -> void:
    if not KINDS.has(kind):
        return
    var k: Dictionary = KINDS[kind]
    var n := maxi(1, int(round(float(k["n"]) * amount)))
    for i in n:
        if _pos.size() >= MAX_PARTICLES:
            _remove(0)
        var ang := randf() * TAU
        var spd := randf_range(k["speed"][0], k["speed"][1])
        var v := Vector2(cos(ang), sin(ang) * 0.6) * spd
        if dir != Vector2.ZERO:
            v += dir.normalized() * spd * 0.9
        var life := randf_range(k["life"][0], k["life"][1])
        var c := Color(k["colors"][randi() % k["colors"].size()])
        c.a = float(k.get("alpha", 1.0))
        _pos.append(at + Vector2(randf_range(-2.0, 2.0), randf_range(-1.0, 1.0)))
        _vel.append(v)
        _z.append(0.0)
        _vz.append(randf_range(k["up"][0], k["up"][1]))
        _life.append(life)
        _max.append(life)
        _size.append(float(randi_range(k["size"][0], k["size"][1])))
        _g.append(float(k["g"]))
        _col.append(c)
    queue_redraw()


func _remove(i: int) -> void:
    var last := _pos.size() - 1
    _pos[i] = _pos[last]; _vel[i] = _vel[last]; _z[i] = _z[last]; _vz[i] = _vz[last]
    _life[i] = _life[last]; _max[i] = _max[last]; _size[i] = _size[last]; _g[i] = _g[last]; _col[i] = _col[last]
    _pos.resize(last); _vel.resize(last); _z.resize(last); _vz.resize(last)
    _life.resize(last); _max.resize(last); _size.resize(last); _g.resize(last); _col.resize(last)


func _process(delta: float) -> void:
    if _pos.is_empty():
        return
    var i := _pos.size() - 1
    while i >= 0:
        _life[i] -= delta
        if _life[i] <= 0.0:
            _remove(i)
        else:
            _vz[i] -= _g[i] * delta
            _z[i] += _vz[i] * delta
            if _z[i] < 0.0:
                _z[i] = 0.0
                _vz[i] = 0.0
                _vel[i] *= 0.85
            _pos[i] += _vel[i] * delta
        i -= 1
    queue_redraw()


func _draw() -> void:
    for i in _pos.size():
        var c := _col[i]
        var life_ratio := clampf(_life[i] / _max[i], 0.0, 1.0)
        c.a *= smoothstep(0.0, 0.3, life_ratio)
        var particle_pos := _pos[i] - Vector2(0.0, _z[i])
        var speed := _vel[i].length()
        # Fast sparks/debris leave a short directional streak; dust stays soft.
        if speed >= 80.0:
            var trail_length := minf(4.0, speed * 0.025)
            var tail := particle_pos - _vel[i].normalized() * trail_length
            draw_line(tail, particle_pos, Color(c.r, c.g, c.b, c.a * 0.72), 1.0)
        var particle_size := maxf(1.0, _size[i] * lerpf(0.55, 1.0, life_ratio))
        draw_rect(
            Rect2(
                floorf(particle_pos.x - particle_size / 2.0),
                floorf(particle_pos.y - particle_size / 2.0),
                particle_size,
                particle_size
            ),
            c
        )
