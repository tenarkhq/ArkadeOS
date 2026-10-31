#!/usr/bin/bash
# Driver coverage (T054): every driver of drivers.list is in the image's kernel,
# so a kernel update that loses one stops here. The NVIDIA image also needs
# the NVIDIA driver; Intel RST arrays need mdadm. Firmware comes with the
# base's linux-firmware.
set -euo pipefail

kver=$(ls /usr/lib/modules | head -1)
missing=0
while IFS=$'\t' read -r module what; do
    [[ -z "${module}" || "${module}" == \#* ]] && continue
    if ! modinfo -k "${kver}" -F filename "${module}" >/dev/null 2>&1; then
        echo "missing driver: ${module} (${what})"
        missing=1
    fi
done < /usr/share/arkadeos/drivers.list
if grep -q nvidia /usr/share/ublue-os/image-info.json 2>/dev/null; then
    modinfo -k "${kver}" -F filename nvidia >/dev/null || { echo "missing driver: nvidia"; missing=1; }
fi
rpm -q mdadm linux-firmware
exit "${missing}"
