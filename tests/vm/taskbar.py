"""Checks a user's Plasma layout file (Roland, 2026-11-04): one taskbar at the
bottom and no other panel of ours: the ArkadeOS menu (kickoff, the lit Ark
mark of ArkadeOS Glass, T086) first, the apps in the middle between two
spacers and close together, the power switch, tray (its icons a little
closer), clock and show-desktop in the glass capsule; flush with the
screen's edge; no top bar (app menu), app grid or trash. Game Mode is not
among the apps, the Portal is. Runs in the VM: python3 - <appletsrc>
[plasmashellrc]."""
import configparser
import sys

c = configparser.ConfigParser(strict=False, interpolation=None)
c.optionxform = str
c.read(sys.argv[1])
applets = {}
for s in c.sections():
    p = s.split("][")
    if len(p) == 4 and p[0] == "Containments" and p[2] == "Applets":
        applets[(p[1], p[3])] = c[s].get("plugin", "")
for gone in ("org.kde.plasma.appmenu", "org.kde.plasma.kickerdash", "org.kde.plasma.trash"):
    assert gone not in applets.values(), f"{gone} still on a panel"
bars = [k[0] for k, v in applets.items() if v == "org.kde.plasma.icontasks"]
assert len(bars) == 1, f"taskbars: {bars}"
bar = bars[0]
assert c.get(f"Containments][{bar}", "location", fallback="") == "4", "taskbar not at the bottom"
ids = [k[1] for k in applets if k[0] == bar]
order = [i for i in c.get(f"Containments][{bar}][General", "AppletOrder", fallback="").split(";") if i in ids]
order = order or sorted(ids, key=int)
plugins = [applets[(bar, i)] for i in order]
want = ["org.kde.plasma.kickoff", "org.kde.plasma.panelspacer", "org.kde.plasma.icontasks", "org.kde.plasma.panelspacer",
        "org.arkadeos.power", "org.kde.plasma.systemtray", "org.kde.plasma.digitalclock",
        "org.kde.plasma.showdesktop", "org.arkadeos.capsule"]
assert plugins == want, f"taskbar: {plugins}"
menu = order[0]
icon = c.get(f"Containments][{bar}][Applets][{menu}][Configuration][General", "icon", fallback="")
assert icon == "arkadeos-launcher-glow", icon
tasks = order[2]
launchers = c.get(f"Containments][{bar}][Applets][{tasks}][Configuration][General", "launchers", fallback="")
assert "org.arkadeos.GameMode.desktop" not in launchers, launchers
assert "org.arkadeos.Portal.desktop" in launchers, launchers
# The app icons close together (Small spacing; Roland, 2026-11-13).
spacing = c.get(f"Containments][{bar}][Applets][{tasks}][Configuration][General", "iconSpacing", fallback="")
assert spacing == "0", f"icon spacing: {spacing!r}"
# The tray's icons a little closer (Small spacing) on its inner containment,
# which the tray widget names (Roland, 2026-11-13).
tray = order[5]
inner = (c.get(f"Containments][{bar}][Applets][{tray}][Configuration", "SystrayContainmentId", fallback="")
         or c.get(f"Containments][{bar}][Applets][{tray}", "SystrayContainmentId", fallback=""))
assert inner, "the tray has no inner containment"
tray_spacing = c.get(f"Containments][{inner}][General", "iconSpacing", fallback="")
assert tray_spacing == "1", f"tray icon spacing: {tray_spacing!r}"
# The clock on one line at the tray's text size, as in the design (T086).
clock = order[6]
look = c[f"Containments][{bar}][Applets][{clock}][Configuration][Appearance"] if c.has_section(
    f"Containments][{bar}][Applets][{clock}][Configuration][Appearance") else {}
assert (look.get("dateDisplayFormat"), look.get("autoFontAndSize"), look.get("fontSize")) == ("1", "false", "10"), dict(look)
if len(sys.argv) > 2:
    # Flush with the edge: Plasma keeps a panel's float in plasmashellrc.
    s = configparser.ConfigParser(strict=False, interpolation=None)
    s.optionxform = str
    s.read(sys.argv[2])
    floating = s.get(f"PlasmaViews][Panel {bar}", "floating", fallback=None)
    assert floating in (None, "0", "false"), f"taskbar floats: {floating}"
print("ok")
