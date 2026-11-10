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
    "food": {"n": 5, "speed": [12.0, 42.0], "up": [22.0, 58.0], "g": 260.0, "life": [0.28, 0.5], "size": [1, 2],
        "colors": ["#d7bd75", "#94a15b", "#c59b62", "#efe0b0"]},
    "dust": {"n": 3, "speed": [5.0, 18.0], "up": [4.0, 14.0], "g": 14.0, "life": [0.3, 0.55], "size": [1, 2],
        "colors": ["#d9c9a3", "#c4b48a", "#e8dcb8"], "alpha": 0.7},
    "puff": {"n": 6, "speed": [8.0, 28.0], "up": [6.0, 20.0], "g": 10.0, "life": [0.45, 0.85], "size": [3, 5],
        "colors": ["#d9d2c3", "#c4bba8", "#e8e2d0", "#b3ab9a"], "alpha": 0.8},
    "debris": {"n": 6, "speed": [20.0, 65.0], "up": [25.0, 70.0], "g": 280.0, "life": [0.4, 0.7], "size": [1, 2],
        "colors": ["#8b6b43", "#6b4a2b", "#8a8f98", "#6e737b", "#b08a5a"]},
    "structure_debris": {"n": 8, "speed": [28.0, 82.0], "up": [24.0, 68.0], "g": 340.0, "life": [0.38, 0.64], "size": [2, 3],
        "colors": ["#a77a45", "#765333", "#aeb3b9", "#858b91", "#c28a52", "#d4c7aa"]},
    "blade_trail": {"n": 5, "speed": [28.0, 78.0], "up": [7.0, 24.0], "g": 190.0, "life": [0.10, 0.22], "size": [1, 2],
        "colors": ["#fff5dc", "#e9d4a6", "#d9e6d6"], "alpha": 0.9},
    "dash": {"n": 7, "speed": [36.0, 105.0], "up": [5.0, 26.0], "g": 170.0, "life": [0.12, 0.24], "size": [1, 2],
        "colors": ["#d4e7db", "#a6c9bf", "#f0e6c7"], "alpha": 0.92},
    "dash_impact": {"n": 10, "speed": [34.0, 88.0], "up": [12.0, 36.0], "g": 250.0, "life": [0.13, 0.28], "size": [1, 2],
        "colors": ["#e9e2ce", "#c5c9b4", "#ffffff"]},
    "perfect_dodge": {"n": 12, "speed": [42.0, 112.0], "up": [18.0, 50.0], "g": 310.0, "life": [0.16, 0.34], "size": [1, 2],
        "colors": ["#fff4c5", "#e6e0ae", "#d4eadb"], "alpha": 0.98},
    "cleave_charge": {"n": 8, "speed": [18.0, 54.0], "up": [12.0, 32.0], "g": 210.0, "life": [0.15, 0.3], "size": [1, 2],
        "colors": ["#ffd78b", "#f0a64f", "#fff0bc"]},
    "heavy_impact": {"n": 14, "speed": [48.0, 126.0], "up": [24.0, 72.0], "g": 390.0, "life": [0.16, 0.36], "size": [1, 3],
        "colors": ["#fff1bf", "#f5c06b", "#d58a4d", "#ffffff"]},
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
var _burst_serial := 0

## Half-angle in radians for directed effects. Zero direction remains radial.
const DIRECTIONAL_SPREAD := {
    "spark": 0.90,
    "impact": 0.52,
    "hurt": 1.15,
    "wood": 1.00,
    "stone": 0.90,
    "food": 1.30,
    "dust": 1.35,
    "puff": 1.55,
    "debris": 1.05,
    "structure_debris": 0.72,
    "blade_trail": 0.42,
    "dash": 0.36,
    "dash_impact": 0.54,
    "perfect_dodge": 0.62,
    "cleave_charge": 1.18,
    "heavy_impact": 0.40,
    "rally": 1.55,
}


func _ready() -> void:
    z_index = 5
    var events := get_node_or_null("/root/Events")
    if events != null:
        events.fx_burst.connect(_on_burst)


func count() -> int:
    return _pos.size()


func _on_burst(kind: String, at: Vector2, dir: Vector2, amount: float) -> void:
    spawn(kind, at, dir, amount)


## dir: arah gerak utama; partikel menyebar dalam kerucut, nol = radial.
## Each burst owns its RNG so visual noise never advances gameplay's global RNG.
func spawn(kind: String, at: Vector2, dir := Vector2.ZERO, amount := 1.0) -> void:
    if not KINDS.has(kind) or amount <= 0.0:
        return
    var k: Dictionary = KINDS[kind]
    var requested := roundi(float(k["n"]) * amount)
    var n := clampi(requested, 1, MAX_PARTICLES)

    _burst_serial += 1
    var rng := RandomNumberGenerator.new()
    var seed_key := "%s|%d|%d|%d|%d|%d|%d" % [
        kind,
        roundi(at.x * 16.0),
        roundi(at.y * 16.0),
        roundi(dir.x * 1000.0),
        roundi(dir.y * 1000.0),
        roundi(amount * 1000.0),
        _burst_serial
    ]
    rng.seed = hash(seed_key)

    var directed := dir.length_squared() > 0.0001
    var spread := float(DIRECTIONAL_SPREAD.get(kind, 1.0))
    for i in n:
        if _pos.size() >= MAX_PARTICLES:
            _remove(0)
        var travel_direction := Vector2.RIGHT
        if directed:
            var axis := dir.normalized()
            var side := axis.orthogonal()
            var angle_offset := rng.randf_range(-spread, spread)
            travel_direction = axis * cos(angle_offset) + side * sin(angle_offset)
        else:
            var angle := rng.randf_range(0.0, TAU)
            travel_direction = Vector2(cos(angle), sin(angle) * 0.6).normalized()
        var speed := rng.randf_range(float(k["speed"][0]), float(k["speed"][1]))
        var velocity := travel_direction * speed
        var life := rng.randf_range(float(k["life"][0]), float(k["life"][1]))
        var colors: Array = k["colors"]
        var color := Color(String(colors[rng.randi_range(0, colors.size() - 1)]))
        color.a = float(k.get("alpha", 1.0))
        _pos.append(at + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-1.0, 1.0)))
        _vel.append(velocity)
        _z.append(0.0)
        _vz.append(rng.randf_range(float(k["up"][0]), float(k["up"][1])))
        _life.append(life)
        _max.append(life)
        _size.append(float(rng.randi_range(int(k["size"][0]), int(k["size"][1]))))
        _g.append(float(k["g"]))
        _col.append(color)
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
