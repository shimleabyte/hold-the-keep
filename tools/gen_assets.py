#!/usr/bin/env python3
"""Generator aset SVG pixel-art untuk Hold the Keep (tanpa dependensi).

Jalankan:  python3 tools/gen_assets.py
Hasil:     assets/sprites/*.svg  (semua pakai shape-rendering=crispEdges di grid 1px)
Karakter/musuh berupa sprite sheet 4 frame (diam, jalan 1, jalan 2, aksi) berjajar horizontal.

Konvensi: sprite karakter/benda berdiri dengan titik tumpu di tengah-bawah kanvas,
sehingga kode game cukup menggambar di offset (-lebar/2, -tinggi).
Ubah palet di bagian atas lalu jalankan ulang untuk mengganti tampilan.
"""
import math
import os
import random
import re

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_OUT = os.path.join(HERE, "..", "assets", "sprites")
OUT = os.path.normpath(os.environ.get("HTK_ASSET_OUTPUT_DIR", DEFAULT_OUT))

# ---------------------------------------------------------------- palet
SKIN, SKIN_D = "#e8c39e", "#c99b73"
HAIR, DARK = "#5b3a1e", "#2a1f17"
WOOD, WOOD_D, WOOD_L = "#8b6b43", "#6b4a2b", "#a98557"
STONE, STONE_D, STONE_L = "#8a8f98", "#6e737b", "#a3a8b1"
STEEL, STEEL_L = "#9aa3b2", "#cfd6e2"
GOLD = "#e8c23a"
RED = "#c0392b"


class Svg:
    def __init__(self, w, h):
        self.w, self.h, self.items = w, h, []

    def rect(self, x, y, w, h, fill, op=1.0):
        if w > 0 and h > 0:
            self.items.append((x, y, w, h, fill, op))
        return self

    def blob(self, cx, cy, rx, ry, fill, op=1.0):
        """Elips pixel: satu rect per baris."""
        for y in range(int(math.floor(cy - ry)), int(math.ceil(cy + ry))):
            t = (y + 0.5 - cy) / ry
            if abs(t) >= 1:
                continue
            half = rx * math.sqrt(1 - t * t)
            x0, x1 = round(cx - half), round(cx + half)
            self.rect(x0, y, x1 - x0, 1, fill, op)
        return self

    def tri(self, cx, top, h, half, fill, line=None, every=3):
        """Segitiga bertangga (atap)."""
        for r in range(h):
            hw = round(1 + (half - 1) * r / max(1, h - 1))
            col = line if (line and r % every == every - 1) else fill
            self.rect(cx - hw, top + r, 2 * hw, 1, col)
        return self

    def pix(self, rows, pal, ox=0, oy=0):
        """ASCII art: '.' kosong, karakter lain dicari di palet. Run horizontal digabung."""
        for y, row in enumerate(rows):
            x = 0
            while x < len(row):
                ch = row[x]
                if ch == ".":
                    x += 1
                    continue
                x2 = x
                while x2 < len(row) and row[x2] == ch:
                    x2 += 1
                self.rect(ox + x, oy + y, x2 - x, 1, pal[ch])
                x = x2
        return self

    def save(self, name):
        os.makedirs(OUT, exist_ok=True)
        parts = [
            '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" '
            'shape-rendering="crispEdges">' % (self.w, self.h, self.w, self.h)
        ]
        for x, y, w, h, f, o in self.items:
            op = ' fill-opacity="%s"' % o if o < 1 else ""
            parts.append('<rect x="%s" y="%s" width="%s" height="%s" fill="%s"%s/>' % (x, y, w, h, f, op))
        parts.append("</svg>")
        with open(os.path.join(OUT, name + ".svg"), "w") as f:
            f.write("\n".join(parts) + "\n")


# ---------------------------------------------------------------- karakter
# Sprite sheet karakter: kolom = frame animasi, baris = arah pandang.
#   baris 0 depan (turun), 1 belakang (naik), 2 samping (menghadap kanan; kiri = flip di kode)
#   frame: idle 0-1, walk 2-5, run 6-9, attack 10-13, work 14-17, hurt 18, death 19-21
# Semua frame dibuat dari POSE (data) oleh renderer humanoid, supaya konsisten.

ANIMS = [("idle", 2), ("walk", 4), ("run", 4), ("attack", 4), ("work", 4), ("hurt", 1), ("death", 3)]
NF = sum(n for _, n in ANIMS)  # 22
VIEWS = ("front", "back", "side")
BELT = WOOD_D


class Look:
    def __init__(self, tunic, tunic_d, pants="#4a3b2a", hair=HAIR, hat=None, cape=None, mask=False,
                 tool_a=None, tool_w="same", shield=None, k=1.0, beard=None, trim=None, boots=DARK,
                 quiver=False, apron=False, heavy_armor=False):
        self.tunic, self.tunic_d, self.pants, self.hair = tunic, tunic_d, pants, hair
        self.hat, self.cape, self.mask, self.shield = hat, cape, mask, shield
        self.tool_a = tool_a
        self.tool_w = tool_a if tool_w == "same" else tool_w
        self.k, self.beard, self.trim, self.boots = k, beard, trim, boots
        self.quiver, self.apron, self.heavy_armor = quiver, apron, heavy_armor
        self.mx = int(math.floor(2 * k + 0.5))
        self.my = int(math.floor(4 * k + 0.5))
        self.fw = int(math.floor(16 * k + 0.5)) + 2 * self.mx
        self.fh = int(math.floor(16 * k + 0.5)) + self.my


def _rr(v):
    return int(math.floor(v + 0.5))


def make_r(svg, look, ox, oy):
    """rect pada grid 16x16 logis; tepi dibulatkan konsisten agar tak ada celah saat diskala (raja k=1.5)."""
    k = look.k

    def r(x, y, w, h, c, op=1.0):
        x0, y0 = _rr(x * k), _rr(y * k)
        x1, y1 = _rr((x + w) * k), _rr((y + h) * k)
        if x1 <= x0:
            x1 = x0 + 1
        if y1 <= y0:
            y1 = y0 + 1
        svg.rect(ox + look.mx + x0, oy + look.my + y0, x1 - x0, y1 - y0, c, op)
    return r


def line_pts(x0, y0, x1, y1):
    x0, y0, x1, y1 = _rr(x0), _rr(y0), _rr(x1), _rr(y1)
    pts, dx, dy = [], abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        pts.append((x0, y0))
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy
    return pts


def draw_tool(r, kind, hx, hy, dx, dy, sc=1.0):
    if kind is None:
        return
    n = math.hypot(dx, dy)
    ux, uy = dx / n, dy / n
    px, py = -uy, ux

    def P(x, y, c):
        r(_rr(x), _rr(y), 1, 1, c)

    def along(L, c, start=0.0):
        for x, y in line_pts(hx + ux * start, hy + uy * start, hx + ux * L, hy + uy * L):
            P(x, y, c)

    base = {"axe": 7, "pick": 7, "fork": 8, "mace": 6}.get(kind, 0) * sc
    ex, ey = hx + ux * base, hy + uy * base
    if kind == "axe":
        along(7 * sc, WOOD_D)
        for i in (0, 1):
            for j in (-1, 0):
                P(ex + px * (i + 0.5) + ux * j, ey + py * (i + 0.5) + uy * j, STEEL_L)
        P(ex + px * 2.5, ey + py * 2.5, STEEL)
    elif kind == "pick":
        along(7 * sc, WOOD_D)
        for i in (-2, -1, 0, 1, 2):
            P(ex + px * i, ey + py * i, STEEL if abs(i) < 2 else STEEL_L)
        P(ex + ux, ey + uy, STEEL)
    elif kind == "fork":
        along(8 * sc, WOOD_D)
        for i in (-1, 0, 1):
            P(ex + px * i, ey + py * i, STONE)
        P(ex + px * -1 + ux, ey + py * -1 + uy, STONE)
        P(ex + px * 1 + ux, ey + py * 1 + uy, STONE)
    elif kind in ("sword", "esword"):
        along(8 * sc, "#e8e8e8", 1)
        along(7 * sc, STEEL_L, 2)
        gc = GOLD if kind == "sword" else STONE
        for i in (-1, 0, 1):
            P(hx + px * i, hy + py * i, gc)
        P(hx - ux, hy - uy, WOOD_D)
        P(hx - ux * 2, hy - uy * 2, WOOD_D)
    elif kind == "hammer":
        along(7 * sc, WOOD_D)
        for i in (-2, -1, 0, 1, 2):
            P(ex + px * i, ey + py * i, STEEL)
        P(ex + ux, ey + uy, STEEL_L)
    elif kind == "bow":
        for step in range(7):
            t = -1.0 + step / 3.0
            P(hx + ux * (3.0 * (1.0 - t * t)) + px * (4.0 * t),
              hy + uy * (3.0 * (1.0 - t * t)) + py * (4.0 * t), WOOD_D)
        for x, y in line_pts(hx - px * 4, hy - py * 4, hx + px * 4, hy + py * 4):
            P(x, y, STEEL_L)
    elif kind == "mace":
        along(6 * sc, WOOD_D)
        for i in (-2, -1, 0, 1, 2):
            P(ex + px * i, ey + py * i, STEEL)
        P(ex + ux, ey + uy, STEEL_L)
        P(ex + ux * 2, ey + uy * 2, "#515965")
    elif kind == "dagger":
        along(max(2, 4 * sc), STEEL_L, 1)
        for i in (-1, 0, 1):
            P(hx + px * i, hy + py * i, WOOD_D)


# (hand_x, hand_y, dir_x, dir_y) menurut arah pandang dan status alat
TOOL_POSE = {
    "front": {"rest": (13, 12, 0, -1, 1), "rest2": (13, 13, 0, -1, 1), "carry": (13, 11, 0, -1, 1), "raised": (13, 6, 0, -1, 1),
              "swing": (13, 10, 0, 1, 0.45), "low": (13, 12, 0, 1, 0.4), "thrust": (13, 11, 0, 1, 0.4), "back": (13, 10, 0, -1, 0.7)},
    "back": {"rest": (13, 12, 0, -1, 1), "rest2": (13, 13, 0, -1, 1), "carry": (13, 11, 0, -1, 1), "raised": (13, 6, 0, -1, 1),
             "swing": (13, 8, 0, -1, 0.6), "low": (13, 10, 0, -1, 0.5), "thrust": (13, 8, 0, -1, 0.5), "back": (13, 11, 0, 1, 0.4)},
    "side": {"rest": (10, 12, 0, -1, 1), "rest2": (10, 13, 0, -1, 1), "carry": (9, 11, -1, -1, 1), "raised": (9, 6, -1, -2, 1),
             "swing": (11, 9, 1, 1, 1), "low": (11, 12, 1, 2, 1), "thrust": (11, 9, 1, 0, 1), "back": (7, 9, 1, 0, 0.8)},
}

SWING = {"states": ["raised", "swing", "low", "rest"], "by": [-1, 0, 1, 0], "lean": [-1, 1, 2, 0]}
STAB = {"states": ["back", "thrust", "thrust", "rest"], "by": [0, 0, 0, 0], "lean": [-1, 1, 2, 0]}
POKE = {"states": ["raised", "low", "low", "rest"], "by": [-1, 1, 1, 0], "lean": [0, 1, 1, 0]}
TOOL_ANIM = {None: STAB, "axe": SWING, "pick": SWING, "fork": POKE, "hammer": SWING, "sword": STAB, "esword": STAB, "dagger": STAB, "bow": STAB, "mace": SWING}


def pose_for(look, anim, i):
    if anim == "idle":
        return [dict(), dict(blink=True, tool="rest2")][i]
    if anim == "walk":
        return [
            dict(by=0, n=(2, 0), f=(-2, 1), arm=-1, lg=(1, 0)),
            dict(by=-1, n=(0, 0), f=(0, 1), arm=0, lg=(0, 0)),
            dict(by=0, n=(-2, 1), f=(2, 0), arm=1, lg=(0, 1)),
            dict(by=-1, n=(0, 1), f=(0, 0), arm=0, lg=(0, 0)),
        ][i]
    if anim == "run":
        return [
            dict(by=0, lean=1, n=(3, 0), f=(-3, 2), arm=-2, lg=(2, 0), tool="carry", run=1),
            dict(by=-1, lean=1, n=(0, 0), f=(0, 2), arm=0, lg=(0, 0), tool="carry", run=1),
            dict(by=0, lean=1, n=(-3, 2), f=(3, 0), arm=2, lg=(0, 2), tool="carry", run=1),
            dict(by=-1, lean=1, n=(0, 2), f=(0, 0), arm=0, lg=(0, 0), tool="carry", run=1),
        ][i]
    if anim in ("attack", "work"):
        seq = TOOL_ANIM[look.tool_a if anim == "attack" else look.tool_w]
        return dict(tool=seq["states"][i], by=seq["by"][i], lean=seq["lean"][i], act=anim, step=i)
    if anim == "hurt":
        return dict(by=0, lean=-2, tool="rest2", hurt=True, blink=True)
    if anim == "death":
        return dict(dead=i + 1)
    raise ValueError(anim)


def draw_hat(look, r, by, lean=0):
    h, L = look.hat, lean
    if h == "wood":
        r(4 + L, 0 + by, 8, 3, "#3f7d3a"); r(4 + L, 3 + by, 8, 1, "#2f5d2c"); r(5 + L, 0 + by, 3, 1, "#5aa24f")
    elif h == "miner":
        r(4 + L, 0 + by, 8, 3, "#e0b030"); r(3 + L, 3 + by, 10, 1, "#b8901f"); r(7 + L, 1 + by, 2, 1, "#fff3b0")
    elif h == "farm":
        r(5 + L, 0 + by, 6, 2, "#d6b86a"); r(5 + L, 1 + by, 6, 1, "#8a6a2a"); r(2 + L, 2 + by, 12, 1, "#e8d28a")
    elif h == "helm":
        r(4 + L, 0 + by, 8, 3, STEEL); r(5 + L, 0 + by, 3, 1, STEEL_L); r(4 + L, 3 + by, 1, 2, STEEL); r(11 + L, 3 + by, 1, 2, STEEL)
    elif h == "builder":
        r(5 + L, 0 + by, 6, 3, "#e0a432"); r(4 + L, 3 + by, 8, 1, "#865a2b")
        r(7 + L, 1 + by, 2, 1, "#fff0b5"); r(10 + L, 1 + by, 2, 1, "#fff0b5")
    elif h == "archer":
        r(4 + L, 0 + by, 8, 3, "#365d45"); r(3 + L, 3 + by, 10, 1, "#244232")
        r(10 + L, -1 + by, 1, 2, "#d6c18b"); r(11 + L, -2 + by, 1, 2, "#a9bd7b")
    elif h == "brute":
        r(3 + L, 0 + by, 10, 3, "#626b75"); r(4 + L, 0 + by, 8, 1, "#c7cdd5")
        r(3 + L, 3 + by, 10, 2, "#3b414c"); r(5 + L, 4 + by, 6, 1, "#252a33")
    elif h == "hood":
        r(4 + L, 0 + by, 8, 5, "#5c1f1f"); r(4 + L, 5 + by, 1, 2, "#5c1f1f"); r(11 + L, 5 + by, 1, 2, "#5c1f1f")
    elif h == "band":
        r(5 + L, 2 + by, 6, 1, RED)
    elif h == "crown":
        r(5 + L, 0 + by, 6, 2, GOLD); r(5 + L, -1 + by, 1, 1, GOLD); r(7 + L, -1 + by, 2, 1, GOLD); r(10 + L, -1 + by, 1, 1, GOLD)
        r(7 + L, 1 + by, 2, 1, RED)


def draw_dead(look, r, stage):
    SK = SKIN
    r(2, 15, 12, 1, "#000000", 0.3)
    if stage == 1:  # berlutut / terhuyung
        r(4, 12, 8, 3, look.pants); r(4, 10, 8, 4, look.tunic); r(4, 13, 8, 1, look.tunic_d)
        r(5, 4, 6, 6, SK); r(5, 4, 6, 2, look.hair); r(6, 7, 1, 1, DARK); r(9, 7, 1, 1, DARK)
        draw_hat(look, r, 3, 0)
    elif stage == 2:  # jatuh miring
        r(11, 11, 4, 3, look.pants); r(6, 10, 6, 5, look.tunic); r(6, 14, 6, 1, look.tunic_d)
        r(2, 9, 5, 5, SK); r(2, 9, 5, 2, look.hair); r(3, 12, 1, 1, DARK)
        r(13, 14, 2, 1, look.boots)
    else:  # terbaring
        r(12, 12, 3, 3, look.pants); r(6, 11, 6, 4, look.tunic); r(6, 14, 6, 1, look.tunic_d)
        r(1, 11, 5, 4, SK); r(1, 11, 5, 2, look.hair); r(3, 13, 1, 1, DARK); r(14, 14, 1, 1, look.boots)
        if look.tool_a:
            pass


def humanoid_frame(look, view, pose):
    svg = Svg(look.fw, look.fh)
    return svg, make_r(svg, look, 0, 0)


def render_humanoid(look, view, pose, svg, ox, oy):
    r = make_r(svg, look, ox, oy)
    if pose.get("dead"):
        draw_dead(look, r, pose["dead"])
        return
    by = pose.get("by", 0)
    lean = pose.get("lean", 0) if view == "side" else 0
    tool_state = pose.get("tool", "rest")
    hx, hy, dx, dy, sc = TOOL_POSE[view][tool_state]
    if view == "side":
        hx += lean
        hx += pose.get("arm", 0) if tool_state in ("rest", "rest2", "carry") else 0
    elif tool_state in ("rest", "rest2", "carry"):
        hy += pose.get("arm", 0) * -1 if view == "front" else 0
    hy += by
    kind = look.tool_a if pose.get("act") != "work" else look.tool_w
    blink = pose.get("blink", False)
    hurt = pose.get("hurt", False)

    r(3, 15, 10, 1, "#000000", 0.3)  # bayangan

    def boot(x, w, lift):
        if 2 - lift > 0:
            r(x, 13, w, 2 - lift, look.pants)
        r(x, 15 - lift, w, 1, look.boots)

    def arm_line(x0, y0, x1, y1, c):
        for x, y in line_pts(x0, y0, x1, y1):
            r(x, y, 1, 1, c)

    def head_front(back):
        if back:
            r(5, 1 + by, 6, 6, look.hair); r(5, 6 + by, 6, 1, look.hair)
        else:
            r(5, 1 + by, 6, 6, SKIN); r(5, 6 + by, 6, 1, SKIN_D)
            r(5, 1 + by, 6, 2, look.hair); r(5, 3 + by, 1, 1, look.hair); r(10, 3 + by, 1, 1, look.hair)
            ec = SKIN_D if blink else DARK
            r(6, 4 + by, 1, 1, ec); r(9, 4 + by, 1, 1, ec)
            if hurt:
                r(7, 6 + by, 2, 1, "#8a2a2a")
            if look.mask:
                r(5, 5 + by, 6, 2, "#2a1f17"); r(6, 4 + by, 1, 1, "#ffd23f"); r(9, 4 + by, 1, 1, "#ffd23f")
            if look.beard:
                r(5, 6 + by, 6, 2, look.beard); r(7, 6 + by, 2, 1, SKIN_D)
        draw_hat(look, r, by)

    if view in ("front", "back"):
        back = view == "back"
        lg = pose.get("lg", (0, 0))
        if look.cape and not back:
            r(3, 8 + by, 10, 7, look.cape)
        if look.quiver:
            r(2, 7 + by, 3, 7, WOOD_D); r(2, 7 + by, 3, 1, WOOD_L)
            r(3, 5 + by, 1, 5, STEEL_L); r(4, 6 + by, 1, 5, STEEL_L)
        boot(5, 2, lg[0]); boot(9, 2, lg[1])
        r(4, 7 + by, 8, 6, look.tunic); r(4, 12 + by, 8, 1, look.tunic_d); r(4, 10 + by, 8, 1, BELT)
        if look.trim:
            r(4, 7 + by, 8, 1, look.trim); r(4, 10 + by, 8, 1, look.trim)
        if look.apron and not back:
            r(5, 11 + by, 6, 4, "#68442d"); r(5, 11 + by, 6, 1, "#b88247")
            r(6, 12 + by, 1, 2, "#d19a5a"); r(9, 12 + by, 1, 2, "#d19a5a")
        if look.heavy_armor:
            r(2, 8 + by, 3, 3, "#4b515c"); r(3, 8 + by, 2, 1, "#b6bdc6")
            r(11, 8 + by, 3, 3, "#4b515c"); r(11, 8 + by, 2, 1, "#b6bdc6")
            r(5, 8 + by, 6, 4, "#68717d"); r(6, 9 + by, 4, 1, "#c7cdd5")
            r(7, 11 + by, 2, 1, "#a38a58")
        sw = pose.get("arm", 0)
        r(3, 8 + by, 1, 4, look.tunic_d); r(3, 12 + by + max(0, sw), 1, 1, SKIN)
        if look.shield:
            r(1, 7 + by, 3, 5, look.shield); r(1, 7 + by, 3, 1, "#e8e8e8"); r(2, 9 + by, 1, 1, GOLD)
        if back:
            arm_line(12, 8 + by, hx, hy, look.tunic_d); r(hx, hy, 1, 1, SKIN)
            draw_tool(r, kind, hx, hy, dx, dy, sc)
            head_front(True)
            if look.cape:
                r(4, 8 + by, 8, 7, look.cape); r(4, 14 + by, 8, 1, "#000000", 0.2)
        else:
            head_front(False)
            arm_line(12, 8 + by, hx, hy, look.tunic_d); r(hx, hy, 1, 1, SKIN)
            draw_tool(r, kind, hx, hy, dx, dy, sc)
        return

    # ---- samping (menghadap kanan)
    n_off, n_lift = pose.get("n", (0, 0))
    f_off, f_lift = pose.get("f", (0, 0))
    if look.cape:
        back_len = 3 if pose.get("run") else 2
        r(5 - back_len + lean, 8 + by, back_len + 1, 7 + (0 if pose.get("run") else 0), look.cape)
    if look.quiver:
        r(2 + lean, 7 + by, 2, 7, WOOD_D); r(2 + lean, 7 + by, 2, 1, WOOD_L)
        r(3 + lean, 5 + by, 1, 6, STEEL_L); r(4 + lean, 6 + by, 1, 5, STEEL_L)
    # kaki jauh
    fx = 7 + f_off
    if 2 - f_lift > 0:
        r(fx, 13, 2, 2 - f_lift, "#3a2f22")
    r(fx, 15 - f_lift, 2, 1, look.boots)
    if look.shield:
        r(4 + lean, 8 + by, 2, 5, look.shield)
    far_hand = (6 + lean - pose.get("arm", 0), 12 + by)
    arm_line(7 + lean, 8 + by, far_hand[0], far_hand[1], look.tunic_d)
    r(5 + lean, 7 + by, 5, 6, look.tunic); r(5 + lean, 12 + by, 5, 1, look.tunic_d); r(5 + lean, 10 + by, 5, 1, BELT)
    if look.trim:
        r(5 + lean, 7 + by, 5, 1, look.trim)
    if look.apron:
        r(6 + lean, 11 + by, 4, 4, "#68442d"); r(6 + lean, 11 + by, 4, 1, "#b88247")
    if look.heavy_armor:
        r(4 + lean, 7 + by, 3, 2, "#4b515c"); r(4 + lean, 7 + by, 3, 1, "#b6bdc6")
        r(7 + lean, 8 + by, 4, 4, "#68717d"); r(8 + lean, 9 + by, 2, 1, "#c7cdd5")
    # kaki dekat
    nx = 6 + n_off
    if 2 - n_lift > 0:
        r(nx, 13, 2, 2 - n_lift, look.pants)
    r(nx, 15 - n_lift, 2, 1, look.boots)
    # kepala
    r(5 + lean, 1 + by, 5, 6, SKIN); r(5 + lean, 6 + by, 5, 1, SKIN_D)
    r(5 + lean, 1 + by, 5, 2, look.hair); r(5 + lean, 3 + by, 2, 3, look.hair)
    r(8 + lean, 4 + by, 1, 1, SKIN_D if blink else DARK); r(10 + lean, 4 + by, 1, 1, SKIN_D)
    if hurt:
        r(8 + lean, 6 + by, 2, 1, "#8a2a2a")
    if look.mask:
        r(8 + lean, 5 + by, 3, 2, "#2a1f17"); r(8 + lean, 4 + by, 1, 1, "#ffd23f")
    if look.beard:
        r(7 + lean, 6 + by, 3, 2, look.beard)
    draw_hat(look, r, by, lean)
    arm_line(8 + lean, 8 + by, hx, hy, look.tunic_d); r(hx, hy, 1, 1, SKIN)
    draw_tool(r, kind, hx, hy, dx, dy, sc)


def humanoid_sheet(name, look):
    sheet = Svg(look.fw * NF, look.fh * len(VIEWS))
    col = 0
    for anim, n in ANIMS:
        for i in range(n):
            pose = pose_for(look, anim, i)
            for row, view in enumerate(VIEWS):
                render_humanoid(look, view, pose, sheet, col * look.fw, row * look.fh)
            col += 1
    sheet.save(name)




def _role_sprite_rect(x, y, w, h, fill):
    return '<rect x="%s" y="%s" width="%s" height="%s" fill="%s"/>' % (x, y, w, h, fill)


def make_role_variant(source_name, output_name, kind):
    """Build a role sheet from a stable base sheet plus role equipment overlays.

    The overlay grid matches the committed 22-frame x 3-direction sheets exactly.
    This keeps the SVGs reproducible without forking the underlying walk/attack poses.
    """
    source_path = os.path.join(OUT, source_name + ".svg")
    with open(source_path, "r", encoding="utf-8") as source_file:
        source = source_file.read()

    match = re.search(r'<svg[^>]*width="(\d+)"[^>]*height="(\d+)"[^>]*>', source)
    if not match:
        raise ValueError("Could not read dimensions from %s" % source_path)
    width, height = int(match.group(1)), int(match.group(2))
    fw, fh = width // NF, height // len(VIEWS)
    if fw != 20 or fh != 20 or width % NF or height % len(VIEWS):
        raise ValueError("Unexpected role sprite frame layout: %dx%d" % (width, height))

    groups = []
    for row in range(len(VIEWS)):
        for frame in range(NF):
            rects = []
            if kind == "builder":
                rects.extend([
                    _role_sprite_rect(5, 4, 10, 1, "#3f3024"),
                    _role_sprite_rect(6, 2, 8, 3, "#dca43a"),
                    _role_sprite_rect(8, 2, 3, 1, "#fff0b5"),
                    _role_sprite_rect(6, 5, 8, 1, "#9b682d"),
                ])
                if row == 0:
                    rects.extend([
                        _role_sprite_rect(6, 12, 8, 4, "#68442d"),
                        _role_sprite_rect(6, 12, 8, 1, "#bd8950"),
                        _role_sprite_rect(7, 13, 1, 2, "#e1ad68"),
                        _role_sprite_rect(12, 13, 1, 2, "#4d3325"),
                    ])
                elif row == 1:
                    rects.extend([
                        _role_sprite_rect(6, 11, 8, 4, "#68442d"),
                        _role_sprite_rect(6, 11, 8, 1, "#bd8950"),
                    ])
                else:
                    rects.extend([
                        _role_sprite_rect(7, 12, 5, 4, "#68442d"),
                        _role_sprite_rect(7, 12, 5, 1, "#bd8950"),
                    ])
                if 14 <= frame <= 17:
                    hammer_y = [8, 10, 13, 11][frame - 14]
                elif 10 <= frame <= 13:
                    hammer_y = [10, 11, 12, 12][frame - 10]
                else:
                    hammer_y = 12
                rects.extend([
                    _role_sprite_rect(15, hammer_y + 1, 1, max(1, 18 - (hammer_y + 1)), "#6b4a2b"),
                    _role_sprite_rect(14, hammer_y, 4, 2, "#858f9d"),
                    _role_sprite_rect(15, hammer_y, 2, 1, "#cfd6e2"),
                ])
            elif kind == "archer":
                quiver_x = 2 if row == 2 else 3
                shift = [0, 1, 2, 1][frame - 10] if 10 <= frame <= 13 else 0
                bow_x = 15 + shift % 2
                rects.extend([
                    _role_sprite_rect(quiver_x, 8, 3, 6, "#59402b"),
                    _role_sprite_rect(quiver_x, 8, 3, 1, "#a98557"),
                    _role_sprite_rect(quiver_x + 1, 6, 1, 7, "#cfd6e2"),
                    _role_sprite_rect(quiver_x + 2, 7, 1, 6, "#cfd6e2"),
                    _role_sprite_rect(8, 3, 1, 2, "#d6c18b"),
                    _role_sprite_rect(9, 2, 1, 2, "#a9bd7b"),
                    _role_sprite_rect(bow_x, 7, 1, 2, "#8b6b43"),
                    _role_sprite_rect(bow_x + 1, 9, 1, 3, "#8b6b43"),
                    _role_sprite_rect(bow_x, 12, 1, 3, "#8b6b43"),
                    _role_sprite_rect(bow_x - 1, 15, 2, 1, "#8b6b43"),
                    _role_sprite_rect(bow_x, 8, 1, 7, "#d8d3c3"),
                ])
            elif kind == "brute":
                rects.extend([
                    _role_sprite_rect(2, 9, 5, 4, "#424953"),
                    _role_sprite_rect(2, 9, 5, 1, "#b6bdc6"),
                    _role_sprite_rect(13, 9, 5, 4, "#424953"),
                    _role_sprite_rect(13, 9, 5, 1, "#b6bdc6"),
                    _role_sprite_rect(6, 10, 8, 5, "#59616d"),
                    _role_sprite_rect(7, 11, 6, 1, "#c7cdd5"),
                    _role_sprite_rect(9, 12, 2, 1, "#9b8250"),
                    _role_sprite_rect(4, 4, 2, 2, "#9aa3b2"),
                    _role_sprite_rect(14, 4, 2, 2, "#9aa3b2"),
                    _role_sprite_rect(6, 3, 8, 3, "#626b75"),
                    _role_sprite_rect(7, 3, 6, 1, "#cfd6e2"),
                    _role_sprite_rect(7, 7, 6, 1, "#252a33"),
                ])
                mace_y = [8, 10, 12, 11][frame - 10] if 10 <= frame <= 13 else 11
                rects.extend([
                    _role_sprite_rect(15, mace_y + 2, 1, max(1, 18 - (mace_y + 2)), "#6b4a2b"),
                    _role_sprite_rect(14, mace_y, 4, 3, "#68717d"),
                    _role_sprite_rect(14, mace_y, 4, 1, "#c7cdd5"),
                    _role_sprite_rect(15, mace_y - 1, 2, 1, "#9b8250"),
                ])
            else:
                raise ValueError("Unknown role sprite variant: %s" % kind)

            groups.append(
                '<g transform="translate(%d %d)">%s</g>'
                % (frame * fw, row * fh, "".join(rects))
            )

    output = source.replace("</svg>", "\n".join(groups) + "\n</svg>")
    if kind == "builder":
        output = (output.replace("#8a8f98", "#b77935")
                        .replace("#6e737b", "#825329")
                        .replace("#e0b030", "#c98d2c")
                        .replace("#b8901f", "#9a6b2d"))
    elif kind == "archer":
        output = (output.replace("#a33b3b", "#496c54")
                        .replace("#7d2c2c", "#304b3b")
                        .replace("#5c1f1f", "#253e32")
                        .replace("#c0392b", "#557b58"))
    else:
        output = (output.replace("#3b4f8a", "#565a63")
                        .replace("#2d3d6b", "#343943"))

    with open(os.path.join(OUT, output_name + ".svg"), "w", encoding="utf-8") as output_file:
        output_file.write(output)


def make_role_variants():
    make_role_variant("villager_miner", "villager_builder", "builder")
    make_role_variant("enemy_bandit", "enemy_archer", "archer")
    make_role_variant("enemy_soldier", "enemy_brute", "brute")

# ---------------------------------------------------------------- serigala

def render_wolf(view, pose, svg, ox, oy, fw=20, fh=20, mx=2, my=4):
    def r(x, y, w, h, c, op=1.0):
        svg.rect(ox + mx + x, oy + my + y, w, h, c, op)

    G, GD, GL = "#7d7d85", "#5f5f67", "#9a9aa3"
    by = pose.get("by", 0)
    lean = pose.get("lean", 0)
    n_off, n_lift = pose.get("n", (0, 0))
    f_off, f_lift = pose.get("f", (0, 0))
    lg = pose.get("lg", (0, 0))
    act = pose.get("act")
    dead = pose.get("dead", 0)
    jaw = act == "attack" and pose.get("step", 0) in (1, 2)
    crouch = 1 if (act == "attack" and pose.get("step", 0) == 0) else 0
    r(2, 14, 12, 1, "#000000", 0.3)
    if dead:
        if dead == 1:
            r(3, 8, 9, 5, G); r(3, 12, 9, 1, GD); r(11, 7, 4, 4, "#8a8a93"); r(12, 8, 1, 1, DARK); r(0, 8, 3, 2, "#6a6a72")
        elif dead == 2:
            r(3, 10, 10, 4, G); r(3, 13, 10, 1, GD); r(12, 10, 3, 3, "#8a8a93"); r(13, 11, 1, 1, DARK); r(0, 11, 3, 2, "#6a6a72")
        else:
            r(2, 11, 11, 3, G); r(2, 13, 11, 1, GD); r(12, 11, 3, 3, "#8a8a93"); r(13, 12, 1, 1, DARK); r(0, 12, 2, 2, "#6a6a72")
        return
    if view == "side":
        def leg(x, off, lift, c):
            xx = x + off
            if 3 - lift > 0:
                r(xx, 12, 2, 3 - lift, c)
            r(xx, 14 - lift, 2, 1, "#4a4a52")
        leg(4, f_off, f_lift, "#5a5a62"); leg(10, n_off, n_lift, "#5a5a62")  # kaki jauh
        r(3 + lean, 7 + by + crouch, 9, 5, G); r(3 + lean, 11 + by + crouch, 9, 1, GD); r(4 + lean, 7 + by + crouch, 7, 1, GL)
        leg(5, -f_off, f_lift if False else n_lift, "#6a6a72"); leg(9, -n_off, f_lift, "#6a6a72")
        tail_dy = 0 if pose.get("run") else (1 if (pose.get("by", 0) == -1) else 0)
        r(0 + lean - (1 if pose.get("run") else 0), 6 + by + tail_dy, 3, 2, "#6a6a72"); r(1 + lean, 5 + by + tail_dy, 1, 1, "#6a6a72")
        hy = by + crouch - (1 if jaw else 0)
        r(11 + lean, 5 + hy, 4, 4, "#8a8a93"); r(14 + lean, 7 + hy, 2, 2, "#6a6a72"); r(15 + lean, 7 + hy, 1, 1, "#111111")
        r(11 + lean, 3 + hy, 1, 2, "#6a6a72"); r(13 + lean, 3 + hy, 1, 2, "#6a6a72")
        r(12 + lean, 6 + hy, 1, 1, "#ffd23f")
        if jaw:
            r(13 + lean, 9 + hy, 3, 2, "#c0392b"); r(13 + lean, 9 + hy, 1, 1, "#ffffff"); r(15 + lean, 9 + hy, 1, 1, "#ffffff")
        else:
            r(14 + lean, 9 + hy, 1, 1, "#ffffff")
        return
    if view == "front":
        for i, x in enumerate((4, 10)):
            lift = lg[i]
            if 3 - lift > 0:
                r(x, 12, 2, 3 - lift, "#6a6a72")
            r(x, 14 - lift, 2, 1, "#4a4a52")
        r(4, 8 + by, 8, 5, G); r(4, 12 + by, 8, 1, GD); r(6, 9 + by, 4, 2, GL)
        r(5, 3 + by + crouch, 6, 6, "#8a8a93")
        r(5, 1 + by + crouch, 2, 3, "#6a6a72"); r(9, 1 + by + crouch, 2, 3, "#6a6a72")
        ec = "#ffd23f"
        r(6, 5 + by + crouch, 1, 1, ec); r(9, 5 + by + crouch, 1, 1, ec)
        r(7, 7 + by + crouch, 2, 2, "#6a6a72"); r(7, 7 + by + crouch, 2, 1, "#111111")
        if jaw:
            r(6, 9 + by + crouch, 4, 2, "#c0392b"); r(6, 9 + by + crouch, 1, 1, "#fff"); r(9, 9 + by + crouch, 1, 1, "#fff")
        return
    # belakang
    for i, x in enumerate((4, 10)):
        lift = lg[i]
        if 3 - lift > 0:
            r(x, 12, 2, 3 - lift, "#6a6a72")
        r(x, 14 - lift, 2, 1, "#4a4a52")
    r(4, 6 + by, 8, 7, G); r(4, 12 + by, 8, 1, GD); r(6, 7 + by, 4, 2, GL)
    r(5, 4 + by, 1, 2, "#6a6a72"); r(10, 4 + by, 1, 2, "#6a6a72")
    r(7, 3 + by - (1 if pose.get("run") else 0), 2, 4, "#6a6a72")


def wolf_sheet(name):
    fw, fh = 20, 20
    sheet = Svg(fw * NF, fh * len(VIEWS))
    col = 0
    dummy = Look("#000", "#000")
    for anim, n in ANIMS:
        for i in range(n):
            if anim == "work":
                pose = pose_for(dummy, "idle", i % 2)
            else:
                pose = pose_for(dummy, anim, i)
            if anim == "attack":
                pose = dict(pose, step=i, act="attack")
            for row, view in enumerate(VIEWS):
                render_wolf(view, pose, sheet, col * fw, row * fh)
            col += 1
    sheet.save(name)


def make_characters():
    humanoid_sheet("player", Look("#c9a227", "#a8841c", hat="band", cape="#8a2a2a", tool_a="sword", tool_w="axe"))
    humanoid_sheet("villager_idle", Look("#d9d2c3", "#b3ab9a"))
    humanoid_sheet("villager_woodcutter", Look("#4e9a4a", "#3b7a38", hat="wood", tool_a="axe"))
    humanoid_sheet("villager_miner", Look("#8a8f98", "#6e737b", hat="miner", tool_a="pick"))
    humanoid_sheet("villager_builder", Look("#b77935", "#825329", pants="#574532", hat="builder",
                                             tool_a="hammer", tool_w="hammer", apron=True, trim="#d89a4e"))
    humanoid_sheet("villager_blacksmith", Look("#985c3d", "#6f3e2a", pants="#3c3029", hat="band",
                                                tool_a="hammer", tool_w="hammer", beard="#4a3024",
                                                trim="#e19a55"))
    humanoid_sheet("villager_farmer", Look("#d6b13c", "#a8892c", hat="farm", tool_a="fork"))
    humanoid_sheet("villager_soldier", Look("#3f6fb5", "#2f548a", hat="helm", tool_a="sword", shield="#3f6fb5"))
    humanoid_sheet("enemy_bandit", Look("#a33b3b", "#7d2c2c", hat="hood", tool_a="dagger", mask=True))
    humanoid_sheet("enemy_archer", Look("#496c54", "#304b3b", pants="#373f32", hat="archer",
                                        cape="#253e32", tool_a="bow", tool_w="bow", quiver=True, trim="#a9b97c"))
    humanoid_sheet("enemy_soldier", Look("#3b4f8a", "#2d3d6b", hat="helm", tool_a="esword", shield=STEEL))
    humanoid_sheet("enemy_brute", Look("#595b64", "#383c45", pants="#312d2a", hat="brute",
                                       cape="#3a3030", tool_a="mace", tool_w="mace", shield="#606773",
                                       heavy_armor=True, beard="#3f302a", trim="#9b8250", k=1.1))
    wolf_sheet("enemy_wolf")
    humanoid_sheet("enemy_king", Look("#4a4a58", "#34343f", pants="#2a2a33", hat="crown", cape="#5a1019", tool_a="sword",
                                      beard="#6b3a1e", trim=GOLD, k=1.5, boots="#111111"))


# ---------------------------------------------------------------- alam

def make_nature():
    rnd = random.Random(11)
    t = Svg(20, 28)  # pohon
    t.rect(4, 26, 12, 2, "#000000", 0.25)
    t.rect(8, 17, 4, 11, WOOD_D).rect(8, 17, 1, 11, "#553a22").rect(7, 26, 1, 2, WOOD_D).rect(12, 26, 1, 2, WOOD_D)
    t.blob(10, 11, 9, 9, "#27582f").blob(7, 9, 6, 6, "#2f6b3a").blob(13, 10, 6, 6, "#3a7d45")
    t.blob(8, 6, 3, 2, "#4a9a57")
    for _ in range(10):
        t.rect(rnd.randint(3, 16), rnd.randint(3, 17), 1, 1, rnd.choice(["#1f4727", "#4a9a57"]))
    t.save("tree")

    s = Svg(12, 8)  # tunggul
    s.rect(1, 6, 10, 2, "#000000", 0.25)
    s.rect(1, 2, 10, 6, WOOD_D).rect(1, 2, 10, 2, WOOD).rect(4, 3, 4, 1, "#a77a45").rect(1, 4, 1, 4, "#553a22")
    s.save("stump")

    r = Svg(16, 12)  # batu
    r.rect(1, 10, 14, 2, "#000000", 0.25)
    r.blob(8, 7, 7, 5, "#8d9298").blob(6, 6, 4, 3, "#aeb3b9").rect(10, 8, 4, 2, "#6f747a").rect(8, 5, 1, 3, "#5f646a")
    r.save("rock")

    d = Svg(12, 6)  # batu habis
    d.blob(6, 4, 5, 2, "#7a7f85").rect(3, 3, 2, 1, "#9aa0a6").rect(7, 4, 3, 1, "#656a70")
    d.save("rock_depleted")


def make_tiles():
    rnd = random.Random(5)
    s = Svg(96, 16)
    specs = [
        ("#5c9a45", ["#4f8a3b", "#6aa84f"], 10),
        ("#5b9845", ["#5fa049", "#559040"], 12),
        ("#2f5d8a", ["#3a70a3"], 0),
        ("#416f3b", ["#335c32", "#527d43"], 14),
        ("#74796e", ["#62675f", "#8a8e82"], 13),
        ("#6b7547", ["#58633e", "#829052"], 14),
    ]
    for i, (base, specks, n) in enumerate(specs):
        ox = i * 16
        s.rect(ox, 0, 16, 16, base)
        for _ in range(n):
            s.rect(ox + rnd.randint(0, 15), rnd.randint(0, 15), 1, 1, rnd.choice(specks))
        if i == 1:  # rumput alt: sedikit helai
            for _ in range(3):
                x, y = ox + rnd.randint(1, 14), rnd.randint(2, 13)
                s.rect(x, y, 1, 2, "#6fae52")
        elif i == 3:  # lantai hutan: lumut kecil
            for x, y in [(2, 4), (10, 12), (13, 6)]:
                s.rect(ox + x, y, 2, 1, "#659050")
        elif i == 4:  # dataran tinggi: serpihan batu
            for x, y in [(3, 5), (10, 10), (13, 3)]:
                s.rect(ox + x, y, 2, 1, "#a3a8a0")
        elif i == 5:  # rawa: rumpun alang-alang
            for x, y in [(4, 7), (11, 12), (13, 4)]:
                s.rect(ox + x, y, 1, 3, "#a0a36b")
    for x, y, w in [(35, 3, 5), (42, 7, 4), (34, 11, 5), (40, 14, 4), (37, 6, 3)]:  # ombak air
        s.rect(x, y, w, 1, "#3f7bb0")
    s.rect(44, 2, 1, 1, "#9cc7e8").rect(36, 9, 1, 1, "#9cc7e8")
    s.save("tiles")

# ---------------------------------------------------------------- bangunan

def make_buildings():
    # dinding: palisade kayu, 16x16
    w = Svg(16, 16)
    for i in range(4):
        x = i * 4
        top = 2 if i % 2 else 3
        w.rect(x, top, 4, 16 - top, WOOD).rect(x, top, 1, 16 - top, WOOD_L).rect(x + 3, top, 1, 16 - top, "#6b4f2f")
        w.rect(x + 1, top - 1, 2, 1, WOOD_L)
    w.rect(0, 6, 16, 1, "#4a3520").rect(0, 12, 16, 1, "#4a3520")
    w.save("wall")

    # rumah 36x38
    h = Svg(36, 38)
    h.rect(26, 3, 4, 10, STONE_D).rect(25, 2, 6, 1, STONE_L)
    h.tri(18, 1, 17, 17, "#9b3d2e", line="#7f2f23")
    h.rect(0, 18, 36, 2, "#7a2f23")
    h.rect(2, 20, 32, 18, "#b08a5a").rect(2, 20, 32, 1, WOOD_D).rect(2, 20, 2, 18, WOOD_D).rect(32, 20, 2, 18, WOOD_D)
    h.rect(2, 36, 32, 2, STONE_D)
    h.rect(15, 28, 6, 8, "#5a3b22").rect(19, 33, 1, 1, GOLD)
    for wx in (6, 25):
        h.rect(wx, 25, 5, 5, "#f2d98a").rect(wx, 25, 5, 1, WOOD_D).rect(wx, 29, 5, 1, WOOD_D).rect(wx + 2, 25, 1, 5, WOOD_D)
    h.save("house")

    # menara 32x50
    t = Svg(32, 50)
    t.rect(3, 6, 26, 44, STONE).rect(3, 6, 2, 44, STONE_L).rect(27, 6, 2, 44, STONE_D)
    for k, y in enumerate(range(10, 46, 4)):
        t.rect(5, y, 22, 1, "#767b83")
        for x in range(5 + (k % 2) * 4, 27, 8):
            t.rect(x, y + 1, 1, 3, "#767b83")
    t.rect(1, 6, 30, 2, STONE_D)
    for x in (3, 10, 17, 24):
        t.rect(x, 0, 5, 6, STONE).rect(x, 0, 5, 1, STONE_L)
    t.rect(15, 16, 2, 8, "#23262b").rect(15, 30, 2, 6, "#23262b")
    t.rect(11, 38, 10, 12, "#2b2118").rect(12, 37, 8, 1, "#2b2118").rect(13, 36, 6, 1, "#2b2118").rect(15, 38, 1, 12, "#4a3520")
    t.rect(3, 46, 26, 4, STONE_D).rect(11, 46, 10, 4, "#2b2118")
    t.save("tower")

    # gudang 50x28
    g = Svg(50, 28)
    g.rect(0, 3, 50, 6, "#6a4a2a").rect(0, 3, 50, 1, "#8a6a3a").rect(0, 8, 50, 1, "#4a3520")
    g.rect(1, 9, 48, 19, "#9c7a4a")
    for x in range(7, 49, 6):
        g.rect(x, 9, 1, 19, "#7d5f37")
    g.rect(1, 26, 48, 2, "#6a4a2a")
    g.rect(18, 13, 14, 15, "#5a3b22")
    for i in range(14):
        g.rect(18 + i, 13 + round(i * 14 / 13), 1, 2, "#7d5f37").rect(31 - i, 13 + round(i * 14 / 13), 1, 2, "#7d5f37")
    g.rect(4, 19, 9, 9, "#b08a5a").rect(4, 19, 9, 1, WOOD_D).rect(4, 27, 9, 1, WOOD_D).rect(4, 19, 1, 9, WOOD_D).rect(12, 19, 1, 9, WOOD_D)
    g.blob(40, 24, 4, 4, "#d9c9a3").blob(45, 25, 3, 3, "#c9b98a").rect(39, 20, 2, 1, "#a89a6a")
    g.save("storage")

    # ladang 48x32
    f = Svg(48, 32)
    f.rect(0, 0, 48, 32, WOOD_D)
    rnd = random.Random(3)
    for i in range(4):
        y = 3 + i * 7
        f.rect(2, y, 44, 4, "#4f7a2e").rect(2, y, 44, 1, "#6a9a3d")
        for x in range(3, 45, 4):
            f.rect(x, y - 1, 2, 2, "#7fb84a")
            if rnd.random() < 0.6:
                f.rect(x + 1, y + 1, 1, 2, GOLD)
    f.rect(0, 0, 48, 1, "#8a6338").rect(0, 31, 48, 1, "#8a6338").rect(0, 0, 1, 32, "#8a6338").rect(47, 0, 1, 32, "#8a6338")
    for x, y in ((0, 0), (46, 0), (0, 29), (46, 29)):
        f.rect(x, y, 2, 3, "#553a22")
    f.save("farm")

    # keep 56x62
    k = Svg(56, 62)
    k.rect(27, 2, 1, 16, "#4a3a2a")
    for r, wd in enumerate([9, 8, 6, 5, 3, 1]):
        k.rect(28, 2 + r, wd, 1, "#e05a4b" if r == 0 else RED)
    # badan utama
    k.rect(13, 21, 30, 41, "#9a9fa8").rect(13, 21, 30, 1, "#b5bac2")
    for x in range(14, 43, 5):
        k.rect(x, 17, 4, 4, "#9a9fa8").rect(x, 17, 4, 1, "#b5bac2")
    for j, y in enumerate(range(25, 60, 5)):
        k.rect(13, y, 30, 1, "#868b94")
        for x in range(13 + (j % 2) * 5, 43, 10):
            k.rect(x, y + 1, 1, 4, "#868b94")
    # menara sudut
    for tx in (1, 43):
        k.rect(tx, 10, 12, 52, "#7d828b").rect(tx, 10, 2, 52, STONE_L).rect(tx + 10, 10, 2, 52, STONE_D)
        for mx in (tx, tx + 5, tx + 9):
            k.rect(mx, 6, 3, 4, "#7d828b").rect(mx, 6, 3, 1, STONE_L)
        k.rect(tx + 5, 26, 2, 6, "#23262b").rect(tx + 5, 40, 2, 6, "#23262b")
        k.rect(tx - 1, 10, 14, 1, STONE_D)
    # gerbang
    k.rect(22, 46, 12, 16, "#2b2118").rect(23, 44, 10, 2, "#2b2118").rect(24, 43, 8, 1, "#2b2118")
    k.rect(26, 44, 1, 18, "#4a3520").rect(29, 44, 1, 18, "#4a3520").rect(22, 52, 12, 1, "#4a3520")
    k.rect(26, 32, 4, 9, RED).rect(26, 32, 4, 1, GOLD).rect(27, 41, 2, 1, RED)
    k.rect(1, 58, 54, 4, STONE_D).rect(22, 58, 12, 4, "#2b2118")
    k.save("keep")

    # anak panah 8x3
    a = Svg(8, 3)
    a.rect(0, 1, 6, 1, "#d9c9a3").rect(0, 0, 1, 3, RED).rect(6, 0, 1, 3, "#e8e8e8").rect(7, 1, 1, 1, "#e8e8e8")
    a.save("arrow")


# ---------------------------------------------------------------- ikon HUD (10x10)

def make_icons():
    i = Svg(10, 10)  # kayu
    i.rect(1, 6, 8, 3, WOOD_D).rect(1, 6, 2, 3, "#a77a45").rect(2, 3, 7, 3, WOOD).rect(2, 3, 2, 3, "#c9a06a")
    i.rect(0, 1, 7, 2, "#a77a45").rect(0, 1, 2, 2, "#d9b078")
    i.save("icon_wood")

    i = Svg(10, 10)  # batu
    i.blob(5, 6, 4.5, 3.5, "#8d9298").blob(4, 5, 2.5, 2, "#aeb3b9").rect(6, 7, 3, 1, "#6f747a")
    i.save("icon_stone")

    i = Svg(10, 10)  # makanan (roti)
    i.blob(5, 6, 4.5, 3, "#d9a441").rect(2, 5, 3, 1, "#f0c46a").rect(4, 6, 1, 2, "#b8802c").rect(6, 6, 1, 2, "#b8802c")
    i.save("icon_food")

    i = Svg(10, 10)  # hati
    i.pix([".###.###.", "#hh######", "#########", "#########", ".#######.", "..#####..", "...###...", "....#...."],
          {"#": "#d63a3a", "h": "#ff8a8a"}, ox=0, oy=1)
    i.save("icon_heart")

    i = Svg(10, 10)  # keep
    i.rect(5, 0, 1, 3, "#4a3a2a").rect(6, 0, 3, 1, RED)
    i.rect(1, 3, 2, 2, "#9a9fa8").rect(4, 3, 2, 2, "#9a9fa8").rect(7, 3, 2, 2, "#9a9fa8")
    i.rect(1, 5, 8, 5, "#9a9fa8").rect(4, 7, 2, 3, "#2b2118").rect(1, 5, 8, 1, "#b5bac2")
    i.save("icon_keep")

    i = Svg(10, 10)  # penduduk
    i.rect(2, 1, 3, 3, SKIN).rect(1, 4, 5, 5, "#3f6fb5").rect(6, 3, 3, 3, SKIN).rect(5, 6, 5, 4, "#4e9a4a")
    i.save("icon_people")


def make_hud_icons():
    # ikon status 10x10
    i = Svg(10, 10)  # matahari
    i.blob(5, 5, 2.5, 2.5, "#f2c230").rect(4, 0, 2, 2, "#f2c230").rect(4, 8, 2, 2, "#f2c230")
    i.rect(0, 4, 2, 2, "#f2c230").rect(8, 4, 2, 2, "#f2c230")
    for x, y in ((1, 1), (8, 1), (1, 8), (8, 8)):
        i.rect(x, y, 1, 1, "#f2c230")
    i.save("icon_sun")

    i = Svg(10, 10)  # bulan sabit
    i.pix(["...####...", "..###.....", ".###......", ".###......", ".###......", ".###......",
           ".####.....", "..#####...", "...####..."], {"#": "#cfd6e2"}, oy=0)
    i.rect(1, 3, 1, 3, "#9aa3b2")
    i.save("icon_moon")

    i = Svg(10, 10)  # tengkorak (musuh)
    i.pix(["..######..", ".########.", "##########", "##oo##oo##", "##oo##oo##", ".########.",
           "..#.##.#..", "..######.."], {"#": "#e8e2d0", "o": "#2a1f17"}, oy=1)
    i.save("icon_skull")

    i = Svg(10, 10)  # kapak
    i.rect(5, 2, 1, 8, WOOD_D).rect(2, 1, 4, 3, STEEL_L).rect(2, 2, 1, 1, STEEL).rect(2, 3, 4, 1, STEEL)
    i.save("icon_axe")

    i = Svg(10, 10)  # beliung
    i.rect(5, 3, 1, 7, WOOD_D).rect(1, 2, 8, 1, "#aeb3b9").rect(1, 3, 1, 1, "#aeb3b9").rect(8, 3, 1, 1, "#aeb3b9")
    i.rect(2, 1, 6, 1, "#cfd6e2")
    i.save("icon_pick")

    i = Svg(10, 10)  # gandum
    i.rect(5, 4, 1, 6, "#8a6a2a").rect(4, 0, 2, 2, GOLD).rect(3, 2, 2, 2, GOLD).rect(6, 2, 2, 2, GOLD).rect(4, 4, 1, 1, GOLD).rect(6, 4, 1, 1, GOLD)
    i.save("icon_wheat")

    i = Svg(10, 10)  # pedang
    i.rect(5, 0, 1, 7, "#e8e8e8").rect(3, 7, 5, 1, GOLD).rect(5, 8, 1, 2, WOOD_D).rect(4, 1, 1, 5, "#cfd6e2")
    i.save("icon_sword")

    # ikon bangunan 16x16 untuk bar bangun
    i = Svg(16, 16)
    i.tri(8, 1, 7, 7, "#9b3d2e", line="#7f2f23").rect(1, 8, 14, 1, "#7a2f23")
    i.rect(3, 9, 10, 7, "#b08a5a").rect(7, 12, 3, 4, "#5a3b22").rect(4, 10, 2, 2, "#f2d98a").rect(11, 10, 1, 2, "#f2d98a")
    i.save("icon_house")

    i = Svg(16, 16)
    for k in range(3):
        x = 1 + k * 5
        top = 3 if k % 2 == 0 else 2
        i.rect(x, top, 4, 16 - top, WOOD).rect(x, top, 1, 16 - top, WOOD_L).rect(x + 3, top, 1, 16 - top, "#6b4f2f")
    i.rect(0, 6, 16, 1, "#4a3520").rect(0, 11, 16, 1, "#4a3520")
    i.save("icon_wall")

    i = Svg(16, 16)
    i.rect(4, 4, 8, 12, STONE).rect(4, 4, 2, 12, STONE_L).rect(10, 4, 2, 12, STONE_D)
    for x in (4, 7, 10):
        i.rect(x, 1, 2, 3, STONE).rect(x, 1, 2, 1, STONE_L)
    i.rect(7, 6, 2, 3, "#23262b").rect(6, 12, 4, 4, "#2b2118").rect(7, 11, 2, 1, "#2b2118")
    i.save("icon_tower")

    i = Svg(16, 16)
    i.rect(0, 3, 16, 3, "#6a4a2a").rect(0, 3, 16, 1, "#8a6a3a")
    i.rect(1, 6, 14, 10, "#9c7a4a").rect(5, 8, 6, 8, "#5a3b22").rect(5, 8, 6, 1, "#7d5f37").rect(7, 8, 1, 8, "#7d5f37")
    i.save("icon_storage")

    i = Svg(16, 16)
    i.rect(0, 2, 16, 13, WOOD_D)
    for y in (4, 9):
        i.rect(2, y, 12, 3, "#4f7a2e").rect(2, y, 12, 1, "#6a9a3d")
        for x in (3, 7, 11):
            i.rect(x, y + 1, 1, 2, GOLD)
    i.rect(0, 2, 16, 1, "#8a6338").rect(0, 14, 16, 1, "#8a6338")
    i.save("icon_farm")


def make_tech_assets():
    # bijih besi 16x12 (node dunia)
    r = Svg(16, 12)
    r.rect(1, 10, 14, 2, "#000000", 0.25)
    r.blob(8, 7, 7, 5, "#5f646a").blob(6, 6, 4, 3, "#7d828b").rect(10, 8, 4, 2, "#464a50")
    for x, y, c in ((4, 5, "#c97b3a"), (9, 4, "#e8a050"), (11, 7, "#c97b3a"), (6, 8, "#e8a050"), (8, 6, "#c97b3a"), (3, 7, "#e8a050")):
        r.rect(x, y, 2, 1, c)
    r.save("iron_ore")

    # tembok batu 16x16
    w = Svg(16, 16)
    w.rect(0, 2, 16, 14, STONE).rect(0, 2, 16, 2, STONE_L)
    for x in (0, 6, 12):
        w.rect(x, 0, 4, 2, STONE).rect(x, 0, 4, 1, STONE_L)
    for k, y in enumerate((7, 12)):
        w.rect(0, y, 16, 1, "#767b83")
        for x in range(3 + k * 4, 16, 8):
            w.rect(x, y - 4, 1, 4, "#767b83")
    w.rect(0, 15, 16, 1, STONE_D)
    w.save("stone_wall")

    # tempa 34x38
    f = Svg(34, 38)
    f.rect(24, 2, 6, 16, STONE_D).rect(23, 1, 8, 2, STONE_L).rect(26, 3, 2, 14, "#5f646a")
    f.tri(17, 8, 11, 17, "#4a4f58", line="#3a3e46")
    f.rect(0, 18, 34, 2, "#3a3e46")
    f.rect(1, 20, 32, 18, STONE).rect(1, 20, 2, 18, STONE_L).rect(31, 20, 2, 18, STONE_D)
    for k, y in enumerate((24, 29)):
        f.rect(3, y, 28, 1, "#767b83")
    f.rect(1, 35, 32, 3, STONE_D)
    f.rect(11, 25, 12, 13, "#2b2118").rect(12, 24, 10, 1, "#2b2118")
    f.rect(13, 29, 8, 9, "#e8803a").rect(15, 32, 4, 6, "#ffd23f").rect(16, 34, 2, 3, "#fff3b0")
    f.rect(25, 33, 7, 2, "#3a3e46").rect(26, 31, 5, 2, "#5a5f68")
    f.rect(4, 23, 4, 4, "#f2d98a").rect(4, 23, 4, 1, WOOD_D).rect(6, 23, 1, 4, WOOD_D)
    f.save("forge")

    # ikon HUD
    i = Svg(10, 10)  # batang besi
    i.rect(1, 6, 8, 3, "#9aa3b2").rect(1, 6, 8, 1, "#cfd6e2").rect(1, 8, 8, 1, "#6e737b")
    i.rect(2, 3, 6, 3, "#aab2c0").rect(2, 3, 6, 1, "#dfe5ee").rect(2, 5, 6, 1, "#7d8594")
    i.save("icon_iron")
    i = Svg(10, 10)  # gulungan riset
    i.rect(2, 1, 6, 8, "#e8dcb8").rect(1, 0, 8, 2, "#c9a227").rect(1, 8, 8, 2, "#c9a227")
    i.rect(3, 3, 4, 1, "#8a6a2a").rect(3, 5, 4, 1, "#8a6a2a").rect(3, 7, 3, 1, "#8a6a2a")
    i.save("icon_tech")
    # ikon bar bangun 16x16
    i = Svg(16, 16)
    i.rect(0, 2, 16, 14, STONE).rect(0, 2, 16, 2, STONE_L)
    for x in (0, 6, 12):
        i.rect(x, 0, 4, 2, STONE)
    i.rect(0, 8, 16, 1, "#767b83").rect(0, 12, 16, 1, "#767b83").rect(5, 4, 1, 4, "#767b83").rect(11, 9, 1, 3, "#767b83")
    i.save("icon_stone_wall")
    i = Svg(16, 16)
    i.rect(10, 0, 3, 6, STONE_D).tri(8, 3, 5, 8, "#4a4f58")
    i.rect(1, 8, 14, 8, STONE).rect(1, 8, 14, 1, STONE_L)
    i.rect(5, 10, 6, 6, "#2b2118").rect(6, 12, 4, 4, "#e8803a").rect(7, 13, 2, 3, "#ffd23f")
    i.save("icon_forge")


if __name__ == "__main__":
    make_characters()
    make_role_variants()
    make_nature()
    make_tiles()
    make_buildings()
    make_icons()
    make_hud_icons()
    make_tech_assets()
    print("Selesai ->", OUT, "(%d file)" % len([n for n in os.listdir(OUT) if n.endswith(".svg")]))
