"""ArkadeOS Glass Plasma style pieces (T086): the taskbar "C" Roland picked on
2026-11-13 (https://claude.ai/artifact/A9QNLgyxWb3rFxzpJJBJs8): a thin glass bar
whose top edge is lit in the glass colour, with a soft glow above it, and the
running apps marked by a short lit line under their icon; the active one
stands on a rounded tile of lighter glass, its line longer and brighter. The
app icons sit close together (Roland, 2026-11-13: "húzzuk már összeébb").

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


def path(d, c, a):
    return f'<path d="{d}" fill="{hexc(c)}" fill-opacity="{a:g}"/>'


# A task's tile: INSET px inside its slot on every side, corners rounded by
# RADIUS, as the design's tiles (rounded 6 px, apart from their neighbours).
INSET, RADIUS = 2, 6


def frame9(prefix, x0, y0, side, edge, line=None, fill=None):
    """A nine-piece frame for one task state, 'side' x 'edge' corners.
    'fill' = (colour, opacity): the rounded tile. 'line' = (height, opacity,
    glow, reach): a lit line along the bottom inside the tile, as wide as the
    middle piece plus 'reach' px into each bottom corner, its ends round."""
    out = []
    C, H, I, R = side, edge, INSET, RADIUS
    cells = {"topleft": (0, 0, C, H), "top": (C + 2, 0, 1, H), "topright": (C + 5, 0, C, H),
             "left": (0, H + 2, C, 1), "center": (C + 2, H + 2, 1, 1), "right": (C + 5, H + 2, C, 1),
             "bottomleft": (0, H + 5, C, H), "bottom": (C + 2, H + 5, 1, H), "bottomright": (C + 5, H + 5, C, H)}
    for name, (x, y, w, h) in cells.items():
        x, y = x0 + x, y0 + y
        body = ""
        if fill:
            col, a = fill
            # The tile's share of each piece; its corners are quarter arcs.
            tile = {
                "topleft": f"M{x + I} {y + H} L{x + I} {y + I + R} A{R} {R} 0 0 1 {x + I + R} {y + I} L{x + C} {y + I} L{x + C} {y + H} Z",
                "topright": f"M{x} {y + I} L{x + C - I - R} {y + I} A{R} {R} 0 0 1 {x + C - I} {y + I + R} L{x + C - I} {y + H} L{x} {y + H} Z",
                "bottomleft": f"M{x + C} {y} L{x + C} {y + H - I} L{x + I + R} {y + H - I} A{R} {R} 0 0 1 {x + I} {y + H - I - R} L{x + I} {y} Z",
                "bottomright": f"M{x} {y} L{x + C - I} {y} L{x + C - I} {y + H - I - R} A{R} {R} 0 0 1 {x + C - I - R} {y + H - I} L{x} {y + H - I} Z",
            }
            if name in tile:
                body += path(tile[name], col, a)
            else:
                rx, ry, rw, rh = {"top": (x, y + I, w, H - I), "bottom": (x, y, w, H - I),
                                  "left": (x + I, y, C - I, h), "right": (x, y, C - I, h)}.get(name, (x, y, w, h))
                body += rect(rx, ry, rw, rh, col, a)
        if line and name in ("bottomleft", "bottom", "bottomright"):
            lh, la, glow, reach = line
            top = y + H - I - 1 - lh
            r = lh / 2
            # The glow: a 1 px halo above the line, as long as the line.
            if name == "bottom":
                body += rect(x, top, w, lh, T, la) + rect(x, top - 1, w, 1, T, glow)
            elif name == "bottomleft":
                body += path(f"M{x + C} {top} L{x + C - reach + r} {top} A{r} {r} 0 0 0 {x + C - reach + r} {top + lh} "
                             f"L{x + C} {top + lh} Z", T, la)
                body += rect(x + C - reach + r, top - 1, reach - r, 1, T, glow) if reach > r else ""
            else:
                body += path(f"M{x} {top} L{x + reach - r} {top} A{r} {r} 0 0 1 {x + reach - r} {top + lh} "
                             f"L{x} {top + lh} Z", T, la)
                body += rect(x, top - 1, reach - r, 1, T, glow) if reach > r else ""
        out.append(piece(f"{prefix}-{name}", x, y, w, h, body))
    return "".join(out)


def tasks(look):
    white, amber = (255, 255, 255), (232, 150, 44)
    # A running app: a short line under its icon; the active one: the tile
    # and a longer, brighter line (on a 37 px slot: 18 and 27 px). Hovering
    # lights the tile and keeps the state's line.
    run, act = (3, 0.7, 0.12, 1.5), (3, 1.0, 0.25, 3)
    states = [("normal", 11, run, None), ("normal-hover", 11, run, (white, 0.08)),
              ("focus", 8, act, (white, 0.12)), ("focus-hover", 8, act, (white, 0.16)),
              ("minimized", 11, (2, 0.4, 0.0, 1), None), ("minimized-hover", 11, (2, 0.4, 0.0, 1), (white, 0.08)),
              ("attention", 8, act, (amber, 0.25)), ("attention-hover", 8, act, (amber, 0.32)),
              ("hover", 8, None, (white, 0.08)), ("launcher-hover", 8, None, (white, 0.08)),
              ("progress", 8, None, (T, 0.35))]
    parts = [frame9(p, i * 40, 0, side, 8, line=ln, fill=fl) for i, (p, side, ln, fl) in enumerate(states)]
    # Round the icon (Small spacing between icons: a slot is as wide as the
    # bar is tall, 37 px on a 40 px bar): 24 px icons, 5 px above them, 8 px
    # below for the line, 6 and 7 px at the sides.
    left = len(states) * 40
    hints = "".join(f'<rect id="normal-hint-{s}-margin" x="{left + i * 12}" y="0" width="{m if s in ("left", "right") else 1}" '
                    f'height="{m if s in ("top", "bottom") else 1}" fill="none"/>'
                    for i, (s, m) in enumerate((("top", 5), ("bottom", 8), ("left", 6), ("right", 7))))
    width = left + 60
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="30" viewBox="0 0 {width} 30">{"".join(parts)}{hints}</svg>\n'


out = sys.argv[1]
for look in LOOKS:
    os.makedirs(os.path.join(out, look), exist_ok=True)
    open(os.path.join(out, look, "panel-background.svg"), "w").write(panel(look))
    open(os.path.join(out, look, "tasks.svg"), "w").write(tasks(look))
print("ok")
