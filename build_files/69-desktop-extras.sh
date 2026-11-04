#!/usr/bin/bash
# Desktop extras: LACT GPU control (T033), Polonium auto-tiling, off by
# default (T038), AirPlay receive and send, off by default (T040). Their
# packages come from packages/install.sh.
set -euo pipefail

# T033: LACT (packages/install.sh); lactd applies the GPU settings at boot.
rpm -q lact >/dev/null
systemctl enable lactd.service

# T038: Polonium, a pinned release (packages/install.sh).
test -f /usr/share/kwin/scripts/polonium/metadata.json

# T040: UxPlay (screen and sound from iPhone/Mac), Shairport Sync (AirPlay
# sound), PipeWire RAOP (sound to AirPlay speakers and Apple TV). Off until
# switched on (arkadeos-airplay on), as nothing runs in the background
# unasked (T050).
rpm -q uxplay shairport-sync >/dev/null
test -f /usr/share/pipewire/pipewire.conf.avail/50-raop.conf

# Bazzite commands that undo ArkadeOS or need what it leaves out stay out of
# the ujust lists: NVK switches to another image for the nouveau driver (one
# image, nouveau off, T080), and Cockpit is not in the image.
for recipe in 40-nvidia.just:toggle-nvk 82-bazzite-cockpit.just:cockpit; do
    file=/usr/share/ublue-os/just/${recipe%%:*}
    grep -qE "^${recipe#*:}[ :]" "${file}"
    sed -i -E "/^${recipe#*:}[ :]/i [private]" "${file}"
done
