#!/usr/bin/bash
# Boot screen (T009): the ArkadeOS Plymouth theme goes into the initramfs.
# Its spinner frames are Fedora's, taken from the spinner theme.
set -euo pipefail

theme=/usr/share/plymouth/themes/arkadeos
spinner=/usr/share/plymouth/themes/spinner
cp "${spinner}"/throbber-*.png "${spinner}"/animation-*.png \
    "${spinner}"/{bullet,capslock,entry,keyboard,keymap-render,lock}.png "${theme}/"
plymouth-set-default-theme arkadeos

kver=$(ls /usr/lib/modules)
dracut --no-hostonly --kver "${kver}" --reproducible --zstd --add ostree \
    -f "/usr/lib/modules/${kver}/initramfs.img"
chmod 0600 "/usr/lib/modules/${kver}/initramfs.img"
lsinitrd "/usr/lib/modules/${kver}/initramfs.img" | grep -q themes/arkadeos/watermark.png
