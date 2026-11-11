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

# ArkadeOS name and logo in os-release (T009), with this build's version:
# ArkadeOS 44.<build date>, the Fedora it is built on, then the day.
"$(dirname "$0")/os-release.sh" "${IMAGE_VERSION}"

# The firmware's boot menu entry is named from the system-release file
# (bootupd, at install): ArkadeOS, not the base's "Bazzite release 44 (Kinoite)".
echo "ArkadeOS release $(rpm -E %fedora)" > /usr/lib/fedora-release
grep -qx "ArkadeOS release [0-9]*" /etc/system-release
