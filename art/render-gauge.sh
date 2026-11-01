#!/bin/bash
# Renders "Ark műszer" (art/gauge.py) at every size in a container with
# Fedora's Blender, then encodes JPEG XL in one with cjxl:
#   podman run --rm -v "$PWD:/w:Z" <blender image> bash /w/art/render-gauge.sh render
#   podman run --rm -v "$PWD:/w:Z" <cjxl image> bash /w/art/render-gauge.sh encode
set -euo pipefail
cd /w; mkdir -p art/out
case "$1" in
render)
    # Blender 5.2's colour config says OCIO 2.5; Fedora's OCIO is 2.4.
    cp -r /usr/share/blender/5.2/datafiles/colormanagement /tmp/cm
    sed -i 's/^ocio_profile_version: 2.5/ocio_profile_version: 2.4/' /tmp/cm/config.ocio
    export OCIO=/tmp/cm/config.ocio
    for size in 1920x1200 2560x1440 2560x1600 3840x2160 5120x2880; do
        blender -b --factory-startup --python art/gauge.py -- ark "${size%x*}" "${size#*x}" \
            "/w/art/out/gauge-${size}.png" 128 2>&1 | grep -E 'Saved|Error' || true
    done
    ;;
encode)
    for f in art/out/gauge-*.png; do
        cjxl -q 95 -e 7 "$f" "${f%.png}.jxl" >/dev/null 2>&1
    done
    ls -la art/out/gauge-*.jxl
    ;;
esac
