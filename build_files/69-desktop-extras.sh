#!/usr/bin/bash
# Desktop extras: LACT GPU control (T033), Polonium auto-tiling, off by
# default (T038), AirPlay receive and send, off by default (T040). Their
# packages and what Toshy builds against (T020) come from packages/install.sh.
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

# Two Bazzite commands that undo ArkadeOS stay out of the ujust lists: NVK
# switches to another image for the nouveau driver (one image, nouveau off,
# T080), and the Breeze GTK theme replaces WhiteSur (T006).
for recipe in 40-nvidia.just:toggle-nvk 90-bazzite-de.just:restore-bazzite-breeze-gtk-theme; do
    file=/usr/share/ublue-os/just/${recipe%%:*}
    grep -q "^${recipe#*:}:" "${file}"
    sed -i "/^${recipe#*:}:/i [private]" "${file}"
done
