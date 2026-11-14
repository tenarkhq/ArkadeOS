#!/usr/bin/bash
# Look (T006): Breeze, KDE's own theme, with the Inter font, in ArkadeOS Glass
# (T086); this sets the boot menu font, the GTK defaults, the glass colour
# schemes and Plasma styles, and the wallpapers.
set -euo pipefail

# Inter comes from packages/install.sh.
rpm -q rsms-inter-fonts >/dev/null
# Inter for the boot menu (T009), Latin letters incl. Hungarian.
for size in 20 24; do
    grub2-mkfont -r 0x20-0x17F -s "${size}" -o "/usr/share/arkadeos/grub-theme/inter-${size}.pf2" \
        /usr/share/fonts/rsms-inter-fonts/Inter-Regular.ttf 2>/dev/null
done
glib-compile-schemas /usr/share/glib-2.0/schemas

# The read-only system layer is no drive in the sidebar (arkadeos-root-hidden).
systemctl enable arkadeos-root-hidden.service
# Nor the free space Dolphin shows: Solid rebuilt with patches/solid-composefs-root.patch
# (solid.sh, its own build stage).
rpm -q kf6-solid | grep -q '\.arkadeos\.'

# Fewer wallpapers to choose from (Roland, 2026-11-01): the Fedora ones and
# the KDE ones he picked go; the rest of KDE's, Bazzite's and ours stay.
# Cold Ripple, Grey, Cluster, Canopée, Cascade, Bazzite's Half-Life VGUI2, ublue and bazzite-glass went too (Roland, 2026-11-03).
cd /usr/share/wallpapers
rm -rf Default Fedora F[0-9]* \
    Altai OneStandsOut ScarletTree giants.jxl FallenLeaf IceCold Shell Kay Kokkini \
    Honeywave summer_1am Nuvole Orionids Kite PastelHills SafeLanding FlyingKonqui \
    EveningGlow ColorfulCups Sub-Arctic MilkyWay Volna Next BytheWater Autumn Path \
    ColdRipple Grey Cluster Canopee Cascade VGUI2.jpg ublue.png bazzite-glass.png
cd /
rm -rf /usr/share/backgrounds/f[0-9]* /usr/share/backgrounds/fedora-workstation
# The Breeze and Fedora global themes named two of them; they get ArkadeOS's.
sed -i 's/^Image=\(Next\|Fedora\)$/Image=ArkadeOS/' /usr/share/plasma/look-and-feel/*/contents/defaults
sed -i 's#wallpapers/Fedora/#wallpapers/ArkadeOS-Lock/#' /usr/share/kde-settings/kde-profile/default/xdg/kscreenlockerrc

# ArkadeOS Glass (T086, Roland, 2026-11-13): the sky-blue glass look. Its
# colour schemes are Breeze's, with the title area (menu bar and toolbar,
# under the glass frame) see-through in the frame's glass and the accent in
# the glass colour; its Plasma styles are Breeze's own with the glass
# taskbar and its lit task lines (art/glass-plasma.py).
python3 - <<'PY'
import re
LOOKS = {"Dark": ("BreezeDark", "Sötét", "45,81,110,136", "30,53,72,133"),
         "Light": ("BreezeLight", "Világos", "192,222,246,147", "215,234,249,146")}
for look, (base, hu, active, inactive) in LOOKS.items():
    text = open(f"/usr/share/color-schemes/{base}.colors").read().replace("61,174,233", "96,170,232")
    out, group = [], None
    for line in text.splitlines():
        if line.startswith("["):
            group = line.strip()
        key = line.split("=", 1)[0]
        if group == "[Colors:Header]" and key in ("BackgroundNormal", "BackgroundAlternate"):
            line = f"{key}={active}"
        elif group == "[Colors:Header][Inactive]" and key in ("BackgroundNormal", "BackgroundAlternate"):
            line = f"{key}={inactive}"
        elif group == "[Colors:Window]" and key in ("BackgroundNormal", "BackgroundAlternate"):
            # The window itself is the same glass as its title area (Darkly,
            # Roland 2026-11-14: "nem csak egy fejléccel", then "az eszköztár
            # és a menüsorok továbbra sem azok, nem homogén a UI"): title bar,
            # menu bar, toolbars, sidebars and status bar one see-through sky
            # blue; views (file lists, text) keep their solid colour.
            line = f"{key}={active}"
        elif group == "[WM]" and key == "activeBackground":
            line = f"{key}={active}"
        elif group == "[WM]" and key == "inactiveBackground":
            line = f"{key}={inactive}"
        elif group == "[General]" and key == "ColorScheme":
            line = f"ColorScheme=ArkadeOSGlass{look}"
        elif group == "[General]" and key == "Name":
            line = f"Name=ArkadeOS Glass {look}\nName[hu]=ArkadeOS Glass {hu}"
        elif re.match(r"Name\[", key) and group == "[General]":
            continue
        out.append(line)
    open(f"/usr/share/color-schemes/ArkadeOSGlass{look}.colors", "w").write("\n".join(out) + "\n")
PY
grep -q '^BackgroundNormal=45,81,110,136$' /usr/share/color-schemes/ArkadeOSGlassDark.colors
grep -A3 '^\[Colors:Window\]$' /usr/share/color-schemes/ArkadeOSGlassDark.colors | grep -qx 'BackgroundNormal=45,81,110,136'
for look in dark light; do
    d=/usr/share/plasma/desktoptheme/arkadeos-glass-${look}
    cp -a /usr/share/plasma/desktoptheme/default "${d}"
    python3 - "${d}/metadata.json" "${look}" <<'PY'
import json, sys
path, look = sys.argv[1:3]
meta = json.load(open(path))
plugin = {k: v for k, v in meta["KPlugin"].items() if not k.startswith(("Name[", "Description["))}
plugin.update(Id=f"arkadeos-glass-{look}", Name=f"ArkadeOS Glass {'Dark' if look == 'dark' else 'Light'}",
              Description="ArkadeOS: Breeze with the sky-blue glass taskbar")
plugin[f"Name[hu]"] = f"ArkadeOS Glass {'Sötét' if look == 'dark' else 'Világos'}"
meta["KPlugin"] = plugin
json.dump(meta, open(path, "w"), indent=4, ensure_ascii=False)
PY
    gzip -9n -c "/usr/share/arkadeos/glass-plasma/${look}/panel-background.svg" > "${d}/widgets/panel-background.svgz"
    cp "${d}/widgets/panel-background.svgz" "${d}/translucent/widgets/panel-background.svgz"
    gzip -9n -c "/usr/share/arkadeos/glass-plasma/${look}/tasks.svg" > "${d}/widgets/tasks.svgz"
done
# The new default wallpaper (Égkék) for every global theme's defaults.
sed -i 's/^Image=ArkadeOS$/Image=ArkadeOS-Egkek/' /usr/share/plasma/look-and-feel/*/contents/defaults
if grep -rqE '^Image=(Next|Fedora|ArkadeOS)$' /usr/share/plasma/look-and-feel/*/contents/defaults; then exit 1; fi
# System Settings in ArkadeOS Glass (T086, Roland, 2026-11-13: "az egész
# ablak kinézetét rendezni kell nem csak az ikonokat"): its Qt Quick parts
# (the side list, most pages) drawn by Union, KDE's CSS style engine, with
# the ArkadeOS Glass style (/usr/share/union/styles/arkadeos-glass): the side
# list tinted with the glass colour, soft rounded selection, rounder fields,
# buttons and cards. Union is still in development at KDE, so only System
# Settings and its single-page windows (kcmshell6) start with it; every other
# app keeps Breeze.
test -f /usr/share/union/styles/arkadeos-glass/contents/css/style.css
test -f /usr/share/union/styles/breeze/contents/css/style.css
for bin in systemsettings kcmshell6; do
    mv "/usr/bin/${bin}" "/usr/libexec/arkadeos/${bin}"
    # exec -a keeps the name it was started by: kinfocenter is a link to
    # systemsettings and opens Info Center only under its own name.
    printf '%s\n' '#!/usr/bin/bash' \
        "# ArkadeOS: ${bin} with the ArkadeOS Glass Union style (build_files/70-theme.sh)." \
        'export QT_QUICK_CONTROLS_STYLE=org.kde.union UNION_STYLE_NAME=arkadeos-glass' \
        "exec -a \"\$0\" /usr/libexec/arkadeos/${bin} \"\$@\"" > "/usr/bin/${bin}"
    chmod 755 "/usr/bin/${bin}"
done
test "$(readlink -f /usr/bin/kinfocenter)" = /usr/bin/systemsettings
grep -qF 'exec -a "$0" /usr/libexec/arkadeos/systemsettings "$@"' /usr/bin/systemsettings
