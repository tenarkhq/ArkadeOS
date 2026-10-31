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
