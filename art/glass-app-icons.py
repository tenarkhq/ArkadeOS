"""ArkadeOS Glass app icons (Roland, 2026-11-14: round 6 approved, then
"ilyen tökéletességre való törekedéssel neki lehet állni az összes eddigi
ikonnak"): the file manager, the terminal and System Settings in the craft
of the Start and Portal marks (glass_craft): crystal glass and machined cool
metal, light from the top, no cast shadow, symmetric where the object
allows, a hand-drawn small size for 32 px and below.

- Files: a folder, its back in deep sky glass with its tab, a sheet of paper
  showing, the front in lit sky glass with a label groove.
- Terminal: a machined metal frame around a deep screen with a glowing
  prompt.
- Settings: three glowing slider tracks on a brushed metal plate with metal
  knobs (not a gear: the gear is the Portal's, next to it on the taskbar).

The Portal's icon is its mark (glass-marks.py). The icons go into the
ArkadeOS Glass themes (both read the same apps folder) under every name the
apps ask for: apps/small for 32 px and below, apps/scalable above.
Usage: glass-app-icons.py <icons folder>"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glass_craft as K  # noqa: E402
from glass_craft import f, lg, rg  # noqa: E402

out = sys.argv[1]

DEFS = [
    lg("fBack", 60, 19, 60, 97, [(0, "#4b97d8", None), (1, "#1b4f86", None)]),
    lg("fFront", 60, 45, 60, 98, [(0, "#eaf7ff", None), (0.45, "#8ccaf5", None), (1, "#3a88d0", None)]),
    lg("fHi", 60, 45, 60, 53, [(0, "#ffffff", 0.55), (1, "#ffffff", 0)]),
    rg("scr", [(0, "#1b4a75", None), (0.6, "#0c2236", None), (1, "#060f19", None)], None, ' cx="0.5" cy="0.32" r="0.8"'),
    lg("gloss", 60, 25, 60, 56, [(0, "#ffffff", 0.13), (1, "#ffffff", 0)]),
    lg("recess", 60, 24, 60, 96, [(0, "#000000", 0.55), (0.5, "#000000", 0.15), (1, "#ffffff", 0.35)]),
    lg("prompt", 40, 47, 40, 73, [(0, "#e6f6ff", None), (1, "#7cc4f4", None)]),
    lg("groove", 60, 26, 60, 94, [(0, "#1b3149", None), (1, "#4b6987", None)]),
    '<linearGradient id="knobCh" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff"/>'
    '<stop offset="0.5" stop-color="#9fd6fb"/><stop offset="1" stop-color="#2f78bd"/></linearGradient>',
    '<linearGradient id="knobFace" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f4fbff"/>'
    '<stop offset="1" stop-color="#b5dffb"/></linearGradient>',
    '<pattern id="brush" width="1.6" height="4" patternUnits="userSpaceOnUse"><rect width="0.5" height="4" fill="#ffffff" opacity="0.13"/></pattern>',
    '<clipPath id="plateClip"><rect x="14.5" y="14.5" width="91" height="91" rx="19.6"/></clipPath>',
]

FOLDER_BACK = "M14 35Q14 28 21 28H40L46 21Q47.5 19.5 50 19.5H70Q72.5 19.5 74 21L80 28H99Q106 28 106 35V90Q106 97 99 97H21Q14 97 14 90Z"
FOLDER_FRONT = "M12 50Q12 45 17 45H103Q108 45 108 50V91Q108 98 101 98H19Q12 98 12 91Z"


def files(big):
    if big:
        return (f'<path d="{FOLDER_BACK}" fill="url(#fBack)"/>'
                '<path d="M21 28.6H40.3L46.4 21.6Q47.8 20.2 50 20.2H70Q72.2 20.2 73.6 21.6L79.7 28.6H99" fill="none" stroke="#ffffff" stroke-opacity="0.4" stroke-width="0.8"/>'
                '<rect x="22" y="31" width="76" height="40" rx="3" fill="#dcebf7"/>'
                '<rect x="27" y="35" width="66" height="40" rx="3" fill="#ffffff"/>'
                '<path d="M35 41.5H85M35 46.5H85M35 51.5H72" stroke="#bcd4e9" stroke-width="0.9" stroke-linecap="round"/>'
                f'<path d="{FOLDER_FRONT}" fill="url(#fFront)"/>'
                '<path d="M12 50Q12 45 17 45H103Q108 45 108 50V53H12Z" fill="url(#fHi)"/>'
                '<path d="M16.5 45.5H103.5" stroke="#ffffff" stroke-opacity="0.95" stroke-width="0.9" stroke-linecap="round"/>'
                '<path d="M13 91.5Q13.4 97.2 19 97.4H101Q106.6 97.2 107 91.5" fill="none" stroke="#1d5a95" stroke-opacity="0.45" stroke-width="0.9"/>'
                '<rect x="45" y="65" width="30" height="7" rx="3.5" fill="#174a7c" fill-opacity="0.4"/>'
                '<path d="M48.5 72.7H71.5" stroke="#ffffff" stroke-opacity="0.6" stroke-width="0.8" stroke-linecap="round"/>')
    return (f'<path d="{FOLDER_BACK}" fill="url(#fBack)"/>'
            '<rect x="24" y="32" width="72" height="30" rx="3" fill="#ffffff"/>'
            f'<path d="{FOLDER_FRONT}" fill="url(#fFront)"/>'
            '<path d="M12 50Q12 45 17 45H103Q108 45 108 50V55H12Z" fill="url(#fHi)"/>'
            '<path d="M16 46H104" stroke="#ffffff" stroke-width="2" stroke-linecap="round"/>')


def terminal(big):
    if big:
        return ('<rect x="10" y="16" width="100" height="88" rx="14" fill="url(#gchD)"/>'
                '<rect x="12.6" y="18.6" width="94.8" height="82.8" rx="11.6" fill="url(#gfaceD)"/>'
                '<path d="M25 19.3H95" stroke="#ffffff" stroke-opacity="0.8" stroke-width="0.7" stroke-linecap="round"/>'
                '<rect x="19" y="25" width="82" height="70" rx="7" fill="url(#scr)"/>'
                '<rect x="19" y="25" width="82" height="70" rx="7" fill="none" stroke="url(#recess)" stroke-width="1.2"/>'
                '<rect x="19.6" y="25.6" width="80.8" height="30" rx="6.4" fill="url(#gloss)"/>'
                '<path d="M40.5 47.5L53 60L40.5 72.5" fill="none" stroke="#5aaeea" stroke-width="10" stroke-linecap="round" stroke-linejoin="round" filter="url(#soft2)" opacity="0.7"/>'
                '<rect x="60" y="66.5" width="22" height="7" rx="2.5" fill="#5aaeea" filter="url(#soft2)" opacity="0.7"/>'
                '<path d="M40.5 47.5L53 60L40.5 72.5" fill="none" stroke="url(#prompt)" stroke-width="6.5" stroke-linecap="round" stroke-linejoin="round"/>'
                '<rect x="60" y="66.5" width="22" height="7" rx="2.5" fill="#e6f6ff"/>')
    return ('<rect x="10" y="16" width="100" height="88" rx="16" fill="url(#gchD)"/>'
            '<rect x="17" y="23" width="86" height="74" rx="8" fill="url(#scr)"/>'
            '<path d="M36 44L52 60L36 76" fill="none" stroke="#e6f6ff" stroke-width="11" stroke-linecap="round" stroke-linejoin="round"/>'
            '<rect x="60" y="66" width="26" height="11" rx="3" fill="#e6f6ff"/>')


def settings(big):
    s = ['<rect x="12" y="12" width="96" height="96" rx="22" fill="url(#gchD)"/>',
         '<rect x="14.5" y="14.5" width="91" height="91" rx="19.6" fill="url(#gfaceD)"/>' if big
         else '<rect x="16" y="16" width="88" height="88" rx="18" fill="url(#gfaceD)"/>']
    if big:
        s.append('<rect x="14.5" y="14.5" width="91" height="91" fill="url(#brush)" clip-path="url(#plateClip)"/>')
        s.append('<path d="M34 15.2H86" stroke="#ffffff" stroke-opacity="0.85" stroke-width="0.7" stroke-linecap="round"/>')
    xs = (36, 60, 84) if big else (34, 60, 86)
    ys = (66, 42, 66) if big else (68, 40, 68)
    tw = 7 if big else 10
    for x, y in zip(xs, ys):
        s.append(f'<rect x="{f(x - tw / 2)}" y="{26 if big else 24}" width="{tw}" height="{68 if big else 72}" rx="{f(tw / 2)}" fill="url(#groove)"/>')
        if big:
            s.append(f'<path d="M{f(x - 2)} 94.7H{f(x + 2)}" stroke="#ffffff" stroke-opacity="0.55" stroke-width="0.7" stroke-linecap="round"/>')
            s.append(f'<rect x="{x - 2}" y="{y}" width="4" height="{92 - y}" rx="2" fill="#5aaeea" filter="url(#soft2)"/>')
            s.append(f'<rect x="{f(x - 1.4)}" y="{y}" width="2.8" height="{92 - y}" rx="1.4" fill="#bfe6ff"/>')
        else:
            s.append(f'<rect x="{f(x - 2.5)}" y="{y}" width="5" height="{94 - y}" rx="2.5" fill="#8fd0ff"/>')
        kw, kh = (22, 14) if big else (28, 18)
        knob = (f'<g transform="translate({f(x - kw / 2)} {f(y - kh / 2)})"><rect width="{kw}" height="{kh}" rx="{5 if big else 6}" fill="url(#knobCh)"/>'
                f'<rect x="1.6" y="1.6" width="{f(kw - 3.2)}" height="{f(kh - 3.2)}" rx="{3.6 if big else 4.5}" fill="url(#knobFace)"/>')
        if big:
            knob += (f'<path d="M{f(kw / 2 - 4)} {f(kh / 2)}H{f(kw / 2 + 4)}" stroke="#1f64a6" stroke-opacity="0.45" stroke-width="1.1" stroke-linecap="round"/>'
                     f'<path d="M3.5 2.1H{f(kw - 3.5)}" stroke="#ffffff" stroke-width="0.6" stroke-linecap="round"/>')
        s.append(knob + "</g>")
    return "".join(s)


ICONS = {"files": (files, ["org.kde.dolphin", "system-file-manager"]),
         "terminal": (terminal, ["utilities-terminal", "org.kde.konsole"]),
         "settings": (settings, ["preferences-system", "systemsettings"])}
NOTE = "ArkadeOS Glass app icon, generated by art/glass-app-icons.py (glass_craft): edit the generator, not this file."

apps = os.path.join(out, "arkadeos-glass", "apps")
for folder, big in (("scalable", True), ("small", False)):
    d = os.path.join(apps, folder)
    os.makedirs(d, exist_ok=True)
    for key, (draw, names) in ICONS.items():
        text = K.standalone(draw(big), "dk", size=96 if big else 32, comment=NOTE, extra_defs=DEFS)
        for name in names:
            open(os.path.join(d, name + ".svg"), "w").write(text)
for base in ("scalable", "small"):
    for scale in ("@2x", "@3x"):
        if not os.path.islink(os.path.join(apps, base + scale)):
            os.symlink(base, os.path.join(apps, base + scale))
print(len(ICONS), "app icons")
