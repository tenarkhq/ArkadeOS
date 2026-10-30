#!/bin/bash
# Renders the chosen wallpaper at every size and encodes 16-bit P3 JPEG XL.
set -euo pipefail
cd /w; mkdir -p art/out
for size in 1920x1200 2560x1440 2560x1600 3840x2160 5120x2880; do
    w=${size%x*} h=${size#*x}
    for mode in dark light; do
        python3 -I art/wallpaper.py A "$w" "$h" "$mode" "art/out/${mode}-${size}.png" &
    done
    wait
done
for f in art/out/*-[0-9]*x[0-9]*.png; do
    case "$f" in *.8bit.png) continue;; esac
    cjxl -q 95 -e 7 -x color_space=RGB_D65_DCI_Rel_SRG "$f" "${f%.png}.jxl" >/dev/null 2>&1
done
ls -la art/out/*.jxl
