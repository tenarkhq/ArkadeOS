#!/usr/bin/bash
# Updates and snapshots (T025): uupd updates the system, Flatpak apps and
# Homebrew every day at 04:00 (Bazzite's timer; the new system starts at the
# next reboot); daily snapshots of the home folders.
set -euo pipefail

systemctl is-enabled uupd.timer
jq -e '.modules.flatpak.disable != true and .modules.system.disable != true' /etc/uupd/config.json
systemctl enable arkadeos-home-snapshots.service snapper-timeline.timer snapper-cleanup.timer
desktop-file-validate /usr/share/applications/org.arkadeos.Rollback.desktop
