"""The ArkadeOS boot animation, round 9: Írisz + Tervrajz (Roland, 2026-11-21:
"az iriszt meg a tervrajzot gyúrjuk össze", then "Igen, építsd").

Thin construction lines lay out the mark like a technical drawing (axes,
dimension marks, two circles, the hexagon), the six crystal pieces of the
Start mark spiral in onto the drawing like a closing iris and snap shut, the
inside lights up from the centre, the gem turns into place with a light line
and a hexagonal ring, the drawing fades, a sheen sweeps the mark and the word
comes letter by letter. While the machine boots, a light point circles the
faint construction circle and a sheen sweeps the mark now and then.

Round 8b's beams, rays, sparks, motes and glints are gone ("kevésbé legyen
hópihe hatású és giccses"), and so are its full-screen layers: Plymouth draws
in software, and their full-screen redraw every frame made the animation catch
(measured in Plymouth at 2560 x 1600: 150-280 ms frames after the ignition).
Everything that moves here stays round the mark; the axes and the light line
are a few pixels tall.

This script builds on round 8b's approved sprites (art/boot-sprites.js wrote
them): the mark's parts, the word, the gem, the shock waves and the sheen. It
draws the new sprites from them with ImageMagick, deletes the ones round 9 no
longer uses and writes the Plymouth script from art/boot-iris.script.in.

Usage: boot_iris.py <theme dir>   (needs magick; the theme dir is
system_files/usr/share/plymouth/themes/arkadeos)
"""
import math
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = 2.169                 # sprite px per design unit at density 1 (2560 x 1440)
MCX, MCY = 590, 305.266        # the mark's centre on the 1180 x 664 design screen
R = 92                         # the bezel's outer hexagon, design units (pointy top)
CIRC_O, CIRC_I = R + 14, R * 0.45
ARC_N = 16                     # segments per construction circle
HEX_PARTS = 4                  # segments per hexagon edge (both ways from the top: 6 edges)
IRIS_STEP = 6                  # degrees between the turning piece's pictures
GEM_N = 14                     # the gem's turn-in, pictures along its timeline
INNER_N = 8                    # the inside lighting up, pictures
SHOCK_USE = 8                  # round 8b shock wave pictures used (the smaller ones)
SHEEN_STEP = 2                 # every second round 8b sheen picture

BLUE = (120, 190, 255)
LINE = (170, 215, 255)

theme = sys.argv[1]
# Round 8b's sprites this builds on: density, centre (design units).
SRC = {"chamber": (1, MCX, MCY), "ridge": (1, MCX, MCY), "ticks": (1, MCX, MCY), "halo": (0.5, MCX, MCY),
       "bloom": (0.5, MCX, MCY), "word": (1, 590, 490.563), "entry": (1, 590, 517.297), "bar": (1, 590, 517.297),
       "bar-back": (1, 590, 517.297), "lock": (1, 590, 517.297), "bullet": (1, 590, 517.297), "gem-7": (1, MCX, MCY)}
SRC.update({"shock0-%d" % j: (0.5, MCX, MCY) for j in range(14)})
SRC.update({"sheen-%d" % j: (1, MCX, MCY) for j in range(33)})
PIECES = [(629.838, 236.44), (669.674, 305.44), (629.838, 374.44), (550.162, 374.44), (510.326, 305.44), (550.162, 236.44)]
spr = {}          # name -> (d, x, y) for the script
keep = set()      # png names the script uses


def P(*a):
    subprocess.run(["magick", *map(str, a)], check=True, cwd=theme)


def px(u):
    return u * RENDER


def reuse(name):
    spr[name] = SRC[name]
    keep.add(name)


def size(name):
    out = subprocess.run(["magick", "identify", "-format", "%w %h", name + ".png"], check=True, cwd=theme,
                         capture_output=True, text=True).stdout
    return tuple(map(int, out.split()))


def masked(name, W, H, alpha, color):
    """A flat colour with an alpha drawn by an -fx expression (i, j: pixel)."""
    P("-size", f"{W}x{H}", "xc:" + color, "(", "-size", f"{W}x{H}", "xc:black", "-fx", alpha, ")",
      "-alpha", "off", "-compose", "CopyOpacity", "-composite", name + ".png")


def rgba(c, a):
    return "rgba(%d,%d,%d,%.3f)" % (*c, a)


def emit(name, cx, cy, d=1):
    spr[name] = (d, round(cx, 3), round(cy, 3))
    keep.add(name)


# ------------------------------------------------------------ reused round 8b sprites
for n in ["chamber", "ridge", "ticks", "halo", "bloom", "word", "entry", "lock", "bullet", "bar", "bar-back"]:
    reuse(n)
for j in range(SHOCK_USE):
    reuse("shock0-%d" % j)
SHEEN = list(range(0, 33, SHEEN_STEP))
for j in SHEEN:
    reuse("sheen-%d" % j)
pieces = PIECES
for k, (x, y) in enumerate(pieces):
    spr["piece%d-0" % k] = (1, x, y)
    keep.add("piece%d-0" % k)
gem_x, gem_y = MCX, MCY
keep.add("gem-7")

# ------------------------------------------------------------ the drawing
# The axes: a line with soft ends, its length set by the script (scaled steps).
for name, w, h in [("axis-h", 1240, 0), ("axis-v", 0, 720)]:
    W, H = (int(px(w)), 3) if w else (3, int(px(h)))
    L, along, across = (W, "i", "j") if w else (H, "j", "i")
    masked(name, W, H, f"0.5*min(1,min({along},{L}-{along})/({L}*0.15))*(abs({across}-1)<0.6?1:0.35)", "rgb(%d,%d,%d)" % BLUE)
    emit(name, MCX, MCY)
# Dimension marks.
P("-size", "3x%d" % int(px(8)), "xc:" + rgba(BLUE, 0.5), "dim-v.png")   # a short upright mark (on the horizontal axis)
P("-size", "%dx3" % int(px(8)), "xc:" + rgba(BLUE, 0.5), "dim-h.png")
emit("dim-v", MCX, MCY)
emit("dim-h", MCX, MCY)


def arc_segments(prefix, r, start_deg):
    for i in range(ARC_N):
        a0 = start_deg + i * 360 / ARC_N
        a1 = a0 + 360 / ARC_N
        pts = [(MCX + r * math.cos(math.radians(a0 + (a1 - a0) * s / 8)), MCY + r * math.sin(math.radians(a0 + (a1 - a0) * s / 8))) for s in range(9)]
        x0, x1 = min(p[0] for p in pts) - 2, max(p[0] for p in pts) + 2
        y0, y1 = min(p[1] for p in pts) - 2, max(p[1] for p in pts) + 2
        W, H = math.ceil(px(x1 - x0)), math.ceil(px(y1 - y0))
        cx, cy = px(MCX - x0), px(MCY - y0)
        rr = px(r)
        P("-size", f"{W}x{H}", "xc:none", "-fill", "none", "-stroke", rgba(BLUE, 0.55), "-strokewidth", 1.3,
          "-draw", f"arc {cx - rr:.2f},{cy - rr:.2f} {cx + rr:.2f},{cy + rr:.2f} {a0:.3f},{a1 + 0.4:.3f}", f"{prefix}-{i}.png")
        emit(f"{prefix}-{i}", x0 + (x1 - x0) / 2, y0 + (y1 - y0) / 2)


arc_segments("arco", CIRC_O, -90)
arc_segments("arci", CIRC_I, 90)
# The faint whole construction circle for the waiting.
D = math.ceil(px(2 * CIRC_O + 4))
P("-size", f"{D}x{D}", "xc:none", "-fill", "none", "-stroke", rgba(BLUE, 1), "-strokewidth", 1.3,
  "-draw", f"circle {D/2:.2f},{D/2:.2f} {D/2 + px(CIRC_O):.2f},{D/2:.2f}", "circle.png")
emit("circle", MCX, MCY)

# The hexagon outline, drawn from the top vertex both ways: segment n (0 ..
# 3*HEX_PARTS-1) of side s (0 clockwise, 1 anticlockwise).
V = [(MCX + R * math.cos(math.radians(-90 + 60 * i)), MCY + R * math.sin(math.radians(-90 + 60 * i))) for i in range(7)]
for side in (0, 1):
    for n in range(3 * HEX_PARTS):
        e, f = divmod(n, HEX_PARTS)
        A, B = (V[e], V[e + 1]) if side == 0 else (V[6 - e], V[5 - e])
        a = (A[0] + (B[0] - A[0]) * f / HEX_PARTS, A[1] + (B[1] - A[1]) * f / HEX_PARTS)
        b = (A[0] + (B[0] - A[0]) * (f + 1) / HEX_PARTS, A[1] + (B[1] - A[1]) * (f + 1) / HEX_PARTS)
        x0, x1 = min(a[0], b[0]) - 2, max(a[0], b[0]) + 2
        y0, y1 = min(a[1], b[1]) - 2, max(a[1], b[1]) + 2
        W, H = math.ceil(px(x1 - x0)), math.ceil(px(y1 - y0))
        P("-size", f"{W}x{H}", "xc:none", "-stroke", rgba(LINE, 0.9), "-strokewidth", px(1.1), "-fill", "none",
          "-draw", f"line {px(a[0]-x0):.2f},{px(a[1]-y0):.2f} {px(b[0]-x0):.2f},{px(b[1]-y0):.2f}", f"hex{side}-{n}.png")
        emit(f"hex{side}-{n}", x0 + (x1 - x0) / 2, y0 + (y1 - y0) / 2)

# ------------------------------------------------------------ the iris
# Piece 0 turned; piece k at turn a uses the picture at 60k + a. When the iris
# shuts each piece changes to its own picture (its own top light).
for a in range(0, 360, IRIS_STEP):
    P("piece0-0.png", "-background", "none", "-virtual-pixel", "none", "-distort", "SRT", a, f"iris-{a}.png")
    emit(f"iris-{a}", MCX, MCY)   # placed by the script, the anchor is the picture's centre

# The bezel lit (the snap): the six pieces and the ridge, whitened.
C = 534
args = ["-size", f"{C}x{C}", "xc:none"]
for k, (x, y) in enumerate(pieces):
    w, h = size("piece%d-0" % k)
    args += ["piece%d-0.png" % k, "-geometry", "+%d+%d" % (round(px(x - MCX) + C / 2 - w / 2), round(px(y - MCY) + C / 2 - h / 2)), "-composite"]
args += ["ridge.png", "-composite", "-channel", "RGB", "-fill", "white", "-colorize", "70", "+channel", "bezel-lit.png"]
P(*args)
emit("bezel-lit", MCX, MCY)

# After the snap the bezel (pieces and ridge) and the base (chamber and ticks)
# are one picture each: fewer layers to redraw round the mark.
args = ["-size", f"{C}x{C}", "xc:none"]
for k, (x, y) in enumerate(pieces):
    w, h = size("piece%d-0" % k)
    args += ["piece%d-0.png" % k, "-geometry", "+%d+%d" % (round(px(x - MCX) + C / 2 - w / 2), round(px(y - MCY) + C / 2 - h / 2)), "-composite"]
P(*args, "ridge.png", "-geometry", "+0+0", "-composite", "bezel.png")
emit("bezel", MCX, MCY)
P("(", "chamber.png", "-channel", "A", "-evaluate", "multiply", "0.9", "+channel", ")",
  "(", "ticks.png", "-channel", "A", "-evaluate", "multiply", "0.8", "+channel", ")", "-composite", "base.png")
emit("base", MCX, MCY)

# The inside lighting up from the centre: the chamber within a growing hexagon, whitened.
for i in range(INNER_N):
    r = px(R * 0.95 * (i + 1) / INNER_N)
    poly = " ".join("%.2f,%.2f" % (C / 2 + r * math.cos(math.radians(-90 + 60 * j)), C / 2 + r * math.sin(math.radians(-90 + 60 * j))) for j in range(6))
    P("chamber.png", "(", "-size", f"{C}x{C}", "xc:none", "-fill", "white", "-draw", f"polygon {poly}", "-blur", "0x2", ")",
      "-compose", "DstIn", "-composite", "-channel", "RGB", "-fill", "rgb(200,230,255)", "-colorize", "65", "+channel", f"inner-{i}.png")
    emit(f"inner-{i}", MCX, MCY)


# The gem turning into place as it grows (60 degrees, an overshooting pop).
def pop(p):
    c1 = 1.70158 * 1.3
    c3 = c1 + 1
    return 1 + c3 * (p - 1) ** 3 + c1 * (p - 1) ** 2


for i in range(GEM_N):
    p = i / (GEM_N - 1)
    k = max(0.05, pop(p))
    turn = 60 * (1 - (1 - (1 - p) ** 3))
    P("gem-7.png", "-background", "none", "-gravity", "center", "-extent", "280x280", "-virtual-pixel", "none",
      "-distort", "SRT", f"{k:.4f} {turn:.3f}", f"gemt-{i}.png")
    emit(f"gemt-{i}", gem_x, gem_y)

# Glows: the burst (two sizes) and the waiting light point.
for name, r, a in [("glow-b", 120, 1.0), ("glow-s", 80, 1.0), ("odot", 16, 0.8)]:
    D = math.ceil(px(2 * r))
    P("-size", f"{D}x{D}", "radial-gradient:white-black", "-evaluate", "pow", "2.2",
      "(", "-size", f"{D}x{D}", "radial-gradient:rgb(225,242,255)-rgb(90,160,255)", ")", "+swap",
      "-alpha", "off", "-compose", "CopyOpacity", "-composite", "-channel", "A", "-evaluate", "multiply", a, "+channel", name + ".png")
    emit(name, MCX, MCY)

# The light line through the core: a bright core and a soft band, tall only a few pixels.
SW, SH = 2560, int(px(14)) | 1
masked("streak-band", SW, SH, f"xx=abs(i-{SW/2})/{SW/2}; yy=abs(j-{SH/2})/{SH/2}; (1-xx)^2*exp(-yy*yy*4)*0.35*(xx<0.6?(1-xx/0.6):0)", "rgb(120,190,255)")
masked("streak-core", SW, SH, f"xx=abs(i-{SW/2})/{SW/2}; yy=abs(j-{SH/2})/{SH/2}; (yy<0.18?0.95:0)*(1-xx)^2", "rgb(225,242,255)")
P("streak-band.png", "streak-core.png", "-composite", "streak.png")
for f in ("streak-band.png", "streak-core.png"):
    os.remove(os.path.join(theme, f))
emit("streak", MCX, MCY)

# The word, letter by letter: the word cut after each letter (the gaps between
# the letters found in its own alpha).
ww, wh = size("word")
cols = subprocess.run(["magick", "word.png", "-alpha", "extract", "-scale", f"{ww}x1!", "-depth", "8", "txt:"], check=True, cwd=theme,
                      capture_output=True, text=True).stdout.splitlines()[1:]
ink = [int(re.search(r"\((\d+)", c).group(1)) > 8 for c in cols]
ends, inside = [], False
for x, v in enumerate(ink):
    if inside and not v:
        ends.append(x)
    inside = v
if inside:
    ends.append(ww)
assert len(ends) == 8, ends
wd, wx, wy = spr["word"]
for n, e in enumerate(ends, 1):
    cut = min(ww, e + 4) if n < 8 else ww
    P("word.png", "-crop", f"{cut}x{wh}+0+0", "+repage", "-background", "none", "-extent", f"{ww}x{wh}", f"word-{n}.png")
    emit(f"word-{n}", wx, wy)

# From the ignition until the core has settled, everything round the mark is
# baked into one picture sequence: Plymouth blends pixel by pixel in software,
# and here eight to ten stacked layers changed together. The light line, the
# ring, the sheen and the thin drawing lines outside the mark stay sprites.
# The opacities are the script's own (t: seconds of the opening).
def ramp(t, a, b):
    return min(1, max(0, (t - a) / (b - a)))


def out3(p):
    return 1 - (1 - p) ** 3


LOCK, IGN = 1.95, 2.15
SEQ_FROM, SEQ_TO = IGN, IGN + 0.9


def place(name):
    d, x, y = spr[name] if name in spr else SRC[name]
    w, h = size(name)
    if d != 1:
        w, h = round(w / d), round(h / d)
    return ["-geometry", "+%d+%d" % (round(px(x - MCX) + C / 2 - w / 2), round(px(y - MCY) + C / 2 - h / 2))], d


def layer_args(name, a):
    if a <= 0.003:
        return []
    geo, d = place(name)
    return ["(", name + ".png"] + (["-resize", "%d%%" % round(100 / d)] if d != 1 else []) + \
        ["-channel", "A", "-evaluate", "multiply", "%.4f" % min(1, a), "+channel", ")"] + geo + ["-composite"]


def mark_at(t, out):
    la = 1 - ramp(t, LOCK + 0.1, LOCK + 0.8)
    args = ["-size", f"{C}x{C}", "xc:none", "-gravity", "northwest"]
    for n in range(ARC_N):
        args += layer_args("arco-%d" % n, la) + layer_args("arci-%d" % n, la)
    for n in range(3 * HEX_PARTS):
        args += layer_args("hex0-%d" % n, la) + layer_args("hex1-%d" % n, la)
    args += layer_args("halo", 0.5 * ramp(t, IGN, IGN + 0.7))
    args += layer_args("base", out3(ramp(t, LOCK, LOCK + 0.5)))
    ip = ramp(t, LOCK + 0.05, LOCK + 0.5)
    if 0 < ip < 1:
        args += layer_args("inner-%d" % round(out3(ip) * (INNER_N - 1)), 1.2 * (1 - ip))
    args += layer_args("bezel", 1)
    args += layer_args("bezel-lit", max(0, 1.5 * (ramp(t, LOCK - 0.05, LOCK + 0.05) - ramp(t, LOCK + 0.05, LOCK + 0.7))))
    u = t - IGN
    gp = ramp(u, 0, 0.7)
    args += layer_args("bloom", 0.55 * gp)
    if gp > 0:
        args += layer_args("gemt-%d" % round(gp * (GEM_N - 1)), gp * 3)
    args += layer_args("glow-s", ramp(u, 0, 0.05) - ramp(u, 0.05, 0.5))
    args += layer_args("glow-b", ramp(u, 0, 0.08) - ramp(u, 0.08, 0.9))
    P(*args, out)


SEQ_N = 22
for i in range(SEQ_N):
    mark_at(SEQ_FROM + (SEQ_TO - SEQ_FROM) * i / (SEQ_N - 1), "seq-%d.png" % i)
    emit("seq-%d" % i, MCX, MCY)
# The whole mark at rest: the sequence's last picture.
mark_at(SEQ_TO, "mark.png")
emit("mark", MCX, MCY)
for n in ("bloom", "glow-s", "glow-b") + tuple("gemt-%d" % i for i in range(GEM_N)):
    keep.discard(n)
keep.add("bloom")    # a source of round 8b, kept for the next run

# ------------------------------------------------------------ the script, and the old sprites out
for n in list(spr):
    if n not in keep:
        del spr[n]
lines = [f'spr["{n}"].d = {d:g}; spr["{n}"].x = {x:g}; spr["{n}"].y = {y:g};' for n, (d, x, y) in sorted(spr.items())]
consts = (f"DW = 1180; DH = 664; DCX = 590; DCY = 305.44; RENDER = {RENDER};\n"
          f"MCX = {MCX}; MCY = {MCY}; ARC_N = {ARC_N}; HEX_N = {3 * HEX_PARTS}; IRIS_STEP = {IRIS_STEP};\n"
          f"SEQ_N = {SEQ_N}; INNER_N = {INNER_N}; SHOCK_N = {SHOCK_USE}; SHEEN_N = {len(SHEEN)};\n"
          + "".join(f"sheen_name[{i}] = \"sheen-{j}\";\n" for i, j in enumerate(SHEEN))
          + "".join(f"piece_x[{k}] = {x:g}; piece_y[{k}] = {y:g};\n" for k, (x, y) in enumerate(pieces))
          + "\n".join(lines))
tpl = open(os.path.join(HERE, "boot-iris.script.in")).read()
open(os.path.join(theme, "arkadeos.script"), "w").write(tpl.replace("#@SPRITES@", consts))
keep |= {"gem-7"}
for f in os.listdir(theme):
    if f.endswith(".png") and f[:-4] not in keep:
        os.remove(os.path.join(theme, f))
# Plymouth blends every pixel that is not fully clear: the invisible tails of
# the soft glows (alpha under 1.2 %) are cut to clear, and every sprite is
# 8 bits per channel (ImageMagick writes 16).
for n in sorted(keep):
    P(n + ".png", "-channel", "A", "-fx", "a<0.012?0:a", "+channel", "-depth", "8", "PNG32:" + n + ".png")
print(len(keep), "sprites")
