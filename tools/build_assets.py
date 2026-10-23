#!/usr/bin/env python3
"""Generate graphics and data tables for the Bikini Atoll SNES ROM.

Writes binary files and gen.inc (constants for ca65) into the build dir.
"""
import math
import os
import random
import struct
import sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "build"
os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------- constants
HOR = 72            # virtual horizon scanline
M7_START = 80       # first Mode 7 scanline
M7_LINES = 120      # Mode 7 scanlines (80..199)
FOCAL = 128
# Altitude: the plane flies CAM_UP (9) units below the camera, 800 ft per unit.
# Camera heights step ~8% apart from just above the waves to 60,000 ft; the
# game snaps to the step nearest the plane's altitude in feet.
FT_PER_UNIT = 800
CAM_ALTS = []
_h = 10.0
while _h < 82:
    if not CAM_ALTS or round(_h) != CAM_ALTS[-1]:
        CAM_ALTS.append(round(_h))
    _h *= 1.08
CAM_ALTS.append(84)              # (84 - 9) * 800 = 60,000 ft
NLVL = len(CAM_ALTS)
M7_P1_BANK = 4                   # Mode 7 tables follow the 4 code banks
M7_P2_BANK = M7_P1_BANK + 2 * NLVL
MAP = 1024
CELLS = 128

TARGET_X, TARGET_Y = 500, 540  # centre of the orange target ship
START_X, START_Y = 60, 120     # plane start position, out over the ocean
START_HEADING = 0x58           # roughly south-east (0 = north, 64 = east)

inc = []


def const(name, val):
    inc.append(f"{name} = {val}")


def write(name, data):
    with open(os.path.join(OUT, name), "wb") as f:
        f.write(bytes(data))


def snes_color(rgb):
    r, g, b = (min(255, max(0, int(v))) >> 3 for v in rgb)
    return r | (g << 5) | (b << 10)


# ---------------------------------------------------------------- noise
def h2(x, y, s=0):
    n = (x * 374761393 + y * 668265263 + s * 2246822519) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFFFFFF) / 4294967296.0


def vnoise(x, y, s):
    xi, yi = math.floor(x), math.floor(y)
    xf, yf = x - xi, y - yi
    u, v = xf * xf * (3 - 2 * xf), yf * yf * (3 - 2 * yf)
    a, b = h2(xi, yi, s), h2(xi + 1, yi, s)
    c, d = h2(xi, yi + 1, s), h2(xi + 1, yi + 1, s)
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v


def fbm(x, y, s, octaves=4):
    t, amp, f, norm = 0.0, 0.5, 1.0, 0.0
    for i in range(octaves):
        t += amp * vnoise(x * f, y * f, s + i * 17)
        norm += amp
        amp *= 0.5
        f *= 2
    return t / norm


# ---------------------------------------------------------------- colours
COLORS = {
    "ocean": (24, 52, 120), "ocean2": (30, 62, 136), "wave": (96, 140, 200),
    "lagoon": (38, 136, 168), "lagoon2": (50, 152, 180), "reef": (118, 198, 196),
    "sand": (222, 208, 156), "sand2": (200, 186, 134),
    "grass": (96, 160, 70), "palm": (38, 108, 48), "palm2": (62, 140, 60),
    "hull": (112, 116, 124), "hulld": (66, 68, 76), "deck": (156, 154, 146),
    "orange": (236, 112, 40), "orange2": (196, 84, 30), "white": (232, 232, 226),
}

# ---------------------------------------------------------------- atoll
ATOLL_X, ATOLL_Y, ATOLL_RX, ATOLL_RY = 520, 500, 340, 270


def atoll_r(x, y):
    return math.hypot((x - ATOLL_X) / ATOLL_RX, (y - ATOLL_Y) / ATOLL_RY)


def land_at(x, y):
    """Value > 0 means land: islets strung along the reef ring."""
    r = atoll_r(x, y)
    ang = math.atan2((y - ATOLL_Y) / ATOLL_RY, (x - ATOLL_X) / ATOLL_RX)
    band = 1 - abs(r - 1) * ATOLL_RX / 13
    islets = fbm(math.cos(ang) * 6 + 7, math.sin(ang) * 6 + 7, 3, 3)
    band += (islets - 0.56) * 5 + 0.3 * (fbm(x / 30, y / 30, 4) - 0.5)
    # the larger island on the north-east rim
    big = 1 - math.hypot((x - 790) / 70, (y - 330) / 34)
    return max(band, big + 0.3 * (fbm(x / 40, y / 40, 5) - 0.5))


corner = [[land_at(cx * 8, cy * 8) > 0 for cx in range(CELLS + 1)]
          for cy in range(CELLS + 1)]


# ---------------------------------------------------------------- tile art
def pick(names, x, y, s):
    return names[int(h2(x, y, s) * len(names)) % len(names)]


def water(inner, x, y, v):
    if inner:
        return pick(["lagoon", "lagoon", "lagoon2"], x, y, 70 + v)
    if h2(x, y, 90 + v) < 0.03:
        return "wave"
    return pick(["ocean", "ocean", "ocean2"], x, y, 80 + v)


def tile_water(inner, v):
    return [[water(inner, x, y, v) for x in range(8)] for y in range(8)]


def tile_reef(inner, v):
    return [[("reef" if h2(x, y, 200 + v) < 0.45 else water(inner, x, y, v))
             for x in range(8)] for y in range(8)]


def tile_edge(tl, tr, bl, br, inner, v):
    rows = []
    for y in range(8):
        row = []
        for x in range(8):
            u, w_ = (x + 0.5) / 8, (y + 0.5) / 8
            w = (tl * (1 - u) * (1 - w_) + tr * u * (1 - w_) +
                 bl * (1 - u) * w_ + br * u * w_)
            w += (h2(x, y, 300 + v) - 0.5) * 0.12
            if w > 0.62:
                row.append(water(inner, x, y, v))
            elif w > 0.48:
                row.append("reef")
            elif w > 0.32:
                row.append(pick(["sand", "sand2"], x, y, 310 + v))
            else:
                row.append(pick(["grass", "sand", "palm2"], x, y, 320 + v))
        rows.append(row)
    return rows


def tile_islet(v):
    rows = []
    for y in range(8):
        row = []
        for x in range(8):
            r = h2(x, y, 400 + v)
            row.append("palm" if r < 0.3 else "palm2" if r < 0.5 else
                       "grass" if r < 0.85 else "sand")
        rows.append(row)
    return rows


def tile_ship(part, target, v):
    """Part of a ship lying east-west: 'bow' (west end), 'mid' or 'stern'."""
    hull, hulld = ("orange", "orange2") if target else ("hull", "hulld")
    rows = tile_water(True, v)
    for y in range(2, 6):
        for x in range(8):
            if part == "bow" and x < (abs(y - 3.5) * 2.5):
                continue
            if part == "stern" and x > 6:
                continue
            if y in (2, 5):
                rows[y][x] = hulld
            elif target and part == "mid" and x in (2, 5):
                rows[y][x] = "white"
            elif part == "mid" and 2 <= x <= 5 and v % 2:
                rows[y][x] = hulld
            else:
                rows[y][x] = "deck" if not target else hull
    return rows


# ---------------------------------------------------------------- build map
tiles = []        # list of 8x8 name grids
tile_index = {}


def add_tile(t):
    key = tuple(tuple(r) for r in t)
    if key not in tile_index:
        tile_index[key] = len(tiles)
        tiles.append(t)
    return tile_index[key]


add_tile(tile_water(False, 0))     # tile 0: open ocean (outside-map fill)

# The target fleet: ships anchored in the lagoon around the target ship.
ships = {}          # (cx, cy) -> tile grid
fleet_rng = random.Random(46)
TGT_CX, TGT_CY = TARGET_X // 8, TARGET_Y // 8


def place_ship(cx, cy, length, target):
    cells = [(cx + i, cy) for i in range(length)]
    if any(c in ships or (c[0], c[1] - 1) in ships or (c[0], c[1] + 1) in ships
           for c in cells):
        return False
    if any(atoll_r(c[0] * 8 + 4, c[1] * 8 + 4) > 0.8 for c in cells):
        return False
    v = fleet_rng.randrange(2)
    for i, c in enumerate(cells):
        part = "bow" if i == 0 else "stern" if i == length - 1 else "mid"
        ships[c] = tile_ship(part, target, v)
    return True


place_ship(TGT_CX - 2, TGT_CY, 5, True)
placed = 0
while placed < 22:
    ang = fleet_rng.uniform(0, 2 * math.pi)
    dist = fleet_rng.uniform(5, 26)
    cx = int(TGT_CX + math.cos(ang) * dist)
    cy = int(TGT_CY + math.sin(ang) * dist * 0.8)
    if place_ship(cx, cy, fleet_rng.choice([3, 4, 4, 5]), False):
        placed += 1

tilemap = [0] * (CELLS * CELLS)
for cy in range(CELLS):
    for cx in range(CELLS):
        tl, tr = corner[cy][cx], corner[cy][cx + 1]
        bl, br = corner[cy + 1][cx], corner[cy + 1][cx + 1]
        inner = atoll_r(cx * 8 + 4, cy * 8 + 4) < 1
        v = int(h2(cx, cy, 1) * 4)
        if (cx, cy) in ships:
            t = ships[(cx, cy)]
        elif not (tl or tr or bl or br):
            near_reef = abs(atoll_r(cx * 8 + 4, cy * 8 + 4) - 1) * ATOLL_RX < 9
            t = tile_reef(inner, v % 2) if near_reef else tile_water(inner, v % 3)
        elif not (tl and tr and bl and br):
            t = tile_edge(tl, tr, bl, br, inner, v % 2)
        else:
            t = tile_islet(v)
        tilemap[cy * CELLS + cx] = add_tile(t)

assert len(tiles) <= 256, len(tiles)

names = sorted({n for t in tiles for r in t for n in r})
assert len(names) <= 96, len(names)
pal_index = {n: 32 + i for i, n in enumerate(names)}

# Mode 7 VRAM: low bytes = tilemap, high bytes = 8bpp tile pixels.
vram = bytearray(32768)
for i in range(CELLS * CELLS):
    vram[i * 2] = tilemap[i]
for t, grid in enumerate(tiles):
    for y in range(8):
        for x in range(8):
            vram[(t * 64 + y * 8 + x) * 2 + 1] = pal_index[grid[y][x]]
write("m7vram.bin", vram)

map_pal = bytearray(192)
for n, i in pal_index.items():
    struct.pack_into("<H", map_pal, (i - 32) * 2, snes_color(COLORS[n]))
write("mappal.bin", map_pal)

# Preview of the whole map, for checking the layout by eye.
try:
    from PIL import Image
    img = Image.new("RGB", (MAP, MAP))
    px = img.load()
    for cy in range(CELLS):
        for cx in range(CELLS):
            grid = tiles[tilemap[cy * CELLS + cx]]
            for y in range(8):
                for x in range(8):
                    px[cx * 8 + x, cy * 8 + y] = COLORS[grid[y][x]]
    img.save(os.path.join(OUT, "map_preview.png"))
except ImportError:
    pass

# ---------------------------------------------------------------- Mode 7 HDMA
# Per scanline (dy = line - HOR):
#   A = cos(h)*alt/dy          C = sin(h)*alt/dy
#   B = sin(h)*alt*f/dy^2      D = -cos(h)*alt*f/dy^2
# Stored as two families (P1 = cos*alt/dy, P2 = cos*alt*f/dy^2) indexed by
# angle, so B/C/D are P tables at shifted angles. Each table is one HDMA
# table padded to 256 bytes; two banks (256 angles) per altitude level,
# P1 for all levels from M7_P1_BANK, then P2 from M7_P2_BANK.
m7 = bytearray(4 * NLVL * 32768)
for fam in range(2):
    for lvl, alt in enumerate(CAM_ALTS):
        for a in range(256):
            c = math.cos(2 * math.pi * a / 256)
            tbl = bytearray([M7_START, 0, 0, 0x80 | M7_LINES])
            for line in range(M7_START, M7_START + M7_LINES):
                dy = line - HOR
                s = alt / dy if fam == 0 else alt * FOCAL / (dy * dy)
                val = max(-32768, min(32767, round(256 * c * s)))
                tbl += struct.pack("<h", val)
            tbl.append(0)
            bank = fam * 2 * NLVL + lvl * 2 + (a >> 7)
            off = bank * 32768 + (a & 127) * 256
            m7[off:off + len(tbl)] = tbl
write("m7tables.bin", m7)

# ---------------------------------------------------------------- sky HDMA
# Mode 3 to CGADD: writes 0,0 then colour 0 low/high each line.
SKY_TOP, SKY_HOR = (40, 80, 168), (176, 206, 236)
TINT_TOP, TINT_HOR = (56, 20, 72), (255, 124, 52)
HUD_BG = (12, 12, 28)
sky = bytearray()
for lvl in range(16):
    t = lvl / 15
    top = [SKY_TOP[i] + (TINT_TOP[i] - SKY_TOP[i]) * t for i in range(3)]
    hor = [SKY_HOR[i] + (TINT_HOR[i] - SKY_HOR[i]) * t for i in range(3)]
    tbl = bytearray([0x80 | M7_START])
    for line in range(M7_START):
        k = min(1.0, line / HOR) ** 1.6
        col = [top[i] + (hor[i] - top[i]) * k for i in range(3)]
        tbl += bytes([0, 0]) + struct.pack("<H", snes_color(col))
    tbl += bytes([M7_LINES, 0, 0]) + struct.pack("<H", 0)
    tbl += bytes([24, 0, 0]) + struct.pack("<H", snes_color(HUD_BG))
    tbl.append(0)
    tbl += bytes(336 - len(tbl))
    sky += tbl
write("sky.bin", sky)
const("SKY_TBL_SIZE", 336)

# ---------------------------------------------------------------- step 2: HUD, font, sprites
import gzip
from PIL import Image, ImageDraw

FONT_OFS = 30       # BG3 tile = ascii - 30 (tiles 0 and 1 stay blank)
HUD_PRIO = 0x2000


def bg3_tile(rows):
    """8 rows of 8 colour indexes (0-3) -> 16 bytes of 2bpp."""
    out = bytearray()
    for r in rows:
        p0 = p1 = 0
        for x, c in enumerate(r):
            p0 |= (c & 1) << (7 - x)
            p1 |= ((c >> 1) & 1) << (7 - x)
        out += bytes([p0, p1])
    return out


psf = gzip.open("/usr/share/consolefonts/Lat15-VGA8.psf.gz").read()
font_tiles = bytearray(32)                       # tiles 0, 1 blank
for ch in range(32, 128):
    g = psf[4 + ch * 8: 4 + ch * 8 + 8]
    on = [[(g[y] >> (7 - x)) & 1 for x in range(8)] for y in range(8)]
    rows = []
    for y in range(8):
        row = []
        for x in range(8):
            if on[y][x]:
                row.append(1)
            elif x > 0 and y > 0 and on[y - 1][x - 1]:
                row.append(3)                    # drop shadow
            else:
                row.append(0)
        rows.append(row)
    font_tiles += bg3_tile(rows)
# '{' and '}' are redrawn as up / down arrows for the climb indicator.
for ch, rows in (("{", ["...1....", "..111...", ".11111..", "1111111.", "...1....", "...1....", "...1....", "........"]),
                 ("}", ["...1....", "...1....", "...1....", "1111111.", ".11111..", "..111...", "...1....", "........"])):
    t = (ord(ch) - FONT_OFS) * 16
    font_tiles[t:t + 16] = bg3_tile([[1 if c == "1" else 0 for c in r] for r in rows])
write("font.bin", font_tiles)


def text_entry(ch, pal):
    return (ord(ch) - FONT_OFS) | (pal << 10) | HUD_PRIO


def new_map():
    return [0] * 1024


def put(m, row, col, text, pal=0):
    for i, ch in enumerate(text):
        m[row * 32 + col + i] = text_entry(ch, pal)


def put_center(m, row, text, pal=0):
    put(m, row, (32 - len(text)) // 2, text, pal)


def map_bytes(m):
    return b"".join(struct.pack("<H", v) for v in m)


# BG3 palettes: 0 white, 1 yellow, 2 red, 3 green, 4 orange, 5 grey, 6 cyan, 7 blink
SHADOW = (8, 8, 16)
BG3_COLS = [(248, 248, 248), (248, 216, 64), (248, 64, 48), (96, 232, 112),
            (248, 136, 48), (168, 172, 184), (120, 220, 240), (248, 216, 64)]
cgram = bytearray(512)
for p, c in enumerate(BG3_COLS):
    struct.pack_into("<HHHH", cgram, p * 8, 0, snes_color(c), snes_color(c),
                     snes_color(SHADOW))
cgram[64:64 + 192] = map_pal

# HUD map: static labels; the game fills in the numbers.
hud = new_map()
put(hud, 0, 16, "V", 1)
put(hud, 25, 1, "ALT", 5)
put(hud, 25, 10, "FT", 5)
put(hud, 25, 14, "SPD", 5)
put(hud, 25, 21, "MPH", 5)
put(hud, 25, 26, "ARMED", 3)
put(hud, 26, 1, "HDG", 5)
put(hud, 26, 10, "TGT", 5)
put(hud, 26, 18, "MI", 5)
put(hud, 26, 22, "BAY:", 5)
put(hud, 26, 26, "SHUT", 0)
put(hud, 27, 1, "SIGHT:", 5)
put(hud, 27, 21, "?:CONTROLS", 5)
write("hudmap.bin", map_bytes(hud))

legend = new_map()
put_center(legend, 1, "FLIGHT CONTROLS", 1)
put(legend, 3, 1, "KEY", 5)
put(legend, 3, 10, "SNES", 5)
put(legend, 3, 19, "ACTION", 5)
rows = [("ARROWS", "D-PAD", "STEER/CLIMB"), ("X", "B", "BAY DOORS"),
        ("Z", "A", "DROP BOMB"), ("A", "X", "CAMERA"),
        ("Q / E", "L / R", "THROTTLE"), ("ENTER", "START", "PAUSE"),
        ("? OR V", "SELECT", "THIS HELP")]
for i, (k, s, a) in enumerate(rows):
    put(legend, 5 + i * 2, 1, k, 6)
    put(legend, 5 + i * 2, 10, s, 0)
    put(legend, 5 + i * 2, 19, a, 0)
put(legend, 20, 1, "LEFT/RIGHT BANKS THE PLANE.", 5)
put(legend, 21, 1, "UP/DOWN CLIMBS OR DESCENDS.", 5)
put(legend, 22, 1, "FOLLOW THE RED COMPASS MARK.", 5)
put(legend, 23, 1, "DROP WHEN THE SIGHT READS", 5)
put(legend, 24, 1, "OVER TARGET.", 5)
put_center(legend, 26, "PRESS ? OR START TO RESUME", 1)
write("legend.bin", map_bytes(legend))

# Compass tape characters for each 10-degree step.
tape = bytearray()
for a in range(36):
    if a % 9 == 0:
        tape += struct.pack("<H", text_entry("NESW"[a // 9], 1))
    elif a % 3 == 0:
        tape += struct.pack("<H", text_entry("|", 0))
    else:
        tape += struct.pack("<H", text_entry(".", 5))
write("tape.bin", tape)


# ---- sprites (4bpp, 128-pixel-wide sheets of 16 tiles per row)
def sheet_bytes(px, w, h):
    out = bytearray()
    for ty in range(h // 8):
        for tx in range(w // 8):
            for planes in ((0, 1), (2, 3)):
                for y in range(8):
                    for p in planes:
                        b = 0
                        for x in range(8):
                            b |= ((px[ty * 8 + y][tx * 8 + x] >> p) & 1) << (7 - x)
                        out.append(b)
    return out


PLANE_COLS = [(0, 0, 0), (32, 36, 44), (224, 228, 236), (172, 178, 190),
              (112, 118, 132), (56, 56, 64), (64, 96, 136), (200, 204, 210),
              (180, 210, 240)]


def draw_plane(angle):
    S = 4
    W, H = 96, 48
    img = Image.new("P", (W * S, H * S), 0)
    d = ImageDraw.Draw(img)

    def P(x, y):
        return ((48 + x) * S, (24 + y) * S)

    def ell(x, y, rx, ry, c):
        d.ellipse([P(x - rx, y - ry), P(x + rx, y + ry)], fill=c)

    for sx in (-1, 1):
        ell(13 * sx, 3, 7, 7, 7)
        ell(29 * sx, 2, 7, 7, 7)
    d.polygon([P(-47, -3), P(-8, 0), P(8, 0), P(47, -3), P(47, -1), P(8, 3),
               P(-8, 3), P(-47, -1)], fill=3)
    d.polygon([P(-47, -3), P(-8, 0), P(8, 0), P(47, -3), P(47, -2), P(8, 1),
               P(-8, 1), P(-47, -2)], fill=2)
    for sx in (-1, 1):
        ell(13 * sx, 3, 3.5, 4, 3)
        ell(13 * sx, 4.5, 3, 2.5, 4)
        ell(13 * sx, 4, 1.5, 1.5, 5)
        ell(29 * sx, 2, 3, 3.5, 3)
        ell(29 * sx, 3.5, 2.5, 2, 4)
        ell(29 * sx, 3, 1.2, 1.2, 5)
    d.polygon([P(-19, 5), P(19, 5), P(19, 7.5), P(-19, 7.5)], fill=3)
    d.polygon([P(-19, 5), P(19, 5), P(19, 6), P(-19, 6)], fill=2)
    ell(0, 3, 6.5, 6.5, 4)
    ell(0, 2.5, 6, 6, 3)
    ell(0, 1, 4, 4, 2)
    d.polygon([P(-1.5, 2), P(-1, -21), P(1, -21), P(1.5, 2)], fill=3)
    d.polygon([P(-1.5, 2), P(-1, -21), P(0, -21), P(0, 2)], fill=2)
    ell(0, 3.5, 2.5, 2.5, 6)
    ell(-1, 2.5, 0.8, 0.8, 8)
    img = img.rotate(angle, resample=Image.NEAREST, center=P(0, 2))
    src = img.load()
    px = [[src[x * S + S // 2, y * S + S // 2] for x in range(W)] for y in range(H)]
    for y in range(H):                           # see-through propeller discs
        for x in range(W):
            if px[y][x] == 7 and (x + y) % 2:
                px[y][x] = 0
    solid = [[c not in (0, 7) for c in r] for r in px]
    for y in range(H):                           # dark outline
        for x in range(W):
            if px[y][x] == 0 and any(
                    0 <= y + dy < H and 0 <= x + dx < W and solid[y + dy][x + dx]
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[y][x] = 1
    sheet = [[0] * 128 for _ in range(H)]
    for y in range(H):
        sheet[y][:W] = px[y]
    return sheet


plane = bytearray()
for ang in (16, 8, 0, -8, -16):                  # banked left ... banked right
    plane += sheet_bytes(draw_plane(ang), 128, 48)
write("plane.bin", plane)


def glyph(rows):
    return [[int(c, 16) if c != "." else 0 for c in r.ljust(16, ".")]
            for r in rows] + [[0] * 16] * (16 - len(rows))


SMALL = {
    0: glyph([  # reticle (colour 3 is swapped by palette)
        ".....555555.....",
        "....53333335....",
        "...535....535...",
        "..535......535..",
        ".535........535.",
        ".53....55....35.",
        ".53....33....35.",
        "553..53333..355.",
        ".53....33....35.",
        ".53....55....35.",
        ".535........535.",
        "..535......535..",
        "...535....535...",
        "....53333335....",
        ".....555555.....",
    ]),
    2: glyph([  # target marker, tip at the bottom centre
        "", "", "", "", "", "",
        "..55555555555...",
        "..51111111115...",
        "...511111115....",
        "....5111115.....",
        ".....51115......",
        "......515.......",
        ".......5........",
    ]),
    4: glyph([  # bomb, near
        ".......55.......",
        "......5665......",
        "......5665......",
        ".....566665.....",
        ".....566665.....",
        ".....566665.....",
        ".....567765.....",
        "......5775......",
        ".....577775.....",
        ".....5.55.5.....",
    ]),
    6: glyph([  # bomb, far
        "......555.......",
        "......565.......",
        "......575.......",
        "......555.......",
    ]),
    8: glyph([  # compass marker, tip at the top centre
        ".......5........",
        "......515.......",
        ".....51115......",
        "....5111115.....",
        "...511111115....",
        "...555555555....",
    ]),
}
small = [[0] * 128 for _ in range(16)]
for col, g in SMALL.items():
    for y in range(16):
        for x in range(16):
            small[y][col * 8 + x] = g[y][x]
write("small.bin", sheet_bytes(small, 128, 16))

MARK_COLS = [(0, 0, 0), (240, 40, 32), (248, 216, 64), (64, 232, 96),
             (248, 248, 248), (24, 20, 20), (150, 154, 140), (70, 72, 70)]
for i, c in enumerate(PLANE_COLS):
    struct.pack_into("<H", cgram, 256 + i * 2, snes_color(c))
for p, swap in ((1, None), (2, (248, 216, 64)), (3, (240, 40, 32))):
    for i, c in enumerate(MARK_COLS):
        if i == 3 and swap:
            c = swap
        struct.pack_into("<H", cgram, 256 + p * 32 + i * 2, snes_color(c))
write("cgram.bin", cgram)

atan = bytes(round(math.atan(i / 64) * 128 / math.pi) for i in range(65))
write("atan.bin", atan)

# Bomb throw per altitude level: simulate the game's integer bomb physics.
GRAVITY, DET_Z = 16, 0x28000
throwf = bytearray()
falln = bytearray()
for alt in CAM_ALTS:
    z, vz, n = (alt - 9) << 16, 0, 0
    while z >= DET_Z:
        vz -= GRAVITY
        z += vz
        n += 1
    throwf.append(round(256 * (1 - (255 / 256) ** n)))
    falln += struct.pack("<H", n)
write("throwf.bin", throwf)
write("falln.bin", falln)
# alt_ft at or above altstep[i] uses camera height i + 1 (midpoints in feet)
write("altstep.bin", b"".join(
    struct.pack("<H", round(((a + b) / 2 - 9) * FT_PER_UNIT)) for a, b in zip(CAM_ALTS, CAM_ALTS[1:])))
const("NLVL", NLVL)
const("M7_P1_BANK", M7_P1_BANK)
const("M7_P2_BANK", M7_P2_BANK)
const("GRAVITY", GRAVITY)
const("DET_Z", DET_Z)


# ---------------------------------------------------------------- step 4: explosion
# Ground palettes tinted towards the fireball glow, 16 levels.
tint = bytearray()
for lvl in range(16):
    t = lvl / 15
    for i in range(96):
        n = names[i] if i < len(names) else None
        c = COLORS[n] if n else (0, 0, 0)
        c = [c[k] * (1 - 0.3 * t) + (255, 120, 60)[k] * 0.2 * t for k in range(3)]
        tint += struct.pack("<H", snes_color(c) if n else 0)
write("maptint.bin", tint)


def coldata_pair(rgb):
    """Best two COLDATA writes (each sets one or more channels) for a colour."""
    r, g, b = (max(0, min(31, round(v))) for v in rgb)
    R, G, B = 0x20, 0x40, 0x80
    best = None
    for (m1, c1), (m2, c2) in (((R, (r,)), (G | B, (g, b))),
                               ((G, (g,)), (R | B, (r, b))),
                               ((B, (b,)), (R | G, (r, g)))):
        v1, v2 = round(sum(c1) / len(c1)), round(sum(c2) / len(c2))
        err = sum((x - v1) ** 2 for x in c1) + sum((x - v2) ** 2 for x in c2)
        if best is None or err < best[0]:
            best = (err, bytes([m1 | v1, m2 | v2]))
    return best[1]


def ramp(stops, v):
    """Interpolate a list of colour stops at v in 0..1."""
    v *= len(stops) - 1
    i = min(int(v), len(stops) - 2)
    f = v - i
    return [stops[i][k] + (stops[i + 1][k] - stops[i][k]) * f for k in range(3)]


CAP_HOT = [(31, 31, 26), (31, 24, 10), (31, 12, 4)]
CAP_COOL = [(31, 30, 30), (27, 24, 26), (20, 16, 19)]
STEM_HOT = [(31, 18, 6), (24, 10, 4)]
STEM_COOL = [(23, 19, 21), (16, 13, 15)]
cloud = bytearray()
for stops_hot, stops_cool in ((CAP_HOT, CAP_COOL), (STEM_HOT, STEM_COOL)):
    for heat in range(16):
        h = heat / 15
        for v in range(32):
            hot, cool = ramp(stops_hot, v / 31), ramp(stops_cool, v / 31)
            cloud += coldata_pair([cool[k] + (hot[k] - cool[k]) * h for k in range(3)])
write("cloudcol.bin", cloud)              # cap ramps then stem ramps, 16x32 pairs each
const("RING_COL", int.from_bytes(coldata_pair((31, 31, 31)), "little"))

write("grow.bin", bytes(round(255 * (1 - math.exp(-i * 4 / 400))) for i in range(256)))
write("circ.bin", bytes(round(255 * math.sqrt(1 - (i / 64) ** 2)) for i in range(65)))
write("lump.bin", bytes(round(1.6 + 1.6 * math.sin(i * 2.4) + h2(i, 0, 9)) for i in range(16)))


# ---------------------------------------------------------------- step 5: screens
from PIL import ImageFont

LOGO_TILE0 = 2 + 96          # first BG3 tile after the font
font_big = ImageFont.truetype("/usr/share/fonts/opentype/urw-base35/NimbusSans-Bold.otf", 28)
logo_txt = "BIKINI ATOLL"
bbox = font_big.getbbox(logo_txt)
lw, lh = bbox[2] - bbox[0], bbox[3] - bbox[1]
LW, LH = 240, 24
img = Image.new("L", (LW, LH), 0)
ImageDraw.Draw(img).text(((LW - lw) // 2 - bbox[0], (LH - lh) // 2 - bbox[1]),
                         logo_txt, font=font_big, fill=255)
src = img.load()
on = [[src[x, y] > 110 for x in range(LW)] for y in range(LH)]
logo_px = [[0] * LW for _ in range(LH)]
for y in range(LH):
    for x in range(LW):
        if on[y][x]:
            logo_px[y][x] = 2 if y < LH * 0.45 else 1
        elif any(0 <= y + dy < LH and 0 <= x + dx < LW and on[y + dy][x + dx]
                 for dx, dy in ((-1, 0), (0, -1), (-1, -1), (1, 0), (0, 1), (-2, -2))):
            logo_px[y][x] = 3
logo_tiles = bytearray()
logo_index = {}
title = new_map()
for ty in range(LH // 8):
    for tx in range(LW // 8):
        rows = [logo_px[ty * 8 + y][tx * 8: tx * 8 + 8] for y in range(8)]
        key = tuple(tuple(r) for r in rows)
        if not any(any(r) for r in rows):
            continue
        if key not in logo_index:
            logo_index[key] = LOGO_TILE0 + len(logo_index)
            logo_tiles += bg3_tile(rows)
        title[(1 + ty) * 32 + 1 + tx] = logo_index[key] | (4 << 10) | HUD_PRIO
assert LOGO_TILE0 + len(logo_index) <= 256
write("logo.bin", logo_tiles)
const("LOGO_BYTES", len(logo_tiles))
# logo palette: orange body, yellow top, dark outline
struct.pack_into("<HHHH", cgram, 4 * 8, 0, snes_color((240, 120, 40)),
                 snes_color((252, 220, 96)), snes_color((40, 16, 24)))
write("cgram.bin", cgram)

put_center(title, 5, "AN ATOMIC TEST MISSION", 0)
put_center(title, 25, "PRESS START", 7)
put_center(title, 27, "? : CONTROLS", 5)
write("title.bin", map_bytes(title))

brief = new_map()
put_center(brief, 1, "MISSION BRIEFING", 1)
lines = [
    (3, "TARGET:  TEST FLEET IN THE", 0), (4, "         BIKINI ATOLL LAGOON", 0),
    (5, "AIM AT:  THE ORANGE SHIP", 0), (6, "ALTITUDE: 31,000 FT", 0),
    (8, "1. FOLLOW THE RED COMPASS", 6), (9, "   MARK TO THE ATOLL.", 6),
    (10, "2. OPEN THE BOMB BAY (X).", 6),
    (11, "3. PUT THE SIGHT RING ON THE", 6), (12, "   ORANGE SHIP. DROP (Z) WHEN", 6),
    (13, "   IT READS OVER TARGET.", 6),
    (14, "4. BREAK AWAY: TURN 155 DEG", 6), (15, "   BEFORE DETONATION.", 6),
    (17, "THE ATOLL HAS BEEN EVACUATED", 5), (18, "AND THE SHIPS ARE UNCREWED.", 5),
]
for row, text, pal in lines:
    put(brief, row, 2, text, pal)
put_center(brief, 22, "PRESS START TO TAKE OFF", 1)
write("brief.bin", map_bytes(brief))

ending = new_map()
put_center(ending, 1, "TEST COMPLETE", 1)
put(ending, 4, 2, "DETONATION:       FT FROM", 0)
put(ending, 5, 2, "            THE TARGET SHIP", 0)
put(ending, 7, 2, "BREAKAWAY TURN:     DEG", 0)
put(ending, 10, 2, "BOMBING:", 5)
put(ending, 11, 2, "BREAKAWAY:", 5)
put(ending, 15, 2, "IN 1946, OPERATION CROSSROADS", 5)
put(ending, 16, 2, "TESTED ATOMIC BOMBS ON A", 5)
put(ending, 17, 2, "FLEET OF UNCREWED SHIPS AT", 5)
put(ending, 18, 2, "BIKINI ATOLL. THE ISLANDERS", 5)
put(ending, 19, 2, "WERE RELOCATED BEFOREHAND.", 5)
put_center(ending, 23, "PRESS START TO FLY AGAIN", 1)
write("ending.bin", map_bytes(ending))
const("END_MISS_OFS", (4 * 32 + 14) * 2)
const("END_TURN_OFS", (7 * 32 + 18) * 2)
const("END_BOMB_OFS", (10 * 32 + 13) * 2)
const("END_TURN2_OFS", (11 * 32 + 13) * 2)

# ---------------------------------------------------------------- math tables
sin_tbl = bytearray()
for a in range(256):
    sin_tbl += struct.pack("<h", round(256 * math.sin(2 * math.pi * a / 256)))
write("sin.bin", sin_tbl)

const("HOR", HOR)
const("M7_START", M7_START)
const("CAM_UP", 9)
const("CAM_BACK", 12)
const("TARGET_X", TARGET_X)
const("TARGET_Y", TARGET_Y)
const("START_X", START_X)
const("START_Y", START_Y)
const("START_HEADING", START_HEADING)
const("ALT_MIN", 0)
const("ALT_MAX", 60000)
const("ALT_START", 31000)
const("ALT_RATE", 33)          # feet per frame, ~2,000 ft/s
const("ALT_WARN", 3000)       # PULL UP! below this
const("ALT_CRASH", 200)       # crash into the ocean below this
const("PLANE_Y_LOW", 150)     # plane sprite top at 0 ft; rises 1px per 1,024 ft
write("camalt.bin", bytes(CAM_ALTS))

# ---------------------------------------------------------------- sound
# Explosion rumble: one seamless loop of low sine partials with random phases
# (1/f amplitudes, so it leans to the deep end), BRR-encoded for the S-DSP.
# Uploaded to APU RAM at SND_DIR: a one-entry sample directory, then the BRR.
import random


def brr_decode_step(nib, shift, filt, p1, p2):
    s = (nib << shift) >> 1
    if filt == 1:
        s += p1 + ((-p1) >> 4)
    elif filt == 2:
        s += 2 * p1 + ((-p1 * 3) >> 5) - p2 + (p2 >> 4)
    elif filt == 3:
        s += 2 * p1 + ((-p1 * 13) >> 6) - p2 + ((p2 * 3) >> 4)
    s = max(-0x8000, min(0x7FFF, s))
    s = ((s * 2) & 0xFFFF)                  # the DSP keeps 15 bits
    s = (s - 0x10000 if s & 0x8000 else s) >> 1
    return s


def brr_encode(pcm, loop):
    out = bytearray()
    p1 = p2 = 0
    nblocks = len(pcm) // 16
    for b in range(nblocks):
        blk = pcm[b * 16:b * 16 + 16]
        best = None
        for filt in ((0,) if b == 0 else range(4)):
            for shift in range(13):
                q1, q2, err, nibs = p1, p2, 0, []
                for x in blk:
                    pred = brr_decode_step(0, shift, filt, q1, q2)
                    step = (1 << shift) >> 1 or 1
                    n = max(-8, min(7, round((x - pred) / step)))
                    y = brr_decode_step(n, shift, filt, q1, q2)
                    err += (x - y) ** 2
                    nibs.append(n & 15)
                    q1, q2 = y, q1
                if best is None or err < best[0]:
                    best = (err, filt, shift, nibs, q1, q2)
        err, filt, shift, nibs, p1, p2 = best
        flags = (1 if b == nblocks - 1 else 0) | (2 if loop else 0)
        out.append((shift << 4) | (filt << 2) | flags)
        for i in range(0, 16, 2):
            out.append((nibs[i] << 4) | nibs[i + 1])
    return out


SND_DIR = 0x0200
RUMBLE_LEN = 4096               # one loop; at pitch $0400 (8 kHz) = 0.512 s
rng = random.Random(1946)
parts = [(k, rng.uniform(0, 2 * math.pi)) for k in range(10, 72)]   # ~20-140 Hz
raw = [sum(math.sin(2 * math.pi * k * i / RUMBLE_LEN + ph) / k for k, ph in parts)
       for i in range(RUMBLE_LEN)]
peak = max(abs(v) for v in raw)
pcm = [round(v / peak * 0x3800) for v in raw]
brr = brr_encode(pcm, loop=True)
start = SND_DIR + 4
write("snd.bin", struct.pack("<HH", start, start) + brr)
const("SND_DIR", SND_DIR)
const("SND_BYTES", 4 + len(brr))

with open(os.path.join(OUT, "gen.inc"), "w") as f:
    f.write("\n".join(inc) + "\n")

print(f"tiles={len(tiles)} colors={len(names)}")
