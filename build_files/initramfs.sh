#!/usr/bin/bash
# Makes the initramfs with the ArkadeOS boot screen in it (T009, T082) under
# OUT, in a side stage of the build: the Containerfile copies it in as a
# layer of its own. Only the packages layer and the boot screen's files reach
# this stage, so the 240 MB file comes out the same bytes until one of them
# changes, and an update does not bring it again (T076). A file that has to
# be in the initramfs is mounted into this stage (Containerfile).
# Usage: initramfs.sh <OUT>
set -euo pipefail
umask 022
source "$(dirname "$0")/stage.sh"

out=$1
# The boot screen's files, its theme chosen and the system's name as the
# image has them (45-system-files.sh, 80-boot.sh, 30-image-info.sh). The
# files' modes are this stage's own (umask), not the checkout's: a build
# machine that checks files out group-writable made another initramfs.
cp -a --no-preserve=mode,ownership "$(dirname "$0")/system_files/." /
"$(dirname "$0")/os-release.sh"
theme=/usr/share/plymouth/themes/arkadeos
cp /usr/share/plymouth/themes/spinner/{bullet,entry,lock}.png "${theme}/"
plymouth-set-default-theme arkadeos

kver=$(ls /usr/lib/modules)
img=${out}/usr/lib/modules/${kver}/initramfs.img
mkdir -p "$(dirname "${img}")"
dracut --no-hostonly --kver "${kver}" --reproducible --zstd --add ostree -f "${img}"
chmod 0600 "${img}"
lsinitrd "${img}" > /tmp/initrd.txt
grep -c themes/arkadeos/arkadeos.script /tmp/initrd.txt
grep -c themes/arkadeos/hot-7-white.png /tmp/initrd.txt
grep -c plymouth/script.so /tmp/initrd.txt
settle
sha256sum "${img}"
