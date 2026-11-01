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

# Dock trash (T069): our metal bin in place of WhiteSur's in every variant.
for theme in WhiteSur WhiteSur-dark WhiteSur-light; do
    for icon in user-trash user-trash-full; do
        install -m 644 "/usr/share/arkadeos/icons/${icon}.svg" "/usr/share/icons/${theme}/places/scalable/${icon}.svg"
    done
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
        grep -lZ ColorScheme-Text "/usr/share/icons/${theme}/${d}"/*.svg 2>/dev/null |
            xargs -0 -r sed -i -e 's/ColorScheme-Text/ColorScheme-Highlight/g' \
                -e '/ColorScheme-Highlight *{/s/color:#[0-9a-fA-F]*/color:#0860f2/'
    done
    gtk-update-icon-cache -f -q "/usr/share/icons/${theme}"
done
