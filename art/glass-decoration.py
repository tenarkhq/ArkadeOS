"""ArkadeOS Glass window frame (T086): an Aurorae theme per look, dark and
light, as Roland picked it on 2026-11-13 (https://claude.ai/artifact/A9QNLgyxWb3rFxzpJJBJs8):
a glass title bar and border in the sky-blue glass, a dark outer rim and a
light inner one, and the three window buttons as one glass capsule on the
right, its close part red on the active window.

The glass colours come from the design's layers: the glass tint (96,170,232
at 35%) under a dark (28% black) or light (35% white) veil, folded into one
colour with its own alpha, so the frame matches the design over the same
background. KWin blurs what lies behind it (Better Blur DX).

Usage: glass-decoration.py <themes folder>  (writes ArkadeOS-Glass-Dark and -Light)"""
import base64
import math
import os
import re
import struct
import sys
import zlib

T = (96, 170, 232)
ALPHA, ACTIVE_FACTOR, INACTIVE_FACTOR = 0.35, 1.0, 0.72


def fold(tint_a, veil, veil_a):
    """One RGBA for 'veil over tint over background'."""
    keep = (1 - veil_a) * (1 - tint_a)          # share of the background left
    a = 1 - keep
    c = [(veil_a * veil + (1 - veil_a) * tint_a * t) / a for t in T]
    return tuple(round(x) for x in c), round(a, 3)


LOOKS = {
    "Dark": {"active": fold(ALPHA, 0, 0.28), "inactive": fold(ALPHA * INACTIVE_FACTOR, 0, 0.36),
             "text": "#ffffff", "text_inactive": "#c3cbd6", "glyph": "#ffffff", "glyph_inactive": "#c3cbd6"},
    "Light": {"active": fold(ALPHA, 255, 0.35), "inactive": fold(ALPHA * INACTIVE_FACTOR, 255, 0.43),
              "text": "#10161f", "text_inactive": "#4a5260", "glyph": "#10161f", "glyph_inactive": "#4a5260"},
}
TOP, SIDE, BOTTOM, R_TOP, R_BOTTOM = 34, 7, 7, 7, 6
# The window's shadow (the design's 0 16px 44px rgba(0,0,0,.45), made to fit
# the frame engine): a box shadow of the frame grown by SPREAD, shifted down
# by DY, blurred by SIGMA, drawn in the frame's padding, which KWin turns into
# the window's shadow (outside the window, under nothing).
SIGMA, SPREAD, DY = 12, 8, 12
SHADOW_ACTIVE, SHADOW_INACTIVE = 0.42, 0.30
PAD_SIDE = 3 * SIGMA + SPREAD
PAD_TOP = PAD_SIDE - DY
PAD_BOTTOM = PAD_SIDE + DY
DARK_RIM, LIGHT_RIM, EDGE = "rgba(0,0,0,0.55)", "rgba(255,255,255,0.38)", "rgba(0,0,0,0.45)"


def phi(x):
    return 0.5 * (1 + math.erf(x / math.sqrt(2)))


def png(w, h, alpha):
    """A black image with the given alpha (a function of x, y in pixels), as a data URI."""
    rows = []
    for y in range(h):
        row = bytearray(b"\x00")
        for x in range(w):
            a = max(0, min(255, round(255 * alpha(x + 0.5, y + 0.5))))
            row += bytes((0, 0, 0, a))
        rows.append(bytes(row))
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    data = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b""))
    return "data:image/png;base64," + base64.b64encode(data).decode()


def shadow_alpha(strength, u, v, kind):
    """The shadow's alpha at a point u px outward from the frame's side edge
    and v px outward from its top or bottom edge (negative: inside). kind is
    'top' or 'bottom': the shadow sits DY lower than the frame."""
    if u <= 0 and v <= 0:
        return 0.0
    fx = phi((SPREAD - u) / SIGMA)
    fy = phi((SPREAD - DY - v) / SIGMA) if kind == "top" else phi((SPREAD + DY - v) / SIGMA)
    return strength * fx * fy


def image(x, y, w, h, alpha):
    return f'<image x="{x}" y="{y}" width="{w}" height="{h}" xlink:href="{png(w, h, alpha)}"/>'


def rgba(c, a):
    return f"rgba({c[0]},{c[1]},{c[2]},{a})"


def corner(x, y, w, h, r, top, right, inset0, inset1):
    """A band of the frame's edge between two insets (0 = the outer edge),
    around one rounded corner of the box (x, y, w, h): filled, no strokes,
    so every piece keeps its exact size."""
    def pt(u, v):  # u, v: distance from the corner's outer edges, inward
        return (x + w - u if right else x + u, y + v if top else y + h - v)

    def arc(rad, u, v, clockwise):
        X, Y = pt(u, v)
        sweep = clockwise ^ right ^ (not top)
        return f"A{rad},{rad} 0 0 {int(sweep)} {X:g},{Y:g}"

    a, b = inset0, inset1
    sx, sy = pt(a, h if top else h)
    d = [f"M{pt(a, h)[0]:g},{pt(a, h)[1]:g}", f"L{pt(a, r)[0]:g},{pt(a, r)[1]:g}", arc(r - a, r, a, True),
         f"L{pt(w, a)[0]:g},{pt(w, a)[1]:g}"]
    if b is None:  # the whole corner, filled to its inner side
        d += [f"L{pt(w, h)[0]:g},{pt(w, h)[1]:g}", "Z"]
    else:
        d += [f"L{pt(w, b)[0]:g},{pt(w, b)[1]:g}", f"L{pt(r, b)[0]:g},{pt(r, b)[1]:g}", arc(r - b, b, r, False),
              f"L{pt(b, h)[0]:g},{pt(b, h)[1]:g}", "Z"]
    return " ".join(d)


def frame(prefix, glass, x0, y0, strength):
    """The nine pieces of one frame state, laid out from (x0, y0): the frame,
    and around it, in the padding, its shadow."""
    g = rgba(*glass)
    s, t, b = SIDE, TOP, BOTTOM
    PL, PT, PB = PAD_SIDE, PAD_TOP, PAD_BOTTOM
    INF = 10 ** 6
    out = []

    def piece(name, x, y, w, h, body):
        out.append(f'<g id="{prefix}-{name}"><rect x="{x}" y="{y}" width="{w}" height="{h}" fill="none"/>{body}</g>')

    def rounded(x, y, w, h, r, top, right):
        return (f'<path d="{corner(x, y, w, h, r, top, right, 0, None)}" fill="{g}"/>'
                f'<path d="{corner(x, y, w, h, r, top, right, 0, 1)}" fill="{DARK_RIM}"/>'
                f'<path d="{corner(x, y, w, h, r, top, right, 1, 2)}" fill="{LIGHT_RIM}"/>')

    W1, H1 = PL + s, PT + t       # top corners
    H3 = b + PB                   # bottom corners
    # top row
    piece("topleft", x0, y0, W1, H1,
          image(x0, y0, W1, H1, lambda x, y: shadow_alpha(strength, PL - x, PT - y, "top"))
          + rounded(x0 + PL, y0 + PT, s, t, R_TOP, True, False)
          + f'<rect x="{x0 + PL + s - 1}" y="{y0 + PT + t - 1}" width="1" height="1" fill="{EDGE}"/>')
    x = x0 + W1 + 2
    piece("top", x, y0, 1, H1,
          image(x, y0, 1, H1, lambda _x, y: shadow_alpha(strength, -INF, PT - y, "top"))
          + f'<rect x="{x}" y="{y0 + PT}" width="1" height="{t}" fill="{g}"/><rect x="{x}" y="{y0 + PT}" width="1" height="1" fill="{DARK_RIM}"/>'
          f'<rect x="{x}" y="{y0 + PT + 1}" width="1" height="1" fill="{LIGHT_RIM}"/><rect x="{x}" y="{y0 + PT + t - 1}" width="1" height="1" fill="{EDGE}"/>')
    x = x0 + W1 + 5
    piece("topright", x, y0, W1, H1,
          image(x, y0, W1, H1, lambda xx, y: shadow_alpha(strength, xx - s, PT - y, "top"))
          + rounded(x, y0 + PT, s, t, R_TOP, True, True)
          + f'<rect x="{x}" y="{y0 + PT + t - 1}" width="1" height="1" fill="{EDGE}"/>')
    # the sides
    y = y0 + H1 + 2
    piece("left", x0, y, W1, 1,
          image(x0, y, W1, 1, lambda xx, _y: shadow_alpha(strength, PL - xx, -INF, "top"))
          + f'<rect x="{x0 + PL}" y="{y}" width="{s}" height="1" fill="{g}"/><rect x="{x0 + PL}" y="{y}" width="1" height="1" fill="{DARK_RIM}"/>'
          f'<rect x="{x0 + PL + 1}" y="{y}" width="1" height="1" fill="{LIGHT_RIM}"/><rect x="{x0 + PL + s - 1}" y="{y}" width="1" height="1" fill="{EDGE}"/>')
    piece("center", x0 + W1 + 2, y, 1, 1, "")
    x = x0 + W1 + 5
    piece("right", x, y, W1, 1,
          image(x, y, W1, 1, lambda xx, _y: shadow_alpha(strength, xx - s, -INF, "top"))
          + f'<rect x="{x}" y="{y}" width="{s}" height="1" fill="{g}"/><rect x="{x + s - 1}" y="{y}" width="1" height="1" fill="{DARK_RIM}"/>'
          f'<rect x="{x + s - 2}" y="{y}" width="1" height="1" fill="{LIGHT_RIM}"/><rect x="{x}" y="{y}" width="1" height="1" fill="{EDGE}"/>')
    # the foot
    y = y0 + H1 + 5
    piece("bottomleft", x0, y, W1, H3,
          image(x0, y, W1, H3, lambda xx, yy: shadow_alpha(strength, PL - xx, yy - b, "bottom"))
          + rounded(x0 + PL, y, s, b, R_BOTTOM, False, False)
          + f'<rect x="{x0 + PL + s - 1}" y="{y}" width="1" height="1" fill="{EDGE}"/>')
    x = x0 + W1 + 2
    piece("bottom", x, y, 1, H3,
          image(x, y, 1, H3, lambda _x, yy: shadow_alpha(strength, -INF, yy - b, "bottom"))
          + f'<rect x="{x}" y="{y}" width="1" height="{b}" fill="{g}"/><rect x="{x}" y="{y}" width="1" height="1" fill="{EDGE}"/>'
          f'<rect x="{x}" y="{y + b - 2}" width="1" height="1" fill="{LIGHT_RIM}"/><rect x="{x}" y="{y + b - 1}" width="1" height="1" fill="{DARK_RIM}"/>')
    x = x0 + W1 + 5
    piece("bottomright", x, y, W1, H3,
          image(x, y, W1, H3, lambda xx, yy: shadow_alpha(strength, xx - s, yy - b, "bottom"))
          + rounded(x, y, s, b, R_BOTTOM, False, True)
          + f'<rect x="{x}" y="{y}" width="1" height="1" fill="{EDGE}"/>')
    return out


def maximized(prefix, glass, x0, y0):
    """A maximized window: a straight glass bar, no border."""
    g = rgba(*glass)
    return [f'<g id="{prefix}-center"><rect x="{x0}" y="{y0}" width="1" height="{TOP}" fill="{g}"/>'
            f'<rect x="{x0}" y="{y0 + TOP - 1}" width="1" height="1" fill="{EDGE}"/></g>']


def decoration_svg(look):
    act, ina = LOOKS[look]["active"], LOOKS[look]["inactive"]
    span = 2 * (PAD_SIDE + SIDE) + 10
    parts = frame("decoration", act, 0, 0, SHADOW_ACTIVE) + frame("decoration-inactive", ina, span, 0, SHADOW_INACTIVE) \
        + maximized("decoration-maximized", act, 2 * span, 0) + maximized("decoration-maximized-inactive", ina, 2 * span + 10, 0)
    w, h = 2 * span + 20, PAD_TOP + TOP + PAD_BOTTOM + BOTTOM + 10
    return (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{w}" height="{h}" '
            f'viewBox="0 0 {w} {h}">{"".join(parts)}</svg>\n')


BW, BH = 34, 22


def capsule(shape, fill, y=0):
    """One part of the button capsule at height y: 'left' (round left end),
    'mid', 'right' (round right end); a separator on the left of mid and right.
    Absolute coordinates: the frame engine reads each state's box as drawn."""
    r = BH / 2
    top, bot = y + 0.5, y + BH - 0.5
    # the rim is drawn open where the parts meet, so no stroke runs over a part's box
    if shape == "left":
        rim = f"M{BW},{top} H{r} A{r - 0.5},{r - 0.5} 0 0 0 {r},{bot} H{BW}"
    elif shape == "right":
        rim = f"M0,{top} H{BW - r} A{r - 0.5},{r - 0.5} 0 0 1 {BW - r},{bot} H0"
    else:
        rim = f"M0,{top} H{BW} M0,{bot} H{BW}"
    d = rim.replace(" M0,", " L0,") + " Z" if shape != "mid" else f"M0,{top} H{BW} V{bot} H0 Z"
    body = f'<path d="{d}" fill="{fill}"/><path d="{rim}" fill="none" stroke="rgba(255,255,255,0.38)" stroke-width="1"/>'
    if shape != "left":
        body += f'<rect x="0" y="{y + 1}" width="1" height="{BH - 2}" fill="rgba(255,255,255,0.25)"/>'
    return body


def glyph(kind, colour, y=0):
    cx, cy = BW / 2, y + BH / 2
    if kind == "minimize":
        return f'<rect x="{cx - 4.5}" y="{cy - 0.8}" width="9" height="1.6" rx="0.8" fill="{colour}"/>'
    if kind == "maximize":
        return f'<rect x="{cx - 4}" y="{cy - 4}" width="8" height="8" rx="2" fill="none" stroke="{colour}" stroke-width="1.5"/>'
    if kind == "restore":
        return (f'<rect x="{cx - 4.5}" y="{cy - 2}" width="6.5" height="6.5" rx="1.5" fill="none" stroke="{colour}" stroke-width="1.4"/>'
                f'<path d="M{cx - 2},{cy - 4} H{cx + 3} Q{cx + 4.5},{cy - 4} {cx + 4.5},{cy - 2.5} V{cy + 2}" fill="none" stroke="{colour}" stroke-width="1.4"/>')
    return (f'<path d="M{cx - 4.5},{cy - 4.5} L{cx + 4.5},{cy + 4.5} M{cx + 4.5},{cy - 4.5} L{cx - 4.5},{cy + 4.5}" '
            f'stroke="{colour}" stroke-width="1.6" stroke-linecap="round"/>')


def button_svg(kind, look):
    L = LOOKS[look]
    shape = {"minimize": "left", "maximize": "mid", "restore": "mid", "close": "right"}[kind]
    states = []
    for i, (state, fill, gcol) in enumerate([
            ("active", "rgba(255,255,255,0.12)", L["glyph"]),
            ("hover", "rgba(255,255,255,0.26)", L["glyph"]),
            ("pressed", "rgba(255,255,255,0.06)", L["glyph"]),
            ("inactive", "rgba(255,255,255,0.08)", L["glyph_inactive"]),
            ("hover-inactive", "rgba(255,255,255,0.22)", L["glyph"]),
            ("deactivated", "rgba(255,255,255,0.05)", L["glyph_inactive"])]):
        g = gcol
        if kind == "close" and state in ("active", "hover", "pressed"):
            fill = {"active": "rgba(226,70,70,0.80)", "hover": "rgba(240,88,80,0.92)", "pressed": "rgba(190,50,45,0.9)"}[state]
            g = "#ffffff"
        if kind == "close" and state == "hover-inactive":
            fill, g = "rgba(226,70,70,0.70)", "#ffffff"
        y = i * (BH + 4)
        states.append(f'<g id="{state}-center"><rect x="0" y="{y}" width="{BW}" height="{BH}" fill="none"/>'
                      f'{capsule(shape, fill, y)}{glyph(kind, g, y)}</g>')
    h = 6 * (BH + 4)
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{BW}" height="{h}" viewBox="0 0 {BW} {h}">{"".join(states)}</svg>\n'


def rc(look):
    L = LOOKS[look]
    return f"""[General]
ActiveTextColor={L["text"]}
InactiveTextColor={L["text_inactive"]}
TitleAlignment=Left
TitleVerticalAlignment=Center
Animation=150
DecorationPosition=0

[Layout]
BorderLeft={SIDE}
BorderRight={SIDE}
BorderBottom={BOTTOM}
BorderLeftMaximized=0
BorderRightMaximized=0
BorderBottomMaximized=0
TitleEdgeTop=6
TitleEdgeBottom=6
TitleEdgeLeft=10
TitleEdgeRight=6
TitleEdgeTopMaximized=6
TitleEdgeBottomMaximized=6
TitleEdgeLeftMaximized=10
TitleEdgeRightMaximized=6
TitleBorderLeft=6
TitleBorderRight=10
TitleHeight={BH}
ButtonWidth={BW}
ButtonHeight={BH}
ButtonSpacing=0
ButtonMarginTop=0
ButtonMarginTopMaximized=0
ExplicitButtonSpacer=8
PaddingTop={PAD_TOP}
PaddingBottom={PAD_BOTTOM}
PaddingLeft={PAD_SIDE}
PaddingRight={PAD_SIDE}
"""


def metadata(look):
    return f"""[Desktop Entry]
Name=ArkadeOS Glass {"Sötét" if look == "Dark" else "Világos"}
Name[en]=ArkadeOS Glass {look}
Comment=ArkadeOS: sky-blue glass frame with a button capsule
X-KDE-PluginInfo-Author=ArkadeOS
X-KDE-PluginInfo-Name=ArkadeOS-Glass-{look}
X-KDE-PluginInfo-Version=1.0
X-KDE-PluginInfo-License=GPL-2.0-or-later
X-KDE-PluginInfo-Category=
X-KDE-PluginInfo-Depends=
X-KDE-PluginInfo-EnabledByDefault=true
"""


def plain(svg):
    """Qt's SVG renderer takes no rgba(): a hex colour and an opacity instead."""
    def sub(m):
        r, g, b, a = (float(x) for x in m.group(2).split(","))
        return f'{m.group(1)}="#{int(r):02x}{int(g):02x}{int(b):02x}" {m.group(1)}-opacity="{a:g}"'
    return re.sub(r'(fill|stroke)="rgba\(([^)]*)\)"', sub, svg)


root = sys.argv[1]
for look in LOOKS:
    d = os.path.join(root, f"ArkadeOS-Glass-{look}")
    os.makedirs(d, exist_ok=True)
    open(os.path.join(d, "decoration.svg"), "w").write(plain(decoration_svg(look)))
    for kind in ("minimize", "maximize", "restore", "close"):
        open(os.path.join(d, f"{kind}.svg"), "w").write(plain(button_svg(kind, look)))
    open(os.path.join(d, f"ArkadeOS-Glass-{look}rc"), "w").write(rc(look))
    open(os.path.join(d, "metadata.desktop"), "w").write(metadata(look))
    print(look, "active", LOOKS[look]["active"], "inactive", LOOKS[look]["inactive"])
