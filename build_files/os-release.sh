#!/usr/bin/bash
# ArkadeOS name and logo (T009) in os-release: About page, boot menu entries,
# hostname. ID stays bazzite, the inherited update helpers check it.
#   os-release.sh [VERSION]
# VERSION is <Fedora version>.<build date> in the image, 45.20261111 for one:
# the Fedora it is built on, then the day (30-image-info.sh). Without it the
# Fedora version alone: the initramfs carries a copy of this file and must
# not change with every day's build (initramfs.sh, T076).
set -euo pipefail

version=${1:-$(rpm -E %fedora)}
sed -i -e 's|^NAME=.*|NAME="ArkadeOS"|' \
    -e 's|^PRETTY_NAME=.*|PRETTY_NAME="ArkadeOS"|' \
    -e "s|^VERSION=.*|VERSION=\"${version}\"|" \
    -e 's|^LOGO=.*|LOGO=arkadeos-logo|' \
    -e 's|^ANSI_COLOR=.*|ANSI_COLOR="0;38;2;244;63;94"|' \
    -e 's|^DEFAULT_HOSTNAME=.*|DEFAULT_HOSTNAME="arkadeos"|' \
    -e 's|^HOME_URL=.*|HOME_URL="https://github.com/tenarkhq/ArkadeOS"|' \
    -e 's|^DOCUMENTATION_URL=.*|DOCUMENTATION_URL="https://github.com/tenarkhq/ArkadeOS"|' \
    -e 's|^SUPPORT_URL=.*|SUPPORT_URL="https://github.com/tenarkhq/ArkadeOS/issues"|' \
    -e 's|^BUG_REPORT_URL=.*|BUG_REPORT_URL="https://github.com/tenarkhq/ArkadeOS/issues"|' \
    -e "s|^BOOTLOADER_NAME=.*|BOOTLOADER_NAME=\"ArkadeOS ${version}\"|" \
    /usr/lib/os-release
grep -qx 'PRETTY_NAME="ArkadeOS"' /usr/lib/os-release
grep -qx "VERSION=\"${version}\"" /usr/lib/os-release
