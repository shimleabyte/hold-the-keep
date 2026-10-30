extends RefCounted
## Font pixel (Silkscreen, SIL OFL 1.1; lisensi di assets/fonts/OFL-Silkscreen.txt).
## Dipakai ukuran 8 (atau kelipatan 8) supaya piksel tajam. Teks tampil huruf kapital.

const FONT := preload("res://assets/fonts/Silkscreen-Regular.ttf")

static var _configured := false


static func get_font() -> FontFile:
    var f: FontFile = FONT  # salinan lokal: properti tidak bisa diubah lewat const
    if not _configured:
        f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
        f.hinting = TextServer.HINTING_NONE
        f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
        _configured = true
    return f
