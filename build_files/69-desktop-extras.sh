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

# Glass audit, finding 9 (Roland, 2026-11-14: "minden glass aknát
# javítsunk"; on the Bazzite Updater: "ez kell nekünk? ... mit updatelünk
# itt?"). The Bazzite Updater runs the same update (uupd) as the ArkadeOS
# automatic update and the Portal, shows Bazzite's news, and its Rebase menu
# would turn the machine into a plain Bazzite image: packages/remove.sh takes
# it out, and its ujust recipe that puts it into Steam leaves the lists. The
# other leftovers leave the menu, the programs stay: Bazzite's documentation
# and forum pages, the Mint web app manager beside our "New web app", the
# NVIDIA X settings that do nothing on Wayland, and yad's icon browser.
if rpm -q bazzite-updater >/dev/null; then exit 1; fi
just=/usr/share/ublue-os/just/93-bazzite-update.just
if grep -qE '^add-updater-to-steam:' "${just}" 2>/dev/null; then
    sed -i -E '/^add-updater-to-steam:/i [private]' "${just}"
fi
for app in bazzite-documentation discourse webapp-manager nvidia-settings yad-icon-browser; do
    f=/usr/share/applications/${app}.desktop
    [[ -f "${f}" ]] || continue
    sed -i -e '/^NoDisplay=/d' -e '0,/^\[Desktop Entry\]/s//[Desktop Entry]\nNoDisplay=true/' "${f}"
    grep -qx NoDisplay=true "${f}"
done
