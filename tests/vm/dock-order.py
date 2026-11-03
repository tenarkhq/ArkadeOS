"""Checks a user's Plasma layout file (Roland, 2026-11-03): the ArkadeOS menu
(kickoff) is the dock's first widget and on no other panel, Game Mode is not
on the dock, the Portal is; the menu and the app grid have the pictures sized
like the app icons. Runs in the VM: python3 - <appletsrc>."""
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
docks = [k[0] for k, v in applets.items() if v == "org.kde.plasma.icontasks"]
assert len(docks) == 1, f"docks: {docks}"
dock = docks[0]
menus = [k for k, v in applets.items() if v == "org.kde.plasma.kickoff"]
assert [k[0] for k in menus] == [dock], f"menus: {menus}"
ids = [k[1] for k in applets if k[0] == dock]
order = [i for i in c.get(f"Containments][{dock}][General", "AppletOrder", fallback="").split(";") if i in ids]
order = order or sorted(ids, key=int)
assert order[0] == menus[0][1], f"order: {order}, menu: {menus[0][1]}"
menu_icon = c.get(f"Containments][{dock}][Applets][{menus[0][1]}][Configuration][General", "icon", fallback="")
assert menu_icon == "/usr/share/arkadeos/icons/dock-menu.svg", menu_icon
grids = [k[1] for k, v in applets.items() if v == "org.kde.plasma.kickerdash" and k[0] == dock]
for g in grids:
    img = c.get(f"Containments][{dock}][Applets][{g}][Configuration][General", "customButtonImage", fallback="")
    assert img == "/usr/share/arkadeos/icons/dock-app-grid.svg", img
tasks = [k[1] for k, v in applets.items() if v == "org.kde.plasma.icontasks"][0]
launchers = c.get(f"Containments][{dock}][Applets][{tasks}][Configuration][General", "launchers", fallback="")
assert "org.arkadeos.GameMode.desktop" not in launchers, launchers
assert "org.arkadeos.Portal.desktop" in launchers, launchers
print("ok")
