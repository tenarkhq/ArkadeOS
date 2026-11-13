#!/bin/bash
# Renders the ArkadeOS Glass wallpapers (T086) at every size, dark and light,
# and encodes JPEG XL into their packages. Runs in a container with numpy,
# Pillow and libjxl-utils, the repository at /w.
set -euo pipefail
cd /w
declare -A PKG=([egkek]=ArkadeOS-Egkek [ark-ribbons]=ArkadeOS-Szalagok [ark-cross]=ArkadeOS-Kereszt)
for name in egkek ark-ribbons ark-cross; do
    pkg=system_files/usr/share/wallpapers/${PKG[$name]}/contents
    mkdir -p "${pkg}/images" "${pkg}/images_dark"
    for size in 1920x1200 2560x1440 2560x1600 3840x2160 5120x2880; do
        w=${size%x*} h=${size#*x}
        for mode in dark light; do
            png=/tmp/${name}-${mode}-${size}.png  # the container's own, gone with it
            python3 -I art/glass-wallpapers.py "${name}" "$w" "$h" "${mode}" "${png}"
            dir=images; [ "${mode}" = dark ] && dir=images_dark
            cjxl -q 95 -e 7 "${png}" "${pkg}/${dir}/${size}.jxl" >/dev/null 2>&1
        done
    done
done
ls -la system_files/usr/share/wallpapers/ArkadeOS-*/contents/images*/
