extends Node2D
## Mayat: memutar animasi "death" sekali, bertahan sebentar, lalu memudar.

const SpriteAnim := preload("res://scripts/entities/sprite_anim.gd")
const HOLD := 1.0
const FADE := 0.8

var tex: Texture2D
var fw := 20
var fh := 20
var anim := SpriteAnim.new()

var _life := 0.0


static func spawn(parent: Node, texture: Texture2D, frame_w: int, frame_h: int, view: int, flipped: bool, pos: Vector2) -> void:
    var c: Node2D = (load("res://scripts/entities/corpse.gd") as GDScript).new()
    c.tex = texture
    c.fw = frame_w
    c.fh = frame_h
    c.anim.view = view
    c.anim.flip = flipped
    c.position = pos
    parent.add_child(c)


func _ready() -> void:
    anim.play("death", true)


func _physics_process(delta: float) -> void:
    if anim.update(delta):
        queue_redraw()
    if anim.finished:
        _life += delta
        modulate.a = clampf(1.0 - (_life - HOLD) / FADE, 0.0, 1.0)
        if _life >= HOLD + FADE:
            queue_free()


func _draw() -> void:
    anim.draw(self, tex, fw, fh)
