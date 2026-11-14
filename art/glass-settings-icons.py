"""ArkadeOS Glass icons of System Settings (T086; Roland, 2026-11-13: "a
beállítások ablakot is rendbe rakhatnád ... az egészre gondoltam. ronda.",
then 11-14: "ilyen tökéletességre való törekedéssel neki lehet állni az összes
eddigi ikonnak", round-7 pilot approved, "haladjunk az ikonokkal").

Every page and group of the side list in the craft of the Start and Portal
marks (glass_craft) and of the app icons (glass-app-icons.py), light from the
top, no cast shadow, symmetric where the object allows:
- devices (mouse, keyboard, controller, tablet) are dark glass bodies with a
  machined metal rim and glowing controls;
- frames and housings (screens, phone, drive, printer, bell, padlock) are
  machined cool metal;
- panels and symbols (pointer, globe, shield face, people, folders) are sky
  glass with a lit rim;
- light is the glow on deep glass: a lit track, a prompt, a rune, a check.
Sound and Display are the round-7 pilots: the machined speaker and the screen
showing the Start mark. No gear: the gear is the Portal's.

Each icon has two hand-drawn sizes: apps/small (32 px and below, bolder, fewer
details, no blur) and apps/scalable (above). They go into the ArkadeOS Glass
themes (both read the same apps folder), over Breeze's, under the names the
pages ask for (Plasma 6.8). Usage: glass-settings-icons.py <icons folder>"""
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glass_craft as K  # noqa: E402
from glass_craft import f, lg, rg  # noqa: E402

out = sys.argv[1]
W = "#ffffff"
GLOW, CORE, SOFT = "#5aaeea", "#e6f6ff", "#bfe6ff"
INK = "#1f64a6"


def el(tag, **a):
    s = "".join(f' {k.rstrip("_").replace("_", "-")}="{f(v) if isinstance(v, float) else v}"' for k, v in a.items())
    return f"<{tag}{s}/>"


def rr(x, y, w, h, r):
    return (f"M{f(x + r)} {f(y)}H{f(x + w - r)}A{f(r)} {f(r)} 0 0 1 {f(x + w)} {f(y + r)}V{f(y + h - r)}"
            f"A{f(r)} {f(r)} 0 0 1 {f(x + w - r)} {f(y + h)}H{f(x + r)}A{f(r)} {f(r)} 0 0 1 {f(x)} {f(y + h - r)}"
            f"V{f(y + r)}A{f(r)} {f(r)} 0 0 1 {f(x + r)} {f(y)}Z")


def cp(cx, cy, r):
    return f"M{f(cx + r)} {f(cy)}A{f(r)} {f(r)} 0 1 1 {f(cx - r)} {f(cy)}A{f(r)} {f(r)} 0 1 1 {f(cx + r)} {f(cy)}Z"


def pts(ps):
    return "M" + "L".join(f"{f(x)} {f(y)}" for x, y in ps) + "Z"


def vg(id_, stops):
    s = "".join(f'<stop offset="{o}" stop-color="{c}"{"" if a is None else f" stop-opacity=\"{a}\""}/>' for o, c, a in stops)
    return f'<linearGradient id="{id_}" x1="0" y1="0" x2="0" y2="1">{s}</linearGradient>'


def rb(id_, stops, cx=0.5, cy=0.3, r=0.8):
    return rg(id_, stops, None, f' cx="{cx}" cy="{cy}" r="{r}"')


# ---------------------------------------------------------------- materials
DEFS = [
    # sky glass (the folder's front), its deep back, the top light and the lit rim
    vg("skyG", [(0, "#eaf7ff", None), (0.45, "#8ccaf5", None), (1, "#3a88d0", None)]),
    vg("deepG", [(0, "#4b97d8", None), (1, "#1b4f86", None)]),
    vg("hiG", [(0, W, 0.55), (0.32, W, 0)]),
    vg("rimG", [(0, W, 0.95), (0.45, W, 0.3), (1, "#1d5a95", 0.55)]),
    # machined cool metal: the chamfer and the face (the Portal's)
    vg("mCh", [(0, W, None), (0.4, "#d9e7f2", None), (0.7, "#7e9cb7", None), (1, "#3d5b78", None)]),
    vg("mFace", [(0, "#e8f1f8", None), (1, "#9fb9cf", None)]),
    # dark glass of the devices, the deep screen, the wallpaper screen, the gloss
    vg("deepK", [(0, "#2c4862", None), (1, "#0f1b28", None)]),
    rb("scrR", [(0, "#1b4a75", None), (0.6, "#0c2236", None), (1, "#060f19", None)], 0.5, 0.32, 0.8),
    rb("wallR", [(0, "#21598b", None), (0.55, "#0d2740", None), (1, "#050c15", None)], 0.5, 0.45, 0.75),
    vg("glossB", [(0, W, 0.16), (0.5, W, 0)]),
    vg("recessB", [(0, "#000000", 0.55), (0.5, "#000000", 0.15), (1, W, 0.35)]),
    vg("glowG", [(0, CORE, None), (1, "#7cc4f4", None)]),
    vg("lightS", [(0, "#f6fbff", None), (1, "#c9e2f6", None)]),
    vg("picG", [(0, "#cfe9fc", None), (0.6, "#7fbcec", None), (1, "#3a88d0", None)]),
    # the keycap and the knob (the Settings app's sliders)
    vg("kCh", [(0, W, None), (0.5, "#9fd6fb", None), (1, "#2f78bd", None)]),
    vg("kFace", [(0, "#f4fbff", None), (1, "#b5dffb", None)]),
    # a crystal sphere, and the colour page's three discs
    rb("sphR", [(0, "#f2faff", None), (0.45, "#9ad0f6", None), (1, "#2f6fa9", None)], 0.38, 0.28, 0.85),
    rb("redR", [(0, "#ffd3dc", None), (0.5, "#f43f5e", None), (1, "#a3142f", None)]),
    rb("grnR", [(0, "#c9f7d9", None), (0.5, "#22c55e", None), (1, "#127a39", None)]),
    rb("bluR", [(0, "#e2f3ff", None), (0.5, "#60aae8", None), (1, "#1f5d9c", None)]),
    # the round-7 pilots: Sound's speaker and Display's screen
    lg("gloss", 60, 25, 60, 56, [(0, W, 0.13), (1, W, 0)]),
    rg("surr", [(0, "#21364b", None), (0.8, "#101d2a", None), (1, "#0a131c", None)], (60, 60, 36)),
    lg("surrHi", 60, 24, 60, 96, [(0, W, 0.28), (0.5, W, 0.04), (1, W, 0)]),
    rg("cone", [(0, "#2a5e8f", None), (0.7, "#12304d", None), (1, "#0b1d30", None)], (60, 56, 31)),
    rb("dome", [(0, W, None), (0.45, "#a6dafc", None), (1, "#2f80c8", None)], 0.5, 0.3, 0.75),
    '<clipPath id="spkClip"><circle cx="60" cy="60" r="45.5"/></clipPath>',
    '<filter id="glw" filterUnits="userSpaceOnUse" x="-20" y="-20" width="160" height="160"><feGaussianBlur stdDeviation="1.6"/></filter>',
]


def glass(d, big, fill="skyG", rule=None):
    ex = {"fill_rule": rule} if rule else {}
    s = el("path", d=d, fill=f"url(#{fill})", **ex)
    if big:
        s += el("path", d=d, fill="url(#hiG)", **ex)
    return s + el("path", d=d, fill="none", stroke="url(#rimG)", stroke_width=1.2 if big else 2.6, stroke_linejoin="round")


def metal(d, big, w=None, rule=None):
    ex = {"fill_rule": rule} if rule else {}
    return el("path", d=d, fill="url(#mFace)", stroke="url(#mCh)", stroke_width=w or (2.4 if big else 4), stroke_linejoin="round", **ex)


def device(d, big):
    s = el("path", d=d, fill="url(#deepK)", stroke="url(#mCh)", stroke_width=2.4 if big else 4, stroke_linejoin="round")
    return s + (el("path", d=d, fill="url(#glossB)") if big else "")


def screen(d, big, fill="scrR"):
    s = el("path", d=d, fill=f"url(#{fill})")
    if big:
        s += el("path", d=d, fill="none", stroke="url(#recessB)", stroke_width=1.2) + el("path", d=d, fill="url(#glossB)")
    return s


def glow(d, big, w):
    kw = dict(fill="none", stroke_linecap="round", stroke_linejoin="round")
    if big:
        return (el("path", d=d, stroke=GLOW, stroke_width=w * 1.8, filter="url(#glw)", opacity=0.75, **kw)
                + el("path", d=d, stroke=CORE, stroke_width=w, **kw))
    return el("path", d=d, stroke=CORE, stroke_width=w, **kw)


def glowf(d, big):
    if big:
        return el("path", d=d, fill=GLOW, filter="url(#glw)", opacity=0.8) + el("path", d=d, fill="url(#glowG)")
    return el("path", d=d, fill=SOFT)


def groove(d, big):
    """A machined groove: a dark cut with its lit lower lip."""
    w = 0.9 if big else 2.4
    return (el("path", d=d, fill="none", stroke="#10304d", stroke_opacity=0.45, stroke_width=w, stroke_linecap="round")
            + (el("path", d=d, fill="none", stroke=W, stroke_opacity=0.6, stroke_width=0.6, stroke_linecap="round", transform="translate(0 0.9)") if big else ""))


def keycap(x, y, w, h, big, r=None):
    r = r or min(w, h) * 0.22
    s = el("path", d=rr(x, y, w, h, r), fill="url(#kCh)")
    i = 1.6 if big else 2.6
    s += el("path", d=rr(x + i, y + i, w - 2 * i, h - 2 * i, max(r - i, 1)), fill="url(#kFace)")
    if big:
        s += el("path", d=f"M{f(x + r)} {f(y + 0.6)}H{f(x + w - r)}", stroke=W, stroke_width=0.6, stroke_linecap="round")
    return s


def badge(big, glyph, cx=60, cy=60, r=48):
    s = el("circle", cx=cx, cy=cy, r=r, fill="url(#mCh)")
    ri = r * (0.91 if big else 0.86)
    s += el("path", d=cp(cx, cy, ri), fill="url(#scrR)")
    if big:
        s += el("path", d=cp(cx, cy, ri), fill="url(#glossB)")
        s += el("circle", cx=cx, cy=cy, r=ri, fill="none", stroke="#000000", stroke_opacity=0.35, stroke_width=0.8)
    return s + glyph


def bezel(x, y, w, h, big, rx=8):
    """A screen's dark bezel with its machined edge."""
    return (el("path", d=rr(x, y, w, h, rx), fill="#0d1a27")
            + el("path", d=rr(x, y, w, h, rx), fill="none", stroke="url(#mCh)", stroke_width=1.6 if big else 3))


def stand(cx, y, big, s=1.0):
    return (el("path", d=pts([(cx - 8 * s, y), (cx + 8 * s, y), (cx + 11.5 * s, y + 13 * s), (cx - 11.5 * s, y + 13 * s)]), fill="url(#mCh)")
            + el("path", d=rr(cx - 26 * s, y + 12 * s, 52 * s, 7 * s, 3.5 * s), fill="url(#mCh)"))


def monitor(big, x, y, w, h, inner=None, with_stand=True):
    s = stand(x + w / 2, y + h - 1, big, w / 104) if with_stand else ""
    s += bezel(x, y, w, h, big, 8 * w / 104 + 1)
    i = 5 if big else 6.5
    sx, sy, sw, sh = x + i, y + i, w - 2 * i, h - 2 * i
    s += inner(sx, sy, sw, sh) if inner else screen(rr(sx, sy, sw, sh, 3.5), big, "wallR")
    return s


def window(big, x, y, w, h, tb=None):
    """An app window: machined frame, glass title bar, deep content."""
    tb = tb or (12 if big else 16)
    s = el("path", d=rr(x, y, w, h, 9), fill="url(#scrR)", stroke="url(#mCh)", stroke_width=2 if big else 3.6)
    s += glass(f"M{f(x)} {f(y + 9)}A9 9 0 0 1 {f(x + 9)} {f(y)}H{f(x + w - 9)}A9 9 0 0 1 {f(x + w)} {f(y + 9)}V{f(y + tb)}H{f(x)}Z", big)
    return s


def globe(big, cx, cy, r):
    cid = f"gc{int(cx)}x{int(cy)}x{int(r)}{'b' if big else 's'}"
    DEFS.append(f'<clipPath id="{cid}"><circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}"/></clipPath>')
    s = el("circle", cx=cx, cy=cy, r=r, fill="url(#sphR)")
    if big:
        lines = (f"M{f(cx - r)} {f(cy)}H{f(cx + r)}M{f(cx - r * 0.87)} {f(cy - r * 0.5)}H{f(cx + r * 0.87)}"
                 f"M{f(cx - r * 0.87)} {f(cy + r * 0.5)}H{f(cx + r * 0.87)}M{f(cx)} {f(cy - r)}V{f(cy + r)}")
        s += f'<g clip-path="url(#{cid})" fill="none" stroke="{W}" stroke-opacity=".6" stroke-width="1.2">'
        s += el("path", d=lines) + el("ellipse", cx=cx, cy=cy, rx=r * 0.45, ry=r) + "</g>"
        s += el("ellipse", cx=cx - r * 0.3, cy=cy - r * 0.48, rx=r * 0.34, ry=r * 0.16, fill=W, opacity=0.55, filter="url(#glw)")
    else:
        s += f'<g clip-path="url(#{cid})" fill="none" stroke="{W}" stroke-opacity=".75" stroke-width="3.4">'
        s += el("path", d=f"M{f(cx - r)} {f(cy)}H{f(cx + r)}") + el("ellipse", cx=cx, cy=cy, rx=r * 0.45, ry=r) + "</g>"
    return s + el("circle", cx=cx, cy=cy, r=r, fill="none", stroke="url(#rimG)", stroke_width=1.2 if big else 2.6)


def bust(big, cx, top, s, fill="skyG"):
    """A person: head and shoulders of glass."""
    head = cp(cx, top + 18 * s, 18 * s)
    body = (f"M{f(cx - 34 * s)} {f(top + 78 * s)}C{f(cx - 34 * s)} {f(top + 48 * s)} {f(cx + 34 * s)} {f(top + 48 * s)} "
            f"{f(cx + 34 * s)} {f(top + 78 * s)}Z")
    return glass(body, big, fill) + glass(head, big, fill)


def magnifier(big, cx, cy, R):
    a = math.radians(45)
    p0 = (cx + R * 0.86 * math.cos(a), cy + R * 0.86 * math.sin(a))
    p1 = (cx + R * 1.75 * math.cos(a), cy + R * 1.75 * math.sin(a))
    hw = R * 0.42
    s = el("path", d=f"M{f(p0[0])} {f(p0[1])}L{f(p1[0])} {f(p1[1])}", stroke="#3d5b78", stroke_width=hw, stroke_linecap="round")
    s += el("path", d=f"M{f(p0[0] - hw * 0.1)} {f(p0[1] - hw * 0.1)}L{f(p1[0] - hw * 0.1)} {f(p1[1] - hw * 0.1)}", stroke="#c9d9e6",
            stroke_width=hw * 0.55, stroke_linecap="round")
    s += el("path", d=cp(cx, cy, R) + cp(cx, cy, R * 0.78), fill="url(#mCh)", fill_rule="evenodd")
    s += el("circle", cx=cx, cy=cy, r=R * 0.78, fill="url(#skyG)")
    if big:
        s += el("circle", cx=cx, cy=cy, r=R * 0.78, fill="url(#hiG)")
        s += el("path", d=f"M{f(cx - R * 0.5)} {f(cy - R * 0.2)}A{f(R * 0.55)} {f(R * 0.55)} 0 0 1 {f(cx - R * 0.1)} {f(cy - R * 0.52)}",
                fill="none", stroke=W, stroke_width=R * 0.08, stroke_linecap="round", opacity=0.85)
    return s


def mark(size_key, x, y, px):
    """The Start mark (dark material) placed at x, y, px units wide."""
    return f'<g transform="translate({f(x)} {f(y)}) scale({f(px / 120)})">{K.start(size_key, halo=False)}</g>'


def crescent(c1, r1, c2, r2):
    d = math.hypot(c2[0] - c1[0], c2[1] - c1[1])
    a = (r1 * r1 - r2 * r2 + d * d) / (2 * d)
    h = math.sqrt(r1 * r1 - a * a)
    ux, uy = (c2[0] - c1[0]) / d, (c2[1] - c1[1]) / d
    px, py = c1[0] + a * ux, c1[1] + a * uy
    p1, p2 = (px - h * uy, py + h * ux), (px + h * uy, py - h * ux)
    return (f"M{f(p1[0])} {f(p1[1])}A{f(r1)} {f(r1)} 0 1 1 {f(p2[0])} {f(p2[1])}"
            f"A{f(r2)} {f(r2)} 0 0 0 {f(p1[0])} {f(p1[1])}Z")


def star(cx, cy, R, r, n=5, rot=-90):
    return pts([(cx + (R if i % 2 == 0 else r) * math.cos(math.radians(rot + i * 180 / n)),
                 cy + (R if i % 2 == 0 else r) * math.sin(math.radians(rot + i * 180 / n))) for i in range(2 * n)])


def sparkle(cx, cy, R):
    return star(cx, cy, R, R * 0.28, 4, -90)


# ---------------------------------------------------------------- the icons
def i_switch(big):
    """Quick Settings and General Behaviour: a lit switch."""
    if big:
        return (metal(rr(8, 34, 104, 52, 26), big) + screen(rr(15, 41, 90, 38, 19), big) + glowf(rr(20, 46, 58, 28, 14), big)
                + el("circle", cx=85, cy=60, r=20, fill="url(#kCh)") + el("circle", cx=85, cy=60, r=17.4, fill="url(#kFace)")
                + el("path", d="M75 46.5A17 17 0 0 1 95 46.5", fill="none", stroke=W, stroke_width=0.8, stroke_linecap="round"))
    return (metal(rr(6, 30, 108, 60, 30), big) + screen(rr(15, 39, 90, 42, 21), big) + glowf(rr(21, 45, 50, 30, 15), big)
            + el("circle", cx=84, cy=60, r=22, fill="url(#kCh)") + el("circle", cx=84, cy=60, r=18.5, fill="url(#kFace)"))


MOUSE = "M60 10C78 10 88 24 88 42V78C88 98 76 110 60 110C44 110 32 98 32 78V42C32 24 42 10 60 10Z"


def i_mouse(big):
    if big:
        return (device(MOUSE, big) + el("path", d="M60 12V46M33.5 48H86.5", fill="none", stroke=W, stroke_opacity=0.22, stroke_width=0.9)
                + screen(rr(54, 21, 12, 22, 6), big) + glowf(rr(57, 24, 6, 14, 3), big))
    return device(MOUSE, big) + el("path", d="M60 13V46", stroke=W, stroke_opacity=0.35, stroke_width=3) + glowf(rr(53, 20, 14, 24, 7), big)


def i_touchpad(big):
    if big:
        return (metal(rr(10, 16, 100, 88, 14), big) + screen(rr(17, 23, 86, 60, 8), big) + groove("M60 87V99", big)
                + glow("M34 70C46 46 70 42 86 52", big, 3.2) + glowf(cp(86, 52, 5), big))
    return (metal(rr(6, 12, 108, 96, 16), big) + screen(rr(15, 21, 90, 64, 10), big) + groove("M60 91V102", big)
            + glowf(cp(48, 53, 8.5), big) + glowf(cp(72, 53, 8.5), big))


ARROW = "M34 10L92 66L64 68L80 102L66 108L50 74L34 92Z"


def i_cursor(big):
    s = glass(ARROW, big)
    if big:
        s += el("path", d="M37 18V84", stroke=W, stroke_opacity=0.5, stroke_width=0.8, stroke_linecap="round")
        s += el("circle", cx=36.5, cy=14.5, r=2.2, fill=W)
    return s


def keys_big(x0, y0, w, rows=((7, 11), (7, 11))):
    """Key caps of a keyboard, lit from below."""
    caps, lights = [], []
    y = y0
    for n, h in rows:
        kw = (w - 2.5 * (n - 1)) / n
        for i in range(n):
            x = x0 + i * (kw + 2.5)
            lights.append(rr(x - 0.5, y - 0.5, kw + 1, h + 1, 2.5))
            caps.append(keycap(x, y, kw, h, True, 2.4))
        y += h + 3
    return y, lights, caps


def i_keyboard(big):
    if big:
        s = device(rr(6, 30, 108, 60, 12), big)
        y, lights, caps = keys_big(14, 38, 92)
        lights.append(rr(34, y - 0.5, 52, 12, 3))
        s += el("path", d="".join(lights), fill=GLOW, filter="url(#glw)", opacity=0.65)
        s += "".join(caps) + keycap(14, y, 17, 11, True, 2.4) + keycap(35, y, 50, 11, True, 2.4) + keycap(89, y, 17, 11, True, 2.4)
        return s
    s = device(rr(4, 28, 112, 64, 12), big)
    for row, y in ((0, 37), (1, 55)):
        for i in range(5):
            s += el("path", d=rr(13 + i * 19.6, y, 15.6, 13, 3), fill="#dcefff")
    return s + el("path", d=rr(30, 73, 60, 11, 3), fill="#dcefff")


def i_shortcut(big):
    """Shortcuts: two keys held together."""
    s = keycap(54, 12, 58, 56, big, 11) + keycap(8, 44, 64, 64, big, 12)
    if big:
        s += el("path", d="M70 34H96", stroke=INK, stroke_opacity=0.45, stroke_width=3, stroke_linecap="round")
        s += el("path", d="M27 85L40 71L53 85", fill="none", stroke=INK, stroke_opacity=0.7, stroke_width=4.5, stroke_linecap="round", stroke_linejoin="round")
    else:
        s += el("path", d="M24 88L40 70L56 88", fill="none", stroke=INK, stroke_width=8, stroke_linecap="round", stroke_linejoin="round")
    return s


def i_vkeyboard(big):
    """The on-screen keyboard: keys of light on a screen."""
    if big:
        s = metal(rr(6, 18, 108, 84, 12), big) + screen(rr(13, 25, 94, 70, 6), big, "wallR")
        s += el("path", d=rr(24, 32, 72, 11, 5.5), fill=W, fill_opacity=0.12) + glow("M30 37.5V37.6", big, 2.4)
        k = "".join(rr(19 + i * 14.2, y, 11.2, 9, 2.5) for y in (52, 65) for i in range(6))
        return s + glowf(k + rr(37, 78, 46, 8, 3), big)
    s = metal(rr(4, 16, 112, 88, 14), big) + screen(rr(12, 24, 96, 72, 8), big, "wallR")
    k = "".join(rr(17 + i * 22.5, y, 18, 12, 3) for y in (40, 58) for i in range(4))
    return s + glowf(k + rr(30, 76, 60, 10, 4), big)


def i_sound(big):
    """The round-7 pilot: a machined speaker."""
    s = ['<circle cx="60" cy="60" r="48" fill="url(#gchD)"/>', '<circle cx="60" cy="60" r="45.5" fill="url(#gfaceD)"/>']
    if big:
        rings = "".join(f'<circle cx="60" cy="60" r="{f(37.5 + 0.8 * j)}" stroke="{W if j % 2 == 0 else "#0a1e32"}" stroke-opacity="{0.1 if j % 2 == 0 else 0.07}"/>' for j in range(10))
        s.append(f'<g fill="none" stroke-width="0.3" clip-path="url(#spkClip)">{rings}</g>')
        for a in (45, 135, 225, 315):
            x, y = 60 + 41.5 * math.cos(math.radians(a)), 60 + 41.5 * math.sin(math.radians(a))
            s.append(f'<circle cx="{f(x)}" cy="{f(y)}" r="2.3" fill="url(#gchInD)"/><circle cx="{f(x)}" cy="{f(y)}" r="1.7" fill="url(#gfaceD)"/>'
                     f'<path d="M{f(x - 1.1)} {f(y)}H{f(x + 1.1)}" stroke="#2c4862" stroke-width="0.5" stroke-linecap="round"/>')
    s.append(f'<circle cx="60" cy="60" r="{36 if big else 37}" fill="url(#surr)"/>')
    if big:
        s.append('<circle cx="60" cy="60" r="34.6" fill="none" stroke="url(#surrHi)" stroke-width="1.6"/>')
    s.append(f'<circle cx="60" cy="60" r="{30 if big else 29}" fill="url(#cone)"/>')
    if big:
        s.append('<g fill="none" stroke="#ffffff" stroke-opacity="0.07" stroke-width="0.6"><circle cx="60" cy="60" r="26"/>'
                 '<circle cx="60" cy="60" r="21.5"/><circle cx="60" cy="60" r="17"/></g>')
    s.append(f'<circle cx="60" cy="60" r="{13 if big else 15}" fill="url(#dome)"/>')
    if big:
        s.append('<ellipse cx="60" cy="52.5" rx="6.5" ry="3" fill="#ffffff" opacity="0.75" filter="url(#soft2)"/>')
    return "".join(s)


def i_note(big):
    """Sound themes: a note of light on a deep disc."""
    w = 4 if big else 8
    g = (glow("M68 32V74M68 32C78 36 86 42 86 54", big, w)
         + glowf('M68 74A11 8.5 -22 1 1 46 82A11 8.5 -22 1 1 68 74Z' if big else 'M70 74A13 10 -22 1 1 44 84A13 10 -22 1 1 70 74Z', big))
    return badge(big, g)


def i_display(big):
    """The round-7 pilot: the screen showing the Start mark."""
    s = ['<path d="M52 81H68L71.5 96H48.5Z" fill="url(#gchD)"/>', '<rect x="34" y="95" width="52" height="7" rx="3.5" fill="url(#gchD)"/>']
    if big:
        s.append('<path d="M38 95.6H82" stroke="#ffffff" stroke-opacity="0.8" stroke-width="0.7" stroke-linecap="round"/>')
    s.append('<rect x="8" y="14" width="104" height="70" rx="9" fill="#0d1a27"/>')
    s.append(f'<rect x="8" y="14" width="104" height="70" rx="9" fill="none" stroke="url(#gchD)" stroke-width="{1.6 if big else 3}"/>')
    s.append(f'<rect x="{13 if big else 15}" y="{19 if big else 21}" width="{94 if big else 90}" height="{60 if big else 56}" rx="4" fill="url(#wallR)"/>')
    if big:
        s.append(mark("M", 45, 34, 30))
        s.append('<rect x="13" y="19" width="94" height="26" rx="4" fill="url(#gloss)"/>')
    else:
        s.append(mark("S", 42, 31, 36))
    return "".join(s)


def i_displays(big):
    """Several screens."""
    return monitor(big, 4, 10, 66, 44, with_stand=False) + monitor(big, 36, 36, 80, 54)


def i_nightlight(big):
    s = glass(crescent((54, 66), 42, (82, 40), 33), big)
    s += glass(sparkle(92, 26, 12 if big else 15), big) + glass(sparkle(108, 54, 7 if big else 10), big)
    return s


def i_daynight(big):
    """The light and dark look through the day: half glass, half night."""
    ri = 44 if big else 41
    s = el("circle", cx=60, cy=60, r=48, fill="url(#mCh)")
    s += el("path", d=f"M60 {60 - ri}A{ri} {ri} 0 0 0 60 {60 + ri}Z", fill="url(#skyG)")
    s += el("path", d=f"M60 {60 - ri}A{ri} {ri} 0 0 1 60 {60 + ri}Z", fill="url(#scrR)")
    if big:
        s += el("path", d=f"M60 {60 - ri}A{ri} {ri} 0 0 0 60 {60 + ri}Z", fill="url(#hiG)")
        s += el("circle", cx=37, cy=60, r=13, fill=W, opacity=0.6, filter="url(#glw)") + el("circle", cx=37, cy=60, r=9, fill=W)
        s += glowf(crescent((84, 60), 12, (91, 53), 10), big)
    else:
        s += el("circle", cx=36, cy=60, r=11, fill=W) + glowf(crescent((84, 60), 14, (92, 52), 11.5), big)
    return s


def i_access(big):
    w = 5.5 if big else 9
    g = el("circle", cx=60, cy=33, r=6.5 if big else 9, fill=CORE if not big else "url(#glowG)")
    if big:
        g = el("circle", cx=60, cy=33, r=8, fill=GLOW, filter="url(#glw)") + g
    g += glow("M34 46L60 51L86 46M60 51V68L47 88M60 68L73 88", big, w)
    return badge(big, g)


PAD = "M34 34H86C102 34 110 48 108 64L105 82C103 96 87 100 79 89L73 80H47L41 89C33 100 17 96 15 82L12 64C10 48 18 34 34 34Z"


def i_gaming(big):
    s = device(PAD, big)
    if big:
        s += metal("M34 47H42V55H50V63H42V71H34V63H26V55H34Z", big, 1.2)
        for dx, dy in ((0, -8), (8, 0), (0, 8), (-8, 0)):
            s += glowf(cp(84 + dx, 59 + dy, 3.8), big)
        s += el("path", d=rr(54, 50, 12, 5, 2.5), fill=W, fill_opacity=0.25)
        return s
    s += metal("M33 45H43V55H53V65H43V75H33V65H23V55H33Z", big, 2)
    return s + glowf(cp(78, 66, 7) + cp(92, 52, 7), big)


def i_tablet(big):
    tip, end = (70, 54), (110, 12)
    dx, dy = end[0] - tip[0], end[1] - tip[1]
    L = math.hypot(dx, dy)
    ux, uy = dx / L, dy / L
    nx, ny = -uy, ux
    hw = 5 if big else 7

    def at(t, w):
        return (tip[0] + ux * t + nx * w, tip[1] + uy * t + ny * w)
    pen = pts([tip, at(12, hw), at(L, hw), at(L, -hw), at(12, -hw)])
    s = device(rr(6, 14, 90, 94, 12), big)
    if big:
        s += el("path", d=rr(16, 24, 70, 74, 6), fill="none", stroke=W, stroke_opacity=0.16, stroke_width=0.8)
        s += glow("M24 88C34 62 50 92 70 54", big, 2.8)
    else:
        s += glow("M22 90C34 60 50 94 70 54", big, 5.5)
    s += metal(pen, big, 1.2 if big else 2.4)
    return s + glowf(cp(tip[0], tip[1], 3.4 if big else 5), big)


def i_touch(big):
    if big:
        return (metal(rr(28, 6, 64, 108, 14), big) + screen(rr(33, 11, 54, 98, 9), big, "wallR")
                + glow(cp(60, 56, 15), big, 2.2) + glowf(cp(60, 56, 6.5), big)
                + el("path", d="M52 103H68", stroke=W, stroke_opacity=0.35, stroke_width=1.4, stroke_linecap="round"))
    return (metal(rr(24, 4, 72, 112, 16), big) + screen(rr(31, 11, 58, 98, 10), big, "wallR")
            + el("circle", cx=60, cy=56, r=18, fill="none", stroke=SOFT, stroke_opacity=0.75, stroke_width=4.5) + glowf(cp(60, 56, 8), big))


def i_bluetooth(big):
    return badge(big, glow("M43 42L77 76L60 93V27L77 44L43 78", big, 5.5 if big else 9))


def i_disks(big):
    if big:
        return (metal(rr(8, 30, 104, 60, 12), big) + el("path", d=rr(18, 40, 36, 14, 4), fill=W, fill_opacity=0.35)
                + screen(rr(18, 66, 84, 14, 7), big) + glowf(cp(91, 73, 3.2), big) + glow("M28 73H58", big, 1.6))
    return metal(rr(6, 26, 108, 68, 14), big) + screen(rr(16, 62, 88, 20, 10), big) + glowf(cp(90, 72, 5.5), big)


def i_printer(big):
    s = el("path", d=rr(30, 8, 60, 40, 3), fill="#f4f9fd", stroke="#9fb9cf", stroke_width=1 if big else 2)
    s += metal(rr(8, 40, 104, 46, 12), big) + screen(rr(20, 70, 80, 8, 4), big)
    s += el("path", d=rr(30, 74, 60, 38, 3), fill=W, stroke="#9fb9cf", stroke_width=1 if big else 2)
    if big:
        s += el("path", d="M40 88H80M40 97H70", stroke="#9cc3e4", stroke_width=2.6, stroke_linecap="round")
        s += glowf(cp(98, 52, 3.4), big)
    else:
        s += el("path", d="M40 90H80", stroke="#7fb2de", stroke_width=5, stroke_linecap="round") + glowf(cp(97, 53, 5.5), big)
    return s


def i_colour(big):
    s = ""
    for (cx, cy), g in (((44, 46), "redR"), ((76, 46), "grnR"), ((60, 74), "bluR")):
        d = cp(cx, cy, 30)
        s += f'<g opacity=".92">{el("path", d=d, fill=f"url(#{g})")}{el("path", d=d, fill="url(#hiG)") if big else ""}</g>'
        s += el("path", d=d, fill="none", stroke="url(#rimG)", stroke_width=1.2 if big else 2.6)
    return s


def i_bolt(big):
    s = glass("M70 6L24 70H57L49 114L96 48H63Z", big)
    if big:
        s += el("path", d="M68 11L30 64", stroke=W, stroke_opacity=0.6, stroke_width=0.9, stroke_linecap="round")
    return s


def i_network(big):
    return globe(big, 60, 60, 48)


def i_connect(big):
    return globe(big, 50, 50, 42) + badge(big, glow("M75 86H97M88 77L97 86L88 95", big, 3.4 if big else 6), 86, 86, 27)


CLOUD = "M30 94A21 21 0 0 1 25 53A29 29 0 0 1 80 41A26 26 0 0 1 95 94Z"


def i_accounts(big):
    s = glass(CLOUD, big)
    if big:
        return s + el("circle", cx=60, cy=63, r=9, fill=W) + el("path", d="M44 91C46 77 74 77 76 91Z", fill=W)
    return s + el("circle", cx=60, cy=62, r=11, fill=W) + el("path", d="M40 93C42 75 78 75 80 93Z", fill=W)


def i_remote(big):
    return (monitor(big, 4, 12, 76, 50)
            + badge(big, glow("M75 78H97L91 72M97 92H75L81 98" if big else "M74 78H98L91 71M98 93H74L81 100", big, 3.2 if big else 5.5), 86, 85, 28))


def i_global_theme(big):
    def inner(x, y, w, h):
        return (el("path", d=rr(x, y, w, h, 3.5), fill="url(#lightS)")
                + el("path", d=f"M{f(x + w / 2)} {f(y)}H{f(x + w - 3.5)}A3.5 3.5 0 0 1 {f(x + w)} {f(y + 3.5)}V{f(y + h - 3.5)}"
                     f"A3.5 3.5 0 0 1 {f(x + w - 3.5)} {f(y + h)}H{f(x + w / 2)}Z", fill="url(#wallR)")
                + (el("path", d=rr(x, y, w, h * 0.4, 3.5), fill="url(#gloss)") if big else ""))
    return monitor(big, 8, 14, 104, 70, inner)


def i_app_style(big):
    s = window(big, 8, 12, 104, 96)
    if big:
        s += el("path", d="M22 50H98", stroke=W, stroke_opacity=0.2, stroke_width=3, stroke_linecap="round") + glow("M22 50H62", big, 3)
        s += keycap(56, 43, 14, 14, big, 7)
        s += el("path", d=rr(22, 70, 14, 14, 3), fill="none", stroke=SOFT, stroke_width=1.6) + glow("M25.5 77L28.5 80L33 74", big, 1.8)
        s += glass(rr(46, 70, 52, 14, 7), big) + el("path", d="M22 96H72", stroke=W, stroke_opacity=0.25, stroke_width=2.4, stroke_linecap="round")
        return s
    s += el("path", d="M22 54H98", stroke=W, stroke_opacity=0.25, stroke_width=6, stroke_linecap="round") + glow("M22 54H60", big, 6)
    s += el("circle", cx=60, cy=54, r=10, fill="url(#kFace)") + glass(rr(22, 74, 76, 20, 10), big)
    return s


def i_decor(big):
    """Window decorations: the title bar and its buttons."""
    tb = 30 if big else 34
    s = window(big, 6, 16, 108, 88, tb)
    for i, x in enumerate((76, 89, 102) if big else (72, 90)):
        r = 4.6 if big else 6.5
        s += el("circle", cx=x, cy=16 + tb / 2, r=r, fill=W, fill_opacity=0.9 if i == (2 if big else 1) else 0.55)
    if big:
        s += el("path", d="M18 31H52", stroke=INK, stroke_opacity=0.35, stroke_width=3, stroke_linecap="round")
    return s


def i_plasma_style(big):
    def inner(x, y, w, h):
        s = screen(rr(x, y, w, h, 3.5), big, "wallR")
        tb = (x + 4, y + h - 17, w - 8, 13) if big else (x + 3, y + h - 22, w - 6, 18)
        s += glass(rr(*tb, tb[3] / 2), big)
        m = tb[3] + (2 if big else 4)
        s += mark("S", tb[0] + 3, tb[1] + tb[3] / 2 - m / 2, m)
        if big:
            s += el("path", d=f"M{f(tb[0] + 26)} {f(tb[1] + 6.5)}H{f(tb[0] + 30)}M{f(tb[0] + 36)} {f(tb[1] + 6.5)}H{f(tb[0] + 40)}",
                    stroke=W, stroke_width=3, stroke_linecap="round", opacity=0.85)
        return s
    return monitor(big, 8, 14, 104, 76, inner, with_stand=False)


def i_icons(big):
    a, b, w = (12, 64, 44) if big else (8, 64, 48)
    return (glass(rr(a, a, w, w, 12), big) + badge(big, glowf(cp(b + w / 2, a + w / 2, w * 0.18), big), b + w / 2, a + w / 2, w / 2)
            + metal(rr(a + 1, b + 1, w - 2, w - 2, 12), big) + glass(cp(b + w / 2, b + w / 2, w / 2), big))


def i_font(big):
    s = glass("M4 108L34 14H50L80 108H62L56 88H28L22 108ZM33 72H51L42 42Z", big, rule="evenodd")
    return s + metal(cp(97, 93, 14) + cp(97, 93, 6.5), big, 1.2 if big else 2.4, "evenodd") + metal(rr(105, 74, 9, 34, 4.5), big, 1.2 if big else 2.4)


def i_wallpaper(big):
    cid = "wpClip" + ("b" if big else "s")
    DEFS.append(f'<clipPath id="{cid}"><path d="{rr(15, 23, 90, 74, 5)}"/></clipPath>')
    s = metal(rr(8, 16, 104, 88, 10), big) + el("path", d=rr(15, 23, 90, 74, 5), fill="url(#picG)")
    s += f'<g clip-path="url(#{cid})">'
    s += el("path", d="M15 78C34 56 52 60 70 72C82 62 96 60 105 64V97H15Z", fill="#2f6fa9", fill_opacity=0.85)
    s += el("path", d="M15 90C36 72 60 74 80 84C90 80 98 80 105 82V97H15Z", fill="url(#deepG)")
    if big:
        s += el("circle", cx=80, cy=43, r=13, fill=W, opacity=0.7, filter="url(#glw)")
    s += el("circle", cx=80, cy=43, r=8 if big else 10, fill=W) + "</g>"
    return s


def i_splash(big):
    s = bezel(8, 14, 104, 88, big, 12) + screen(rr(14, 20, 92, 76, 7), big)
    if big:
        s += mark("M", 39, 28, 42) + el("path", d=rr(36, 82, 48, 4, 2), fill=W, fill_opacity=0.15) + glowf(rr(36, 82, 30, 4, 2), big)
    else:
        s += mark("S", 35, 22, 50) + el("path", d=rr(30, 80, 60, 7, 3.5), fill=W, fill_opacity=0.2) + glowf(rr(30, 80, 36, 7, 3.5), big)
    return s


def i_anim(big):
    w = 6 if big else 9
    s = "".join(el("path", d=d, stroke=GLOW, stroke_opacity=op, stroke_width=w, stroke_linecap="round")
                for d, op in (("M10 44H34", 0.55), ("M4 60H38", 0.85), ("M10 76H34", 0.55)))
    s += el("circle", cx=74, cy=60, r=32, fill="url(#sphR)")
    if big:
        s += el("ellipse", cx=64, cy=44, rx=11, ry=5.5, fill=W, opacity=0.6, filter="url(#glw)")
    return s + el("circle", cx=74, cy=60, r=32, fill="none", stroke="url(#rimG)", stroke_width=1.2 if big else 2.6)


def i_effects(big):
    s = glass(sparkle(58, 62, 50), big)
    if big:
        s += el("path", d="M58 14V110M10 62H106", stroke=W, stroke_opacity=0.45, stroke_width=0.8, stroke_linecap="round")
    return s + glass(sparkle(98, 20, 13 if big else 16), big) + glass(sparkle(20, 100, 9 if big else 13), big)


BELL = "M60 16C41 16 31 31 31 50V70L20 84H100L89 70V50C89 31 79 16 60 16Z"


def i_bell(big):
    s = metal(cp(60, 13, 5), big, 1.4 if big else 2.4) + metal(BELL, big)
    s += el("path", d="M48 86A12 12 0 0 0 72 86Z", fill="url(#mCh)")
    if big:
        s += el("path", d="M49 24C42 30 40 40 40 50V68", fill="none", stroke=W, stroke_opacity=0.7, stroke_width=2.4, stroke_linecap="round", filter="url(#glw)")
        s += el("circle", cx=92, cy=26, r=13, fill=GLOW, opacity=0.6, filter="url(#glw)")
        s += el("circle", cx=92, cy=26, r=10, fill="url(#glowG)") + el("circle", cx=92, cy=26, r=10, fill="none", stroke=GLOW, stroke_width=1)
    else:
        s += el("circle", cx=92, cy=26, r=13, fill=GLOW) + el("circle", cx=92, cy=26, r=8, fill=CORE)
    return s


def i_activities(big):
    return (glass(rr(42, 10, 68, 52, 9), big, "deepG") + glass(rr(26, 32, 68, 52, 9), big, "deepG")
            + glass(rr(10, 56, 68, 52, 9), big))


def i_defaults(big):
    a, b, w = (12, 64, 44) if big else (8, 64, 48)
    return (glass(rr(a, a, w, w, 12), big) + glass(rr(b, a, w, w, 12), big, "deepG") + glass(rr(a, b, w, w, 12), big, "deepG")
            + glass(star(b + w / 2, b + w / 2 + 2, w * 0.58, w * 0.25), big))


def i_vdesk(big):
    a, b, w, h = (8, 62, 50, 42) if big else (6, 62, 52, 46)
    y2 = a + h + (10 if big else 8)
    s = glass(rr(a, a + 4, w, h, 7), big)
    for x, y in ((b, a + 4), (a, y2), (b, y2)):
        s += el("path", d=rr(x, y, w, h, 7), fill="url(#scrR)", stroke="url(#mCh)", stroke_width=1.6 if big else 3)
    return s


def i_windows(big):
    return window(big, 34, 10, 78, 58) + window(big, 8, 40, 80, 68)


def i_win_actions(big):
    return (window(big, 30, 8, 80, 56) + window(big, 6, 36, 76, 64)
            + badge(big, glow("M76 88H98M87 77V99", big, 3.6 if big else 6), 87, 88, 26))


SHIELD = "M60 8L102 22V54C102 82 84 100 60 112C36 100 18 82 18 54V22Z"
SHIELD_IN = "M60 18L92 29V55C92 77 78 91 60 101C42 91 28 77 28 55V29Z"


def i_security(big):
    return metal(SHIELD, big) + screen(SHIELD_IN, big) + glow("M42 58L55 71L79 45", big, 6 if big else 10)


def i_padlock(big):
    s = el("path", d="M36 54V38A24 24 0 0 1 84 38V54", fill="none", stroke="#3d5b78", stroke_width=13 if big else 15, stroke_linecap="round")
    s += el("path", d="M36 54V38A24 24 0 0 1 84 38V54", fill="none", stroke="url(#mFace)", stroke_width=9 if big else 10, stroke_linecap="round")
    s += metal(rr(20, 50, 80, 60, 12), big)
    if big:
        return s + screen(rr(48, 64, 24, 32, 12), big) + glowf(cp(60, 76, 4.6) + rr(57.6, 76, 4.8, 12, 2.4), big)
    return s + screen(rr(46, 62, 28, 36, 14), big) + glowf(cp(60, 75, 6) + rr(56.5, 75, 7, 14, 3.5), big)


def i_login(big):
    s = metal(rr(48, 8, 62, 104, 10), big) + screen(rr(56, 16, 46, 88, 5), big)
    s += glowf(cp(94, 62, 3.5 if big else 5), big)
    return s + glass("M6 50H34V36L62 60L34 84V70H6Z", big)


def i_users(big):
    return bust(big, 80, 10, 0.78, "deepG") + bust(big, 46, 30, 0.95)


def i_user(big):
    return bust(big, 60, 10, 1.25)


def i_power(big):
    s = metal(rr(104, 48, 10, 24, 4), big, 1.4 if big else 2.4) + metal(rr(6, 30, 100, 60, 12), big) + screen(rr(14, 38, 84, 44, 7), big)
    s += glowf(rr(19, 43, 54, 34, 4.5), big)
    return s + el("path", d="M54 46L40 64H51L46 78L64 58H53Z", fill="#0f3a63")


def i_search(big):
    return magnifier(big, 48, 48, 36)


FOLDER_BACK = "M14 35Q14 28 21 28H40L46 21Q47.5 19.5 50 19.5H70Q72.5 19.5 74 21L80 28H99Q106 28 106 35V90Q106 97 99 97H21Q14 97 14 90Z"
FOLDER_FRONT = "M12 50Q12 45 17 45H103Q108 45 108 50V91Q108 98 101 98H19Q12 98 12 91Z"


def i_filesearch(big):
    s = glass(FOLDER_BACK, big, "deepG") + el("path", d=rr(24, 32, 72, 34, 3), fill=W) + glass(FOLDER_FRONT, big)
    return s + magnifier(big, 74, 74, 22)


def i_locale(big):
    s = globe(big, 50, 50, 42)
    s += el("circle", cx=86, cy=86, r=27, fill="url(#mCh)") + el("circle", cx=86, cy=86, r=23.5 if big else 22, fill="url(#mFace)")
    s += el("path", d="M86 72V86L96 92", fill="none", stroke="#1f3a55", stroke_width=3.2 if big else 5.5, stroke_linecap="round", stroke_linejoin="round")
    if big:
        s += "".join(el("circle", cx=86 + 19 * math.cos(math.radians(a)), cy=86 + 19 * math.sin(math.radians(a)), r=1.3, fill="#3d5b78") for a in range(0, 360, 90))
    return s


BUBBLE = "M26 16H94A18 18 0 0 1 112 34V70A18 18 0 0 1 94 88H54L30 108V88H26A18 18 0 0 1 8 70V34A18 18 0 0 1 26 16Z"


def i_feedback(big):
    r = 6 if big else 8.5
    return glass(BUBBLE, big) + "".join(el("circle", cx=x, cy=54, r=r, fill=W) for x in (36, 60, 84))


def i_services(big):
    """Background services: a rack of machined units with their lights (no gear)."""
    s = ""
    for i, y in enumerate((12, 46, 80) if big else (10, 45, 80)):
        h = 28 if big else 30
        s += metal(rr(12, y, 96, h, 7), big) + screen(rr(20, y + h / 2 - (4 if big else 5.5), 50, 8 if big else 11, 4 if big else 5.5), big)
        s += glowf(cp(90, y + h / 2, 3.6 if big else 5.5), big)
    return s


def i_peripherals(big):
    s = device(rr(4, 52, 74, 46, 10), big)
    if big:
        caps = "".join(keycap(11 + i * 12.6, y, 10, 9, True, 2) for y in (59, 71) for i in range(5)) + keycap(24, 83, 34, 8, True, 2)
        s += caps
    else:
        s += el("path", d="".join(rr(11 + i * 17, y, 13, 11, 2.5) for y in (60, 76) for i in range(4)), fill="#dcefff")
    s += device("M98 26C110 26 116 36 116 48V74C116 88 108 96 98 96C88 96 80 88 80 74V48C80 36 86 26 98 26Z", big)
    return s + glowf(rr(95, 33, 6, 14, 3) if big else rr(93.5, 32, 9, 17, 4.5), big)


def i_multimedia(big):
    return badge(big, glowf("M48 36L82 60L48 84Z" if big else "M46 34L84 60L46 86Z", big))


ICONS = {
    "preferences-desktop": i_switch,
    "preferences-desktop-mouse": i_mouse, "input-mouse": i_mouse,
    "preferences-desktop-touchpad": i_touchpad,
    "preferences-desktop-cursors": i_cursor,
    "preferences-desktop-keyboard": i_keyboard, "input-keyboard": i_keyboard,
    "preferences-desktop-keyboard-shortcut": i_shortcut,
    "input-keyboard-virtual": i_vkeyboard,
    "preferences-desktop-sound": i_sound,
    "media-optical-audio": i_note,
    "preferences-desktop-display": i_display,
    "preferences-desktop-display-randr": i_displays,
    "redshift-status-on": i_nightlight,
    "lighttable": i_daynight,
    "preferences-desktop-accessibility": i_access,
    "preferences-desktop-gaming": i_gaming,
    "preferences-desktop-tablet": i_tablet,
    "preferences-desktop-touchscreen": i_touch,
    "preferences-system-bluetooth": i_bluetooth,
    "preferences-system-disks": i_disks,
    "preferences-devices-printer": i_printer,
    "preferences-desktop-color": i_colour,
    "preferences-desktop-thunderbolt": i_bolt,
    "preferences-system-network": i_network, "preferences-system-network-connection": i_network,
    "preferences-system-network-share": i_network,
    "network-connect": i_connect,
    "preferences-online-accounts": i_accounts,
    "preferences-system-network-remote": i_remote,
    "preferences-desktop-theme-global": i_global_theme,
    "preferences-desktop-theme-applications": i_app_style,
    "preferences-desktop-theme-windowdecorations": i_decor,
    "preferences-desktop-plasma-theme": i_plasma_style,
    "preferences-desktop-icons": i_icons,
    "preferences-desktop-font": i_font,
    "preferences-desktop-wallpaper": i_wallpaper,
    "preferences-system-splash": i_splash,
    "preferences-desktop-animations": i_anim,
    "preferences-desktop-effects": i_effects,
    "preferences-desktop-notification-bell": i_bell,
    "preferences-desktop-activities": i_activities,
    "preferences-desktop-default-applications": i_defaults,
    "preferences-desktop-virtual": i_vdesk,
    "preferences-system-windows": i_windows,
    "preferences-system-windows-actions": i_win_actions,
    "preferences-security": i_security,
    "preferences-desktop-user-password": i_padlock,
    "preferences-system-login": i_login,
    "preferences-system-users": i_users,
    "preferences-desktop-user": i_user,
    "preferences-system-power-management": i_power,
    "preferences-desktop-search": i_search, "plasma-search": i_search,
    "preferences-desktop-baloo": i_filesearch,
    "preferences-desktop-locale": i_locale,
    "preferences-desktop-feedback": i_feedback,
    "preferences-system-session-services": i_services,
    "preferences-desktop-peripherals": i_peripherals,
    "preferences-desktop-multimedia": i_multimedia,
}
NOTE = "ArkadeOS Glass System Settings icon, generated by art/glass-settings-icons.py (glass_craft): edit the generator, not this file."

if __name__ == "__main__":
    apps = os.path.join(out, "arkadeos-glass", "apps")
    drawn = {}
    for folder, big in (("scalable", True), ("small", False)):
        d = os.path.join(apps, folder)
        os.makedirs(d, exist_ok=True)
        for name, draw in ICONS.items():
            if (draw, big) not in drawn:
                body = draw(big)
                text = K.standalone(body, "dk", size=96 if big else 32, comment=NOTE, extra_defs=DEFS)
                assert not re.search(r"url\(#([^)]+)\)", text) or all(
                    f'id="{i}"' in text for i in re.findall(r"url\(#([^)]+)\)", text)), name
                drawn[(draw, big)] = text
            open(os.path.join(d, name + ".svg"), "w").write(drawn[(draw, big)])
    print(len(ICONS), "settings icons")
