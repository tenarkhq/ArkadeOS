#!/usr/bin/bash
# Updates and snapshots (T025): uupd updates the system, Flatpak apps and
# Homebrew every day at 04:00 (Bazzite's timer; the new system starts at the
# next reboot); daily snapshots of the home folders, without the users'
# caches (home-cache).
set -euo pipefail

systemctl is-enabled uupd.timer
jq -e '.modules.flatpak.disable != true and .modules.system.disable != true' /etc/uupd/config.json
systemctl enable arkadeos-home-snapshots.service arkadeos-home-cache.service snapper-timeline.timer snapper-cleanup.timer
desktop-file-validate /usr/share/applications/org.arkadeos.Rollback.desktop
# "Restart now" (the update notice, the Portal) asks Plasma's own prompt
# through qdbus-qt6; Fedora 45 no longer has the tool under the name qdbus.
command -v qdbus-qt6 >/dev/null
test -e /usr/share/dbus-1/services/org.kde.LogoutPrompt.service

# T048: the top bar says when an update waits for the reboot.
systemctl --global enable arkadeos-update-notify.timer
