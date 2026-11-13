"""ArkadeOS Glass tray icons (T086, Roland, 2026-11-13: "a jobb alsó sarokban
lévő ikonok is máshogy néznek ki. nem lehet újat rajzolni azoknak az
appoknak?"): the status icons of the taskbar's glass capsule, drawn in one
hand, as in the design (https://claude.ai/artifact/A9QNLgyxWb3rFxzpJJBJs8):
thin round strokes, 1.5 px on a 22 px grid. Volume, Wi-Fi and wired network,
battery, power profile, brightness and night light, Bluetooth, notifications
and the show-desktop button.

They go into two icon themes, ArkadeOS Glass (on Breeze) and ArkadeOS Glass
Dark (on Breeze Dark), which the ArkadeOS global themes pick; every other
icon is Breeze's. The names are the ones the Plasma 6.8 tray widgets ask for
(plasma-pa, plasma-nm, powerdevil, bluedevil, plasma-workspace), every
variant of each, so that no Breeze icon of the same kind shows up between
ours. The colours follow the colour scheme (Plasma recolours the
ColorScheme-* classes): white on the dark glass, dark on the light one.
Usage: glass-icons.py <icons folder>"""
import math
import os
import sys

STYLE = ('<style id="current-color-scheme" type="text/css">'
         ".ColorScheme-Text { color: #232629; } .ColorScheme-Highlight { color: #60aae8; } "
         ".ColorScheme-NegativeText { color: #da4453; } .ColorScheme-NeutralText { color: #f67400; } "
         ".ColorScheme-PositiveText { color: #27ae60; } .ColorScheme-Background { color: #eff0f1; }</style>")


def svg(*parts):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 22 22">'
            + STYLE + "".join(parts) + "</svg>\n")


def line(d, cls="Text", a=1.0, w=1.5):
    op = f' stroke-opacity="{a:g}"' if a < 1 else ""
    return (f'<path class="ColorScheme-{cls}" d="{d}" fill="none" stroke="currentColor" stroke-width="{w:g}"'
            f' stroke-linecap="round" stroke-linejoin="round"{op}/>')


def solid(d, cls="Text", a=1.0):
    op = f' fill-opacity="{a:g}"' if a < 1 else ""
    return f'<path class="ColorScheme-{cls}" d="{d}" fill="currentColor"{op}/>'


def dot(x, y, r, cls="Text", a=1.0):
    op = f' fill-opacity="{a:g}"' if a < 1 else ""
    return f'<circle class="ColorScheme-{cls}" cx="{x:g}" cy="{y:g}" r="{r:g}" fill="currentColor"{op}/>'


def f(v):
    return f"{v:.2f}".rstrip("0").rstrip(".")


def cross(x, y, s=2, cls="Text"):
    return line(f"M{f(x - s)} {f(y - s)} L{f(x + s)} {f(y + s)} M{f(x + s)} {f(y - s)} L{f(x - s)} {f(y + s)}", cls)


DIM = 0.35
icons = {}

# Volume: the speaker and up to two waves.
SPEAKER = "M3.75 8.75 H6.75 L10.75 5.25 V16.75 L6.75 13.25 H3.75 Z"
WAVE1 = "M13.9 8.2 A4.1 4.1 0 0 1 13.9 13.8"
WAVE2 = "M15.5 5.6 A7 7 0 0 1 15.5 16.4"
icons["audio-volume-muted-symbolic"] = svg(line(SPEAKER), cross(16.5, 11, 2))
icons["audio-volume-low-symbolic"] = svg(line(SPEAKER), line(WAVE1), line(WAVE2, a=DIM))
icons["audio-volume-medium-symbolic"] = svg(line(SPEAKER), line(WAVE1), line(WAVE2, a=0.65))
icons["audio-volume-high-symbolic"] = svg(line(SPEAKER), line(WAVE1), line(WAVE2))
icons["audio-volume-high-warning-symbolic"] = svg(line(SPEAKER), line(WAVE1, "NeutralText"), line(WAVE2, "NeutralText"))
icons["audio-volume-high-danger-symbolic"] = svg(line(SPEAKER), line(WAVE1, "NegativeText"), line(WAVE2, "NegativeText"))

# Network. Wi-Fi: a dot and three arcs, lit by the signal; wired: a network
# socket. A VPN adds a lock, a limited connection an exclamation mark.
WX, WY = 11, 16.25


def arc(r, a=45):
    x0, x1 = WX - r * math.sin(math.radians(a)), WX + r * math.sin(math.radians(a))
    y = WY - r * math.cos(math.radians(a))
    return f"M{f(x0)} {f(y)} A{r} {r} 0 0 1 {f(x1)} {f(y)}"


def wifi(lit):
    parts = [dot(WX, WY, 1.4, a=1 if lit >= 1 else DIM)]
    for i, r in enumerate((4, 7.5, 11)):
        parts.append(line(arc(r), a=1 if lit >= i + 2 else DIM))
    return parts


LOCK = (solid("M15.5 17 h5 a.6 .6 0 0 1 .6 .6 v3.3 a.6 .6 0 0 1 -.6 .6 h-5 a.6 .6 0 0 1 -.6 -.6 v-3.3 a.6 .6 0 0 1 .6 -.6 Z")
        + line("M16.6 17 V15.9 A1.4 1.4 0 0 1 19.4 15.9 V17", w=1.2))
LIMITED = line("M19.5 13.8 V17.4", "NeutralText") + dot(19.5, 20, 0.9, "NeutralText")
SOCKET = "M4.75 5.75 H17.25 V14.25 H14.25 V16.75 H7.75 V14.25 H4.75 Z"
PINS = "M8.5 8.75 V10.25 M11 8.75 V10.25 M13.5 8.75 V10.25"
for strength, lit in (("0", 0), ("20", 1), ("40", 2), ("60", 3), ("80", 4), ("100", 4)):
    for suffix, extra in (("", []), ("-locked", [LOCK]), ("-limited", [LIMITED])):
        icons[f"network-wireless-{strength}{suffix}-symbolic"] = svg(*wifi(lit), *extra)
for suffix, extra in (("", []), ("-locked", [LOCK]), ("-limited", [LIMITED])):
    icons[f"network-wired-activated{suffix}-symbolic"] = svg(line(SOCKET), line(PINS), *extra)
icons["network-wireless-disconnected-symbolic"] = svg(*wifi(0), cross(17.5, 17.5, 1.75))
icons["network-wired-disconnected-symbolic"] = svg(line(SOCKET, a=DIM), line(PINS, a=DIM), cross(17.5, 17.5, 1.75))
icons["network-unavailable-symbolic"] = svg(*wifi(0), cross(17.5, 17.5, 1.75, "NegativeText"))
icons["network-flightmode-on-symbolic"] = svg(solid(
    "M11 3.25 C11.75 3.25 12.25 4 12.25 5 V9.1 L18.75 12.75 V14.4 L12.25 12.4 V15.9 L14.25 17.4 V18.75 L11 17.8 "
    "L7.75 18.75 V17.4 L9.75 15.9 V12.4 L3.25 14.4 V12.75 L9.75 9.1 V5 C9.75 4 10.25 3.25 11 3.25 Z"))
icons["network-wireless-bluetooth-symbolic"] = svg(*wifi(4))

# Battery: lying, as in the design, filled to its charge (red at 10 % and
# below, amber at 20 %); charging adds a bolt in the glass colour. A power
# profile other than the default adds a small dot.
BODY = "M4.75 7.25 H14.75 A2 2 0 0 1 16.75 9.25 V12.75 A2 2 0 0 1 14.75 14.75 H4.75 A2 2 0 0 1 2.75 12.75 V9.25 A2 2 0 0 1 4.75 7.25 Z"
NUB = "M17.9 9.5 H18.5 A.75 .75 0 0 1 19.25 10.25 V11.75 A.75 .75 0 0 1 18.5 12.5 H17.9 Z"
BOLT = "M10.9 4.9 L6.6 11.5 H9.5 L8.5 17.1 L12.9 10.3 H10 Z"


def battery(level, charging=False, profile=""):
    parts = [line(BODY), solid(NUB)]
    if level > 0:
        w = max(1.5, 10.5 * level / 100)
        cls = "NegativeText" if level <= 10 and not charging else "NeutralText" if level <= 20 and not charging else "Text"
        parts.append(solid(f"M4.5 9 H{f(4.5 + w - 0.75)} A.75 .75 0 0 1 {f(4.5 + w)} 9.75 V12.25 A.75 .75 0 0 1 "
                           f"{f(4.5 + w - 0.75)} 13 H4.5 Z" if w > 1.5 else "M4.5 9 H6 V13 H4.5 Z", cls))
    if charging:
        parts.append(line(BOLT, "Background", w=2.2))
        parts.append(solid(BOLT, "Highlight"))
    if profile:
        parts.append(dot(19.25, 4.75, 1.75, "PositiveText" if profile == "powersave" else "NeutralText"))
    return svg(*parts)


for level in range(0, 101, 10):
    for charging in (False, True):
        for profile in ("", "powersave", "performance"):
            name = f"battery-{level:03d}" + ("-charging" if charging else "") + (f"-profile-{profile}" if profile else "")
            icons[name + "-symbolic"] = battery(level, charging, profile)
icons["battery-full-symbolic"] = battery(100)
icons["battery-missing-symbolic"] = svg(line(BODY, a=DIM), solid(NUB, a=DIM), cross(9.75, 11, 1.75))

# Power profile: a gauge, its needle low, in the middle or high.
GX, GY, GR = 11, 12.75, 7.5


def gauge(angle):
    a0, a1 = math.radians(210), math.radians(-30)
    p0 = (GX + GR * math.cos(a0), GY - GR * math.sin(a0))
    p1 = (GX + GR * math.cos(a1), GY - GR * math.sin(a1))
    n = math.radians(angle)
    tip = (GX + 5 * math.cos(n), GY - 5 * math.sin(n))
    return svg(line(f"M{f(p0[0])} {f(p0[1])} A{GR} {GR} 0 1 1 {f(p1[0])} {f(p1[1])}"),
               line(f"M{GX} {GY} L{f(tip[0])} {f(tip[1])}"), dot(GX, GY, 1.6))


icons["battery-profile-powersave-symbolic"] = gauge(155)
icons["battery-profile-balanced-symbolic"] = gauge(90)
icons["battery-profile-performance-symbolic"] = gauge(25)
icons["speedometer-symbolic"] = gauge(90)

# Brightness: the sun; night light: the moon.
RAYS = " ".join(f"M{f(11 + 6 * math.cos(math.radians(a)))} {f(11 - 6 * math.sin(math.radians(a)))} "
                f"L{f(11 + 8 * math.cos(math.radians(a)))} {f(11 - 8 * math.sin(math.radians(a)))}" for a in range(0, 360, 45))
SUN = [line("M14.5 11 A3.5 3.5 0 1 1 7.5 11 A3.5 3.5 0 1 1 14.5 11 Z"), line(RAYS)]
MOON = "M17.44 11.86 A6.5 6.5 0 1 1 10.14 4.56 A5.2 5.2 0 0 0 17.44 11.86 Z"
icons["brightness-high-symbolic"] = svg(*SUN)
icons["redshift-status-day-symbolic"] = svg(*SUN)
icons["redshift-status-on-symbolic"] = svg(line(MOON))
icons["redshift-status-off-symbolic"] = svg(line(MOON, a=DIM))

# Bluetooth: the rune; connected adds two dots.
RUNE = "M7.25 7.75 L14.25 14.25 L11 17.75 V4.25 L14.25 7.75 L7.25 14.25"
icons["network-bluetooth-symbolic"] = svg(line(RUNE))
icons["network-bluetooth-activated-symbolic"] = svg(line(RUNE), dot(5, 11, 1.1, "Highlight"), dot(17, 11, 1.1, "Highlight"))
icons["network-bluetooth-inactive-symbolic"] = svg(line(RUNE, a=DIM))

# Notifications: the bell; new ones add a dot in the glass colour.
BELL = "M5.75 15.25 H16.25 L15 13.4 V10 A4 4 0 0 0 7 10 V13.4 Z"
CLAPPER = "M9.5 17.75 A1.6 1.6 0 0 0 12.5 17.75"
icons["notification-inactive-symbolic"] = svg(line(BELL), line(CLAPPER), line("M11 4.25 V5.75"))
icons["notification-active-symbolic"] = svg(line(BELL), line(CLAPPER), line("M11 4.25 V5.75"), dot(16.5, 5.5, 2.4, "Highlight"))
icons["notifications-disabled-symbolic"] = svg(line(BELL, a=DIM), line(CLAPPER, a=DIM), line("M4.25 4.25 L17.75 17.75"))

# Show desktop: a small screen, not the full-size frame of Breeze.
icons["user-desktop-symbolic"] = svg(line("M6 5.75 H16 A1.5 1.5 0 0 1 17.5 7.25 V13 A1.5 1.5 0 0 1 16 14.5 H6 "
                                          "A1.5 1.5 0 0 1 4.5 13 V7.25 A1.5 1.5 0 0 1 6 5.75 Z"),
                                     line("M11 14.5 V17.25 M8.25 17.25 H13.75"))

THEME = """[Icon Theme]
Name={name}
Comment=ArkadeOS: {base_name} with the glass taskbar's own tray icons
Inherits={base},hicolor
Example=audio-volume-high-symbolic
FollowsColorScheme=true
DisplayDepth=32
Directories=status/22,status/22@2x,status/22@3x

[status/22]
Size=22
Context=Status
Type=Scalable
MinSize=8
MaxSize=256

[status/22@2x]
Size=22
Scale=2
Context=Status
Type=Scalable
MinSize=8
MaxSize=256

[status/22@3x]
Size=22
Scale=3
Context=Status
Type=Scalable
MinSize=8
MaxSize=256
"""

out = sys.argv[1]
light = os.path.join(out, "arkadeos-glass")
status = os.path.join(light, "status", "22")
os.makedirs(status, exist_ok=True)
for old in os.listdir(status):
    if old.endswith(".svg") and old[:-4] not in icons:
        os.remove(os.path.join(status, old))
for name, text in icons.items():
    open(os.path.join(status, name + ".svg"), "w").write(text)
for scale in ("22@2x", "22@3x"):
    link = os.path.join(light, "status", scale)
    if not os.path.islink(link):
        os.symlink("22", link)
open(os.path.join(light, "index.theme"), "w").write(THEME.format(name="ArkadeOS Glass", base="breeze", base_name="Breeze"))
dark = os.path.join(out, "arkadeos-glass-dark")
os.makedirs(dark, exist_ok=True)
if not os.path.islink(os.path.join(dark, "status")):
    os.symlink("../arkadeos-glass/status", os.path.join(dark, "status"))
open(os.path.join(dark, "index.theme"), "w").write(THEME.format(name="ArkadeOS Glass Dark", base="breeze-dark", base_name="Breeze Dark"))
print(len(icons), "icons")
