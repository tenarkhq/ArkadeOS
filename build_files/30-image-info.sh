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
