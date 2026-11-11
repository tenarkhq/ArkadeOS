#!/usr/bin/bash
# Boot screen (T009, T082): the ArkadeOS Plymouth theme. Its sprites and
# script come from art/boot-sprites.js; the disk password field's pictures are
# Fedora's, taken from the spinner theme. The initramfs that shows it at boot
# is made from the same files in its own stage (initramfs.sh, T076); the
# system itself gets them here, for the screen at shutdown.
set -euo pipefail

theme=/usr/share/plymouth/themes/arkadeos
spinner=/usr/share/plymouth/themes/spinner
cp "${spinner}"/{bullet,entry,lock}.png "${theme}/"
plymouth-set-default-theme arkadeos

# The initramfs is in place, readable by root only, and carries this theme.
kver=$(ls /usr/lib/modules)
img=/usr/lib/modules/${kver}/initramfs.img
[[ "$(stat -c %a "${img}")" == 600 ]]
lsinitrd -f usr/share/plymouth/themes/arkadeos/arkadeos.script "${img}" | cmp - "${theme}/arkadeos.script"
lsinitrd "${img}" > /tmp/initrd.txt
grep -c themes/arkadeos/hot-7-white.png /tmp/initrd.txt
grep -c plymouth/script.so /tmp/initrd.txt

# T023: Windows next to ArkadeOS gets an entry in the boot menu.
systemctl enable arkadeos-windows-entry.service
