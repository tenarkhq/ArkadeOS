#!/usr/bin/bash
# Installs an ArkadeOS image onto a raw disk file with the layout a real
# install from the ISO gets (T022): BIOS boot, EFI partition, ext4 /boot,
# btrfs root.
# bootc's own whole-disk install keeps /boot inside a read-only root, where
# staged updates cannot be finalized and the boot menu cannot be changed.
# Usage (root): make-disk.sh <disk.raw> <image> <ssh public key> <source imgref> <target imgref>
set -euo pipefail

disk=$1 image=$2 key=$3 source=$4 target=$5
truncate -s 60G "${disk}"
loop=$(losetup -fP --show "${disk}")
trap 'umount -R /tmp/arkadeos-target 2>/dev/null || true; losetup -d "${loop}"' EXIT
printf 'label: gpt\nsize=1M, type=21686148-6449-6E6F-744E-656564454649\nsize=600M, type=U\nsize=1G, type=L\ntype=L\n' | sfdisk -q "${loop}"
udevadm settle
mkfs.vfat -F 32 -n EFI-SYSTEM "${loop}p2" >/dev/null
mkfs.ext4 -q -L boot "${loop}p3"
mkfs.btrfs -q -f -L root "${loop}p4"
mnt=/tmp/arkadeos-target
mkdir -p "${mnt}"
mount "${loop}p4" "${mnt}"
mkdir -p "${mnt}/boot"
mount "${loop}p3" "${mnt}/boot"
mkdir -p "${mnt}/boot/efi"
mount "${loop}p2" "${mnt}/boot/efi"
podman run --rm --privileged --pid=host --net=host --security-opt label=type:unconfined_t \
    -v /dev:/dev -v /var/lib/containers:/var/lib/containers -v "${mnt}:/target" \
    -v "${key}:/vm-key.pub:ro" \
    "${image}" \
    bootc install to-filesystem --generic-image \
        --source-imgref "${source}" --target-imgref "${target}" \
        --karg console=ttyS0,115200 \
        --root-ssh-authorized-keys /vm-key.pub /target
