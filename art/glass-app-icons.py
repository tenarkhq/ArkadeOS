"""ArkadeOS Glass app icons (T086, Roland, 2026-11-13: of the three families
"App ikon A, de gyúrjál még rá biztos sikerül szebbre részletesebbre"): the
Portal, the file manager, the terminal and System Settings in sky-blue glass
with depth, a lit rim, an inner glow and a soft shadow, no tile behind the
drawing. QtSvg draws them (no filters: shadows and glows are gradients).
The Portal's goes to hicolor (it is ours); the others into the ArkadeOS
Glass icon themes, over Breeze's, under every name the apps ask for.
Usage: glass-app-icons.py <icons folder>"""
import math
import os
import sys

out = sys.argv[1]
GREEN, AMBER, LILAC, RED = "#22C55E", "#F59E0B", "#C9CCF2", "#F43F5E"


def svg(body, defs):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96" width="96" height="96">'
            f'<defs>{defs}</defs>{body}</svg>\n')


def lin(gid, stops, x1=0, y1=0, x2=0, y2=1):
    s = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{a}"/>' for o, c, a in stops)
    return f'<linearGradient id="{gid}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{s}</linearGradient>'


def rad(gid, cx, cy, r, stops, fx=None, fy=None):
    s = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{a}"/>' for o, c, a in stops)
    f = f' fx="{fx}" fy="{fy}"' if fx is not None else ""
    return f'<radialGradient id="{gid}" cx="{cx}" cy="{cy}" r="{r}"{f} gradientUnits="userSpaceOnUse">{s}</radialGradient>'


# Shared: the glass (light top, deep bottom), the rim light, a soft shadow.
GLASS = [(0, "#b4dcfb", 1), (0.45, "#6fb3ec", 1), (1, "#2a69a8", 1)]
DEEP = [(0, "#2c5f91", 1), (1, "#173b5f", 1)]
RIM = [(0, "#ffffff", 0.85), (0.5, "#ffffff", 0.25), (1, "#ffffff", 0.05)]
SHADOW = [(0, "#000000", 0.38), (1, "#000000", 0)]


def shadow(cx, cy, rx, ry):
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="url(#sh)"/>'


def gear(cx, cy, R, r, n=8, tooth=0.46, bevel=0.07):
    pts = []
    step = 2 * math.pi / n
    for i in range(n):
        a = i * step - math.pi / 2
        for da, rr in ((-tooth * step / 2 - bevel, r), (-tooth * step / 2, R), (tooth * step / 2, R), (tooth * step / 2 + bevel, r)):
            pts.append((cx + rr * math.cos(a + da), cy + rr * math.sin(a + da)))
    return "M" + " L".join(f"{x:.2f} {y:.2f}" for x, y in pts) + " Z"


icons = {}

# Portal: a ring of glass, a dark glass well inside lit from below, the Ark
# mark in it with glossy dots.
d = (lin("ring", GLASS) + lin("rim", RIM) + rad("well", 48, 60, 30, [(0, "#2f6fa8", 0.9), (0.6, "#13283f", 1), (1, "#0b1726", 1)])
     + rad("sh", 48, 88, 34, SHADOW) + rad("halo", 48, 48, 44, [(0.75, "#60aae8", 0), (0.86, "#60aae8", 0.35), (1, "#60aae8", 0)]))
dots = ""
for (x, y), col in zip(((36, 36), (60, 36), (36, 60), (60, 60)), (GREEN, AMBER, LILAC, RED)):
    dots += (f'<circle cx="{x}" cy="{y}" r="5.6" fill="{col}"/>'
             f'<circle cx="{x - 1.6}" cy="{y - 1.8}" r="2" fill="#ffffff" fill-opacity="0.55"/>')
icons["portal"] = svg(
    shadow(48, 89, 30, 4.5) + '<circle cx="48" cy="48" r="44" fill="url(#halo)"/>'
    '<circle cx="48" cy="48" r="40" fill="url(#ring)"/>'
    '<circle cx="48" cy="48" r="39.2" fill="none" stroke="url(#rim)" stroke-width="1.6"/>'
    '<circle cx="48" cy="48" r="28.5" fill="url(#well)"/>'
    '<circle cx="48" cy="48" r="28.5" fill="none" stroke="#0b1d30" stroke-opacity="0.55" stroke-width="2"/>'
    '<path d="M27 40 A22 22 0 0 1 56 27.5" fill="none" stroke="#ffffff" stroke-opacity="0.22" stroke-width="2.5" stroke-linecap="round"/>'
    '<path d="M48 48L36 36M48 48L60 36M48 48L36 60M48 48L60 60" stroke="#ffffff" stroke-width="4.5" stroke-linecap="round"/>'
    + dots + '<circle cx="48" cy="48" r="6.4" fill="#ffffff"/>', d)

# Files: the folder's back in deep glass with its tab, sheets of paper
# showing, the front in sky glass with a lit rim and a label groove.
d = (lin("back", DEEP) + lin("front", GLASS) + lin("rim", RIM) + rad("sh", 48, 88, 40, SHADOW)
     + lin("paper", [(0, "#ffffff", 1), (1, "#dce9f5", 1)]))
FRONT = "M7 40 Q7 32 15 32 H81 Q89 32 89 40 V77 Q89 85 81 85 H15 Q7 85 7 77 Z"
icons["files"] = svg(
    shadow(48, 89, 38, 4.5)
    + '<path d="M9 23 Q9 12 20 12 H36.5 Q41 12 44 15.2 L48 19.5 H76 Q87 19.5 87 30 V48 H9 Z" fill="url(#back)"/>'
    '<path d="M10.5 22.5 Q10.5 13.5 20 13.5 H36.3 Q40.3 13.5 43 16.4 L47.4 21 H76 Q85.5 21 85.5 30" fill="none" stroke="#ffffff" stroke-opacity="0.25" stroke-width="1.4"/>'
    '<rect x="17" y="24" width="56" height="26" rx="3" fill="url(#paper)" transform="rotate(-3 45 37)"/>'
    '<rect x="22" y="27" width="56" height="24" rx="3" fill="#eef5fb" fill-opacity="0.95" transform="rotate(2.5 50 39)"/>'
    f'<path d="{FRONT}" fill="url(#front)"/>'
    f'<path d="{FRONT}" fill="none" stroke="url(#rim)" stroke-width="1.8"/>'
    '<path d="M15 33.5 H81" stroke="#ffffff" stroke-opacity="0.6" stroke-width="1.2"/>'
    '<rect x="33" y="58" width="30" height="7" rx="3.5" fill="#1d4f80" fill-opacity="0.35"/>'
    '<rect x="33" y="57" width="30" height="7" rx="3.5" fill="none" stroke="#ffffff" stroke-opacity="0.55" stroke-width="1.2"/>', d)

# Terminal: a window of dark glass with a lit sky rim, the capsule buttons
# of ArkadeOS Glass on its bar, a glowing prompt and dim lines of output.
d = (lin("body", [(0, "#2b4561", 1), (0.12, "#1c2f43", 1), (1, "#0d1622", 1)]) + lin("bar", [(0, "#7cc0f2", 0.55), (1, "#3f86c6", 0.35)])
     + lin("edge", [(0, "#a6d6fb", 1), (1, "#3f86c6", 1)]) + rad("sh", 48, 88, 40, SHADOW)
     + rad("glow", 34, 50, 18, [(0, "#60aae8", 0.45), (1, "#60aae8", 0)]))
TERM = "M7 22 Q7 12 17 12 H79 Q89 12 89 22 V74 Q89 84 79 84 H17 Q7 84 7 74 Z"
icons["terminal"] = svg(
    shadow(48, 89, 38, 4.5)
    + f'<path d="{TERM}" fill="url(#body)"/>'
    '<path d="M8.5 22 Q8.5 13.5 17 13.5 H79 Q87.5 13.5 87.5 22 V25 H8.5 Z" fill="url(#bar)"/>'
    f'<path d="{TERM}" fill="none" stroke="url(#edge)" stroke-width="2.4"/>'
    '<rect x="62" y="16.5" width="20" height="5.5" rx="2.75" fill="#ffffff" fill-opacity="0.22" stroke="#ffffff" stroke-opacity="0.6" stroke-width="0.8"/>'
    '<rect x="75.3" y="16.5" width="6.7" height="5.5" rx="2.75" fill="#e24646" fill-opacity="0.85"/>'
    '<circle cx="34" cy="50" r="18" fill="url(#glow)"/>'
    '<path d="M22 40 L35 50 L22 60" fill="none" stroke="#ffffff" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>'
    '<path d="M42 61 H62" stroke="#7cc0f2" stroke-width="6" stroke-linecap="round"/>'
    '<path d="M22 72 H50 M56 72 H70" stroke="#7cc0f2" stroke-opacity="0.35" stroke-width="3" stroke-linecap="round"/>', d)

# Settings: a gear of sky glass with a lit rim, a groove around its hub, a
# dark glass hub with a light ring.
d = (lin("g", GLASS) + lin("rim", RIM) + rad("sh", 48, 88, 36, SHADOW)
     + rad("hub", 48, 54, 16, [(0, "#2f6fa8", 1), (1, "#0e2238", 1)]))
G = gear(48, 47, 41, 32.5)
icons["settings"] = svg(
    shadow(48, 89, 32, 4.5)
    + f'<path d="{G}" fill="url(#g)" stroke="url(#g)" stroke-width="3.5" stroke-linejoin="round"/>'
    f'<path d="{G}" fill="none" stroke="url(#rim)" stroke-width="1.6" stroke-linejoin="round"/>'
    '<circle cx="48" cy="47" r="24" fill="none" stroke="#1d4f80" stroke-opacity="0.35" stroke-width="2.5"/>'
    '<circle cx="48" cy="46.2" r="24" fill="none" stroke="#ffffff" stroke-opacity="0.35" stroke-width="1"/>'
    '<circle cx="48" cy="47" r="14.5" fill="url(#hub)"/>'
    '<circle cx="48" cy="47" r="14.5" fill="none" stroke="#ffffff" stroke-width="4"/>'
    '<path d="M39.5 42.5 A10 10 0 0 1 50 37.2" fill="none" stroke="#ffffff" stroke-opacity="0.35" stroke-width="2" stroke-linecap="round"/>', d)

NAMES = {"portal": [("hicolor", "arkadeos-portal")],
         "files": [("arkadeos-glass", "org.kde.dolphin"), ("arkadeos-glass", "system-file-manager")],
         "terminal": [("arkadeos-glass", "utilities-terminal"), ("arkadeos-glass", "org.kde.konsole")],
         "settings": [("arkadeos-glass", "preferences-system"), ("arkadeos-glass", "systemsettings")]}
for key, text in icons.items():
    for theme, name in NAMES[key]:
        folder = os.path.join(out, theme, "scalable" if theme == "hicolor" else "apps", "apps" if theme == "hicolor" else "scalable")
        os.makedirs(folder, exist_ok=True)
        open(os.path.join(folder, name + ".svg"), "w").write(text)
apps = os.path.join(out, "arkadeos-glass", "apps")
for scale in ("scalable@2x", "scalable@3x"):
    if not os.path.islink(os.path.join(apps, scale)):
        os.symlink("scalable", os.path.join(apps, scale))
print("ok")
