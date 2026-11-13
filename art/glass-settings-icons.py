"""ArkadeOS Glass icons of System Settings (T086, Roland, 2026-11-13: "a
beállítások ablakot is rendbe rakhatnád ... az egészre gondoltam. ronda."):
every page and group of its side list in the hand of the app icons (family
A, art/glass-app-icons.py): shapes of sky-blue glass with a lit rim and a
soft shadow, white details, an ArkadeOS colour where a thing has one. Drawn
on 96 px, read at 22 px, so the shapes are bold and the details few.
They go into both ArkadeOS Glass icon themes, over Breeze's, under the names
the pages ask for (Plasma 6.8). Usage: glass-settings-icons.py <icons folder>"""
import math
import os
import sys

GREEN, AMBER, LILAC, RED, SKY = "#22C55E", "#F59E0B", "#C9CCF2", "#F43F5E", "#60aae8"
W = "#ffffff"


def stops(gid, kind, pts, **a):
    s = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{op}"/>' for o, c, op in pts)
    attrs = " ".join(f'{k}="{v}"' for k, v in a.items())
    return f'<{kind}Gradient id="{gid}" {attrs}>{s}</{kind}Gradient>'


DEFS = (stops("g", "linear", [(0, "#b4dcfb", 1), (0.45, "#6fb3ec", 1), (1, "#2a69a8", 1)], x1=0, y1=0, x2=0, y2=1)
        + stops("d", "linear", [(0, "#2b4561", 1), (1, "#0f1b28", 1)], x1=0, y1=0, x2=0, y2=1)
        + stops("r", "linear", [(0, W, 0.85), (0.5, W, 0.25), (1, W, 0.05)], x1=0, y1=0, x2=0, y2=1)
        + stops("sh", "radial", [(0, "#000000", 0.38), (1, "#000000", 0)], cx=48, cy=90, r=40, gradientUnits="userSpaceOnUse"))


def svg(*parts, shadow=(48, 89, 34, 4.5)):
    cx, cy, rx, ry = shadow
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96" width="96" height="96"><defs>{DEFS}</defs>'
            f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="url(#sh)"/>' + "".join(parts) + "</svg>\n")


def glass(d, fill="url(#g)"):
    """A body of glass with its lit rim."""
    return f'<path d="{d}" fill="{fill}"/><path d="{d}" fill="none" stroke="url(#r)" stroke-width="2"/>'


def dark(d):
    return glass(d, "url(#d)")


def line(d, col=W, w=6, op=1):
    return (f'<path d="{d}" fill="none" stroke="{col}" stroke-width="{w}" stroke-linecap="round" '
            f'stroke-linejoin="round" stroke-opacity="{op}"/>')


def fill(d, col=W, op=1):
    return f'<path d="{d}" fill="{col}" fill-opacity="{op}"/>'


def dot(x, y, r, col=W):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{col}"/>'


def rrect(x, y, w, h, r):
    return (f"M{x + r} {y} H{x + w - r} A{r} {r} 0 0 1 {x + w} {y + r} V{y + h - r} A{r} {r} 0 0 1 {x + w - r} {y + h} "
            f"H{x + r} A{r} {r} 0 0 1 {x} {y + h - r} V{y + r} A{r} {r} 0 0 1 {x + r} {y} Z")


def circle(cx, cy, r):
    return f"M{cx + r} {cy} A{r} {r} 0 1 1 {cx - r} {cy} A{r} {r} 0 1 1 {cx + r} {cy} Z"


def gear(cx, cy, R, r, n=8, tooth=0.46, bevel=0.07):
    pts, step = [], 2 * math.pi / n
    for i in range(n):
        a = i * step - math.pi / 2
        for da, rr in ((-tooth * step / 2 - bevel, r), (-tooth * step / 2, R), (tooth * step / 2, R), (tooth * step / 2 + bevel, r)):
            pts.append((cx + rr * math.cos(a + da), cy + rr * math.sin(a + da)))
    return "M" + " L".join(f"{x:.2f} {y:.2f}" for x, y in pts) + " Z"


MONITOR = rrect(8, 14, 80, 54, 8)
STAND = "M38 68 L35 80 H61 L58 68 Z"
MOUSE = "M48 8 C64 8 72 20 72 34 V58 C72 76 62 88 48 88 C34 88 24 76 24 58 V34 C24 20 32 8 48 8 Z"
KEYBOARD = rrect(6, 26, 84, 46, 9)
KEYS = "M18 40 H20 M30 40 H32 M42 40 H44 M54 40 H56 M66 40 H68 M78 40 H78.5 M18 52 H20 M30 52 H32 M66 52 H68 M78 52 H78.5 M34 61 H62"
GLOBE = circle(48, 48, 38)
SHIELD = "M48 8 L82 20 V44 C82 66 68 80 48 88 C28 80 14 66 14 44 V20 Z"
BELL = "M20 66 H76 L70 56 V40 A22 22 0 0 0 26 40 V56 Z"
PRINTER_BODY = rrect(8, 34, 80, 36, 8)

icons = {}
# Quick Settings and General Behaviour: the screen with a switch on it.
icons["preferences-desktop"] = svg(glass(MONITOR), dark(STAND), dark(rrect(28, 33, 40, 18, 9)), dot(58, 42, 6.5))
# Mouse, touchpad, pointers.
icons["preferences-desktop-mouse"] = svg(glass(MOUSE), line("M48 10 V36 M26 38 H70", "#1d4f80", 3, .5), dark(rrect(44, 20, 8, 14, 4)))
icons["input-mouse"] = icons["preferences-desktop-mouse"]
icons["preferences-desktop-touchpad"] = svg(glass(rrect(10, 14, 76, 70, 10)), line("M10 64 H86 M48 64 V84", "#1d4f80", 3, .55),
                                            dot(40, 38, 4.5), dot(56, 38, 4.5, W))
icons["preferences-desktop-cursors"] = svg(glass("M26 8 L74 54 L52 56 L64 82 L54 87 L42 61 L26 76 Z"))
# Keyboard, shortcuts, the on-screen keyboard.
icons["preferences-desktop-keyboard"] = svg(glass(KEYBOARD), line(KEYS, W, 6))
icons["input-keyboard"] = icons["preferences-desktop-keyboard"]
icons["preferences-desktop-keyboard-shortcut"] = svg(glass(KEYBOARD), line(KEYS, W, 6), dark(rrect(56, 8, 34, 26, 8)),
                                                     line("M66 21 H80", SKY, 5))
icons["input-keyboard-virtual"] = svg(glass(rrect(6, 30, 84, 44, 9)), line(KEYS.replace("40", "44").replace("52", "56").replace("61", "64"), W, 6),
                                      dark(rrect(30, 6, 36, 20, 6)), line("M40 16 H56", W, 4))
# Sound and its themes.
SPEAKER = "M12 36 H28 L50 16 V80 L28 60 H12 Z"
icons["preferences-desktop-sound"] = svg(glass(SPEAKER), line("M62 34 A16 16 0 0 1 62 62", SKY, 7), line("M72 22 A30 30 0 0 1 72 74", SKY, 7, .6))
icons["media-optical-audio"] = svg(glass(circle(48, 48, 38)), dark(circle(48, 48, 11)), line("M48 22 A26 26 0 0 1 74 48", W, 4, .6),
                                   line("M68 50 V72", RED, 5), dot(62, 74, 7, RED))
# Displays, night light, the day-night cycle.
icons["preferences-desktop-display"] = svg(glass(MONITOR), dark(STAND), line("M20 56 L36 40 L48 50 L62 34 L76 46", W, 5, .9))
icons["preferences-desktop-display-randr"] = svg(glass(rrect(6, 10, 56, 40, 7)), glass(rrect(32, 34, 58, 42, 7)), dark("M50 76 L47 86 H76 L73 76 Z"))
icons["redshift-status-on"] = svg(glass("M76.1 51.75 A28.36 28.36 0 1 1 44.24 19.9 A22.69 22.69 0 0 0 76.1 51.75 Z"),
                                  dot(72, 18, 4), dot(84, 32, 3))
icons["lighttable"] = svg(glass(circle(48, 48, 36)), fill("M48 12 A36 36 0 0 1 48 84 Z", "#173b5f", .85), dot(30, 48, 9),
                          fill("M66 34 A10 10 0 1 0 72 56 A13 13 0 0 1 66 34 Z", W))
# Accessibility, game controllers, tablets, touch screens.
icons["preferences-desktop-accessibility"] = svg(glass(circle(48, 48, 38)), dot(48, 26, 6.5),
                                                 line("M28 38 L48 42 L68 38 M48 42 V58 L38 74 M48 58 L58 74", W, 6))
icons["preferences-desktop-gaming"] = svg(glass("M26 26 H70 C84 26 90 38 88 52 L85 66 C83 78 69 80 63 71 L58 63 H38 L33 71 "
                                                "C27 80 13 78 11 66 L8 52 C6 38 12 26 26 26 Z"),
                                          line("M24 46 H38 M31 39 V53", W, 6), dot(64, 42, 4.5, GREEN), dot(72, 51, 4.5, RED))
icons["preferences-desktop-tablet"] = svg(glass(rrect(8, 12, 64, 72, 9)), line("M30 66 L74 22", "#1d4f80", 3, .4),
                                          line("M82 14 L52 64 L46 70 L48 62 L78 12 Z", W, 4), fill("M82 14 L78 12 L52 58 L56 61 Z", W))
icons["preferences-desktop-touchscreen"] = svg(glass(rrect(18, 8, 60, 80, 10)), line("M40 78 H56", "#1d4f80", 4, .5),
                                               f'<circle cx="48" cy="40" r="15" fill="none" stroke="{W}" stroke-width="4" stroke-opacity=".5"/>',
                                               dot(48, 40, 7))
# Bluetooth, disks, printers, colour, Thunderbolt.
icons["preferences-system-bluetooth"] = svg(glass(circle(48, 48, 38)), line("M34 34 L60 60 L48 72 V24 L60 36 L34 62", W, 6))
icons["preferences-system-disks"] = svg(glass(rrect(8, 22, 80, 52, 10)), line("M8 54 H88", "#1d4f80", 3, .5), dot(72, 64, 4.5, GREEN),
                                        line("M20 64 H44", W, 5, .8))
icons["preferences-devices-printer"] = svg(fill(rrect(26, 8, 44, 32, 4), "#eef5fb"), glass(PRINTER_BODY),
                                           fill(rrect(26, 58, 44, 30, 4), W), line("M34 68 H62 M34 77 H54", "#3f86c6", 3.5),
                                           dot(74, 46, 3.5, GREEN))
icons["preferences-desktop-color"] = svg(f'<circle cx="38" cy="38" r="22" fill="{RED}" fill-opacity=".85"/>',
                                         f'<circle cx="58" cy="38" r="22" fill="{GREEN}" fill-opacity=".8"/>',
                                         f'<circle cx="48" cy="56" r="22" fill="{SKY}" fill-opacity=".85"/>')
icons["preferences-desktop-thunderbolt"] = svg(glass("M54 6 L20 54 H44 L38 90 L76 38 H52 Z"))
# Networks and accounts.
MERIDIANS = "M10 48 H86 M48 10 C30 28 30 68 48 86 M48 10 C66 28 66 68 48 86 M18 28 H78 M18 68 H78"
icons["preferences-system-network"] = svg(glass(GLOBE), line(MERIDIANS, W, 4, .85))
icons["preferences-system-network-connection"] = icons["preferences-system-network"]
icons["network-connect"] = svg(glass(GLOBE), line(MERIDIANS, W, 3.5, .45), dark(circle(66, 66, 18)), line("M58 66 H74 M68 60 L74 66 L68 72", W, 4))
icons["preferences-online-accounts"] = svg(glass("M22 66 A26 26 0 0 1 26 30 A24 24 0 0 1 70 30 A20 20 0 0 1 74 70 H26 A14 14 0 0 1 22 66 Z"),
                                           dot(48, 42, 9), fill("M30 70 C34 56 62 56 66 70 Z", W))
icons["preferences-system-network-remote"] = svg(glass(rrect(6, 10, 60, 44, 7)), dark("M28 54 L26 62 H46 L44 54 Z"),
                                                 dark(circle(68, 66, 20)), line("M58 62 H76 L71 57 M78 70 H60 L65 75", W, 4))
# Looks: global theme, styles, colours, icons, fonts, wallpaper, splash, sounds.
icons["preferences-desktop-theme-global"] = svg(glass(MONITOR), fill(rrect(16, 22, 32, 38, 3), "#0f1b28", .9),
                                                fill(rrect(48, 22, 32, 38, 3), W, .9), dark(STAND))
icons["preferences-desktop-theme-applications"] = svg(glass(rrect(8, 12, 80, 72, 9)), dark(rrect(16, 30, 64, 46, 5)),
                                                      fill(rrect(22, 38, 22, 8, 4), SKY), line("M22 56 H70 M22 66 H56", W, 4, .8))
icons["preferences-desktop-theme-windowdecorations"] = svg(dark(rrect(8, 16, 80, 66, 9)), glass("M8 25 A9 9 0 0 1 17 16 H79 A9 9 0 0 1 88 25 V36 H8 Z"),
                                                           fill(rrect(52, 21, 30, 10, 5), W, .35), fill(rrect(72, 21, 10, 10, 5), RED))
icons["preferences-desktop-plasma-theme"] = svg(glass(rrect(8, 18, 80, 56, 8)), dark(rrect(8, 60, 80, 14, 4)),
                                                dot(20, 67, 3.5, SKY), line("M36 67 H44 M52 67 H60", W, 4), dot(78, 67, 2.5))
icons["preferences-desktop-icons"] = svg(glass(rrect(10, 10, 34, 34, 9)), glass(rrect(52, 10, 34, 34, 17)),
                                         glass(rrect(10, 52, 34, 34, 9)), glass(rrect(52, 52, 34, 34, 9)))
icons["preferences-desktop-font"] = svg(glass("M8 82 L32 14 H44 L68 82 H54 L49 66 H27 L22 82 Z"), fill("M31 54 H45 L38 32 Z", "#173b5f"),
                                        line("M84 54 V82", W, 7), f'<circle cx="72" cy="68" r="12" fill="none" stroke="{W}" stroke-width="7"/>')
icons["preferences-desktop-wallpaper"] = svg(glass(rrect(8, 14, 80, 66, 9)), fill("M14 74 L38 46 L52 60 L62 50 L82 74 Z", "#173b5f", .85),
                                             dot(66, 32, 7, AMBER))
icons["preferences-system-splash"] = svg(glass(circle(48, 48, 38)), line("M48 48 L36 36 M48 48 L60 36 M48 48 L36 60 M48 48 L60 60", W, 4.5),
                                         dot(36, 36, 5, GREEN), dot(60, 36, 5, AMBER), dot(36, 60, 5, LILAC), dot(60, 60, 5, RED), dot(48, 48, 6))
icons["preferences-desktop-animations"] = svg(glass(circle(56, 48, 30)), line("M8 34 H22 M4 48 H20 M8 62 H22", SKY, 6))
icons["preferences-desktop-effects"] = svg(glass("M48 8 L56 38 L86 48 L56 58 L48 88 L40 58 L10 48 L40 38 Z"), dot(76, 18, 5, AMBER), dot(20, 76, 4, LILAC))
# Apps, windows, notifications, activities, desktops.
icons["preferences-desktop-notification-bell"] = svg(glass(BELL), dark("M40 72 A8 8 0 0 0 56 72 Z"), line("M48 12 V18", W, 6), dot(72, 22, 9, SKY))
icons["preferences-desktop-activities"] = svg(glass(rrect(26, 8, 56, 44, 8)), glass(rrect(18, 22, 56, 44, 8)), glass(rrect(10, 36, 56, 44, 8)))
icons["preferences-desktop-default-applications"] = svg(glass(rrect(10, 10, 34, 34, 9)), glass(rrect(52, 10, 34, 34, 9)),
                                                        glass(rrect(10, 52, 34, 34, 9)),
                                                        fill("M69 50 L74 62 L87 63 L77 71 L80 84 L69 77 L58 84 L61 71 L51 63 L64 62 Z", AMBER))
icons["preferences-desktop-virtual"] = svg(glass(rrect(8, 12, 38, 32, 6)), glass(rrect(50, 12, 38, 32, 6)), glass(rrect(8, 50, 38, 32, 6)),
                                           dark(rrect(50, 50, 38, 32, 6)), line("M58 66 H80", SKY, 5))
WINDOWS = [dark(rrect(30, 10, 56, 44, 7)), glass(rrect(10, 34, 56, 50, 7)), fill("M10 41 A7 7 0 0 1 17 34 H59 A7 7 0 0 1 66 41 V46 H10 Z", W, .5)]
icons["preferences-system-windows"] = svg(*WINDOWS)
icons["preferences-system-windows-actions"] = svg(*WINDOWS, dark(circle(70, 70, 16)), line("M64 70 H76 M70 64 V76", W, 4))
# Security, users, power, search, locale, session.
icons["preferences-security"] = svg(glass(SHIELD), line("M33 48 L44 59 L64 37", W, 7))
icons["preferences-desktop-user-password"] = svg(line("M30 42 V32 A18 18 0 0 1 66 32 V42", "#3f86c6", 8), glass(rrect(18, 40, 60, 46, 10)),
                                                 dark(circle(48, 58, 7)), line("M48 62 V72", "#0f1b28", 6))
icons["preferences-system-login"] = svg(glass(rrect(40, 8, 46, 80, 8)), dark(circle(52, 50, 4)), line("M8 48 H32 M24 38 L34 48 L24 58", SKY, 7))
icons["preferences-system-users"] = svg(glass(circle(62, 30, 14)), glass("M38 82 C38 60 86 60 86 82 Z"), glass(circle(34, 36, 16)),
                                        glass("M6 86 C6 60 62 60 62 86 Z"))
icons["preferences-desktop-user"] = svg(glass(circle(48, 30, 18)), glass("M14 86 C14 56 82 56 82 86 Z"))
icons["preferences-system-power-management"] = svg(glass(rrect(8, 26, 74, 44, 9)), fill(rrect(84, 40, 6, 16, 3), "#3f86c6"),
                                                   fill(rrect(16, 34, 40, 28, 4), GREEN, .9), fill("M50 30 L38 50 H48 L44 66 L60 44 H50 Z", W))
icons["preferences-desktop-search"] = svg(glass(circle(40, 40, 28)), dark(circle(40, 40, 16)), line("M60 60 L84 84", "#3f86c6", 12),
                                          line("M32 32 A12 12 0 0 1 44 28", W, 3.5, .7))
icons["plasma-search"] = icons["preferences-desktop-search"]
icons["preferences-desktop-baloo"] = svg(glass("M10 22 Q10 14 18 14 H36 L42 20 H78 Q86 20 86 28 V74 Q86 82 78 82 H18 Q10 82 10 74 Z"),
                                         dark(circle(50, 50, 13)), line("M59 59 L70 70", W, 6))
icons["preferences-desktop-locale"] = svg(glass(GLOBE), line(MERIDIANS, W, 3.5, .45), dark(circle(64, 64, 22)), line("M64 52 V64 L72 70", W, 4.5))
icons["preferences-desktop-feedback"] = svg(glass("M14 18 H82 A8 8 0 0 1 90 26 V58 A8 8 0 0 1 82 66 H40 L22 82 V66 H14 A8 8 0 0 1 6 58 V26 A8 8 0 0 1 14 18 Z"),
                                            dot(30, 42, 5), dot(48, 42, 5), dot(66, 42, 5))
icons["preferences-system-session-services"] = svg(glass(gear(40, 40, 30, 23)), dark(circle(40, 40, 9)), glass(gear(70, 70, 20, 15, 6)),
                                                   dark(circle(70, 70, 6)))
# Groups of the side list (System Settings' categories).
icons["preferences-system-network-share"] = icons["preferences-system-network"]
icons["preferences-desktop-peripherals"] = svg(glass(rrect(6, 30, 50, 34, 8)), line("M16 42 H18 M26 42 H28 M36 42 H38 M46 42 H46.5 M20 52 H42", W, 5),
                                               glass("M74 22 C84 22 88 30 88 38 V60 C88 72 82 80 74 80 C66 80 60 72 60 60 V38 C60 30 64 22 74 22 Z"))
icons["preferences-desktop-multimedia"] = svg(glass(circle(48, 48, 38)), fill("M40 30 L66 48 L40 66 Z", W))
icons["preferences-system"] = None  # the app's own icon (glass-app-icons.py)
icons = {k: v for k, v in icons.items() if v}

out = sys.argv[1]
folder = os.path.join(out, "arkadeos-glass", "apps", "scalable")
os.makedirs(folder, exist_ok=True)
for name, text in icons.items():
    open(os.path.join(folder, name + ".svg"), "w").write(text)
print(len(icons), "icons")
