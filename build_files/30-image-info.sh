#!/usr/bin/bash
# Points the Universal Blue image info at ArkadeOS, so the update and rebase
# helpers inherited from Bazzite follow the ArkadeOS image, not Bazzite's.
set -euo pipefail

info=/usr/share/ublue-os/image-info.json
ref="ostree-image-signed:docker://ghcr.io/${IMAGE_VENDOR}/${IMAGE_NAME}"

jq --arg name "${IMAGE_NAME}" --arg vendor "${IMAGE_VENDOR}" --arg ref "${ref}" \
   --arg version "${IMAGE_VERSION}" --arg fedora "$(rpm -E %fedora)" \
   '. + {"image-name": $name, "image-vendor": $vendor, "image-ref": $ref,
         "image-tag": "stable", "image-branch": "stable",
         "fedora-version": $fedora, "version": $version, "version-pretty": ("ArkadeOS " + $version)}' \
   "${info}" > "${info}.new"
mv "${info}.new" "${info}"
cat "${info}"

# ArkadeOS name and logo (T009) in os-release: About page, boot menu entries,
# hostname. ID stays bazzite, the inherited update helpers check it. The
# version is ArkadeOS 44.<build date>: the Fedora it is built on, then the day.
sed -i -e 's|^NAME=.*|NAME="ArkadeOS"|' \
    -e 's|^PRETTY_NAME=.*|PRETTY_NAME="ArkadeOS"|' \
    -e "s|^VERSION=.*|VERSION=\"${IMAGE_VERSION}\"|" \
    -e 's|^LOGO=.*|LOGO=arkadeos-logo|' \
    -e 's|^ANSI_COLOR=.*|ANSI_COLOR="0;38;2;244;63;94"|' \
    -e 's|^DEFAULT_HOSTNAME=.*|DEFAULT_HOSTNAME="arkadeos"|' \
    -e 's|^HOME_URL=.*|HOME_URL="https://github.com/tenarkhq/ArkadeOS"|' \
    -e 's|^DOCUMENTATION_URL=.*|DOCUMENTATION_URL="https://github.com/tenarkhq/ArkadeOS"|' \
    -e 's|^SUPPORT_URL=.*|SUPPORT_URL="https://github.com/tenarkhq/ArkadeOS/issues"|' \
    -e 's|^BUG_REPORT_URL=.*|BUG_REPORT_URL="https://github.com/tenarkhq/ArkadeOS/issues"|' \
    -e "s|^BOOTLOADER_NAME=.*|BOOTLOADER_NAME=\"ArkadeOS ${IMAGE_VERSION}\"|" \
    /usr/lib/os-release
grep -qx 'PRETTY_NAME="ArkadeOS"' /usr/lib/os-release
grep -qx "VERSION=\"${IMAGE_VERSION}\"" /usr/lib/os-release
