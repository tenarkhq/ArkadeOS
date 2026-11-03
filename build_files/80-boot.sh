#!/usr/bin/bash
# Boot screen (T009, T082): the ArkadeOS Plymouth theme goes into the
# initramfs. Its sprites and script come from art/boot-sprites.js; the disk
# password field's pictures are Fedora's, taken from the spinner theme.
set -euo pipefail

theme=/usr/share/plymouth/themes/arkadeos
spinner=/usr/share/plymouth/themes/spinner
cp "${spinner}"/{bullet,entry,lock}.png "${theme}/"
plymouth-set-default-theme arkadeos

kver=$(ls /usr/lib/modules)
dracut --no-hostonly --kver "${kver}" --reproducible --zstd --add ostree \
    -f "/usr/lib/modules/${kver}/initramfs.img"
chmod 0600 "/usr/lib/modules/${kver}/initramfs.img"
lsinitrd "/usr/lib/modules/${kver}/initramfs.img" > /tmp/initrd.txt
grep -c themes/arkadeos/arkadeos.script /tmp/initrd.txt
grep -c themes/arkadeos/hot-7-white.png /tmp/initrd.txt
grep -c plymouth/script.so /tmp/initrd.txt

# T023: Windows next to ArkadeOS gets an entry in the boot menu.
systemctl enable arkadeos-windows-entry.service
