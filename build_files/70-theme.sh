#!/usr/bin/bash
# Look (T006): the WhiteSur files come from whitesur.sh in their own layer;
# this adds the Inter font and the GTK defaults.
set -euo pipefail

dnf5 -y install --setopt=install_weak_deps=False rsms-inter-fonts
# Inter for the boot menu (T009), Latin letters incl. Hungarian.
for size in 20 24; do
    grub2-mkfont -r 0x20-0x17F -s "${size}" -o "/usr/share/arkadeos/grub-theme/inter-${size}.pf2" \
        /usr/share/fonts/rsms-inter-fonts/Inter-Regular.ttf 2>/dev/null
done
glib-compile-schemas /usr/share/glib-2.0/schemas

# Dock trash (T069): our metal bin in place of WhiteSur's in every variant,
# at every dock size: the scalable folder starts at 32 pixels, a smaller dock
# takes the 22 and 24 pixel ones. The 16 pixel one stays the sidebar's.
for theme in WhiteSur WhiteSur-dark WhiteSur-light; do
    for icon in user-trash user-trash-full; do
        for size in scalable 22 24; do
            if [[ -d "/usr/share/icons/${theme}/places/${size}" ]]; then
                install -m 644 "/usr/share/arkadeos/icons/${icon}.svg" "/usr/share/icons/${theme}/places/${size}/${icon}.svg"
            fi
        done
    done
    # The dock's trash widget asks for the one-colour name (user-trash-symbolic).
    # From 22 pixels up it finds the metal bin in places/dock, listed before
    # WhiteSur's places/symbolic; menus and sidebars keep the 16 pixel one.
    mkdir -p "/usr/share/icons/${theme}/places/dock"
    for icon in user-trash user-trash-full; do
        install -m 644 "/usr/share/arkadeos/icons/${icon}.svg" "/usr/share/icons/${theme}/places/dock/${icon}-symbolic.svg"
    done
    index="/usr/share/icons/${theme}/index.theme"
    if ! grep -q '^\[places/dock\]' "${index}"; then
        sed -i -e '/^Directories=/s|places/symbolic,|places/dock,places/symbolic,|' \
            -e '/^ScaledDirectories=/s|places@2x/symbolic,|places@2x/dock,places@2x/symbolic,|' "${index}"
        printf '\n[places/dock]\nSize=48\nContext=Places\nMinSize=22\nMaxSize=512\nType=Scalable\n' >> "${index}"
        printf '\n[places@2x/dock]\nSize=48\nScale=2\nContext=Places\nMinSize=22\nMaxSize=512\nType=Scalable\n' >> "${index}"
    fi
    grep -q '^Directories=.*places/dock,places/symbolic' "${index}"
    gtk-update-icon-cache -f -q "/usr/share/icons/${theme}"
done

# Kvantum app style (T069, Finder-like Dolphin); its WhiteSur themes come
# from whitesur.sh.
dnf5 -y install --setopt=install_weak_deps=False kvantum
test -f /usr/share/Kvantum/WhiteSur/WhiteSurDark.kvconfig
# The small one-colour place and drive icons (Dolphin's sidebar) take the
# accent colour instead of the text colour, as in Finder.
for theme in WhiteSur WhiteSur-dark WhiteSur-light; do
    for d in places/16 devices/16; do
        [[ -d "/usr/share/icons/${theme}/${d}" ]] || continue
        { grep -lZ ColorScheme-Text "/usr/share/icons/${theme}/${d}"/*.svg 2>/dev/null || true; } |
            xargs -0 -r sed -i -e 's/ColorScheme-Text/ColorScheme-Highlight/g' \
                -e '/ColorScheme-Highlight *{/s/color:#[0-9a-fA-F]*/color:#0860f2/'
    done
    gtk-update-icon-cache -f -q "/usr/share/icons/${theme}"
done
# The read-only system layer is no drive in the sidebar (arkadeos-root-hidden).
systemctl enable arkadeos-root-hidden.service

# Fewer wallpapers to choose from (Roland, 2026-11-01): the Fedora ones and
# the KDE ones he picked go; the rest of KDE's, Bazzite's and ours stay.
cd /usr/share/wallpapers
rm -rf Default Fedora F44 \
    Altai OneStandsOut ScarletTree giants.jxl FallenLeaf IceCold Shell Kay Kokkini \
    Honeywave summer_1am Nuvole Orionids Kite PastelHills SafeLanding FlyingKonqui \
    EveningGlow ColorfulCups Sub-Arctic MilkyWay Volna Next BytheWater Autumn Path
cd /
rm -rf /usr/share/backgrounds/f44 /usr/share/backgrounds/fedora-workstation
# The Breeze and Fedora global themes named two of them; they get the Ark.
sed -i 's/^Image=\(Next\|Fedora\)$/Image=ArkadeOS/' /usr/share/plasma/look-and-feel/*/contents/defaults
sed -i 's#wallpapers/Fedora/#wallpapers/ArkadeOS-Lock/#' /usr/share/kde-settings/kde-profile/default/xdg/kscreenlockerrc
if grep -rqE '^Image=(Next|Fedora)$' /usr/share/plasma/look-and-feel/*/contents/defaults; then exit 1; fi
