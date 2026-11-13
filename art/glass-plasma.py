"""ArkadeOS Glass Plasma style pieces (T086): the taskbar "C" Roland picked on
2026-11-13 (https://claude.ai/artifact/A9QNLgyxWb3rFxzpJJBJs8): a thin glass bar
whose top edge is lit in the glass colour, with a soft glow above it, and the
running apps marked by a lit line under their icon (longer and brighter
under the active one).

Writes panel-background.svg and tasks.svg per look; the build gzips them into
the ArkadeOS Glass Plasma styles (build_files/70-theme.sh), which are Breeze's
own otherwise. The glass colour is the window frame's (art/glass-decoration.py).
Usage: glass-plasma.py <out folder>"""
import os
import sys

T = (96, 170, 232)
LOOKS = {"dark": ((45, 81, 110), 0.532), "light": ((192, 222, 246), 0.577)}


def hexc(c):
    return "#%02x%02x%02x" % tuple(c)


def piece(pid, x, y, w, h, body=""):
    return f'<g id="{pid}"><rect x="{x}" y="{y}" width="{w}" height="{h}" fill="none"/>{body}</g>'


def rect(x, y, w, h, c, a):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{hexc(c)}" fill-opacity="{a:g}"/>'


def panel(look):
    glass, ga = LOOKS[look]
    out = []
    # The bar: glass everywhere; the top edge lit (2 px), the other edges plain
    # (a bottom panel shows only its top edge).
    E = 2
    out.append(piece("topleft", 0, 0, 2, E, rect(0, 0, 2, 1, T, 0.95) + rect(0, 1, 2, 1, glass, ga)))
    out.append(piece("top", 4, 0, 1, E, rect(4, 0, 1, 1, T, 0.95) + rect(4, 1, 1, 1, glass, ga)))
    out.append(piece("topright", 7, 0, 2, E, rect(7, 0, 2, 1, T, 0.95) + rect(7, 1, 2, 1, glass, ga)))
    out.append(piece("left", 0, 4, 2, 1, rect(0, 4, 2, 1, glass, ga)))
    out.append(piece("center", 4, 4, 1, 1, rect(4, 4, 1, 1, glass, ga)))
    out.append(piece("right", 7, 4, 2, 1, rect(7, 4, 2, 1, glass, ga)))
    out.append(piece("bottomleft", 0, 7, 2, 2, rect(0, 7, 2, 2, glass, ga)))
    out.append(piece("bottom", 4, 7, 1, 2, rect(4, 7, 1, 2, glass, ga)))
    out.append(piece("bottomright", 7, 7, 2, 2, rect(7, 7, 2, 2, glass, ga)))
    # The blur goes under the whole bar.
    for name, (x, y, w, h) in {"mask-topleft": (20, 0, 2, 2), "mask-top": (24, 0, 1, 2), "mask-topright": (27, 0, 2, 2),
                               "mask-left": (20, 4, 2, 1), "mask-center": (24, 4, 1, 1), "mask-right": (27, 4, 2, 1),
                               "mask-bottomleft": (20, 7, 2, 2), "mask-bottom": (24, 7, 1, 2), "mask-bottomright": (27, 7, 2, 2)}.items():
        out.append(piece(name, x, y, w, h, f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#000000"/>'))
    # Contents sit 3 px in from the lit edge, flush with the screen's edges.
    for side, size in (("top", 3), ("bottom", 0), ("left", 4), ("right", 4)):
        out.append(f'<rect id="hint-{side}-margin" x="40" y="{len(out)}" width="{size if side in ("left", "right") else 1}" '
                   f'height="{size if side in ("top", "bottom") else 1}" fill="none"/>')
    # The glow above the bar: a shadow in the glass colour, 10 px, fading out.
    G = 10
    grad = (f'<defs><linearGradient id="glow" x1="0" y1="1" x2="0" y2="0">'
            f'<stop offset="0" stop-color="{hexc(T)}" stop-opacity="0.28"/>'
            f'<stop offset="1" stop-color="{hexc(T)}" stop-opacity="0"/></linearGradient></defs>')
    out.append(piece("shadow-top", 60, 0, 1, G, f'<rect x="60" y="0" width="1" height="{G}" fill="url(#glow)"/>'))
    out.append(piece("shadow-topleft", 56, 0, 1, G, f'<rect x="56" y="0" width="1" height="{G}" fill="url(#glow)"/>'))
    out.append(piece("shadow-topright", 64, 0, 1, G, f'<rect x="64" y="0" width="1" height="{G}" fill="url(#glow)"/>'))
    for name, (x, y) in {"shadow-left": (56, 14), "shadow-right": (64, 14), "shadow-bottomleft": (56, 18),
                         "shadow-bottom": (60, 18), "shadow-bottomright": (64, 18), "shadow-center": (60, 14)}.items():
        out.append(piece(name, x, y, 1, 1))
    for side, size in (("top", G), ("bottom", 0), ("left", 0), ("right", 0)):
        out.append(f'<rect id="shadow-hint-{side}-margin" x="80" y="{len(out)}" width="{size if side in ("left", "right") else 1}" '
                   f'height="{size if side in ("top", "bottom") else 1}" fill="none"/>')
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="100" height="40" viewBox="0 0 100 40">{grad}{"".join(out)}</svg>\n'


def frame9(prefix, x0, y0, side, edge, body_center, line=None, fill=None):
    """A nine-piece frame for one task state. 'line' = (length share, height,
    opacity): a lit line along the bottom, centred, as wide as the middle
    piece (the corners are 'side' wide and stay empty)."""
    out = []
    S, H = side, edge
    cells = {"topleft": (0, 0, S, H), "top": (S + 2, 0, 1, H), "topright": (S + 5, 0, S, H),
             "left": (0, H + 2, S, 1), "center": (S + 2, H + 2, 1, 1), "right": (S + 5, H + 2, S, 1),
             "bottomleft": (0, H + 5, S, H), "bottom": (S + 2, H + 5, 1, H), "bottomright": (S + 5, H + 5, S, H)}
    for name, (x, y, w, h) in cells.items():
        x, y = x0 + x, y0 + y
        body = ""
        if fill:
            body += rect(x, y, w, h, fill[0], fill[1])
        if line and name == "bottom":
            lh, la, glow = line
            body += rect(x, y + h - lh, w, lh, T, la)
            body += rect(x, y + h - lh - 2, w, 2, T, glow)
        out.append(piece(f"{prefix}-{name}", x, y, w, h, body))
    return "".join(out)


def tasks(look):
    white = (255, 255, 255)
    parts = []
    # side = width of the empty ends of the line: a running app's line is the
    # icon's width less 2 x 12 px, the active one's less 2 x 6 px.
    parts.append(frame9("normal", 0, 0, 12, 4, "", line=(3, 0.7, 0.12)))
    parts.append(frame9("focus", 40, 0, 6, 4, "", line=(3, 1.0, 0.25), fill=(white, 0.12)))
    parts.append(frame9("hover", 80, 0, 6, 4, "", fill=(white, 0.08)))
    parts.append(frame9("attention", 120, 0, 6, 4, "", line=(3, 1.0, 0.3), fill=((232, 150, 44), 0.25)))
    parts.append(frame9("minimized", 160, 0, 12, 4, "", line=(2, 0.4, 0.0)))
    parts.append(frame9("progress", 200, 0, 2, 4, "", fill=(T, 0.35)))
    hints = "".join(f'<rect id="normal-hint-{s}-margin" x="{240 + i * 3}" y="0" width="2" height="2" fill="none"/>'
                    for i, s in enumerate(("top", "bottom", "left", "right")))
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="260" height="20" viewBox="0 0 260 20">{"".join(parts)}{hints}</svg>\n'


out = sys.argv[1]
for look in LOOKS:
    os.makedirs(os.path.join(out, look), exist_ok=True)
    open(os.path.join(out, look, "panel-background.svg"), "w").write(panel(look))
    open(os.path.join(out, look, "tasks.svg"), "w").write(tasks(look))
print("ok")
