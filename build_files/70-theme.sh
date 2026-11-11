#!/usr/bin/bash
# Look (T006): Breeze, KDE's own theme, with the Inter font; this sets the
# boot menu font, the GTK defaults and the wallpapers.
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
# The Breeze and Fedora global themes named two of them; they get the Ark.
sed -i 's/^Image=\(Next\|Fedora\)$/Image=ArkadeOS/' /usr/share/plasma/look-and-feel/*/contents/defaults
sed -i 's#wallpapers/Fedora/#wallpapers/ArkadeOS-Lock/#' /usr/share/kde-settings/kde-profile/default/xdg/kscreenlockerrc
if grep -rqE '^Image=(Next|Fedora)$' /usr/share/plasma/look-and-feel/*/contents/defaults; then exit 1; fi
